// mac_tap.mm — macOS system-output capture for EarWitness via Core Audio
// process taps (macOS 14.4+), the production promotion of the spike prototype
// at spikes/macos-audio/tap/tap_probe.m. See the macos-system-audio-tap ADR
// and .code_my_spec/knowledge/meeting-bots/macos-audio-driver-spike.md §2.
//
// miniaudio has no macOS loopback backend (mackron/miniaudio#875), so this is
// the one platform hole in EarWitness's capture story. The mechanism, verified
// in the spike, is driverless:
//   1. CATapDescription           — describe WHAT to tap (global, private, unmuted)
//   2. AudioHardwareCreateProcessTap        — realize the tap object
//   3. AudioHardwareCreateAggregateDevice   — private aggregate carrying the tap
//   4. kAudioTapPropertyFormat              — learn the tap's stream format (ASBD)
//   5. AudioDeviceCreateIOProcIDWithBlock + AudioDeviceStart — pull frames
//
// The tap delivers 48kHz / 2ch / float32 interleaved frames on a Core Audio
// real-time thread. We convert them to 16kHz mono s16 with ma_data_converter
// and accumulate into a growing buffer — exactly the shape the miniaudio mic
// path in audio_capture.cpp produces — then write the finished WAV on stop
// through the shared writer in wav_writer.h. The rest of the app is unchanged.
//
// ObjC++ (.mm) because CATapDescription is an Objective-C class. This file is
// compiled and linked into priv/audio_capture_nif.so on macOS only (see the
// Makefile). It includes miniaudio.h for ma_data_converter declarations ONLY —
// the implementation lives in audio_capture.cpp (which defines
// MINIAUDIO_IMPLEMENTATION); defining it here too would duplicate symbols.

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/CATapDescription.h>
#import <CoreAudio/AudioHardwareTapping.h>

#include <unistd.h>

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

// Match audio_capture.cpp's miniaudio configuration (minus the implementation
// macro) so we pull in the same declarations and nothing more.
#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#define MA_NO_NODE_GRAPH
#define MA_NO_ENGINE
#include "../miniaudio.h"

#include "mac_tap.h"
#include "wav_writer.h"

namespace {

// Tap output target: what the mic path also produces.
constexpr ma_uint32 kOutSampleRate = 16000;
constexpr ma_uint32 kOutChannels = 1;

// Owns one running (or stopped-but-not-yet-finalized) tap capture. The NIF
// holds this as an opaque handle inside its CaptureState resource.
struct MacTapCapture {
  AudioObjectID tap = kAudioObjectUnknown;
  AudioObjectID aggregate = kAudioObjectUnknown;
  AudioDeviceIOProcID io_proc = nullptr;
  dispatch_queue_t io_queue = nil;

  ma_data_converter converter{};
  bool converter_initialized = false;
  ma_uint32 input_channels = 2;  // filled from the tap's reported ASBD

  std::mutex mutex;               // guards `samples` across RT thread + stop
  std::vector<ma_int16> samples;  // accumulated 16kHz mono s16
  size_t read_cursor = 0;         // samples already drained by ew_mac_tap_read_new

  // Preallocated conversion scratch, sized once at start so the real-time
  // IOProc never allocates for it. Grown only in the (not expected) case a
  // buffer exceeds the preallocation.
  std::vector<ma_int16> convert_scratch;

  std::string path;
};

// Reads the tap's stream format (sample rate, channels) into *asbd.
OSStatus tap_format(AudioObjectID tap, AudioStreamBasicDescription *asbd) {
  AudioObjectPropertyAddress addr = {kAudioTapPropertyFormat, kAudioObjectPropertyScopeGlobal,
                                     kAudioObjectPropertyElementMain};
  UInt32 size = sizeof(*asbd);
  return AudioObjectGetPropertyData(tap, &addr, 0, nullptr, &size, asbd);
}

// Tears down all Core Audio objects a capture owns and deletes it. Safe to
// call on a partially-constructed capture (any field may be unset). Does NOT
// write a WAV — callers that want the file call write first.
void destroy_capture(MacTapCapture *cap) {
  if (cap == nullptr) {
    return;
  }
  if (cap->aggregate != kAudioObjectUnknown && cap->io_proc != nullptr) {
    AudioDeviceStop(cap->aggregate, cap->io_proc);
    AudioDeviceDestroyIOProcID(cap->aggregate, cap->io_proc);
    cap->io_proc = nullptr;
  }
  if (cap->aggregate != kAudioObjectUnknown) {
    AudioHardwareDestroyAggregateDevice(cap->aggregate);
    cap->aggregate = kAudioObjectUnknown;
  }
  if (cap->tap != kAudioObjectUnknown) {
    AudioHardwareDestroyProcessTap(cap->tap);
    cap->tap = kAudioObjectUnknown;
  }
  if (cap->converter_initialized) {
    ma_data_converter_uninit(&cap->converter, nullptr);
    cap->converter_initialized = false;
  }
  // io_queue (and any other strong ObjC members) are released by ARC when the
  // struct destructor runs on delete — compiled with -fobjc-arc (see Makefile).
  delete cap;
}

}  // namespace

void *ew_mac_tap_start(const char *path) {
  @autoreleasepool {
    if (path == nullptr) {
      return nullptr;
    }

    // Process taps require macOS 14.4+. Refuse cleanly below the floor so the
    // caller reports unavailable rather than crashing on a missing symbol.
    if (@available(macOS 14.4, *)) {
      // fallthrough
    } else {
      return nullptr;
    }

    MacTapCapture *cap = new (std::nothrow) MacTapCapture();
    if (cap == nullptr) {
      return nullptr;
    }
    cap->path.assign(path);

    // 1. Describe the tap: global (everything the machine plays, minus us),
    //    private + unmuted so we don't alter what the user hears.
    CATapDescription *desc = [[CATapDescription alloc] initStereoGlobalTapButExcludeProcesses:@[]];
    desc.name = @"EarWitnessTap";
    desc.UUID = [NSUUID UUID];
    desc.muteBehavior = CATapUnmuted;
    desc.privateTap = YES;

    // 2. Realize the tap.
    if (AudioHardwareCreateProcessTap(desc, &cap->tap) != noErr ||
        cap->tap == kAudioObjectUnknown) {
      destroy_capture(cap);
      return nullptr;
    }

    // 3. Private aggregate device carrying the tap. Per-run UID so a leaked
    //    aggregate from a hard-killed prior run can't collide (coreaudiod
    //    keeps private aggregates until it restarts) — a documented trap.
    NSString *tapUID = [desc.UUID UUIDString];
    NSString *aggUID =
        [NSString stringWithFormat:@"ai.earwitness.tap.aggregate.%d.%p", getpid(), (void *)cap];
    NSDictionary *aggProps = @{
      @(kAudioAggregateDeviceNameKey) : @"EarWitnessTapAggregate",
      @(kAudioAggregateDeviceUIDKey) : aggUID,
      @(kAudioAggregateDeviceIsPrivateKey) : @YES,
      @(kAudioAggregateDeviceIsStackedKey) : @NO,
      @(kAudioAggregateDeviceTapAutoStartKey) : @YES,
      @(kAudioAggregateDeviceTapListKey) : @[ @{
        @(kAudioSubTapUIDKey) : tapUID,
        @(kAudioSubTapDriftCompensationKey) : @YES,
      } ],
    };
    if (AudioHardwareCreateAggregateDevice((__bridge CFDictionaryRef)aggProps, &cap->aggregate) !=
            noErr ||
        cap->aggregate == kAudioObjectUnknown) {
      destroy_capture(cap);
      return nullptr;
    }

    // 4. Learn the tap's format. Findings: 48kHz / 2ch / float32 interleaved.
    //    We read it rather than hardcode so a future OS change (mono, another
    //    rate) still feeds the converter the right input description.
    AudioStreamBasicDescription asbd = {};
    if (tap_format(cap->tap, &asbd) != noErr) {
      destroy_capture(cap);
      return nullptr;
    }
    ma_uint32 in_channels = asbd.mChannelsPerFrame ? asbd.mChannelsPerFrame : 2;
    ma_uint32 in_rate = asbd.mSampleRate ? static_cast<ma_uint32>(asbd.mSampleRate) : 48000;
    cap->input_channels = in_channels;

    // Init the converter: f32/<n>ch/<rate> in → s16/mono/16kHz out. Handles
    // resample + channel downmix + format conversion in one pass, matching
    // the 16kHz mono PCM16 the mic path and WavHeader.parse/1 expect.
    ma_data_converter_config conv_cfg = ma_data_converter_config_init(
        ma_format_f32, ma_format_s16, in_channels, kOutChannels, in_rate, kOutSampleRate);
    if (ma_data_converter_init(&conv_cfg, nullptr, &cap->converter) != MA_SUCCESS) {
      destroy_capture(cap);
      return nullptr;
    }
    cap->converter_initialized = true;

    // Preallocate: reserve ~1s of output up front so appends rarely realloc,
    // and size the per-callback conversion scratch for a generous 1s input
    // buffer so the RT thread never allocates it in the common case.
    cap->samples.reserve(kOutSampleRate);
    ma_uint64 scratch_out = 0;
    if (ma_data_converter_get_expected_output_frame_count(&cap->converter, in_rate, &scratch_out) !=
        MA_SUCCESS) {
      scratch_out = kOutSampleRate;
    }
    cap->convert_scratch.resize(static_cast<size_t>(scratch_out) + kOutSampleRate);

    // Capture raw pointers/values the block needs — never touch the ObjC
    // objects or reallocate on the RT thread.
    MacTapCapture *cap_ptr = cap;

    // 5. IOProc: real-time thread. Convert the tap's f32 frames to s16 mono
    //    16kHz and append. No logging, no enif calls, no unbounded allocation.
    AudioDeviceIOBlock block = ^(const AudioTimeStamp *now, const AudioBufferList *inData,
                                 const AudioTimeStamp *inTime, AudioBufferList *outData,
                                 const AudioTimeStamp *outTime) {
      (void)now;
      (void)inTime;
      (void)outData;
      (void)outTime;
      if (inData == nullptr || inData->mNumberBuffers == 0) {
        return;
      }
      const AudioBuffer *b = &inData->mBuffers[0];
      if (b->mData == nullptr || b->mDataByteSize == 0) {
        return;
      }
      ma_uint32 channels = b->mNumberChannels ? b->mNumberChannels : cap_ptr->input_channels;
      ma_uint64 frame_count_in =
          b->mDataByteSize / (static_cast<ma_uint64>(sizeof(float)) * channels);
      if (frame_count_in == 0) {
        return;
      }

      ma_uint64 frame_count_out = 0;
      if (ma_data_converter_get_expected_output_frame_count(&cap_ptr->converter, frame_count_in,
                                                            &frame_count_out) != MA_SUCCESS) {
        return;
      }
      if (frame_count_out == 0) {
        return;
      }
      // Grow scratch only if a buffer is unexpectedly large (mono s16 output).
      if (cap_ptr->convert_scratch.size() < frame_count_out) {
        cap_ptr->convert_scratch.resize(static_cast<size_t>(frame_count_out));
      }

      ma_uint64 in_consumed = frame_count_in;
      ma_uint64 out_written = frame_count_out;
      if (ma_data_converter_process_pcm_frames(&cap_ptr->converter, b->mData, &in_consumed,
                                               cap_ptr->convert_scratch.data(),
                                               &out_written) != MA_SUCCESS) {
        return;
      }
      if (out_written == 0) {
        return;
      }

      std::lock_guard<std::mutex> lock(cap_ptr->mutex);
      cap_ptr->samples.insert(cap_ptr->samples.end(), cap_ptr->convert_scratch.data(),
                              cap_ptr->convert_scratch.data() + out_written);
    };

    // NON-NULL serial queue: macOS 26 silently never fires the IOProc with a
    // NULL queue (documented trap).
    cap->io_queue = dispatch_queue_create("ai.earwitness.tap.io", DISPATCH_QUEUE_SERIAL);
    if (AudioDeviceCreateIOProcIDWithBlock(&cap->io_proc, cap->aggregate, cap->io_queue, block) !=
            noErr ||
        cap->io_proc == nullptr) {
      destroy_capture(cap);
      return nullptr;
    }
    if (AudioDeviceStart(cap->aggregate, cap->io_proc) != noErr) {
      destroy_capture(cap);
      return nullptr;
    }

    return cap;
  }
}

void ew_mac_tap_quiesce(void *handle) {
  auto *cap = static_cast<MacTapCapture *>(handle);
  if (cap == nullptr) {
    return;
  }

  // Stop the device first so the IOProc quiesces, then flush any in-flight
  // callback on the serial IO queue so no more appends race a later read/write.
  if (cap->aggregate != kAudioObjectUnknown && cap->io_proc != nullptr) {
    AudioDeviceStop(cap->aggregate, cap->io_proc);
    AudioDeviceDestroyIOProcID(cap->aggregate, cap->io_proc);
    cap->io_proc = nullptr;
  }
  if (cap->io_queue != nil) {
    dispatch_sync(cap->io_queue, ^{
                  });  // barrier: any queued IOProc block has finished
  }
}

int ew_mac_tap_stop(void *handle) {
  auto *cap = static_cast<MacTapCapture *>(handle);
  if (cap == nullptr) {
    return -1;
  }

  ew_mac_tap_quiesce(cap);

  bool wrote;
  {
    std::lock_guard<std::mutex> lock(cap->mutex);
    wrote = ear_witness::write_wav_s16(cap->path, cap->samples);
  }

  destroy_capture(cap);
  return wrote ? 0 : -1;
}

bool ew_mac_tap_read_new(void *handle, int16_t **out_samples, size_t *out_count) {
  auto *cap = static_cast<MacTapCapture *>(handle);
  if (cap == nullptr || out_samples == nullptr || out_count == nullptr) {
    return false;
  }

  *out_samples = nullptr;
  *out_count = 0;

  std::lock_guard<std::mutex> lock(cap->mutex);
  size_t total = cap->samples.size();
  if (cap->read_cursor >= total) {
    return true;  // nothing new
  }

  size_t new_count = total - cap->read_cursor;
  auto *buffer = static_cast<int16_t *>(std::malloc(new_count * sizeof(int16_t)));
  if (buffer == nullptr) {
    return false;
  }

  std::memcpy(buffer, cap->samples.data() + cap->read_cursor, new_count * sizeof(int16_t));
  cap->read_cursor = total;
  *out_samples = buffer;
  *out_count = new_count;
  return true;
}

void ew_mac_tap_free(void *handle) {
  destroy_capture(static_cast<MacTapCapture *>(handle));
}

bool ew_mac_tap_available(void) {
  if (@available(macOS 14.4, *)) {
    return true;
  }
  return false;
}

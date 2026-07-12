// tap_probe.m — EarWitness spike: capture system audio OUTPUT on macOS 14.4+
// via Core Audio process taps, driverless. Proves PCM frames flow from the
// system output mix into a user process.
//
// Build:   see build.sh (clang -framework CoreAudio -framework AudioToolbox ...)
// Run:     ./tap_probe [seconds] [out.wav]
//          - prints per-buffer RMS/peak so you can SEE audio moving
//          - if out.wav given, dumps captured PCM as a WAV
//
// This is a SPIKE. It intentionally uses a global system tap (everything the
// machine is playing, minus this process). Per-process tapping uses the same
// API with initWithProcesses:andDeviceUID:withStream: instead.
//
// Mechanism (the "record the other side of the call" path):
//   1. CATapDescription  — describe WHAT to tap (global, private, unmuted)
//   2. AudioHardwareCreateProcessTap  — realize the tap object
//   3. AudioHardwareCreateAggregateDevice — private aggregate whose tap-list
//      contains our tap; this is the thing you can actually run an IOProc on
//   4. kAudioTapPropertyFormat — learn the tap's stream format (ASBD)
//   5. AudioDeviceCreateIOProcIDWithBlock + AudioDeviceStart — pull frames

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/CATapDescription.h>
#import <CoreAudio/AudioHardwareTapping.h>
#import <math.h>

static AudioObjectID gTap = kAudioObjectUnknown;
static AudioObjectID gAggregate = kAudioObjectUnknown;
static AudioDeviceIOProcID gIOProc = NULL;

// --- WAV dump state (float32 interleaved as captured) ---
static FILE *gWav = NULL;
static uint32_t gWavFrames = 0;
static uint32_t gWavChannels = 2;
static double gWavRate = 48000.0;

#define CHK(expr) do { OSStatus _s = (expr); if (_s != noErr) { \
  fprintf(stderr, "ERR %s -> %d (%.4s)\n", #expr, (int)_s, (char*)&_s); return _s; } } while (0)

static void wav_open(const char *path, double rate, uint32_t ch) {
  gWav = fopen(path, "wb");
  if (!gWav) { fprintf(stderr, "cannot open %s\n", path); return; }
  gWavRate = rate; gWavChannels = ch; gWavFrames = 0;
  // Reserve 44-byte header; patched on close. IEEE float32.
  uint8_t hdr[44] = {0};
  fwrite(hdr, 1, 44, gWav);
}

static void wav_write(const float *samples, uint32_t frames, uint32_t ch) {
  if (!gWav) return;
  fwrite(samples, sizeof(float), (size_t)frames * ch, gWav);
  gWavFrames += frames;
}

static void wav_close(void) {
  if (!gWav) return;
  uint32_t dataBytes = gWavFrames * gWavChannels * (uint32_t)sizeof(float);
  uint32_t byteRate = (uint32_t)(gWavRate) * gWavChannels * (uint32_t)sizeof(float);
  uint16_t blockAlign = (uint16_t)(gWavChannels * sizeof(float));
  uint32_t riff = 36 + dataBytes; uint32_t fmtSize = 16; uint16_t fmt = 3 /*IEEE float*/;
  uint16_t ch16 = (uint16_t)gWavChannels; uint32_t rate = (uint32_t)gWavRate; uint16_t bits = 32;
  fseek(gWav, 0, SEEK_SET);
  fwrite("RIFF",1,4,gWav); fwrite(&riff,4,1,gWav); fwrite("WAVE",1,4,gWav);
  fwrite("fmt ",1,4,gWav); fwrite(&fmtSize,4,1,gWav); fwrite(&fmt,2,1,gWav);
  fwrite(&ch16,2,1,gWav); fwrite(&rate,4,1,gWav); fwrite(&byteRate,4,1,gWav);
  fwrite(&blockAlign,2,1,gWav); fwrite(&bits,2,1,gWav);
  fwrite("data",1,4,gWav); fwrite(&dataBytes,4,1,gWav);
  fclose(gWav); gWav = NULL;
  fprintf(stderr, "wrote %u frames to WAV\n", gWavFrames);
}

static OSStatus get_format(AudioObjectID tap, AudioStreamBasicDescription *asbd) {
  AudioObjectPropertyAddress addr = {
    kAudioTapPropertyFormat, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
  UInt32 sz = sizeof(*asbd);
  return AudioObjectGetPropertyData(tap, &addr, 0, NULL, &sz, asbd);
}

int main(int argc, char **argv) {
  @autoreleasepool {
    double seconds = (argc > 1) ? atof(argv[1]) : 5.0;
    const char *wavPath = (argc > 2) ? argv[2] : NULL;

    // 1. Describe the tap: global, exclude nothing, private + unmuted so we
    //    don't change what the user hears.
    CATapDescription *desc =
      [[CATapDescription alloc] initStereoGlobalTapButExcludeProcesses:@[]];
    desc.name = @"EarWitnessTapProbe";
    desc.UUID = [NSUUID UUID];
    desc.muteBehavior = CATapUnmuted;
    desc.privateTap = YES;   // Objective-C name for isPrivate / setPrivate:

    // 2. Realize the tap.
    CHK(AudioHardwareCreateProcessTap(desc, &gTap));
    fprintf(stderr, "tap object id = %u\n", gTap);

    // 3. Private aggregate device whose tap-list is our tap. For a global tap
    //    the tap alone is sufficient; some macOS versions want a real output
    //    device as the main sub-device (see findings doc). We try tap-only
    //    first because it is the simplest thing that can possibly work.
    NSString *tapUID = [desc.UUID UUIDString];
    // Unique UID per run so a leaked private aggregate from a previously
    // hard-killed run can't collide (coreaudiod keeps them until it restarts).
    NSString *aggUID = [NSString stringWithFormat:@"ai.earwitness.tap.aggregate.%d", getpid()];
    NSDictionary *aggProps = @{
      @(kAudioAggregateDeviceNameKey):        @"EarWitnessTapAggregate",
      @(kAudioAggregateDeviceUIDKey):         aggUID,
      @(kAudioAggregateDeviceIsPrivateKey):   @YES,
      @(kAudioAggregateDeviceIsStackedKey):   @NO,
      @(kAudioAggregateDeviceTapAutoStartKey):@YES,
      @(kAudioAggregateDeviceTapListKey): @[ @{
          @(kAudioSubTapUIDKey):                 tapUID,
          @(kAudioSubTapDriftCompensationKey):   @YES,
      } ],
    };
    CHK(AudioHardwareCreateAggregateDevice((__bridge CFDictionaryRef)aggProps, &gAggregate));
    fprintf(stderr, "aggregate device id = %u\n", gAggregate);

    // 4. Learn the tap's format.
    AudioStreamBasicDescription asbd = {0};
    CHK(get_format(gTap, &asbd));
    fprintf(stderr, "tap format: %.1f Hz, %u ch, %u bits, formatFlags=0x%x\n",
            asbd.mSampleRate, asbd.mChannelsPerFrame, asbd.mBitsPerChannel,
            (unsigned)asbd.mFormatFlags);
    gWavChannels = asbd.mChannelsPerFrame ? asbd.mChannelsPerFrame : 2;
    gWavRate = asbd.mSampleRate ? asbd.mSampleRate : 48000.0;
    if (wavPath) wav_open(wavPath, gWavRate, gWavChannels);

    __block uint64_t totalFrames = 0;
    __block int bufLogs = 0;

    // 5. IOProc: called on a real-time thread with the tap's audio. We compute
    //    RMS/peak (proof of real audio) and optionally append to the WAV.
    AudioDeviceIOBlock block = ^(const AudioTimeStamp *now,
                                 const AudioBufferList *inData,
                                 const AudioTimeStamp *inTime,
                                 AudioBufferList *outData,
                                 const AudioTimeStamp *outTime) {
      (void)now;(void)inTime;(void)outData;(void)outTime;
      if (!inData || inData->mNumberBuffers == 0) return;
      const AudioBuffer *b = &inData->mBuffers[0];
      const float *s = (const float *)b->mData;
      uint32_t ch = b->mNumberChannels ? b->mNumberChannels : gWavChannels;
      uint32_t n  = b->mDataByteSize / (uint32_t)sizeof(float);      // total samples
      uint32_t frames = ch ? n / ch : n;
      double sumsq = 0; float peak = 0;
      for (uint32_t i = 0; i < n; i++) { float v = s[i]; sumsq += (double)v*v; float a = fabsf(v); if (a>peak) peak=a; }
      double rms = n ? sqrt(sumsq / n) : 0;
      totalFrames += frames;
      if (bufLogs < 200 && (bufLogs % 10 == 0)) {
        fprintf(stderr, "buf: frames=%u ch=%u rms=%.5f peak=%.5f\n", frames, ch, rms, peak);
      }
      bufLogs++;
      wav_write(s, frames, ch);
    };

    // NOTE (macOS 26): passing a NULL dispatch queue here can silently never
    // fire the IOProc. Give it a real serial queue.
    dispatch_queue_t ioQueue = dispatch_queue_create("ai.earwitness.tap.io", DISPATCH_QUEUE_SERIAL);
    fprintf(stderr, "creating IOProc...\n"); fflush(stderr);
    CHK(AudioDeviceCreateIOProcIDWithBlock(&gIOProc, gAggregate, ioQueue, block));
    fprintf(stderr, "starting device...\n"); fflush(stderr);
    CHK(AudioDeviceStart(gAggregate, gIOProc));
    fprintf(stderr, "capturing %.1f s ... (play some audio now)\n", seconds); fflush(stderr);

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];

    AudioDeviceStop(gAggregate, gIOProc);
    AudioDeviceDestroyIOProcID(gAggregate, gIOProc);
    AudioHardwareDestroyAggregateDevice(gAggregate);
    AudioHardwareDestroyProcessTap(gTap);
    wav_close();

    fprintf(stderr, "DONE. total frames captured = %llu (%.2f s @ %.0f Hz)\n",
            totalFrames, gWavRate ? totalFrames/gWavRate : 0, gWavRate);
    return 0;
  }
}

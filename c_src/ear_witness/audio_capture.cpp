// miniaudio-backed capture NIF for EarWitness.Audio.Miniaudio — the real
// (non-fixture) capture backend for EarWitness.Audio.Pipeline. See
// .code_my_spec/architecture/decisions/miniaudio-capture.md.
//
// Platform coverage:
//   - Microphone capture: every platform miniaudio supports (macOS Core
//     Audio, Windows WASAPI, Linux ALSA/PulseAudio/PipeWire) — validated
//     live on macOS.
//   - System-output loopback: Windows via native WASAPI loopback
//     (ma_device_type_loopback) and Linux via a PulseAudio/PipeWire
//     "monitor" capture device — neither has been exercised on real
//     Windows/Linux hardware in this change; CI on those platforms must
//     validate before this path is trusted.
//   - macOS system-output loopback IS implemented, but not in miniaudio
//     (which has no macOS loopback backend — mackron/miniaudio#875). It lives
//     in the sibling Core Audio process-tap module c_src/ear_witness/mac_tap.mm
//     (see .code_my_spec/architecture/decisions/macos-system-audio-tap.md).
//     On macOS 14.4+ loopback_available() returns true and
//     start_loopback_capture/1 drives that tap through the ew_mac_tap_* C
//     interface (mac_tap.h); older macOS honestly reports unavailable.

#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#define MA_NO_NODE_GRAPH
#define MA_NO_ENGINE
#define MINIAUDIO_IMPLEMENTATION
#include "../miniaudio.h"

#include "wav_writer.h"

#ifdef __APPLE__
// macOS system-output capture lives in mac_tap.mm (Core Audio process tap) —
// miniaudio has no macOS loopback backend (mackron/miniaudio#875). The
// loopback paths below call into it via this C interface.
#include "mac_tap.h"
#endif

#include <erl_nif.h>

#include <cctype>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <new>
#include <string>
#include <vector>

namespace {

constexpr ma_uint32 kSampleRate = 16000;
constexpr ma_uint32 kChannels = 1;

// Owns one running (or stopped-but-not-yet-finalized) capture device. Lives
// as an enif resource so the Elixir side gets an opaque handle back from
// start_capture/2 and start_loopback_capture/1 to pass to stop_capture/1.
struct CaptureState {
  ma_device device{};
  std::mutex mutex;
  std::vector<ma_int16> samples;
  // Count of samples already handed out by capture_read_new/1 — the live
  // transcriber's drain cursor. Only advanced under `mutex`; never rewinds
  // `samples`, so stop_capture/1 still writes the identical full WAV. For a
  // duplex capture it indexes `mixed` instead.
  size_t read_cursor = 0;
  std::string path;
  bool device_initialized = false;
  // Duplex (microphone + system-audio tap) capture: the mic streams into
  // `samples` via data_callback (as usual) while `mac_tap_handle` streams the
  // system audio into the tap's own buffer; mix_duplex sums the two,
  // index-aligned, into `mixed`, which read_new/stop then serve/finalize. Empty
  // and unused for single-source captures.
  bool duplex = false;
  // Serializes the duplex CONSUMERS — read_new (the live transcriber's drain
  // process) and stop_capture (the UI's stop) run from different Erlang
  // processes, i.e. different scheduler threads. tap_buffer/mixed/read_cursor
  // and mac_tap_handle teardown are only touched under this lock. `mutex`
  // above keeps protecting `samples` against the audio callback.
  std::mutex duplex_mutex;
  std::vector<ma_int16> tap_buffer;  // system-audio samples drained from the tap
  std::vector<ma_int16> mixed;       // mic + system audio, summed and clamped
  // Non-null when this capture is a macOS Core Audio process tap rather than a
  // miniaudio device (see mac_tap.mm). The tap owns its own sample buffer,
  // conversion, and WAV finalize; stop_capture/1 and the resource destructor
  // route to it. Always null on non-Apple platforms and for mic capture.
  void *mac_tap_handle = nullptr;
};

ErlNifResourceType *g_capture_resource_type = nullptr;

void data_callback(ma_device *device, void *output, const void *input, ma_uint32 frame_count) {
  (void)output;

  auto *state = static_cast<CaptureState *>(device->pUserData);
  if (state == nullptr || input == nullptr || frame_count == 0) {
    return;
  }

  const auto *incoming = static_cast<const ma_int16 *>(input);
  std::lock_guard<std::mutex> lock(state->mutex);
  state->samples.insert(state->samples.end(), incoming,
                         incoming + static_cast<size_t>(frame_count) * kChannels);
}

void capture_resource_dtor(ErlNifEnv *env, void *obj) {
  (void)env;
  auto *state = static_cast<CaptureState *>(obj);
#ifdef __APPLE__
  // A tap capture GC'd without an explicit stop must still tear down its Core
  // Audio objects — a leaked private aggregate lingers in coreaudiod. Discard
  // (no WAV) here, mirroring how the miniaudio branch below uninits without
  // finalizing a file.
  if (state->mac_tap_handle != nullptr) {
    ew_mac_tap_free(state->mac_tap_handle);
    state->mac_tap_handle = nullptr;
  }
#endif
  if (state->device_initialized) {
    ma_device_uninit(&state->device);
  }
  state->~CaptureState();
}

ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM value) {
  return enif_make_tuple2(env, enif_make_atom(env, "ok"), value);
}

ERL_NIF_TERM make_error(ErlNifEnv *env, const char *reason) {
  return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, reason));
}

ERL_NIF_TERM make_binary_from_cstring(ErlNifEnv *env, const char *str) {
  size_t len = std::strlen(str);
  ERL_NIF_TERM term;
  unsigned char *buffer = enif_make_new_binary(env, len, &term);
  if (len > 0) {
    std::memcpy(buffer, str, len);
  }
  return term;
}

bool get_path(ErlNifEnv *env, ERL_NIF_TERM term, std::string *out) {
  ErlNifBinary bin;
  if (!enif_inspect_binary(env, term, &bin)) {
    return false;
  }
  out->assign(reinterpret_cast<const char *>(bin.data), bin.size);
  return true;
}

// PCM16 mono WAV finalize is shared with the macOS tap path — see
// wav_writer.h (ear_witness::write_wav_s16). kSampleRate/kChannels above and
// the writer's kWavSampleRate/kWavChannels are the same 16kHz mono contract.

// Enumerates devices via a fresh, short-lived context each call — simpler
// and safer than keeping one alive for the NIF's lifetime, and cheap
// enough (device lists change rarely, and this is only called from user
// interaction, not the audio callback).
struct DeviceLister {
  ma_context context{};
  bool initialized = false;

  DeviceLister() { initialized = ma_context_init(nullptr, 0, nullptr, &context) == MA_SUCCESS; }

  ~DeviceLister() {
    if (initialized) {
      ma_context_uninit(&context);
    }
  }
};

// Starts a capture (or, for ma_device_type_loopback, loopback-of-a-playback)
// device streaming into a fresh CaptureState resource. device_id may be
// null to request the platform default.
ERL_NIF_TERM start_device(ErlNifEnv *env, ma_device_type device_type, const ma_device_id *device_id,
                           const std::string &path) {
  void *resource_mem = enif_alloc_resource(g_capture_resource_type, sizeof(CaptureState));
  auto *state = new (resource_mem) CaptureState();
  state->path = path;

  ma_device_config config = ma_device_config_init(device_type);
  config.capture.pDeviceID = device_id;
  config.capture.format = ma_format_s16;
  config.capture.channels = kChannels;
  config.capture.shareMode = ma_share_mode_shared;
  config.sampleRate = kSampleRate;
  config.dataCallback = data_callback;
  config.pUserData = state;

  ma_result result = ma_device_init(nullptr, &config, &state->device);
  if (result != MA_SUCCESS) {
    enif_release_resource(resource_mem);
    return make_error(env, "device_init_failed");
  }
  state->device_initialized = true;

  result = ma_device_start(&state->device);
  if (result != MA_SUCCESS) {
    ma_device_uninit(&state->device);
    state->device_initialized = false;
    enif_release_resource(resource_mem);
    return make_error(env, "device_start_failed");
  }

  ERL_NIF_TERM resource_term = enif_make_resource(env, resource_mem);
  // enif_make_resource/2 took its own reference; release ours so the
  // resource's lifetime is owned solely by the Elixir-side term (freed by
  // capture_resource_dtor when garbage collected, same pattern the BEAM
  // uses for every other resource-object NIF).
  enif_release_resource(resource_mem);
  return make_ok(env, resource_term);
}

ma_int16 clamp_s16(int32_t v) {
  if (v > 32767) return 32767;
  if (v < -32768) return -32768;
  return static_cast<ma_int16>(v);
}

// Resolves the capture device at `device_index` (as enumerated by
// list_devices/0) to its ma_device_id. Returns false — leaving *out_id
// untouched — for a negative index or if the list shifted, so the caller falls
// back to the platform default device.
bool resolve_capture_device_id(int device_index, ma_device_id *out_id) {
  if (device_index < 0) {
    return false;
  }
  DeviceLister lister;
  if (!lister.initialized) {
    return false;
  }
  ma_device_info *capture_infos = nullptr;
  ma_uint32 capture_count = 0;
  ma_device_info *playback_infos = nullptr;
  ma_uint32 playback_count = 0;
  if (ma_context_get_devices(&lister.context, &playback_infos, &playback_count, &capture_infos,
                              &capture_count) != MA_SUCCESS ||
      static_cast<ma_uint32>(device_index) >= capture_count) {
    return false;
  }
  *out_id = capture_infos[device_index].id;
  return true;
}

#ifdef __APPLE__
// Mixes the microphone (state->samples) with the system-audio tap into
// state->mixed, index-aligned — both are 16kHz mono s16 captured from
// near-simultaneous starts, so sample i of each is ~the same instant. During
// capture (`final` false) it mixes only up to the shorter of the two streams so
// they stay aligned as they grow; at stop (`final` true) it mixes the whole of
// both, treating the shorter one's missing tail as silence so no audio is lost.
// Consumer-only (read_new/stop, never the audio thread); reads state->samples
// under state->mutex.
void mix_duplex(CaptureState *state, bool final) {
  if (state->mac_tap_handle != nullptr) {
    int16_t *tap_new = nullptr;
    size_t tap_count = 0;
    if (ew_mac_tap_read_new(state->mac_tap_handle, &tap_new, &tap_count) && tap_count > 0) {
      state->tap_buffer.insert(state->tap_buffer.end(), tap_new, tap_new + tap_count);
      std::free(tap_new);
    }
  }

  std::lock_guard<std::mutex> lock(state->mutex);
  size_t mic_n = state->samples.size();
  size_t tap_n = state->tap_buffer.size();
  size_t target = final ? (mic_n > tap_n ? mic_n : tap_n) : (mic_n < tap_n ? mic_n : tap_n);
  state->mixed.reserve(target);
  for (size_t i = state->mixed.size(); i < target; ++i) {
    int32_t m = i < mic_n ? state->samples[i] : 0;
    int32_t t = i < tap_n ? state->tap_buffer[i] : 0;
    state->mixed.push_back(clamp_s16(m + t));
  }
}
#endif

// Case-insensitive substring search — used to spot PulseAudio/PipeWire
// "Monitor of ..." capture devices, which is how Linux loopback capture
// works: monitors show up as ordinary capture devices, no loopback device
// type needed (that's WASAPI-only — see ma_is_loopback_supported below).
bool contains_ci(const char *haystack, const char *needle) {
  std::string h(haystack);
  std::string n(needle);
  for (auto &c : h) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  for (auto &c : n) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return h.find(n) != std::string::npos;
}

#if defined(__linux__) && !defined(__ANDROID__)
// Finds the first PulseAudio/PipeWire monitor source among capture
// devices. Returns true and fills *out_id when found.
bool find_linux_monitor_device(ma_device_id *out_id) {
  DeviceLister lister;
  if (!lister.initialized) {
    return false;
  }

  ma_device_info *capture_infos = nullptr;
  ma_uint32 capture_count = 0;
  ma_device_info *playback_infos = nullptr;
  ma_uint32 playback_count = 0;

  if (ma_context_get_devices(&lister.context, &playback_infos, &playback_count, &capture_infos,
                              &capture_count) != MA_SUCCESS) {
    return false;
  }

  for (ma_uint32 i = 0; i < capture_count; i++) {
    if (contains_ci(capture_infos[i].name, "monitor")) {
      *out_id = capture_infos[i].id;
      return true;
    }
  }

  return false;
}
#endif

// ---------------------------------------------------------------------------
// Playback (play_wav/1) — plays one of our own 16kHz mono PCM16 WAVs out the
// default OUTPUT device. Self-contained and additive: it shares nothing with
// the capture path above except kSampleRate/kChannels, so it slots cleanly
// alongside the mic + loopback capture backends (and the sibling macOS tap).
// MA_NO_DECODING stays on — we parse the fixed 44-byte header ourselves rather
// than pulling in miniaudio's decoders.
// ---------------------------------------------------------------------------

// Reads the PCM16 payload of one of our own 16kHz-mono WAVs into `out`. These
// files are always written by write_wav above (or the Elixir DemoSignal
// helper), so the header is a fixed 44-byte RIFF/WAVE: "RIFF"@0, "WAVE"@8,
// "data"@36, 4-byte data size @40, samples @44. We still validate those tags
// so a truncated/foreign file is rejected rather than played as noise.
// Returns false (leaving out untouched) on any structural problem.
bool read_wav_s16(const std::string &path, std::vector<ma_int16> *out) {
  FILE *file = std::fopen(path.c_str(), "rb");
  if (file == nullptr) {
    return false;
  }

  // RIFF/WAVE preamble (12 bytes): "RIFF" <size> "WAVE".
  unsigned char riff[12];
  if (std::fread(riff, 1, sizeof(riff), file) != sizeof(riff) ||
      std::memcmp(riff + 0, "RIFF", 4) != 0 || std::memcmp(riff + 8, "WAVE", 4) != 0) {
    std::fclose(file);
    return false;
  }

  // Walk the chunk list to find "data" — the app's own captures write a
  // canonical 44-byte header (data at offset 36), but a bundled/external clip
  // (e.g. the recording-notice WAV from ffmpeg) may carry a LIST/INFO or fmt
  // extension chunk first. Skipping unknown chunks makes this read any valid
  // PCM16 WAV, not only our own writer's layout.
  while (true) {
    unsigned char chunk[8];
    if (std::fread(chunk, 1, sizeof(chunk), file) != sizeof(chunk)) {
      std::fclose(file);
      return false;  // ran off the end without a data chunk
    }

    uint32_t chunk_size = static_cast<uint32_t>(chunk[4]) | (static_cast<uint32_t>(chunk[5]) << 8) |
                          (static_cast<uint32_t>(chunk[6]) << 16) |
                          (static_cast<uint32_t>(chunk[7]) << 24);

    if (std::memcmp(chunk, "data", 4) == 0) {
      size_t frame_count = chunk_size / sizeof(ma_int16);
      out->resize(frame_count);
      if (frame_count > 0) {
        size_t read = std::fread(out->data(), sizeof(ma_int16), frame_count, file);
        // Tolerate a data-size field that overshoots the bytes actually
        // present (e.g. a capture killed mid-finalize) — play what landed.
        out->resize(read);
      }
      std::fclose(file);
      return true;
    }

    // Skip this chunk's body; RIFF chunks are word-aligned, so an odd size is
    // followed by a pad byte.
    long skip = static_cast<long>(chunk_size) + (chunk_size & 1);
    if (std::fseek(file, skip, SEEK_CUR) != 0) {
      std::fclose(file);
      return false;
    }
  }
}

// Drives one blocking playback to completion. Lives on the calling (dirty)
// NIF thread's stack; the miniaudio audio thread reads `samples` and reports
// progress back through `cursor`/`finished` under `mutex`.
struct PlaybackState {
  std::vector<ma_int16> samples;
  size_t cursor = 0;
  std::mutex mutex;
  std::condition_variable cv;
  bool finished = false;
  // Number of all-silence buffers emitted after the last real sample. We wait
  // for a few before signalling done so the device's own buffer has flushed
  // the tail to the DAC — otherwise uninit could clip the final ~10-30ms,
  // which matters for the closed-loop tap test that analyses the played tone.
  int drain_buffers = 0;
};

constexpr int kDrainBuffers = 3;

void playback_data_callback(ma_device *device, void *output, const void *input,
                            ma_uint32 frame_count) {
  (void)input;
  auto *state = static_cast<PlaybackState *>(device->pUserData);
  auto *out = static_cast<ma_int16 *>(output);
  if (state == nullptr || out == nullptr || frame_count == 0) {
    return;
  }

  std::lock_guard<std::mutex> lock(state->mutex);

  size_t remaining = state->samples.size() - state->cursor;
  ma_uint32 to_copy =
      remaining < static_cast<size_t>(frame_count) ? static_cast<ma_uint32>(remaining) : frame_count;
  if (to_copy > 0) {
    std::memcpy(out, state->samples.data() + state->cursor,
                static_cast<size_t>(to_copy) * sizeof(ma_int16));
    state->cursor += to_copy;
  }
  if (to_copy < frame_count) {
    std::memset(out + to_copy, 0, static_cast<size_t>(frame_count - to_copy) * sizeof(ma_int16));
  }

  if (state->cursor >= state->samples.size() && !state->finished) {
    if (++state->drain_buffers >= kDrainBuffers) {
      state->finished = true;
      state->cv.notify_one();
    }
  }
}

}  // namespace

static ERL_NIF_TERM nif_list_devices(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;
  (void)argv;

  DeviceLister lister;
  if (!lister.initialized) {
    return enif_make_list(env, 0);
  }

  ma_device_info *capture_infos = nullptr;
  ma_uint32 capture_count = 0;
  ma_device_info *playback_infos = nullptr;
  ma_uint32 playback_count = 0;

  if (ma_context_get_devices(&lister.context, &playback_infos, &playback_count, &capture_infos,
                              &capture_count) != MA_SUCCESS) {
    return enif_make_list(env, 0);
  }

  std::vector<ERL_NIF_TERM> devices;
  devices.reserve(capture_count + playback_count);

  // Capture devices get nonnegative ids (their index in this enumeration —
  // start_capture/2 re-enumerates and indexes the same way). Playback
  // devices get negative ids so the two spaces can never collide; nothing
  // in this NIF currently starts a capture from a playback id, but keeping
  // them visible lets EarWitness.Audio.list_devices/0 (the legacy device
  // picker) show both lists like Membrane.PortAudio.list_devices/0 did.
  for (ma_uint32 i = 0; i < capture_count; i++) {
    ERL_NIF_TERM map = enif_make_new_map(env);
    enif_make_map_put(env, map, enif_make_atom(env, "id"), enif_make_int(env, static_cast<int>(i)),
                       &map);
    enif_make_map_put(env, map, enif_make_atom(env, "name"),
                       make_binary_from_cstring(env, capture_infos[i].name), &map);
    enif_make_map_put(env, map, enif_make_atom(env, "max_input_channels"), enif_make_int(env, 1),
                       &map);
    enif_make_map_put(env, map, enif_make_atom(env, "max_output_channels"), enif_make_int(env, 0),
                       &map);
    enif_make_map_put(env, map, enif_make_atom(env, "default_sample_rate"),
                       enif_make_int(env, static_cast<int>(kSampleRate)), &map);
    enif_make_map_put(env, map, enif_make_atom(env, "is_default"),
                       enif_make_atom(env, capture_infos[i].isDefault ? "true" : "false"), &map);
    devices.push_back(map);
  }

  for (ma_uint32 i = 0; i < playback_count; i++) {
    ERL_NIF_TERM map = enif_make_new_map(env);
    enif_make_map_put(env, map, enif_make_atom(env, "id"),
                       enif_make_int(env, -(static_cast<int>(i) + 1)), &map);
    enif_make_map_put(env, map, enif_make_atom(env, "name"),
                       make_binary_from_cstring(env, playback_infos[i].name), &map);
    enif_make_map_put(env, map, enif_make_atom(env, "max_input_channels"), enif_make_int(env, 0),
                       &map);
    enif_make_map_put(env, map, enif_make_atom(env, "max_output_channels"), enif_make_int(env, 1),
                       &map);
    enif_make_map_put(env, map, enif_make_atom(env, "default_sample_rate"),
                       enif_make_int(env, static_cast<int>(kSampleRate)), &map);
    enif_make_map_put(env, map, enif_make_atom(env, "is_default"),
                       enif_make_atom(env, playback_infos[i].isDefault ? "true" : "false"), &map);
    devices.push_back(map);
  }

  return enif_make_list_from_array(env, devices.data(), devices.size());
}

static ERL_NIF_TERM nif_start_capture(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;

  int device_index;
  std::string path;
  if (!enif_get_int(env, argv[0], &device_index) || !get_path(env, argv[1], &path)) {
    return enif_make_badarg(env);
  }

  if (device_index < 0) {
    // Negative index (the default sentinel, or a playback-device id
    // handed back by mistake) — fall back to the platform default capture
    // device rather than refusing outright.
    return start_device(env, ma_device_type_capture, nullptr, path);
  }

  DeviceLister lister;
  if (!lister.initialized) {
    return make_error(env, "device_init_failed");
  }

  ma_device_info *capture_infos = nullptr;
  ma_uint32 capture_count = 0;
  ma_device_info *playback_infos = nullptr;
  ma_uint32 playback_count = 0;

  if (ma_context_get_devices(&lister.context, &playback_infos, &playback_count, &capture_infos,
                              &capture_count) != MA_SUCCESS ||
      static_cast<ma_uint32>(device_index) >= capture_count) {
    // Device list can legitimately shift between list_devices/0 and
    // start_capture/2 (a USB mic unplugged, say) — fall back to the
    // default device instead of failing the whole capture over it.
    return start_device(env, ma_device_type_capture, nullptr, path);
  }

  ma_device_id device_id = capture_infos[device_index].id;
  return start_device(env, ma_device_type_capture, &device_id, path);
}

static ERL_NIF_TERM nif_start_loopback_capture(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;

  std::string path;
  if (!get_path(env, argv[0], &path)) {
    return enif_make_badarg(env);
  }

#if defined(_WIN32)
  // WASAPI loopback: capture whatever is playing on the default render
  // device. No explicit device id needed — null means "default playback
  // device" here because deviceType is ma_device_type_loopback.
  return start_device(env, ma_device_type_loopback, nullptr, path);
#elif defined(__linux__) && !defined(__ANDROID__)
  ma_device_id monitor_id;
  if (!find_linux_monitor_device(&monitor_id)) {
    return make_error(env, "source_unavailable");
  }
  return start_device(env, ma_device_type_capture, &monitor_id, path);
#elif defined(__APPLE__)
  // macOS: miniaudio has no loopback backend (mackron/miniaudio#875), so drive
  // the native Core Audio process tap (mac_tap.mm). It accumulates converted
  // 16kHz-mono-s16 samples and finalizes the WAV on stop, exactly like the mic
  // path — so we only need to hold its opaque handle in a CaptureState the
  // Elixir side can hand back to stop_capture/1. A null handle means the tap
  // couldn't start (below the 14.4 floor, or the TCC AudioCapture permission
  // was denied).
  {
    void *tap = ew_mac_tap_start(path.c_str());
    if (tap == nullptr) {
      return make_error(env, "source_unavailable");
    }

    void *resource_mem = enif_alloc_resource(g_capture_resource_type, sizeof(CaptureState));
    auto *state = new (resource_mem) CaptureState();
    state->path = path;
    state->mac_tap_handle = tap;

    ERL_NIF_TERM resource_term = enif_make_resource(env, resource_mem);
    enif_release_resource(resource_mem);
    return make_ok(env, resource_term);
  }
#else
  // Any other platform: no system-output capture backend. Report honestly
  // rather than faking it.
  (void)path;
  return make_error(env, "source_unavailable");
#endif
}

// Starts a DUPLEX capture — the microphone AND the system-audio tap at once,
// mixed into one 16kHz mono PCM16 stream ("both sides of a call": your voice via
// the mic + the other party via system output). The mic streams into
// state->samples; the tap into its own buffer; read_new/stop mix them
// (mix_duplex). macOS only — miniaudio has no macOS loopback backend, so this
// needs the Core Audio process tap; other platforms report source_unavailable
// and the caller falls back to a single source.
static ERL_NIF_TERM nif_start_duplex_capture(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;

  int device_index;
  std::string path;
  if (!enif_get_int(env, argv[0], &device_index) || !get_path(env, argv[1], &path)) {
    return enif_make_badarg(env);
  }

#ifdef __APPLE__
  void *resource_mem = enif_alloc_resource(g_capture_resource_type, sizeof(CaptureState));
  auto *state = new (resource_mem) CaptureState();
  state->path = path;
  state->duplex = true;

  // 1. System-audio tap (its own buffer; mix_duplex drains + mixes it). The
  //    path handed to the tap is unused — this capture writes the mixed WAV
  //    itself in stop_capture/1, and tears the tap down via quiesce + free.
  state->mac_tap_handle = ew_mac_tap_start(path.c_str());
  if (state->mac_tap_handle == nullptr) {
    enif_release_resource(resource_mem);
    return make_error(env, "source_unavailable");
  }

  // 2. Microphone device into state->samples (same 16kHz mono s16 as the tap).
  ma_device_id resolved_id;
  const ma_device_id *device_id =
      resolve_capture_device_id(device_index, &resolved_id) ? &resolved_id : nullptr;

  ma_device_config config = ma_device_config_init(ma_device_type_capture);
  config.capture.pDeviceID = device_id;
  config.capture.format = ma_format_s16;
  config.capture.channels = kChannels;
  config.capture.shareMode = ma_share_mode_shared;
  config.sampleRate = kSampleRate;
  config.dataCallback = data_callback;
  config.pUserData = state;

  if (ma_device_init(nullptr, &config, &state->device) != MA_SUCCESS) {
    ew_mac_tap_free(state->mac_tap_handle);
    state->mac_tap_handle = nullptr;
    enif_release_resource(resource_mem);
    return make_error(env, "device_init_failed");
  }
  state->device_initialized = true;

  if (ma_device_start(&state->device) != MA_SUCCESS) {
    ma_device_uninit(&state->device);
    state->device_initialized = false;
    ew_mac_tap_free(state->mac_tap_handle);
    state->mac_tap_handle = nullptr;
    enif_release_resource(resource_mem);
    return make_error(env, "device_start_failed");
  }

  ERL_NIF_TERM resource_term = enif_make_resource(env, resource_mem);
  enif_release_resource(resource_mem);
  return make_ok(env, resource_term);
#else
  (void)device_index;
  (void)path;
  return make_error(env, "source_unavailable");
#endif
}

static ERL_NIF_TERM nif_stop_capture(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;

  CaptureState *state;
  if (!enif_get_resource(env, argv[0], g_capture_resource_type, reinterpret_cast<void **>(&state))) {
    return enif_make_badarg(env);
  }

#ifdef __APPLE__
  // Duplex (mic + system-audio tap): stop both sources, mix the remainder, and
  // write ONE combined 16kHz mono WAV. Checked before the tap-only branch since
  // a duplex capture also carries a mac_tap_handle.
  if (state->duplex) {
    // Device stop stays OUTSIDE duplex_mutex: ma_device_stop blocks until the
    // audio callback drains, and that callback takes state->mutex — holding
    // an unrelated lock here is fine, but keeping the stop unlocked keeps the
    // lock ordering trivially safe.
    if (state->device_initialized) {
      ma_device_stop(&state->device);
      ma_device_uninit(&state->device);
      state->device_initialized = false;
    }

    // Everything the concurrent read_new consumer touches — tap drain, the
    // mixed buffer (realloc on growth!), and the tap handle free — happens
    // under duplex_mutex, so a drain tick mid-stop can't memcpy from a
    // reallocated `mixed` or use a freed tap handle.
    std::lock_guard<std::mutex> duplex_lock(state->duplex_mutex);

    if (state->mac_tap_handle != nullptr) {
      ew_mac_tap_quiesce(state->mac_tap_handle);
    }

    mix_duplex(state, /*final=*/true);
    bool wrote = ear_witness::write_wav_s16(state->path, state->mixed);

    if (state->mac_tap_handle != nullptr) {
      ew_mac_tap_free(state->mac_tap_handle);
      state->mac_tap_handle = nullptr;
    }
    return wrote ? enif_make_atom(env, "ok") : make_error(env, "write_failed");
  }

  // macOS tap capture: hand off to the native tap, which stops the device,
  // converts + writes the shared 16kHz mono WAV, and tears down its Core Audio
  // objects. Same Elixir surface as the mic path — stop_capture/1 works for
  // both.
  if (state->mac_tap_handle != nullptr) {
    int rc = ew_mac_tap_stop(state->mac_tap_handle);
    state->mac_tap_handle = nullptr;
    if (rc != 0) {
      return make_error(env, "write_failed");
    }
    return enif_make_atom(env, "ok");
  }
#endif

  if (!state->device_initialized) {
    return make_error(env, "already_stopped");
  }

  // ma_device_stop is synchronous — it blocks until the audio thread has
  // fully drained, so no lock is needed to read state->samples afterwards.
  ma_device_stop(&state->device);
  ma_device_uninit(&state->device);
  state->device_initialized = false;

  bool wrote = ear_witness::write_wav_s16(state->path, state->samples);
  if (!wrote) {
    return make_error(env, "write_failed");
  }

  return enif_make_atom(env, "ok");
}

// Drains the samples captured since the last call into a fresh binary of
// little-endian PCM16 bytes (the same layout stop_capture/1 writes to the
// WAV), advancing the capture's read cursor. Returns {:ok, <<>>} when nothing
// new has arrived. Additive to the capture path — it never mutates
// state->samples, so stop_capture/1 still finalizes the identical full WAV.
// This is how EarWitness.Transcription.LiveTranscriber pulls audio out of an
// in-progress capture (the WAV file itself is empty until stop). Runs on a
// normal scheduler: it only takes the capture mutex briefly and memcpys a
// short window (~a second or two of 16kHz mono at most).
static ERL_NIF_TERM nif_capture_read_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;

  CaptureState *state;
  if (!enif_get_resource(env, argv[0], g_capture_resource_type, reinterpret_cast<void **>(&state))) {
    return enif_make_badarg(env);
  }

#ifdef __APPLE__
  // Duplex (mic + system-audio tap): mix whatever is newly available from both
  // sources, then serve the newly-mixed samples. Held under duplex_mutex the
  // whole way: stop_capture (a different Erlang process → different scheduler
  // thread) grows `mixed` in its final mix — a vector realloc would leave the
  // memcpy below reading a dangling data() pointer — and frees the tap handle
  // mix_duplex drains. Checked before the tap-only branch since a duplex
  // capture also carries a mac_tap_handle.
  if (state->duplex) {
    std::lock_guard<std::mutex> duplex_lock(state->duplex_mutex);
    mix_duplex(state, /*final=*/false);
    size_t total = state->mixed.size();
    size_t new_count = state->read_cursor < total ? total - state->read_cursor : 0;
    ERL_NIF_TERM bin_term;
    unsigned char *buffer = enif_make_new_binary(env, new_count * sizeof(ma_int16), &bin_term);
    if (new_count > 0) {
      std::memcpy(buffer, state->mixed.data() + state->read_cursor, new_count * sizeof(ma_int16));
      state->read_cursor = total;
    }
    return make_ok(env, bin_term);
  }

  // macOS system-output tap: its samples live in the tap's own buffer, not
  // state->samples, so drain them through the tap's C interface (mirroring how
  // stop_capture/1 routes to ew_mac_tap_stop). A null handle (already stopped)
  // simply yields nothing new.
  if (state->mac_tap_handle != nullptr) {
    int16_t *tap_samples = nullptr;
    size_t tap_count = 0;
    if (!ew_mac_tap_read_new(state->mac_tap_handle, &tap_samples, &tap_count)) {
      return make_error(env, "read_failed");
    }
    ERL_NIF_TERM bin_term;
    unsigned char *buffer = enif_make_new_binary(env, tap_count * sizeof(int16_t), &bin_term);
    if (tap_count > 0) {
      std::memcpy(buffer, tap_samples, tap_count * sizeof(int16_t));
    }
    std::free(tap_samples);
    return make_ok(env, bin_term);
  }
#endif

  std::lock_guard<std::mutex> lock(state->mutex);
  size_t total = state->samples.size();
  size_t new_count = state->read_cursor < total ? total - state->read_cursor : 0;
  size_t byte_len = new_count * sizeof(ma_int16);

  ERL_NIF_TERM bin_term;
  unsigned char *buffer = enif_make_new_binary(env, byte_len, &bin_term);
  if (new_count > 0) {
    std::memcpy(buffer, state->samples.data() + state->read_cursor, byte_len);
    state->read_cursor = total;
  }
  return make_ok(env, bin_term);
}

static ERL_NIF_TERM nif_loopback_available(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;
  (void)argv;

#if defined(_WIN32)
  DeviceLister lister;
  bool available = lister.initialized && ma_is_loopback_supported(lister.context.backend);
  return enif_make_atom(env, available ? "true" : "false");
#elif defined(__linux__) && !defined(__ANDROID__)
  ma_device_id unused_id;
  bool available = find_linux_monitor_device(&unused_id);
  return enif_make_atom(env, available ? "true" : "false");
#elif defined(__APPLE__)
  // Core Audio process taps are available on macOS 14.4+ (runtime-checked in
  // mac_tap.mm via @available) — true there, false on older macOS.
  return enif_make_atom(env, ew_mac_tap_available() ? "true" : "false");
#else
  return enif_make_atom(env, "false");
#endif
}

// Plays a 16kHz mono PCM16 WAV out the default OUTPUT device and BLOCKS until
// the whole file has been rendered. Registered as ERL_NIF_DIRTY_JOB_IO_BOUND
// (see nif_funcs) so the blocking wait runs on a dirty scheduler and never
// stalls a normal BEAM scheduler.
static ERL_NIF_TERM nif_play_wav(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;

  std::string path;
  if (!get_path(env, argv[0], &path)) {
    return enif_make_badarg(env);
  }

  PlaybackState state;
  if (!read_wav_s16(path, &state.samples)) {
    return make_error(env, "read_failed");
  }

  ma_device_config config = ma_device_config_init(ma_device_type_playback);
  config.playback.format = ma_format_s16;
  config.playback.channels = kChannels;
  config.sampleRate = kSampleRate;
  config.dataCallback = playback_data_callback;
  config.pUserData = &state;

  ma_device device;
  if (ma_device_init(nullptr, &config, &device) != MA_SUCCESS) {
    return make_error(env, "device_init_failed");
  }

  if (ma_device_start(&device) != MA_SUCCESS) {
    ma_device_uninit(&device);
    return make_error(env, "device_start_failed");
  }

  {
    std::unique_lock<std::mutex> lock(state.mutex);
    state.cv.wait(lock, [&state] { return state.finished; });
  }

  // uninit stops the audio thread and joins it, so no callback can touch
  // `state` after this returns — safe to let the stack frame unwind.
  ma_device_uninit(&device);
  return enif_make_atom(env, "ok");
}

// Like nif_play_wav, but plays to the first PLAYBACK device whose name contains
// `device_name` (case-insensitive) — e.g. the "EarWitness Microphone" virtual
// device's output side. Returns {:error, :device_not_found} when nothing
// matches. Dirty IO-bound (blocks until the clip has rendered).
static ERL_NIF_TERM nif_play_wav_to_device(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;

  std::string path;
  std::string device_name;
  if (!get_path(env, argv[0], &path) || !get_path(env, argv[1], &device_name)) {
    return enif_make_badarg(env);
  }

  PlaybackState state;
  if (!read_wav_s16(path, &state.samples)) {
    return make_error(env, "read_failed");
  }

  ma_context context;
  if (ma_context_init(nullptr, 0, nullptr, &context) != MA_SUCCESS) {
    return make_error(env, "context_init_failed");
  }

  ma_device_info *playback_infos = nullptr;
  ma_uint32 playback_count = 0;
  if (ma_context_get_devices(&context, &playback_infos, &playback_count, nullptr, nullptr) !=
      MA_SUCCESS) {
    ma_context_uninit(&context);
    return make_error(env, "enumerate_failed");
  }

  ma_device_id device_id;
  bool found = false;
  for (ma_uint32 i = 0; i < playback_count; i++) {
    if (contains_ci(playback_infos[i].name, device_name.c_str())) {
      device_id = playback_infos[i].id;
      found = true;
      break;
    }
  }
  if (!found) {
    ma_context_uninit(&context);
    return make_error(env, "device_not_found");
  }

  ma_device_config config = ma_device_config_init(ma_device_type_playback);
  config.playback.pDeviceID = &device_id;
  config.playback.format = ma_format_s16;
  config.playback.channels = kChannels;
  config.sampleRate = kSampleRate;
  config.dataCallback = playback_data_callback;
  config.pUserData = &state;

  ma_device device;
  if (ma_device_init(&context, &config, &device) != MA_SUCCESS) {
    ma_context_uninit(&context);
    return make_error(env, "device_init_failed");
  }

  if (ma_device_start(&device) != MA_SUCCESS) {
    ma_device_uninit(&device);
    ma_context_uninit(&context);
    return make_error(env, "device_start_failed");
  }

  {
    std::unique_lock<std::mutex> lock(state.mutex);
    state.cv.wait(lock, [&state] { return state.finished; });
  }

  ma_device_uninit(&device);
  ma_context_uninit(&context);
  return enif_make_atom(env, "ok");
}

static int on_load(ErlNifEnv *env, void ** /*priv_data*/, ERL_NIF_TERM /*load_info*/) {
  auto flags = static_cast<ErlNifResourceFlags>(ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER);
  g_capture_resource_type =
      enif_open_resource_type(env, nullptr, "ear_witness_capture", capture_resource_dtor, flags, nullptr);
  return g_capture_resource_type == nullptr ? -1 : 0;
}

// Dirty IO-bound throughout: every device call can block inside CoreAudio —
// AudioDeviceStart in particular sits in a HALB_IOThread retry loop for
// seconds to minutes when coreaudiod is unhealthy (observed live: a Record
// click pinned a normal scheduler for the whole stall, wedging the VM).
// read_new stays normal: it's a sub-ms buffer copy on a 1.5s cadence.
static ErlNifFunc nif_funcs[] = {
    {"list_devices", 0, nif_list_devices, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"start_capture", 2, nif_start_capture, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"start_loopback_capture", 1, nif_start_loopback_capture, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"start_duplex_capture", 2, nif_start_duplex_capture, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"stop_capture", 1, nif_stop_capture, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"read_new", 1, nif_capture_read_new},
    {"loopback_available?", 0, nif_loopback_available, ERL_NIF_DIRTY_JOB_IO_BOUND},
    // play_wav blocks on a condition variable until the whole file has
    // rendered, so it must not run on a normal scheduler.
    {"play_wav", 1, nif_play_wav, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"play_wav_to_device", 2, nif_play_wav_to_device, ERL_NIF_DIRTY_JOB_IO_BOUND},
};

ERL_NIF_INIT(Elixir.EarWitness.Audio.Miniaudio, nif_funcs, on_load, NULL, NULL, NULL)

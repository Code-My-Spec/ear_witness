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
//   - macOS system-output loopback is NOT implemented here — miniaudio has
//     no macOS loopback backend (mackron/miniaudio#875). It is a separate
//     native Core Audio process-tap module — see
//     .code_my_spec/architecture/decisions/macos-system-audio-tap.md.
//     loopback_available() and start_loopback_capture/1 both honestly
//     report unavailable on macOS rather than faking it.

#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#define MA_NO_NODE_GRAPH
#define MA_NO_ENGINE
#define MINIAUDIO_IMPLEMENTATION
#include "../miniaudio.h"

#include <erl_nif.h>

#include <cctype>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <cstdio>
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
  std::string path;
  bool device_initialized = false;
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

// Writes accumulated PCM16 mono samples as a RIFF/WAVE file — the exact
// layout EarWitness.Recordings.WavHeader.parse/1 expects.
bool write_wav(const std::string &path, const std::vector<ma_int16> &samples) {
  FILE *file = std::fopen(path.c_str(), "wb");
  if (file == nullptr) {
    return false;
  }

  const ma_uint32 channels = kChannels;
  const ma_uint32 bits_per_sample = 16;
  const ma_uint32 block_align = channels * (bits_per_sample / 8);
  const ma_uint32 byte_rate = kSampleRate * block_align;
  const ma_uint32 data_size = static_cast<ma_uint32>(samples.size() * sizeof(ma_int16));
  const ma_uint32 riff_size = 36 + data_size;
  const ma_uint16 pcm_format = 1;

  bool ok = true;
  ok = ok && std::fwrite("RIFF", 1, 4, file) == 4;
  ok = ok && std::fwrite(&riff_size, sizeof(riff_size), 1, file) == 1;
  ok = ok && std::fwrite("WAVE", 1, 4, file) == 4;
  ok = ok && std::fwrite("fmt ", 1, 4, file) == 4;
  const ma_uint32 fmt_chunk_size = 16;
  ok = ok && std::fwrite(&fmt_chunk_size, sizeof(fmt_chunk_size), 1, file) == 1;
  ok = ok && std::fwrite(&pcm_format, sizeof(pcm_format), 1, file) == 1;
  const ma_uint16 channels16 = static_cast<ma_uint16>(channels);
  ok = ok && std::fwrite(&channels16, sizeof(channels16), 1, file) == 1;
  ok = ok && std::fwrite(&kSampleRate, sizeof(kSampleRate), 1, file) == 1;
  ok = ok && std::fwrite(&byte_rate, sizeof(byte_rate), 1, file) == 1;
  const ma_uint16 block_align16 = static_cast<ma_uint16>(block_align);
  ok = ok && std::fwrite(&block_align16, sizeof(block_align16), 1, file) == 1;
  const ma_uint16 bits_per_sample16 = static_cast<ma_uint16>(bits_per_sample);
  ok = ok && std::fwrite(&bits_per_sample16, sizeof(bits_per_sample16), 1, file) == 1;
  ok = ok && std::fwrite("data", 1, 4, file) == 4;
  ok = ok && std::fwrite(&data_size, sizeof(data_size), 1, file) == 1;

  if (ok && data_size > 0) {
    ok = std::fwrite(samples.data(), 1, data_size, file) == data_size;
  }

  std::fclose(file);
  return ok;
}

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

  unsigned char header[44];
  if (std::fread(header, 1, sizeof(header), file) != sizeof(header)) {
    std::fclose(file);
    return false;
  }

  if (std::memcmp(header + 0, "RIFF", 4) != 0 || std::memcmp(header + 8, "WAVE", 4) != 0 ||
      std::memcmp(header + 36, "data", 4) != 0) {
    std::fclose(file);
    return false;
  }

  uint32_t data_size = static_cast<uint32_t>(header[40]) | (static_cast<uint32_t>(header[41]) << 8) |
                       (static_cast<uint32_t>(header[42]) << 16) |
                       (static_cast<uint32_t>(header[43]) << 24);

  size_t frame_count = data_size / sizeof(ma_int16);
  out->resize(frame_count);
  if (frame_count > 0) {
    size_t read = std::fread(out->data(), sizeof(ma_int16), frame_count, file);
    // Tolerate a data-size field that overshoots the bytes actually present
    // (e.g. a capture killed mid-finalize) — play whatever really landed.
    out->resize(read);
  }

  std::fclose(file);
  return true;
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
#else
  // macOS (and any other platform): miniaudio has no loopback backend here
  // (mackron/miniaudio#875) — system-output capture needs the separate
  // Core Audio process-tap module described in the
  // macos-system-audio-tap ADR. Report honestly rather than faking it.
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

  if (!state->device_initialized) {
    return make_error(env, "already_stopped");
  }

  // ma_device_stop is synchronous — it blocks until the audio thread has
  // fully drained, so no lock is needed to read state->samples afterwards.
  ma_device_stop(&state->device);
  ma_device_uninit(&state->device);
  state->device_initialized = false;

  bool wrote = write_wav(state->path, state->samples);
  if (!wrote) {
    return make_error(env, "write_failed");
  }

  return enif_make_atom(env, "ok");
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

static int on_load(ErlNifEnv *env, void ** /*priv_data*/, ERL_NIF_TERM /*load_info*/) {
  auto flags = static_cast<ErlNifResourceFlags>(ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER);
  g_capture_resource_type =
      enif_open_resource_type(env, nullptr, "ear_witness_capture", capture_resource_dtor, flags, nullptr);
  return g_capture_resource_type == nullptr ? -1 : 0;
}

static ErlNifFunc nif_funcs[] = {
    {"list_devices", 0, nif_list_devices},
    {"start_capture", 2, nif_start_capture},
    {"start_loopback_capture", 1, nif_start_loopback_capture},
    {"stop_capture", 1, nif_stop_capture},
    {"loopback_available?", 0, nif_loopback_available},
    // Dirty IO-bound: play_wav blocks on a condition variable until the whole
    // file has rendered, so it must not run on a normal scheduler.
    {"play_wav", 1, nif_play_wav, ERL_NIF_DIRTY_JOB_IO_BOUND},
};

ERL_NIF_INIT(Elixir.EarWitness.Audio.Miniaudio, nif_funcs, on_load, NULL, NULL, NULL)

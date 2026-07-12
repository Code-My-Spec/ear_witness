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
// Playback (feed path) — plays a WAV file OUT to a device. Used to inject the
// recording notice (story 871) into the "EarWitness Microphone" virtual device
// so meeting apps (Zoom/Teams/Meet) that have selected it as their microphone
// hear the notice on the user's outgoing voice channel. See
// native/vmic-macos/README.md and EarWitness.Audio.VirtualMic.
// ---------------------------------------------------------------------------

// Holds the decoded PCM for one synchronous playback. Lives on the calling
// thread's stack for the duration of play_to_device — the device is fully
// uninitialized (which joins the audio thread) before the state goes out of
// scope, so the audio callback can never outlive it.
struct PlaybackState {
  std::vector<ma_int16> samples;  // interleaved, in the WAV's own channel count
  ma_uint32 channels = 1;
  size_t cursor = 0;  // index into samples (advances channels-at-a-time per frame)
  std::mutex mutex;
  std::condition_variable cv;
  bool finished = false;
};

void playback_data_callback(ma_device *device, void *output, const void *input,
                            ma_uint32 frame_count) {
  (void)input;
  auto *state = static_cast<PlaybackState *>(device->pUserData);
  if (state == nullptr || output == nullptr) {
    return;
  }

  auto *out = static_cast<ma_int16 *>(output);
  const ma_uint32 channels = state->channels;
  const size_t total = state->samples.size();

  std::lock_guard<std::mutex> lock(state->mutex);
  ma_uint32 frames_written = 0;
  for (; frames_written < frame_count && state->cursor + channels <= total; frames_written++) {
    for (ma_uint32 c = 0; c < channels; c++) {
      out[static_cast<size_t>(frames_written) * channels + c] = state->samples[state->cursor + c];
    }
    state->cursor += channels;
  }
  // Zero-fill any remaining frames in this buffer (end of clip, or underrun).
  for (size_t i = static_cast<size_t>(frames_written) * channels;
       i < static_cast<size_t>(frame_count) * channels; i++) {
    out[i] = 0;
  }

  if (state->cursor + channels > total && !state->finished) {
    state->finished = true;
    state->cv.notify_all();
  }
}

bool read_u16(FILE *file, ma_uint16 *out) { return std::fread(out, sizeof(*out), 1, file) == 1; }
bool read_u32(FILE *file, ma_uint32 *out) { return std::fread(out, sizeof(*out), 1, file) == 1; }

// Minimal RIFF/WAVE reader for 16-bit PCM (the only format EarWitness
// produces — see write_wav above and WavHeader.parse/1). Fills *samples with
// interleaved s16 and reports the source channel count / sample rate so the
// playback device can be configured to match (miniaudio then converts to the
// output device's native format). Returns false on any unsupported/malformed
// file rather than guessing.
bool read_wav(const std::string &path, std::vector<ma_int16> *samples, ma_uint32 *channels,
              ma_uint32 *sample_rate) {
  FILE *file = std::fopen(path.c_str(), "rb");
  if (file == nullptr) {
    return false;
  }

  char riff[4];
  char wave[4];
  ma_uint32 riff_size = 0;
  bool ok = std::fread(riff, 1, 4, file) == 4 && read_u32(file, &riff_size) &&
            std::fread(wave, 1, 4, file) == 4;
  if (!ok || std::memcmp(riff, "RIFF", 4) != 0 || std::memcmp(wave, "WAVE", 4) != 0) {
    std::fclose(file);
    return false;
  }

  ma_uint16 audio_format = 0;
  ma_uint16 num_channels = 0;
  ma_uint16 bits_per_sample = 0;
  ma_uint32 rate = 0;
  bool have_fmt = false;
  bool have_data = false;

  while (true) {
    char chunk_id[4];
    ma_uint32 chunk_size = 0;
    if (std::fread(chunk_id, 1, 4, file) != 4 || !read_u32(file, &chunk_size)) {
      break;
    }

    if (std::memcmp(chunk_id, "fmt ", 4) == 0) {
      ma_uint32 byte_rate = 0;
      ma_uint16 block_align = 0;
      ok = read_u16(file, &audio_format) && read_u16(file, &num_channels) && read_u32(file, &rate) &&
           read_u32(file, &byte_rate) && read_u16(file, &block_align) &&
           read_u16(file, &bits_per_sample);
      if (!ok) {
        break;
      }
      if (chunk_size > 16) {
        std::fseek(file, static_cast<long>(chunk_size - 16), SEEK_CUR);
      }
      have_fmt = true;
    } else if (std::memcmp(chunk_id, "data", 4) == 0) {
      const size_t sample_count = chunk_size / sizeof(ma_int16);
      samples->resize(sample_count);
      have_data = sample_count == 0 ||
                  std::fread(samples->data(), 1, chunk_size, file) == chunk_size;
      break;
    } else {
      // Skip unknown chunk (RIFF chunks are padded to an even byte count).
      std::fseek(file, static_cast<long>(chunk_size + (chunk_size & 1u)), SEEK_CUR);
    }
  }

  std::fclose(file);
  if (!have_fmt || !have_data || bits_per_sample != 16 || audio_format != 1 || num_channels == 0) {
    return false;
  }
  *channels = num_channels;
  *sample_rate = rate;
  return true;
}

// Plays `path` synchronously to the playback device identified by `device_id`
// (null = system default). Blocks (on a dirty IO scheduler — see nif_funcs)
// until the whole clip has been pushed to the device, then tears the device
// down. Returns :ok or {:error, reason}.
ERL_NIF_TERM play_to_device(ErlNifEnv *env, const ma_device_id *device_id, const std::string &path) {
  PlaybackState state;
  ma_uint32 channels = 1;
  ma_uint32 rate = kSampleRate;
  if (!read_wav(path, &state.samples, &channels, &rate)) {
    return make_error(env, "wav_read_failed");
  }
  state.channels = channels;

  if (state.samples.empty()) {
    return enif_make_atom(env, "ok");  // Nothing to play; treat as a no-op success.
  }

  ma_device_config config = ma_device_config_init(ma_device_type_playback);
  config.playback.pDeviceID = device_id;
  config.playback.format = ma_format_s16;
  config.playback.channels = channels;
  config.sampleRate = rate;
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

  // ma_device_uninit stops and joins the audio thread synchronously, so no
  // further callbacks touch `state` after this returns.
  ma_device_uninit(&device);
  return enif_make_atom(env, "ok");
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

// Plays a WAV file to the system default playback device.
static ERL_NIF_TERM nif_play_wav(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;
  std::string path;
  if (!get_path(env, argv[0], &path)) {
    return enif_make_badarg(env);
  }
  return play_to_device(env, nullptr, path);
}

// Plays a WAV file to the first PLAYBACK device whose name contains
// `device_name` (case-insensitive substring) — e.g. "EarWitness Microphone",
// the virtual device's output side. Returns {:error, :device_not_found} when
// no playback device matches. This is the seam story 871 uses to inject the
// recording notice into the outgoing voice channel.
static ERL_NIF_TERM nif_play_wav_to_device(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  (void)argc;
  std::string path;
  std::string device_name;
  if (!get_path(env, argv[0], &path) || !get_path(env, argv[1], &device_name)) {
    return enif_make_badarg(env);
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
                              &capture_count) != MA_SUCCESS) {
    return make_error(env, "device_init_failed");
  }

  for (ma_uint32 i = 0; i < playback_count; i++) {
    if (contains_ci(playback_infos[i].name, device_name.c_str())) {
      ma_device_id device_id = playback_infos[i].id;
      return play_to_device(env, &device_id, path);
    }
  }
  return make_error(env, "device_not_found");
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
    // Playback blocks for the length of the clip, so it runs on a dirty IO
    // scheduler to avoid stalling a normal BEAM scheduler thread.
    {"play_wav", 1, nif_play_wav, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"play_wav_to_device", 2, nif_play_wav_to_device, ERL_NIF_DIRTY_JOB_IO_BOUND},
};

ERL_NIF_INIT(Elixir.EarWitness.Audio.Miniaudio, nif_funcs, on_load, NULL, NULL, NULL)

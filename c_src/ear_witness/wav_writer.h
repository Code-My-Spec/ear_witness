// Shared 16kHz-mono-PCM16 RIFF/WAVE writer for EarWitness's capture backends.
//
// Both capture paths accumulate signed-16-bit mono samples at 16kHz and
// finalize by writing this exact 44-byte RIFF/WAVE header + PCM payload — the
// layout EarWitness.Recordings.WavHeader.parse/1 and the transcription engine
// expect:
//   - c_src/ear_witness/audio_capture.cpp (miniaudio mic + Win/Linux loopback)
//   - c_src/ear_witness/mac_tap.mm        (macOS Core Audio process tap)
//
// Header-only (functions are `inline`) so it can be included in both
// translation units without duplicate-symbol errors at link time. It has no
// miniaudio dependency — samples are plain int16_t — so mac_tap.mm can reuse
// the writer without pulling in the miniaudio implementation.

#ifndef EAR_WITNESS_WAV_WRITER_H
#define EAR_WITNESS_WAV_WRITER_H

#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

namespace ear_witness {

constexpr uint32_t kWavSampleRate = 16000;
constexpr uint32_t kWavChannels = 1;

// Writes `sample_count` mono PCM16 samples as a RIFF/WAVE file at `path`.
// Returns true on a fully-written file, false if the file couldn't be opened
// or a write was short.
inline bool write_wav_s16(const std::string &path, const int16_t *samples, size_t sample_count) {
  FILE *file = std::fopen(path.c_str(), "wb");
  if (file == nullptr) {
    return false;
  }

  const uint32_t channels = kWavChannels;
  const uint32_t sample_rate = kWavSampleRate;
  const uint32_t bits_per_sample = 16;
  const uint32_t block_align = channels * (bits_per_sample / 8);
  const uint32_t byte_rate = sample_rate * block_align;
  const uint32_t data_size = static_cast<uint32_t>(sample_count * sizeof(int16_t));
  const uint32_t riff_size = 36 + data_size;
  const uint16_t pcm_format = 1;

  bool ok = true;
  ok = ok && std::fwrite("RIFF", 1, 4, file) == 4;
  ok = ok && std::fwrite(&riff_size, sizeof(riff_size), 1, file) == 1;
  ok = ok && std::fwrite("WAVE", 1, 4, file) == 4;
  ok = ok && std::fwrite("fmt ", 1, 4, file) == 4;
  const uint32_t fmt_chunk_size = 16;
  ok = ok && std::fwrite(&fmt_chunk_size, sizeof(fmt_chunk_size), 1, file) == 1;
  ok = ok && std::fwrite(&pcm_format, sizeof(pcm_format), 1, file) == 1;
  const uint16_t channels16 = static_cast<uint16_t>(channels);
  ok = ok && std::fwrite(&channels16, sizeof(channels16), 1, file) == 1;
  ok = ok && std::fwrite(&sample_rate, sizeof(sample_rate), 1, file) == 1;
  ok = ok && std::fwrite(&byte_rate, sizeof(byte_rate), 1, file) == 1;
  const uint16_t block_align16 = static_cast<uint16_t>(block_align);
  ok = ok && std::fwrite(&block_align16, sizeof(block_align16), 1, file) == 1;
  const uint16_t bits_per_sample16 = static_cast<uint16_t>(bits_per_sample);
  ok = ok && std::fwrite(&bits_per_sample16, sizeof(bits_per_sample16), 1, file) == 1;
  ok = ok && std::fwrite("data", 1, 4, file) == 4;
  ok = ok && std::fwrite(&data_size, sizeof(data_size), 1, file) == 1;

  if (ok && data_size > 0) {
    ok = std::fwrite(samples, 1, data_size, file) == data_size;
  }

  std::fclose(file);
  return ok;
}

inline bool write_wav_s16(const std::string &path, const std::vector<int16_t> &samples) {
  return write_wav_s16(path, samples.data(), samples.size());
}

}  // namespace ear_witness

#endif  // EAR_WITNESS_WAV_WRITER_H

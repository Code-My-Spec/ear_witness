# Round-trip verification for the "EarWitness Microphone" virtual device.
#
# Proves the loopback trick works end to end: generate a 440 Hz tone, play it
# into the device's OUTPUT side (via EarWitness.Audio.Miniaudio.play_wav_to_device/2),
# WHILE capturing from the device's INPUT side (start_capture on that device's
# index), then Goertzel-verify the 440 Hz tone survived the output -> input
# round trip. If it does, injecting audio into the virtual mic works — exactly
# what story 871's recording notice needs.
#
# PREREQUISITE: the driver must be installed (native/vmic-macos/install.sh).
# Without it the script exits with a clear message rather than a crash.
#
# Run:
#   mix run native/vmic-macos/verify.exs
#
# This does NOT run in CI / on an un-provisioned box — it needs the installed
# system driver and a live Core Audio server.

require Logger

alias EarWitness.Audio.Miniaudio
alias EarWitness.Audio.VirtualMic

sample_rate = 16_000
freq = 440.0
duration_s = 1.5
tmp_dir = System.tmp_dir!()
tone_path = Path.join(tmp_dir, "ew_vmic_tone_#{System.system_time()}.wav")
capture_path = Path.join(tmp_dir, "ew_vmic_capture_#{System.system_time()}.wav")

# --- WAV helpers ------------------------------------------------------------
write_wav = fn path, samples ->
  data =
    for s <- samples, into: <<>> do
      clamped = s |> max(-32_768) |> min(32_767)
      <<clamped::signed-little-16>>
    end

  data_size = byte_size(data)
  block_align = 2
  byte_rate = sample_rate * block_align

  header =
    <<"RIFF", 36 + data_size::little-32, "WAVE", "fmt ", 16::little-32, 1::little-16,
      1::little-16, sample_rate::little-32, byte_rate::little-32, block_align::little-16,
      16::little-16, "data", data_size::little-32>>

  File.write!(path, header <> data)
end

read_wav_samples = fn path ->
  <<"RIFF", _sz::little-32, "WAVE", rest::binary>> = File.read!(path)

  find_data = fn find_data, bin ->
    case bin do
      <<"data", size::little-32, payload::binary>> ->
        <<pcm::binary-size(size), _::binary>> = payload
        for <<s::signed-little-16 <- pcm>>, do: s

      <<_id::binary-size(4), size::little-32, payload::binary>> ->
        <<_skip::binary-size(size), tail::binary>> = payload
        find_data.(find_data, tail)

      _ ->
        []
    end
  end

  find_data.(find_data, rest)
end

# --- Goertzel single-bin magnitude ------------------------------------------
goertzel = fn samples, target_hz ->
  n = length(samples)
  k = Float.round(n * target_hz / sample_rate)
  w = 2.0 * :math.pi() * k / n
  coeff = 2.0 * :math.cos(w)

  {s_prev, s_prev2} =
    Enum.reduce(samples, {0.0, 0.0}, fn x, {sp, sp2} ->
      s = x / 32_768.0 + coeff * sp - sp2
      {s, sp}
    end)

  power = s_prev2 * s_prev2 + s_prev * s_prev - coeff * s_prev * s_prev2
  :math.sqrt(max(power, 0.0)) / n
end

# --- Preflight --------------------------------------------------------------
unless VirtualMic.available?() do
  IO.puts("""

  ✗ "#{VirtualMic.device_name()}" is not installed.
    Build + install the driver first:
      cd native/vmic-macos && ./build.sh && sudo ./install.sh
  """)

  System.halt(1)
end

# Capture-side device index: list_devices/0 gives capture devices a
# nonnegative id equal to their enumeration index (start_capture/2 indexes the
# same way). Find the EarWitness Microphone entry that is a capture device.
capture_index =
  Miniaudio.list_devices()
  |> Enum.find_value(fn d ->
    name = Map.get(d, :name, "")
    id = Map.get(d, :id, -1)

    if id >= 0 and String.contains?(String.downcase(name), "earwitness microphone") do
      id
    end
  end)

if is_nil(capture_index) do
  IO.puts("✗ Could not find a capture-side index for the virtual device.")
  System.halt(1)
end

# --- Generate tone ----------------------------------------------------------
n_samples = round(sample_rate * duration_s)

tone =
  for i <- 0..(n_samples - 1) do
    round(0.5 * 32_767 * :math.sin(2.0 * :math.pi() * freq * i / sample_rate))
  end

write_wav.(tone_path, tone)
IO.puts("• Generated #{duration_s}s / #{freq}Hz tone -> #{tone_path}")

# --- Round trip: capture (input) while playing (output) ---------------------
IO.puts("• Starting capture on \"#{VirtualMic.device_name()}\" (index #{capture_index})")
{:ok, handle} = Miniaudio.start_capture(capture_index, capture_path)

# Small settle so the capture device is streaming before we inject.
Process.sleep(200)

IO.puts("• Playing tone into the virtual mic output (blocks for the clip)")
:ok = VirtualMic.feed(tone_path)

# Let the tail flush into the capture buffer, then stop.
Process.sleep(300)
:ok = Miniaudio.stop_capture(handle)

# --- Analyze ----------------------------------------------------------------
captured = read_wav_samples.(capture_path)
IO.puts("• Captured #{length(captured)} samples")

if length(captured) < sample_rate / 2 do
  IO.puts("✗ Too few samples captured — round trip did not carry audio.")
  System.halt(1)
end

mag_440 = goertzel.(captured, 440.0)
mag_1000 = goertzel.(captured, 1000.0)
mag_250 = goertzel.(captured, 250.0)
ratio = mag_440 / max(mag_1000 + mag_250, 1.0e-9)

IO.puts("""

  Goertzel magnitudes (normalized):
    440 Hz  (signal)   : #{Float.round(mag_440, 6)}
    1000 Hz (off-band) : #{Float.round(mag_1000, 6)}
    250 Hz  (off-band) : #{Float.round(mag_250, 6)}
    440 / off-band     : #{Float.round(ratio, 2)}x
""")

File.rm(tone_path)
File.rm(capture_path)

if ratio > 5.0 do
  IO.puts("✓ PASS — 440Hz tone made the output -> input round trip. Injection works.")
  System.halt(0)
else
  IO.puts("✗ FAIL — 440Hz not dominant; the loopback round trip did not carry the tone.")
  System.halt(1)
end

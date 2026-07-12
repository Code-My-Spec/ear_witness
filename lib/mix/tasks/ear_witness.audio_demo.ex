defmodule Mix.Tasks.EarWitness.AudioDemo do
  @shortdoc "Live-hardware audio demo: mic passthrough, speaker out, and system-output tap closed loop."

  @moduledoc """
  Proves EarWitness's three real audio paths on the machine you run it on,
  with a loud PASS/FAIL summary and the measured numbers behind each verdict.

      mix ear_witness.audio_demo

  Stages:

    1. MIC PASSTHROUGH — records ~#{3}s from the default mic, checks the WAV is
       not silent, then plays it straight back so you hear your own captured
       voice (the literal passthrough). Speak while it records.

    2. SPEAKER OUT — plays a 660Hz tone out the default output device. Passes
       when `play_wav/1` returns `:ok` (you should hear it).

    3. TAP THE SPEAKER (closed loop) — starts the system-output tap, plays a
       440Hz tone through the speakers, stops the tap, and uses a Goertzel
       detector to prove the tapped WAV contains 440Hz far above off-target
       control frequencies. This self-verifies system-output capture end to
       end. Skipped when `EarWitness.Audio.Miniaudio.loopback_available?/0` is
       false.

  macOS note: the first tap start raises the one-time TCC "AudioCapture"
  permission prompt. Click **Allow** — then rerun the task and stage 3 will
  capture the tone.
  """

  use Mix.Task

  # A Mix task can't own a boundary, so classify it into the EarWitness
  # boundary it drives (whose modules are all `exports: :all`).
  use Boundary, classify_to: EarWitness

  alias EarWitness.Audio.{DemoSignal, Miniaudio}

  @mic_seconds 3
  # Normalised RMS (0.0..1.0). Below this the mic captured effective silence.
  @silence_floor 0.01

  @speaker_freq 660
  @speaker_seconds 1.5

  @tap_freq 440
  @tap_seconds 2.5
  @control_freqs [300, 1000]
  # 440Hz amplitude must beat the loudest control frequency by at least this
  # factor. A genuine capture of the exact played tone clears this by a wide
  # margin (typically tens of x); broadband noise or a silent tap does not.
  @tap_dominance 8.0
  # The tap WAV must also carry real level, not just a favourable ratio between
  # two tiny numbers.
  @tap_rms_floor 0.02

  @impl Mix.Task
  def run(_args) do
    # app.config compiles the project and loads (not starts) :ear_witness, so
    # the Miniaudio NIF's @on_load can resolve :code.priv_dir/1. We avoid
    # app.start on purpose — this demo needs the audio NIF, not the Phoenix
    # endpoint / Oban / the database.
    Mix.Task.run("app.config")

    dir = Path.join(System.tmp_dir!(), "ear_witness_audio_demo")
    File.mkdir_p!(dir)

    banner()
    IO.puts("  Scratch WAVs: #{dir}\n")

    if match?({:unix, :darwin}, :os.type()) do
      IO.puts(
        "  macOS: the tap (stage 3) raises a one-time \"AudioCapture\" prompt on first run.\n" <>
          "         Click Allow; if stage 3 does not pass the first time, rerun this task.\n"
      )
    end

    results = [
      run_stage("STAGE 1  MIC PASSTHROUGH", fn -> stage_mic(dir) end),
      run_stage("STAGE 2  SPEAKER OUT", fn -> stage_speaker(dir) end),
      run_stage("STAGE 3  TAP CLOSED LOOP", fn -> stage_tap(dir) end)
    ]

    summary(results)
  end

  # --- stages -------------------------------------------------------------

  defp stage_mic(dir) do
    path = Path.join(dir, "mic.wav")
    IO.puts("  Recording #{@mic_seconds}s from the default mic — SPEAK NOW...")

    with {:ok, handle} <- Miniaudio.start_capture(0, path),
         Process.sleep(@mic_seconds * 1000),
         :ok <- Miniaudio.stop_capture(handle) do
      samples = DemoSignal.read_wav_samples(path)
      rms = DemoSignal.rms(samples)

      if rms >= @silence_floor do
        IO.puts("  Captured rms=#{f(rms)} — playing it back so you hear yourself...")
        _ = Miniaudio.play_wav(path)
        {:pass, "rms=#{f(rms)} >= floor #{f(@silence_floor)}, played back"}
      else
        {:fail, "rms=#{f(rms)} < floor #{f(@silence_floor)} — mic heard silence; speak up / check the input device"}
      end
    else
      {:error, reason} -> {:fail, "capture error #{inspect(reason)}"}
      other -> {:fail, "unexpected capture result #{inspect(other)}"}
    end
  end

  defp stage_speaker(dir) do
    path = Path.join(dir, "tone_#{@speaker_freq}.wav")
    DemoSignal.write_wav(path, DemoSignal.tone(@speaker_freq, @speaker_seconds))
    IO.puts("  Playing a #{@speaker_freq}Hz tone for #{@speaker_seconds}s — you should hear it...")

    case Miniaudio.play_wav(path) do
      :ok -> {:pass, "play_wav -> :ok (#{@speaker_freq}Hz, #{@speaker_seconds}s)"}
      other -> {:fail, "play_wav -> #{inspect(other)} (no output device?)"}
    end
  end

  defp stage_tap(dir) do
    # apply/3 defeats the type checker narrowing loopback_available?/0's
    # not-loaded stub return (false) to a literal, which would flag the tap
    # body below as dead code. The real NIF returns true wherever the tap works.
    if apply(Miniaudio, :loopback_available?, []) do
      tone_path = Path.join(dir, "tone_#{@tap_freq}.wav")
      tap_path = Path.join(dir, "tap.wav")
      DemoSignal.write_wav(tone_path, DemoSignal.tone(@tap_freq, @tap_seconds))

      IO.puts("  Starting system-output tap and playing #{@tap_freq}Hz for #{@tap_seconds}s...")

      case Miniaudio.start_loopback_capture(tap_path) do
        {:ok, handle} ->
          player = Task.async(fn -> Miniaudio.play_wav(tone_path) end)
          _ = Task.await(player, round(@tap_seconds * 1000) + 10_000)
          # Let the tail of the tone land in the tap before we stop it.
          Process.sleep(250)
          _ = Miniaudio.stop_capture(handle)
          analyze_tap(tap_path)

        {:error, reason} ->
          {:fail,
           "start_loopback_capture -> #{inspect(reason)} — on macOS click Allow on the AudioCapture prompt, then rerun"}
      end
    else
      {:skip,
       "loopback_available?() == false here (macOS without the Core Audio tap, or no monitor source on Linux)"}
    end
  end

  defp analyze_tap(tap_path) do
    samples = DemoSignal.read_wav_samples(tap_path)
    rms = DemoSignal.rms(samples)
    target = DemoSignal.goertzel_amplitude(samples, @tap_freq)

    controls =
      Enum.map(@control_freqs, fn hz -> {hz, DemoSignal.goertzel_amplitude(samples, hz)} end)

    loudest_control = controls |> Enum.map(&elem(&1, 1)) |> Enum.max()
    ratio = if loudest_control > 0.0, do: target / loudest_control, else: :infinity

    controls_str =
      controls
      |> Enum.map(fn {hz, amp} -> "#{hz}Hz=#{f(amp)}" end)
      |> Enum.join(" ")

    numbers = "[#{@tap_freq}Hz=#{f(target)} vs #{controls_str}] ratio=#{ratio_str(ratio)}x rms=#{f(rms)}"

    IO.puts("  Goertzel: #{numbers}")

    cond do
      rms < @tap_rms_floor ->
        {:fail, "tap captured near-silence — #{numbers} (rms floor #{f(@tap_rms_floor)})"}

      ratio != :infinity and ratio < @tap_dominance ->
        {:fail, "#{@tap_freq}Hz did not dominate — #{numbers} (need #{f(@tap_dominance)}x)"}

      true ->
        {:pass, "tapped tone verified — #{numbers}"}
    end
  end

  # --- output helpers -----------------------------------------------------

  defp run_stage(label, fun) do
    IO.puts("\n== #{label} ==")

    result =
      try do
        fun.()
      rescue
        e -> {:fail, "raised #{Exception.message(e)}"}
      end

    {status, detail} = result
    IO.puts("  -> #{status_word(status)}: #{detail}")
    {label, status, detail}
  end

  defp summary(results) do
    IO.puts("\n" <> String.duplicate("=", 72))
    IO.puts("  AUDIO DEMO SUMMARY")
    IO.puts(String.duplicate("=", 72))

    Enum.each(results, fn {label, status, detail} ->
      IO.puts("  #{String.pad_trailing(label, 26)} #{String.pad_trailing(status_word(status), 5)}  #{detail}")
    end)

    IO.puts(String.duplicate("=", 72))

    any_fail? = Enum.any?(results, fn {_l, s, _d} -> s == :fail end)

    if any_fail? do
      IO.puts("  Result: FAIL — see the failing stage(s) above.\n")
    else
      IO.puts("  Result: all executed stages PASSED (skips are not failures).\n")
    end
  end

  defp banner do
    IO.puts(String.duplicate("=", 72))
    IO.puts("  EARWITNESS AUDIO DEMO — real hardware, self-verifying")
    IO.puts(String.duplicate("=", 72))
  end

  defp status_word(:pass), do: "PASS"
  defp status_word(:fail), do: "FAIL"
  defp status_word(:skip), do: "SKIP"

  defp f(x) when is_float(x), do: :erlang.float_to_binary(x, decimals: 4)
  defp f(x), do: :erlang.float_to_binary(x * 1.0, decimals: 4)

  defp ratio_str(:infinity), do: "inf"
  defp ratio_str(x), do: :erlang.float_to_binary(x * 1.0, decimals: 1)
end

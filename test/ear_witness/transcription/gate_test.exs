defmodule EarWitness.Transcription.GateTest do
  use ExUnit.Case, async: false

  alias EarWitness.Transcription.Gate

  test "runs callers one at a time, never overlapping" do
    # Each task reports when it enters and leaves the gate; if two were ever
    # inside at once the running counter would exceed 1.
    counter = :counters.new(2, [:atomics])

    tasks =
      for _ <- 1..5 do
        Task.async(fn ->
          Gate.run(fn ->
            :counters.add(counter, 1, 1)
            running = :counters.get(counter, 1)
            max_seen = :counters.get(counter, 2)
            if running > max_seen, do: :counters.put(counter, 2, running)
            Process.sleep(20)
            :counters.sub(counter, 1, 1)
            {:ok, :done}
          end)
        end)
      end

    assert Enum.all?(Task.await_many(tasks, 5_000), &(&1 == {:ok, :done}))
    assert :counters.get(counter, 2) == 1
  end

  test "returns the gated function's result" do
    assert {:ok, 42} = Gate.run(fn -> {:ok, 42} end)
    assert {:error, :nope} = Gate.run(fn -> {:error, :nope} end)
  end

  test "a crash inside the gate becomes {:error, reason} and later callers still run" do
    assert {:error, message} = Gate.run(fn -> raise "bad file" end)
    assert message =~ "bad file"

    assert {:error, message} = Gate.run(fn -> exit(:whisper_died) end)
    assert message =~ "whisper_died"

    assert {:ok, :still_alive} = Gate.run(fn -> {:ok, :still_alive} end)
  end
end

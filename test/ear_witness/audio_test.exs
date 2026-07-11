defmodule EarWitness.AudioTest do
  use ExUnit.Case
  doctest EarWitness.Audio
  alias EarWitness.Audio

  describe "Devices" do
    test "list devices happy path" do
      Audio.list_devices()
    end
  end
end

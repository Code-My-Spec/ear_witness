defmodule TodoApp.Audio do
  def list_devices() do
    Membrane.PortAudio.list_devices()
  end
end

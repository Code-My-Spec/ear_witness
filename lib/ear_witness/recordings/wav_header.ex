defmodule EarWitness.Recordings.WavHeader do
  @moduledoc """
  Pure parsing of a RIFF/WAVE header — enough to validate that a file is a
  structurally usable WAV and to compute its declared duration. No I/O;
  callers read the bytes and hand them in.
  """

  defstruct [:channels, :sample_rate, :bits_per_sample, :num_samples, :duration_seconds]

  @type t :: %__MODULE__{
          channels: pos_integer(),
          sample_rate: pos_integer(),
          bits_per_sample: pos_integer(),
          num_samples: non_neg_integer(),
          duration_seconds: float()
        }

  @doc """
  Parses WAV header bytes, returning the declared format and duration.
  Anything without a valid RIFF/WAVE container, a `fmt ` chunk, and a
  `data` chunk is rejected as `{:error, :invalid_audio_file}`.
  """
  @spec parse(binary()) :: {:ok, t()} | {:error, :invalid_audio_file}
  def parse(<<"RIFF", _riff_size::little-32, "WAVE", rest::binary>>) do
    with {:ok, fmt} <- find_chunk(rest, "fmt "),
         <<_format_tag::little-16, channels::little-16, sample_rate::little-32,
           _byte_rate::little-32, block_align::little-16, bits_per_sample::little-16,
           _extra::binary>> <- fmt,
         true <- block_align > 0 and sample_rate > 0,
         {:ok, data} <- find_chunk(rest, "data") do
      num_samples = div(byte_size(data), block_align)

      {:ok,
       %__MODULE__{
         channels: channels,
         sample_rate: sample_rate,
         bits_per_sample: bits_per_sample,
         num_samples: num_samples,
         duration_seconds: num_samples / sample_rate
       }}
    else
      _ -> {:error, :invalid_audio_file}
    end
  end

  def parse(_not_a_wav), do: {:error, :invalid_audio_file}

  @doc """
  Returns a WAV file's raw PCM sample bytes (the `data` chunk payload,
  undecoded). Still pure parsing, no I/O — callers read the bytes and
  hand them in, same as `parse/1`.
  """
  @spec data_bytes(binary()) :: {:ok, binary()} | {:error, :invalid_audio_file}
  def data_bytes(<<"RIFF", _riff_size::little-32, "WAVE", rest::binary>>) do
    case find_chunk(rest, "data") do
      {:ok, data} -> {:ok, data}
      _ -> {:error, :invalid_audio_file}
    end
  end

  def data_bytes(_not_a_wav), do: {:error, :invalid_audio_file}

  defp find_chunk(
         <<id::binary-size(4), size::little-32, chunk::binary-size(size), rest::binary>>,
         target
       ) do
    if id == target do
      {:ok, chunk}
    else
      find_chunk(skip_pad(rest, size), target)
    end
  end

  defp find_chunk(_incomplete, _target), do: :error

  defp skip_pad(rest, size) when rem(size, 2) == 1, do: skip_byte(rest)
  defp skip_pad(rest, _size), do: rest

  defp skip_byte(<<_pad, rest::binary>>), do: rest
  defp skip_byte(<<>>), do: <<>>
end

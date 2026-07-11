# Membrane.RawAudio



## sample_size/1

Returns how many bytes are needed to store a single sample.

Inlined by the compiler

## frame_size/1

Returns how many bytes are needed to store a single frame.

Inlined by the compiler

## sample_type_float?/1

Determines if the sample values are represented by a floating point number.

Inlined by the compiler.

## sample_type_fixed?/1

Determines if the sample values are represented by an integer.

Inlined by the compiler.

## little_endian?/1

Determines if the sample values are represented by a number in little endian byte ordering.

Inlined by the compiler.

## big_endian?/1

Determines if the sample values are represented by a number in big endian byte ordering.

Inlined by the compiler.

## signed?/1

Determines if the sample values are represented by a signed number.

Inlined by the compiler.

## unsigned?/1

Determines if the sample values are represented by an unsigned number.

Inlined by the compiler.

## sample_to_value/2

Converts one raw sample into its numeric value, interpreting it for given sample format.

Inlined by the compiler.

## value_to_sample/2

Converts value into one raw sample, encoding it with the given sample format.

Inlined by the compiler.

## value_to_sample_check_overflow/2

Same as value_to_sample/2, but also checks for overflow.
Returns {:error, :overflow} if overflow happens.

Inlined by the compiler.

## sample_min/1

Returns minimum sample value for given sample format.

Inlined by the compiler.

## sample_max/1

Returns maximum sample value for given sample format.

Inlined by the compiler.

## silence/1

Returns one 'silent' sample, that is value of zero in given format' sample format.

Inlined by the compiler.

## silence/3

Returns a binary which corresponds to the silence during the given interval
of time in given format' sample format

## Examples:
The following code generates the silence for the given format

    iex> alias Membrane.RawAudio
    iex> format = %RawAudio{sample_rate: 48_000, sample_format: :s16le, channels: 2}
    iex> silence = RawAudio.silence(format, 100 |> Membrane.Time.microseconds())
    <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

## frames_to_bytes/2

Converts frames to bytes in given format.

Inlined by the compiler.

## bytes_to_frames/3

Converts bytes to frames in given format.

Inlined by the compiler.

## time_to_frames/3

Converts time in Membrane.Time units to frames in given format.

Inlined by the compiler.

## frames_to_time/3

Converts frames to time in Membrane.Time units in given format.

Inlined by the compiler.

## time_to_bytes/3

Converts time in Membrane.Time units to bytes in given format.

Inlined by the compiler.

## bytes_to_time/3

Converts bytes to time in Membrane.Time units in given format.

Inlined by the compiler.
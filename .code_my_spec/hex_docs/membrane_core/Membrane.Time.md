# Membrane.Time

Module containing functions needed to perform handling of time.

Membrane always internally uses nanosecond as a time unit. This is how all time
units should represented in the code unless there's a good reason to act
differently.

Please note that Erlang VM may internally use different units and that may
differ from platform to platform. Still, unless you need to perform calculations
that do not touch hardware clock, you should use Membrane units for consistency.

## pretty_duration/1

Checks whether a value is `Membrane.Time.t`.

## inspect/1

Returns string representation of result of `to_code/1`.

## pretty_now/0

Returns current time in pretty format (currently iso8601), as string
Uses `os_time/0` under the hood.

## monotonic_time/0

Returns current monotonic time based on `System.monotonic_time/0`
in `Membrane.Time` units.

## os_time/0

Returns current POSIX time of operating system based on `System.os_time/0`
in `Membrane.Time` units.

This time is not monotonic.

## vm_time/0

Returns current Erlang VM system time based on `System.system_time/0`
in `Membrane.Time` units.

It is the VM view of the `os_time/0`. They may not match in case of time warps.
It is not monotonic.

## from_iso8601!/1

Converts iso8601 string to `Membrane.Time` units.
If `value` is invalid, throws match error.

## to_iso8601/1

Returns time as a iso8601 string.

## from_datetime/1

Converts `DateTime` to `Membrane.Time` units.

## to_datetime/1

Returns time as a `DateTime` struct. TimeZone is set to UTC.

## from_ntp_timestamp/1

Converts NTP timestamp (time since 0h on 1st Jan 1900) into Unix timestamp
(time since 1st Jan 1970) represented in `Membrane.Time` units.

NTP timestamp uses fixed point representation with the integer part in the first 32 bits
and the fractional part in the last 32 bits.

## to_ntp_timestamp/1

Converts the timestamp into NTP timestamp. May introduce small rounding errors.

## native_unit/0

Returns one VM native unit in `Membrane.Time` units.

## native_units/1

Returns given amount of VM native units in `Membrane.Time` units.

## to_native_units/1

Returns time in VM native units. Rounded using Kernel.round/1.

## divide_by_timebase/2

Divides timestamp by a timebase. The result is rounded to the nearest integer.

## Examples:
    iex> timestamp = 10 |> Membrane.Time.seconds()
    iex> timebase = Ratio.new(Membrane.Time.second(), 30)
    iex> Membrane.Time.divide_by_timebase(timestamp, timebase)
    300
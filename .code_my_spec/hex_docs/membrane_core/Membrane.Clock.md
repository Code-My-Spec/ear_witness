# Membrane.Clock

Clock is a Membrane utility that allows elements to measure time according to
a particular clock, which can be e.g. a soundcard hardware clock.

Internally, Clock is a GenServer process that can receive _updates_ (see `t:update_message/0`),
which are messages containing amount of time until the next update.
For example, a sink playing audio to the sound card can send an update before
each write to the sound card buffer (for practical reasons that can be done every
100 or 1000 writes). Although it might be more intuitive to send updates with
the time passed, in practice the described approach turns out to be more convenient,
as it simplifies the first update.

Basing on updates, Clock calculates the `t:ratio/0` of its time to the reference
time. The reference time can be configured with `:time_provider` option. The ratio
is broadcasted (see `t:ratio_message/0`) to _subscribers_ (see `subscribe/2`)
- processes willing to synchronize to the custom clock. Subscribers can adjust
their timers according to received ratio - timers started with
`t:Membrane.Element.Action.start_timer/0` action in elements do it automatically.
Initial ratio is equal to 1, which means that if no updates are received,
Clock is synchronized to the reference time.

## Proxy mode
Clock can work in _proxy_ mode, which means it cannot receive updates, but
it receives ratio from another clock instead, and forwards it to subscribers.
Proxy mode is enabled with `proxy_for: pid` or `proxy: true` (no initial proxy)
option, and the proxy is set/changed using `proxy_for/2`.

## subscribe/2

Subscribes `pid` for receiving `t:ratio_message/0` messages from the clock.

This function can be called multiple times from the same process. To unsubscribe,
`unsubscribe/2` should be called the same amount of times. The subscribed pid
always receives one message, regardless of how many times it called `subscribe/2`.

## unsubscribe/2

Unsubscribes `pid` from receiving `t:ratio_message/0` messages from the clock.

For unsubscription to take effect, `unsubscribe/2` should be called the same
amount of times as `subscribe/2`.

## proxy_for/2

Sets a new proxy clock to `clock_to_proxy_for`.
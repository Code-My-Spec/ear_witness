# Membrane.LiveAudioMixer

This element performs audio mixing for live streams.

Live Audio Mixer starts to mix audio after the first input pad is added or, if `latency` option is set to `nil`, when `start_mixing` notification is send.
From this point, the mixer will produce an audio until `:schedule_eos` notification and `:end_of_stream` are received on all input pads.

Mixer mixes only raw audio (PCM), so some parser may be needed to precede it in pipeline.

## Notifications

- `:schedule_eos` -  mixer will send `end_of_stream` when it processes all input streams.
  After sending `:schedule_eos` mixer will raise if it gets a new input pad.

- {`:start_mixing`, latency} - mixer will start mixing audio after latency (non_neg_integer()).
  Audio that will come before the notification will be buffered.

Input pads can have offset - it tells how much timestamps differ from mixer time.
Setting offset to `:live` adjusts the offset to the current mixer timer.

```elixir
get_child(:a_new_input)

# Choose one:
|> via_in(:input, options: [offset: 0]) # Identical to not setting the option
|> via_in(:input, options: [offset: 1_000])
|> via_in(:input, options: [offset: :live])

|> child(:livemixer, Membrane.LiveAudioMixer)
```
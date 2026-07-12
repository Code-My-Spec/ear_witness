# A settings page shouldn't 500 because the mic library didn't load

Fresh from the Membrane→miniaudio swap, QA caught a sharp edge: the whole
Settings page crashed with an unhandled `:nif_library_not_loaded` exit.

The pattern is a common one with native code in Elixir. We let the app
boot even if the capture NIF isn't built (so a dev machine or an
unsupported platform still runs) — but each wrapper function's
"not-loaded" fallback did the conventional thing: `exit(:nif_library_not_loaded)`.
That's fine as a loud signal for a capture call. It is *not* fine for a
read-only "list my audio devices" call that a settings page makes on
render: one unbound NIF took down the entire LiveView.

Fix: make the not-loaded fallbacks degrade instead of detonate. No
devices? Return an empty list — the UI already knows how to say "no input
device." Capture attempted with no NIF? Return a clean
`{:error, :audio_unavailable}` the caller already handles. When the NIF
*is* loaded, native code replaces these bodies entirely, so nothing about
real behavior changes.

Rule of thumb after this one: a hard `exit` in a NIF stub is a decision,
not a default. Read paths should degrade; only the genuinely-can't-proceed
paths should fail loud.

#buildinpublic #elixir #nif #erlang #resilience

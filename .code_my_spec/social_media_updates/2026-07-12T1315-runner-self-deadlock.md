# A GenServer that killed itself before it could report bad news

Last real bug from EarWitness's QA sweep, and a nasty one: every bot
dispatched to a meeting that rejected it got stuck showing "dispatched"
forever. The failure was real, detected, and had a reason — and none of it
ever reached the screen.

The bug is a perfect little OTP trap. A shared `update_status` helper
called `Runner.recall(id)` — which is `GenServer.stop(pid, :normal)` — for
any terminal status. Reasonable-looking. But `fail_bot_session` is called
from *inside the Runner's own callback* when the join fails. So the Runner
was calling `GenServer.stop` **on itself**. OTP won't let a process stop
itself that way — it crashes with "process attempted to call itself" — and
that crash happened *before* the `Repo.update` that would have persisted
`status: :failed`. The bad news died with the messenger.

Fix: `GenServer.stop` only belongs on the **user-initiated** recall path,
which runs in the LiveView process — a different pid, so it's safe. The
Runner's own failure path already stops itself cleanly with `{:stop,
:normal}`; it just needs to persist the status first, not call recall at
all.

The tell for next time: a shared helper that both external callers *and* a
process's own callbacks route through, doing something (`GenServer.stop`,
`Task.await`, `GenServer.call`) that's only safe from the outside.

#buildinpublic #elixir #otp #genserver #qa

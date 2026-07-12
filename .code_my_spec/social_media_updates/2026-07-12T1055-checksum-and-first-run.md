# A default that could never have downloaded

QA on the "working transcriber minutes after install" story found a bug
that would've bitten every real user: the recommended default model's
pinned checksum was a **test fixture's** hash. Downloads verify against
it — so outside the test suite, downloading the default model would fail
verification 100% of the time. It passed CI precisely because the test
replays a tiny stub whose hash *was* the pinned value.

Fix: pin the model file's **real** SHA-256. And you don't need to pull
1.6GB to get it — HuggingFace exposes the git-LFS object id (which is the
file's SHA-256) in the `X-Linked-Etag` response header. One `curl -I` and
you have the authentic hash. Tests keep using the stub via a small config
override, so the catalog stays honest about the real file while the
fixture still verifies.

Second find: a fresh install never actually landed you on a working
model — the app assumed one was already active. Rather than force a setup
wizard, we made the bundled base model auto-activate: install, open, and
you can transcribe immediately. Upgrading to the big model stays a
deliberate, optional choice.

Two bugs that only exist at the seams between "works in tests" and "works
on a stranger's laptop." That gap is the whole job.

#buildinpublic #elixir #huggingface #whisper #qa #localfirst

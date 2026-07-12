# Search that actually finds what you said (and not what you didn't)

QA on EarWitness's library-wide search (story 864 — "find anything ever
said") turned up two bugs that both hit the exact workflow the feature
promises: type a phrase, then narrow it down.

**The disappearing search.** Type a query, reach for the speaker filter a
beat too soon, and the whole thing blanked — query box empty, results
gone. Classic LiveView foot-gun: the search box and the filters were two
separate forms firing independent change events. A filter change that
landed while your last keystroke was still in flight ran the search with
a stale (empty) query, then patched your text right back out of the box.
Fix: one form. Every change now carries the full state — query plus
filters — so editing one field can never wipe another. Added a small
debounce for good measure.

**"witness" matched "with".** Searching for *witness* surfaced ten
segments that only contained the word *with*. Root cause was a two-part
collision: the FTS5 index used the Porter stemmer, which chops *witness*
down to the stem *wit*, and the query layer wildcards every term — so
*wit\** happily matched *with*. Dropping Porter (unicode61 tokenizer,
prefix matching retained) kills the false positives while still finding
forward inflections: *meeting* still finds *meetings*. Shipped as an
in-place index rebuild, no reindex required.

Both verified green across the story's six BDD specs. Search should feel
boringly correct now — which is exactly the goal.

#buildinpublic #elixir #phoenix #liveview #sqlite #fts5 #localfirst

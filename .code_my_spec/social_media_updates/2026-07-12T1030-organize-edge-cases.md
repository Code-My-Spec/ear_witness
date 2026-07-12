# The bugs live one click past the happy path

Story 865 ("keep recordings organized") passed all six acceptance
criteria on the real app — and then QA kept poking and found two bugs
that only show up at the edges.

**Unchecking the last case did nothing.** A recording can belong to
several cases via a checkbox group. Uncheck one of several — fine. Uncheck
the *last* one — the box snapped right back and the membership stuck.
Classic HTML gotcha: a checkbox group with nothing checked submits *no
field at all*, so the LiveView event arrived with no `recording` key, the
handler's pattern match missed, and the event silently died. Fix: match
the event loosely and default the missing map, so "remove from every
case" actually removes.

The tell: our BDD specs passed this the whole time — because the test
form helper always includes the field. Only a real browser omits an
all-unchecked group. Good reminder that live QA earns its keep.

**Blank case name, blank response.** Submitting "create case" with an
empty name did nothing and said nothing — the error branch was a no-op.
Now it surfaces "Case name can't be blank," same as the import form
already did.

Both fixed and verified. Small bugs, but they're exactly the kind that
make software feel broken. #buildinpublic #elixir #liveview #qa

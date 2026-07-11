# Zarex

Filename sanitization for Elixir. This is useful when you generate filenames for downloads from user input.

Zarex takes a given filename and normalizes, filters and truncates it.

It deletes the bad stuff but leaves unicode characters in place, so users can
use whatever alphabets they want to. Zarex also doesn't remove whitespace—instead,
any sequence of whitespace that is 1 or more characters in length is collapsed to a
single space. Filenames are truncated so that they are at maximum 255 bytes long.

### Examples

    iex> Zarex.sanitize("  whatēver//wëird:user:înput:")
    "whatēverwëirduserînput"

    iex> Zarex.sanitize("<", filename_fallback: "file")
    "file"

## sanitize/2

Takes a given filename and normalizes, filters and truncates it.

  If extra breathing room is required (for example to add your own filename
  extension later), you can leave extra room with the padding parameter
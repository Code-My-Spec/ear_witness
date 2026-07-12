# Anubis.Server.Component.URITemplate

RFC 6570 URI Template parser and matcher (Levels 1 and 2).

Supported expressions:

| Form        | Level | Description                          |
|-------------|-------|--------------------------------------|
| `{var}`     | 1     | Simple expansion (excludes `/?#`)    |
| `{+var}`    | 2     | Reserved expansion (allows reserved) |
| `{#var}`    | 2     | Fragment expansion (literal `#`)     |

Level 3 (multi-var, label, path-segment, query) and Level 4 (prefix, explode)
are not supported.

## Examples

    iex> {:ok, t} = URITemplate.parse("file:///{path}")
    iex> URITemplate.match(t, "file:///docs/readme.md")
    {:ok, %{"path" => "docs/readme.md"}}

    iex> {:ok, t} = URITemplate.parse("db:///{table}/{id}")
    iex> URITemplate.match(t, "db:///users/42")
    {:ok, %{"table" => "users", "id" => "42"}}

    iex> {:ok, t} = URITemplate.parse("file:///{+path}")
    iex> URITemplate.match(t, "file:///deep/nested/file.md")
    {:ok, %{"path" => "deep/nested/file.md"}}

    iex> {:ok, t} = URITemplate.parse("/page{#section}")
    iex> URITemplate.match(t, "/page#intro")
    {:ok, %{"section" => "intro"}}

## parse/1

Parses an RFC 6570 (Level 1 + Level 2) URI template string.

Returns `{:ok, %URITemplate{}}` on success, `{:error, reason}` otherwise.

## parse!/1

Same as `parse/1` but raises `ArgumentError` on failure.

## match/2

Matches a URI against a parsed template (or template string).

Returns `{:ok, vars_map}` on a match where keys are variable names and
values are the percent-decoded substrings, or `:error` if the URI does not
match the template.
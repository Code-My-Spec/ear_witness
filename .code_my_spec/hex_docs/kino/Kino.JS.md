# Kino.JS



## new/3

Instantiates a static JavaScript kino defined by `module`.

The given `data` is passed directly to the JavaScript side during
initialization.

## Options

  * `:export` - a function called to export the given kino to Markdown.
    See the "Export" section below

## Export

The output can optionally be exported in notebook source by specifying
an `:export` function. The function receives the `data` as an argument
and should return a tuple `{info_string, payload}`. `info_string`
is used to annotate the Markdown code block where the output is
persisted. `payload` is the value persisted in the code block. The
value is automatically serialized to JSON, unless it is already a
string.

For example:

    data = "graph TD;A-->B;"
    Kino.JS.new(__MODULE__, data, export: fn data -> {"mermaid", data} end)

Would be rendered as the following Live Markdown:

````markdown
```mermaid
graph TD;A-->B;
```
````

> #### Export function {: .info}
>
> You should prefer to use the `data` argument for computing the
> export payload. However, if it cannot be inferred from `data`,
> you should just reference the original value. Do not put additional
> fields in `data`, just to use it for export, given those fields
> are sent to the client.
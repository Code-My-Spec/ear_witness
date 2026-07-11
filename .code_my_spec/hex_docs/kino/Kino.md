# Kino



## render/1

Renders the given term as cell output.

This effectively allows any Livebook cell to have multiple
evaluation results.

## inspect/2

Inspects the given term as cell output.

This works essentially the same as `IO.inspect/2`, except it
always produces colored text and respects the configuration
set with `configure/1`.

Opposite to `render/1`, it does not attempt to render the given
term as a kino.

## configure/1

Configures Kino.

The supported options are:

  * `:inspect`

They are discussed individually in the sections below.

## Inspect

A keyword list containing inspect options used for printing
usual evaluation results. Defaults to pretty formatting with
a limit of 50 entries.

To show more entries, you configure a higher limit:

    Kino.configure(inspect: [limit: 200])

You can also show all entries by setting the limit to `:infinity`,
but keep in mind that for large data structures it is memory-expensive
and is not an advised configuration in this case. Instead prefer
the use of `IO.inspect/2` with `:infinity` limit when needed.

See `Inspect.Opts` for the full list of options.

## async_listen/2

Same as `listen/2`, except each event is processed concurrently.

## nothing/0

Returns a special value that results in no visible output.

## Examples

This is especially handy when you wish to suppress the default output
of a cell. For instance, a cell containing this would normally result
in verbose response output:

    resp = Req.get!("https://example.org")

That output can be suppressed by appending a call to `nothing/0`:

    resp = Req.get!("https://example.org")
    Kino.nothing()

## start_child/1

Starts a process under the Kino supervisor.

The process is automatically terminated when the current process
terminates or the current cell reevaluates.

If you want to terminate the started process, use
`terminate_child/1`. If you terminate the process manually,
the Kino supervisor might restart it if the child's `:restart`
strategy says so.

> #### Nested start {: .warning}
>
> It is not possible to use `start_child/1` while initializing
> another process started this way. In other words, you generally
> cannot call `start_child/1` inside callbacks such as `c:GenServer.init/1`
> or `c:Kino.JS.Live.init/2`. If you do that, starting the process
> will block forever.
>
> On creation, many kinos use `start_child/1` underneath, which means
> that you cannot use functions such as `Kino.DataTable.new/1` in
> `c:GenServer.init/1`. If you need to do that, you must either
> create the kinos beforehand and pass in the `GenServer` argument,
> or create them in `c:GenServer.handle_continue/2`.

## start_child!/1

Similar to `start_child/2` but returns the new pid or raises an error.

## terminate_child/1

Terminates a child started with `start_child/1`.

Returns `:ok` if the child was found and terminated, or
`{:error, :not_found}` if the child was not found.

## tmp_dir/0

Returns a temporary directory that gets removed when the runtime
terminates.

## beam_paths/0

Returns the directories that contain `.beam` files for modules
defined in the notebook.

## recompile/0

Recompiles dependencies.

Once you have installed dependencies with `Mix.install/1`, this will
recompile any outdated path dependencies declared during the install.

> #### Reproducibility {: .warning}
>
> Keep in mind that recompiling dependency modules is **not** going
> to mark any cells as stale. This means that the given notebook
> state may no longer be reproducible. This function is meant as a
> utility when prototyping alongside a Mix project.
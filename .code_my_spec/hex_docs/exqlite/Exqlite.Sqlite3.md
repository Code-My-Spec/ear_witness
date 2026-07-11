# Exqlite.Sqlite3

The interface to the NIF implementation.

## open/2

Opens a new sqlite database at the Path provided.

`path` can be `":memory"` to keep the sqlite database in memory.

## Options

  * `:mode` - controls the flags for sqlite3_open_v2 (see
    https://www.sqlite.org/c3ref/c_open_autoproxy.html). Defaults to
    `[:readwrite, :create]` (opens for reading and writing and creates the
    file if it does not exist).

    Single modes are permitted:
    - `:readwrite` - read/write to the database. Does not create the database
      if it is not present. Use in combination with `:create` to create the
      database if it does not exist.
    - `:readonly` - read-only (file must exist).
    - `:create` - creates the database if it does not exist.

    Combinations are permitted:
    - `[:readwrite, :create]` - read/write + create if needed. This is the
      default if not specified.
    - `[:readonly, :nomutex]`

    Note: `[:readwrite, :nomutex]` is not recommended.

## close/1

Closes the database and releases any underlying resources.

## interrupt/1

Interrupt a long-running query.

This calls `sqlite3_interrupt()` and is effective while SQLite is actively
executing a statement. It does not wake the custom busy handler while the
connection is sleeping and waiting on a lock. Use `cancel/1` when you need
to abort both statement execution and busy waits.

> #### Warning {: .warning}
> If you are going to interrupt a long running process, it is unsafe to call
> `close/1` immediately after. You run the risk of undefined behavior. This
> is a limitation of the sqlite library itself. Please see the documentation
> https://www.sqlite.org/c3ref/interrupt.html for more information.
>
> If close must be called after, it is best to put a short sleep in order to
> let sqlite finish doing its book keeping.

## set_busy_timeout/2

Set the busy timeout in milliseconds without destroying the custom busy handler.

Unlike `PRAGMA busy_timeout` (which internally calls `sqlite3_busy_timeout()`
and replaces any custom handler), this function only updates the timeout value
that the custom busy handler reads. This preserves the ability to cancel
busy waits via `cancel/1`.

A timeout of `0` makes lock contention fail immediately with `SQLITE_BUSY`.
Larger values let SQLite keep retrying until the timeout expires or the wait
is cancelled.

This is the low-level API behind the `:busy_timeout` connection option.

## set_progress_handler_steps/2

Configure how often SQLite invokes the progress handler during statement execution.

The default is `1000` virtual machine steps.

Values less than `1` disable the progress handler. Larger values reduce the
overhead of cancellation checks at the cost of slower response to `cancel/1`
and `interrupt/1` while a query is running.

This is the low-level API behind the `:progress_handler_steps` connection
option.

## cancel/1

Cancel a running query: wake any busy handler sleep and interrupt VDBE execution.

This is a superset of `interrupt/1` — it sets a cancel flag that the busy and
progress handlers observe, and also calls `sqlite3_interrupt()`. After a
cancel, the connection can be reused normally.

Use this when a query might be blocked either inside SQLite bytecode
execution or inside the busy handler waiting for a lock.

## execute/2

Executes an sql script. Multiple stanzas can be passed at once.

## changes/1

Get the number of changes recently.

**Note**: If triggers are used, the count may be larger than expected.

See: https://sqlite.org/c3ref/changes.html

## reset/1

Resets a prepared statement.

See: https://sqlite.org/c3ref/reset.html

## bind_parameter_count/1

Returns number of SQL parameters in a prepared statement.

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT ?, ?")
    iex> Sqlite3.bind_parameter_count(stmt)
    2

## bind/2

Resets a prepared statement and binds values to it.

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT ?, ?, ?, ?, ?")
    iex> Sqlite3.bind(stmt, [42, 3.14, "Alice", {:blob, <<0, 0, 0>>}, nil])
    iex> Sqlite3.step(conn, stmt)
    {:row, [42, 3.14, "Alice", <<0, 0, 0>>, nil]}

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT :42, @pi, $name, @blob, :null")
    iex> Sqlite3.bind(stmt, %{":42" => 42, "@pi" => 3.14, "$name" => "Alice", :"@blob" => {:blob, <<0, 0, 0>>}, ~c":null" => nil})
    iex> Sqlite3.step(conn, stmt)
    {:row, [42, 3.14, "Alice", <<0, 0, 0>>, nil]}

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT ?")
    iex> Sqlite3.bind(stmt, [42, 3.14, "Alice"])
    ** (ArgumentError) expected 1 arguments, got 3

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT ?, ?")
    iex> Sqlite3.bind(stmt, [42])
    ** (ArgumentError) expected 2 arguments, got 1

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT ?")
    iex> Sqlite3.bind(stmt, [:erlang.list_to_pid(~c"<0.0.0>")])
    ** (ArgumentError) unsupported type: #PID<0.0.0>

## shrink_memory/1

Causes the database connection to free as much memory as it can. This is
useful if you are on a memory restricted system.

## serialize/2

Serialize the contents of the database to a binary.

## deserialize/3

Disconnect from database and then reopen as an in-memory database based on
the serialized binary.

## release/2

Once finished with the prepared statement, call this to release the underlying
resources.

This should be called whenever you are done operating with the prepared statement. If
the system has a high load the garbage collector may not clean up the prepared
statements in a timely manner and causing higher than normal levels of memory
pressure.

If you are operating on limited memory capacity systems, definitely call this.

## enable_load_extension/2

Allow loading native extensions.

## set_update_hook/2

Send data change notifications to a process.

Each time an insert, update, or delete is performed on the connection provided
as the first argument, a message will be sent to the pid provided as the second argument.

The message is of the form: `{action, db_name, table, row_id}`, where:

  * `action` is one of `:insert`, `:update` or `:delete`
  * `db_name` is a string representing the database name where the change took place
  * `table` is a string representing the table name where the change took place
  * `row_id` is an integer representing the unique row id assigned by SQLite

## Restrictions

  * There are some conditions where the update hook will not be invoked by SQLite.
    See the documentation for [more details](https://www.sqlite.org/c3ref/update_hook.html)
  * Only one pid can listen to the changes on a given database connection at a time.
    If this function is called multiple times for the same connection, only the last pid will
    receive the notifications
  * Updates only happen for the connection that is opened. For example, there
    are two connections A and B. When an update happens on connection B, the
    hook set for connection A will not receive the update, but the hook for
    connection B will receive the update.

## set_authorizer/2

Set an authorizer that denies specific SQL operations.

Accepts a list of action atoms to deny. Any SQL statement that triggers a
denied action will fail with a "not authorized" error during preparation.

Pass an empty list to clear the authorizer.

## Action atoms

`:attach`, `:detach`, `:pragma`, `:insert`, `:update`, `:delete`,
`:create_table`, `:drop_table`, `:create_index`, `:drop_index`,
`:create_trigger`, `:drop_trigger`, `:create_view`, `:drop_view`,
`:alter_table`, `:reindex`, `:analyze`, `:function`, `:savepoint`,
`:transaction`, `:read`, `:select`, `:recursive`,
`:create_temp_table`, `:create_temp_index`, `:create_temp_trigger`,
`:create_temp_view`, `:drop_temp_table`, `:drop_temp_index`,
`:drop_temp_trigger`, `:drop_temp_view`, `:create_vtable`, `:drop_vtable`

## Examples

    # Block ATTACH and DETACH (prevent cross-database reads)
    :ok = Sqlite3.set_authorizer(conn, [:attach, :detach])

    # Clear the authorizer
    :ok = Sqlite3.set_authorizer(conn, [])

## set_log_hook/1

Send log messages to a process.

Each time a message is logged in SQLite a message will be sent to the pid provided as the argument.

The message is of the form: `{:log, rc, message}`, where:

  * `rc` is an integer [result code](https://www.sqlite.org/rescode.html) or an [extended result code](https://www.sqlite.org/rescode.html#extrc)
  * `message` is a string representing the log message

See [`SQLITE_CONFIG_LOG`](https://www.sqlite.org/c3ref/c_config_covering_index_scan.html) and
["The Error And Warning Log"](https://www.sqlite.org/errlog.html) for more details.

## Restrictions

  * Only one pid can listen to the log messages at a time.
    If this function is called multiple times, only the last pid will
    receive the notifications

## bind_text/3

Binds a text value to a prepared statement.

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT ?")
    iex> Sqlite3.bind_text(stmt, 1, "Alice")
    :ok

## bind_blob/3

Binds a blob value to a prepared statement.

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT ?")
    iex> Sqlite3.bind_blob(stmt, 1, <<0, 0, 0>>)
    :ok

## bind_integer/3

Binds an integer value to a prepared statement.

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT ?")
    iex> Sqlite3.bind_integer(stmt, 1, 42)
    :ok

## bind_float/3

Binds a float value to a prepared statement.

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT ?")
    iex> Sqlite3.bind_float(stmt, 1, 3.14)
    :ok

## bind_null/2

Binds a null value to a prepared statement.

    iex> {:ok, conn} = Sqlite3.open(":memory:", [:readonly])
    iex> {:ok, stmt} = Sqlite3.prepare(conn, "SELECT ?")
    iex> Sqlite3.bind_null(stmt, 1)
    :ok
# Exqlite.Connection

This module implements connection details as defined in DBProtocol.

## Attributes

- `db` - The sqlite3 database reference.
- `path` - The path that was used to open.
- `transaction_status` - The status of the connection. Can be `:idle` or `:transaction`.

## Unknowns

- How are pooled connections going to work? Since sqlite3 doesn't allow for
  simultaneous access. We would need to check if the write ahead log is
  enabled on the database. We can't assume and set the WAL pragma because the
  database may be stored on a network volume which would cause potential
  issues.

Notes:
  - we try to closely follow structure and naming convention of myxql.
  - sqlite thrives when there are many small conventions, so we may not implement
    some strategies employed by other adapters. See https://sqlite.org/np1queryprob.html

## connect/1

Initializes the Ecto Exqlite adapter.

For connection configurations we use the defaults that come with SQLite3, but
we recommend which options to choose. We do not default to the recommended
because we don't know what your environment is like.

Allowed options:

  * `:database` - The path to the database. In memory is allowed. You can use
    `:memory` or `":memory:"` to designate that.
  * `:default_transaction_mode` - one of `deferred` (default), `immediate`,
    or `exclusive`. If a mode is not specified in a call to `Repo.transaction/2`,
    this will be the default transaction mode.
  * `:mode` - controls the sqlite3_open_v2 flags. Defaults to
    `[:readwrite, :create]` (read/write + create if needed). Use
    `:readwrite` for read/write without create, `:readonly` for read-only, or
    a list such as `[:readwrite, :create]` or `[:readonly, :nomutex]`.
    Note: `[:readwrite, :nomutex]` is not recommended.
  * `:journal_mode` - Sets the journal mode for the sqlite connection. Can be
    one of the following `:delete`, `:truncate`, `:persist`, `:memory`,
    `:wal`, or `:off`. Defaults to `:delete`. It is recommended that you use
    `:wal` due to support for concurrent reads. Note: `:wal` does not mean
    concurrent writes.
  * `:temp_store` - Sets the storage used for temporary tables. Default is
    `:default`. Allowed values are `:default`, `:file`, `:memory`. It is
    recommended that you use `:memory` for storage.
  * `:synchronous` - Can be `:extra`, `:full`, `:normal`, or `:off`. Defaults
    to `:normal`.
  * `:foreign_keys` - Sets if foreign key checks should be enforced or not.
    Can be `:on` or `:off`. Default is `:on`.
  * `:cache_size` - Sets the cache size to be used for the connection. This is
    an odd setting as a positive value is the number of pages in memory to use
    and a negative value is the size in kilobytes to use. Default is `-2000`.
    It is recommended that you use `-64000`.
  * `:cache_spill` - The cache_spill pragma enables or disables the ability of
    the pager to spill dirty cache pages to the database file in the middle of
    a transaction. By default it is `:on`, and for most applications, it
    should remain so.
  * `:case_sensitive_like`
  * `:auto_vacuum` - Defaults to `:none`. Can be `:none`, `:full` or
    `:incremental`. Depending on the database size, `:incremental` may be
    beneficial.
  * `:locking_mode` - Defaults to `:normal`. Allowed values are `:normal` or
    `:exclusive`. See [sqlite documentation][1] for more information.
  * `:secure_delete` - Defaults to `:off`. If enabled, it will cause SQLite3
    to overwrite records that were deleted with zeros.
  * `:wal_auto_check_point` - Sets the write-ahead log auto-checkpoint
    interval. Default is `1000`. Setting the auto-checkpoint size to zero or a
    negative value turns auto-checkpointing off.
  * `:busy_timeout` - Sets the busy timeout in milliseconds for a connection.
    Default is `2000`. This is applied via `Exqlite.Sqlite3.set_busy_timeout/2`
    so Exqlite keeps its custom busy handler installed. Set it to `0` if you
    want lock contention to fail immediately instead of sleeping and retrying.
  * `:progress_handler_steps` - Controls how often SQLite runs the progress
    handler used for query cancellation. Default is `1000`. Values less than
    `1` disable the progress handler, which reduces per-op overhead but means
    `interrupt/1` and `cancel/1` only take effect once SQLite returns from the
    current call.
  * `:chunk_size` - The chunk size for bulk fetching. Defaults to `50`.
  * `:key` - Optional key to set during database initialization. This PRAGMA
    is often used to set up database level encryption.
  * `:journal_size_limit` - The size limit in bytes of the journal.
  * `:soft_heap_limit` - The size limit in bytes for the heap limit.
  * `:hard_heap_limit` - The size limit in bytes for the heap.
  * `:custom_pragmas` - A list of custom pragmas to set on the connection, for example to configure extensions.
  * `:serialized` - A SQLite database which was previously serialized, to load into the database after connection.
  * `:load_extensions` - A list of paths identifying extensions to load. Defaults to `[]`.
    The provided list will be merged with the global extensions list, set on `:exqlite, :load_extensions`.
    Be aware that the path should handle pointing to a library compiled for the current architecture.
    Example configuration:

    ```
      arch_dir =
        System.cmd("uname", ["-sm"])
        |> elem(0)
        |> String.trim()
        |> String.replace(" ", "-")
        |> String.downcase() # => "darwin-arm64"

      config :myapp, arch_dir: arch_dir

      # global
      config :exqlite, load_extensions: [ "./priv/sqlite/#{arch_dir}/rotate" ]

      # per connection in a Phoenix app
      config :myapp, Myapp.Repo,
        database: "path/to/db",
        load_extensions: [
          "./priv/sqlite/#{arch_dir}/vector0",
          "./priv/sqlite/#{arch_dir}/vss0"
        ]
    ```
  * `:before_disconnect` - A function to run before disconnect, either a
    2-arity fun or `{module, function, args}` with the close reason and
    `t:Exqlite.Connection.t/0` prepended to `args` or `nil` (default: `nil`)

For more information about the options above, see [sqlite documentation][1]

## Cancellation notes

Exqlite exposes two low-level cancellation APIs:

  * `Exqlite.Sqlite3.interrupt/1` interrupts SQLite while it is executing a
    statement.
  * `Exqlite.Sqlite3.cancel/1` is stronger: it also wakes the custom busy
    handler if the connection is sleeping while waiting on a lock.

Connection teardown uses `cancel/1` so DBConnection timeouts and disconnects
can break out of both long-running statements and busy waits.

[1]: https://www.sqlite.org/pragma.html

## handle_begin/2

Begin a transaction.

For full info refer to sqlite docs: https://sqlite.org/lang_transaction.html

Note: default transaction mode is DEFERRED.

## handle_close/3

Close a query prepared by `handle_prepare/3` with the database. Return
`{:ok, result, state}` on success and to continue,
`{:error, exception, state}` to return an error and continue, or
`{:disconnect, exception, state}` to return an error and disconnect.

This callback is called in the client process.
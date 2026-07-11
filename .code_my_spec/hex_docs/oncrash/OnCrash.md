# OnCrash

Convinence module to wrap a monitor and call a function when a process ends. Useful to setp cleanup tasks on process shutdown.

```elixir
worker = spawn(fn ->
  OnCrash.call(fn -> cleanup() end)
  do_the_work()
end)
```

OnCrash is always called when the process finished. So it will aso run the callback when the process ends with a `:normal` exit
reason. To have exit reason specific code a fun with a `reason` parameter can be specified:

```elixir
worker = spawn(fn ->
  OnCrash.call(fn reason ->
    if reason != :normal do
      IO.puts("Worker died with reason #{inspect(reason)}")
      cleanup()
    end
  end)
  do_the_work()
end)
```

## call/2

Registers the given fun as callback to be executed once the process exits.
  pid is provided it binds to the given process. Otherwise it binds to the current
  executing process.

  ```elixir
  worker = spawn(fn ->
    OnCrash.call(fn -> cleanup() end)
    do_the_work()
  end)
  ```

  And to differentiate

  ```elixir
  worker = spawn(fn ->
    OnCrash.call(fn reason ->
      case reason do
        # On raise "oh_no!"
        {%RuntimeError{message: "oh_no!"}, _backtrace} -> you_code_here()
        # On throw(:oh_no!)
        {{:nocatch, :oh_no!}, _backtrace} -> you_code_here()
        # On exit(:oh_no!)
        :oh_no! -> you_code_here()
      end
      cleanup()
    end)
    do_the_work()
  end)
  ```
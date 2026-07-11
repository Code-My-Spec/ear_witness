# ExSni



## is_supported?/0

Returns true if there is a StatusNotifierWatcher available
on the Session Bus.

## is_supported?/1

Returns true if there is a StatusNotifierWatcher available
on the Session Bus.
- sni_pid - The pid of the ExSni Supervisor

## get_supported/1

Returns {:ok, sni_pid} if there is a StatusNotifierWatcher available
on the Session Bus. Returns {:error, reason} otherwise.
- sni_pid - The pid of the ExSni Supervisor
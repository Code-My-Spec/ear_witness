# MixTestWatch.PortRunner

Run the tasks in a new OS process via ports

## run/1

Run tests using the runner from the config.

## build_tasks_cmds/1

Build a shell command that runs the desired mix task(s).

Colour is forced on- normally Elixir would not print ANSI colours while
running inside a port.
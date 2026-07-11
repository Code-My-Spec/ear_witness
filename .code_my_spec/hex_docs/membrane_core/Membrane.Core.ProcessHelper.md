# Membrane.Core.ProcessHelper



## notoelo/2

This is a hack to exit with a custom reason, but without having GenServer
exit logs occurring when the exit reason is neither :normal, :shutdown
nor {:shutdown, reason}
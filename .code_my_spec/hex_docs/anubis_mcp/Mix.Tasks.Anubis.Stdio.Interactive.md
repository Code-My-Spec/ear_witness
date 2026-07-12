# Mix.Tasks.Anubis.Stdio.Interactive

Mix task to test the STDIO transport implementation, interactively sending commands.

## Options

* `--command` / `-c` - Command to execute for the STDIO transport (default: "mcp")
* `--args` / `-a` - Comma-separated arguments for the command (default: "run,priv/dev/echo/index.py")
* `--env` / `-e` - Environment variable to pass (repeatable: `--env KEY=VALUE --env OTHER=VAL`)
* `--cwd` - Working directory for the spawned process
* `--verbose` / `-v` - Verbosity level (repeatable for more verbosity)

## Examples

    # Basic usage
    mix stdio.interactive -c npx -a "@modelcontextprotocol/server-everything"

    # With environment variables
    mix stdio.interactive -c my-server --env DEBUG=1 --env LOG_LEVEL=debug

    # With working directory
    mix stdio.interactive -c ./my-server --cwd /path/to/project

    # Combined
    mix stdio.interactive -c node --args "server.js" --cwd /tmp/myapp --env NODE_ENV=production
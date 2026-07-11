# Mix.Tasks.Sass

Invokes sass with the given args.

Usage:

    $ mix sass TASK_OPTIONS PROFILE SASS_ARGS

Example:

    $ mix sass default assets/css/app.scss priv/static/assets/app.css

If dart-sass is not installed, it is automatically downloaded.
Note the arguments given to this task will be appended
to any configured arguments.

## Options

  * `--runtime-config` - load the runtime configuration before executing
    command

Note flags to control this Mix task must be given before the profile:

    $ mix sass --runtime-config default assets/css/app.scss
# DartSass

DartSass is a installer and runner for [Sass](https://sass-lang.com/guide).

## Profiles

You can define multiple configuration profiles. By default, there is a
profile called `:default` which you can configure its args, current
directory and environment:

    config :dart_sass,
      version: "1.61.0",
      default: [
        args: ~w(css/app.scss ../priv/static/assets/app.css),
        cd: Path.expand("../assets", __DIR__)
      ]

## Dart Sass configuration

There are two global configurations for the `dart_sass` application:

  * `:version` - the expected Sass version.

  * `:path` - the path to the Sass executable. By default
    it is automatically downloaded and placed inside the `_build` directory
    of your current app. Note that if your system architecture requires a
    separate Dart VM executable to run, then `:path` should be defined as a
    list of absolute paths.

Overriding the `:path` is not recommended, as we will automatically
download and manage `sass` for you. But in case you can't download
it (for example, the GitHub releases are behind a proxy), you may want to
set the `:path` to a configurable system location.

For instance, you can install `sass` globally with `npm`:

    $ npm install -g sass

Then the executable will be at:

    NPM_ROOT/sass/sass.js

Where `NPM_ROOT` is the result of `npm root -g`.

Once you find the location of the executable, you can store it in a
`MIX_SASS_PATH` environment variable, which you can then read in
your configuration file:

    config :dart_sass, path: System.get_env("MIX_SASS_PATH")

Note that overriding `:path` disables version checking.

## configured_version/0

Returns the configured Sass version.

## config_for!/1

Returns the configuration for the given profile.

Returns nil if the profile does not exist.

## bin_paths/0

Returns the path to the `dart` VM executable and to the `sass` executable.

## bin_version/0

Returns the version of the Sass executable.

Returns `{:ok, version_string}` on success or `:error` when the executable
is not available.

## run/2

Runs the given command with `args`.

The given args will be appended to the configured args.
The task output will be streamed directly to stdio. It
returns the status of the underlying call.

## install_and_run/2

Installs, if not available, and then runs `sass`.

Returns the same as `run/2`.

## install/0

Installs Sass with `configured_version/0`.
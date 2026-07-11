# Toml.Provider

This module provides an implementation of both the Distilery and Elixir
config provider behaviours, so that TOML files can be used for configuration
in releases.

## Distillery Usage

Add the following to your `rel/config.exs`

    release :myapp do
      # ...snip...
      set config_providers: [
        {Toml.Provider, [path: "${XDG_CONFIG_DIR}/myapp.toml", transforms: [...]]}
      ]
    end

## Elixir Usage

    config_providers: [
      {Toml.Provider, [
        path: {:system, "XDG_CONFIG_DIR", "myapp.toml"},
        transforms: [...]
      ]}
    ]

This will result in `Toml.Provider` being invoked during boot, at which point it
will evaluate the given path and read the TOML file it finds. If one is not
found, or is not accessible, the provider will raise an error, and the boot
sequence will terminate unsuccessfully. If it succeeds, it persists settings in
the file to the application environment (i.e. you access it via
`Application.get_env/2`).

The config provider expects a certain format to the TOML file, namely that
keys at the root of the document are tables which correspond to applications
which need to be configured. If it encounters keys at the root of the document
which are not tables, they are ignored.

## Options

The same options that `Toml.parse/2` accepts are able to be provided to `Toml.Provider`,
but there are two main differences:

  * `:path` (required) - sets the path to the TOML file to load config from
  * `:keys` - defaults to `:atoms`, but can be set to `:atoms!` if desired, all other
    key types are ignored, as it results in an invalid config structure
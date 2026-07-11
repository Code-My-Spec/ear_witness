# Desktop

This is the documentation for the Desktop project.

By default, Desktop applications depend on the following packages:

  * [Phoenix](https://hexdocs.pm/phoenix) - the Phoenix web framework

  * [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) - real-time
    user experience

  * [Sqlite3 Ecto](https://github.com/elixir-sqlite/ecto_sqlite3) - local
    database

To get started, see the [Getting Started Guide](./guides/getting_started.md).

This library is still worked on heaviliy and APIs are going to change in v2. If you are curious
to play around or contribute it's to best clone the current sample app at:
https://github.com/elixir-desktop/desktop-example-app and start modifying it to your wishes.

## identify_default_locale/1

Call on application to use the system locale by default for
  translations. The function will scan your gettext backend for available
  languages and compare to the system language to select the best match.

  ```
    Desktop.identify_default_locale(MyApp.Gettext)
  ```

## put_default_locale/1

Allows setting the default locale that will be used for translations in this
  Desktop application.
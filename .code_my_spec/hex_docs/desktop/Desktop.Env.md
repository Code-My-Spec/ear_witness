# Desktop.Env

Env holds any needed :wx / Desktop application state. Currently
it keeps track of
* The open Desktop.Window(s),
* OS Application events (such as when a file is dragged on the application icon)
* The :wx environment
* The dbus connection (sni) on linux

Also it has a global connect() method to allow binding of :wx event callbacks using
this long lived process as reference.

## backend/0

Returns the currently used webview backend

## sni/0

Returns the raw ExSni handle if used under linux to talk to DBus.

## wx/0

Returns the wx object. This is what has been created by the application using `:wx.new/1`. You
typically need a reference to this to execute raw `:wx` commands.

## wx_env/0

Gets the Desktop process's current raw `:wx` environment.
Can be sent to other processes to allow them use this process wx environment.

## Example

    iex> :wx.set_env(Desktop.Env.wx_env())
    iex> :wxWebView.isContextMenuEnabled(Desktop.Window.webview(pid))
    false

## wx_use_env/0

Shortcut for `:wx.set_env(Desktop.Env.wx_env())`

## subscribe/0

Wrapper around wx.subscribe()

  Will send to the calling process events in the form:

  * `{:print_file, [filename]}`
  * `{:open_file, [filename]}`
  * `{:open_url, [filename]}`
  * `{:new_file, []}`
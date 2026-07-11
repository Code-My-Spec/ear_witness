# Desktop.Window



## url/1

Returns the url currently shown of the Window.

  * `pid` - The pid or atom of the Window

## Examples

    iex> Desktop.Window.url(pid)
    http://localhost:1234/main

## show/2

Show the Window if not visible with the given url.

  * `pid` - The pid or atom of the Window
  * `url` - The endpoint url to show. If non is provided
    the url callback will be used to get one.

## Examples

    iex> Desktop.Window.show(pid, "/")
    :ok

## hide/1

Hide the Window if visible (noop on mobile platforms)

  * `pid` - The pid or atom of the Window

## Examples

    iex> Desktop.Window.hide(pid)
    :ok

## is_hidden?/1

Returns true if the window is hidden. Always returns false
on mobile platforms.

  * `pid` - The pid or atom of the Window

## Examples

    iex> Desktop.Window.is_hidden?(pid)
    false

## is_active?/1

Returns true if the window is active. Always returns true
on mobile platforms.

  * `pid` - The pid or atom of the Window

## Examples

    iex> Desktop.Window.is_active?(pid)
    false

## set_title/2

Set the windows title

  * `pid` - The pid or atom of the Window
  * `title` - The new windows title

## Examples

    iex> Desktop.Window.set_title(pid, "New Window Title")
    :ok

## iconize/2

Iconize or restore the window

  * `pid` - The pid or atom of the Window
  * `restore` - Optional defaults to false whether the
                window should be restored

## rebuild_webview/1

Rebuild the webview. This function is a troubleshooting
function at this time. On Windows it's sometimes necessary
to rebuild the WebView2 frame.

  * `pid` - The pid or atom of the Window

## Examples

    iex> Desktop.Window.rebuild_webview(pid)
    :ok

## webview/1

Fetch the underlying :wxWebView instance object. Call
this if you have to use more advanced :wxWebView functions
directly on the object.

  * `pid` - The pid or atom of the Window

## Examples

    iex> :wx.set_env(Desktop.Env.wx_env())
    iex> :wxWebView.isContextMenuEnabled(Desktop.Window.webview(pid))
    false

## frame/1

Fetch the underlying :wxFrame instance object. This represents
the window which the webview is drawn into.

  * `pid` - The pid or atom of the Window

## Examples

    iex> :wx.set_env(Desktop.Env.wx_env())
    iex> :wxWindow.show(Desktop.Window.frame(pid), show: false)
    false

## show_notification/3

Show a desktop notification

  * `pid` - The pid or atom of the Window

  * `text` - The text content to show in the notification

  * `opts` - Additional notification options

    Valid keys are:

      * `:id` - An id for the notification, this is important if you
        want control, the visibility of the notification. The default
        value when none is provided is `:default`

      * `:type` - One of `:info` `:error` `:warn` these will change
        how the notification will be displayed. The default is `:info`

      * `:title` - An alternative title for the notificaion,
        when none is provided the current window title is used.

      * `:timeout` - A timeout hint specifying how long the notification
        should be displayed.

        Possible values are:

          * `:auto` - This is the default and let's the OS decide

          * `:never` - Indicates that notification should not be hidden
            automatically

          * ms - A time value in milliseconds, how long the notification
            should be shown

      * `:callback` - A function to be executed when the user clicks on the
        notification.

## Examples

    iex> :wx.set_env(Desktop.Env.wx_env())
    iex> :wxWebView.isContextMenuEnabled(Desktop.Window.webview(pid))
    false

## quit/0

Quit the application. This forces a quick termination which can
be helpful on MacOS/Windows as sometimes the destruction is
crashing.
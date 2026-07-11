# Desktop.Menu

Menu module used to create and handle menus in Desktop

Menus are defined similar to Live View using a callback module an XML:

```
  defmodule ExampleMenuBar do
    use Desktop.Menu

    @impl true
    def mount(menu) do
      menu = assign(menu, items: ExampleRepo.all_items())
      {:ok, menu}
    end

    @impl true
    def handle_event(command, menu) do
      case command do
        <<"open">> -> :not_implemented
        <<"quit">> -> Desktop.Window.quit()
        <<"help">> -> Desktop.OS.launch_default_browser('https://google.com')
        <<"about">> -> :not_implemented
      end

      {:noreply, menu}
    end

    @impl true
    def render(assigns) do
      ~E"""
      <menubar>
        <menu label="<%= gettext "File" %>">
            <item onclick="open"><%= gettext "Open" %></item>
            <hr/>
            <item onclick="quit"><%= gettext "Quit" %></item>
        </menu>
        <menu label="<%= gettext "Items" %>">
          <%= for item <- @items do %>
            <item><%= item.name %></item>
          <% end %>
        </menu>
        <menu label="<%= gettext "Help" %>">
            <item onclick="help"><%= gettext "Show Documentation" %></item>
            <item onclick="about"><%= gettext "About" %></item>
        </menu>
      </menubar>
      """
    end
  end
```

# Template

As in live view the template can either be embedded in the `def render(assigns)`
method or it can be side loaded as a .eex file next to the menus .ex file.

# XML Structure

These items are defined:

## `<menubar>...menus...</menubar>`

For an application (window) menubar this must be the root element. When
passing a menubar to `Desktop.Window` start parameters this has to be the root element.
It has no attributes

## `<menu label="Label">...items...</menu>`

For an icon menu `menu` must be the root element. Menu elements can contain multiple
children of type `menu`, `item` and `hr`

### Attributes

* `label` - the label that should be displayed on the menu

## `<item ...>Label</item>`

This is an entry in the menu with a text a type and an onclick action

### Attributes

* `onclick` - an event name that should be fired when this item is clicked. It will cause `handle_event/2` to be called
* `type`        - the type of the item. The default is `normal`, but it can be either
  * `normal`    - a normal text item
  * `radio`     - a radio button
  * `checkbox`  - a checkbox item
* `checked` - whether the `checkbox` or `radio` button should be checked. `nil`, `false` and `0` are treated
as false values, every other value is treated as true.
* `disabled` - whether the item should be disabled. `nil`, `false` and `0` are treated
as false values, every other value is treated as true.

## `<hr />`

A separator item
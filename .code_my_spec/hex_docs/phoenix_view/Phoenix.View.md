# Phoenix.View

A module for generating `render/2` functions from templates on disk.

With design patterns introduced by `Phoenix.LiveView`, this module has fallen
out of fashion in favor of `Phoenix.Component`, even in non LiveView
applications. See the "Replaced by `Phoenix.Component`" section below.

## Examples

In Phoenix v1.6 and earlier, new Phoenix apps defined a blueprint for views
at `lib/your_app_web.ex`. It generally looked like this:

    defmodule YourAppWeb do
      # ...

      def view do
        quote do
          use Phoenix.View, root: "lib/your_app_web/templates", namespace: YourAppWeb

          # Import convenience functions from controllers
          import Phoenix.Controller,
            only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

          # Use all HTML functionality (forms, tags, etc)
          use Phoenix.HTML

          import YourAppWeb.ErrorHelpers
          import YourAppWeb.Gettext
        end
      end

      # ...
    end

Then you could use the definition above to define any view in your application:

    defmodule YourAppWeb.UserView do
      use YourAppWeb, :view
    end

Because we defined the template root to be "lib/your_app_web/templates",
`Phoenix.View` will automatically load all templates at "your_app_web/templates/user"
and include them in the `YourApp.UserView`. For example, imagine we have the
template:

    # your_app_web/templates/user/index.html.heex
    Hello <%= @name %>

The `.heex` extension maps to a template engine which tells Phoenix how
to compile the code in the file into Elixir source code. After it is
compiled, the template can be rendered as:

    Phoenix.View.render_to_string(YourApp.UserView, "index.html", name: "John Doe")
    #=> "Hello John Doe"

## Rendering and formats

`Phoenix.View` renders templates.

A template has a name, which also contains a format. For example,
in the previous section we have rendered the "index.html" template:

    Phoenix.View.render_to_string(YourApp.UserView, "index.html", name: "John Doe")
    #=> "Hello John Doe"

While we got a string at the end, that's not actually what our templates
render. Let's take a deeper look:

    Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
    #=> ...

This inner representation allows us to separate how templates render and
how they are encoded. For example, if you want to render JSON data, we
could do so by adding a "show.json" entry to `render/2` in our view:

    defmodule YourAppWeb.UserView do
      use YourAppWeb, :view

      def render("show.json", %{user: user}) do
        %{name: user.name, address: user.address}
      end
    end

Notice that in order to render JSON data, we don't need to explicitly
return a JSON string! Instead, we just return data that is encodable to
JSON. Now, when we call:

    Phoenix.View.render_to_string(YourApp.UserView, "user.json", user: %User{...})

Because the template has the `.json` extension, Phoenix knows how to
encode the map returned for the "user.json" template into an actual
JSON payload to be sent over the wire.

Phoenix ships with some template engines and format encoders, which
can be further configured in the Phoenix application. You can read
more about format encoders in `Phoenix.Template` documentation.

## Replaced by `Phoenix.Component`

In `Phoenix.LiveView`, `Phoenix.View` was replaced by `Phoenix.Component`.
With Phoenix v1.7+ we can also use `Phoenix.Component` to render traditional
templates as functional components, using the `embed_templates` function.

For example, in Phoenix v1.7+, the `YourAppWeb.UserView` above would be
written as:

    defmodule YourAppWeb.UserHTML do
      use YourAppWeb, :html

      embed_templates "users/*"
    end

The benefit of `Phoenix.Component` is that it unifies the rendering of
traditional request/response life cycles with the composable component
model provided by LiveView.

The table below summarizes how the defaults changed from Phoenix v1.6 to v1.7:

| Feature                          | Phoenix v1.6                            | Phoenix v1.7                                  |
| -------------------------------- | --------------------------------------- | --------------------------------------------- |
| `MyController.action/2` renders  | `MyView.render("action.html", assigns)` | `MyHTML.action(assigns)`                      |
| Define views at                  | `lib/my_app/views/my_view.ex`           | `lib/my_app/controllers/my_html.ex`           |
| At the top of your views         | `use MyAppWeb, :view`                   | `use MyAppWeb, :html`                         |
| Default template language        | `EEx` (`.eex` extension)                | `HEEx` (`.heex` extension)                    |
| To embed templates from disk     | `use Phoenix.View`                      | `use Phoenix.Component` (+ `embed_templates`) |
| HTML helpers (forms, links, etc) | `use Phoenix.HTML`                      | `use Phoenix.Component`                       |

However, note Phoenix v1.7 is backwards compatible with v1.6 if you want to
keep with the old style. The functionality in this module will be maintained
in the long term though for those who cannot or prefer not to migrate.

### Migrating to Phoenix.Component

Migrating your current views to components be done in a few steps. You should
also be able to migrate one view at a time.

> It may be helpful to generate a new project using Phoenix v1.7+ to compare
> code samples during this process.

The first step is to define `def html` in your `lib/my_app_web.ex` module.
This function is similar to `def view`, but it replaces `use Phoenix.View`
by `use Phoenix.Component` (requires LiveView 0.18.3 or later). We also
recomend to add `import Phoenix.View` inside `def html` while migrating.

Then, for each view, you must follow these steps (we will assume the
current view is called `MyAppWeb.MyView`):

  1. Replace `render_existing/3` calls by `function_exported?/3` checks,
     according to the `render_existing` documentation.

  2. Replace `use MyApp, :view` by `use MyApp, :html` and invoke
     `embed_templates "../templates/my/*"`. Alternatively, you can move
     both the HTML file and its templates to the `controllers` directory,
     to align with Phoenix v1.7 conventions.

  3. Your templates may now break if they are calling `render/2`.
     You can address this by replacing `render/2` with a function
     component. For instance, `render("_form.html", changeset: @changeset, user: @user)`
     must now be called as `<._form changeset={@changeset} user={@user} />`.
     If passing all assigns, `render("_form.html", assigns)` becomes
     `<%= _form(assigns) %>`

  4. Your templates may now break if they are calling `render_layout/4`.
     You can address this by converting the layout into a function component
     that receives its contents as a slot. See `render_layout/4` docs

Now you are using components! Once you convert all views, you should
be able to remove `Phoenix.View` as a dependency from your project.

Remove `def view` and also remove the `import Phoenix.View` from
`def html` in your `lib/my_app_web.ex` module. When doing so,
compilation may fail if you are using certain functions:

  * Replace `render/3` with a function component. For instance,
    `render(OtherView, "_form.html", changeset: @changeset, user: @user)`
    can now be called as `<OtherView.form changeset={@changeset} user={@user} />`.
    If passing all assigns, `render(OtherView, "_form.html", assigns)`
    becomes `<%= OtherView._form(assigns) %>`.

  * If you are using `Phoenix.View` for APIs, you can remove `Phoenix.View`
    altogether. Instead of `def render("index.html", assigns)`, use `def users(assigns)`.
    Instead of `def render("show.html", assigns)`, do `def user(assigns)`.
    Instead `render_one`/`render_many`, call the `users/1` and `user/1` functions
    directly.

## __using__/1

When used, defines the current module as a main view module.

## Options

  * `:root` - the template root to find templates
  * `:path` - the optional path to search for templates within the `:root`.
    Defaults to the underscored view module name. A blank string may
    be provided to use the `:root` path directly as the template lookup path
  * `:namespace` - the namespace to consider when calculating view paths
  * `:pattern` - the wildcard pattern to apply to the root
    when finding templates. Default `"*"`

The `:root` option is required while the `:namespace` defaults to the
first nesting in the module name. For instance, both `MyApp.UserView`
and `MyApp.Admin.UserView` have namespace `MyApp`.

The `:namespace` and `:path` options are used to calculate template
lookup paths. For example, if you are in `MyApp.UserView` and the
namespace is `MyApp`, templates are expected at `Path.join(root, "user")`.
On the other hand, if the view is `MyApp.Admin.UserView`,
the path will be `Path.join(root, "admin/user")` and so on. For
explicit root path locations, the `:path` option can be provided instead.
The `:root` and `:path` are joined to form the final lookup path.
A blank string may be provided to use the `:root` path directly as the
template lookup path.

Setting the namespace to `MyApp.Admin` in the second example will force
the template to also be looked up at `Path.join(root, "user")`.

## render/3

Renders a template.

It expects the view module, the template as a string, and a
set of assigns.

Notice that this function returns the inner representation of a
template. If you want the encoded template as a result, use
`render_to_iodata/3` instead.

## Examples

    Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
    #=> {:safe, "Hello John Doe"}

## Assigns

Assigns are meant to be user data that will be available in templates.
However, there are keys under assigns that are specially handled by
Phoenix, they are:

  * `:layout` - tells Phoenix to wrap the rendered result in the
    given layout. See next section

## Layouts

Templates can be rendered within other templates using the `:layout`
option. `:layout` accepts a tuple of the form
`{LayoutModule, "template.extension"}`.

To template that goes inside the layout will be placed in the `@inner_content`
assign:

    <%= @inner_content %>

## render_many/4

Renders a collection.

It receives a collection as an enumerable of structs and returns
the rendered collection in a list. This is typically used to render
a collection as structured data. For example, to render a list of
users to json:

    render_many(users, UserView, "show.json")

which is roughly equivalent to:

    Enum.map(users, fn user ->
      render(UserView, "show.json", user: user)
    end)

The underlying user is passed to the view and template as `:user`,
which is inferred from the view name. The name of the key
in assigns can be customized with the `:as` option:

    render_many(users, UserView, "show.json", as: :data)

is roughly equivalent to:

    Enum.map(users, fn user ->
      render(UserView, "show.json", data: user)
    end)

## render_one/4

Renders a single item if not nil.

The following:

    render_one(user, UserView, "show.json")

is roughly equivalent to:

    if user != nil do
      render(UserView, "show.json", user: user)
    end

The underlying user is passed to the view and template as
`:user`, which is inflected from the view name. The name
of the key in assigns can be customized with the `:as` option:

    render_one(user, UserView, "show.json", as: :data)

is roughly equivalent to:

    if user != nil do
      render(UserView, "show.json", data: user)
    end

## render_to_iodata/3

Renders the template and returns iodata.

## render_to_string/3

Renders the template and returns a string.

## template_path_to_name/2

Converts the template path into the template name.

## Examples

    iex> Phoenix.View.template_path_to_name(
    ...>   "lib/templates/admin/users/show.html.eex",
    ...>   "lib/templates"
    ...> )
    "admin/users/show.html"

## module_to_template_root/3

Converts a module, without the suffix, to a template root.

## Examples

    iex> Phoenix.View.module_to_template_root(MyApp.UserView, MyApp, "View")
    "user"

    iex> Phoenix.View.module_to_template_root(MyApp.Admin.User, MyApp, "View")
    "admin/user"

    iex> Phoenix.View.module_to_template_root(MyApp.Admin.User, MyApp.Admin, "View")
    "user"

    iex> Phoenix.View.module_to_template_root(MyApp.View, MyApp, "View")
    ""

    iex> Phoenix.View.module_to_template_root(MyApp.View, MyApp.View, "View")
    ""
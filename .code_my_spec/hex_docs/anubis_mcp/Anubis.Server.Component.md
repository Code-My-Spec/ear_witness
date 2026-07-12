# Anubis.Server.Component



## schema/1

Defines the parameter schema for the component.

The schema uses Peri's validation DSL and is automatically validated
before the component's callback is executed.

## output_schema/1

Defines the output schema for a tool component.

This schema describes the expected structure of the tool's output in the
structuredContent field. Only available for tool components.

## field/3

Defines a field with metadata for JSON Schema generation.

Supports both simple fields and nested objects with their own fields.

## Examples

    # Simple field
    field :email, {:required, :string}, format: "email", description: "User's email address"
    field :age, :integer, description: "Age in years"
    
    # Nested field
    field :user do
      field :name, {:required, :string}
      field :email, :string, format: "email"
    end

    # Nested field with metadata
    field :profile, description: "User profile information" do
      field :bio, :string, description: "Short biography"
      field :avatar_url, :string, format: "uri"
    end

## embeds_many/3

Defines a field that embeds many objects (array of objects).

## Examples

    embeds_many :users, description: "List of users" do
      field :id, :string, required: true, description: "User ID"
      field :name, :string, description: "User name"
    end

    embeds_many :tags, required: true do
      field :name, :string, required: true
      field :value, :string
    end

## embeds_one/3

Defines a field that embeds one object.

## Examples

    embeds_one :user, description: "User object" do
      field :id, :string, required: true, description: "User ID"
      field :name, :string, description: "User name"
    end

    embeds_one :address, required: true do
      field :street, :string, required: true
      field :city, :string, required: true
      field :zip, :string
    end

## get_description/1

Extracts the description from a component module.

## Parameters
  * `module` - The component module atom

## Returns
  * The description from `description/0` callback if defined
  * Falls back to the module's `@moduledoc` if no callback is defined
  * Empty string if neither is defined

## Examples

    iex> defmodule MyTool do
    ...>   @moduledoc "A helpful tool"
    ...>   use Anubis.Server.Component, type: :tool
    ...> end
    iex> Anubis.Server.Component.get_description(MyTool)
    "A helpful tool"

    iex> defmodule MyToolWithCallback do
    ...>   @moduledoc "Default description"
    ...>   use Anubis.Server.Component, type: :tool
    ...>   def description, do: "Custom description from callback"
    ...> end
    iex> Anubis.Server.Component.get_description(MyToolWithCallback)
    "Custom description from callback"

## get_type/1

Gets the component type (:tool, :prompt, or :resource).

## Parameters
  * `module` - The component module atom

## Returns
  * `:tool` - If the module is a tool component
  * `:prompt` - If the module is a prompt component
  * `:resource` - If the module is a resource component

## Examples

    iex> defmodule MyTool do
    ...>   use Anubis.Server.Component, type: :tool
    ...> end
    iex> Anubis.Server.Component.get_type(MyTool)
    :tool

## component?/1

Checks if a module is a valid component.

## Parameters
  * `module` - The module atom to check

## Returns
  * `true` if the module uses `Anubis.Server.Component`
  * `false` otherwise

## Examples

    iex> defmodule MyTool do
    ...>   use Anubis.Server.Component, type: :tool
    ...> end
    iex> Anubis.Server.Component.component?(MyTool)
    true

    iex> defmodule NotAComponent do
    ...>   def hello, do: :world
    ...> end
    iex> Anubis.Server.Component.component?(NotAComponent)
    false
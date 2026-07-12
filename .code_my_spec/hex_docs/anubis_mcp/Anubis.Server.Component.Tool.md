# Anubis.Server.Component.Tool

Defines the behaviour for MCP tools.

Tools are functions that can be invoked by the client with specific parameters.
Each tool must define its name, description, and parameter schema, as well as
implement the execution logic.

## Example

    defmodule MyServer.Tools.Calculator do
      @behaviour Anubis.Server.Behaviour.Tool

      alias Anubis.Server.{Frame, Response}
      alias Anubis.MCP.Error

      @impl true
      def name, do: "calculator"

      @impl true
      def description, do: "Performs basic arithmetic operations"

      @impl true
      def input_schema do
        %{
          "type" => "object",
          "properties" => %{
            "operation" => %{
              "type" => "string",
              "enum" => ["add", "subtract", "multiply", "divide"]
            },
            "a" => %{"type" => "number"},
            "b" => %{"type" => "number"}
          },
          "required" => ["operation", "a", "b"]
        }
      end

      @impl true
      def execute(%{"operation" => "add", "a" => a, "b" => b}, frame) do
        result = a + b

        # Can return updated frame if needed
        new_frame = Frame.assign(frame, :last_calculation, result)

        {:reply, Response.text(Response.tool(), to_string(result)), new_frame}
      end

      @impl true
      def execute(%{"operation" => "divide", "a" => _a, "b" => 0}, frame) do
        {:error, Error.invalid_request("Cannot divide by zero"), frame}
      end
    end
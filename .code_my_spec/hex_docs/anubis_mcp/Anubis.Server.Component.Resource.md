# Anubis.Server.Component.Resource

Defines the behaviour for MCP resources.

Resources represent data that can be read by the client, such as files,
documents, or any other content. Each resource is identified by a URI
and can provide content in various formats.

## Example

    defmodule MyServer.Resources.Documentation do
      @behaviour Anubis.Server.Behaviour.Resource

      alias Anubis.Server.{Frame, Response}
      alias Anubis.MCP.Error

      @impl true
      def uri, do: "file:///docs/readme.md"

      @impl true
      def name, do: "Project README"

      @impl true
      def description, do: "The main documentation for this project"

      @impl true
      def mime_type, do: "text/markdown"

      @impl true
      def read(_params, frame) do
        case File.read("README.md") do
          {:ok, content} ->
            # Can track access in frame
            new_frame = Frame.assign(frame, :last_resource_access, DateTime.utc_now())
            {:reply, Response.text(Response.resource(), content), new_frame}

          {:error, reason} ->
            {:error, Error.domain_error("Failed to read README: #{inspect(reason)}"), frame}
        end
      end
    end

## Example with URI template (parameterized resource)

    defmodule MyServer.Resources.UserDoc do
      use Anubis.Server.Component,
        type: :resource,
        uri_template: "file:///docs/{user}/{filename}"

      alias Anubis.Server.Response

      @impl true
      def read(%{"params" => %{"user" => user, "filename" => name}}, frame) do
        path = Path.join(["docs", user, name])

        case File.read(path) do
          {:ok, content} ->
            {:reply, Response.text(Response.resource(), content), frame}

          {:error, _} ->
            {:error, Anubis.MCP.Error.resource(:not_found, %{message: "no such file"}), frame}
        end
      end
    end

Variables in `uri_template` follow RFC 6570 (Level 1 — simple `{var}` expansion).
Extracted variables are delivered to `read/2` as the `"params"` key of the first argument.

## Example with dynamic content

    defmodule MyServer.Resources.SystemStatus do
      @behaviour Anubis.Server.Behaviour.Resource

      @impl true
      def uri, do: "system://status"

      @impl true
      def name, do: "System Status"

      @impl true
      def description, do: "Current system status and metrics"

      @impl true
      def mime_type, do: "application/json"

      @impl true
      def read(_params, frame) do
        status = %{
          uptime: System.uptime(),
          memory: :erlang.memory(),
          user_id: frame.assigns[:user_id],
          timestamp: DateTime.utc_now()
        }

        {:reply, Response.json(Response.resource(), status), frame}
      end
    end
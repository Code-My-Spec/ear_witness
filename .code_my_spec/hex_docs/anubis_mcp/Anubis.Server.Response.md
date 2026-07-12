# Anubis.Server.Response

Fluent interface for building MCP component responses.

This module provides builders for tool, prompt, and resource responses
that integrate seamlessly with the component system.

## Examples

    # Tool response
    Response.tool()
    |> Response.text("Result: " <> result)
    |> Response.build()
    
    # Resource response (uri and mime_type come from component)
    Response.resource()
    |> Response.text(file_contents)
    |> Response.build()
    
    # Prompt response
    Response.prompt()
    |> Response.user_message("What is the weather?")
    |> Response.assistant_message("Let me check...")
    |> Response.build()

## tool/0

Start building a tool response.

## Examples

    iex> Response.tool()
    %Response{type: :tool, content: [], isError: false}

## prompt/1

Start building a prompt response with optional description.

## Parameters

  * `description` - Optional description of the prompt

## Examples

    iex> Response.prompt()
    %Response{type: :prompt, messages: []}
    
    iex> Response.prompt("Weather assistant prompt")
    %Response{type: :prompt, messages: [], description: "Weather assistant prompt"}

## resource/0

Start building a resource response.

The uri and mimeType are automatically injected from the component's
uri/0 and mime_type/0 callbacks when the response is built by the server.

## Examples

    iex> Response.resource()
    %Response{type: :resource, contents: nil}

## completion/0

Start building a completion response.

## Examples

    iex> Response.completion()
    %Response{type: :completion, values: [], hasMore: false}

## text/3

Add text content to a tool or resource response.

For tool responses, adds text to the content array.
For resource responses, sets the text content.

## Parameters

  * `response` - A tool or resource response struct
  * `text` - The text content

## Examples

    iex> Response.tool() |> Response.text("Hello world")
    %Response{
      type: :tool,
      content: [%{"type" => "text", "text" => "Hello world"}],
      isError: false
    }
    
    iex> Response.resource() |> Response.text("File contents")
    %Response{type: :resource, contents: %{"text" => "File contents"}}

## json/3

Add JSON-encoded content to a tool response.

This is a convenience function that automatically encodes data as JSON
and adds it as text content. Useful for returning structured data from tools.

## Parameters

  * `response` - A tool response struct
  * `data` - Any JSON-encodable data structure

## Examples

    iex> Response.tool() |> Response.json(%{status: "ok", count: 42})
    %Response{
      type: :tool,
      content: [%{"type" => "text", "text" => "{\"status\":\"ok\",\"count\":42}"}],
      isError: false
    }
    
    iex> Response.tool() |> Response.json([1, 2, 3])
    %Response{
      type: :tool,
      content: [%{"type" => "text", "text" => "[1,2,3]"}],
      isError: false
    }

## structured/2

Set structured content for a tool response.

This adds structured JSON content that conforms to the tool's output schema.
For backward compatibility, this also adds the JSON as text content.

## Parameters

  * `response` - A tool response struct
  * `data` - A map containing the structured data

## Examples

    iex> Response.tool() |> Response.structured(%{temperature: 22.5, conditions: "Partly cloudy"})
    %Response{
      type: :tool,
      content: [%{"type" => "text", "text" => "{\"temperature\":22.5,\"conditions\":\"Partly cloudy\"}"}],
      structured_content: %{temperature: 22.5, conditions: "Partly cloudy"},
      isError: false
    }

## image/4

Add image content to a tool response.

## Parameters

  * `response` - A tool response struct
  * `data` - Base64 encoded image data
  * `mime_type` - MIME type of the image (e.g., "image/png")

## Examples

    iex> Response.tool() |> Response.image(base64_data, "image/png")
    %Response{
      type: :tool,
      content: [%{"type" => "image", "data" => base64_data, "mimeType" => "image/png"}],
      isError: false
    }

## audio/4

Add audio content to a tool response.

## Parameters

  * `response` - A tool response struct
  * `data` - Base64 encoded audio data
  * `mime_type` - MIME type of the audio (e.g., "audio/wav")
  * `opts` - Optional keyword list with:
    * `:transcription` - Optional text transcription of the audio

## Examples

    iex> Response.tool() |> Response.audio(audio_data, "audio/wav")
    %Response{
      type: :tool,
      content: [%{"type" => "audio", "data" => audio_data, "mimeType" => "audio/wav"}],
      isError: false
    }
    
    iex> Response.tool() |> Response.audio(audio_data, "audio/wav", transcription: "Hello")
    %Response{
      type: :tool,
      content: [%{
        "type" => "audio",
        "data" => audio_data,
        "mimeType" => "audio/wav",
        "transcription" => "Hello"
      }],
      isError: false
    }

## embedded_resource/3

Add an embedded resource reference to a tool response.

## Parameters

  * `response` - A tool response struct
  * `uri` - The resource URI
  * `opts` - Optional keyword list with:
    * `:name` - Human-readable name
    * `:description` - Resource description
    * `:mime_type` - MIME type
    * `:text` - Text content (for text resources)
    * `:blob` - Base64 data (for binary resources)

## Examples

    iex> Response.tool() |> Response.embedded_resource("file://example.txt",
    ...>   name: "Example File",
    ...>   mime_type: "text/plain",
    ...>   text: "File contents"
    ...> )

## resource_link/4

Add a resource link to a tool response.

## Parameters

  * `response` - A tool response struct
  * `uri` - The resource URI
  * `name` - The name of the resource
  * `opts` - Optional keyword list with:
    * `:title` - Human-readable title
    * `:description` - Resource description
    * `:mime_type` - MIME type
    * `:size` - Size in bytes
    * `:annotations` - Optional annotations map

## Examples

    iex> Response.tool() |> Response.resource_link("file://main.rs", "main.rs",
    ...>   title: "Main File",
    ...>   description: "Primary application entry point",
    ...>   mime_type: "text/x-rust",
    ...>   annotations: %{audience: ["assistant"], priority: 0.9}
    ...> )
    %Response{
      type: :tool,
      content: [%{
        "type" => "resource_link",
        "uri" => "file://main.rs",
        "name" => "main.rs",
        "title" => "Main File",
        "description" => "Primary application entry point",
        "mimeType" => "text/x-rust",
        "annotations" => %{"audience" => ["assistant"], "priority" => 0.9}
      }],
      isError: false
    }

## error/2

Mark a tool response as an error and add error message.

## Parameters

  * `response` - A tool response struct
  * `message` - The error message

## Examples

    iex> Response.tool() |> Response.error("Division by zero")
    %Response{
      type: :tool,
      content: [%{"type" => "text", "text" => "Error: Division by zero"}],
      isError: true
    }

## user_message/2

Add a user message to a prompt response.

## Parameters

  * `response` - A prompt response struct
  * `content` - The message content (string or structured content)

## Examples

    iex> Response.prompt() |> Response.user_message("What's the weather?")
    %Response{
      type: :prompt,
      messages: [%{"role" => "user", "content" => "What's the weather?"}]
    }

## assistant_message/2

Add an assistant message to a prompt response.

## Parameters

  * `response` - A prompt response struct
  * `content` - The message content (string or structured content)

## Examples

    iex> Response.prompt() |> Response.assistant_message("Let me check the weather for you.")
    %Response{
      type: :prompt,
      messages: [%{"role" => "assistant", "content" => "Let me check the weather for you."}]
    }

## system_message/2

Add a system message to a prompt response.

## Parameters

  * `response` - A prompt response struct
  * `content` - The message content (string or structured content)

## Examples

    iex> Response.prompt() |> Response.system_message("You are a helpful weather assistant.")
    %Response{
      type: :prompt,
      messages: [%{"role" => "system", "content" => "You are a helpful weather assistant."}]
    }

## blob/2

Set blob (base64) content for a resource response.

## Parameters

  * `response` - A resource response struct
  * `data` - binary data

## Examples

    iex> Response.resource() |> Response.blob(data)
    %Response{type: :resource, contents: %{"blob" => base64_data}}

## name/2

Set optional name for a resource response.

## Parameters

  * `response` - A resource response struct
  * `name` - Human-readable name for the resource

## Examples

    iex> Response.resource() |> Response.name("Configuration File")
    %Response{type: :resource, metadata: %{name: "Configuration File"}}

## description/2

Set optional description for a resource response.

## Parameters

  * `response` - A resource response struct
  * `desc` - Description of the resource

## Examples

    iex> Response.resource() |> Response.description("Application configuration settings")
    %Response{type: :resource, metadata: %{description: "Application configuration settings"}}

## size/2

Set optional size for a resource response.

## Parameters

  * `response` - A resource response struct
  * `size` - Size in bytes

## Examples

    iex> Response.resource() |> Response.size(1024)
    %Response{type: :resource, metadata: %{size: 1024}}

## completion_value/3

Add a completion value to a completion response.

## Parameters

  * `response` - A completion response struct
  * `value` - The completion value
  * `opts` - Optional keyword list with:
    * `:description` - Description of the completion value
    * `:label` - Optional label for the value

## Examples

    iex> Response.completion() |> Response.completion_value("tool:calculator", description: "Math calculator tool")
    %Response{
      type: :completion,
      values: [%{"value" => "tool:calculator", "description" => "Math calculator tool"}]
    }

## completion_values/2

Add multiple completion values at once.

## Parameters

  * `response` - A completion response struct
  * `values` - List of values (strings or maps with value/description/label)

## Examples

    iex> Response.completion() |> Response.completion_values(["foo", "bar"])
    %Response{
      type: :completion,
      values: [%{"value" => "foo"}, %{"value" => "bar"}]
    }
    
    iex> Response.completion() |> Response.completion_values([
    ...>   %{value: "foo", description: "Foo option"},
    ...>   %{value: "bar", description: "Bar option"}
    ...> ])

## with_pagination/3

Set pagination information for completion response.

## Parameters

  * `response` - A completion response struct
  * `total` - Total number of available completions
  * `has_more` - Whether more completions are available

## Examples

    iex> Response.completion() 
    ...> |> Response.completion_values(["foo", "bar"])
    ...> |> Response.with_pagination(10, true)
    %Response{
      type: :completion,
      values: [%{"value" => "foo"}, %{"value" => "bar"}],
      total: 10,
      hasMore: true
    }

## to_protocol/1

Build the final response structure.

Transforms the response struct into the appropriate format for the MCP protocol.

## Parameters

  * `response` - A response struct of any type

## Examples

    iex> Response.tool() |> Response.text("Hello") |> Response.to_protocol()
    %{"content" => [%{"type" => "text", "text" => "Hello"}], "isError" => false}
    
    iex> Response.prompt() |> Response.user_message("Hi") |> Response.to_protocol()
    %{"messages" => [%{"role" => "user", "content" => "Hi"}]}
    
    iex> Response.resource() |> Response.text("data") |> Response.to_protocol()
    %{"text" => "data"}
# Anubis.Server.Component.Prompt

Defines the behaviour for MCP prompts.

Prompts are reusable templates that generate messages based on provided arguments.
They help standardize common interactions and can be customized with parameters.

## Example

    defmodule MyServer.Prompts.CodeReview do
      @behaviour Anubis.Server.Behaviour.Prompt
      
      alias Anubis.Server.{Frame, Response}
      
      @impl true
      def name, do: "code_review"
      
      @impl true
      def description do
        "Generate a code review prompt for the given programming language and code"
      end
      
      @impl true
      def arguments do
        [
          %{
            "name" => "language",
            "description" => "The programming language of the code",
            "required" => true
          },
          %{
            "name" => "code",
            "description" => "The code to review",
            "required" => true
          },
          %{
            "name" => "focus_areas",
            "description" => "Specific areas to focus on (e.g., performance, security)",
            "required" => false
          }
        ]
      end
      
      @impl true
      def get_messages(%{"language" => lang, "code" => code} = args, frame) do
        focus = Map.get(args, "focus_areas", "general quality")
        
        messages = [
          %{
            "role" => "user",
            "content" => %{
              "type" => "text",
              "text" => """
              Please review the following #{lang} code, focusing on #{focus}:
              
              ```#{lang}
              #{code}
              ```
              
              Provide constructive feedback on:
              1. Code quality and readability
              2. Potential bugs or issues
              3. Performance considerations
              4. Best practices for #{lang}
              """
            }
          }
        ]
        
        # Can track prompt usage
        new_frame = Frame.assign(frame, :last_prompt_used, "code_review")
        
        response =
          Response.prompt()
          |> Response.user_message(Enum.map_join(messages, "
", & &1["content"]["text"]))

        {:reply, response, new_frame}
      end
    end
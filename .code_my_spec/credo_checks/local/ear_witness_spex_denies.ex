defmodule EarWitness.Check.Warning.EarWitnessSpexDenies do
  use Credo.Check,
    id: "EARWIT0001",
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Whole-module denies for EarWitness BDD spec files (`_spex.exs`).

      The framework check (`spex_denied_calls.ex`) carries the universal
      function-level denies; this project-local check carries the
      whole-module list:

      Stdlib bypasses:

      - `File`, `:file` — real-disk reads bypass the spec environment.
      - `Port` — talks to external programs (whisper.cpp runs behind the
        Transcription engine, never directly from a spec).

      EarWitness internals (specs act through the LiveView surface, never
      the domain contexts — see the architecture proposal):

      - `EarWitness.Repo` — direct DB access bypasses the public surface.
      - `EarWitness.Recordings` — create recordings by driving
        RecordingLive (record/import actions), not by calling the context.
      - `EarWitness.Transcription` — start transcriptions from the UI, not
        the context; assert on rendered transcript output.
      - `EarWitness.Audio` — capture pipelines are infrastructure; specs
        never touch Membrane or the audio tap directly.
      - `EarWitness.Speakers` — diarization runs behind the transcription
        flow; name speakers through TranscriptLive.
      - `EarWitness.Search` — search through SearchLive (or the MCP
        surface), not the context.
      - `EarWitness.Models` — model setup is driven through SetupLive.
      - `EarWitness.Bots` — dispatch bots through BotLive.

      Schemas (`EarWitness.Recordings.Recording`,
      `EarWitness.Transcription.Transcript`, `EarWitness.Speakers.Speaker`,
      ...) and the public surfaces (`EarWitnessWeb.*`, including
      `EarWitnessWeb.McpServer`) are NOT denied — those are the legal
      surfaces. Sanctioned shortcuts live on `EarWitnessSpex.Fixtures`.
      """
    ]

  @denied_whole_modules [
    File,
    Port,
    EarWitness.Repo,
    EarWitness.Recordings,
    EarWitness.Transcription,
    EarWitness.Audio,
    EarWitness.Speakers,
    EarWitness.Search,
    EarWitness.Models,
    EarWitness.Bots
  ]
  @denied_whole_erlang_modules [:file]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    if String.ends_with?(filename, "_spex.exs") do
      ctx = %{issue_meta: Context.build(source_file, params, __MODULE__), issues: []}
      Credo.Code.prewalk(source_file, &traverse/2, ctx).issues
    else
      []
    end
  end

  # Aliased Elixir modules — File.*, Port.*, EarWitness.Repo.*, ...
  defp traverse(
         {{:., _, [{:__aliases__, meta, module_parts}, fun]}, _, _args} = ast,
         ctx
       ) do
    module = Module.concat(module_parts)

    if module in @denied_whole_modules do
      {ast, add_issue(ctx, meta, "#{inspect(module)}.#{fun}")}
    else
      {ast, ctx}
    end
  end

  # Erlang modules — :file.*
  defp traverse({{:., _, [erl_mod, fun]}, meta, _args} = ast, ctx)
       when is_atom(erl_mod) do
    if erl_mod in @denied_whole_erlang_modules do
      {ast, add_issue(ctx, meta, "#{inspect(erl_mod)}.#{fun}")}
    else
      {ast, ctx}
    end
  end

  defp traverse(ast, ctx), do: {ast, ctx}

  defp add_issue(ctx, meta, trigger) do
    issue =
      format_issue(
        ctx.issue_meta,
        message:
          "Call to `#{trigger}` is denied in _spex.exs files. Specs must act through " <>
            "the public LiveView surface (or EarWitnessSpex.Fixtures for sanctioned " <>
            "seeding) — see .code_my_spec/knowledge/bdd/spex/boundaries.md.",
        trigger: trigger,
        line_no: meta[:line],
        column: meta[:column]
      )

    %{ctx | issues: [issue | ctx.issues]}
  end
end

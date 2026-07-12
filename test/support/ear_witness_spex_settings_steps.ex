defmodule EarWitnessSpex.SettingsSteps do
  @moduledoc """
  Reusable steps for driving `EarWitnessWeb.SettingsLive` from BDD specs —
  capture-source selection and consent-policy choice happen through the
  real settings UI, never via `Application.put_env` (see the project BDD
  plan's anti-patterns).
  """

  @endpoint EarWitnessWeb.Endpoint

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @doc """
  Opens settings and selects the recording consent policy
  (`"silent" | "notify" | "announce"`) through the real form. Returns the
  settings view.
  """
  def choose_consent_policy(conn, policy) do
    {:ok, view, _html} = live(conn, "/settings")

    view
    |> form(~s([data-test="consent-policy-form"]), %{"policy" => policy})
    |> render_change()

    view
  end

  @doc """
  Opens settings and selects the system audio tap as the capture source
  through the real form. Returns the settings view.
  """
  def choose_tap_capture_source(conn) do
    {:ok, view, _html} = live(conn, "/settings")

    view
    |> form(~s([data-test="capture-source-form"]), %{"source" => "tap"})
    |> render_change()

    view
  end

  @doc """
  Opens settings and switches the active transcription model to
  `model_id` through the real form (story 866, criterion 7370 — "Swap the
  active model in settings"). Returns the settings view.
  """
  def switch_active_model(conn, model_id) do
    {:ok, view, _html} = live(conn, "/settings")

    view
    |> form(~s([data-test="active-model-form"]), %{"model_id" => model_id})
    |> render_change()

    view
  end

  @doc """
  Opens settings and sets whether AI assistants may reach the local MCP
  tool surface (`"enabled" | "disabled"`) through the real form (story 868
  — "Revoking access shuts the assistant out"). Returns the settings view.

  New selector, not yet in the project's selector-conventions list
  (`.code_my_spec/knowledge/bdd/spex/index.md`): `[data-test="assistant-access-form"]`,
  field name `"access"`. Neither `EarWitnessWeb.SettingsLive` nor this form
  exists yet — this is a judgment call made explicit here (mirroring
  `EarWitnessSpex.TranscriptSteps`'s route-assumption note) so a human can
  confirm or correct the selector/field name before implementation.
  """
  def set_assistant_access(conn, access) when access in ["enabled", "disabled"] do
    {:ok, view, _html} = live(conn, "/settings")

    view
    |> form(~s([data-test="assistant-access-form"]), %{"access" => access})
    |> render_change()

    view
  end
end

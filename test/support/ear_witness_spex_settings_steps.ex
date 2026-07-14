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
  Opens settings. Kept for the many capture scenarios that begin "the tap is the
  active capture source": there is no source to pick anymore — every recording
  captures the microphone and system audio together (story 872 UAT), so that
  precondition is automatically satisfied and this just returns the settings
  view. (Name retained so those specs read unchanged.)
  """
  def choose_tap_capture_source(conn) do
    {:ok, view, _html} = live(conn, "/settings")
    view
  end

  @doc """
  Opens settings and switches the active transcription model to
  `model_id` through the real form (story 866, criterion 7370 — "Swap the
  active model in settings"). Returns the settings view.
  """
  def switch_active_model(conn, model_id) do
    {:ok, view, _html} = live(conn, "/settings")

    # Settings is now a model manager: each downloaded, non-active model has
    # a "Use" button (phx-click switch_active_model) rather than one radio form.
    view
    |> element(~s([data-test="use-model"][data-model="#{model_id}"]))
    |> render_click()

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

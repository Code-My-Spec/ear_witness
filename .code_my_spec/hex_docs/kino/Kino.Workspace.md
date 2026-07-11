# Kino.Workspace

Functions related to workspace integrations and Livebook apps.

## app_info/0

Returns information about the running app.

Note that `:started_by` information is only available for multi-session
apps when the app uses a Livebook Teams workspace.

Unless called from within an app deployment, returns `%{type: :none}`.

## user_info/1

Returns user information for the given connected client id.

Note that this information is only available when the session uses
Livebook Teams workspace, otherwise `:not_available` error is returned.

If there is no such connected client, `:not_found` error is returned.
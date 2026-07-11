# Bundlex.Helper.MixHelper



## get_app!/0

Helper function for retrieving app name from mix.exs and failing if it was
not found.

## get_app!/1

Returns app for the given module. In case of failure fallbacks to `get_app!/0`.

## get_priv_dir/1

Returns path to the `priv` dir for given application.

## get_project_dir/0

Returns root directory of the currently compiled project.

## get_project_dir/1

Returns root directory of the project of given application.
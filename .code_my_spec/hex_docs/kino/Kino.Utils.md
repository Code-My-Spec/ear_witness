# Kino.Utils



## truthy_keys/1

Returns keyword list keys that hold a truthy value.

## Examples

    iex> Kino.Utils.truthy_keys(cat: true, dog: false)
    [:cat]

    iex> Kino.Utils.truthy_keys(tea: :ok, coffee: nil)
    [:tea]

## has_function?/3

Checks if the given module exports the given function.

Loads the module if not loaded.

## supervisor?/1

Checks if the given process is a supervisor.

## get_image_type/1

Determines image type looking for the magic number in the binary.
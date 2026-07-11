# Membrane.Core.DocsHelper



## add_callbacks_list_to_moduledoc/2

A function that appends a list of callbacks to the @moduledoc of a given argument.

The list of callbacks is fetched out of the callbacks defined by that module, passed as the
first argument, and the callbacks fetched from each of the modules passed as a list in second argument.
The third argument filter the callbacks that should be put into the @moduledoc, as it is a prefix of the
callback names that are desired to be put there.
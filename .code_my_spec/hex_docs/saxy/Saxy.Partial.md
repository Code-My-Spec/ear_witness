# Saxy.Partial



## new/3

Builds up a `Saxy.Partial`, which can be used for later parsing.

## parse/2

Continue parsing next chunk of the document with a partial.

This function can return in 3 ways:

* `{:cont, partial}` - The parsing process has not been terminated.
* `{:halt, user_state}` - The parsing process has been terminated, usually because of parser stopping.
* `{:halt, user_state, rest}` - The parsing process has been terminated, usually because of parser halting.
* `{:error, exception}` - The parsing process has erred.

## terminate/1

Terminates the XML document parsing.
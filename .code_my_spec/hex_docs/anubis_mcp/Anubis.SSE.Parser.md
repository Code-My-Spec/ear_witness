# Anubis.SSE.Parser



## run/1

Parses a string containing one or more SSE events.

Each event is separated by an empty line (two consecutive newlines).
Returns a list of `%SSE.Event{}` structs.
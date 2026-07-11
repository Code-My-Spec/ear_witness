# Membrane.Core.Element.EventController



## handle_event/3

Handles incoming event: either stores it in InputQueue, or executes element callback.
Extra checks and tasks required by special events such as `:start_of_stream`
or `:end_of_stream` are performed.
# Membrane.Core.Element.BufferController



## handle_incoming_buffers/3

Handles incoming buffer: either stores it in InputQueue, or executes element's
callback. Also calls `Membrane.Core.Element.ManualFlowController.supply_demand/2`
to check if there are any unsupplied demands.

## exec_buffer_callback/3

Executes `handle_buffer` callback.
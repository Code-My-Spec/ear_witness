# Membrane.Core.Element.ManualFlowController



## handle_redemand/2

Called when redemand action was returned.
  * If element is currently supplying demand, it means that after finishing `supply_demand` it will call
    `handle_delayed_demands`.
  * If element isn't supplying demand at the moment and there's some unsupplied demand on the given
    output, `handle_demand` is invoked right away, so that the demand can be synchronously supplied.

## supply_demand/2

If element is not supplying demand currently, this function supplies
demand right away by taking buffers from the InputQueue of the given input pad
and passing it to proper controllers.

If element is currently supplying demand it delays supplying demand until all
current processing is finished.

This is necessary due to the case when one requests a demand action while previous
demand is being supplied. This could lead to a situation where buffers are taken
from InputQueue and passed to callbacks, while buffers being currently supplied
have not been processed yet, and therefore to changing order of buffers.

The `size` argument can be passed optionally to update the demand on the pad
before proceeding to supplying it.
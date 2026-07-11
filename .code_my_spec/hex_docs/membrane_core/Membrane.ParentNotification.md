# Membrane.ParentNotification

A parent notification is a message sent from `Membrane.Parent` or `Membrane.Bin` to a child
via action `t:Membrane.Pipeline.Action.notify_parent` or `t:Membrane.Bin.Action.notify_child`
returned from any callback.

A notification can be handled in child with `c:Membrane.Element.Base.handle_parent_notification/3` or
`c:Membrane.Bin.handle_parent_notification/3` callback.
# Membrane.ChildNotification

A child notification is a message sent from `Membrane.Element` or `Membrane.Bin` to a parent
via action `t:Membrane.Element.Action.notify_parent` or `t:Membrane.Bin.Action.notify_parent`
returned from any callback.

A notification can be handled in parent with
`c:Membrane.Parent.handle_child_notification/4` callback.
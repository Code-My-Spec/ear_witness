# ExSni.Menu.Item



## set_id/2

WARNING: Always use unique IDs across the entire tree.
If you set the same ID for a node and any of its descendants,
most menu hosts (i.e. libdbusmenu) will recurse indefinitely when attempting
to build the list of IDs to request the layout for; which will most likely
result in a system-wide crash/hang.

To store custom ID (e.g. "id" attribute), use `uid` property and `set_uid/2`
# Membrane.Core.Bin.PadController



## handle_external_link_request/5

Handles a link request from the bin's parent.

## handle_internal_link_request/4

Handles a link request coming from the bin itself when linking a bin's pad
to a pad of one of its children.

## respond_links/2

Sends link response to the parent for each of bin's pads involved in given spec.

## all_pads_linked?/2

Returns true if all pads of given `spec_ref` are linked, false otherwise.

## handle_link/5

Verifies linked pad and proxies the message to the proper child.

## handle_unlink/2

Handles situation where the pad has been unlinked (e.g. when connected element has been removed from the pipeline)
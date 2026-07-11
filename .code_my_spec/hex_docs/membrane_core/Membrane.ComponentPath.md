# Membrane.ComponentPath

A list consisting of following pipeline/bin/element names down the assembled pipeline.

It traces element's path inside a pipeline.
Information is being stored in a process dictionary and can be set/appended to.

## set/1

Sets current path.

If path had already existed then replaces it.

## format/1

Returns formatted string of given path's names.

## get_formatted/0

Works the same way as `format/1` but uses currently stored path.

## get/0

Returns currently stored path.

If path has not been set, empty list is returned.
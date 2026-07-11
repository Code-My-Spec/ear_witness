# Membrane.Pad

Pads are units defined by elements and bins, allowing them to be linked with their
siblings. This module consists of pads typespecs and utils.

Each pad is described by its name, direction, availability, mode and possible stream format.
For pads to be linkable, these properties have to be compatible. For more
information on each of them, check appropriate type in this module.

Each link can only consist of exactly two pads.

## ref/1

Creates a static pad reference.

## ref/2

Creates a dynamic pad reference.

## availability_mode/1

Returns pad availability mode for given availability.

## name_by_ref/1

Returns the name for the given pad reference
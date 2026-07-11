# Kino.AttributeStore



## initialize/0

Initializes resources for global attrs.

## counter_next/1

Increments the given counter and returns the new value.

## counter_put_max/2

Sets the counter to `value` unless it already has a higher value.

Returns the new counter value.

## put_attribute/2

Puts the shared attribute value.

## get_attribute/2

Returns the attribute value for a given key.
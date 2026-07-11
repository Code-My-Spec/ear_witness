# Toml.Builder



## push_table/2

Starts a new table and sets the context for subsequent key/values

## push_table_array/2

Starts a new array of tables and sets the context for subsequent key/values

## push_comment/2

Push a comment on a stack containing lines of comments applying to some element.
Comments are collected and assigned to key paths when a key is set, table created, etc.

## push_key/3

Push a value for a key into the TOML document.

This operation is used when any key/value pair is set, and table or table array is defined.

Based on the key the type of the value provided, the behavior of this function varies, as validation
as performed as part of setting the key, to ensure that redefining keys is prohibited, but that setting
child keys of existing tables is allowed. Table arrays considerably complicate this unfortunately.
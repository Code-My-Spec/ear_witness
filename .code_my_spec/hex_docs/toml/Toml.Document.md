# Toml.Document



## new/1

Create a new empty TOML document

## to_map/1

Convert the given TOML document to a plain map.

During conversion to a plain map, keys are converted according 
to the key type defined when the document was created.

In addition to converting keys, if transforms were defined, they are
applied to values depth-first, bottom-up. Transforms are first composed
into a single function, designed to be executed in the order they appear 
in the list provided; if any transform returns an error, conversion is
stopped and an error is returned - otherwise, the value is passed from
transformer to transformer and the final result replaces the value in the
document.
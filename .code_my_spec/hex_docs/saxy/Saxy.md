# Saxy



## encode!/2

Encodes a simple form XML element into string.

This function encodes an element in simple form format and a prolog to an XML document.

## Examples

    iex> import Saxy.XML
    iex> root = element(:foo, [{"foo", "bar"}], "bar")
    iex> prolog = [version: "1.0"]
    iex> Saxy.encode!(root, prolog)
    "<?xml version=\"1.0\"?><foo foo=\"bar\">bar</foo>"

## encode_to_iodata!/2

Encodes a simple form element into IO data.

Same as `encode!/2` but this encodes the document into IO data.

## Examples

    iex> import Saxy.XML
    iex> root = element(:foo, [{"foo", "bar"}], "bar")
    iex> prolog = [version: "1.0"]
    iex> Saxy.encode_to_iodata!(root, prolog)
    [
      ['<?xml', [32, 'version', 61, 34, "1.0", 34], [], [], '?>'],
      [60, "foo", 32, "foo", 61, 34, "bar", 34],
      62,
      ["bar"],
      [60, 47, "foo", 62]
    ]
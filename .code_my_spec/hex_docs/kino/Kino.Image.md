# Kino.Image

A kino for rendering a binary image.

This is just a meta-struct that implements the `Kino.Render`
protocol, so that it gets rendered as the underlying image.

## Examples

    content = File.read!("/path/to/image.jpeg")
    Kino.Image.new(content, "image/jpeg")

## new/2

Creates a new kino displaying the given binary image.

The given type can be either `:jpeg`/`:jpg`, `:png`, `:gif`, `:svg`, `:pixel`
or a string with image MIME type.

## Pixel data

Note that a special `image/x-pixel` MIME type is supported. The
binary consists of the following consecutive parts:

  * height - 32 bits (unsigned big-endian integer)
  * width - 32 bits (unsigned big-endian integer)
  * channels - 8 bits (unsigned integer)
  * data - pixel data in HWC order

Pixel data consists of 8-bit unsigned integers. The number of channels
can be either: 1 (grayscale), 2 (grayscale + alpha), 3 (RGB), or 4
(RGB + alpha).

## new/1

Creates a new kino similarly to `new/2` from a compatible term.

Currently the supported terms are:

  * `Nx.Tensor` in HWC order
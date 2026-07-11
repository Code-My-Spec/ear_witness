# Kino.Inspect

A struct wrapping any term for default rendering.

This is just a meta-struct that implements the `Kino.Render`
protocol, so that the wrapped value is rendered using the inspect
protocol.

## new/1

Wraps the given term.
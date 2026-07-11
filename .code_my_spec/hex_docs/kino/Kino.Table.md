# Kino.Table

A behaviour module for implementing tabular kinos.

This module implements table visualization and delegates data
fetching and traversal to the behaviour implementation.

## new/3

Creates a new tabular kino using the given module as data
specification.

## Options

  * `:export` - a function called to export the given kino to Markdown.
    This works the same as `Kino.JS.new/3`, except the function
    receives the state as an argument

## update/2

Updates the table with new data.

An arbitrary update event can be used and it is then handled by
the `c:on_update/2` callback.
# Peri.Generatable

A module for generating sample data based on Peri schemas using StreamData.

This module provides functions to generate various types of data, conforming to the schema definitions given in Peri. It leverages the StreamData library to create streams of random data that match the specified types and constraints.

## Examples

    iex> schema = %{
    ...>   name: :string,
    ...>   age: {:integer, {:gte, 18}},
    ...>   active: :boolean
    ...> }
    iex> Peri.Generatable.gen(schema)
    %StreamData{
      type: :fixed_map,
      data: %{name: StreamData.string(:alphanumeric), age: StreamData.filter(StreamData.integer(), &(&1 >= 18)), active: StreamData.boolean()}
    }

## gen/1

Generates a stream of data based on the given schema type.

This function provides various clauses to handle different types and constraints defined in Peri schemas. It uses StreamData to generate streams of random data conforming to the specified types and constraints.

## Parameters

  - `schema`: The schema type to generate data for. It can be a simple type like `:integer`, `:string`, etc., or a complex type with constraints like `{:integer, {:gte, 18}}`.

## Returns

  - A StreamData generator stream for the specified schema type.

## Examples

    iex> Peri.Generatable.gen(:atom)
    %StreamData{type: :atom, data: ...}

    iex> Peri.Generatable.gen(:string)
    %StreamData{type: :string, data: ...}

    iex> Peri.Generatable.gen(:integer)
    %StreamData{type: :integer, data: ...}

    iex> Peri.Generatable.gen({:enum, [:admin, :user, :guest]})
    %StreamData{type: :one_of, data: ...}

    iex> Peri.Generatable.gen({:list, :integer})
    %StreamData{type: :list_of, data: ...}

    iex> Peri.Generatable.gen({:tuple, [:string, :integer]})
    %StreamData{type: :tuple, data: ...}

    iex> Peri.Generatable.gen({:integer, {:gt, 10}})
    %StreamData{type: :filter, data: ...}

    iex> Peri.Generatable.gen({:string, {:regex, ~r/^[a-z]+$/}})
    %StreamData{type: :filter, data: ...}

    iex> Peri.Generatable.gen({:either, {:integer, :string}})
    %StreamData{type: :one_of, data: ...}

    iex> Peri.Generatable.gen({:custom, {MyModule, :my_fun}})
    %StreamData{type: :filter, data: ...}

    iex> schema = %{name: :string, age: {:integer, {:gte, 18}}}
    iex> Peri.Generatable.gen(schema)
    %StreamData{type: :fixed_map, data: ...}
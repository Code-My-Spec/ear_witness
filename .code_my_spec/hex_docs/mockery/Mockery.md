# Mockery

Provides core mocking functionality for Elixir tests.

This module offers tools to create and manage mocks within the
context of individual test processes. Mocks created here are isolated and
will not affect other processes, making them safe for concurrent and
asynchronous testing.

## Using Mockery in your tests

By adding `use Mockery` in your test modules, you automatically import several useful modules and functions:

- Core Mockery function `mock/3`
- Assertion helpers from `Mockery.Assertions` ([`assert_called!/3`](Mockery.Assertions.html#assert_called!/3), [`refute_called!/3`](Mockery.Assertions.html#refute_called!/3))
- History control functions from `Mockery.History` ([`enable_history/0`](Mockery.History.html#enable_history/0), [`disable_history/0`](Mockery.History.html#disable_history/0))

Example usage:

    defmodule MyApp.User do
      def greet, do: "Hello, User!"
    end

    defmodule MyApp.Greeter do
      use Mockery.Macro

      def greet_user do
        mockable(MyApp.User).greet()
      end
    end

    defmodule MyApp.GreeterTest do
      use ExUnit.Case, async: true
      use Mockery

      test "mock greet/0 from MyApp.User" do
        mock(MyApp.User, [greet: 0], "Hello, Mocked User!")

        assert MyApp.Greeter.greet_user() == "Hello, Mocked User!"
        assert_called! MyApp.User, :greet, args: [], times: 1
      end
    end

## mock/3

Function used to create mock in context of single test process.

Mock created in test won't leak to another process (other test, spawned Task, GenServer...).
It can be used safely in asynchronous tests.

Mocks can be created with static value:

    mock Mod, [fun: 2], "mocked value"

or function:

    mock Mod, [fun: 2], fn(_, arg2) -> arg2 end

Keep in mind that function inside mock must have same arity as
original one.

This:

    mock Mod, [fun: 2], &to_string/1

will raise an error.

It is also possible to mock function with given name and any arity

    mock Mod, :fun, "mocked value"

but this version doesn't support function as value.

Also, multiple mocks for same module are chainable

    Mod
    |> mock(:fun1, "value")
    |> mock([fun2: 1], &string/1)
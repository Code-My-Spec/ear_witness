# Mockery.Macro

Provides macros that enable mocking and assertions.

This module should be included in your own modules with `use Mockery.Macro`.

It imports the macros defined here and sets up compilation option to suppress warnings
about **Mockery.Proxy.MacroProxy**.

## Example

    defmodule Foo do
      use Mockery.Macro

      def call_bar do
        mockable(Bar).bar()
      end
    end

## __using__/1

Injects Mockery helper macros into the calling module.

When you `use Mockery.Macro`, this macro:

- Imports the macros from `Mockery.Macro` (`mockable/1`, `mockable/2`,
  and `defmock/2`).
- When mockery is enabled (`config :mockery, :enable, true`),
  adds `@compile {:no_warn_undefined, Mockery.Proxy.MacroProxy}`
  so the compiler does not warn when `Mockery.Proxy.MacroProxy` is referenced.

## Options

- `suppress_dialyzer_warnings: true | false` (default: `false`)

  See the ["Dialyzer"](#__using__/1-dialyzer) section for more information

## Example

    defmodule MyApp.Module do
      use Mockery.Macro

      ...
    end

## Dialyzer

We recommend running Dialyzer in an environment where Mockery is not enabled
(for example, `:dev`) so Dialyzer analyzes the original modules rather than the injected
proxy module.

If it is not possible to run Dialyzer in an environment with Mockery disabled, setting
`use Mockery.Macro, suppress_dialyzer_warnings: true` will silence Dialyzer warnings that
are caused by functions that use `mockable/2`. This works by adding per-function
`@dialyzer {:nowarn_function, ...}` entries for functions that reference `mockable/2`.

`:suppress_dialyzer_warnings` can also be enabled globally:

    # config/test.exs
    config :mockery, Mockery.Macro, suppress_dialyzer_warnings: true

## mockable/2

Function used to prepare module for mocking/asserting.

This macro enables mocking and assertions by setting up a proxy to the original module.
When mocking is enabled via configuration (`config :mockery, enable: true`), it creates a proxy.
Otherwise, it returns the original module unchanged.

## Examples
#### Prepare for mocking

    defmodule Foo do
      use Mockery.Macro

      def foo do
        mockable(Bar).bar()
      end
    end

#### Prepare for mocking with global mock

    # test/support/global_mocks/bar.ex
    defmodule BarGlobalMock do
      def bar, do: :mocked
    end

    # lib/foo.ex
    defmodule Foo do
      use Mockery.Macro

      def foo do
        mockable(Bar, by: BarGlobalMock).bar()
      end
    end

> #### Potential issues {: .warning}
>
> Output of `mockable/2` macro should not be bind to variable or module attribute.
> If it happens, you'll see a compilation warning at best, and in the worst case Mockery won't
> work correctly.
>
> Examples of invalid usage:
>     @var mockable(Foo)
>
>     var = mockable(Foo)

## defmock/3

Defines a private macro that expands to `mockable/1` or `mockable/2`.

## Examples

    defmock :foo, Foo
    defmock :bar, Bar, by: GlobalMock

These expand to:

    defmacrop foo do
      quote do: mockable(Foo)
    end

    defmacrop bar do
      quote do: mockable(Bar, by: GlobalMock)
    end

This macro allows you to refactor code like this:

    def my_function do
      mockable(Bar, by: GlobalMock).function_call()
    end

Into a cleaner form:

    defmock :bar, Bar, by: GlobalMock

    def my_function do
      bar().function_call()
    end
# Ratio

This module allows you to use Rational numbers in Elixir, to enable exact calculations with all numbers big and small.

`Ratio` defines arithmetic and comparison operations to work with rational numbers.


This module also contains:
- a guard-safe `is_rational/1` check.
- a `compare/2` function for use with e.g. `Enum.sort`.
- `to_float/1` to (lossly) convert a rational into a float.

# Shorthand infix construction operator

Since version 4.0, `Ratio` no longer defines an infix operator to create rational numbers.
Instead, rational numbers are made using `Ratio.new`,
and as the output from using an existing `Ratio` struct with a mathematical operation.

If you do want to use an infix operator such as
`<~>` (supported in all Elixir versions)
or `<|>` (deprecated in Elixir v1.14, the default of older versions of the `Ratio` library)

you can add the following one-liner to the module(s) in which you want to use it:

```elixir
defdelegate numerator <~> denominator, to: Ratio, as: :new
```

## Inline Math Operators and Casting

Ratio interopts with the `Numbers` library:
If you want to overload Elixir's builtin math operators, you can use `use Numbers, overload_operators: true`.

This also allows you to pass in a rational number as one argument
and an integer, float or Decimal (if you have installed the `Decimal` library),
which are then cast to rational numbers whenever necessary.

``` elixir
defmodule IDoAlotOfMathHere do
  defdelegate numerator <~> denominator, to: Ratio, as: :new
  use Numbers, overload_operators: true

  def calculate(input) do
    num = input <~> 2
    result = num * 2 + (3 <~> 4) * 5.0
    result / 2
  end
end
```

```
iex> IDoAlotOfMathHere.calculate(42)
Ratio.new(183, 8)
```

## new/2

Creates a new Rational number.
This number is simplified to the most basic form automatically.

Rational numbers with a `0` as denominator are not allowed.

Note that it is recommended to use integer numbers for the numerator and the denominator.

## Floats

*If possible, don't use them.*

Using Floats for the numerator or denominator is possible, however, because base-2 floats cannot represent all base-10 fractions properly, the results might be different from what you might expect.
See [The Perils of Floating Point](http://www.lahey.com/float.htm) for more information about this.

Floats are converted into rationals by using `Float.ratio` (since version 3.0).

## Decimals

To use `Decimal` parameters, the [decimal](https://hex.pm/packages/decimal) library must
be configured in `mix.exs`.

## Examples

    iex> Ratio.new(1, 2)
    Ratio.new(1, 2)
    iex> Ratio.new(100, 300)
    Ratio.new(1, 3)
    iex> Ratio.new(1.5, 4)
    Ratio.new(3, 8)
    iex> Ratio.new(Ratio.new(3, 2), 3)
    Ratio.new(1, 2)
    iex> Ratio.new(Ratio.new(3, 3), 2)
    Ratio.new(1, 2)
    iex> Ratio.new(Ratio.new(3, 2), Ratio.new(1, 3))
    Ratio.new(9, 2)

## abs/1

Returns the absolute version of the given number (which might be an integer, float or Rational).

## Examples

    iex>Ratio.abs(Ratio.new(-5, 2))
    Ratio.new(5, 2)

## sign/1

Returns the sign of the given number (which might be an integer, float or Rational)

This is:

 - 1 if the number is positive.
 - -1 if the number is negative.
 - 0 if the number is zero.

## numerator/1

Converts the passed *number* as a Rational number, and extracts its denominator.
For integers returns the passed number itself.

## denominator/1

Treats the passed *number* as a Rational number, and extracts its denominator.
For integers, returns `1`.

## add/2

Adds two rational numbers.

    iex> Ratio.add(Ratio.new(1, 4), Ratio.new(2, 4))
    Ratio.new(3, 4)

For ease of use, `rhs` is allowed to be an integer as well:

    iex> Ratio.add(Ratio.new(1, 4), 2)
    Ratio.new(9, 4)

To perform addition where one of the operands might be another numeric type,
use `Numbers.add/2` instead, as this will perform the required coercions
between the number types:

    iex> Ratio.add(Ratio.new(1, 3), Decimal.new("3.14"))
    ** (FunctionClauseError) no function clause matching in Ratio.add/2

    iex> Numbers.add(Ratio.new(1, 3), Decimal.new("3.14"))
    Ratio.new(521, 150)

## sub/2

Subtracts the rational number *rhs* from the rational number *lhs*.

    iex> Ratio.sub(Ratio.new(1, 4), Ratio.new(2, 4))
    Ratio.new(-1, 4)

For ease of use, `rhs` is allowed to be an integer as well:

    iex> Ratio.sub(Ratio.new(1, 4), 2)
    Ratio.new(-7, 4)

To perform addition where one of the operands might be another numeric type,
use `Numbers.sub/2` instead, as this will perform the required coercions
between the number types:

    iex> Ratio.sub(Ratio.new(1, 3), Decimal.new("3.14"))
    ** (FunctionClauseError) no function clause matching in Ratio.sub/2

    iex> Numbers.sub(Ratio.new(1, 3), Decimal.new("3.14"))
    Ratio.new(-421, 150)

## minus/1

Negates the given rational number.

## Examples

iex> Ratio.minus(Ratio.new(5, 3))
Ratio.new(-5, 3)

## mult/2

Multiplies two rational numbers.

    iex> Ratio.mult( Ratio.new(1, 3), Ratio.new(1, 2))
    Ratio.new(1, 6)

For ease of use, allows `rhs` to be an integer as well as a `Ratio` struct.

    iex> Ratio.mult( Ratio.new(1, 3), 2)
    Ratio.new(2, 3)

To perform multiplication where one of the operands might be another numeric type,
use `Numbers.mult/2` instead, as this will perform the required coercions
between the number types:

    iex> Ratio.mult( Ratio.new(1, 3), Decimal.new("3.14"))
    ** (FunctionClauseError) no function clause matching in Ratio.mult/2

    iex> Numbers.mult( Ratio.new(1, 3), Decimal.new("3.14"))
    Ratio.new(157, 150)

## div/2

Divides the rational number `lhs` by the rational number `rhs`.

    iex> Ratio.div(Ratio.new(2, 3), Ratio.new(8, 5))
    Ratio.new(5, 12)

For ease of use, allows `rhs` to be an integer as well as a `Ratio` struct.

    iex> Ratio.div(Ratio.new(2, 3), 10)
    Ratio.new(2, 30)

To perform division where one of the operands might be another numeric type,
use `Numbers.div/2` instead, as this will perform the required coercions
between the number types:

    iex> Ratio.div(Ratio.new(2, 3), Decimal.new(10))
    ** (FunctionClauseError) no function clause matching in Ratio.div/2

    iex> Numbers.div(Ratio.new(2, 3), Decimal.new(10))
    Ratio.new(2, 30)

## compare/2

Compares two rational numbers, returning `:lt`, `:eg` or `:gt`
depending on whether *a* is less than, equal to or greater than *b*, respectively.

This function is able to compare rational numbers against integers or floats as well.

This function accepts other types as input as well, comparing them using Erlang's Term Ordering.
This is mostly useful if you have a collection that contains other kinds of numbers (builtin integers or floats) as well.

## eq?/2

True if *a* is equal to *b*

## gt?/2

True if *a* is larger than or equal to *b*

## lt?/2

True if *a* is smaller than *b*

## gte?/2

True if *a* is larger than or equal to *b*

## lte?/2

True if *a* is smaller than or equal to *b*

## equal?/2

True if *a* is equal to *b*?

## pow/2

returns *x* to the *n* th power.

*x* is allowed to be an integer, rational or float (in the last case, this is first converted to a rational).

Will give the answer as a rational number when applicable.
Note that the exponent *n* is only allowed to be an integer.

(so it is not possible to compute roots using this function.)

## Examples

    iex> Ratio.pow(Ratio.new(2), 4)
    Ratio.new(16, 1)
    iex> Ratio.pow(Ratio.new(2), -4)
    Ratio.new(1, 16)
    iex> Ratio.pow(Ratio.new(3, 2), 10)
    Ratio.new(59049, 1024)
    iex> Ratio.pow(Ratio.new(10), 0)
    Ratio.new(1, 1)

## to_float/1

Converts the given *number* to a Float. As floats do not have arbitrary precision, this operation is generally not reversible.

## to_float_error/1

Returns a tuple, where the first element is the result of `to_float(number)` and
the second is a conversion error.

The conversion error is calculated by subtracting the original number from the
conversion result.

## Examples

    iex> Ratio.to_float_error(Ratio.new(1, 2))
    {0.5, Ratio.new(0, 1)}
    iex> Ratio.to_float_error(Ratio.new(2, 3))
    {0.6666666666666666, Ratio.new(-1, 27021597764222976)}

## to_string/1

Returns a binstring representation of the Rational number.
If the denominator is `1` it will still be printed wrapped with `Ratio.new`.

## Examples

    iex> Ratio.to_string Ratio.new(10, 7)
    "Ratio.new(10, 7)"
    iex> Ratio.to_string Ratio.new(10, 2)
    "Ratio.new(5, 1)"

## floor/1

Rounds a number (rational, integer or float) to the largest whole number less than or equal to num.
For negative numbers, this means we are rounding towards negative infinity.


iex> Ratio.floor(Ratio.new(1, 2))
0
iex> Ratio.floor(Ratio.new(5, 4))
1
iex> Ratio.floor(Ratio.new(-3, 2))
-2

## ceil/1

Rounds a number (rational, integer or float) to the largest whole number larger than or equal to num.
For negative numbers, this means we are rounding towards negative infinity.


iex> Ratio.ceil(Ratio.new(1, 2))
1
iex> Ratio.ceil(Ratio.new(5, 4))
2
iex> Ratio.ceil(Ratio.new(-3, 2))
-1
iex> Ratio.ceil(Ratio.new(400))
400

## trunc/1

Returns the integer part of number.

## Examples

    iex> Ratio.trunc(1.7)
    1
    iex> Ratio.trunc(-1.7)
    -1
    iex> Ratio.trunc(3)
    3
    iex> Ratio.trunc(Ratio.new(5, 2))
    2
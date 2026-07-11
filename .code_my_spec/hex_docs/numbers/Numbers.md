# Numbers

Allows you to use arithmetical operations on _any_ type
that implements the proper protocols.

For each arithmetical operation, a different protocol is used
so that types for which only a subset of these operations makes sense
can still work with those.

## Basic Usage

Usually, `Numbers` is used in another module by using
`alias Numbers, as: N`, followed by calling the functions using
this aliased but still descriptive syntax:
`total_price = N.mult(N.add(price, fee), vat)`

Because `Numbers` dispatches based on protocol definitions,
you only need to swap what kind of arguments are used
to change the type of the result.


## Overloaded Operators

As explicit opt-in functionality, `Numbers` will add overloaded
operators to your module, if you write `use Numbers, overload_operators: true`

This will alter `a + b`, `a - b`, `a * b`, `a / b`, `-a` and `abs(a)` to
dispatch to the corresponding functions in the `Numbers` module.

Do note that these overloaded operator versions are _not_ allowed in guard tests,
which is why this functionality is only provided as an opt-in option to use
when an algorithm would be too unreadable without it.


## Examples:

Using built-in numbers:

    iex> alias Numbers, as: N
    iex> N.add(1, 2)
    3
    iex> N.mult(3,5)
    15
    iex> N.mult(1.5, 100)
    150.0

Using Decimals: (requires the [Decimal](https://hex.pm/packages/decimal) library.)

    iex> alias Numbers, as: N
    iex> d = Decimal.new(2)
    iex> N.div(d, 10)
    #Decimal<0.2>
    iex> small_number = N.div(d, 1234)
    #Decimal<0.001620745542949756888168557536>
    iex> N.pow(small_number, 100)
    #Decimal<9.364478495445313580679473524E-280>

## Defining your own Numbers implementations

See `Numbers.Protocols` for a full explanation on how to do this.

## add/2

Adds two Numeric `a` and `b` together.

Depends on an implementation existing of `Numbers.Protocol.Addition`

## sub/2

Subtracts the Numeric `b` from the Numeric `a`.

Depends on an implementation existing of `Numbers.Protocol.Subtraction`

## mult/2

Multiplies the Numeric `a` with the Numeric `b`

Depends on an implementation existing of `Numbers.Protocol.Multiplication`

## div/2

Divides the Numeric `a` by `b`.

Note that this is a supposed to be a full (non-truncated) division;
no rounding or truncation is supposed to happen, even when calculating with integers.

Depends on an implementation existing of `Numbers.Protocol.Division`

## pow/2

Power function: computes `base^exponent`,
where `base` is Numeric,
and `exponent` _has_ to be an integer.

_(This means that it is impossible to calculate roots by using this function.)_

Depends on an implementation existing of `Numbers.Protocol.Exponentiation`

## __using__/1

Convert the custom Numeric struct
to the built-in float datatype.

This operation might be lossy, losing precision in the process.
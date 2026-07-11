# Numbers.Helper

Helper functions that might make the implementation
of Numbers for your own numberlike types easier.

## pow_by_sq/2

Performs 'Exponentiation by Squaring',
which is a reasonably fast algorithm to compute integer powers,
by performing log(n) multiplication steps.

Depends on an implementation existing of `Numbers.Protocols.Multiplication`,
as well as (to support negative powers) an implementation of `Numbers.Protocols.Division`.
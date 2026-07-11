# Complex.Kernel

Provides operator overloading for Elixir operators.

When you `use Complex.Kernel`, be aware that the arithmetic operators
won't work in clause guards. For that you need to use the fully qualified
functions (i.e.: `when Kernel.+(a, b) == 1`) instead.
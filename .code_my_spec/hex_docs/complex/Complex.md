# Complex

*Complex* is a library that brings complex number support to Elixir.

Each complex number is represented as a `%Complex{}` struct, that holds
the real and imaginary parts. There are functions for the creation and
manipulation of complex numbers.

This module implements mathematical functions such as `add/2`, `subtract/2`,
`divide/2`, and `multiply/2` that subtitute the `+`, `-`, `/` and `*` operators.

Operator overloading is provided through `Complex.Kernel`

### Examples

    iex> Complex.new(3, 4)
    %Complex{im: 4.0, re: 3.0}

    iex> Complex.new(0, 1)
    %Complex{im: 1.0, re: 0.0}

## to_string/1

Conveniency function that is used to implement the `String.Chars` and `Inspect` protocols.

## new/2

Returns a new complex with specified real and imaginary components. The
imaginary part defaults to zero so a real number can be created with `new/1`.

### See also

`from_polar/2`

### Examples

    iex> Complex.new(3, 4)
    %Complex{im: 4.0, re: 3.0}

    iex> Complex.new(2)
    %Complex{im: 0.0, re: 2.0}

    iex> Complex.new(:infinity)
    %Complex{im: 0.0, re: :infinity}

    iex> Complex.new(:nan, :neg_infinity)
    %Complex{im: :neg_infinity, re: :nan}

## parse/1

Parses a complex number from a string.  The values of the real and imaginary
parts must be represented by a float, including decimal and at least one
trailing digit (e.g. 1.2, 0.4).

### See also

`new/2`

### Examples

    iex> Complex.parse("1.1+2.2i")
    {%Complex{im: 2.2, re: 1.1}, ""}

    iex> Complex.parse("1+2i")
    {%Complex{im: 2.0, re: 1.0}, ""}

    iex> Complex.parse("2-3i")
    {%Complex{im: -3.0, re: 2.0}, ""}

    iex> Complex.parse("-1.0-3.i")
    {%Complex{im: -3.0, re: -1.0}, ""}

    iex> Complex.parse("-1.0+3.i 2.2+3.3i")
    {%Complex{im: 3.0, re: -1.0}, " 2.2+3.3i"}

    iex> Complex.parse("1e-4-3e-3i")
    {%Complex{im: -3.0e-3, re: 1.0e-4}, ""}

    iex> Complex.parse("2i")
    {%Complex{im: 2.0, re: 0.0}, ""}

    iex> Complex.parse("-3.0i")
    {%Complex{im: -3.0, re: 0.0}, ""}

    iex> Complex.parse("NaN+Infi")
    {%Complex{im: :infinity, re: :nan}, ""}

    iex> Complex.parse("-Inf+NaNi")
    {%Complex{im: :nan, re: :neg_infinity}, ""}

    iex> Complex.parse("Inf-NaNi")
    {%Complex{im: :nan, re: :infinity}, ""}

    iex> Complex.parse("Inf")
    {%Complex{im: 0.0, re: :infinity}, ""}

## phase/1

Returns the phase angle of the supplied complex, in radians.

### See also

`new/2`, `from_polar/2`

### Examples

    iex> Complex.phase(Complex.from_polar(1,:math.pi/2))
    1.5707963267948966

## to_polar/1

Returns the polar coordinates of the supplied complex.  That is, the
returned tuple {r,phi} is the magnitude and phase (in radians) of z.

### See also

`from_polar/2`

### Examples

    iex> Complex.to_polar(Complex.from_polar(1,:math.pi/2))
    {1.0, 1.5707963267948966}

## add/2

Returns a new complex that is the sum of the provided complex numbers.  Also
supports a mix of complex and number.

### See also

`div/2`, `multiply/2`, `subtract/2`

### Examples

    iex> Complex.add(Complex.from_polar(1, :math.pi/2), Complex.from_polar(1, :math.pi/2))
    %Complex{im: 2.0, re: 1.2246467991473532e-16}

    iex> Complex.add(Complex.new(4, 4), 1)
    %Complex{im: 4.0, re: 5.0}

    iex> Complex.add(2, Complex.new(4, 3))
    %Complex{im: 3.0, re: 6.0}

    iex> Complex.add(2, 3)
    5

    iex> Complex.add(2.0, 2)
    4.0

## subtract/2

Returns a new complex that is the difference of the provided complex numbers.
Also supports a mix of complex and number.

### See also

`add/2`, `div/2`, `multiply/2`

### Examples

    iex> Complex.subtract(Complex.new(1,2), Complex.new(3,4))
    %Complex{im: -2.0, re: -2.0}

    iex> Complex.subtract(Complex.new(1, 2), 3)
    %Complex{im: 2.0, re: -2.0}

    iex> Complex.subtract(10, Complex.new(1, 2))
    %Complex{im: -2.0, re: 9.0}

## multiply/2

Returns a new complex that is the product of the provided complex numbers.
Also supports a mix of complex and number.

### See also

`add/2`, `div/2`, `subtract/2`

### Examples

    iex> Complex.multiply(Complex.new(1,2), Complex.new(3,4))
    %Complex{im: 10.0, re: -5.0}

    iex> Complex.multiply(Complex.new(0, 1), Complex.new(0, 1))
    %Complex{im: 0.0, re: -1.0}

    iex> Complex.multiply(Complex.new(1, 2), 3)
    %Complex{im: 6.0, re: 3.0}

    iex> Complex.multiply(3, Complex.new(1, 2))
    %Complex{im: 6.0, re: 3.0}

    iex> Complex.multiply(-2, Complex.new(:infinity, :neg_infinity))
    %Complex{im: :nan, re: :nan}

## square/1

Returns a new complex that is the square of the provided complex number.

### See also

`multiply/2`

### Examples

    iex> Complex.square(Complex.new(2.0, 0.0))
    %Complex{im: 0.0, re: 4.0}

    iex> Complex.square(Complex.new(0, 1))
    %Complex{im: 0.0, re: -1.0}

## divide/2

Returns a new complex that is the ratio (division) of the provided complex
numbers.

### See also

`add/2`, `multiply/2`, `subtract/2`

### Examples

    iex> Complex.divide(Complex.from_polar(1, :math.pi/2), Complex.from_polar(1, :math.pi/2))
    %Complex{im: 0.0, re: 1.0}

## abs/1

Returns the magnitude (length) of the provided complex number.

### See also

`new/2`, `phase/1`

### Examples

    iex> Complex.abs(Complex.from_polar(1, :math.pi/2))
    1.0

## abs_squared/1

Returns the square of the magnitude of the provided complex number.

The square of the magnitude is faster to compute---no square roots!

### See also

`new/2`, `abs/1`

### Examples

    iex> Complex.abs_squared(Complex.from_polar(1, :math.pi/2))
    1.0

    iex> Complex.abs_squared(Complex.from_polar(2, :math.pi/2))
    4.0

## real/1

Returns the real part of the provided complex number.

### See also

`imag/1`

### Examples

    iex> Complex.real(Complex.new(1, 2))
    1.0

    iex> Complex.real(1)
    1

## imag/1

Returns the imaginary part of the provided complex number.
If a real number is provided, 0 is returned.

### See also

`real/1`

### Examples

    iex> Complex.imag(Complex.new(1, 2))
    2.0

    iex> Complex.imag(1)
    0

## conjugate/1

Returns a new complex that is the complex conjugate of the provided complex
number.

If $z = a + bi$, $conjugate(z) = z^* = a - bi$

### See also

`abs/2`, `phase/1`

### Examples

    iex> Complex.conjugate(Complex.new(1,2))
    %Complex{im: -2.0, re: 1.0}

## sqrt/1

Returns a new complex that is the complex square root of the provided
complex number.

### See also

`abs/1`, `cbrt/1`, `phase/1`

### Examples

    iex> Complex.sqrt(Complex.from_polar(2,:math.pi))
    %Complex{im: 1.4142135623730951, re: 8.659560562354933e-17}

## cbrt/1

Returns a new number that is the complex cube root of the provided
number.

Returns the principal branch of the cube root for complex inputs.

### See also

`abs/1`, `phase/1`, `sqrt/1`

### Examples

    iex> Complex.cbrt(-8)
    -2.0

When a negative number is given as a complex input,
the output now changes. Instead of still giving a
negative number, we now get a number with phase
$\frac{\pi}{3}$

    iex> z = Complex.cbrt(Complex.new(-8, 0))
    %Complex{re: 1.0000000000000002, im: 1.7320508075688772}
    iex> Complex.abs(z)
    2.0
    iex> Complex.phase(z)
    1.0471975511965976
    iex> :math.pi() / 3
    1.0471975511965976

## exp/1

Returns a new complex that is the complex exponential of the provided
complex number: $exp(z) = e^z$.

### See also

`log/1`

### Examples

    iex> Complex.exp(Complex.from_polar(2,:math.pi))
    %Complex{im: 3.3147584285483636e-17, re: 0.1353352832366127}

## log/1

Returns a new complex that is the complex natural log of the provided
complex number, $log(z) = log_e(z)$.

### See also

`exp/1`

### Examples

    iex> Complex.log(Complex.from_polar(2,:math.pi))
    %Complex{im: 3.141592653589793, re: 0.6931471805599453}

## log10/1

Returns a new complex that is the complex log base 10 of the provided
complex number.

### See also

`log/1`

### Examples

    iex> Complex.log10(Complex.from_polar(2,:math.pi))
    %Complex{im: 1.3643763538418412, re: 0.30102999566398114}

## log2/1

Returns a new complex that is the complex log base 2 of the provided
complex number.

### See also

`log/1`, `log10/1`

### Examples

    iex> Complex.log2(Complex.from_polar(2,:math.pi))
    %Complex{im: 4.532360141827194, re: 1.0}

## pow/2

Returns a new complex that is the provided parameter a raised to the
complex power b.

### See also

`log/1`, `log10/1`

### Examples

    iex> Complex.pow(Complex.from_polar(2,:math.pi), Complex.new(0, 1))
    %Complex{im: 0.027612020368333014, re: 0.03324182700885666}

## sin/1

Returns a new complex that is the sine of the provided parameter.

### See also

`cos/1`, `tan/1`

### Examples

    iex> Complex.sin(Complex.from_polar(2,:math.pi))
    %Complex{im: -1.0192657827055095e-16, re: -0.9092974268256817}

## negate/1

Returns a new complex that is the "negation" of the provided parameter.
That is, the real and imaginary parts are negated.

### See also

`new/2`

### Examples

    iex> Complex.negate(Complex.new(3,5))
    %Complex{im: -5.0, re: -3.0}

## asin/1

Returns a new complex that is the inverse sine (i.e., arcsine) of the
provided parameter.

### See also

`sin/1`

### Examples

    iex> Complex.asin(Complex.from_polar(2,:math.pi))
    %Complex{im: 1.3169578969248164, re: -1.5707963267948966}

## cos/1

Returns a new complex that is the cosine of the provided parameter.

### See also

`sin/1`, `tan/1`

### Examples

    iex> Complex.cos(Complex.from_polar(2,:math.pi))
    %Complex{im: 2.2271363664699914e-16, re: -0.4161468365471424}

## acos/1

Returns a new complex that is the inverse cosine (i.e., arccosine) of the
provided parameter.

### See also

`cos/1`

### Examples

    iex> Complex.acos(Complex.from_polar(2,:math.pi))
    %Complex{im: 1.3169578969248164, re: -3.141592653589793}

## tan/1

Returns a new complex that is the tangent of the provided parameter.

### See also

`sin/1`, `cos/1`

### Examples

    iex> Complex.tan(Complex.from_polar(2,:math.pi))
    %Complex{im: 1.4143199004457915e-15, re: 2.185039863261519}

## atan/1

Returns a new complex that is the inverse tangent (i.e., arctangent) of the
provided parameter.

### See also

`tan/1`, `atan2/2`

### Examples

    iex> Complex.atan(Complex.from_polar(2,:math.pi))
    %Complex{im: 0.0, re: -1.1071487177940904}

    iex> Complex.tan(Complex.atan(Complex.new(2,3)))
    %Complex{im: 2.9999999999999996, re: 2.0}

## atan2/2

$atan2(b, a)$ returns the phase of the complex number $a + bi$.

### See also

`tan/1`, `atan/1`

### Examples

    iex> phase = Complex.atan2(2, 2)
    iex> phase == :math.pi() / 4
    true

    iex> phase = Complex.atan2(2, Complex.new(0))
    iex> phase == Complex.new(:math.pi() / 2, 0)
    true

## cot/1

Returns a new complex that is the cotangent of the provided parameter.

### See also

`sin/1`, `cos/1`, `tan/1`

### Examples

    iex> Complex.cot(Complex.from_polar(2,:math.pi))
    %Complex{im: -2.962299212953233e-16, re: 0.45765755436028577}

## acot/1

Returns a new complex that is the inverse cotangent (i.e., arccotangent) of
the provided parameter.

### See also

`cot/1`

### Examples

    iex> Complex.acot(Complex.from_polar(2,:math.pi))
    %Complex{im: -9.71445146547012e-17, re: -0.46364760900080615}

    iex> Complex.cot(Complex.acot(Complex.new(2,3)))
    %Complex{im: 2.9999999999999996, re: 1.9999999999999993}

## sec/1

Returns a new complex that is the secant of the provided parameter.

### See also

`sin/1`, `cos/1`, `tan/1`

### Examples

    iex> Complex.sec(Complex.from_polar(2,:math.pi))
    %Complex{im: -1.2860374461837126e-15, re: -2.402997961722381}

## asec/1

Returns a new complex that is the inverse secant (i.e., arcsecant) of
the provided parameter.

### See also

`sec/1`

### Examples

    iex> Complex.asec(Complex.from_polar(2,:math.pi))
    %Complex{im: -0.0, re: 2.0943951023931957}

    iex> Complex.sec(Complex.asec(Complex.new(2,3)))
    %Complex{im: 2.9999999999999982, re: 1.9999999999999987}

## csc/1

Returns a new complex that is the cosecant of the provided parameter.

### See also

`sec/1`, `sin/1`, `cos/1`, `tan/1`

### Examples

    iex> Complex.csc(Complex.from_polar(2,:math.pi))
    %Complex{im: 1.2327514463765779e-16, re: -1.0997501702946164}

## acsc/1

Returns a new complex that is the inverse cosecant (i.e., arccosecant) of
the provided parameter.

### See also

`sec/1`

### Examples

    iex> Complex.acsc(Complex.from_polar(2,:math.pi))
    %Complex{im: 0.0, re: -0.5235987755982988}

    iex> Complex.csc(Complex.acsc(Complex.new(2,3)))
    %Complex{im: 3.0, re: 1.9999999999999993}

## sinh/1

Returns a new complex that is the hyperbolic sine of the provided parameter.

### See also

`cosh/1`, `tanh/1`

### Examples

    iex> Complex.sinh(Complex.from_polar(2,:math.pi))
    %Complex{im: 9.214721821703068e-16, re: -3.626860407847019}

## asinh/1

Returns a new complex that is the inverse hyperbolic sine (i.e., arcsinh) of
the provided parameter.

### See also

`sinh/1`

### Examples

    iex> Complex.asinh(Complex.from_polar(2,:math.pi))
    %Complex{im: 1.0953573965284052e-16, re: -1.4436354751788099}

    iex> Complex.sinh(Complex.asinh(Complex.new(2,3)))
    %Complex{im: 3.0, re: 2.0000000000000004}

## cosh/1

Returns a new complex that is the hyperbolic cosine of the provided
parameter.

### See also

`sinh/1`, `tanh/1`

### Examples

    iex> Complex.cosh(Complex.from_polar(2,:math.pi))
    %Complex{im: -8.883245978848233e-16, re: 3.7621956910836314}

## acosh/1

Returns a new complex that is the inverse hyperbolic cosine (i.e., arccosh)
of the provided parameter.

### See also

`cosh/1`

### Examples

    iex> Complex.acosh(Complex.from_polar(2,:math.pi))
    %Complex{im: -3.141592653589793, re: -1.3169578969248164}

## tanh/1

Returns a new complex that is the hyperbolic tangent of the provided
parameter.

### See also

`sinh/1`, `cosh/1`

### Examples

    iex> Complex.tanh(Complex.from_polar(2,:math.pi))
    %Complex{im: 1.7304461302709575e-17, re: -0.9640275800758169}

## atanh/1

Returns a new complex that is the inverse hyperbolic tangent (i.e., arctanh)
of the provided parameter.

### See also

`tanh/1`

### Examples

    iex> Complex.atanh(Complex.from_polar(2,:math.pi))
    %Complex{im: 1.5707963267948966, re: -0.5493061443340549}

    iex> Complex.tanh(Complex.atanh(Complex.new(2,3)))
    %Complex{im: 3.0, re: 1.9999999999999993}

## sech/1

Returns a new complex that is the hyperbolic secant of the provided
parameter.

### See also

`sinh/1`, `cosh/1`, `tanh/1`

### Examples

    iex> Complex.sech(Complex.from_polar(2,:math.pi))
    %Complex{im: 6.27608655779184e-17, re: 0.26580222883407967}

## asech/1

Returns a new complex that is the inverse hyperbolic secant (i.e., arcsech)
of the provided parameter.

### See also

`sech/1`

### Examples

    iex> Complex.asech(Complex.from_polar(2,:math.pi))
    %Complex{im: -2.0943951023931953, re: 0.0}

    iex> Complex.sech(Complex.asech(Complex.new(2,3)))
    %Complex{im: 2.999999999999999, re: 2.0}

## csch/1

Returns a new complex that is the hyperbolic cosecant of the provided
parameter.

### See also

`sinh/1`, `cosh/1`, `tanh/1`

### Examples

    iex> Complex.csch(Complex.from_polar(2,:math.pi))
    %Complex{im: -7.00520014334671e-17, re: -0.2757205647717832}

## acsch/1

Returns a new complex that is the inverse hyperbolic cosecant (i.e., arccsch)
of the provided parameter.

### See also

`csch/1`

### Examples

    iex> Complex.acsch(Complex.from_polar(2,:math.pi))
    %Complex{im: -5.4767869826420256e-17, re: -0.48121182505960336}

    iex> Complex.csch(Complex.acsch(Complex.new(2,3)))
    %Complex{im: 3.0000000000000018, re: 1.9999999999999984}

## coth/1

Returns a new complex that is the hyperbolic cotangent of the provided
parameter.

### See also

`sinh/1`, `cosh/1`, `tanh/1`

### Examples

    iex> Complex.coth(Complex.from_polar(2,:math.pi))
    %Complex{im: -1.8619978115303644e-17, re: -1.037314720727548}

## acoth/1

Returns a new complex that is the inverse hyperbolic cotangent (i.e., arccoth)
of the provided parameter.

### See also

`coth/1`

### Examples

    iex> Complex.acoth(Complex.from_polar(2,:math.pi))
    %Complex{im: -8.164311994315688e-17, re: -0.5493061443340548}

    iex> Complex.coth(Complex.acoth(Complex.new(2,3)))
    %Complex{im: 2.999999999999998, re: 2.000000000000001}
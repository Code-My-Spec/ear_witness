# Unifex.CodeGenerator.BaseType

Behaviour and abstraction over type-specific code generation.

When invoking callbacks for type `:type` and interface `Interface` it searches for
a module that implements given callback in the following order:
- `Unifex.CodeGenerator.BaseTypes.Type.Interface`
- `Unifex.CodeGenerator.BaseTypes.Type`
- `Unifex.CodeGenerator.BaseTypes.Default.Interface`

## __using__/1

Returns level of pointer nesting of native type.

## generate_arg_serialize/4

Provides a way to convert native variable `name` into `UNIFEX_TERM`

Tries to get value from type-specific module, uses `enif_make_#{type}` as fallback value.

## generate_declaration/5

Generates a declaration of parameter (to be placed in function header) based on `c:generate_native_type/1` and
provided `name`.

Uses `type` as fallback for `c:generate_native_type/1`

When mode is set to :const_unless_ptr_on_ptr, function will choose to behave like it would be set to :default or :const,
depending on value returned by `ptr_level(type, code_generator, ctx)`.
This mode can be used in places, when in general, you want to have declaration of variable with const type, but using :const
mode would generate code, that would require explicit cast to avoid generating warnings during compilation - e.g. in C,
passing argument of type `char **` to function, that expects argument of type `char const * const *` without any explicit cast,
will generate such a warning

## generate_initialization/4

Generates an initialization of variable content. Should be paired with `generate_destruction/1`

Returns an empty string if the type does not provide initialization

## generate_destruction/4

Generates an destrucition of variable content. Should be paired with `generate_initialization/1`

Returns an empty string if the type does not provide destructor

## generate_arg_parse/6

Generates parsing of UNIFEX_TERM `argument` into the native variable
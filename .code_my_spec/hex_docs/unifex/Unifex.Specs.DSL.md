# Unifex.Specs.DSL

Module exporting macros that can be used to define Unifex specs.

Example of such specs is provided below:

    module Membrane.Element.Mad.Decoder.Native

    type position :: :manager | :developer | :intern | :product_owner

    type personal_data :: %PersonalData{
      age: int,
      experience: int,
      name: string
    }

    spec get_salary(person :: personal_data, person_position :: position) ::
           {:ok :: label, salary :: int}
           {:error :: label, :unemployed :: label}

    spec create() :: {:ok :: label, state}

    spec decode_frame(payload, offset :: int, state) ::
           {:ok :: label, {payload, bytes_used :: long, sample_rate :: long, channels :: int}}
           | {:error :: label, :buflen :: label}
           | {:error :: label, :malformed :: label}
           | {:error :: label, {:recoverable :: label, bytes_to_skip :: int}}

    dirty :cpu, decode_frame: 3

    sends {:example_msg :: label, number :: int}

According to this specification, module `Membrane.Element.Mad.Decoder.Native` should contain 2 functions: `create/0`
and `decode_frame/3` (which is a cpu-bound dirty NIF). The module should use `Unifex.Loader` to provide access to
these functions. What is more, messages of the form `{:example_msg, integer}` can be sent from the native code to
erlang processes.

Following types definitions will be generated and will be available from native code

    #ifdef __cplusplus
    enum Position { MANAGER, DEVELOPER, INTERN, PRODUCT_OWNER };
    #else
    enum Position_t { MANAGER, DEVELOPER, INTERN, PRODUCT_OWNER };
    typedef enum Position_t Position;
    #endif

    #ifdef __cplusplus
    struct personal_data {
      int age;
      int experience;
      char *name;
    };
    #else
    struct personal_data_t {
      int age;
      int experience;
      char *name;
    };
    typedef struct personal_data_t personal_data;
    #endif

The generated boilerplate would require implementation of the following functions:

    UNIFEX_TERM get_salary(UnifexEnv *env, personal_data person, Position person_position);
    UNIFEX_TERM create(UnifexEnv* env);
    UNIFEX_TERM decode_frame(UnifexEnv* env, UnifexPayload * payload, int offset, State* state);

Also the following functions that should be called to return results will be generated:

    UNIFEX_TERM get_salary_result_ok(UnifexEnv *env, int salary);
    UNIFEX_TERM get_salary_result_error_unemployed(UnifexEnv *env);
    UNIFEX_TERM create_result_ok(UnifexEnv* env, State* state);
    UNIFEX_TERM decode_frame_result_ok(UnifexEnv* env, UnifexPayload * payload,
                                       long bytes_used, long sample_rate, int channels);
    UNIFEX_TERM decode_frame_result_error_buflen(UnifexEnv* env);
    UNIFEX_TERM decode_frame_result_error_malformed(UnifexEnv* env);
    UNIFEX_TERM decode_frame_result_error_recoverable(UnifexEnv* env, int bytes_to_skip);

See docs for appropriate macros for more details.

## module/1

Defines module that exports native functions to Elixir world.

The module needs to be defined manually, but it can `use` `Unifex.Loader` to
have functions declared with `spec/1` automatically defined.

## spec/1

Defines native function specification.

The specification should be in the form of

    spec function_name(parameter1 :: parameter1_type, some_type, parameter3 :: parameter3_type, ...) ::
        {:label1 :: label, {result_value1 :: result_value1_type, some_type2, ...}}
        | {:label2 :: label, other_result_value2 :: other_result_value2_type}

## Parameters

Specs for parameters can either take the form of `parameter1 :: parameter1_type`
which will generate parameter with name `parameter1` of type `parameter1_type`
The other form - just a name, like `some_type` - will generate parameter `some_type`
of type `some_type`.

Custom types can be added by creating modules `Unifex.CodeGenerator.BaseTypes.Type` that implement
`Unifex.CodeGenerator.BaseType` behaviour. Then, they can by used in specs as `type`.

Each generated function gets additional `UnifexEnv* env` as the first parameter implicitly.

## Returned values

Specs for returned values contain a special type - `label`. An atom of type `label`
will be put literally in returned values by the special function generated for each
spec. Names of the generated functions start with Elixir function name
(e.g. `create`) followed by `_result_` part and then all the labels joined with `_`.

## Example

The example is provided in the moduledoc of this module.

## @/1

Defines native function documentation.
  Documentation will be visible in the generated docs.

  The documentation should be in the form of

      @doc """
      Documentation...
      """
      spec function_name...

## interface/1

Specifies interface, for example NIF or CNode.

It should be a module name (or list of module names) that will be prepended
with `Unifex.CodeGenerators`. If no interface is specified, it is automatically
detected basing on `Bundlex.Project` specification.

## state_type/1

Defines the state type, required for using `Unifex.CodeGenerator.BaseTypes.State`.

## dirty/2

Macro used for marking functions as dirty, i.e. performing long cpu-bound or
io-bound operations.

The macro should be used the following way:

    dirty type, function1: function1_arity, ...

when type is one of:
- `:cpu` - marks function as CPU-bound (maps to the `ERL_NIF_DIRTY_JOB_CPU_BOUND` erlang flag)
- `:io` - marks function as IO-bound (maps to the `ERL_NIF_DIRTY_JOB_IO_BOUND` erlang flag)

## sends/1

Defines terms that can be sent from the native code to elixir processes.

Creates native function that can be invoked to send specified data. Name of the
function starts with `send_` and is constructed from `label`s.

## callback/2

Defines names of callbacks invoked on specified hook.

The available hooks are:

* `:load` - invoked when the library is loaded. Callback must have the following typing:

  `int on_load(UnifexEnv *env, void ** priv_data)`

  The callback receives an `env` and a pointer to private data that is initialized
  with NULL and can be set to whatever should be passed to other callbacks.
  If callback returns anything else than 0, the library fails to load.

* `:upgrade` - called when the library is loaded while there is old code for this module
  with a native library loaded. Compared to `:load`, it also receives `old_priv_data`:

  `int on_upgrade(UnifexEnv* env, void** priv_data, void** old_priv_data)`

  Both old and new private data can be modified
  If this callback is not defined, the module code cannot be hot-swapped. Non-zero return
  value also prevents code upgrade.

* `:unload` - called when the code for module is unloaded. It has the following declaration:

  `void on_unload(UnifexEnv *env, void * priv_data)`

## type/1

Contains user custom type specification

Currently supported types are enums and structs

The struct specification should be in the form of

    type my_struct :: %My.Struct{
      field1: type1,
      field2: type2,
      ...
    }

The enum specification should be in the form of

    type my_enum :: :option_one | :option_two | :option_three | ...

Enum constants can be given an explicit value with `enum_value`

    type my_explicit_enum :: enum_value(:option_one, 1) | :option_two | :option_three | ...

The numeric value assigned to any enum constant can only be used from C/C++.
In Elixir, the atom must be used.

Struct or enums specified in such way can be used in like any other supported type, E.g.

    spec my_function(in_enum :: my_enum) :: {:ok :: label, out_struct :: my_struct}

Elixir definition of %My.Struct{} should contain every field listed in specification and is not generated by Unifex
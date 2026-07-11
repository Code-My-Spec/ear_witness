# Numbers.Protocols

A set of protocols that can be implemented for your data structure, to add `Numbers`-support to it. 

In older versions of `Numbers`, structures were required to follow a single, very strict, behaviour.
But because there are many different kind of structures that benefit from a numeric interface, including
those for which one or multiple of these operations cannot be (unambiguously) defined,
this has been split in these different protocols.

By using the different protocols, each data structure can 'pick and choose' what functionality
is supported. As protocol dispatching is used, the result should be a lot faster than in older
versions of Numbers, which performed behaviour-based runtime dispatch on the struct name.


## Coercion

Numbers does not automatically transform numbers from one type to another if one of the functions is called with two different types.

Frequently you do want to use other data types together with your custom data type. For this, a custom coercion can be specified,
using `Coerce.defcoercion/3` as exposed by the [`Coerce`](https://hex.pm/packages/coerce) library that `Numbers` depends on.
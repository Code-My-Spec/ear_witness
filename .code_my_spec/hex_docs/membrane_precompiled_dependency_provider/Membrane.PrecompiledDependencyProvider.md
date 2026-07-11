# Membrane.PrecompiledDependencyProvider

Module providing URLs for precompiled dependencies used by Membrane plugins.

Dependencies that are fully located in the repositories of `membraneframework-precompiled` will
be referred to as generic. Otherwise they will be referred to as non-generic.

## get_dependency_url/2

Get URL of a precompiled build of given dependency for a platform from which this function is being
called. 

A specific version of the dependency can be provided with `:version` option or through config 
(see `t:version_config/0`). If provided in both ways, the config value will be taken.
For generic dependencies this version needs to be the same as a release name from the
repository of the precompiled dependency, but without the leading "v". By default the latest
version is chosen.
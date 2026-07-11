# Membrane.Core.SubprocessSupervisor



## start_component/4

Starts a Membrane component under the supervisor

## start_utility/2

Starts a utility process under the supervisor.

The process will be terminated when the parent component dies.

## start_link_utility/2

Like `start_utility/2`, but links the spawned utility to the calling process.

## set_parent_component/2

Sets the calling Membrane component as the parent component for children and utilities
spawned with the supervisor.
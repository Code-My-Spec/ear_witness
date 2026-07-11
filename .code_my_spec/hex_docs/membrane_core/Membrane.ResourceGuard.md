# Membrane.ResourceGuard

Utility for handling resources that must be cleaned up after use.

This utility uses a separate process that allows registering functions
that are called when the owner process (passed to `start_link/1`) dies for
any reason. Each Membrane component spawns its resource guard on startup
and provides it via callback context.

### Example

    def handle_setup(ctx, state) do
      resource = MyResource.create()

      Membrane.ResourceGuard.register(ctx.resource_guard, fn ->
        MyResource.cleanup(resource)
      end)

      {:ok, %{state | my_resource: resource}}
    end

## register/3

Registers a resource cleanup function in the resource guard.

Registered functions are called in the order reverse to the registration order.
Function returns a tag of the registered cleanup function. Tag can be passed
under a `:tag` key in `opts`. Many functions can be registered with the same tag.
If there is no `:tag` key in `opts`, tag will be result of `make_ref()`.

## unregister/2

Unregisters a resource cleanup function from the resource guard.

All cleanup functions with tag `tag` are deleted.

## cleanup/1

Executes all cleanup functions registered in the resource gurard.

## cleanup/2

Executes cleanup functions registered with the specifc tag.

If many cleanup functions are registered with the same tag, all of them are executed.
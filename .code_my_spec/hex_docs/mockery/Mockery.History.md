# Mockery.History

Provides calls history for Mockery.Assertions macros.

It's disabled by default.
It can be enabled/disabled globally by following config

    config :mockery, history: true

Or for single test process

    Mockery.History.enable_history()
    Mockery.History.disable_history()

Process config has higher priority than global config

## enable_history/0

Enables history in scope of single test process

    use Mockery

    test "example" do
      #...

      enable_history()
      assert_called! Foo, :bar, args: [_, :a]
    end

## disable_history/0

Disables history in scope of single test process

    use Mockery

    test "example" do
      #...

      disable_history()
      assert_called! Foo, :bar, args: [_, :a]
    end
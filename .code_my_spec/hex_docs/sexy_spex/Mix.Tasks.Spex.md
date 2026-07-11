# Mix.Tasks.Spex

Run spex files - executable specifications for AI-driven development.

SexySpex provides a framework for writing executable specifications that serve as
both tests and living documentation, optimized for AI-driven development workflows.

Each spex file manages its own application lifecycle using setup_all and setup blocks:
- setup_all: Application startup and shutdown
- setup: State reset between tests
- Context passing between test steps
- Integration with external tools (like ScenicMCP for GUI testing)

## Usage

    mix spex                    # Run all spex files
    mix spex path/to/file.exs   # Run specific spex file
    mix spex --help             # Show this help

## Options

    --pattern       File pattern to match (default: test/spex/**/*_spex.exs)
    --verbose       Show detailed output
    --timeout       Test timeout in milliseconds (default: 60000)
    --manual        Interactive manual mode - step through each action

## Examples

    mix spex
    mix spex test/spex/user_login_spex.exs
    mix spex --pattern "**/integration_*_spex.exs"
    mix spex --only-spex --verbose
    mix spex --manual           # Interactive step-by-step mode

## Configuration

You can configure spex behavior in your config files:

    config :sexy_spex,
      manual_mode: false,
      step_delay: 0

Application lifecycle is handled in individual spex files using setup_all blocks.
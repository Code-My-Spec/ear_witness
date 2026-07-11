# SexySpex.DSL

Domain-specific language for writing executable specifications.

Provides macros for structuring specifications in a readable, executable format
following the Given-When-Then pattern.

## spex/3

Defines a specification.

## Example

    spex "user can login", tags: [:authentication] do
      scenario "with valid credentials" do
        # test implementation
      end
    end

## Options

  * `:description` - Human-readable description of the specification
  * `:tags` - List of atoms for categorizing the specification
  * `:context` - Map of additional context information

## scenario/2

Defines a scenario within a specification.

Scenarios group related Given-When-Then steps together.

## scenario/3

Defines a scenario with context support.

Context is passed between steps similar to ExUnit's approach.

## Example

    scenario "user workflow", context do
      given_ "a user", context do
        user = create_user()
        context = Map.put(context, :user, user)
      end
      
      when_ "they login", context do
        session = login(context.user)
        context = Map.put(context, :session, session)
      end
      
      then_ "they see dashboard", context do
        assert context.session.valid?
      end
    end

## given_/2

Defines the preconditions for a test scenario.

## Examples

    # Without context
    given_ "some setup" do
      # setup code
    end
    
    # With context (ExUnit style)
    given_ "some setup", context do
      data = setup()
      context = Map.put(context, :data, data)
    end

## when_/2

Defines the action being tested.

## then_/2

Defines the expected outcome.

## and_/2

Defines additional context or cleanup.
# Kino.Tree

A kino for interactively viewing nested data as a tree view.

The data can be any term.

## Examples

    data = %{
      id: 1,
      email: "user@example.com",
      inserted_at: ~U[2022-01-01T10:00:00Z],
      addresses: [
        %{
          country: "pl",
          city: "Kraków",
          street: "Karmelicka",
          zip: "00123"
        }
      ]
    }

    Kino.Tree.new(data)

The tree view is particularly useful when inspecting larger data
structures:

    data = Process.info(self())
    Kino.Tree.new(data)

## new/1

Creates a new kino displaying the given data structure.
defmodule EarWitnessTest do
  use Boundary, top_level?: true, deps: [EarWitness], exports: [DataCase]
end

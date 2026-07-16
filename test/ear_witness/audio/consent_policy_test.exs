defmodule EarWitness.Audio.ConsentPolicyTest do
  use ExUnit.Case, async: false

  alias EarWitness.Audio.ConsentPolicy

  test "silent authorizes with no notice" do
    assert ConsentPolicy.authorize(:silent) == {:ok, :none}
  end

  test "notify authorizes and flags a shown notice" do
    assert ConsentPolicy.authorize(:notify) == {:ok, :shown}
  end

  describe "announce" do
    test "reports delivered when the delivery seam succeeds" do
      # config/test.exs defaults the override to :ok
      assert ConsentPolicy.authorize(:announce) == {:ok, :delivered}
    end

    test "refuses capture when the notice cannot be delivered" do
      prev = Application.get_env(:ear_witness, :announcement_delivery_override)
      Application.put_env(:ear_witness, :announcement_delivery_override, :fail)
      on_exit(fn -> Application.put_env(:ear_witness, :announcement_delivery_override, prev) end)

      assert ConsentPolicy.authorize(:announce) == {:error, :notice_undelivered}
    end
  end
end

defmodule SpecTest do
  use ExUnit.Case, async: true

  describe "conform/2" do
    test "predicates" do
      assert Spec.conform!(1, &is_integer/1) == 1

      assert_raise Spec.Error, "cannot conform `:one` to `&:erlang.is_integer/1`", fn ->
        Spec.conform!(:one, &is_integer/1)
      end
    end
  end
end

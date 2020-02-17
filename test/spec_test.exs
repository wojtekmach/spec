defmodule SpecTest do
  use ExUnit.Case, async: true

  describe "conform/2" do
    test "predicates" do
      assert Spec.conform!(1, &is_integer/1) == 1

      assert_raise Spec.Error, "cannot conform `:one` to `&:erlang.is_integer/1`", fn ->
        Spec.conform!(:one, &is_integer/1)
      end
    end

    test "ranges" do
      assert Spec.conform!(1, 1..5) == 1

      assert_raise Spec.Error, "cannot conform `10` to `1..5`", fn ->
        Spec.conform!(10, 1..5)
      end
    end

    test "any_of" do
      spec = Spec.any_of([1..5, 10..20])

      assert Spec.conform!(1, spec) == 1

      assert_raise Spec.Error, "cannot conform `6` to `#{inspect(spec)}`", fn ->
        Spec.conform!(6, spec)
      end
    end

    test "all_of" do
      spec = Spec.all_of([1..5, 5..10])

      assert Spec.conform!(5, spec) == 5

      assert_raise Spec.Error, "cannot conform `6` to `#{inspect(spec)}`", fn ->
        Spec.conform!(6, spec)
      end
    end
  end
end

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

  describe "compatibility/2" do
    test "ranges" do
      assert Spec.compatibility(1..10, 1..10) == :equal
      assert Spec.compatibility(1..10, 2..5) == :stricter
      assert Spec.compatibility(1..10, 1..20) == :looser
      assert Spec.compatibility(1..10, -10..10) == :looser
      assert Spec.compatibility(1..10, -10..5) == :incompatible
    end

    test "ranges and is_integer" do
      assert Spec.compatibility(1..10, &is_integer/1) == :looser
      assert Spec.compatibility(&is_integer/1, 1..10) == :stricter
    end

    test "ranges and any_of" do
      assert Spec.compatibility(1..10, Spec.any_of([1..5, 1..10])) == :equal
      assert Spec.compatibility(1..10, Spec.any_of([1..5, 5..10])) == :stricter
      assert Spec.compatibility(1..10, Spec.any_of([1..5, 1..20])) == :looser
      assert Spec.compatibility(1..10, Spec.any_of([11..20])) == :incompatible
      assert Spec.compatibility(1..10, Spec.any_of([11..20, &is_integer/1])) == :looser
      assert Spec.compatibility(1..10, Spec.any_of([&is_binary/1])) == :incompatible
    end
  end
end

defmodule Spec.ContractTest do
  use ExUnit.Case, async: true
  require Spec.Contract

  def rgb2hex(r, g, b) do
    hex = (256 * 256 * r + 256 * g + b) |> Integer.to_string(16) |> String.pad_leading(6, "0")
    "#" <> hex
  end

  test "conform/2" do
    contract = %Spec.Contract{args: [0..255, 0..255, 0..255], result: &is_binary/1}
    assert Spec.Contract.conform!({__MODULE__, :rgb2hex, [1, 2, 255]}, contract) == "#0102FF"
  end
end

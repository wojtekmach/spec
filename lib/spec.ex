defmodule Spec do
  def conform(value, spec) do
    Spec.Spec.conform(spec, value)
  end

  def conform!(value, spec) do
    case conform(value, spec) do
      {:ok, value} -> value
      {:error, exception} -> raise exception
    end
  end

  defmodule AnyOf do
    defstruct [:specs]
  end

  def any_of(specs) do
    %AnyOf{specs: specs}
  end

  defmodule AllOf do
    defstruct [:specs]
  end

  def all_of(specs) do
    %AllOf{specs: specs}
  end

  def compatibility(spec1, spec2) do
    Spec.Compatibility.compatibility(spec1, spec2)
  end

  def gen(spec) do
    Spec.Gen.gen(spec)
  end
end

defprotocol Spec.Spec do
  def conform(spec, value)
end

defmodule Spec.Error do
  defexception [:spec, :value]

  @impl true
  def message(%{spec: spec, value: value}) do
    "cannot conform `#{inspect(value)}` to `#{inspect(spec)}`"
  end
end

defimpl Spec.Spec, for: Function do
  def conform(spec, value) when is_function(spec, 1) do
    case spec.(value) do
      true -> {:ok, value}
      false -> {:error, %Spec.Error{spec: spec, value: value}}
    end
  end
end

defimpl Spec.Spec, for: Range do
  def conform(spec, value) do
    if value in spec do
      {:ok, value}
    else
      {:error, %Spec.Error{spec: spec, value: value}}
    end
  end
end

defimpl Spec.Spec, for: Spec.AnyOf do
  def conform(%{specs: specs} = any_of, value) do
    Enum.reduce_while(specs, {:ok, value}, fn spec, _ ->
      case Spec.Spec.conform(spec, value) do
        {:ok, value} -> {:halt, {:ok, value}}
        {:error, _} -> {:cont, {:error, %Spec.Error{spec: any_of, value: value}}}
      end
    end)
  end
end

defimpl Spec.Spec, for: Spec.AllOf do
  def conform(%{specs: specs} = all_of, value) do
    Enum.reduce_while(specs, {:ok, value}, fn spec, _ ->
      case Spec.Spec.conform(spec, value) do
        {:ok, value} -> {:cont, {:ok, value}}
        {:error, _} -> {:halt, {:error, %Spec.Error{spec: all_of, value: value}}}
      end
    end)
  end
end

defmodule Spec.Compatibility do
  @moduledoc false

  def compatibility(spec, spec) do
    :equal
  end

  def compatibility(l1..r1, l2..r2) do
    cond do
      l2 >= l1 and r2 <= r1 -> :stricter
      l2 <= l1 and r2 >= r1 -> :looser
      true -> :incompatible
    end
  end

  def compatibility(%Range{}, fun) when is_function(fun, 1) do
    if fun == (&is_integer/1) do
      :looser
    else
      :incompatible
    end
  end

  def compatibility(fun, %Range{}) when is_function(fun, 1) do
    if fun == (&is_integer/1) do
      :stricter
    else
      :incompatible
    end
  end

  def compatibility(%Range{} = range, %Spec.AnyOf{specs: specs}) do
    Enum.reduce_while(specs, :incompatible, fn spec, acc ->
      case compatibility(range, spec) do
        :looser -> {:halt, :looser}
        :stricter -> {:cont, :stricter}
        :equal -> {:cont, :equal}
        :incompatible -> {:cont, acc}
      end
    end)
  end
end

defprotocol Spec.Gen do
  def gen(spec)
end

defimpl Spec.Gen, for: Function do
  def gen(spec) when is_function(spec, 1) do
    cond do
      spec == &is_integer/1 ->
        StreamData.integer()

      true ->
        StreamData.term() |> StreamData.filter(spec)
    end
  end
end

defimpl Spec.Gen, for: Range do
  def gen(spec) do
    StreamData.integer(spec)
  end
end

defimpl Spec.Gen, for: Spec.AnyOf do
  def gen(%{specs: specs}) do
    specs
    |> Enum.map(&Spec.Gen.gen(&1))
    |> StreamData.one_of()
  end
end

defmodule Spec.Contract do
  defstruct [:args, :result]

  def conform({mod, fun, args}, contract) do
    with :ok <- conform_args(args, contract) do
      Spec.conform(apply(mod, fun, args), contract.result)
    end
  end

  def conform!(mfargs, contract) do
    case conform(mfargs, contract) do
      {:ok, value} -> value
      {:error, exception} -> raise exception
    end
  end

  defp conform_args(args, contract) do
    Enum.reduce_while(Enum.zip(args, contract.args), :ok, fn {value, spec}, _ ->
      case Spec.conform(value, spec) do
        {:ok, _} -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  def compatible?(%__MODULE__{} = contract1, %__MODULE__{} = contract2) do
    compatible_args?(contract1.args, contract2.args) and compatible_result?(contract1.result, contract2.result)
  end

  defp compatible_args?(args1, args2) when length(args1) == length(args2) do
    Enum.reduce_while(Enum.zip(args1, args2), true, fn {arg1, arg2}, _ ->
      case Spec.compatibility(arg1, arg2) do
        :equal -> {:cont, true}
        :looser -> {:cont, true}
        _ -> {:halt, false}
      end
    end)
  end

  defp compatible_args?(_, _), do: false

  defp compatible_result?(result1, result2) do
    case Spec.compatibility(result1, result2) do
      :equal -> true
      :stricter -> true
      _ -> false
    end
  end
end

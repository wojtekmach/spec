defmodule Spec do
  def conform(value, spec) do
    Spec.Spec.conform(spec, value)
  end

  def conform!(value, spec) do
    case conform(value, spec) do
      {:ok, value} ->
        value

      {:error, exception} ->
        raise exception
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
      true ->
        {:ok, value}

      false ->
        {:error, %Spec.Error{spec: spec, value: value}}
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
        {:ok, value} ->
          {:halt, {:ok, value}}

        {:error, _} ->
          {:cont, {:error, %Spec.Error{spec: any_of, value: value}}}
      end
    end)
  end
end

defimpl Spec.Spec, for: Spec.AllOf do
  def conform(%{specs: specs} = all_of, value) do
    Enum.reduce_while(specs, {:ok, value}, fn spec, _ ->
      case Spec.Spec.conform(spec, value) do
        {:ok, value} ->
          {:cont, {:ok, value}}

        {:error, _} ->
          {:halt, {:error, %Spec.Error{spec: all_of, value: value}}}
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
    if fun == &is_integer/1 do
      :looser
    else
      :incompatible
    end
  end

  def compatibility(fun, %Range{}) when is_function(fun, 1) do
    if fun == &is_integer/1 do
      :stricter
    else
      :incompatible
    end
  end

  def compatibility(%Range{} = range, %Spec.AnyOf{specs: specs}) do
    Enum.reduce_while(specs, :incompatible, fn spec, acc ->
      case compatibility(range, spec) do
        :looser ->
          {:halt, :looser}

        :stricter ->
          {:cont, :stricter}

        :equal ->
          {:cont, :equal}

        :incompatible ->
          {:cont, acc}
      end
    end)
  end
end

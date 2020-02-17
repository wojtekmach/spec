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

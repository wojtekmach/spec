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

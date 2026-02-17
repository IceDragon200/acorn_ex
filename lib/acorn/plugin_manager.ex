defmodule Acorn.PluginManager do
  defmodule PluginRef do
    defstruct [
      module: nil,
      state: nil,
    ]

    @type t :: %__MODULE__{
      module: module(),
      state: any()
    }
  end

  @moduledoc """
  Executes configured inbound and outbound plugin chains.
  """
  defstruct [
    inbound: [],
    outbound: [],
  ]

  @type t :: %__MODULE__{
    inbound: [PluginRef.t()],
    outbound: [PluginRef.t()]
  }

  @type plugin_spec :: module() | {module(), keyword()}

  @spec init(keyword()) :: {:ok, t()} | {:error, any()}
  def init(opts \\ []) do
    with {:ok, inbound} <- init_pipeline(Keyword.get(opts, :inbound, []), []),
         {:ok, outbound} <- init_pipeline(Keyword.get(opts, :outbound, []), []) do
      {:ok, %__MODULE__{inbound: inbound, outbound: outbound}}
    end
  end

  @spec run_inbound(t(), Acorn.Pdu.t(), map()) ::
          {:ok, Acorn.Pdu.t(), map(), t()}
          | {:halt, list(), map(), t()}
          | {:error, any(), t()}
  def run_inbound(%__MODULE__{} = manager, %Acorn.Pdu{} = pdu, context \\ %{}) do
    run_inbound_plugins(manager.inbound, pdu, context, [])
    |> finalize_inbound(manager)
  end

  @spec run_outbound(t(), Acorn.Pdu.t(), any(), any(), map()) ::
          {:ok, Acorn.Pdu.t(), any(), any(), map(), t()}
          | {:halt, map(), t()}
          | {:error, any(), t()}
  def run_outbound(%__MODULE__{} = manager, %Acorn.Pdu{} = pdu, dest, from, context \\ %{}) do
    run_outbound_plugins(manager.outbound, pdu, dest, from, context, [])
    |> finalize_outbound(manager)
  end

  defp init_pipeline([], acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp init_pipeline([spec | specs], acc) do
    with {:ok, module, opts} <- normalize_plugin_spec(spec),
         {:module, _} <- Code.ensure_loaded(module),
         true <- function_exported?(module, :init, 1),
         {:ok, state} <- module.init(opts) do
      init_pipeline(specs, [%PluginRef{module: module, state: state} | acc])
    else
      false ->
        {:error, {:invalid_plugin, spec}}

      {:error, _} = err ->
        err

      _ ->
        {:error, {:invalid_plugin, spec}}
    end
  end

  defp normalize_plugin_spec({module, opts}) when is_atom(module) and is_list(opts) do
    {:ok, module, opts}
  end

  defp normalize_plugin_spec(module) when is_atom(module) do
    {:ok, module, []}
  end

  defp normalize_plugin_spec(spec) do
    {:error, {:invalid_plugin_spec, spec}}
  end

  defp run_inbound_plugins([], pdu, context, updated) do
    {:ok, pdu, context, Enum.reverse(updated)}
  end

  defp run_inbound_plugins([%PluginRef{} = plugin | rest], pdu, context, updated) do
    case plugin.module.handle_inbound(pdu, context, plugin.state) do
      {:cont, %Acorn.Pdu{} = next_pdu, next_context, new_state} when is_map(next_context) ->
        run_inbound_plugins(
          rest,
          next_pdu,
          next_context,
          [%PluginRef{plugin | state: new_state} | updated]
        )

      {:halt, responses, next_context, new_state} when is_list(responses) and is_map(next_context) ->
        rest = Enum.reverse(updated) ++ [%PluginRef{plugin | state: new_state}] ++ rest
        {:halt, responses, next_context, rest}

      {:error, reason, new_state} ->
        rest = Enum.reverse(updated) ++ [%PluginRef{plugin | state: new_state}] ++ rest
        {:error, reason, rest}

      _ ->
        rest = Enum.reverse(updated) ++ [plugin] ++ rest
        {:error, {:invalid_plugin_reply, plugin.module, :handle_inbound}, rest}
    end
  end

  defp run_outbound_plugins([], pdu, dest, from, context, updated) do
    {:ok, pdu, dest, from, context, Enum.reverse(updated)}
  end

  defp run_outbound_plugins([%PluginRef{} = plugin | rest], pdu, dest, from, context, updated) do
    case plugin.module.handle_outbound(pdu, dest, from, context, plugin.state) do
      {:cont, %Acorn.Pdu{} = next_pdu, next_dest, next_from, next_context, new_state}
      when is_map(next_context) ->
        run_outbound_plugins(
          rest,
          next_pdu,
          next_dest,
          next_from,
          next_context,
          [%PluginRef{plugin | state: new_state} | updated]
        )

      {:halt, next_context, new_state} when is_map(next_context) ->
        {:halt, next_context,
         Enum.reverse(updated) ++ [%PluginRef{plugin | state: new_state}] ++ rest}

      {:error, reason, new_state} ->
        {:error, reason, Enum.reverse(updated) ++ [%PluginRef{plugin | state: new_state}] ++ rest}

      _ ->
        {:error, {:invalid_plugin_reply, plugin.module, :handle_outbound},
         Enum.reverse(updated) ++ [plugin] ++ rest}
    end
  end

  defp finalize_inbound({:ok, pdu, context, inbound}, %__MODULE__{} = manager) do
    {:ok, pdu, context, %__MODULE__{manager | inbound: inbound}}
  end

  defp finalize_inbound({:halt, responses, context, inbound}, %__MODULE__{} = manager) do
    {:halt, responses, context, %__MODULE__{manager | inbound: inbound}}
  end

  defp finalize_inbound({:error, reason, inbound}, %__MODULE__{} = manager) do
    {:error, reason, %__MODULE__{manager | inbound: inbound}}
  end

  defp finalize_outbound({:ok, pdu, dest, from, context, outbound}, %__MODULE__{} = manager) do
    {:ok, pdu, dest, from, context, %__MODULE__{manager | outbound: outbound}}
  end

  defp finalize_outbound({:halt, context, outbound}, %__MODULE__{} = manager) do
    {:halt, context, %__MODULE__{manager | outbound: outbound}}
  end

  defp finalize_outbound({:error, reason, outbound}, %__MODULE__{} = manager) do
    {:error, reason, %__MODULE__{manager | outbound: outbound}}
  end
end

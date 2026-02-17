defmodule Acorn.PluginHandler do
  defmodule State do
    defstruct [
      plugin_manager: nil
    ]

    @type t :: %__MODULE__{
      plugin_manager: Acorn.PluginManager.t(),
    }
  end

  alias Acorn.Pdu
  alias Acorn.PluginManager

  @behaviour Acorn.HandlerModule

  @impl true
  def init(opts) when is_list(opts) do
    with {:ok, plugin_manager} <- PluginManager.init(opts) do
      {:ok, %State{plugin_manager: plugin_manager}}
    end
  end

  @impl true
  def handle_pdu(%Pdu{} = pdu, %State{} = state) do
    case PluginManager.run_inbound(state.plugin_manager, pdu, %{}) do
      {:ok, _pdu, _context, plugin_manager} ->
        {:reply, [], %State{state | plugin_manager: plugin_manager}}

      {:halt, responses, _context, plugin_manager} ->
        {:reply, responses, %State{state | plugin_manager: plugin_manager}}

      {:error, _reason, plugin_manager} ->
        {:reply, [], %State{state | plugin_manager: plugin_manager}}
    end
  end

  @impl true
  def send_pdu(socket, %Pdu{} = pdu, dest, from, %State{} = state) do
    case PluginManager.run_outbound(state.plugin_manager, pdu, dest, from, %{}) do
      {:ok, pdu, next_dest, _next_from, context, plugin_manager} ->
        case Acorn.Pdu.encode(pdu) do
          {:ok, blob} ->
            case :socket.sendto(socket, blob, next_dest) do
              :ok ->
                case send_additional_outbound_pdus(socket, context) do
                  :ok ->
                    {:ok, %State{state | plugin_manager: plugin_manager}}
                end
            end
        end

      {:halt, _context, plugin_manager} ->
        {:ok, %State{state | plugin_manager: plugin_manager}}

      {:error, _reason, plugin_manager} ->
        {:ok, %State{state | plugin_manager: plugin_manager}}
    end
  end

  defp send_additional_outbound_pdus(_socket, %{additional_outbound_pdus: []}), do: :ok
  defp send_additional_outbound_pdus(_socket, %{} = context) when not is_map_key(context, :additional_outbound_pdus), do: :ok

  defp send_additional_outbound_pdus(socket, %{additional_outbound_pdus: additional}) when is_list(additional) do
    Enum.reduce_while(additional, :ok, fn
      {%Pdu{} = pdu, dest}, :ok ->
        case Acorn.Pdu.encode(pdu) do
          {:ok, blob} ->
            case :socket.sendto(socket, blob, dest) do
              :ok -> {:cont, :ok}
            end
        end
    end)
  end
end

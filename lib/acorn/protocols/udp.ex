defmodule Acorn.KV.Protocol.UDP do
  defmodule State do
    defstruct [
      bind: nil,
      module: nil,
      assigns: nil,
      socket: nil,
      select: nil,
    ]

    @type t :: %__MODULE__{}
  end

  @moduledoc """
  Provides Acorn's bare socket infrastructure, this will accept payloads and parse them for its
  module to handle.

  Protocols are NOT responsible for segmentation/reordering, that is the module's job.
  """
  use GenServer

  alias Acorn.Pdu

  import Acorn.Utils

  def send_pdu(pid, %Pdu{} = pdu, dest, timeout \\ 15_000) do
    GenServer.call(pid, {:send_pdu, pdu, dest}, timeout)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  defdelegate stop(pid, reason \\ :normal, timeout \\ :infinity), to: GenServer

  @impl true
  def init(opts) do
    with validate_keyword_required(opts, [:module, :options, :bind]),
         module <- Keyword.fetch!(opts, :module) do
      %State{} = state =
        %State{
          module: module,
          assigns: nil
        }

      if function_exported?(state.module, :init, 1) do
        case state.module.init(opts[:options]) do
          {:ok, assigns} ->
            %State{} = state =
              %State{
                state
                | bind: Keyword.fetch!(opts, :bind),
                  assigns: assigns
              }

            {:ok, state, {:continue, :listen}}

          {:error, reason} ->
            {:error, {:module_error, reason}}
        end
      else
        {:error, :module_missing_init}
      end
    end
  end

  @impl true
  def terminate(_reason, %State{} = state) do
    Process.flag(:trap_exit, false)
    if state.socket do
      :socket.close(state.socket)
    end
    :ok
  end

  @impl true
  def handle_continue(:listen, %State{} = state) do
    with \
      {:ok, socket} <- :socket.open(:inet, :dgram, :udp),
      :ok <- :socket.bind(socket, state.bind)
    do
      %State{} = state =
        %State{
          state
          | socket: socket
        }

      {:noreply, state, {:continue, :recv}}
    else
      {:error, _} = err ->
        {:stop, err, state}
    end
  end

  @impl true
  def handle_continue(:recv, %State{} = state) do
    case :socket.recv(state.socket, 0, [], :nowait) do
      {:select, handle} ->
        {:noreply, %State{state | select: handle}}

      {:ok, blob} ->
        case parse_pdu(blob, state) do
          {:ok, %Acorn.Pdu{} = pdu, %State{} = state} ->
            {:noreply, state, {:continue, {:handle_pdu, pdu}}}

          {:ok, state} ->
            {:noreply, state, {:continue, :recv}}
        end

      {:error, _reason} = err ->
        {:stop, err, state}
    end
  end

  @impl true
  def handle_continue({:recv, _handle}, %State{} = state) do
    case :socket.recv(state.socket, 0, []) do
      {:ok, blob} ->
        case parse_pdu(blob, state) do
          {:ok, %Acorn.Pdu{} = pdu, %State{} = state} ->
            {:noreply, state, {:continue, {:handle_pdu, pdu}}}

          {:ok, state} ->
            {:noreply, state, {:continue, :recv}}
        end

      {:error, _reason} = err ->
        {:stop, err, state}
    end
  end

  @impl true
  def handle_continue({:handle_pdu, %Acorn.Pdu{} = pdu}, %State{} = state) do
    case state.module.handle_pdu(pdu, state.assigns) do
      {:reply, pdus, assigns} ->
        %State{} = state =
          %State{
            state
            | assigns: assigns
          }

        {:noreply, state, {:continue, {:send_pdus, pdus}}}
    end
  end

  @impl true
  def handle_continue({:send_pdus, []}, %State{} = state) do
    {:noreply, state, {:continue, :recv}}
  end

  @impl true
  def handle_continue({:send_pdus, [item | rest]}, %State{} = state) do
    case item do
      {:send, %Acorn.Pdu{} = pdu, dest} ->
        case do_send_pdu(pdu, dest, nil, state) do
          {:ok, %State{} = state} ->
            {:noreply, state, {:continue, {:send_pdus, rest}}}
        end
    end
  end

  @impl true
  def handle_call({:send_pdu, %Pdu{} = pdu, dest}, from, %State{} = state) do
    case do_send_pdu(pdu, dest, from, state) do
      {:ok, %State{} = state} ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info({:"$socket", _socket, :select, handle}, %State{} = state) do
    {:noreply, state, {:continue, {:recv, handle}}}
  end

  def parse_pdu(blob, %State{} = state) do
    case Acorn.Pdu.parse(blob) do
      {:ok, %Acorn.Pdu{} = pdu} ->
        {:ok, pdu, state}

      :error ->
        {:ok, state}
    end
  end

  defp do_send_pdu(pdu, dest, from, %State{} = state) do
    case state.module.send_pdu(state.socket, pdu, dest, from, state.assigns) do
      {:ok, assigns} ->
        %State{} = state =
          %State{
            state
            | assigns: assigns
          }

        {:ok, state}
    end
  end
end

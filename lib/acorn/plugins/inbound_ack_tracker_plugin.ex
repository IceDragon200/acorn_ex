defmodule Acorn.Plugins.InboundAckTrackerPlugin do
  use Acorn.Plugin

  alias Acorn.Pdu
  alias Mortar.Proplist

  @impl true
  def init(_opts) do
    {:ok, %{acks: MapSet.new(), need_seq: %{}}}
  end

  @impl true
  def handle_inbound(%Pdu{} = pdu, context, state) do
    case pdu.start_line do
      %Acorn.StartLine{type: :response, status_code: "000"} ->
        tx_id = Proplist.get(pdu.cpim.headers, "TX-ID")
        ack_message_id = Proplist.get(pdu.cpim.headers, "Ack-Message-ID")

        if is_binary(tx_id) and is_binary(ack_message_id) do
          ack = {tx_id, ack_message_id}
          acks = MapSet.put(state.acks, ack)
          context = Map.update(context, :acks, [ack], &[ack | &1])
          {:cont, pdu, context, %{state | acks: acks}}
        else
          {:cont, pdu, context, state}
        end

      %Acorn.StartLine{type: :response, status_code: "001"} ->
        tx_id = Proplist.get(pdu.cpim.headers, "TX-ID")
        need_seq = Proplist.get(pdu.cpim.headers, "Need-Seq")

        if is_binary(tx_id) and is_binary(need_seq) do
          state = put_in(state, [:need_seq, tx_id], need_seq)
          context = Map.update(context, :need_seq, %{tx_id => need_seq}, &Map.put(&1, tx_id, need_seq))
          {:cont, pdu, context, state}
        else
          {:cont, pdu, context, state}
        end

      _ ->
        {:cont, pdu, context, state}
    end
  end

end

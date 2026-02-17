defmodule Acorn.Plugins.OutboundRetryPlugin do
  use Acorn.Plugin

  alias Acorn.CPIM
  alias Acorn.Pdu
  alias Mortar.Proplist

  @impl true
  def init(opts) do
    {:ok,
     %{
       max_attempts: Keyword.get(opts, :max_attempts, 5),
       t1_ms: Keyword.get(opts, :t1_ms, 500),
       pending: %{},
       attempts: %{}
     }}
  end

  @impl true
  def handle_outbound(%Pdu{} = pdu, dest, from, context, state) do
    tx_id = Proplist.get(pdu.cpim.headers, "TX-ID")
    message_id = Proplist.get(pdu.cpim.headers, "Message-ID")

    if is_binary(tx_id) and is_binary(message_id) do
      key = {tx_id, message_id}
      attempt = Map.get(state.attempts, key, 0) + 1

      pdu = put_header(pdu, "Retry-Attempt", Integer.to_string(attempt))
      pending_entry = %{pdu: pdu, dest: dest, from: from, inserted_at_ms: System.monotonic_time(:millisecond)}

      state =
        state
        |> put_in([:pending, key], pending_entry)
        |> put_in([:attempts, key], attempt)

      context =
        Map.put(context, :retry,
          %{tx_id: tx_id, message_id: message_id, attempt: attempt, t1_ms: state.t1_ms, max_attempts: state.max_attempts}
        )

      {:cont, pdu, dest, from, context, state}
    else
      {:cont, pdu, dest, from, context, state}
    end
  end

  @doc """
  Removes pending retry entries based on a TX-ID / Ack-Message-ID tuple.
  """
  @spec acknowledge(map(), binary(), binary()) :: map()
  def acknowledge(state, tx_id, ack_message_id)
      when is_map(state) and is_binary(tx_id) and is_binary(ack_message_id) do
    key = {tx_id, ack_message_id}
    state |> update_in([:pending], &Map.delete(&1, key)) |> update_in([:attempts], &Map.delete(&1, key))
  end

  defp put_header(%Pdu{} = pdu, name, value) do
    %CPIM{} = cpim = pdu.cpim
    headers = Proplist.put(cpim.headers, name, value)
    %Pdu{pdu | cpim: %CPIM{cpim | headers: headers}}
  end
end

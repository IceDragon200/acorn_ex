defmodule Acorn.Plugins.InboundReassemblyPlugin do
  use Acorn.Plugin

  alias Acorn.CPIM
  alias Acorn.Pdu
  alias Mortar.Proplist

  @impl true
  def init(opts) do
    {:ok,
     %{
       ttl_ms: Keyword.get(opts, :ttl_ms, 30_000),
       buffers: %{}
     }}
  end

  @impl true
  def handle_inbound(%Pdu{} = pdu, context, state) do
    state = purge_expired(state)

    with {:ok, segment_id} <- required_header(pdu.cpim.headers, "Segment-ID"),
         {:ok, segment_index} <- parse_positive_int(pdu.cpim.headers, "Segment-Index"),
         {:ok, segment_count} <- parse_positive_int(pdu.cpim.headers, "Segment-Count") do
      key = segment_key(pdu, segment_id)
      bucket = Map.get(state.buffers, key, %{segment_count: segment_count, pieces: %{}, template: pdu, inserted_at_ms: now_ms()})
      bucket = %{bucket | pieces: Map.put(bucket.pieces, segment_index, pdu.cpim.body || "")}
      buffers = Map.put(state.buffers, key, bucket)
      state = %{state | buffers: buffers}

      if map_size(bucket.pieces) == bucket.segment_count do
        rebuilt_pdu = rebuild(bucket.template, bucket.pieces, bucket.segment_count)
        state = %{state | buffers: Map.delete(state.buffers, key)}
        context = Map.put(context, :reassembled, %{segment_id: segment_id, segment_count: segment_count})
        {:cont, rebuilt_pdu, context, state}
      else
        context =
          Map.put(context, :reassembly_waiting, %{
            segment_id: segment_id,
            segment_index: segment_index,
            segment_count: segment_count
          })

        {:halt, [], context, state}
      end
    else
      :error ->
        {:cont, pdu, context, state}
    end
  end

  defp rebuild(%Pdu{} = template, pieces, segment_count) do
    %CPIM{} = cpim = template.cpim

    body =
      1..segment_count
      |> Enum.map(&Map.fetch!(pieces, &1))
      |> IO.iodata_to_binary()

    headers =
      cpim.headers
      |> Proplist.drop(["Segment-ID", "Segment-Index", "Segment-Count"])

    cpim = %CPIM{cpim | headers: headers, body: body}
    %Pdu{template | cpim: cpim}
  end

  defp required_header(headers, name) do
    case Proplist.get(headers, name) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> :error
    end
  end

  defp parse_positive_int(headers, name) do
    with {:ok, value} <- required_header(headers, name),
         {n, ""} <- Integer.parse(value),
         true <- n > 0 do
      {:ok, n}
    else
      _ -> :error
    end
  end

  defp segment_key(%Pdu{} = pdu, segment_id) do
    tx_id = Proplist.get(pdu.cpim.headers, "TX-ID")
    {tx_id, segment_id}
  end

  defp purge_expired(state) do
    cutoff = now_ms() - state.ttl_ms

    buffers =
      Enum.reduce(state.buffers, %{}, fn {key, bucket}, acc ->
        if bucket.inserted_at_ms >= cutoff do
          Map.put(acc, key, bucket)
        else
          acc
        end
      end)

    %{state | buffers: buffers}
  end

  defp now_ms, do: System.monotonic_time(:millisecond)
end

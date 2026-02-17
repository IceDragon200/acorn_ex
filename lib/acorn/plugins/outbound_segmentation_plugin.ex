defmodule Acorn.Plugins.OutboundSegmentationPlugin do
  use Acorn.Plugin

  alias Acorn.CPIM
  alias Acorn.Pdu
  alias Mortar.Proplist

  @impl true
  def init(opts) do
    {:ok,
     %{
       max_segment_bytes: Keyword.get(opts, :max_segment_bytes, 900),
       next_id: 0
     }}
  end

  @impl true
  def handle_outbound(%Pdu{} = pdu, dest, from, context, state) do
    body = pdu.cpim.body || ""

    if byte_size(body) <= state.max_segment_bytes do
      {:cont, pdu, dest, from, context, state}
    else
      segment_id =
        Proplist.get(pdu.cpim.headers, "Segment-ID") ||
          Proplist.get(pdu.cpim.headers, "Message-ID") ||
          generated_segment_id(state.next_id)

      segments = split_binary(body, state.max_segment_bytes)
      count = length(segments)

      segmented_pdus =
        segments
        |> Enum.with_index(1)
        |> Enum.map(fn {chunk, index} ->
          to_segment_pdu(pdu, segment_id, index, count, chunk)
        end)

      [first | rest] = segmented_pdus

      additional =
        Enum.map(rest, fn next_pdu ->
          {next_pdu, dest}
        end)

      context =
        context
        |> Map.update(:additional_outbound_pdus, additional, &(&1 ++ additional))
        |> Map.put(:segmentation, %{segment_id: segment_id, segment_count: count})

      {:cont, first, dest, from, context, %{state | next_id: state.next_id + 1}}
    end
  end

  defp to_segment_pdu(%Pdu{} = pdu, segment_id, index, count, chunk) do
    %CPIM{} = cpim = pdu.cpim

    headers =
      cpim.headers
      |> Proplist.put("Segment-ID", segment_id)
      |> Proplist.put("Segment-Index", Integer.to_string(index))
      |> Proplist.put("Segment-Count", Integer.to_string(count))

    cpim = %CPIM{cpim | headers: headers, body: chunk}
    %Pdu{pdu | cpim: cpim}
  end

  defp split_binary(bin, max_size) when is_binary(bin) and max_size > 0 do
    do_split_binary(bin, max_size, [])
  end

  defp do_split_binary(<<>>, _max_size, acc), do: Enum.reverse(acc)

  defp do_split_binary(bin, max_size, acc) when byte_size(bin) <= max_size do
    Enum.reverse([bin | acc])
  end

  defp do_split_binary(bin, max_size, acc) do
    <<chunk::binary-size(max_size), rest::binary>> = bin
    do_split_binary(rest, max_size, [chunk | acc])
  end

  defp generated_segment_id(counter), do: "seg-" <> Integer.to_string(counter + 1)
end

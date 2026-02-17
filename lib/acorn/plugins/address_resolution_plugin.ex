defmodule Acorn.Plugins.AddressResolutionPlugin do
  use Acorn.Plugin

  alias Acorn.Pdu
  alias Acorn.StartLine
  alias Mortar.Proplist
  import Acorn.Utils

  @impl true
  def handle_outbound(%Pdu{} = pdu, dest, from, context, state) do
    case resolve_destination(pdu, dest, context) do
      {:ok, resolved_dest} ->
        context = Map.put(context, :resolved_dest, resolved_dest)
        {:cont, pdu, resolved_dest, from, context, state}

      :error ->
        {:cont, pdu, dest, from, context, state}
    end
  end

  defp resolve_destination(%Pdu{} = pdu, dest, context) do
    if destination_present?(dest) do
      {:ok, dest}
    else
      headers = pdu.cpim.headers
      candidate = candidate_identity(pdu.start_line, headers)

      case parse_identity(candidate) do
        {:ok, parsed} ->
          {:ok, parsed}

        :error ->
          case Map.get(context, :transport_from) do
            %{family: :inet, addr: _addr, port: _port} = from -> {:ok, from}
            _ -> :error
          end
      end
    end
  end

  defp candidate_identity(%StartLine{type: :response, status_code: "000"}, headers) do
    Proplist.get(headers, "Ack-To") || Proplist.get(headers, "Reply-To") || Proplist.get(headers, "From")
  end

  defp candidate_identity(%StartLine{type: :response}, headers) do
    Proplist.get(headers, "Reply-To") || Proplist.get(headers, "From")
  end

  defp candidate_identity(%StartLine{type: :request}, headers) do
    Proplist.get(headers, "To")
  end

  defp destination_present?(%{family: :inet, addr: _addr, port: _port}), do: true
  defp destination_present?(_), do: false

  defp parse_identity(nil), do: :error

  defp parse_identity(identity) when is_binary(identity) do
    identity =
      case String.split(identity, "@", parts: 2) do
        [_, right] -> right
        [right] -> right
      end

      case String.split(identity, ":", parts: 2) do
      [host, port_str] ->
        with {:ok, addr} <- parse_inet_address(host),
             {port, ""} <- Integer.parse(port_str),
             true <- port >= 0 and port <= 65_535 do
          {:ok, %{family: :inet, addr: addr, port: port}}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

end

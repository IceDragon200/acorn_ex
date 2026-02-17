defmodule Acorn.Plugins.InboundSessionPlugin do
  use Acorn.Plugin

  alias Acorn.CPIM
  alias Acorn.Pdu
  alias Acorn.StartLine
  alias Mortar.Proplist

  defmodule SessionState do
    defstruct mode: :unordered, last_seq: nil

    @type t :: %__MODULE__{
            mode: :ordered | :unordered,
            last_seq: nil | integer()
          }
  end

  @impl true
  def init(opts) do
    default_mode =
      case Keyword.get(opts, :default_mode, :unordered) do
        :ordered -> :ordered
        "ordered" -> :ordered
        _ -> :unordered
      end

    {:ok, %{default_mode: default_mode, sessions: %{}}}
  end

  @impl true
  def handle_inbound(%Pdu{} = pdu, context, state) do
    headers = pdu.cpim.headers
    session_key = session_key(pdu, headers)

    %SessionState{} = session =
      Map.get(state.sessions, session_key, %SessionState{mode: state.default_mode})
      |> maybe_negotiate_mode(headers)

    with {:ok, seq} <- parse_seq(headers),
         :ok <- validate_sequence(session, seq) do
      session = %SessionState{session | last_seq: max_seq(session.last_seq, seq)}
      sessions = Map.put(state.sessions, session_key, session)
      context = Map.put(context, :session, %{key: session_key, mode: session.mode, seq: seq})
      {:cont, pdu, context, %{state | sessions: sessions}}
    else
      {:gap, need_seq} ->
        responses = [build_nack_response(pdu, need_seq)]
        context = Map.put(context, :session_gap, need_seq)
        {:halt, responses, context, state}

      :error ->
        {:cont, pdu, context, state}
    end
  end

  defp parse_seq(headers) do
    case Proplist.get(headers, "Seq") do
      nil ->
        :error

      seq_str ->
        case Integer.parse(seq_str) do
          {seq, ""} -> {:ok, seq}
          _ -> :error
        end
    end
  end

  defp validate_sequence(%SessionState{mode: :unordered}, _seq), do: :ok

  defp validate_sequence(%SessionState{mode: :ordered, last_seq: nil}, _seq), do: :ok

  defp validate_sequence(%SessionState{mode: :ordered, last_seq: last_seq}, seq) do
    cond do
      seq <= last_seq ->
        :ok

      seq == last_seq + 1 ->
        :ok

      seq > last_seq + 1 ->
        {:gap, format_need_seq(last_seq + 1, seq - 1)}
    end
  end

  defp maybe_negotiate_mode(%SessionState{} = session, headers) do
    mode =
      Proplist.get(headers, "Set-Session-Mode") ||
        Proplist.get(headers, "Request-Session-Mode")

    case mode do
      "ordered" -> %SessionState{session | mode: :ordered}
      "unordered" -> %SessionState{session | mode: :unordered}
      _ -> session
    end
  end

  defp session_key(%Pdu{} = pdu, headers) do
    Proplist.get(headers, "Session-ID") || Proplist.get(headers, "TX-ID") || pdu.reference
  end

  defp format_need_seq(first, last) when first == last, do: Integer.to_string(first)
  defp format_need_seq(first, last), do: "#{first}..#{last}"

  defp max_seq(nil, seq), do: seq
  defp max_seq(prev, seq) when seq > prev, do: seq
  defp max_seq(prev, _seq), do: prev

  defp build_nack_response(%Pdu{} = pdu, need_seq) do
    tx_id = Proplist.get(pdu.cpim.headers, "TX-ID")

    cpim =
      %CPIM{
        headers:
          [
            {"Need-Seq", need_seq}
            | (if tx_id, do: [{"TX-ID", tx_id}], else: [])
          ],
        body: ""
      }

    {:send, %Pdu{reference: make_ref(), start_line: StartLine.new_response("001", "NACK"), cpim: cpim}, nil}
  end

end

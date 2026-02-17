defmodule Acorn.PluginsTest do
  use ExUnit.Case, async: true

  alias Acorn.CPIM
  alias Acorn.Pdu
  alias Acorn.PluginManager
  alias Acorn.Plugins.AddressResolutionPlugin
  alias Acorn.Plugins.InboundAckTrackerPlugin
  alias Acorn.Plugins.InboundReassemblyPlugin
  alias Acorn.Plugins.InboundSessionPlugin
  alias Acorn.Plugins.OutboundRetryPlugin
  alias Acorn.Plugins.OutboundSegmentationPlugin
  alias Acorn.StartLine

  test "InboundSessionPlugin emits NACK when ordered sequence has a gap" do
    {:ok, manager} = PluginManager.init(inbound: [{InboundSessionPlugin, default_mode: :ordered}])

    {:ok, _pdu, _context, manager} =
      PluginManager.run_inbound(manager, request_pdu([{"TX-ID", "tx-1"}, {"Seq", "1"}]), %{})

    {:halt, responses, context, _manager} =
      PluginManager.run_inbound(manager, request_pdu([{"TX-ID", "tx-1"}, {"Seq", "3"}]), %{})

    assert context.session_gap == "2"
    assert [{:send, %Pdu{} = nack, nil}] = responses
    assert nack.start_line.status_code == "001"
    assert {"Need-Seq", "2"} in nack.cpim.headers
  end

  test "OutboundRetryPlugin tracks pending retries and increments attempt count" do
    {:ok, manager} = PluginManager.init(outbound: [{OutboundRetryPlugin, max_attempts: 3, t1_ms: 250}])

    dest = %{family: :inet, addr: {127, 0, 0, 1}, port: 7077}
    from = {self(), make_ref()}

    {:ok, pdu1, ^dest, ^from, context1, manager} =
      PluginManager.run_outbound(
        manager,
        request_pdu([{"TX-ID", "tx-2"}, {"Message-ID", "msg-1"}]),
        dest,
        from,
        %{}
      )

    assert {"Retry-Attempt", "1"} in pdu1.cpim.headers
    assert context1.retry.attempt == 1

    [%{state: state}] = manager.outbound
    assert Map.has_key?(state.pending, {"tx-2", "msg-1"})

    {:ok, pdu2, ^dest, ^from, context2, _manager} =
      PluginManager.run_outbound(
        manager,
        request_pdu([{"TX-ID", "tx-2"}, {"Message-ID", "msg-1"}]),
        dest,
        from,
        %{}
      )

    assert {"Retry-Attempt", "2"} in pdu2.cpim.headers
    assert context2.retry.attempt == 2
  end

  test "InboundAckTrackerPlugin records ack and need-seq context" do
    {:ok, manager} = PluginManager.init(inbound: [InboundAckTrackerPlugin])

    ack_pdu =
      response_pdu("000", "ACK", [
        {"TX-ID", "tx-3"},
        {"Ack-Message-ID", "msg-ack"}
      ])

    {:ok, _pdu, context1, manager} = PluginManager.run_inbound(manager, ack_pdu, %{})
    assert {"tx-3", "msg-ack"} in context1.acks

    nack_pdu =
      response_pdu("001", "NACK", [
        {"TX-ID", "tx-3"},
        {"Need-Seq", "8..10"}
      ])

    {:ok, _pdu, context2, _manager} = PluginManager.run_inbound(manager, nack_pdu, %{})
    assert context2.need_seq["tx-3"] == "8..10"
  end

  test "AddressResolutionPlugin resolves ACK destination using Ack-To precedence" do
    {:ok, manager} = PluginManager.init(outbound: [AddressResolutionPlugin])
    from = {self(), make_ref()}

    pdu =
      response_pdu("000", "ACK", [
        {"Ack-To", "node@127.0.0.1:7090"},
        {"Reply-To", "node@127.0.0.1:7080"},
        {"From", "node@127.0.0.1:7070"}
      ])

    {:ok, _pdu, dest, ^from, context, _manager} =
      PluginManager.run_outbound(manager, pdu, nil, from, %{})

    assert dest == %{family: :inet, addr: {127, 0, 0, 1}, port: 7090}
    assert context.resolved_dest == dest
  end

  test "AddressResolutionPlugin falls back to transport source when headers unavailable" do
    {:ok, manager} = PluginManager.init(outbound: [AddressResolutionPlugin])
    from = {self(), make_ref()}

    pdu = response_pdu("200", "OK", [])
    transport_from = %{family: :inet, addr: {10, 0, 0, 2}, port: 7777}

    {:ok, _pdu, dest, ^from, context, _manager} =
      PluginManager.run_outbound(manager, pdu, nil, from, %{transport_from: transport_from})

    assert dest == transport_from
    assert context.resolved_dest == transport_from
  end

  test "OutboundSegmentationPlugin splits large body into additional outbound PDUs" do
    {:ok, manager} = PluginManager.init(outbound: [{OutboundSegmentationPlugin, max_segment_bytes: 5}])

    pdu =
      request_pdu([{"TX-ID", "tx-seg"}, {"Message-ID", "msg-seg"}], "helloworld!!")

    dest = %{family: :inet, addr: {127, 0, 0, 1}, port: 7077}
    from = {self(), make_ref()}

    {:ok, first, ^dest, ^from, context, _manager} =
      PluginManager.run_outbound(manager, pdu, dest, from, %{})

    assert {"Segment-ID", _} = Enum.find(first.cpim.headers, fn {k, _} -> k == "Segment-ID" end)
    assert {"Segment-Index", "1"} in first.cpim.headers
    assert {"Segment-Count", "3"} in first.cpim.headers
    assert first.cpim.body == "hello"
    assert length(context.additional_outbound_pdus) == 2
  end

  test "InboundReassemblyPlugin reassembles out-of-order segments" do
    {:ok, manager} = PluginManager.init(inbound: [InboundReassemblyPlugin])

    seg2 =
      request_pdu(
        [{"TX-ID", "tx-seg2"}, {"Segment-ID", "s-1"}, {"Segment-Index", "2"}, {"Segment-Count", "2"}],
        "world"
      )

    {:halt, [], context1, manager} = PluginManager.run_inbound(manager, seg2, %{})
    assert context1.reassembly_waiting.segment_index == 2

    seg1 =
      request_pdu(
        [{"TX-ID", "tx-seg2"}, {"Segment-ID", "s-1"}, {"Segment-Index", "1"}, {"Segment-Count", "2"}],
        "hello"
      )

    {:ok, reassembled, context2, _manager} = PluginManager.run_inbound(manager, seg1, %{})
    assert reassembled.cpim.body == "helloworld"
    assert context2.reassembled.segment_id == "s-1"
    refute Enum.any?(reassembled.cpim.headers, fn {k, _} -> k in ["Segment-ID", "Segment-Index", "Segment-Count"] end)
  end

  defp request_pdu(headers, body \\ "") do
    %Pdu{
      reference: make_ref(),
      start_line: StartLine.new_request("REG", "/resource"),
      cpim: %CPIM{headers: headers, body: body}
    }
  end

  defp response_pdu(status_code, status_text, headers) do
    %Pdu{
      reference: make_ref(),
      start_line: StartLine.new_response(status_code, status_text),
      cpim: %CPIM{headers: headers, body: ""}
    }
  end
end

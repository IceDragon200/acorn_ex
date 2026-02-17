defmodule Acorn.PluginManagerTest do
  use ExUnit.Case, async: true

  alias Acorn.CPIM
  alias Acorn.Pdu
  alias Acorn.Plugin
  alias Acorn.PluginManager
  alias Acorn.StartLine

  defmodule InboundTaggerPlugin do
    use Plugin

    @impl true
    def init(opts), do: {:ok, %{name: Keyword.fetch!(opts, :name)}}

    @impl true
    def handle_inbound(%Pdu{} = pdu, context, state) do
      %CPIM{} = cpim = pdu.cpim
      cpim = %CPIM{cpim | headers: [{state.name, "1"} | cpim.headers]}
      {:cont, %Pdu{pdu | cpim: cpim}, Map.put(context, state.name, true), state}
    end
  end

  defmodule OutboundDestRewritePlugin do
    use Plugin

    @impl true
    def handle_outbound(%Pdu{} = pdu, _dest, from, context, state) do
      next_dest = %{family: :inet, addr: {127, 0, 0, 1}, port: 9000}
      {:cont, pdu, next_dest, from, Map.put(context, :rewritten, true), state}
    end
  end

  defmodule HaltInboundPlugin do
    use Plugin

    @impl true
    def handle_inbound(%Pdu{} = _pdu, context, state) do
      response = %Pdu{
        reference: make_ref(),
        start_line: StartLine.new_request("ACK", "/resource"),
        cpim: %CPIM{headers: [{"Content-Type", "application/octet-stream"}], body: "ok"}
      }

      {:halt, [{:send, response, %{family: :inet, addr: {127, 0, 0, 1}, port: 7600}}],
       Map.put(context, :halted, true), state}
    end
  end

  test "runs inbound plugins in order and persists state" do
    {:ok, manager} =
      PluginManager.init(
        inbound: [
          {InboundTaggerPlugin, name: "X-One"},
          {InboundTaggerPlugin, name: "X-Two"}
        ]
      )

    {:ok, pdu, context, manager} = PluginManager.run_inbound(manager, make_pdu("REG"), %{})

    assert context["X-One"] == true
    assert context["X-Two"] == true
    assert {"X-One", "1"} in pdu.cpim.headers
    assert {"X-Two", "1"} in pdu.cpim.headers

    assert length(manager.inbound) == 2
  end

  test "allows outbound plugin to rewrite destination" do
    {:ok, manager} = PluginManager.init(outbound: [OutboundDestRewritePlugin])

    original_dest = %{family: :inet, addr: {10, 0, 0, 1}, port: 7000}
    from = {self(), make_ref()}

    {:ok, _pdu, dest, ^from, context, _manager} =
      PluginManager.run_outbound(manager, make_pdu("PING"), original_dest, from, %{})

    assert dest == %{family: :inet, addr: {127, 0, 0, 1}, port: 9000}
    assert context.rewritten
  end

  test "inbound plugin can halt the chain with precomputed responses" do
    {:ok, manager} =
      PluginManager.init(inbound: [HaltInboundPlugin, {InboundTaggerPlugin, name: "X-Late"}])

    {:halt, responses, context, manager} = PluginManager.run_inbound(manager, make_pdu("REG"), %{})

    assert [{:send, %Pdu{}, %{port: 7600}}] = responses
    assert context.halted
    assert length(manager.inbound) == 2
  end

  defp make_pdu(method) do
    %Pdu{
      reference: make_ref(),
      start_line: StartLine.new_request(method, "/resource"),
      cpim: %CPIM{headers: [{"Content-Type", "application/octet-stream"}], body: "hello"}
    }
  end
end

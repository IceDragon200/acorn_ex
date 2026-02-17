defmodule Acorn.KV.Protocol.UDPTest do
  use ExUnit.Case

  alias Acorn.KV.Protocol.UDP

  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  describe "start_link/1" do
    test "can start a udp listener" do
      expect Acorn.Support.MockHandle, :init, fn [] ->
        {:ok, %{}}
      end

      {:ok, server} = UDP.start_link(
        module: Acorn.Support.MockHandle,
        options: [],
        bind: %{
          family: :inet,
          port: 7600,
          addr: {0, 0, 0, 0}
        }
      )

      :ok = UDP.stop(server)
    end
  end
end

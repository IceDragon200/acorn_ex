defmodule Acorn.PduTest do
  use ExUnit.Case

  alias Acorn.CPIM
  alias Acorn.Pdu
  alias Acorn.StartLine

  test "encode/1 builds wire-compatible iodata" do
    pdu = %Pdu{
      reference: make_ref(),
      start_line: StartLine.new_request("REG", "/merci"),
      cpim: %CPIM{
        headers: [{"Content-Type", "application/octet-stream"}],
        body: "Hello, World\r\n"
      }
    }

    assert {:ok, iodata} = Pdu.encode(pdu)

    assert IO.iodata_to_binary(iodata) ==
             "REG /merci ACORN/1.0\r\nContent-Type: application/octet-stream\r\n\r\nHello, World\r\n"
  end

  test "encode/1 rejects CRLF injection in request method token" do
    pdu = %Pdu{
      reference: make_ref(),
      start_line: StartLine.new_request("REG\r\nX-Evil: 1", "/merci"),
      cpim: %CPIM{
        headers: [{"Content-Type", "application/octet-stream"}],
        body: "Hello, World\r\n"
      }
    }

    assert :error = Pdu.encode(pdu)
  end
end

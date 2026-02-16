defmodule Acorn.ProtocolTest do
  use ExUnit.Case

  alias Acorn.StartLine

  describe "parse_start_line/1 [REQUEST]" do
    test "can parse a literal request target start line" do
      assert {:ok, %StartLine{
        type: :request,
        version: "ACORN/1.0",
        method: "REG",
        request_target: "/merci",
      }, ""} == Acorn.Protocol.parse_start_line("REG /merci ACORN/1.0\r\n")
    end

    test "can parse a string/quoted request target start line" do
      assert {:ok, %StartLine{
        type: :request,
        version: "ACORN/1.0",
        method: "REG",
        request_target: "/look ma i can haz spaces",
      }, ""} == Acorn.Protocol.parse_start_line("REG \"/look ma i can haz spaces\" ACORN/1.0\r\n")
    end

    test "returns :error for unknown escape sequence in quoted request target" do
      assert :error ==
               Acorn.Protocol.parse_start_line("REG \"/look\\q\" ACORN/1.0\r\n")
    end

    test "returns :error for unterminated quoted request target" do
      assert :error ==
               Acorn.Protocol.parse_start_line("REG \"/look ma ACORN/1.0\r\n")
    end

    test "returns :error when request version is empty" do
      assert :error ==
               Acorn.Protocol.parse_start_line("REG /merci \r\n")
    end

    test "returns :error for repeated spaces between method and request-target" do
      assert :error ==
               Acorn.Protocol.parse_start_line("REG  /merci ACORN/1.0\r\n")
    end

    test "returns :error when method token is empty" do
      assert :error ==
               Acorn.Protocol.parse_start_line(" /merci ACORN/1.0\r\n")
    end

    test "returns :error when method token contains tab character" do
      assert :error ==
               Acorn.Protocol.parse_start_line("RE\tG /merci ACORN/1.0\r\n")
    end
  end

  describe "parse_start_line/1 [RESPONSE]" do
    test "can parse a response start line" do
      assert {:ok, %StartLine{
        type: :response,
        version: "ACORN/1.0",
        status_code: "200",
        status_text: "Sure, why not",
      }, ""} == Acorn.Protocol.parse_start_line("ACORN/1.0 200 Sure, why not\r\n")
    end

    test "can parse a response start line with no status text" do
      assert {:ok, %StartLine{
        type: :response,
        version: "ACORN/1.0",
        status_code: "200",
        status_text: "",
      }, ""} == Acorn.Protocol.parse_start_line("ACORN/1.0 200\r\n")

      assert {:ok, %StartLine{
        type: :response,
        version: "ACORN/1.0",
        status_code: "200",
        status_text: "",
      }, ""} == Acorn.Protocol.parse_start_line("ACORN/1.0 200 \r\n")
    end

    test "returns :error when response status code is empty" do
      assert :error == Acorn.Protocol.parse_start_line("ACORN/1.0 \r\n")
    end

    test "returns :error for repeated spaces between version and status code" do
      assert :error == Acorn.Protocol.parse_start_line("ACORN/1.0  200 OK\r\n")
    end

    test "returns :error when status code is not exactly 3 digits" do
      assert :error == Acorn.Protocol.parse_start_line("ACORN/1.0 20 OK\r\n")
      assert :error == Acorn.Protocol.parse_start_line("ACORN/1.0 2000 OK\r\n")
    end
  end
end

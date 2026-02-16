defmodule Acorn.CPIMTest do
  use ExUnit.Case

  alias Acorn.CPIM

  describe "parse/1" do
    test "can parse a simple CPIM" do
      blob =
        """
        Content-Type: application/octet-stream\r
        \r
        Hello, World\r
        """

      assert {:ok, %CPIM{
        headers: [
          {"Content-Type", "application/octet-stream"},
        ],
        body: "Hello, World\r\n"
      }} = CPIM.parse(blob)
    end

    test "parse/1 rejects headers with empty header name" do
      blob =
        """
        : application/octet-stream\r
        \r
        Hello, World\r
        """

      assert :error = CPIM.parse(blob)
    end
  end

  describe "encode/1" do
    test "encode/1 renders headers and body to wire format" do
      cpim = %CPIM{
        headers: [{"Content-Type", "application/octet-stream"}],
        body: "Hello, World\r\n"
      }

      assert {:ok, iodata} = CPIM.encode(cpim)

      assert """
      Content-Type: application/octet-stream\r
      \r
      Hello, World\r
      """ == IO.iodata_to_binary(iodata)
    end

    test "parse/1 of empty blob returns encodable empty body" do
      assert {:ok, %CPIM{} = cpim} = CPIM.parse("")
      assert cpim.body == ""

      assert {:ok, iodata} = CPIM.encode(cpim)
      assert IO.iodata_to_binary(iodata) == "\r\n"
    end

    test "encode/1 rejects CRLF injection in header value" do
      cpim = %CPIM{
        headers: [{"Content-Type", "text/plain\r\nX-Evil: 1"}],
        body: "Hello, World\r\n"
      }

      assert :error = CPIM.encode(cpim)
    end
  end

  describe "encode_header_pair/1" do
    test "can encode a header pair" do
      assert {:ok, ["A", ": ", "XYZ", "\r\n"]} == CPIM.encode_header_pair("A", "XYZ")
      assert {:ok, ["A", ": ", "\"\\r\\n\"", "\r\n"]} == CPIM.encode_header_pair("A", "\r\n")
      assert {:ok, ["Content-Type", ": ", "application/vnd.api+json; charset=\\\"utf-8\\\"", "\r\n"]} ==
        CPIM.encode_header_pair("Content-Type", "application/vnd.api+json; charset=\"utf-8\"")
    end
  end

  describe "encode_header_key/1" do
    test "can encode different header keys" do
      assert {:ok, "ALL_UPPER_CASE"} == CPIM.encode_header_key("ALL_UPPER_CASE")
      assert {:ok, "123-xyz-88-blah-de-dah"} == CPIM.encode_header_key("123-xyz-88-blah-de-dah")
      assert {:ok, "Content-Type"} == CPIM.encode_header_key("Content-Type")
    end
  end

  describe "encode_header_value/1" do
    test "can encode header values" do
      assert {:ok, "vnd.api+json"} == CPIM.encode_header_value("vnd.api+json")
      assert {:ok, "a=2,b=3,c=4"} == CPIM.encode_header_value("a=2,b=3,c=4")
      assert {:ok, "a=2; b=3; c=4"} == CPIM.encode_header_value("a=2; b=3; c=4")
      assert {:ok, "\\\"explicit quotes\\\""} == CPIM.encode_header_value("\"explicit quotes\"")
      assert {:ok, "application/vnd.api+json"} == CPIM.encode_header_value("application/vnd.api+json")
      assert {:ok, "application/vnd.api+json; charset=\\\"utf-8\\\""} == CPIM.encode_header_value("application/vnd.api+json; charset=\"utf-8\"")
    end

    test "can encode raw newlines" do
      assert {:ok, "\"\\r\\n\""} == CPIM.encode_header_value("\r\n")
    end

    test "can handle mixed literal with newline, if the newline leads" do
      assert {:ok, "\"\\r\\nmixed=\\\"\\\"\""} == CPIM.encode_header_value("\r\nmixed=\"\"")
    end

    test "cannot mix raw newlines with mixed_literal context" do
      assert :error == CPIM.encode_header_value("mixed=\"\"\r\n")
    end
  end
end

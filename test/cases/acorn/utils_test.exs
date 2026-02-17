defmodule Acorn.UtilsTest do
  use ExUnit.Case

  alias Acorn.Utils

  describe "is_integral_string?/1" do
    test "reports if string is just numbers" do
      assert true == Utils.is_integral_string?("200")
      assert false == Utils.is_integral_string?("20X")
      assert false == Utils.is_integral_string?("")
      assert false == Utils.is_integral_string?(" ")
    end
  end

  describe "parse_word/1" do
    test "can parse strings out as word units" do
      assert {:ok, "WORD", ""} == Utils.parse_word("WORD")
      assert {:ok, "WORD-ON_WORD", ""} == Utils.parse_word("WORD-ON_WORD")
      assert {:ok, "WORD", "\r\n"} == Utils.parse_word("WORD\r\n")
      assert {:ok, "1.0", "\r\n"} == Utils.parse_word("1.0\r\n")
      assert {:ok, "ACORN", "/1.0\r\n"} == Utils.parse_word("ACORN/1.0\r\n")
    end

    test "empty strings are not valid words" do
      assert :error == Utils.parse_word("")
      assert :error == Utils.parse_word(" ")
      assert :error == Utils.parse_word("\r\n")
    end
  end

  describe "parse_inet_address/1" do
    test "parses valid IPv4 and IPv6 addresses" do
      assert {:ok, {127, 0, 0, 1}} == Utils.parse_inet_address("127.0.0.1")
      assert {:ok, {0, 0, 0, 0, 0, 0, 0, 1}} == Utils.parse_inet_address("::1")
    end

    test "returns :error for invalid address values" do
      assert :error == Utils.parse_inet_address("999.0.0.1")
      assert :error == Utils.parse_inet_address("not-an-ip")
    end
  end

  describe "encode_inet_address/1" do
    test "encodes inet address tuples back to string format" do
      assert {:ok, "127.0.0.1"} == Utils.encode_inet_address({127, 0, 0, 1})
      assert {:ok, "::1"} == Utils.encode_inet_address({0, 0, 0, 0, 0, 0, 0, 1})
    end

    test "returns :error for non-address values" do
      assert :error == Utils.encode_inet_address(:not_an_address)
    end
  end

  describe "encode_identity/2" do
    test "encodes identity with node name" do
      assert {:ok, "node-a@127.0.0.1:7077"} ==
               Utils.encode_identity("node-a", %{addr: {127, 0, 0, 1}, port: 7077})
    end

    test "encodes identity without node name" do
      assert {:ok, "127.0.0.1:7077"} ==
               Utils.encode_identity(nil, %{addr: {127, 0, 0, 1}, port: 7077})
    end

    test "returns :error for invalid identity input" do
      assert :error == Utils.encode_identity("node-a", %{addr: :bad, port: 7077})
      assert :error == Utils.encode_identity("node-a", %{addr: {127, 0, 0, 1}, port: 99_999})
    end
  end
end

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
end

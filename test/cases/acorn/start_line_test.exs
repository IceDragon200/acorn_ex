defmodule Acorn.StartLineTest do
  use ExUnit.Case

  alias Acorn.StartLine

  describe "parse_version/1" do
    test "can parse version-like strings" do
      assert {:ok, "ACORN/1.0", " Other stuff happening here"} == StartLine.parse_version("ACORN/1.0 Other stuff happening here")
      assert {:ok, "THIS_SOME_BS/1.0", "\r\n"} == StartLine.parse_version("THIS_SOME_BS/1.0\r\n")
      assert :error = StartLine.parse_version("lol no/1.0")
    end
  end
end

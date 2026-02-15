defmodule Acorn.CPIMTest do
  use ExUnit.Case

  alias Acorn.CPIM

  describe "can parse a simple CPIM" do
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
end

defmodule Acorn.Protocol do
  @spec parse_start_line(binary()) :: {:ok, Acorn.StartLine.t(), binary()}
  def parse_start_line(blob) do
    Acorn.StartLine.parse(blob)
  end
end

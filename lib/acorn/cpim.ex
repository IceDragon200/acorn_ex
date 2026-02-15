defmodule Acorn.CPIM do
  defstruct [
    headers: [],
    body: nil
  ]

  @type t :: %__MODULE__{
    headers: [{binary(), binary()}],
    body: binary()
  }

  @spec encode(t()) :: {:ok, iodata()}
  def encode(%__MODULE__{} = cpim) do
    {:ok, [
      Enum.map(cpim, fn {key, value} ->
        [key, ": ", value, "\r\n"]
      end),
      "\r\n",
      cpim.body
    ]}
  end

  @spec parse(binary()) :: {:ok, t()} | :error
  def parse(blob) when is_binary(blob) do
    parse(blob, :headers, %__MODULE__{})
  end

  def parse(<<>>, _, %__MODULE__{} = cpim) do
    {:ok, %__MODULE__{cpim | headers: Enum.reverse(cpim.headers)}}
  end

  def parse(<<"\r\n", rest::binary>>, :headers, %__MODULE__{} = cpim) do
    parse(<<>>, :body, %__MODULE__{cpim | body: rest})
  end

  def parse(rest, :headers = state, %__MODULE__{} = cpim) do
    case :binary.split(rest, "\r\n") do
      [header, rest] ->
        case :binary.split(header, ": ") do
          [name, value] ->
            parse(rest, state, %__MODULE__{cpim | headers: [{name, value} | cpim.headers]})

          _ ->
            :error
        end

      [_] ->
        :error
    end
  end
end

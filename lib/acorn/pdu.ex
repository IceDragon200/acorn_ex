defmodule Acorn.Pdu do
  defstruct [
    reference: nil,
    start_line: nil,
    cpim: nil,
  ]

  @type t :: %__MODULE__{
    reference: reference(),
    start_line: Acorn.StartLine.t(),
    cpim: Acorn.CPIM.t(),
  }

  @spec encode(t()) :: {:ok, iodata()}
  def encode(%__MODULE__{} = pdu) do
    {:ok, [
      Acorn.StartLine.encode(pdu.start_line),
      Acorn.CPIM.encode(pdu.cpim),
    ]}
  end

  def parse(blob) do
    case Acorn.Protocol.parse_start_line(blob) do
      {:ok, %Acorn.StartLine{} = sl, rest} ->
        case Acorn.CPIM.parse(rest) do
          {:ok, %Acorn.CPIM{} = cpim} ->
            pdu = %__MODULE__{
              reference: make_ref(),
              start_line: sl,
              cpim: cpim
            }
            {:ok, pdu}

          :error ->
            :error
        end

      :error ->
        :error
    end
  end
end

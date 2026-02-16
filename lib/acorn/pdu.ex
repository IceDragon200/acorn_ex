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
    with {:ok, start_line} <- Acorn.StartLine.encode(pdu.start_line),
         {:ok, cpim} <- Acorn.CPIM.encode(pdu.cpim) do
      {:ok, [start_line, cpim]}
    end
  end

  @spec parse(binary()) :: {:ok, t()} | :error
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

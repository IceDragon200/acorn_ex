defmodule Acorn.HandlerModule do
  @type assigns :: any()

  @callback init(any()) :: {:ok, assigns()}

  @callback handle_pdu(Acorn.Pdu.t()) :: {:reply, list(), assigns()}
end

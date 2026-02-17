defmodule Acorn.HandlerModule do
  @type socket :: any()

  @type assigns :: any()

  @callback init(any()) :: {:ok, assigns()}

  @doc """
  Handle an incoming/received PDU, the handler is responsible for generating a response and
  returning it.
  """
  @callback handle_pdu(Acorn.Pdu.t(), assigns()) :: {:reply, list(), assigns()}

  @doc """
  """
  @callback send_pdu(socket(), Acorn.Pdu.t(), dest::any(), from::any(), assigns()) :: {:ok, assigns()}
end

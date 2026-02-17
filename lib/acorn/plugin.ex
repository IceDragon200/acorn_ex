defmodule Acorn.Plugin do
  @moduledoc """
  Behaviour for inbound and outbound protocol layers.

  Layers can mutate the PDU/context, halt further processing, or report an error.
  """

  @type context :: map()
  @type plugin_state :: any()

  @callback init(keyword()) :: {:ok, plugin_state()} | {:error, any()}

  @callback handle_inbound(Acorn.Pdu.t(), context(), plugin_state()) ::
              {:cont, Acorn.Pdu.t(), context(), plugin_state()}
              | {:halt, list(), context(), plugin_state()}
              | {:error, any(), plugin_state()}

  @callback handle_outbound(Acorn.Pdu.t(), dest :: any(), from :: any(), context(), plugin_state()) ::
              {:cont, Acorn.Pdu.t(), dest :: any(), from :: any(), context(), plugin_state()}
              | {:halt, context(), plugin_state()}
              | {:error, any(), plugin_state()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Acorn.Plugin

      @impl true
      def init(_opts), do: {:ok, %{}}

      @impl true
      def handle_inbound(%Acorn.Pdu{} = pdu, context, state), do: {:cont, pdu, context, state}

      @impl true
      def handle_outbound(%Acorn.Pdu{} = pdu, dest, from, context, state),
        do: {:cont, pdu, dest, from, context, state}

      defoverridable init: 1, handle_inbound: 3, handle_outbound: 5
    end
  end
end

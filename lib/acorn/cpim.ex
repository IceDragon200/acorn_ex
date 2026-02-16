defmodule Acorn.CPIM do
  import Acorn.Utils

  defstruct [
    headers: [],
    body: ""
  ]

  @type t :: %__MODULE__{
    headers: [{binary(), binary()}],
    body: binary()
  }

  defguard is_utf8_ascii_header_symbol?(c) when c in [?!, ?@, ?#, ?$, ?%, ?^, ?&, ?*, ?(, ?), ?[, ?], ?{, ?}, ?<, ?>, ?,, ?., ?/, ?', ?;, ?+, ?-, ?_, ?=]

  @spec encode(t()) :: {:ok, iodata()}
  def encode(%__MODULE__{} = cpim) do
    with {:ok, headers} <- encode_headers(cpim.headers) do
      {:ok, [headers, "\r\n", cpim.body]}
    end
  end

  def encode_headers(headers) do
    {:ok, Enum.map(headers, fn {key, value} ->
      case encode_header_pair(key, value) do
        {:ok, res} ->
          res

        :error ->
          throw :error
      end
    end)}
  catch :error ->
    :error
  end

  def encode_header_pair(key, value) do
    with {:ok, key} <- encode_header_key(key),
         {:ok, value} <- encode_header_value(value) do
      {:ok, [key, ": ", value, "\r\n"]}
    end
  end

  @spec encode_header_key(binary()) :: {:ok, String.t()} | :error
  def encode_header_key(key) when is_binary(key) do
    with {:ok, _, ""} <- parse_word(key) do
      # if it ain't a valid word, then it's not a valid key.
      {:ok, key}
    end
  end

  def encode_header_key(_) do
    :error
  end

  @spec encode_header_value(binary()) :: {:ok, String.t()} | :error
  def encode_header_value(value) when is_binary(value) do
    encode_header_value(value, :literal, [])
  end

  def encode_header_value(_) do
    :error
  end

  def encode_header_value(<<>>, :mixed_literal, acc) do
    res =
      acc
      |> Enum.reverse()
      |> iodata_to_utf8_binary()

    {:ok, res}
  end

  def encode_header_value(<<>>, :literal, acc) do
    res =
      acc
      |> Enum.reverse()
      |> iodata_to_utf8_binary()

    {:ok, res}
  end

  def encode_header_value(<<>>, :quoted, acc) do
    res =
      [?", Enum.reverse(acc), ?"]
      |> iodata_to_utf8_binary()

    {:ok, res}
  end

  def encode_header_value(<<c::utf8, rest::binary>>, state, acc) do
    cond do
      c == ?\s or c == ?\t or is_utf8_ascii_header_symbol?(c) or is_utf8_ascii_letter_char?(c) or is_utf8_digit_char?(c) ->
        encode_header_value(rest, state, [c | acc])

      c == ?" ->
        case state do
          state when state in [:literal, :mixed_literal] ->
            encode_header_value(rest, :mixed_literal, [?", ?\\ | acc])

          :quoted ->
            encode_header_value(rest, state, [?", ?\\ | acc])
        end

      state in [:literal, :quoted] and c == ?\r ->
        encode_header_value(rest, :quoted, [?r, ?\\ | acc])

      state in [:literal, :quoted] and c == ?\n ->
        encode_header_value(rest, :quoted, [?n, ?\\ | acc])

      true ->
        :error
    end
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
            with {:ok, name} <- validate_header_name(name) do
              parse(rest, state, %__MODULE__{cpim | headers: [{name, value} | cpim.headers]})
            end

          _ ->
            :error
        end

      [_] ->
        :error
    end
  end

  @spec validate_header_name(String.t()) :: {:ok, String.t()} | :error
  def validate_header_name(name) when is_binary(name) do
    validate_header_name(name, :start, [])
  end

  def validate_header_name(<<>>, :start, _acc) do
    :error
  end

  def validate_header_name(<<>>, :body, acc) do
    {:ok, IO.iodata_to_binary(Enum.reverse(acc))}
  end

  def validate_header_name(<<c::utf8, rest::binary>>, :start, acc) do
    case c do
      c when is_utf8_ascii_letter_char?(c) ->
        validate_header_name(rest, :body, [c | acc])

      _ ->
        :error
    end
  end

  def validate_header_name(<<c::utf8, rest::binary>>, :body, acc) do
    case c do
      c when c == ?- or is_utf8_ascii_letter_char?(c) or is_utf8_digit_char?(c) ->
        validate_header_name(rest, :body, [c | acc])

      _ ->
        :error
    end
  end
end

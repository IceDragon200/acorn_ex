defmodule Acorn.StartLine do
  defstruct [
    type: nil,
    version: nil,
    method: nil,
    request_target: nil,
    status_code: nil,
    status_text: nil
  ]

  @type t :: %__MODULE__{
    type: :request | :response,
    version: String.t(),
    method: nil | String.t(),
    request_target: nil | String.t(),
    status_code: nil | String.t(),
    status_text: nil | String.t(),
  }

  @default_version "ACORN/1.0"

  def new_request(method, request_target, version \\ @default_version) do
    %__MODULE__{
      type: :request,
      method: method,
      request_target: request_target,
      version: version,
    }
  end

  def new_response(status_code, status_text \\ "", version \\ @default_version) do
    %__MODULE__{
      type: :response,
      status_code: status_code,
      status_text: status_text,
      version: version,
    }
  end

  @spec encode(t()) :: {:ok, iodata()}
  def encode(%__MODULE__{} = subject) do
    case subject.type do
      :request ->
        request_target = maybe_escape_request_target(subject.request_target)
        {:ok, [subject.method, " ", request_target, " ", subject.version, "\r\n"]}

      :response ->
        case subject.status_text || "" do
          "" ->
            {:ok, [subject.version, " ", subject.status_code, "\r\n"]}

          _ ->
            {:ok, [subject.version, " ", subject.status_code, " ", subject.status_text, "\r\n"]}
        end
    end
  end

  @spec parse(binary()) :: {:ok, t(), binary()} | :error
  def parse(rest) when is_binary(rest) do
    case :binary.split(rest, "\r\n") do
      [line, rest] ->
        case :binary.split(line, " ") do
          [method_or_version, line] ->
            case String.upcase(method_or_version) do
              <<"ACORN/", _::binary>> ->
                case parse_response(method_or_version, line) do
                  {:ok, %__MODULE__{} = res} ->
                    {:ok, res, rest}

                  # :error ->
                  #   :error
                end

              _method ->
                case parse_request(method_or_version, line) do
                  {:ok, %__MODULE__{} = res} ->
                    {:ok, res, rest}

                  :error ->
                    :error
                end
            end

          [_] ->
            :error
        end

      [_] ->
        :error
    end
  end

  @spec parse_response(String.t(), binary()) :: {:ok, t()}
  def parse_response(version, line) do
    start_line = %__MODULE__{
      type: :response,
      version: version,
    }
    case :binary.split(line, " ") do
      [status_code, status_text] ->
        %__MODULE__{} = start_line =
          %__MODULE__{
            start_line
            | status_code: status_code,
              status_text: status_text
          }

        {:ok, start_line}

      [status_code] ->
        %__MODULE__{} = start_line =
          %__MODULE__{
            start_line
            | status_code: status_code,
              status_text: ""
          }

        {:ok, start_line}
    end
  end

  @spec parse_request(String.t(), binary()) :: {:ok, t()}
  def parse_request(method, line) do
    start_line = %__MODULE__{
      type: :request,
      method: method
    }

    case parse_request_target(line) do
      {:ok, request_target, line} ->
        case :binary.split(line, " ") do
          ["", version] ->
            start_line =
              %__MODULE__{
                start_line
                | request_target: request_target,
                  version: version
              }
            {:ok, start_line}

          [_] ->
            :error
        end

      :error ->
        :error
    end
  end

  @spec parse_request_target(binary()) ::
    {:ok, request_target::binary(), rest::binary()}
    | :error
  def parse_request_target(rest) do
    parse_request_target(rest, :start, [])
  end

  def parse_request_target(rest, :end, acc) do
    {:ok, reversed_charlist_to_utf8_binary(acc), rest}
  end

  def parse_request_target(<<>> = rest, :literal, acc) do
    {:ok, reversed_charlist_to_utf8_binary(acc), rest}
  end

  def parse_request_target(<<>>, :start, _) do
    :error
  end

  def parse_request_target(<<c::utf8, rest::binary>>, :start, acc) do
    case c do
      ?" ->
        parse_request_target(rest, :quoted, acc)

      _ ->
        parse_request_target(rest, :literal, [c | acc])
    end
  end

  def parse_request_target(<<?", rest::binary>>, :quoted, acc) do
    parse_request_target(rest, :end, acc)
  end

  def parse_request_target(<<c::utf8, rest::binary>>, :quoted = state, acc) do
    case c do
      ?\\ ->
        case rest do
          <<c::utf8, rest::binary>> ->
            case c do
              ?r ->
                parse_request_target(rest, state, [?\r | acc])

              ?n ->
                parse_request_target(rest, state, [?\n | acc])

              ?" ->
                parse_request_target(rest, state, [?" | acc])

              ?\\ ->
                parse_request_target(rest, state, [?\\ | acc])
            end

          _ ->
            :error
        end

      _ ->
        parse_request_target(rest, state, [c | acc])
    end
  end

  def parse_request_target(<<" ", _rest::binary>> = rest, :literal, acc) do
    parse_request_target(rest, :end, acc)
  end

  def parse_request_target(<<c::utf8, rest::binary>>, :literal = state, acc) do
    parse_request_target(rest, state, [c | acc])
  end

  @spec reversed_charlist_to_utf8_binary(list()) :: binary()
  def reversed_charlist_to_utf8_binary(acc) do
    reversed_charlist_to_utf8_binary(acc, <<>>)
  end

  def reversed_charlist_to_utf8_binary([], acc) do
    acc
  end

  def reversed_charlist_to_utf8_binary([c | rest], acc) when is_integer(c) do
    reversed_charlist_to_utf8_binary(rest, <<c::utf8, acc::binary>>)
  end

  def reversed_charlist_to_utf8_binary([rest | rest2], acc) when is_list(rest) do
    acc = reversed_charlist_to_utf8_binary(rest, acc)
    reversed_charlist_to_utf8_binary(rest2, acc)
  end

  def maybe_escape_request_target(str) do
    maybe_escape_request_target(str, :literal, [])
  end

  def maybe_escape_request_target(<<>>, :literal, acc) do
    reversed_charlist_to_utf8_binary(acc)
  end

  def maybe_escape_request_target(<<>>, :quoted, acc) do
    reversed_charlist_to_utf8_binary([?", acc, ?"])
  end

  def maybe_escape_request_target(<<c::utf8, rest::binary>>, state, acc) do
    case c do
      ?\r ->
        maybe_escape_request_target(rest, :quoted, [?r, ?\\ | acc])

      ?\n ->
        maybe_escape_request_target(rest, :quoted, [?n, ?\\ | acc])

      c when c in [?", ?\\] ->
        maybe_escape_request_target(rest, :quoted, [c, ?\\ | acc])

      ?\s ->
        maybe_escape_request_target(rest, :quoted, [c | acc])

      _ ->
        maybe_escape_request_target(rest, state, [c | acc])
    end
  end
end

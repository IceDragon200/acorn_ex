defmodule Acorn.StartLine do
  import Acorn.Utils

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
        with {:ok, method, ""} <- parse_word(subject.method),
             {:ok, version} <- validate_version(subject.version) do
          {:ok, [method, " ", request_target, " ", version, "\r\n"]}
        else
          {:ok, _, _} -> :error
          :error -> :error
        end

      :response ->
        case subject.status_text || "" do
          "" ->
            {:ok, [subject.version, " ", subject.status_code, "\r\n"]}

          _ ->
            {:ok, [subject.version, " ", subject.status_code, " ", subject.status_text, "\r\n"]}
        end
    end
  end

  @spec parse(binary()) :: {:ok, t(), rest::binary()} | :error
  def parse(rest) when is_binary(rest) do
    case parse_version(rest) do
      {:ok, version, rest} ->
        with {:ok, version} <- validate_version(version),
             {:ok, rest} <- chomp_space(rest),
             {:ok, %__MODULE__{} = res, rest} <- parse_response(version, rest) do
          {:ok, res, rest}
        end

      :error ->
        with {:ok, method, rest} <- parse_word(rest),
             {:ok, rest} <- chomp_space(rest),
             {:ok, %__MODULE__{} = res, rest} <- parse_request(method, rest) do
          {:ok, res, rest}
        end
    end
  end

  @spec parse_response(String.t(), binary()) :: {:ok, t(), rest::binary()}
  def parse_response(version, rest) do
    start_line = %__MODULE__{
      type: :response,
      version: version,
    }
    with {:ok, status_code, rest} <- parse_word(rest),
         {:ok, status_code} <- validate_status_code(status_code) do
      {status_text, rest} =
        case rest do
          <<"\r\n", rest::binary>> ->
            {"", rest}

          <<?\s, rest::binary>> ->
            case :binary.split(rest, "\r\n") do
              [status_text, rest] ->
                {status_text, rest}

              [status_text] ->
                {status_text, ""}
            end

          :error ->
            throw :error
        end

      %__MODULE__{} = start_line =
        %__MODULE__{
          start_line
          | status_code: status_code,
            status_text: status_text
        }

      {:ok, start_line, rest}
    end
  catch :error ->
    :error
  end

  def validate_status_code(status_code) do
    if is_integral_string?(status_code) do
      if byte_size(status_code) == 3 do
        {:ok, status_code}
      else
        :error
      end
    else
      :error
    end
  end

  @spec parse_request(String.t(), binary()) :: {:ok, t(), rest::binary()}
  def parse_request(method, rest) do
    start_line = %__MODULE__{
      type: :request,
      method: method
    }

    case parse_request_target(rest) do
      {:ok, request_target, rest} ->
        {rest, count} = trim_leading_spaces(rest)
        case count do
          1 ->
            with {:ok, version, rest} <- parse_version(rest),
                 <<"\r\n", rest::binary>> <- rest,
                 {:ok, version} <- validate_version(version) do
              start_line =
                %__MODULE__{
                  start_line
                  | request_target: request_target,
                    version: version
                }
              {:ok, start_line, rest}
            else
              :error -> :error
              _ -> :error
            end

          _ ->
            :error
        end

      :error ->
        :error
    end
  end

  @spec parse_version(binary()) :: {:ok, version::binary(), rest::binary()} | :error
  def parse_version(str) when is_binary(str) do
    case parse_word(str) do
      {:ok, word, rest} ->
        case rest do
          <<?/, rest::binary>> ->
            case parse_word(rest) do
              {:ok, ver, rest} ->
                # we don't validate here, we just parse something that may be "version" like
                {:ok, <<word::binary, "/", ver::binary>>, rest}

              :error ->
                :error
            end

          _ ->
            :error
        end

      :error ->
        :error
    end
  end

  @spec validate_version(binary()) :: {:ok, binary()} | :error
  def validate_version(str) when is_binary(str) do
    case str do
      <<acorn::binary-size(5), "/", rest::binary>> ->
        case String.upcase(acorn) do
          "ACORN" ->
            with {:ok, _} <- parse_protocol_version(rest) do
              {:ok, str}
            end
          _ ->
            :error
        end

      _ ->
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

  def parse_request_target(<<>>, :quoted, _) do
    :error
  end

  def parse_request_target(<<>>, :start, _) do
    :error
  end

  def parse_request_target(<<c::utf8, rest::binary>>, :start, acc) do
    case c do
      ?" ->
        parse_request_target(rest, :quoted, acc)

      c when is_utf8_ascii_letter_char?(c) or c == ?/ or is_utf8_digit_char?(c) ->
        parse_request_target(rest, :literal, [c | acc])

      _ ->
        :error
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

              _ ->
                :error
            end

          _ ->
            :error
        end

      _ ->
        parse_request_target(rest, state, [c | acc])
    end
  end

  def parse_request_target(<<c::utf8, rest::binary>> = str, :literal = state, acc) do
    case c do
      ?/ ->
        parse_request_target(rest, state, [c | acc])

      c ->
        case Unicode.category(c) do
          cat when is_utf8_letter_category?(cat) or is_utf8_digit_category?(cat) ->
            parse_request_target(rest, state, [c | acc])

          _ ->
            parse_request_target(str, :end, acc)
        end
    end
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

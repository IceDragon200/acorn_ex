defmodule Acorn.Utils do
  defguard is_utf8_digit_char?(c) when c >= ?0 and c <= ?9
  defguard is_utf8_ascii_letter_char?(c) when (c >= ?A and c <= ?Z) or (c >= ?a and c <= ?z)
  defguard is_utf8_ascii_space_like_char?(c) when c in [?\t, ?\s]
  defguard is_utf8_letter_category?(c) when c in [:L, :Ll, :Lm, :Lo, :Lt, :Lu]
  defguard is_utf8_digit_category?(c) when c in [:N, :Nd, :Nl, :No]
  defguard is_utf8_newline_like_char(c) when c in [
    # New Line
    0x0A,
    # NP form feed, new pag
    0x0C,
    # Carriage Return
    0x0D,
    # Next-Line
    0x85,
    # Line Separator
    0x2028,
    # Paragraph Separator
    0x2029,
  ]
  defguard is_utf8_twochar_newline(c1, c2) when c1 == 0x0D and c2 == 0x0A

  @doc """
  Splits off as many characters from the string that would form a simple word (no leading numbers).
  """
  @spec parse_word(binary()) :: {:ok, word::binary(), rest::binary()} | :error
  def parse_word(str) when is_binary(str) do
    parse_word(str, :start, [])
  end

  def parse_word(rest, :end, acc) do
    word =
      acc
      |> Enum.reverse()
      |> iodata_to_utf8_binary()

    {:ok, word, rest}
  end

  def parse_word(<<>> = str, :body, acc) do
    parse_word(str, :end, acc)
  end

  def parse_word(<<c::utf8, rest::binary>> = str, state, acc) when state in [:start, :body] do
    cond do
      state == :body and c == ?- ->
        parse_word(rest, :body, [c | acc])

      c == ?. or c == ?_ or is_utf8_ascii_letter_char?(c) or is_utf8_digit_char?(c) ->
        parse_word(rest, :body, [c | acc])

      c ->
        cat = Unicode.category(c)
        cond do
          is_utf8_letter_category?(cat) or is_utf8_digit_category?(cat) ->
            parse_word(rest, :body, [c | acc])

          true ->
            case state do
              :body ->
                parse_word(str, :end, acc)

              :start ->
                :error
            end
        end
    end
  end

  def parse_word(_str, _state, _acc) do
    :error
  end

  @spec is_integral_string?(String.t(), integer()) :: boolean()
  def is_integral_string?(str, n \\ 0)

  def is_integral_string?(<<>>, n) do
    n > 0
  end

  def is_integral_string?(<<c::utf8, rest::binary>>, n) do
    if c >= ?0 and c <= ?9 do
      is_integral_string?(rest, n + 1)
    else
      false
    end
  end

  @spec parse_protocol_version(String.t()) :: {:ok, tuple()}
  def parse_protocol_version(str) do
    segments = String.split(str, ".")

    if Enum.all?(segments, &is_integral_string?/1) do
      l = length(segments)
      if l > 1 and l <= 4 do
        {:ok, List.to_tuple([l | segments])}
      else
        :error
      end
    else
      :error
    end
  end

  @spec iodata_to_utf8_binary(iodata()) :: binary()
  def iodata_to_utf8_binary(c) when is_integer(c) do
    <<c::utf8>>
  end

  def iodata_to_utf8_binary(str) when is_binary(str) do
    str
  end

  def iodata_to_utf8_binary(list) when is_list(list) do
    for item <- list, into: "" do
      iodata_to_utf8_binary(item)
    end
  end

  @spec trim_leading_spaces(binary(), integer()) :: binary()
  def trim_leading_spaces(str, count \\ 0)

  def trim_leading_spaces(<<?\s, rest::binary>>, count) do
    trim_leading_spaces(rest, count + 1)
  end

  def trim_leading_spaces(rest, count) when is_binary(rest) do
    {rest, count}
  end

  @spec chomp_space(binary()) :: {:ok, binary()} | :error
  def chomp_space(<<?\s, rest::binary>>) do
    {:ok, rest}
  end

  def chomp_space(_) do
    :error
  end
end

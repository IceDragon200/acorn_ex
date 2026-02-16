defmodule Acorn.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Acorn.CPIM
  alias Acorn.StartLine

  property "request start-line encode/parse roundtrips for valid inputs" do
    check all method <- method_gen(),
              request_target <- request_target_gen(),
              version <- version_gen() do
      start_line = StartLine.new_request(method, request_target, version)

      assert {:ok, encoded} = StartLine.encode(start_line)
      wire = IO.iodata_to_binary(encoded)

      assert {:ok, parsed, ""} = StartLine.parse(wire)
      assert parsed.type == :request
      assert parsed.method == method
      assert parsed.request_target == request_target
      assert parsed.version == version
    end
  end

  property "cpim encode/parse roundtrips for safe header values" do
    check all headers <- uniq_list_of(header_pair_gen(), max_length: 5),
              body <- body_gen() do
      cpim = %CPIM{headers: headers, body: body}

      assert {:ok, encoded} = CPIM.encode(cpim)
      wire = IO.iodata_to_binary(encoded)
      assert {:ok, parsed} = CPIM.parse(wire)

      assert parsed.headers == headers
      assert parsed.body == body
    end
  end

  property "start-line parser does not raise for arbitrary binary input" do
    check all blob <- binary(max_length: 256) do
      assert_no_throw(fn -> StartLine.parse(blob) end)
    end
  end

  property "cpim parser does not raise for arbitrary binary input" do
    check all blob <- binary(max_length: 256) do
      assert_no_throw(fn -> CPIM.parse(blob) end)
    end
  end

  defp assert_no_throw(fun) do
    try do
      _ = fun.()
      assert true
    rescue
      ex ->
        flunk("unexpected exception: #{Exception.message(ex)}")
    catch
      kind, reason ->
        flunk("unexpected throw/exit (#{inspect(kind)}): #{inspect(reason)}")
    end
  end

  defp method_gen do
    gen all first <- member_of(?A..?Z),
            rest <- list_of(member_of(Enum.to_list(?A..?Z) ++ Enum.to_list(?0..?9)), max_length: 10) do
      List.to_string([first | rest])
    end
  end

  defp request_target_gen do
    one_of([
      literal_request_target_gen(),
      quoted_request_target_gen()
    ])
  end

  defp literal_request_target_gen do
    allowed =
      Enum.to_list(?a..?z) ++
        Enum.to_list(?A..?Z) ++
        Enum.to_list(?0..?9) ++
        [?/]

    list_of(member_of(allowed), min_length: 1, max_length: 60)
    |> map(&List.to_string/1)
  end

  defp quoted_request_target_gen do
    # Leading space guarantees encoder emits quoted form.
    allowed =
      Enum.to_list(?a..?z) ++
        Enum.to_list(?A..?Z) ++
        Enum.to_list(?0..?9) ++
        [?/, ?_, ?-, ?", ?\\, ?\r, ?\n, ?\s]

    list_of(member_of(allowed), max_length: 60)
    |> map(fn chars -> " " <> List.to_string(chars) end)
  end

  defp version_gen do
    gen all segments <- list_of(integer(0..999), length: 2) do
      "ACORN/" <> Enum.map_join(segments, ".", &Integer.to_string/1)
    end
  end

  defp header_pair_gen do
    gen all key <- header_key_gen(),
            value <- header_value_gen() do
      {key, value}
    end
  end

  defp header_key_gen do
    first = Enum.to_list(?A..?Z) ++ Enum.to_list(?a..?z)
    tail = first ++ Enum.to_list(?0..?9) ++ [?-]

    gen all c1 <- member_of(first),
            rest <- list_of(member_of(tail), max_length: 20) do
      List.to_string([c1 | rest])
    end
  end

  defp header_value_gen do
    chars =
      Enum.to_list(?A..?Z) ++
        Enum.to_list(?a..?z) ++
        Enum.to_list(?0..?9) ++
        [?\s, ?\t, ?-, ?_, ?., ?/, ?+, ?=, ?;, ?,]

    list_of(member_of(chars), max_length: 80)
    |> map(&List.to_string/1)
  end

  defp body_gen do
    chars =
      Enum.to_list(?A..?Z) ++
        Enum.to_list(?a..?z) ++
        Enum.to_list(?0..?9) ++
        [?\s, ?\t, ?\n, ?\r, ?-, ?_, ?., ?/, ?+, ?=, ?:, ?;]

    list_of(member_of(chars), max_length: 120)
    |> map(&List.to_string/1)
  end
end

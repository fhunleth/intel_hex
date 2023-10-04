defmodule IntelHex.FlattenTest do
  use ExUnit.Case

  alias IntelHex.Record

  defp test_hex(base_address \\ 0) do
    blocks =
      IntelHex.Block.records_to_blocks([
        %Record{type: :extended_linear_address, address: base_address},
        %Record{type: :data, address: 0x10, data: <<1, 2, 3, 4, 5>>},
        %Record{type: :data, address: 0x20, data: <<6, 7, 8, 9, 10>>},
        %Record{type: :eof}
      ])

    %IntelHex{blocks: blocks}
  end

  test "flattens records" do
    result = IntelHex.flatten_to_list(test_hex())

    assert result == [
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             1,
             2,
             3,
             4,
             5,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             6,
             7,
             8,
             9,
             10
           ]
  end

  test "flattens records with non-default padding" do
    result = IntelHex.flatten_to_list(test_hex(), fill: 25)

    assert result == [
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             1,
             2,
             3,
             4,
             5,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             25,
             6,
             7,
             8,
             9,
             10
           ]
  end

  test "flattens records with base offset" do
    result = IntelHex.flatten_to_list(test_hex(0x10))

    assert result == [
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             1,
             2,
             3,
             4,
             5,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             255,
             6,
             7,
             8,
             9,
             10
           ]
  end
end

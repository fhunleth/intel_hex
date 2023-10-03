defmodule IntelHex.BlockTest do
  use ExUnit.Case
  doctest IntelHex.Block

  alias IntelHex.Block

  describe "records_to_blocks/1" do
    test "merges records" do
      test_records = [
        # Starting offset
        %IntelHex.Record{address: 100, data: <<>>, type: :extended_linear_address},
        %IntelHex.Record{address: 0, data: <<1, 2, 3, 4>>, type: :data},
        %IntelHex.Record{address: 4, data: <<5, 6, 7, 8>>, type: :data},
        # Hole
        %IntelHex.Record{address: 16, data: <<16, 17, 18, 19>>, type: :data},
        # No hole on address update
        %IntelHex.Record{address: 120, data: <<>>, type: :extended_linear_address},
        %IntelHex.Record{address: 0, data: <<20, 21, 22, 23>>, type: :data}
      ]

      assert Block.records_to_blocks(test_records) == [
               %Block{address: 100, data: <<1, 2, 3, 4, 5, 6, 7, 8>>},
               %Block{address: 116, data: <<16, 17, 18, 19, 20, 21, 22, 23>>}
             ]
    end
  end

  describe "blocks_to_records/2" do
    test "simple small block" do
      blocks = [Block.new(0x0, "ABCD")]

      assert Block.blocks_to_records(blocks) == [
               %IntelHex.Record{address: 0, data: <<>>, type: :extended_linear_address},
               %IntelHex.Record{address: 0, data: "ABCD", type: :data},
               %IntelHex.Record{address: 0, data: <<>>, type: :eof}
             ]
    end

    test "block spanning multiple records" do
      data = :rand.bytes(34)
      blocks = [Block.new(0x4, data)]

      assert Block.blocks_to_records(blocks) == [
               %IntelHex.Record{address: 0, data: <<>>, type: :extended_linear_address},
               %IntelHex.Record{
                 address: 4,
                 data: binary_part(data, 0, 16),
                 type: :data
               },
               %IntelHex.Record{address: 20, data: binary_part(data, 16, 16), type: :data},
               %IntelHex.Record{address: 36, data: binary_part(data, 32, 2), type: :data},
               %IntelHex.Record{address: 0, data: <<>>, type: :eof}
             ]
    end

    test "block spanning 64K boundary" do
      data = :rand.bytes(20)
      blocks = [Block.new(0x1FFF2, data)]

      assert Block.blocks_to_records(blocks) == [
               %IntelHex.Record{address: 0x10000, data: <<>>, type: :extended_linear_address},
               %IntelHex.Record{
                 address: 0xFFF2,
                 data: binary_part(data, 0, 14),
                 type: :data
               },
               %IntelHex.Record{address: 0x20000, data: <<>>, type: :extended_linear_address},
               %IntelHex.Record{address: 0, data: binary_part(data, 14, 6), type: :data},
               %IntelHex.Record{address: 0, data: <<>>, type: :eof}
             ]
    end

    test "large block spanning 64K boundaries" do
      data = :rand.bytes(70_000)
      blocks = [Block.new(0x8010000, data)]

      first_64k = binary_part(data, 0, 0x10000)
      second_64k = binary_part(data, 0x10000, byte_size(data) - 0x10000)

      assert Block.blocks_to_records(blocks) ==
               [
                 %IntelHex.Record{
                   address: 0x8010000,
                   data: <<>>,
                   type: :extended_linear_address
                 }
               ] ++
                 data_records(first_64k) ++
                 [
                   %IntelHex.Record{
                     address: 0x8020000,
                     data: <<>>,
                     type: :extended_linear_address
                   }
                 ] ++
                 data_records(second_64k) ++
                 [%IntelHex.Record{address: 0, data: <<>>, type: :eof}]
    end
  end

  defp data_records(data), do: data_records(0, data, [])
  defp data_records(_address, <<>>, acc), do: Enum.reverse(acc)

  defp data_records(address, <<data::16-bytes, rest::binary>>, acc) do
    data_records(address + 16, rest, [IntelHex.Record.data(address, data) | acc])
  end
end

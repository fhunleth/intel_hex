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
               Block.new(100, <<1, 2, 3, 4, 5, 6, 7, 8>>),
               Block.new(116, <<16, 17, 18, 19, 20, 21, 22, 23>>)
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

    defp data_records(data), do: data_records(0, data, [])
    defp data_records(_address, <<>>, acc), do: Enum.reverse(acc)

    defp data_records(address, <<data::16-bytes, rest::binary>>, acc) do
      data_records(address + 16, rest, [IntelHex.Record.data(address, data) | acc])
    end
  end

  describe "normalize/1" do
    test "normalize sorts" do
      input = [
        Block.new(4, <<2>>),
        Block.new(0, <<0>>),
        Block.new(6, <<3>>),
        Block.new(2, <<1>>)
      ]

      output = [
        Block.new(0, <<0>>),
        Block.new(2, <<1>>),
        Block.new(4, <<2>>),
        Block.new(6, <<3>>)
      ]

      assert Block.normalize(input) == output
    end

    test "merges adjacent blocks" do
      input = [
        Block.new(2, <<2>>),
        Block.new(0, <<0>>),
        Block.new(3, <<3>>),
        Block.new(1, <<1>>)
      ]

      output = [Block.new(0, <<0, 1, 2, 3>>)]

      assert Block.normalize(input) == output
    end

    test "removes overlaps" do
      input = [
        Block.new(10, <<0, 1, 2, 3>>),
        Block.new(9, <<9, 10>>),
        Block.new(11, <<11, 12>>)
      ]

      # original order is preserved
      output = [Block.new(9, <<9, 10, 11, 12, 3>>)]

      assert Block.normalize(input) == output
    end

    test "removes complete overlaps" do
      input = [
        Block.new(10, <<0, 1>>),
        Block.new(12, <<2, 3>>),
        Block.new(9, <<9, 10, 11, 12, 13, 14, 15>>)
      ]

      # original order is preserved
      output = [Block.new(9, <<9, 10, 11, 12, 13, 14, 15>>)]

      assert Block.normalize(input) == output
    end

    test "removes complete overlaps 2" do
      input = [
        Block.new(10, <<0, 1>>),
        Block.new(13, <<2, 3>>),
        Block.new(9, <<9, 10, 11, 12, 13, 14, 15>>)
      ]

      # original order is preserved
      output = [Block.new(9, <<9, 10, 11, 12, 13, 14, 15>>)]

      assert Block.normalize(input) == output
    end

    test "removes complete overlaps check" do
      input = [
        Block.new(9, <<9, 10, 11, 12, 13, 14>>),
        Block.new(10, <<0, 1>>),
        Block.new(13, <<2, 3>>)
      ]

      # original order is preserved
      output = [Block.new(9, <<9, 0, 1, 12, 2, 3>>)]

      assert Block.normalize(input) == output
    end
  end
end

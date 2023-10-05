defmodule IntelHex.OperationsTest do
  use ExUnit.Case
  doctest IntelHex.Operations

  alias IntelHex.Block
  alias IntelHex.Operations

  @input [
    Block.new(100, <<1, 2, 3, 4, 5, 6, 7, 8>>),
    Block.new(116, <<16, 17, 18, 19, 20, 21, 22, 23>>)
  ]

  describe "crop/1" do
    test "no cropping needed" do
      assert Operations.crop(@input, 0, 200) == @input
    end

    test "cropping everything" do
      assert Operations.crop(@input, 200, 100) == []
    end

    test "cropping left side" do
      assert Operations.crop(@input, 101, 100) == [
               Block.new(101, <<2, 3, 4, 5, 6, 7, 8>>),
               Block.new(116, <<16, 17, 18, 19, 20, 21, 22, 23>>)
             ]
    end

    test "cropping right side" do
      assert Operations.crop(@input, 100, 18) == [
               Block.new(100, <<1, 2, 3, 4, 5, 6, 7, 8>>),
               Block.new(116, <<16, 17>>)
             ]
    end

    test "cropping whole block side" do
      assert Operations.crop(@input, 100, 15) == [
               Block.new(100, <<1, 2, 3, 4, 5, 6, 7, 8>>)
             ]
    end
  end

  describe "fill_gaps/3" do
    test "single block cases" do
      blocks = [Block.new(100, <<1, 2, 3, 4>>)]

      assert Operations.fill_gaps(blocks, 0, 4, 9) == [Block.new(0, <<9, 9, 9, 9>>) | blocks]
      assert Operations.fill_gaps(blocks, 96, 4, 9) == [Block.new(96, <<9, 9, 9, 9, 1, 2, 3, 4>>)]
      assert Operations.fill_gaps(blocks, 98, 4, 9) == [Block.new(98, <<9, 9, 1, 2, 3, 4>>)]
      assert Operations.fill_gaps(blocks, 98, 8, 9) == [Block.new(98, <<9, 9, 1, 2, 3, 4, 9, 9>>)]
      assert Operations.fill_gaps(blocks, 100, 2, 9) == blocks
      assert Operations.fill_gaps(blocks, 100, 4, 9) == blocks
      assert Operations.fill_gaps(blocks, 100, 6, 9) == [Block.new(100, <<1, 2, 3, 4, 9, 9>>)]
      assert Operations.fill_gaps(blocks, 101, 2, 9) == blocks
      assert Operations.fill_gaps(blocks, 102, 2, 9) == blocks
      assert Operations.fill_gaps(blocks, 102, 4, 9) == [Block.new(100, <<1, 2, 3, 4, 9, 9>>)]

      assert Operations.fill_gaps(blocks, 104, 4, 9) == [
               Block.new(100, <<1, 2, 3, 4, 9, 9, 9, 9>>)
             ]

      assert Operations.fill_gaps(blocks, 200, 4, 9) == blocks ++ [Block.new(200, <<9, 9, 9, 9>>)]
    end

    test "multiple blocks" do
      assert Operations.fill_gaps(@input, 104, 12, 9) ==
               [
                 Block.new(
                   100,
                   <<1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 9, 9, 9, 9, 9, 9, 16, 17, 18, 19, 20, 21, 22,
                     23>>
                 )
               ]

      assert Operations.fill_gaps(@input, 98, 28, 9) ==
               [
                 Block.new(
                   98,
                   <<9, 9, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 9, 9, 9, 9, 9, 9, 16, 17, 18, 19, 20, 21,
                     22, 23, 9, 9>>
                 )
               ]
    end
  end
end

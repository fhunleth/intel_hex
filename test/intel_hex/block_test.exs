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
end

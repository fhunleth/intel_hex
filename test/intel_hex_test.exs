defmodule IntelHexTest do
  use ExUnit.Case
  doctest IntelHex

  test "can read a .hex file" do
    hex = IntelHex.load!("test/test.hex")

    assert hex.records ==
             [
               %IntelHex.Record{address: 0, data: <<0, 0>>, type: :extended_linear_address},
               %IntelHex.Record{
                 address: 0,
                 data: <<2, 24, 0, 2, 24, 3, 8, 253, 9, 2, 0, 2, 24, 11, 11, 50>>,
                 type: :data
               },
               %IntelHex.Record{
                 address: 16,
                 data: <<11, 60, 34, 2, 24, 19, 10, 236, 11, 0>>,
                 type: :data
               },
               %IntelHex.Record{
                 address: 27,
                 data: <<2, 24, 27, 70, 154, 2, 29, 225, 2, 24, 35, 228, 255, 225, 64>>,
                 type: :data
               },
               %IntelHex.Record{
                 address: 43,
                 data: <<2, 24, 43, 127, 7, 34, 211, 34, 2, 24, 51, 162, 74, 146, 52, 34>>,
                 type: :data
               },
               %IntelHex.Record{
                 address: 59,
                 data: <<2, 24, 59, 162, 75, 146, 55, 34, 2, 24, 67, 117, 200, 32, 34>>,
                 type: :data
               },
               %IntelHex.Record{address: 0, data: <<>>, type: :eof}
             ]
  end

  test "load! raises on errors" do
    assert_raise(File.Error, fn -> IntelHex.load!("test/does_not_exist.hex") end)

    assert_raise(IntelHex.DecodeError, fn ->
      IntelHex.load!("test/test-badchecksum.hex")
    end)
  end

  test "load returns errors" do
    assert {:error, %File.Error{}} = IntelHex.load("test/does_not_exist.hex")
    assert {:error, _} = IntelHex.load("test/test-badchecksum.hex")
  end
end

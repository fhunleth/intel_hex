defmodule IntelHexTest do
  use ExUnit.Case
  doctest IntelHex

  alias IntelHex.DecodeError

  test "raises on records without start codes" do
    assert_raise(DecodeError, fn -> IntelHex.decode_record!("abc") end)
  end

  test "decodes extended linear address record" do
    rec = IntelHex.decode_record!(":020000040000FA")
    assert rec.address == 0
    assert rec.data == [0, 0]
    assert rec.type == :extended_linear_address
  end

  test "decodes 16 byte data record" do
    rec = IntelHex.decode_record!(":10001000010900150E1960080100200040FFFFFFD4")
    assert rec.address == 0x0010

    assert rec.data == [
             0x01,
             0x09,
             0x00,
             0x15,
             0x0E,
             0x19,
             0x60,
             0x08,
             0x01,
             0x00,
             0x20,
             0x00,
             0x40,
             0xFF,
             0xFF,
             0xFF
           ]

    assert rec.type == :data
  end

  test "decodes 7 byte data record" do
    rec = IntelHex.decode_record!(":07000900FFFFFFFFFFFFFFF7")
    assert rec.address == 0x0009
    assert rec.data == [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    assert rec.type == :data
  end

  test "decodes eof" do
    rec = IntelHex.decode_record!(":00000001FF")
    assert rec.address == 0
    assert rec.data == []
    assert rec.type == :eof
  end

  test "fails on odd-length records" do
    assert_raise(IntelHex.DecodeError, fn -> IntelHex.decode_record!(":100010000ff") end)
  end

  test "ignores trailing whitespace" do
    IntelHex.decode_record!(":00000001FF   ")
    IntelHex.decode_record!(":00000001FF\n")
    IntelHex.decode_record!(":00000001FF\r\n")
    IntelHex.decode_record!(":00000001FF\r")
  end

  test "decode_record returns error tuple" do
    assert {:error, _} = IntelHex.decode_record("asdf")
  end

  test "can read a .hex file" do
    records = IntelHex.decode_file!("test/test.hex")

    assert records ==
             [
               %IntelHex.Record{address: 0, data: [0, 0], type: :extended_linear_address},
               %IntelHex.Record{
                 address: 0,
                 data: [2, 24, 0, 2, 24, 3, 8, 253, 9, 2, 0, 2, 24, 11, 11, 50],
                 type: :data
               },
               %IntelHex.Record{
                 address: 16,
                 data: [11, 60, 34, 2, 24, 19, 10, 236, 11, 0],
                 type: :data
               },
               %IntelHex.Record{
                 address: 27,
                 data: [2, 24, 27, 70, 154, 2, 29, 225, 2, 24, 35, 228, 255, 225, 64],
                 type: :data
               },
               %IntelHex.Record{
                 address: 43,
                 data: [2, 24, 43, 127, 7, 34, 211, 34, 2, 24, 51, 162, 74, 146, 52, 34],
                 type: :data
               },
               %IntelHex.Record{
                 address: 59,
                 data: [2, 24, 59, 162, 75, 146, 55, 34, 2, 24, 67, 117, 200, 32, 34],
                 type: :data
               },
               %IntelHex.Record{address: 0, data: [], type: :eof}
             ]
  end

  test "decode_file! raises on errors" do
    assert_raise(File.Error, fn -> IntelHex.decode_file!("test/does_not_exist.hex") end)

    assert_raise(IntelHex.DecodeError, fn ->
      IntelHex.decode_file!("test/test-badchecksum.hex")
    end)
  end

  test "decode_file returns errors" do
    assert {:error, :enoent} == IntelHex.decode_file("test/does_not_exist.hex")
    assert {:error, _} = IntelHex.decode_file("test/test-badchecksum.hex")
  end
end

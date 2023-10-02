defmodule IntelHex.RecordTest do
  use ExUnit.Case
  doctest IntelHex.Record

  alias IntelHex.DecodeError
  alias IntelHex.Record

  describe "decode!/1" do
    test "raises on records without start codes" do
      assert_raise(DecodeError, fn -> Record.decode!("abc") end)
    end

    test "decodes extended linear address record" do
      rec = Record.decode!(":020000040000FA")
      assert rec.address == 0
      assert rec.data == <<0, 0>>
      assert rec.type == :extended_linear_address
    end

    test "decodes 16 byte data record" do
      rec = Record.decode!(":10001000010900150E1960080100200040FFFFFFD4")
      assert rec.address == 0x0010

      assert rec.data == <<
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
             >>

      assert rec.type == :data
    end

    test "decodes 7 byte data record" do
      rec = Record.decode!(":07000900FFFFFFFFFFFFFFF7")
      assert rec.address == 0x0009
      assert rec.data == <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>
      assert rec.type == :data
    end

    test "decodes eof" do
      rec = Record.decode!(":00000001FF")
      assert rec.address == 0
      assert rec.data == <<>>
      assert rec.type == :eof
    end

    test "fails on odd-length records" do
      assert_raise(IntelHex.DecodeError, fn -> Record.decode!(":100010000ff") end)
    end

    test "ignores trailing whitespace" do
      Record.decode!(":00000001FF   ")
      Record.decode!(":00000001FF\n")
      Record.decode!(":00000001FF\r\n")
      Record.decode!(":00000001FF\r")
    end
  end

  describe "decode/1" do
    test "decode returns error tuple" do
      assert {:error, _} = Record.decode("asdf")
    end
  end

  describe "encode/1" do
    test "encodes and decodes the same" do
      assert decode_encode_same?(":00000001FF\n")
      assert decode_encode_same?(":020000040000FA\n")
      assert decode_encode_same?(":020000040800F2\n")
      assert decode_encode_same?(":10000000081000200D220008113C0008AB28000851\n")
    end
  end

  defp decode_encode_same?(input) do
    result = input |> Record.decode!() |> Record.encode()
    result == input
  end
end

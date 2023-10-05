defmodule IntelHexTest do
  use ExUnit.Case
  doctest IntelHex

  alias IntelHex.Block

  test "can read a .hex file" do
    hex = IntelHex.load!("test/test.hex")

    assert hex.blocks ==
             [
               Block.new(
                 0,
                 <<2, 24, 0, 2, 24, 3, 8, 253, 9, 2, 0, 2, 24, 11, 11, 50, 11, 60, 34, 2, 24, 19,
                   10, 236, 11, 0>>
               ),
               Block.new(
                 27,
                 <<2, 24, 27, 70, 154, 2, 29, 225, 2, 24, 35, 228, 255, 225, 64>>
               ),
               Block.new(
                 43,
                 <<2, 24, 43, 127, 7, 34, 211, 34, 2, 24, 51, 162, 74, 146, 52, 34, 2, 24, 59,
                   162, 75, 146, 55, 34, 2, 24, 67, 117, 200, 32, 34>>
               )
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

  test "cropping a file" do
    # This only tests the basic API. Cropping is more thoroughly tested in operations_test.exs.
    hex = IntelHex.load!("test/test.hex") |> IntelHex.crop(2, 4)

    assert hex.blocks == [Block.new(2, <<0, 2, 24, 3>>)]
  end

  test "getting data" do
    hex = IntelHex.load!("test/test.hex")

    assert IntelHex.get(hex, 0, 4) == <<2, 24, 0, 2>>
    assert IntelHex.get(hex, 26, 4) == <<0, 2, 24, 27>>
    assert IntelHex.get(hex, 26, 4, fill: 9) == <<9, 2, 24, 27>>
  end

  test "setting data" do
    hex =
      IntelHex.load!("test/test.hex")
      |> IntelHex.set(1, <<100, 101, 102, 103, 104>>)
      |> IntelHex.set(32, <<200, 201>>)

    assert IntelHex.get(hex, 0, 7) == <<2, 100, 101, 102, 103, 104, 8>>
    assert IntelHex.get(hex, 32, 4) == <<200, 201, 225, 2>>
  end

  @tag :tmp_dir
  test "resave the test file", %{tmp_dir: tmp_dir} do
    load_path = "test/test.hex"
    save_path = Path.join(tmp_dir, "save.hex")

    hex = IntelHex.load!(load_path)
    IntelHex.save(hex, save_path)

    input = File.read!(load_path)
    output = File.read!(save_path)

    assert input == output
  end

  @tag :tmp_dir
  test "save a simple file", %{tmp_dir: tmp_dir} do
    save_path = Path.join(tmp_dir, "save.hex")

    hex =
      IntelHex.new()
      |> IntelHex.set(
        16,
        <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
          25, 26, 27, 28, 29, 30, 31, 32>>
      )
      |> IntelHex.set(256, <<100, 101, 102, 103>>)
      |> IntelHex.set(0x11000, <<200, 201, 202, 203>>)

    IntelHex.save(hex, save_path, block_size: 32)

    output = File.read!(save_path) |> String.replace("\r\n", "\n")

    assert output == """
           :020000040000FA
           :200010000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20C0
           :040100006465666765
           :020000040001F9
           :04100000C8C9CACBC6
           :00000001FF
           """
  end
end

defmodule IntelHex.Decoder do
  alias IntelHex.{DecodeError, Record}
  use Bitwise

  @doc """
  Decode one hex record.

  If the record is not in Intel Hex format, an exception will be raised.
  """
  @spec decode_record!(String.t()) :: IntelHex.Record.t() | no_return
  def decode_record!(string) do
    string
    |> String.trim()
    |> strip_start_code()
    |> to_integers()
    |> length_ok?()
    |> checksum_ok?()
    |> to_record()
  end

  defp strip_start_code(<<?:, rest::binary>>), do: rest
  defp strip_start_code(_), do: raise(DecodeError, message: "Missing record start code ':'")

  defp to_integers(<<>>), do: []

  defp to_integers(<<hex::binary-size(2), rest::binary>>) do
    [String.to_integer(hex, 16) | to_integers(rest)]
  rescue
    ArgumentError ->
      raise DecodeError, message: "Expecting a hex integer, but got #{inspect(hex)}."
  end

  defp to_integers(_other) do
    raise DecodeError, message: "Expecting an even number of hex characters"
  end

  defp length_ok?([data_bytes | _rest] = numbers) do
    byte_count = data_bytes + 5

    if length(numbers) != byte_count do
      raise DecodeError, message: "Checksum failure"
    else
      numbers
    end
  end

  defp checksum_ok?(numbers) do
    csum = Enum.reduce(numbers, 0, &+/2) &&& 0xFF

    if csum != 0 do
      raise DecodeError, message: "Checksum failure"
    else
      numbers
    end
  end

  defp to_record([_data_bytes, address_msb, address_lsb, type | data_and_checksum]) do
    record_type = record_type(type)

    %Record{
      address: to_address(record_type, address_msb, address_lsb, data_and_checksum),
      type: record_type,
      data: Enum.drop(data_and_checksum, -1)
    }
  end

  defp record_type(0), do: :data
  defp record_type(1), do: :eof
  defp record_type(2), do: :extended_segment_address
  defp record_type(3), do: :start_segment_address
  defp record_type(4), do: :extended_linear_address
  defp record_type(5), do: :start_linear_address
  defp record_type(x), do: raise(DecodeError, message: "Unknown record type #{x}")

  defp to_address(:extended_linear_address, _address_msb, _address_lsb, [a, b | _rest]) do
    (a <<< 24) + (b <<< 16)
  end

  defp to_address(:start_linear_address, _address_msb, _address_lsb, [a, b, c, d | _rest]) do
    (a <<< 24) + (b <<< 16) + (c <<< 8) + d
  end

  defp to_address(:extended_segment_address, _address_msb, _address_lsb, [a, b | _rest]) do
    (a <<< 12) + (b <<< 4)
  end

  defp to_address(:start_segment_address, _address_msb, _address_lsb, [a, b, c, d | _rest]) do
    # ab is segment register, cd is index
    (a <<< 12) + (b <<< 4) + (c <<< 8) + d
  end

  defp to_address(_, address_msb, address_lsb, _) do
    (address_msb <<< 8) + address_lsb
  end
end

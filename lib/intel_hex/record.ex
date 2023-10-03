defmodule IntelHex.Record do
  @moduledoc """
  Information for one line in an Intel HEX file
  """
  alias IntelHex.DecodeError
  import Bitwise

  defstruct address: 0, data: [], type: :data

  @type type() ::
          :data
          | :eof
          | :extended_segment_address
          | :start_segment_address
          | :extended_linear_address
          | :start_linear_address
  @type t() :: %__MODULE__{address: non_neg_integer(), data: binary(), type: type()}

  @doc """
  Decode one Intel Hex record
  """
  @spec decode(String.t()) :: {:ok, t()} | {:error, term()}
  def decode(string) do
    {:ok, decode!(string)}
  rescue
    exception in DecodeError -> {:error, exception}
  end

  @doc """
  Decode one Intel Hex record

  If the record is not in Intel Hex format, an exception will be raised.
  """
  @spec decode!(String.t()) :: t()
  def decode!(string) do
    string
    |> String.trim()
    |> strip_start_code()
    |> to_integers()
    |> length_ok?()
    |> checksum_ok?()
    |> to_record()
  end

  @doc """
  Encode an Intel Hex record
  """
  @spec encode(t()) :: String.t()
  def encode(%__MODULE__{type: :data} = record) do
    info_to_record(record.address, 0, record.data)
  end

  def encode(%__MODULE__{type: :eof}) do
    ":00000001FF\n"
  end

  def encode(%__MODULE__{type: :extended_segment_address} = record) do
    segment = record.address >>> 4
    info_to_record(record.address, 2, <<segment::16>>)
  end

  def encode(%__MODULE__{type: :start_segment_address} = record) do
    a = record.address >>> 4
    b = record.address - a
    info_to_record(record.address, 3, <<a::16, b::16>>)
  end

  def encode(%__MODULE__{type: :extended_linear_address} = record) do
    address = record.address >>> 16
    info_to_record(record.address, 4, <<address::16>>)
  end

  def encode(%__MODULE__{type: :start_linear_address} = record) do
    info_to_record(record.address, 5, <<record.address::32>>)
  end

  defp info_to_record(address, type, data) do
    payload = <<byte_size(data), address::16, type, data::binary>>
    ":#{Base.encode16(payload)}#{Base.encode16(<<checksum(payload)>>)}\n"
  end

  defp strip_start_code(<<?:, rest::binary>>), do: rest
  defp strip_start_code(_), do: raise(DecodeError, message: "Missing record start code ':'")

  defp to_integers(data) do
    case Base.decode16(data, case: :upper) do
      {:ok, data} -> data
      :error -> raise DecodeError, message: "Expecting hex integers at #{inspect(data)}"
    end
  end

  defp length_ok?(<<data_bytes, _::binary>> = data) do
    byte_count = data_bytes + 5

    if byte_size(data) != byte_count do
      raise DecodeError,
        message: "Expecting #{byte_count} bytes in record, but got #{byte_size(data)}"
    else
      data
    end
  end

  defp checksum(data, acc \\ 0)
  defp checksum(<<>>, acc), do: -acc &&& 0xFF
  defp checksum(<<x, rest::binary>>, acc), do: checksum(rest, acc + x)

  defp checksum_ok?(data) do
    if checksum(data, 0) != 0 do
      raise DecodeError, message: "Checksum failure"
    else
      data
    end
  end

  defp to_record(<<_data_bytes, offset::16, type, data_and_checksum::binary>>) do
    record_type = record_type(type)

    %__MODULE__{
      address: to_address(record_type, offset, data_and_checksum),
      type: record_type,
      data: binary_part(data_and_checksum, 0, byte_size(data_and_checksum) - 1)
    }
  end

  defp record_type(0), do: :data
  defp record_type(1), do: :eof
  defp record_type(2), do: :extended_segment_address
  defp record_type(3), do: :start_segment_address
  defp record_type(4), do: :extended_linear_address
  defp record_type(5), do: :start_linear_address
  defp record_type(x), do: raise(DecodeError, message: "Unknown record type #{x}")

  defp to_address(:extended_linear_address, _offset, <<a::16, _::binary>>), do: a <<< 16
  defp to_address(:start_linear_address, _offset, <<a::32, _::binary>>), do: a
  defp to_address(:extended_segment_address, _offset, <<a::16, _::binary>>), do: a <<< 4
  defp to_address(:start_segment_address, _offset, <<a::16, b::16, _::binary>>), do: (a <<< 4) + b
  defp to_address(_, offset, _), do: offset
end

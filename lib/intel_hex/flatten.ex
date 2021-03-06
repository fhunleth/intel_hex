defmodule IntelHex.Flatten do
  @moduledoc false

  def to_list(records, options \\ []) do
    fill = Keyword.get(options, :fill, 255)
    start = Keyword.get(options, :start, 0)

    to_list(start, 0, records, [], fill)
  end

  defp to_list(_base, _offset, [], _rarray, _fill) do
    raise ArgumentError, message: "Missing EOF record"
  end

  defp to_list(
         base,
         offset,
         [%{type: :extended_linear_address, address: address} | rest],
         rarray,
         fill
       )
       when address >= base + offset do
    padding_amount = address - base - offset
    padding = List.duplicate(fill, padding_amount)
    to_list(address, 0, rest, padding ++ rarray, fill)
  end

  defp to_list(
         base,
         offset,
         [%{type: :extended_linear_address, address: address} | _rest],
         _rarray,
         _fill
       ) do
    raise ArgumentError,
      message:
        "Records not in sequential order: got #{inspect(address, base: :hex)} but expecting #{
          inspect(base + offset, base: :hex)
        } or later"
  end

  defp to_list(base, offset, [%{type: :data, address: address, data: data} | rest], rarray, fill)
       when address >= offset do
    padding_amount = address - offset
    padding = List.duplicate(fill, padding_amount)

    to_list(
      base,
      offset + padding_amount + length(data),
      rest,
      Enum.reverse(data) ++ padding ++ rarray,
      fill
    )
  end

  defp to_list(base, offset, [%{type: :data, address: address} | _rest], _rarray, _fill) do
    raise ArgumentError,
      message:
        "Records not in sequential order: got #{inspect(address, base: :hex)} but expecting #{
          inspect(base + offset, base: :hex)
        } or later"
  end

  defp to_list(_base, _offset, [%{type: :eof} | _rest], rarray, _fill) do
    Enum.reverse(rarray)
  end

  defp to_list(base, offset, [head | rest], rarray, fill) do
    IO.inspect(head)
    to_list(base, offset, rest, rarray, fill)
  end
end

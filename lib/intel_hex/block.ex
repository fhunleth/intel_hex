defmodule IntelHex.Block do
  @moduledoc false

  defstruct [:address, :data]
  @type t() :: %__MODULE__{address: non_neg_integer(), data: binary()}

  def records_to_blocks(records) do
    to_blocks(records, 0, [])
  end

  defp to_blocks([], _base_address, acc) do
    acc
    |> Enum.reverse()
    |> Enum.sort(&(&1.address <= &2.address))
    |> remove_overlaps()
    |> merge()
  end

  defp to_blocks([record | rest], base_address, acc) do
    case record.type do
      :data ->
        block = %__MODULE__{address: base_address + record.address, data: record.data}
        to_blocks(rest, base_address, [block | acc])

      :eof ->
        to_blocks([], base_address, acc)

      _ ->
        to_blocks(rest, record.address, acc)
    end
  end

  defp remove_overlaps(blocks) do
    blocks |> remove_overlaps_r([]) |> Enum.reverse()
  end

  defp remove_overlaps_r([], acc), do: acc
  defp remove_overlaps_r([b1], acc), do: [b1 | acc]

  defp remove_overlaps_r([b1, b2 | rest], acc) do
    addr = b1.address + byte_size(b1.data)

    cond do
      b1.address == b2.address ->
        remove_overlaps_r(rest, [b2 | acc])

      addr <= b2.address ->
        remove_overlaps_r([b2 | rest], [b1 | acc])

      addr > b2.address ->
        trimmed_b1 = %__MODULE__{
          address: b1.address,
          data: binary_part(b1.data, 0, b2.address - b1.address)
        }

        remove_overlaps_r([b2 | rest], [trimmed_b1 | acc])
    end
  end

  defp merge([b1 | rest]) do
    merge_r(rest, b1.address, b1.address + byte_size(b1.data), [b1.data], [])
    |> Enum.reverse()
  end

  defp merge_r([], start, _current, buffers, done) do
    [finalize_merge(start, buffers) | done]
  end

  defp merge_r([b1 | rest], start, current, buffers, done) do
    if b1.address == current do
      merge_r(rest, start, current + byte_size(b1.data), [b1.data | buffers], done)
    else
      merge_r(rest, b1.address, b1.address + byte_size(b1.data), [b1.data], [
        finalize_merge(start, buffers) | done
      ])
    end
  end

  defp finalize_merge(start, buffers) do
    result = buffers |> Enum.reverse() |> Enum.join()
    %__MODULE__{address: start, data: result}
  end
end

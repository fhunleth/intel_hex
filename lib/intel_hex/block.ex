defmodule IntelHex.Block do
  @moduledoc false
  import Bitwise

  alias IntelHex.Record

  defstruct [:address, :data]
  @type t() :: %__MODULE__{address: non_neg_integer(), data: binary()}

  @doc """
  Create a new block
  """
  @spec new(non_neg_integer(), binary()) :: t()
  def new(address, data) when is_integer(address) and is_binary(data) do
    %__MODULE__{address: address, data: data}
  end

  @doc """
  Convert a list of records to memory blocks

  The returned list of blocks is sorted, merged, and any overlaps resolved.
  """
  @spec records_to_blocks([Record.t()]) :: [t()]
  def records_to_blocks(records) do
    to_blocks(records, 0, [])
  end

  @doc """
  Turn a list of memory blocks back to records

  Only linear addressing is supported.

  Options:
  * `:block_size` - the max data bytes per record. (defaults to 16)
  """
  @spec blocks_to_records([t()], keyword()) :: [Record.t()]
  def blocks_to_records(blocks, opts \\ []) do
    _block_size = Keyword.get(opts, :block_size, 16)

    to_records(blocks, -1, [])
  end

  defp to_records([], _base_address, acc) do
    [Record.eof() | acc]
    |> Enum.reverse()
  end

  defp to_records([block | rest], base_address, acc) do
    data_base_address = block.address &&& 0xFFFF0000
    blocks64 = split_64k(block)

    {new_base_address, new_acc} =
      data_64k_to_records_r(base_address, data_base_address, blocks64, acc)

    to_records(rest, new_base_address, new_acc)
  end

  defp data_64k_to_records_r(current_base_address, _base_address, [], acc) do
    {current_base_address, acc}
  end

  defp data_64k_to_records_r(current_base_address, base_address, blocks64, acc)
       when current_base_address != base_address do
    # Move the base address
    data_64k_to_records_r(base_address, base_address, blocks64, [
      Record.extended_linear_address(base_address) | acc
    ])
  end

  defp data_64k_to_records_r(base_address, base_address, [block64 | rest], acc) do
    new_acc =
      chunk_data_to_records_r(base_address, block64.address, block64.data, acc)

    data_64k_to_records_r(base_address, base_address + 0x10000, rest, new_acc)
  end

  defp chunk_data_to_records_r(_base_address, _address, <<>>, acc), do: acc

  defp chunk_data_to_records_r(base_address, address, data, acc) do
    chunk = binary_slice(data, 0, 16)
    chunk_size = byte_size(chunk)
    record = Record.data(address - base_address, chunk)
    new_acc = [record | acc]

    if chunk_size == 16 do
      chunk_data_to_records_r(
        base_address,
        address + 16,
        binary_part(data, 16, byte_size(data) - 16),
        new_acc
      )
    else
      new_acc
    end
  end

  defp split_64k(block) do
    # Split a block into chunks that will be on 64K boundaries
    base_address = block.address &&& 0xFFFF0000
    first_chunk_size = min(base_address + 0x10000 - block.address, byte_size(block.data))
    first_chunk = binary_part(block.data, 0, first_chunk_size)
    first_block = %__MODULE__{address: block.address, data: first_chunk}

    aligned_data =
      binary_part(block.data, first_chunk_size, byte_size(block.data) - first_chunk_size)

    aligned_blocks = split_64k_aligned(base_address + 0x10000, aligned_data, [])

    [first_block | aligned_blocks]
  end

  defp split_64k_aligned(address, data, acc) do
    data_size = byte_size(data)

    cond do
      data_size > 0x10000 ->
        chunk = binary_part(data, 0, 0x10000)
        rest = binary_part(data, 0x10000, data_size)
        block = %__MODULE__{address: address, data: chunk}
        split_64k_aligned(address + 0x10000, rest, [block | acc])

      data_size > 0 ->
        block = %__MODULE__{address: address, data: data}
        [block | acc] |> Enum.reverse()

      true ->
        acc
    end
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

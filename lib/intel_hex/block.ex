defmodule IntelHex.Block do
  @moduledoc """
  A block is a contiguous set of bytes at an address

  If you're working with `IntelHex` only, then you don't need to worry about
  this module. However, handling blocks directly can enable more complex
  manipulations of the data stored in `.hex` files.

  Generally programs pass around lists of `Block`s. Functions in this library
  expect these lists to conform to the following rules:

  1. Sorted by address from lowest address to highest
  2. No overlaps between blocks
  3. A gap of one or more bytes separates each block

  Calling `normalize/1` will ensure that `Block` lists follow these rules.
  """
  import Bitwise

  alias IntelHex.Record

  defstruct [:address, :data]
  @type t() :: %__MODULE__{address: non_neg_integer(), data: binary()}

  @doc """
  Create a new block
  """
  @spec new(non_neg_integer(), binary()) :: t()
  def new(address, data)
      when is_integer(address) and address >= 0 and address <= 0xFFFFFFFF and is_binary(data) do
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
    block_size = Keyword.get(opts, :block_size, 16) |> max(1) |> min(255)

    to_records(blocks, -1, block_size, [])
  end

  @doc """
  Normalize a list of blocks

  This makes sure that they're sorted, non-overlapping and blocks that are next
  to each other get merged. This is normally done automatically, but if you're
  manually creating block lists and unsure whether there are overlaps or
  adjacent blocks, then it's recommended to run this.
  """
  @spec normalize([t()]) :: [t()]
  def normalize(blocks) do
    blocks
    |> Enum.sort(&overlap_sort/2)
    |> remove_overlaps()
    |> merge()
  end

  defp overlap_sort(b1, b2) do
    # Return true if b1 comes before b2 or they overlap

    # The following is easier to read than the test below
    # that it's equivalent to.

    # b1_start = b1.address
    # b1_end = b1_start + byte_size(b1.data)
    # b2_start = b2.address
    # b2_end = b2_start + byte_size(b2.data)
    # cond do
    #   # b2 completely before b1
    #   b2_end <= b1_start -> false
    #   # b1 completely before b2
    #   b1_end >= b2_start -> true
    #   # overlap
    #   true -> true
    # end

    b2.address + byte_size(b2.data) > b1.address
  end

  defp to_records([], _base_address, _block_size, acc) do
    [Record.eof() | acc]
    |> Enum.reverse()
  end

  defp to_records([block | rest], base_address, block_size, acc) do
    data_base_address = block.address &&& 0xFFFF0000
    blocks64 = split_64k(block)

    {new_base_address, new_acc} =
      data_64k_to_records_r(base_address, data_base_address, blocks64, block_size, acc)

    to_records(rest, new_base_address, block_size, new_acc)
  end

  defp data_64k_to_records_r(current_base_address, _base_address, [], _block_size, acc) do
    {current_base_address, acc}
  end

  defp data_64k_to_records_r(current_base_address, base_address, blocks64, block_size, acc)
       when current_base_address != base_address do
    # Move the base address
    data_64k_to_records_r(base_address, base_address, blocks64, block_size, [
      Record.extended_linear_address(base_address) | acc
    ])
  end

  defp data_64k_to_records_r(base_address, base_address, [block64 | rest], block_size, acc) do
    new_acc =
      chunk_data_to_records_r(base_address, block64.address, block64.data, block_size, acc)

    data_64k_to_records_r(base_address, base_address + 0x10000, rest, block_size, new_acc)
  end

  defp chunk_data_to_records_r(_base_address, _address, <<>>, _block_size, acc), do: acc

  defp chunk_data_to_records_r(base_address, address, data, block_size, acc) do
    chunk = binary_slice(data, 0, block_size)
    chunk_size = byte_size(chunk)
    record = Record.data(address - base_address, chunk)
    new_acc = [record | acc]

    if chunk_size == block_size do
      chunk_data_to_records_r(
        base_address,
        address + block_size,
        binary_part(data, block_size, byte_size(data) - block_size),
        block_size,
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
        rest = binary_part(data, 0x10000, data_size - 0x10000)
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
    |> normalize()
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
    original_len = length(blocks)
    new_blocks = blocks |> remove_overlaps_r([]) |> Enum.reverse()
    new_len = length(new_blocks)

    # The algorithm for removing overlaps only compares two blocks at a time,
    # so it isn't able to guarantee that triple overlaps are handled.
    # Therefore, whenever a overlap is removed, make another pass.
    if new_len < original_len, do: remove_overlaps(new_blocks), else: new_blocks
  end

  defp remove_overlaps_r([], acc), do: acc
  defp remove_overlaps_r([b1], acc), do: [b1 | acc]

  defp remove_overlaps_r([b1, b2 | rest], acc) do
    b1_start = b1.address
    b2_start = b2.address
    b1_end = b1_start + byte_size(b1.data)
    b2_end = b2.address + byte_size(b2.data)

    cond do
      b2_start >= b1_end ->
        # No overlap: b2 is after b1
        remove_overlaps_r([b2 | rest], [b1 | acc])

      b2_start <= b1_start and b2_end >= b1_end ->
        # b2 completely overlaps b1, so drop b1 and try again.
        remove_overlaps_r([b2 | rest], acc)

      b2_start >= b1_start ->
        # b2 overlaps b1 so absorb it and try again.
        left_b1_len = b2_start - b1_start
        b1_len = b1_end - b1_start
        b2_len = b2_end - b2_start

        left_b1_data = binary_part(b1.data, 0, left_b1_len)

        right_b1_data =
          if b1_len > left_b1_len + b2_len,
            do: binary_part(b1.data, left_b1_len + b2_len, b1_len - b2_len - left_b1_len),
            else: <<>>

        new_b1 = new(b1_start, left_b1_data <> b2.data <> right_b1_data)

        remove_overlaps_r([new_b1 | rest], acc)

      true ->
        # b2_start < b1_start -> b2 comes before b1, but doesn't completely overlap b1
        new_b1 =
          new(
            b2_start,
            b2.data <> binary_part(b1.data, b2_end - b1_start, b1_end - b2_end)
          )

        remove_overlaps_r([new_b1 | rest], acc)
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

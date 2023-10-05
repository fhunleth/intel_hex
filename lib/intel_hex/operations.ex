defmodule IntelHex.Operations do
  @moduledoc false

  alias IntelHex.Block

  @doc """
  Filter the block list so it only contains the specified range
  """
  @spec crop([Block.t()], non_neg_integer, non_neg_integer) :: [Block.t()]
  def crop(blocks, address, length) do
    blocks
    |> Enum.map(&crop_block(&1, address, length))
    |> Enum.reject(&is_nil/1)
  end

  defp crop_block(block, address, length) do
    block_start = block.address
    block_end = block_start + byte_size(block.data)

    include_end = address + length

    cond do
      block_end <= address or block_start >= include_end ->
        nil

      block_start >= address and block_end <= include_end ->
        block

      true ->
        new_start = max(block_start, address)
        new_end = min(block_end, include_end)
        new_length = new_end - new_start

        %Block{
          address: new_start,
          data: binary_part(block.data, new_start - block_start, new_length)
        }
    end
  end

  @doc """
  Fill locations that don't have data with the specified value
  """
  @spec fill_gaps([Block.t()], non_neg_integer, non_neg_integer, 0..255) :: [Block.t()]
  def fill_gaps(blocks, address, length, value) do
    blocks
    |> do_fill_gap(address, address + length, value, [])
    |> Block.normalize()
  end

  defp do_fill_gap(blocks, fill_start, fill_end, _value, acc) when fill_start >= fill_end do
    # All filling is done
    Enum.reverse(acc) ++ blocks
  end

  defp do_fill_gap([], fill_start, fill_end, value, acc) do
    # All blocks scanned and still more filling to do
    filler_block = %Block{
      address: fill_start,
      data: :binary.copy(<<value>>, fill_end - fill_start)
    }

    Enum.reverse([filler_block | acc])
  end

  defp do_fill_gap([block | rest], fill_start, fill_end, value, acc) do
    block_start = block.address
    block_end = block_start + byte_size(block.data)

    cond do
      fill_start >= block_end ->
        # Filling starts after this block, so go to the next block
        do_fill_gap(rest, fill_start, fill_end, value, [block | acc])

      fill_end <= block_start ->
        # This block starts after the last address to fill. Add a filler block
        # and we're done.
        filler_block = %Block{
          address: fill_start,
          data: :binary.copy(<<value>>, fill_end - fill_start)
        }

        do_fill_gap(rest, fill_end, fill_end, value, [block, filler_block | acc])

      fill_start < block_start ->
        # Need to fill in before this block
        filler_block = %Block{
          address: fill_start,
          data: :binary.copy(<<value>>, block_start - fill_start)
        }

        # Move the fill start to account for the filling we're doing and this block
        new_fill_start = min(fill_end, block_end)
        do_fill_gap(rest, new_fill_start, fill_end, value, [block, filler_block | acc])

      fill_start <= block_end ->
        # No filling needed in this block so advance the first address to fill
        new_fill_start = min(fill_end, block_end)
        do_fill_gap(rest, new_fill_start, fill_end, value, [block | acc])
    end
  end
end

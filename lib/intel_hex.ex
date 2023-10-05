defmodule IntelHex do
  @moduledoc """
  Decode Intel HEX files
  """
  alias IntelHex.DecodeError

  alias IntelHex.Block
  alias IntelHex.Operations
  alias IntelHex.Record

  defstruct path: nil, blocks: []
  @type t() :: %__MODULE__{path: String.t(), blocks: [Block.t()]}

  @doc """
  Create an empty hex file

  Use `IntelHex.set/3` or other functions to populate it.
  """
  @spec new() :: %__MODULE__{path: String.t(), blocks: []}
  def new() do
    %__MODULE__{path: "", blocks: []}
  end

  @doc """
  Load an Intel Hex-formatted file into memory

  Raises File.Error or IntelHex.DecodeError if an error occurs.
  """
  @spec load!(Path.t()) :: t()
  def load!(path) do
    blocks =
      File.stream!(path)
      |> Stream.map(&Record.decode!/1)
      |> Enum.to_list()
      |> Block.records_to_blocks()

    %__MODULE__{path: path, blocks: blocks}
  end

  @doc """
  Load an Intel Hex-formatted file into memory
  """
  @spec load(Path.t()) :: {:ok, t()} | {:error, term()}
  def load(path) do
    {:ok, load!(path)}
  rescue
    exception in [File.Error, DecodeError] ->
      {:error, exception}
  end

  @doc """
  Save data to an Intel Hex-formatted file

  Options:
  * `:block_size` - the max data bytes per record. (defaults to 16)
  """
  @spec save(t(), Path.t(), keyword()) :: :ok
  def save(hex, path, options \\ []) do
    hex.blocks
    |> Block.blocks_to_records(options)
    |> Stream.map(&Record.encode/1)
    |> Stream.into(File.stream!(path))
    |> Stream.run()
  end

  @doc """
  Only keep data within the specified address range
  """
  @spec crop(t(), non_neg_integer(), non_neg_integer()) :: t()
  def crop(hex, address, length) do
    new_blocks = Operations.crop(hex.blocks, address, length)
    %{hex | blocks: new_blocks}
  end

  @doc """
  Get the data at a specified address

  Options:
  * `:fill` - value to use when none exists (defaults to `0`)
  """
  @spec get(t(), non_neg_integer(), non_neg_integer(), fill: 0..255) :: binary()
  def get(hex, address, num_bytes, options \\ []) do
    fill_value = Keyword.get(options, :fill, 0)

    hex.blocks
    |> Operations.crop(address, num_bytes)
    |> Operations.fill_gaps(address, num_bytes, fill_value)
    |> hd()
    |> Map.get(:data)
  end

  @doc """
  Set a set of bytes at the specified address
  """
  @spec set(t(), non_neg_integer(), binary()) :: t()
  def set(hex, address, data) do
    # The algorithm here abuses the de-overlap code during normalization
    # I.e., add the new data as a block to the end and normalize.
    %{hex | blocks: Block.normalize(hex.blocks ++ [Block.new(address, data)])}
  end

  defimpl Inspect do
    import Inspect.Algebra

    @impl Inspect
    def inspect(hex, _opts) do
      concat(["%IntelHex{num_blocks: #{length(hex.blocks)}}"])
    end
  end
end

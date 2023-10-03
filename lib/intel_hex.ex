defmodule IntelHex do
  @moduledoc """
  Decode Intel HEX files
  """
  alias IntelHex.DecodeError

  alias IntelHex.Flatten
  alias IntelHex.Record

  defstruct path: nil, records: []
  @type t() :: %__MODULE__{path: String.t(), records: [Record.t()]}

  @doc """
  Load an Intel Hex-formatted file into memory

  Raises File.Error or IntelHex.DecodeError if an error occurs.
  """
  @spec load!(Path.t()) :: t()
  def load!(path) do
    records =
      File.stream!(path)
      |> Stream.map(&Record.decode!/1)
      |> Enum.to_list()

    %__MODULE__{path: path, records: records}
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
  Flatten a list of records to a list of memory values.

  This runs though the records. The records must be an ascending order.
  Gaps are allowed and are filled in by the `:fill` value. Addressing starts
  at zero, but if you'd like to start it later, use the `:start` option.
  """
  @spec flatten_to_list(t(), keyword()) :: [0..255]
  def flatten_to_list(hex, options \\ []) when is_struct(hex) do
    Flatten.to_list(hex, options)
  end

  defimpl Inspect do
    import Inspect.Algebra

    @impl Inspect
    def inspect(hex, _opts) do
      concat(["%IntelHex{num_records: #{length(hex.records)}}"])
    end
  end
end

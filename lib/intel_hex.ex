defmodule IntelHex do
  @moduledoc """
  Decode Intel HEX files
  """
  alias IntelHex.DecodeError

  alias IntelHex.Flatten
  alias IntelHex.Record

  defstruct records: []
  @type t() :: %__MODULE__{records: [Record.t()]}

  @doc """
  Decode one Intel Hex record
  """
  @spec decode_record(String.t()) :: {:ok, Record.t()} | {:error, term()}
  def decode_record(string) do
    {:ok, decode_record!(string)}
  rescue
    exception in DecodeError -> {:error, exception.message}
  end

  defdelegate decode_record!(string), to: Record, as: :decode!

  @doc """
  Decode all of the hex records in a file or raises File.Error or IntelHex.DecodeError if an error occurs.
  """
  @spec decode_file!(String.t()) :: t()
  def decode_file!(path) do
    records =
      File.stream!(path)
      |> Stream.map(&decode_record!/1)
      |> Enum.to_list()

    %__MODULE__{records: records}
  end

  @doc """
  Decode all of the hex records in a file.
  """
  @spec decode_file(String.t()) :: {:ok, [Record.t()]} | {:error, term()}
  def decode_file(path) do
    {:ok, decode_file!(path)}
  rescue
    exception in [File.Error, DecodeError] ->
      {:error, Map.get(exception, :reason) || Map.get(exception, :message)}
  end

  @doc """
  Flatten a list of records to a list of memory values.

  This runs though the records. The records must be an ascending order.
  Gaps are allowed and are filled in by the `:fill` value. Addressing starts
  at zero, but if you'd like to start it later, use the `:start` option.
  """
  def flatten_to_list(hex, options \\ []) when is_struct(hex) do
    Flatten.to_list(hex.records, options)
  end
end

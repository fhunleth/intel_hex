defmodule IntelHex do
  @moduledoc """
  Documentation for IntelHex.
  """
  alias IntelHex.{Decoder, DecodeError, Flatten, Record}

  @doc """
  Decode one Intel Hex record
  """
  @spec decode_record(String.t()) :: {:ok, Record.t()} | {:error, DecodeError.t()}
  def decode_record(string) do
    {:ok, decode_record!(string)}
  rescue
    exception in DecodeError ->
      {:error, exception}
  end

  defdelegate decode_record!(string), to: Decoder

  @doc """
  Decode all of the hex records in a file.
  """
  @spec decode_file!(String.t()) :: [Record.t()] | no_return
  def decode_file!(path) do
    File.stream!(path)
    |> Stream.map(&decode_record!/1)
    |> Enum.to_list()
  end

  @doc """
  Flatten a list of records to a list of memory values.

  This runs though the records. The records must be an ascending order.
  Gaps are allowed and are filled in by the `:fill` value. Addressing starts
  at zero, but if you'd like to start it later, use the `:start` option.
  """
  defdelegate flatten_to_list(records, options \\ []), to: Flatten, as: :to_list
end

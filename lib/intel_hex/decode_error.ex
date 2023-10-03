defmodule IntelHex.DecodeError do
  defexception [
    :line,
    :message
  ]

  @impl true
  def message(%{line: line, message: message}) do
    "#{line}: #{message}"
  end
end

defmodule IntelHex.DecodeError do
  defexception [
    :line,
    :message
  ]

  def message(%{line: line, message: message}) do
    "#{line}: #{message}"
  end
end

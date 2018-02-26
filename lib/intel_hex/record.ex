defmodule IntelHex.Record do
  @moduledoc """
  Information for one line in an Intel HEX file
  """

  defstruct address: 0, data: [], type: :data

  @type types ::
          :data
          | :eof
          | :extended_segment_address
          | :start_segment_address
          | :extended_linear_address
          | :start_linear_address
  @type t :: %IntelHex.Record{address: non_neg_integer, data: list, type: types}
end

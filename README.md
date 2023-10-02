# IntelHex

[![CircleCI](https://circleci.com/gh/fhunleth/intel_hex.svg?style=svg)](https://circleci.com/gh/fhunleth/intel_hex)
[![Hex version](https://img.shields.io/hexpm/v/intel_hex.svg "Hex version")](https://hex.pm/packages/intel_hex)

This is a small library to help decode [Intel HEX records](https://en.wikipedia.org/wiki/Intel_HEX). This file format is frequently used for firmware images on microcontrollers.

The main interface returns a low-level view of the records:

```elixir
iex> records = IntelHex.decode_file!("test/test.hex")
[
  %IntelHex.Record{address: 0, data: [0, 0], type: :extended_linear_address},
  %IntelHex.Record{
    address: 0,
    data: [2, 24, 0, 2, 24, 3, 8, 253, 9, 2, 0, 2, 24, 11, 11, 50],
    type: :data
  },
  %IntelHex.Record{
    address: 16,
    data: [11, 60, 34, 2, 24, 19, 10, 236, 11, 0],
    type: :data
  },
  ...
  %IntelHex.Record{address: 0, data: [], type: :eof}
]
```

If you'd like the records to be flattened back into a memory image, you can run `IntelHex.flatten_to_list/2` against the records:

```elixir
iex(2)> IntelHex.flatten_to_list(records)
[2, 24, 0, 2, 24, 3, 8, 253, 9, 2, 0, 2, 24, 11, 11, 50, 11, 60, 34, 2, 24, 19,
 10, 236, 11, 0, 255, 2, 24, 27, 70, 154, 2, 29, 225, 2, 24, 35, 228, 255, 225,
 64, 255, 2, 24, 43, 127, 7, 34, 211, ...]
```

`IntelHex.flatten_to_list/2` takes keyword parameters to specify start offsets and default fill bytes for skipped locations. The default filler byte is 255 which can be seen in the above examples if you squint hard enough.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `intel_hex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:intel_hex, "~> 0.1.0"}
  ]
end
```

## Future work

The library has a couple major missing features:

1. Support for anything besides 16-bit Intel Hex files
1. Encoder support

I don't currently have a use case for those, but if you do, I'd certainly work with you to get these included.
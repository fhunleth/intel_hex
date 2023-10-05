# IntelHex

[![CircleCI](https://circleci.com/gh/fhunleth/intel_hex.svg?style=svg)](https://circleci.com/gh/fhunleth/intel_hex)
[![Hex version](https://img.shields.io/hexpm/v/intel_hex.svg "Hex version")](https://hex.pm/packages/intel_hex)

This is a library for loading, modifying and saving [Intel HEX
files](https://en.wikipedia.org/wiki/Intel_HEX). This file format is frequently
used for firmware images on microcontrollers.

Here's an example use:

```elixir
iex> hex = IntelHex.load!("./test/test.hex")
%IntelHex{}

# Take a look at the first two 16-bit integers
iex> <<x::little-16, y::little-16>> = IntelHex.get(hex, 0, 4); {x, y}
{6146, 512}

# Change them to {1, 2}
iex> hex = IntelHex.set(hex, 0, <<1::little-16, 2::little-16>>)
%IntelHex{}

# Check that it worked.
iex> <<x::little-16, y::little-16>> = IntelHex.get(hex, 0, 4); {x,y}
{1, 2}

# Save it to a new file
iex> IntelHex.save(hex, "new.hex")
:ok
```

## Installation

The package can be installed by adding `intel_hex` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:intel_hex, "~> 0.1.0"}
  ]
end
```

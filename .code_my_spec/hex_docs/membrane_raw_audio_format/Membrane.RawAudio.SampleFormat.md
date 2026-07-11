# Membrane.RawAudio.SampleFormat

This module defines sample formats used in `Membrane.RawAudio`
and some helpers to deal with them.

## to_tuple/1

Converts format atom to an equivalent 3-tuple form

## from_tuple/1

Converts 3-tuple format to an equivalent atom form

## serialize/1

converts audio format to 32-bit unsigned integer consisting of (from oldest bit):
* first bit for type (int/float)
* then bit for encoding (unsigned/signed)
* then bit for endianity (little/big)
* then sequence of zeroes
* last 8 bits for size (in bits)

expects atom format

returns format encoded as integer

## deserialize/1

Converts positive integer containing serialized format to atom.

expects serialized format

returns format atom (See `t:t/0`)
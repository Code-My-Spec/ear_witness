# LibPE.Checksum

Elixir implementation of the PE checksum algorithm by David N. Cutler 1993
  from https://bytepointer.com/resources/microsoft_pe_checksum_algo_distilled.htm

## checksum/2

binary_size is provided so embedded `checksum` values can be removed
  before running and added afterwards again.
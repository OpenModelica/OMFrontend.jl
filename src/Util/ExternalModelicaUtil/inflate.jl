# zlib decompression (RFC 1950 and DEFLATE, RFC 1951) in Julia, for the compressed variables of
# MAT files of version 7. It follows Mark Adler's puff.c: a bit reader, canonical Huffman codes
# decoded one bit at a time, and the stored, fixed and dynamic blocks.
# Author: John Tinnerholm

"""
    InflateState

The compressed input, the read position (the next byte, from 1), the bits read but not used yet,
and the output.
"""
mutable struct InflateState
  const input::Vector{UInt8}
  position::Int64
  bitBuffer::Int64
  bitCount::Int64
  const output::Vector{UInt8}
end

"""
    Huffman

A canonical Huffman code: the number of codes of each length 0 to 15 (`count[length + 1]`) and the
symbols ordered by code.
"""
struct Huffman
  count::Vector{Int64}
  symbol::Vector{Int64}
end

Huffman(symbols::Int64) = Huffman(zeros(Int64, MAX_BITS + 1), zeros(Int64, symbols))

const MAX_BITS::Int64 = 15
const MAX_LENGTH_CODES::Int64 = 286
const MAX_DISTANCE_CODES::Int64 = 30
const FIXED_LENGTH_CODES::Int64 = 288

const LENGTH_BASE::Vector{Int64} = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59,
                                    67, 83, 99, 115, 131, 163, 195, 227, 258]
const LENGTH_EXTRA::Vector{Int64} = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4,
                                     5, 5, 5, 5, 0]
const DISTANCE_BASE::Vector{Int64} = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385,
                                      513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
const DISTANCE_EXTRA::Vector{Int64} = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10,
                                       10, 11, 11, 12, 12, 13, 13]
#= The order of the code length code lengths of a dynamic block. =#
const CODE_LENGTH_ORDER::Vector{Int64} = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

"""
    inflateError(message)

Throw the error of corrupt compressed data.
"""
inflateError(message::String) = error("Invalid compressed data: " * message)

"""
    bits!(state, need)::Int64

The next `need` bits of the input (at most 15), the first bit read the lowest.
"""
function bits!(state::InflateState, need::Int64)::Int64
  local value::Int64 = state.bitBuffer
  while state.bitCount < need
    state.position > length(state.input) && inflateError("unexpected end")
    value |= Int64(state.input[state.position]) << state.bitCount
    state.position += 1
    state.bitCount += 8
  end
  state.bitBuffer = value >> need
  state.bitCount -= need
  return value & ((Int64(1) << need) - 1)
end

"""
    construct!(code, lengths, first, n)::Int64

Build the canonical Huffman code of the `n` code lengths `lengths[first:first + n - 1]` (0: the
symbol has no code). Returns 0 for a complete code, a positive number for an incomplete one, a
negative one for an over-subscribed one.
"""
function construct!(code::Huffman, lengths::Vector{Int64}, first::Int64, n::Int64)::Int64
  fill!(code.count, 0)
  for symbol::Int64 in 0:(n - 1)
    code.count[lengths[first + symbol] + 1] += 1
  end
  code.count[1] == n && return Int64(0)
  local left::Int64 = 1
  for len::Int64 in 1:MAX_BITS
    left <<= 1
    left -= code.count[len + 1]
    left < 0 && return left
  end
  local offsets::Vector{Int64} = zeros(Int64, MAX_BITS + 1)
  for len::Int64 in 1:(MAX_BITS - 1)
    offsets[len + 2] = offsets[len + 1] + code.count[len + 1]
  end
  for symbol::Int64 in 0:(n - 1)
    local len::Int64 = lengths[first + symbol]
    if len != 0
      code.symbol[offsets[len + 1] + 1] = symbol
      offsets[len + 1] += 1
    end
  end
  return left
end

"""
    decode!(state, code)::Int64

The next symbol of the input in the Huffman code `code`.
"""
function decode!(state::InflateState, code::Huffman)::Int64
  local value::Int64 = 0
  local first::Int64 = 0
  local index::Int64 = 0
  for len::Int64 in 1:MAX_BITS
    value |= bits!(state, Int64(1))
    local count::Int64 = code.count[len + 1]
    if value - count < first
      return code.symbol[index + (value - first) + 1]
    end
    index += count
    first += count
    first <<= 1
    value <<= 1
  end
  inflateError("code out of range")
end

"""
    stored!(state)

A stored block: the bits up to the next byte are dropped, then the length, its complement and the
bytes follow.
"""
function stored!(state::InflateState)::Nothing
  state.bitBuffer = 0
  state.bitCount = 0
  state.position + 3 > length(state.input) && inflateError("unexpected end")
  local input::Vector{UInt8} = state.input
  local p::Int64 = state.position
  local len::Int64 = Int64(input[p]) | (Int64(input[p + 1]) << 8)
  local complement::Int64 = Int64(input[p + 2]) | (Int64(input[p + 3]) << 8)
  len == (~complement & 0xffff) || inflateError("stored block length")
  p += 4
  p + len - 1 > length(input) && inflateError("unexpected end")
  append!(state.output, view(input, p:(p + len - 1)))
  state.position = p + len
  return nothing
end

"""
    codes!(state, lengthCode, distanceCode)

The literals and length/distance pairs of a block, up to its end symbol 256.
"""
function codes!(state::InflateState, lengthCode::Huffman, distanceCode::Huffman)::Nothing
  local output::Vector{UInt8} = state.output
  while true
    local symbol::Int64 = decode!(state, lengthCode)
    if symbol < 256
      push!(output, UInt8(symbol))
    elseif symbol == 256
      return nothing
    else
      symbol -= 257
      symbol >= 29 && inflateError("invalid length symbol")
      local len::Int64 = LENGTH_BASE[symbol + 1] + bits!(state, LENGTH_EXTRA[symbol + 1])
      local distanceSymbol::Int64 = decode!(state, distanceCode)
      distanceSymbol >= 30 && inflateError("invalid distance symbol")
      local distance::Int64 = DISTANCE_BASE[distanceSymbol + 1] + bits!(state, DISTANCE_EXTRA[distanceSymbol + 1])
      distance > length(output) && inflateError("distance too far back")
      local from::Int64 = length(output) - distance
      for k::Int64 in 1:len
        push!(output, output[from + k])
      end
    end
  end
end

"""
    fixed!(state)

A block with the fixed Huffman codes of RFC 1951.
"""
function fixed!(state::InflateState)::Nothing
  local lengths::Vector{Int64} = zeros(Int64, FIXED_LENGTH_CODES)
  lengths[1:144] .= 8
  lengths[145:256] .= 9
  lengths[257:280] .= 7
  lengths[281:288] .= 8
  local lengthCode::Huffman = Huffman(FIXED_LENGTH_CODES)
  construct!(lengthCode, lengths, Int64(1), FIXED_LENGTH_CODES)
  local distanceLengths::Vector{Int64} = fill(Int64(5), MAX_DISTANCE_CODES)
  local distanceCode::Huffman = Huffman(MAX_DISTANCE_CODES)
  construct!(distanceCode, distanceLengths, Int64(1), MAX_DISTANCE_CODES)
  codes!(state, lengthCode, distanceCode)
  return nothing
end

"""
    dynamic!(state)

A block with its own Huffman codes, which are sent first, themselves Huffman coded.
"""
function dynamic!(state::InflateState)::Nothing
  local nlen::Int64 = bits!(state, Int64(5)) + 257
  local ndist::Int64 = bits!(state, Int64(5)) + 1
  local ncode::Int64 = bits!(state, Int64(4)) + 4
  (nlen > MAX_LENGTH_CODES || ndist > MAX_DISTANCE_CODES) && inflateError("bad counts")
  local lengths::Vector{Int64} = zeros(Int64, MAX_LENGTH_CODES + MAX_DISTANCE_CODES)
  for index::Int64 in 1:ncode
    lengths[CODE_LENGTH_ORDER[index] + 1] = bits!(state, Int64(3))
  end
  local lengthCode::Huffman = Huffman(MAX_LENGTH_CODES)
  local distanceCode::Huffman = Huffman(MAX_DISTANCE_CODES)
  construct!(lengthCode, lengths, Int64(1), Int64(19)) == 0 || inflateError("incomplete code length code")
  fill!(lengths, 0)
  local index::Int64 = 0
  while index < nlen + ndist
    local symbol::Int64 = decode!(state, lengthCode)
    if symbol < 16
      lengths[index + 1] = symbol
      index += 1
    else
      local len::Int64 = 0
      local repeat::Int64 = 0
      if symbol == 16
        index == 0 && inflateError("repeat without a length")
        len = lengths[index]
        repeat = 3 + bits!(state, Int64(2))
      elseif symbol == 17
        repeat = 3 + bits!(state, Int64(3))
      else
        repeat = 11 + bits!(state, Int64(7))
      end
      index + repeat > nlen + ndist && inflateError("too many lengths")
      for _ in 1:repeat
        lengths[index + 1] = len
        index += 1
      end
    end
  end
  lengths[257] == 0 && inflateError("no end-of-block code")
  local err::Int64 = construct!(lengthCode, lengths, Int64(1), nlen)
  (err < 0 || (err > 0 && nlen - lengthCode.count[1] != 1)) && inflateError("incomplete literal/length code")
  err = construct!(distanceCode, lengths, nlen + 1, ndist)
  (err < 0 || (err > 0 && ndist - distanceCode.count[1] != 1)) && inflateError("incomplete distance code")
  codes!(state, lengthCode, distanceCode)
  return nothing
end

"""
    inflate!(state)

The DEFLATE blocks from the read position on, up to the last one.
"""
function inflate!(state::InflateState)::Nothing
  local last::Bool = false
  while !last
    last = bits!(state, Int64(1)) == 1
    local type::Int64 = bits!(state, Int64(2))
    if type == 0
      stored!(state)
    elseif type == 1
      fixed!(state)
    elseif type == 2
      dynamic!(state)
    else
      inflateError("invalid block type")
    end
  end
  return nothing
end

"""
    adler32(data)::UInt32

The Adler-32 checksum of `data` (RFC 1950).
"""
function adler32(data::AbstractVector{UInt8})::UInt32
  local a::UInt32 = 1
  local b::UInt32 = 0
  local i::Int64 = 1
  local n::Int64 = length(data)
  while i <= n
    #= 5552 bytes keep the sums below 2^32 before the modulo =#
    local stop::Int64 = min(n, i + 5551)
    for k::Int64 in i:stop
      a += data[k]
      b += a
    end
    a %= UInt32(65521)
    b %= UInt32(65521)
    i = stop + 1
  end
  return (b << 16) | a
end

"""
    zlibDecompress(data)::Vector{UInt8}

The bytes of the zlib stream `data`: its header (deflate, no preset dictionary), the DEFLATE blocks
and the Adler-32 checksum of the result, which is checked.
"""
function zlibDecompress(data::Vector{UInt8})::Vector{UInt8}
  length(data) < 6 && inflateError("too short for a zlib stream")
  local cmf::UInt8 = data[1]
  local flg::UInt8 = data[2]
  (cmf & 0x0f == 0x08 && cmf >> 4 <= 0x07) || inflateError("not deflate")
  (UInt32(cmf) * 256 + UInt32(flg)) % 31 == 0 || inflateError("zlib header check")
  flg & 0x20 == 0 || inflateError("preset dictionary")
  local state::InflateState = InflateState(data, Int64(3), Int64(0), Int64(0), sizehint!(UInt8[], 4 * length(data)))
  inflate!(state)
  local p::Int64 = state.position
  p + 3 > length(data) && inflateError("no Adler-32 checksum")
  local expected::UInt32 = (UInt32(data[p]) << 24) | (UInt32(data[p + 1]) << 16) | (UInt32(data[p + 2]) << 8) | UInt32(data[p + 3])
  adler32(state.output) == expected || inflateError("Adler-32 checksum")
  return state.output
end

#= /*
* This file is part of OpenModelica.
*
* Copyright (c) 1998-2026, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF AGPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.8.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GNU AGPL
* VERSION 3, ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the OSMC (Open Source Modelica Consortium)
* Public License (OSMC-PL) are obtained from OSMC, either from the above
* address, from the URLs:
* http://www.openmodelica.org or
* https://github.com/OpenModelica/ or
* http://www.ida.liu.se/projects/OpenModelica,
* and in the OpenModelica distribution.
*
* GNU AGPL version 3 is obtained from:
* https://www.gnu.org/licenses/licenses.html#GPL
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*
*/ =#

# The string functions of the Modelica Standard Library (ModelicaStrings.c of MSL 4.1.0) in Julia,
# for constant evaluation. Indices are byte indices from 1, as in the C code; a string ends at its
# last byte (the C code stops at the terminating NUL).
# Author: John Tinnerholm

"""
    _byte(string, index)::UInt8

The byte at `index`, or `0x00` outside the string (the terminating NUL of the C string).
"""
@inline function _byte(string::String, index::Int64)::UInt8
  return 1 <= index <= ncodeunits(string) ? codeunit(string, index) : 0x00
end

"""
    _bytes(string, first, last)::String

The bytes `first:last` of `string` as a new string.
"""
@inline function _bytes(string::String, first::Int64, last::Int64)::String
  return String(codeunits(string)[first:last])
end

"""
    _isspace(byte)::Bool

`isspace` of the C locale: space, `\\t`, `\\n`, `\\v`, `\\f`, `\\r`.
"""
@inline _isspace(byte::UInt8)::Bool = byte == 0x20 || (0x09 <= byte <= 0x0d)

"""
    _isdigit(byte)::Bool

`isdigit` of the C locale.
"""
@inline _isdigit(byte::UInt8)::Bool = UInt8('0') <= byte <= UInt8('9')

"""
    _isalpha(byte)::Bool

`isalpha` of the C locale: ASCII letters.
"""
@inline _isalpha(byte::UInt8)::Bool = (UInt8('a') <= byte <= UInt8('z')) || (UInt8('A') <= byte <= UInt8('Z'))

"""
    _tolower(byte)::UInt8

`tolower` of the C locale.
"""
@inline _tolower(byte::UInt8)::UInt8 = UInt8('A') <= byte <= UInt8('Z') ? byte + 0x20 : byte

"""
    Strings_skipWhiteSpace(string, startIndex = 1)::Int64

The index of the first byte from `startIndex` on that is not white space (or one past the end).
"""
function Strings_skipWhiteSpace(string::String, startIndex::Int64 = Int64(1))::Int64
  local i::Int64 = startIndex
  while _byte(string, i) != 0x00 && _isspace(_byte(string, i))
    i += 1
  end
  return i
end

"""
    _matchUnsignedInteger(string, start)::Int64

The number of digits from `start` on.
"""
function _matchUnsignedInteger(string::String, start::Int64)::Int64
  local p::Int64 = start
  while _isdigit(_byte(string, p))
    p += 1
  end
  return p - start
end

"""
    Strings_compare(string1, string2, caseSensitive)::Int64

1 if `string1` is less than `string2`, 2 if they are equal, 3 if it is greater (the enumeration
Modelica.Utilities.Types.Compare). Without `caseSensitive` ASCII letters compare in lower case.
"""
function Strings_compare(string1::String, string2::String, caseSensitive::Bool)::Int64
  local result::Int64 = 0
  if caseSensitive
    result = cmp(string1, string2)
  else
    local i::Int64 = 1
    while _tolower(_byte(string1, i)) == _tolower(_byte(string2, i)) && _byte(string1, i) != 0x00
      i += 1
    end
    result = Int64(_tolower(_byte(string1, i))) - Int64(_tolower(_byte(string2, i)))
  end
  return result < 0 ? Int64(1) : result == 0 ? Int64(2) : Int64(3)
end

#= The longest number token the C code converts (MAX_TOKEN_SIZE). =#
const MAX_TOKEN_SIZE::Int64 = 100

"""
    Strings_scanInteger(string, startIndex, unsigned)::Tuple{Int64, Int64}

Scan an integer after white space from `startIndex`: `(next index, value)`, or `(startIndex, 0)`
if there is none (no digits, a sign when `unsigned`, or a Real number). The value is a C `int`.
"""
function Strings_scanInteger(string::String, startIndex::Int64, unsigned::Bool)::Tuple{Int64, Int64}
  local tokenStart::Int64 = Strings_skipWhiteSpace(string, startIndex)
  local first::UInt8 = _byte(string, tokenStart)
  local sign::Int64 = (first == UInt8('+') || first == UInt8('-')) ? 1 : 0
  if !unsigned || sign == 0
    local numberLength::Int64 = _matchUnsignedInteger(string, tokenStart + sign)
    if numberLength > 0 && sign + numberLength < MAX_TOKEN_SIZE
      local after::UInt8 = _byte(string, tokenStart + sign + numberLength)
      if after == 0x00 || (after != UInt8('.') && after != UInt8('e') && after != UInt8('E'))
        local text::String = _bytes(string, tokenStart, tokenStart + sign + numberLength - 1)
        local parsed::Union{Nothing, Int64} = tryparse(Int64, text)
        #= strtol saturates; the result is then cast to a C int =#
        local value::Int64 = parsed === nothing ? (first == UInt8('-') ? typemin(Int64) : typemax(Int64)) : parsed
        return (tokenStart + sign + numberLength, Int64(value % Int32))
      end
    end
  end
  return (startIndex, Int64(0))
end

"""
    Strings_scanReal(string, startIndex, unsigned)::Tuple{Int64, Float64}

Scan a Real number after white space from `startIndex`, with the grammar
`[sign] unsigned [. [unsigned]] [(e|E) [sign] unsigned]`: `(next index, value)`, or
`(startIndex, 0.0)` if there is none.
"""
function Strings_scanReal(string::String, startIndex::Int64, unsigned::Bool)::Tuple{Int64, Float64}
  local tokenStart::Int64 = Strings_skipWhiteSpace(string, startIndex)
  local totalLength::Int64 = 0
  local first::UInt8 = _byte(string, tokenStart)
  if first == UInt8('+') || first == UInt8('-')
    unsigned && return (startIndex, 0.0)
    totalLength = 1
  end
  totalLength += _matchUnsignedInteger(string, tokenStart + totalLength)
  if _byte(string, tokenStart + totalLength) == UInt8('.')
    totalLength += 1
    totalLength += _matchUnsignedInteger(string, tokenStart + totalLength)
  end
  local e::UInt8 = _byte(string, tokenStart + totalLength)
  if e == UInt8('e') || e == UInt8('E')
    local expLength::Int64 = 1
    local expSign::UInt8 = _byte(string, tokenStart + totalLength + 1)
    if expSign == UInt8('+') || expSign == UInt8('-')
      expLength += 1
    end
    local digits::Int64 = _matchUnsignedInteger(string, tokenStart + totalLength + expLength)
    digits == 0 && return (startIndex, 0.0)
    totalLength += expLength + digits
  end
  if totalLength > 0 && totalLength < MAX_TOKEN_SIZE
    local text::String = _bytes(string, tokenStart, tokenStart + totalLength - 1)
    local parsed::Union{Nothing, Float64} = tryparse(Float64, text)
    if parsed !== nothing
      return (tokenStart + totalLength, parsed)
    end
    #= out of the range of Float64: strtod gives ±Inf or 0, as the rounding of the exact value =#
    local wide::Union{Nothing, BigFloat} = tryparse(BigFloat, text)
    if wide !== nothing
      return (tokenStart + totalLength, Float64(wide))
    end
  end
  return (startIndex, 0.0)
end

"""
    Strings_scanString(string, startIndex)::Tuple{Int64, String}

Scan a string in double quotes after white space from `startIndex` (`\\"` does not end it and is
kept as is): `(next index, contents)`, or `(startIndex, "")` if there is none or it is empty.
"""
function Strings_scanString(string::String, startIndex::Int64)::Tuple{Int64, String}
  local tokenStart::Int64 = Strings_skipWhiteSpace(string, startIndex)
  _byte(string, tokenStart) == UInt8('"') || return (startIndex, "")
  local i::Int64 = tokenStart + 1
  while true
    local c::UInt8 = _byte(string, i)
    c == 0x00 && return (startIndex, "")
    if c == UInt8('"') && _byte(string, i - 1) != UInt8('\\')
      break
    end
    i += 1
  end
  local pastToken::Int64 = i + 1
  local tokenLength::Int64 = pastToken - tokenStart - 2
  tokenLength > 0 || return (startIndex, "")
  return (pastToken, _bytes(string, tokenStart + 1, tokenStart + tokenLength))
end

"""
    Strings_scanIdentifier(string, startIndex)::Tuple{Int64, String}

Scan an identifier (a letter, then letters, digits and `_`) after white space from `startIndex`:
`(next index, identifier)`, or `(startIndex, "")` if there is none.
"""
function Strings_scanIdentifier(string::String, startIndex::Int64)::Tuple{Int64, String}
  local tokenStart::Int64 = Strings_skipWhiteSpace(string, startIndex)
  _isalpha(_byte(string, tokenStart)) || return (startIndex, "")
  local tokenLength::Int64 = 1
  while true
    local c::UInt8 = _byte(string, tokenStart + tokenLength)
    (_isalpha(c) || _isdigit(c) || c == UInt8('_')) || break
    tokenLength += 1
  end
  return (tokenStart + tokenLength, _bytes(string, tokenStart, tokenStart + tokenLength - 1))
end

"""
    Strings_hashString(string)::Int64

The hash of ModelicaStrings_hashString: Arash Partow's AP hash (uthash's HASH_AP) of the bytes,
as a C `int`.
"""
function Strings_hashString(string::String)::Int64
  local hash::UInt32 = 0xAAAAAAAA
  local i::Int64 = 0
  for byte::UInt8 in codeunits(string)
    local key::UInt32 = UInt32(byte)
    if iseven(i)
      hash ⊻= (hash << 7) ⊻ (key * (hash >> 3))
    else
      hash ⊻= ~((hash << 11) + (key ⊻ (hash >> 5)))
    end
    i += 1
  end
  return Int64(reinterpret(Int32, hash))
end

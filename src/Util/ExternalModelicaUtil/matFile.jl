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

# MATLAB MAT files of version 4, 6 and 7 (7: compressed with zlib) in Julia, for
# ModelicaIO_readMatrixSizes and ModelicaIO_readRealMatrix (ModelicaIO.c of MSL 4.1.0, which reads
# them with matio). Version 7.3 files are HDF5 files and are not read.
# Author: John Tinnerholm

"""
    MatVariable

A variable of a MAT file: its name, its matio class (1 cell, 2 struct, 3 object, 4 char, 5 sparse,
6 to 15 numeric, 0 empty), whether it is complex, its dimensions, the real part of a numeric
variable as `Float64` in column-major order, and the field names and fields of a struct (for each
element, column-major, all fields in order).
"""
struct MatVariable
  name::String
  classType::Int64
  isComplex::Bool
  dims::Vector{Int64}
  data::Vector{Float64}
  fieldNames::Vector{String}
  fields::Vector{MatVariable}
end

const MAT_CLASS_EMPTY::Int64 = 0
const MAT_CLASS_STRUCT::Int64 = 2
const MAT_CLASS_CHAR::Int64 = 4
const MAT_CLASS_SPARSE::Int64 = 5
const MAT_CLASS_DOUBLE::Int64 = 6
const MAT_CLASS_UINT64::Int64 = 15
const MI_MATRIX::Int64 = 14
const MI_COMPRESSED::Int64 = 15
const MATLAB_NAME_LENGTH_MAX::Int64 = 64

const EMPTY_MAT_VARIABLE::MatVariable =
  MatVariable("", MAT_CLASS_EMPTY, false, Int64[0, 0], Float64[], String[], MatVariable[])

"""
    _uint(bytes, position, n, bigEndian)::UInt64

The unsigned integer of the `n` bytes from `position` on, in the byte order of the file.
"""
function _uint(bytes::Vector{UInt8}, position::Int64, n::Int64, bigEndian::Bool)::UInt64
  position + n - 1 > length(bytes) && error("unexpected end of the file")
  local value::UInt64 = 0
  if bigEndian
    for k::Int64 in 0:(n - 1)
      value = (value << 8) | UInt64(bytes[position + k])
    end
  else
    for k::Int64 in (n - 1):-1:0
      value = (value << 8) | UInt64(bytes[position + k])
    end
  end
  return value
end

"""
    _int32(bytes, position, bigEndian)::Int64

The signed 32-bit integer from `position` on.
"""
_int32(bytes::Vector{UInt8}, position::Int64, bigEndian::Bool)::Int64 =
  Int64(reinterpret(Int32, UInt32(_uint(bytes, position, Int64(4), bigEndian))))

"""
    _miSize(type)::Int64

The size in bytes of one number of the MAT data type `type` (0 for a type that holds no numbers).
"""
function _miSize(type::Int64)::Int64
  (type == 1 || type == 2) && return Int64(1)
  (type == 3 || type == 4) && return Int64(2)
  (type == 5 || type == 6 || type == 7) && return Int64(4)
  (type == 9 || type == 12 || type == 13) && return Int64(8)
  return Int64(0)
end

"""
    _miNumber(type, value)::Float64

The number of MAT data type `type` with the bits `value`, as `Float64`.
"""
function _miNumber(type::Int64, value::UInt64)::Float64
  type == 1 && return Float64(reinterpret(Int8, UInt8(value)))
  type == 2 && return Float64(UInt8(value))
  type == 3 && return Float64(reinterpret(Int16, UInt16(value)))
  type == 4 && return Float64(UInt16(value))
  type == 5 && return Float64(reinterpret(Int32, UInt32(value)))
  type == 6 && return Float64(UInt32(value))
  type == 7 && return Float64(reinterpret(Float32, UInt32(value)))
  type == 9 && return reinterpret(Float64, value)
  type == 12 && return Float64(reinterpret(Int64, value))
  return Float64(value)
end

"""
    _numbers(bytes, type, size, position, bigEndian)::Vector{Float64}

The numbers of the data element of type `type` and `size` bytes at `position`.
"""
function _numbers(bytes::Vector{UInt8}, type::Int64, size::Int64, position::Int64, bigEndian::Bool)::Vector{Float64}
  local width::Int64 = _miSize(type)
  width == 0 && error("data of type $type is not numeric")
  local n::Int64 = size ÷ width
  local result::Vector{Float64} = Vector{Float64}(undef, n)
  for k::Int64 in 1:n
    result[k] = _miNumber(type, _uint(bytes, position + (k - 1) * width, width, bigEndian))
  end
  return result
end

"""
    _tag(bytes, position, bigEndian)::Tuple{Int64, Int64, Int64, Int64}

The data element of a version 5 file at `position`: `(type, size, data position, next position)`.
A small element has type and size in one word and its data in the next; other data is padded to 8
bytes, except compressed data.
"""
function _tag(bytes::Vector{UInt8}, position::Int64, bigEndian::Bool)::Tuple{Int64, Int64, Int64, Int64}
  local word::UInt64 = _uint(bytes, position, Int64(4), bigEndian)
  if word >> 16 != 0
    return (Int64(word & 0xffff), Int64(word >> 16), position + 4, position + 8)
  end
  local type::Int64 = Int64(word)
  local size::Int64 = Int64(_uint(bytes, position + 4, Int64(4), bigEndian))
  local next::Int64 = type == MI_COMPRESSED ? position + 8 + size : position + 8 + cld(size, 8) * 8
  return (type, size, position + 8, next)
end

"""
    _cString(bytes, first, last)::String

The bytes `first:last` up to the first NUL.
"""
function _cString(bytes::Vector{UInt8}, first::Int64, last::Int64)::String
  local stop::Int64 = last
  for k::Int64 in first:last
    if bytes[k] == 0x00
      stop = k - 1
      break
    end
  end
  return String(bytes[first:stop])
end

"""
    _matrix(bytes, position, size, bigEndian)::MatVariable

The variable of the miMATRIX element with `size` bytes of data at `position` (version 5).
"""
function _matrix(bytes::Vector{UInt8}, position::Int64, size::Int64, bigEndian::Bool)::MatVariable
  size == 0 && return EMPTY_MAT_VARIABLE
  local (_, _, flagsAt::Int64, dimsTag::Int64) = _tag(bytes, position, bigEndian)
  local flags::UInt64 = _uint(bytes, flagsAt, Int64(4), bigEndian)
  local classType::Int64 = Int64(flags & 0xff)
  local isComplex::Bool = (flags >> 8) & 0x08 != 0
  local (_, dimsSize::Int64, dimsAt::Int64, nameTag::Int64) = _tag(bytes, dimsTag, bigEndian)
  local dims::Vector{Int64} = Int64[_int32(bytes, dimsAt + 4 * k, bigEndian) for k in 0:(dimsSize ÷ 4 - 1)]
  local (_, nameSize::Int64, nameAt::Int64, next::Int64) = _tag(bytes, nameTag, bigEndian)
  local name::String = _cString(bytes, nameAt, nameAt + nameSize - 1)
  local data::Vector{Float64} = Float64[]
  local fieldNames::Vector{String} = String[]
  local fields::Vector{MatVariable} = MatVariable[]
  if MAT_CLASS_DOUBLE <= classType <= MAT_CLASS_UINT64
    local (type::Int64, dataSize::Int64, dataAt::Int64, _) = _tag(bytes, next, bigEndian)
    data = _numbers(bytes, type, dataSize, dataAt, bigEndian)
  elseif classType == MAT_CLASS_STRUCT
    local (_, _, lengthAt::Int64, namesTag::Int64) = _tag(bytes, next, bigEndian)
    local nameLength::Int64 = _int32(bytes, lengthAt, bigEndian)
    local (_, namesSize::Int64, namesAt::Int64, fieldTag::Int64) = _tag(bytes, namesTag, bigEndian)
    local nfields::Int64 = nameLength > 0 ? namesSize ÷ nameLength : 0
    for f::Int64 in 0:(nfields - 1)
      push!(fieldNames, _cString(bytes, namesAt + f * nameLength, namesAt + (f + 1) * nameLength - 1))
    end
    local p::Int64 = fieldTag
    for k::Int64 in 0:(prod(dims) * nfields - 1)
      local (type::Int64, fieldSize::Int64, fieldAt::Int64, fieldNext::Int64) = _tag(bytes, p, bigEndian)
      type == MI_MATRIX || error("a field of struct \"$name\" is not a matrix")
      local field::MatVariable = _matrix(bytes, fieldAt, fieldSize, bigEndian)
      push!(fields, MatVariable(fieldNames[k % nfields + 1], field.classType, field.isComplex, field.dims, field.data,
                                field.fieldNames, field.fields))
      p = fieldNext
    end
  end
  return MatVariable(name, classType, isComplex, dims, data, fieldNames, fields)
end

"""
    _version5Variables(bytes, bigEndian)::Vector{MatVariable}

The variables of a version 5 file (MATLAB 5 to 7.2: the format of version 6, compressed in
version 7), after its 128-byte header.
"""
function _version5Variables(bytes::Vector{UInt8}, bigEndian::Bool)::Vector{MatVariable}
  local variables::Vector{MatVariable} = MatVariable[]
  local p::Int64 = 129
  while p + 7 <= length(bytes)
    local (type::Int64, size::Int64, at::Int64, next::Int64) = _tag(bytes, p, bigEndian)
    if type == MI_COMPRESSED
      local inflated::Vector{UInt8} = zlibDecompress(bytes[at:(at + size - 1)])
      local (innerType::Int64, innerSize::Int64, innerAt::Int64, _) = _tag(inflated, Int64(1), bigEndian)
      innerType == MI_MATRIX && push!(variables, _matrix(inflated, innerAt, innerSize, bigEndian))
    elseif type == MI_MATRIX
      push!(variables, _matrix(bytes, at, size, bigEndian))
    end
    p = next
  end
  return variables
end

"""
    _version4Type(bytes, position)::Tuple{Bool, Bool, Int64}

The type word MOPT of a version 4 variable at `position`: whether it is valid, whether the file is
big-endian (M), and the word.
"""
function _version4Type(bytes::Vector{UInt8}, position::Int64)::Tuple{Bool, Bool, Int64}
  for bigEndian::Bool in (false, true)
    local word::Int64 = _int32(bytes, position, bigEndian)
    local m::Int64 = word ÷ 1000
    local o::Int64 = (word % 1000) ÷ 100
    local p::Int64 = (word % 100) ÷ 10
    local t::Int64 = word % 10
    if word >= 0 && m == (bigEndian ? 1 : 0) && o == 0 && p <= 5 && t <= 2
      return (true, bigEndian, word)
    end
  end
  return (false, false, Int64(0))
end

"""
    _version4Variables(bytes)::Vector{MatVariable}

The variables of a version 4 file: each one a header of five 32-bit integers (type MOPT, rows,
columns, imaginary flag, name length), the name, the real part and the imaginary part.
"""
function _version4Variables(bytes::Vector{UInt8})::Vector{MatVariable}
  #= the type P of the data: Float64, Float32, Int32, Int16, UInt16, UInt8, as MAT data types =#
  local miTypes::Vector{Int64} = Int64[9, 7, 5, 3, 4, 2]
  local variables::Vector{MatVariable} = MatVariable[]
  local position::Int64 = 1
  while position + 19 <= length(bytes)
    local (valid::Bool, bigEndian::Bool, word::Int64) = _version4Type(bytes, position)
    valid || break
    local rows::Int64 = _int32(bytes, position + 4, bigEndian)
    local columns::Int64 = _int32(bytes, position + 8, bigEndian)
    local imaginary::Bool = _int32(bytes, position + 12, bigEndian) != 0
    local nameLength::Int64 = _int32(bytes, position + 16, bigEndian)
    (rows < 0 || columns < 0 || nameLength < 1) && break
    local nameAt::Int64 = position + 20
    nameAt + nameLength - 1 > length(bytes) && break
    local name::String = _cString(bytes, nameAt, nameAt + nameLength - 1)
    local type::Int64 = miTypes[(word % 100) ÷ 10 + 1]
    local dataAt::Int64 = nameAt + nameLength
    local dataSize::Int64 = rows * columns * _miSize(type)
    dataAt + dataSize * (imaginary ? 2 : 1) - 1 > length(bytes) && break
    local t::Int64 = word % 10
    local classType::Int64 = t == 0 ? MAT_CLASS_DOUBLE : t == 1 ? MAT_CLASS_CHAR : MAT_CLASS_SPARSE
    local data::Vector{Float64} = t == 0 ? _numbers(bytes, type, dataSize, dataAt, bigEndian) : Float64[]
    push!(variables, MatVariable(name, classType, imaginary, Int64[rows, columns], data, String[], MatVariable[]))
    position = dataAt + dataSize * (imaginary ? 2 : 1)
  end
  return variables
end

"""
    readMatVariables(fileName, functionName)::Vector{MatVariable}

The variables of the MAT file. Errors as ModelicaIO (prefixed by `functionName`) for a file that
is missing or not a MAT file, and for a version 7.3 file.
"""
function readMatVariables(fileName::String, functionName::String)::Vector{MatVariable}
  local openError::String = "Not possible to open file \"$fileName\": No such file or directory"
  isfile(fileName) || matError(functionName, openError)
  local bytes::Vector{UInt8} = read(fileName)
  if length(bytes) >= 128
    local endian::Tuple{UInt8, UInt8} = (bytes[127], bytes[128])
    if endian == (UInt8('I'), UInt8('M')) || endian == (UInt8('M'), UInt8('I'))
      local bigEndian::Bool = endian == (UInt8('M'), UInt8('I'))
      local version::UInt64 = _uint(bytes, Int64(125), Int64(2), bigEndian)
      #= the message of matio built without HDF5, as in libModelicaExternalC =#
      version == 0x0200 && matError(functionName, "No HDF5 support which is required to read the v7.3 " *
                                                  "MAT file \"$fileName\"")
      version == 0x0100 && return _version5Variables(bytes, bigEndian)
    end
  end
  local variables::Vector{MatVariable} = _version4Variables(bytes)
  isempty(variables) && matError(functionName, openError)
  return variables
end

"""
    matError(functionName, message)

Throw the error `message` of the ModelicaIO function `functionName`.
"""
matError(functionName::String, message::String) = error(functionName * " failed: " * message)

"""
    _shortName(name)::String

`name` cut to the length of a MATLAB name (63 bytes and "...").
"""
function _shortName(name::String)::String
  ncodeunits(name) > MATLAB_NAME_LENGTH_MAX - 1 || return name
  return String(codeunits(name)[1:(MATLAB_NAME_LENGTH_MAX - 1)]) * "..."
end

"""
    readMatMatrix(fileName, matrixName, functionName)::Tuple{Bool, MatVariable}

The numeric, real matrix `matrixName` of the file, where `a.b.c` is field `c` of field `b` of the
1x1 struct `a`, with the checks and error messages of readRealMatIO of ModelicaIO.c. `false` when
the C code finds no variable and gives no error (a field that is missing before the last name).
"""
function readMatMatrix(fileName::String, matrixName::String, functionName::String)::Tuple{Bool, MatVariable}
  local variables::Vector{MatVariable} = readMatVariables(fileName, functionName)
  local tokens::Vector{String} = String[String(t) for t in split(matrixName, '.'; keepempty = false)]
  local rootName::String = isempty(tokens) ? matrixName : tokens[1]
  local index::Int64 = something(findfirst(v::MatVariable -> v.name == rootName, variables), 0)
  if index == 0
    matError(functionName, "Variable \"$(isempty(tokens) ? matrixName : _shortName(rootName))\" not found in file \"$fileName\".")
  end
  local variable::MatVariable = variables[index]
  #= the C code names the first name of the path in these messages =#
  local first::String = isempty(tokens) ? matrixName : _shortName(tokens[1])
  local k::Int64 = 2
  while k <= length(tokens)
    if variable.classType != MAT_CLASS_STRUCT
      matError(functionName, "Variable \"$first\" of \"$matrixName\" is not a struct array.")
    elseif length(variable.dims) != 2
      matError(functionName, "Variable \"$first\" of \"$matrixName\" is not a struct array of rank 2.")
    elseif variable.dims != [1, 1]
      matError(functionName, "Variable \"$first\" of \"$matrixName\" is not a 1x1 struct array.")
    end
    local field::Int64 = something(findfirst(==(tokens[k]), variable.fieldNames), 0)
    k += 1
    if field == 0
      k <= length(tokens) && return (false, EMPTY_MAT_VARIABLE)
      matError(functionName, "Variable \"$matrixName\" not found in file \"$fileName\".")
    end
    variable = variable.fields[field]
  end
  length(variable.dims) == 2 || matError(functionName, "Variable \"$matrixName\" is not of rank 2.")
  MAT_CLASS_DOUBLE <= variable.classType <= MAT_CLASS_UINT64 ||
    matError(functionName, "Matrix \"$matrixName\" is not a numeric array.")
  variable.isComplex && matError(functionName, "Matrix \"$matrixName\" must not be complex.")
  return (true, variable)
end

"""
    ModelicaIO_readMatrixSizes(fileName, matrixName)::Vector{Int64}

The dimensions `[rows, columns]` of the real matrix `matrixName` of the MAT file.
"""
function ModelicaIO_readMatrixSizes(fileName::String, matrixName::String)::Vector{Int64}
  local (found::Bool, variable::MatVariable) = readMatMatrix(fileName, matrixName, "ModelicaIO_readMatrixSizes")
  found || return Int64[0, 0]
  return Int64[variable.dims[1], variable.dims[2]]
end

"""
    ModelicaIO_readRealMatrix(fileName, matrixName, nrow, ncol, verboseRead = true)::Matrix{Float64}

The real matrix `matrixName` of the MAT file, which must have `nrow` rows and `ncol` columns.
"""
function ModelicaIO_readRealMatrix(fileName::String, matrixName::String, nrow::Int64, ncol::Int64,
                                   verboseRead::Bool = true)::Matrix{Float64}
  local functionName::String = "ModelicaIO_readRealMatrix"
  verboseRead && print(stdout, "... loading \"$matrixName\" from \"$fileName\"\n")
  local (found::Bool, variable::MatVariable) = readMatMatrix(fileName, matrixName, functionName)
  found || return zeros(Float64, nrow, ncol)
  local rows::Int64 = variable.dims[1]
  local columns::Int64 = variable.dims[2]
  nrow == rows || matError(functionName, "Cannot read $nrow rows of array \"$matrixName($rows,$columns)\" from file \"$fileName\"")
  ncol == columns || matError(functionName, "Cannot read $ncol columns of array \"$matrixName($rows,$columns)\" from file \"$fileName\"")
  length(variable.data) == rows * columns ||
    matError(functionName, "Error when reading numeric data of matrix \"$matrixName($nrow,$ncol)\" from file \"$fileName\"")
  return Matrix{Float64}(reshape(copy(variable.data), rows, columns))
end

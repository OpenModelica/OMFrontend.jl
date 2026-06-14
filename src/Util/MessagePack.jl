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

module MessagePack

using MetaModelica
using ExportAll

#=  Do not modify this file: It was automatically generated from https:github.com/sjoelund/msgpack-modelica/
=#

module Pack

using MetaModelica
using ExportAll

module SimpleBuffer

using MetaModelica
using ExportAll

module SimpleBuffer

"""using ExternalObject #= Modelica extend clause"""
function constructor()::SimpleBuffer
  local buf::SimpleBuffer

  @error "TODO: Defined in the runtime"
  return buf
end

function destructor(buf::SimpleBuffer)
  return @error "TODO: Defined in the runtime"
end
end

function writeFile(sbuffer::SimpleBuffer, file::String)
  return @error "TODO: Defined in the runtime"
end

function position(sbuffer::SimpleBuffer)::Int
  local position::Int

  @error "TODO: Defined in the runtime"
  return position
end

@exportAll()
end

module Packer

"""using ExternalObject #= Modelica extend clause"""
function constructor(buf::SimpleBuffer.SimpleBuffer)::Packer
  local packer::Packer

  @error "TODO: Defined in the runtime"
  return packer
end

function destructor(packer::Packer)
  return @error "TODO: Defined in the runtime"
end
end

function double(packer::Packer, dbl::AbstractFloat)::Bool
  local result::Bool

  @error "TODO: Defined in the runtime"
  return result
end

function integer(packer::Packer, i::Int)::Bool
  local result::Bool

  @error "TODO: Defined in the runtime"
  return result
end

function bool(packer::Packer, bool::Bool)::Bool
  local result::Bool

  function msgpack_pack_true(packer::Packer)::Bool
    local result::Bool

    @error "TODO: Defined in the runtime"
    return result
  end

  function msgpack_pack_false(packer::Packer)::Bool
    local result::Bool

    @error "TODO: Defined in the runtime"
    return result
  end

  @assign result = if bool
    msgpack_pack_true(packer)
  else
    msgpack_pack_false(packer)
  end
  return result
end

function sequence(packer::Packer, len::Int)::Bool
  local result::Bool

  @error "TODO: Defined in the runtime"
  return result
end

function map(packer::Packer, len::Int)::Bool
  local result::Bool

  @error "TODO: Defined in the runtime"
  return result
end

function string(packer::Packer, str::String)::Bool
  local result::Bool

  @error "TODO: Defined in the runtime"
  return result
end

function nil(packer::Packer)::Bool
  local result::Bool

  @error "TODO: Defined in the runtime"
  return result
end

@exportAll()
end

module Unpack

using MetaModelica
using ExportAll

module Deserializer

"""using ExternalObject #= Modelica extend clause"""
function constructor(file::String)::Deserializer
  local deserializer::Deserializer

  @error "TODO: Defined in the runtime"
  return deserializer
end

function destructor(deserializer::Deserializer)
  return @error "TODO: Defined in the runtime"
end
end

function next(deserializer::Deserializer, offset::Int)::Tuple{Bool, Integer}
  local newoffset::Int
  local success::Bool

  @error "TODO: Defined in the runtime"
  return (success, newoffset)
end

function toStream(
  deserializer::Deserializer,
  ss::Utilities.Stream.Stream,
  offset::Int,
)::Tuple{Integer, Bool}
  local success::Bool
  local newoffset::Int

  @error "TODO: Defined in the runtime"
  return (newoffset, success)
end

function integer(deserializer::Deserializer, offset::Int)::Tuple{Integer, Integer, Bool}
  local success::Bool
  local newoffset::Int
  local res::Int

  @error "TODO: Defined in the runtime"
  return (res, newoffset, success)
end

function string(deserializer::Deserializer, offset::Int)::Tuple{String, Integer, Bool}
  local success::Bool
  local newoffset::Int
  local res::String

  @error "TODO: Defined in the runtime"
  return (res, newoffset, success)
end

function get_integer(deserializer::Deserializer)::Int
  local res::Int

  @error "TODO: Defined in the runtime"
  return res
end

@exportAll()
end

module Utilities

using MetaModelica
using ExportAll

module Stream

using MetaModelica
using ExportAll

module Stream

"""using ExternalObject #= Modelica extend clause"""
function constructor(file::String = "")::Stream #= Output file or \\\"\\\" for an in-memory string accessible using get() =#
  local ss::Stream

  @error "TODO: Defined in the runtime"
  return ss
end

function destructor(ss::Stream)
  return @error "TODO: Defined in the runtime"
end
end

"""Only works for in-memory streams"""
function get(ss::Stream)::String
  local str::String

  @error "TODO: Defined in the runtime"
  return str
end

function append(ss::Stream, str::String)
  return @error "TODO: Defined in the runtime"
end

@exportAll()
end

function deserializeFileToFile(
  inBinaryFile::String,
  outTextFile::String,
  separator::String = "\\n",
)
  local deserializer::Unpack.Deserializer = Unpack.Deserializer(inBinaryFile)
  local ss::Stream.Stream = Stream.Stream(outTextFile)
  local success::Bool = true
  local offset::Int = 0

  return while success
    @assign (offset, success) = Unpack.toStream(deserializer, ss, offset)
    if success
      Stream.append(ss, separator)
    end
  end
end

@exportAll()
end

module UsersGuide

using MetaModelica
using ExportAll

module License

using MetaModelica
using ExportAll

@exportAll()
end

@exportAll()
end

@exportAll()
end

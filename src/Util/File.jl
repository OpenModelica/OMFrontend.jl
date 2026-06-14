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

module File

using MetaModelica
using ExportAll

module FileHandler

using ExternalObject #= Modelica extend clause =#

"""File constructor."""
function constructor(fromID::Option{Integer} = noReference()) where {T} #= Never pass this an actual Option<Integer>. Only use File.getReference(file) or File.noReference(). Determines if we should restore from another File object or create a new File. =#
  local file::FileHandler

  @error "TODO: Defined in the runtime"
  return file
end

function destructor(file::FileHandler)
  return @error "TODO: Defined in the runtime"
end
end

Mode = (() -> begin #= Enumeration =#
  Read = 1
  Write = 2
  () -> (Read; Write)
end)()

function open(file::FileHandler, filename::String, mode::Mode = Mode.Read)
  return @error "TODO: Defined in the runtime"
end

function write(file::FileHandler, data::String)
  return @error "TODO: Defined in the runtime"
end

function writeInt(file::FileHandler, data::Int, format::String = "%d")
  return @error "TODO: Defined in the runtime"
end

function writeReal(file::FileHandler, data::AbstractFloat, format::String = "%.15g")
  return @error "TODO: Defined in the runtime"
end

Escape = (() -> begin #= Enumeration =#
  None = 1  #= No escape string =#
  C = 2  #= Escapes C strings (minimally): \\\\n and \\\" =#
  JSON = 3  #= Escapes JSON strings (quotes and control characters) =#
  XML = 4  #= Escapes strings to XML text =#
  () -> (None; C; JSON; XML)  #= Escapes strings to XML text =#
end)()

function writeEscape(file::FileHandler, data::String, escape::Escape)
  return @error "TODO: Defined in the runtime"
end

Whence = (() -> begin #= Enumeration =#
  Set = 1  #= SEEK_SET 0=start of file =#
  Current = 2  #= SEEK_CUR 0=current byte =#
  End = 3  #= SEEK_END 0=end of file =#
  () -> (Set; Current; End)  #= SEEK_END 0=end of file =#
end)()

function seek(file::FileHandler, offset::Int, whence::Whence = Whence.Set)::Bool
  local success::Bool

  @error "TODO: Defined in the runtime"
  return success
end

function tell(file::FileHandler)::Int
  local pos::Int

  @error "TODO: Defined in the runtime"
  return pos
end

function getFilename(file::Option{<:Integer})::String
  local fileName::String

  @error "TODO: Defined in the runtime"
  return fileName
end

"""Returns NULL (an opaque pointer; not actually Option<Integer>)"""
function noReference()::Option{Integer}
  local reference::Option{Integer}

  @error "TODO: Defined in the runtime"
  return reference
end

"""Returns an opaque pointer (not actually Option<Integer>)"""
function getReference(file::FileHandler)::Option{Integer}
  local reference::Option{Integer}

  @error "TODO: Defined in the runtime"
  return reference
end

function releaseReference(file::FileHandler)
  return @error "TODO: Defined in the runtime"
end

function writeSpace(file::FileHandler, n::Int)
  return for i = 1:n
    FileHandler.write(file, " ")
  end
end

module Examples

using MetaModelica
using ExportAll

module WriteToFile #= Should be a model here. Not widley used but apparently occurs =#

const file = FileHandler()::FileHandler

open(file, "abc.txt", Mode.Write)
write(file, "def.fafaf\\n")
writeEscape(file, "xx<def.\\\\nfaf>af\\n", escape = Escape.JSON)
end

@exportAll()
end

@exportAll()
end

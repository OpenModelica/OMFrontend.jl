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

module IOStreamExt

using MetaModelica
using ExportAll

function createFile(fileName::String)::Int
  local fileID::Int

  @error "TODO: Defined in the runtime"
  return fileID
end

function closeFile(fileID::Int)
  return @error "TODO: Defined in the runtime"
end

function deleteFile(fileID::Int)
  return @error "TODO: Defined in the runtime"
end

function clearFile(fileID::Int)
  return @error "TODO: Defined in the runtime"
end

function appendFile(fileID::Int, inString::String)
  return @error "TODO: Defined in the runtime"
end

function readFile(fileID::Int)::String
  local outString::String

  @error "TODO: Defined in the runtime"
  return outString
end

function printFile(fileID::Int, whereToPrint::Int) #= stdout:1, stderr:2 =#
  return @error "TODO: Defined in the runtime"
end

function createBuffer()::Int
  local bufferID::Int

  @error "TODO: Defined in the runtime"
  return bufferID
end

function appendBuffer(bufferID::Int, inString::String)
  return @error "TODO: Defined in the runtime"
end

function deleteBuffer(bufferID::Int)
  return @error "TODO: Defined in the runtime"
end

function clearBuffer(bufferID::Int)
  return @error "TODO: Defined in the runtime"
end

function readBuffer(bufferID::Int)::String
  local outString::String

  @error "TODO: Defined in the runtime"
  return outString
end

function printBuffer(bufferID::Int, whereToPrint::Int) #= stdout:1, stderr:2 =#
  return @error "TODO: Defined in the runtime"
end

"""
New implementation
@author johti17
"""
function appendReversedList(inStringLst::List{<:String})::String
  local lstAsArr::Vector{String} = reverse(listArray(inStringLst))
  local tmp::String = ""
  local outString::String = ""
  buffer = IOBuffer()
  map(lstAsArr) do x
    print(buffer, x)
  end
  outSting = String(take!(buffer))
end

function printReversedList(inStringLst::List{<:String}, whereToPrint::Int) #= stdout:1, stderr:2 =#
  return @error "TODO: Defined in the runtime"
end

@exportAll()
end

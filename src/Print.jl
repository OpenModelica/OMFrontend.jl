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

module Print

using MetaModelica
using ExportAll

"""saves and clears content of buffer and return a handle to the saved buffer so it can be restored by restorBuf later on"""
function saveAndClearBuf()::Int
  local handle::Int

  @error "TODO: Defined in the runtime"
  return handle
end

function restoreBuf(handle::Int)
  @error "TODO: Defined in the runtime"
end

function printErrorBuf(inString::String)
  @error "TODO: Defined in the runtime"
end

function clearErrorBuf()
  @error "TODO: Defined in the runtime"
end

function getErrorString()::String
  local outString::String

  @error "TODO: Defined in the runtime"
  return outString
end

function printBuf(inString::String)
  @error "TODO: Defined in the runtime"
end

function clearBuf()
  @error "TODO: Defined in the runtime"
end

"""Does not clear the buffer"""
function getString()::String
  local outString::String

  @error "TODO: Defined in the runtime"
  return outString
end

"""Writes the buffer to a file"""
function writeBuf(filename::String)
  @error "TODO: Defined in the runtime"
end

"""Writes the print buffer to the filename, with /*#modelicaLine...*/ directives converted to #line C preprocessor macros"""
function writeBufConvertLines(filename::String)
  @error "TODO: Defined in the runtime"
end

"""Gets the actual length of the filled space in the print buffer."""
function getBufLength()::Int
  local outBufFilledLength::Int

  @error "TODO: Defined in the runtime"
  return outBufFilledLength
end

"""Prints the given number of spaces to the print buffer."""
function printBufSpace(inNumOfSpaces::Int)
  @error "TODO: Defined in the runtime"
end

"""Prints one new line character to the print buffer."""
function printBufNewLine()
  @error "TODO: Defined in the runtime"
end

"""
  Tests if the last outputted character in the print buffer is a new line.
  It is a (temporary) workaround to stringLength()'s O(n) cost.
"""
function hasBufNewLineAtEnd()::Bool
  local outHasNewLineAtEnd::Bool

  @error "TODO: Defined in the runtime"
  return outHasNewLineAtEnd
end

@exportAll()
end

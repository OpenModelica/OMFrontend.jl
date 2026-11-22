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

module ModelicaExternalC

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll
import OMRuntimeExternalC

"""Streams / File functions delegate to ModelicaInternal C implementations"""
function Streams_print(string::String, fileName::String)
  OMRuntimeExternalC.ModelicaInternal_print(string, fileName)
end

function Streams_readLine(fileName::String, lineNumber::Int64)::Tuple{String, Bool}
  return OMRuntimeExternalC.ModelicaInternal_readLine(fileName, lineNumber)
end

function Streams_countLines(fileName::String)::Int64
  return OMRuntimeExternalC.ModelicaInternal_countLines(fileName)
end

function File_fullPathName(fileName::String)::String
  return OMRuntimeExternalC.ModelicaInternal_fullPathName(fileName)
end

function File_stat(name::String)::Int64
  return OMRuntimeExternalC.ModelicaInternal_stat(name)
end

function Streams_close(fileName::String)
  OMRuntimeExternalC.ModelicaStreams_closeFile(fileName)
end

"""String functions delegate to ModelicaStrings C implementations"""
function Strings_compare(string1::String, string2::String, caseSensitive::Bool)::Int64
  return OMRuntimeExternalC.ModelicaStrings_compare(string1, string2, Int64(caseSensitive))
end

function Strings_scanReal(
  string::String,
  startIndex::Int64,
  unsigned::Bool,
)::Tuple{Int64, Float64}
  return OMRuntimeExternalC.ModelicaStrings_scanReal(string, startIndex, Int64(unsigned))
end

function Strings_scanInteger(
  string::String,
  startIndex::Int64,
  unsigned::Bool,
)::Tuple{Int64, Int64}
  return OMRuntimeExternalC.ModelicaStrings_scanInteger(string, startIndex, Int64(unsigned))
end

function Strings_scanString(string::String, startIndex::Int64)::Tuple{Int64, String}
  return OMRuntimeExternalC.ModelicaStrings_scanString(string, startIndex)
end

function Strings_scanIdentifier(string::String, startIndex::Int64)::Tuple{Int64, String}
  return OMRuntimeExternalC.ModelicaStrings_scanIdentifier(string, startIndex)
end

function Strings_skipWhiteSpace(string::String, startIndex::Int64 = Int64(1))::Int64
  return OMRuntimeExternalC.ModelicaStrings_skipWhiteSpace(string, startIndex)
end

function Strings_hashString(string::String)::Int64
  return OMRuntimeExternalC.ModelicaStrings_hashString(string)
end

"""ModelicaIO functions delegate to OMRuntimeExternalC"""
function ModelicaIO_readMatrixSizes(fileName::String, matrixName::String)::Vector{Int64}
  return OMRuntimeExternalC.ModelicaIO_readMatrixSizes(fileName, matrixName)
end

function ModelicaIO_readRealMatrix(
  fileName::String,
  matrixName::String,
  nrow::Int64,
  ncol::Int64,
  verboseRead::Bool = true,
)::Matrix{Float64}
  return OMRuntimeExternalC.ModelicaIO_readRealMatrix(fileName, matrixName, nrow, ncol, verboseRead)
end

@exportAll()
end

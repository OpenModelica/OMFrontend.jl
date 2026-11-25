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

# The file and stream functions of the Modelica Standard Library (ModelicaInternal.c of MSL 4.1.0)
# in Julia, for constant evaluation: print, readLine, countLines, fullPathName, stat, closeFile.
# Author: John Tinnerholm

"""
    CachedLines

The lines of a file read by `Streams_readLine`, with the modification time and size they were read
at. The C code keeps the file open between calls for the same reason: a loop over the lines of a
file reads it once.
"""
struct CachedLines
  mtime::Float64
  size::Int64
  lines::Vector{String}
end

const LINE_CACHE = Dict{String, CachedLines}()
const LINE_CACHE_LOCK = ReentrantLock()

"""
    splitLines(content)::Vector{String}

The lines of `content` as the C code reads them: separated by `\\n` (a `\\r` stays in the line), a
last line without `\\n` counts, a `\\n` at the end starts no new line.
"""
function splitLines(content::String)::Vector{String}
  isempty(content) && return String[]
  local lines::Vector{String} = String[String(l) for l in split(content, '\n')]
  if endswith(content, '\n')
    pop!(lines)
  end
  return lines
end

"""
    fileLines(fileName)::Vector{String}

The lines of the file, from the cache when the file is unchanged.
"""
function fileLines(fileName::String)::Vector{String}
  isfile(fileName) || error("Not possible to open file \"$fileName\" for reading: No such file or directory")
  local info::Base.Filesystem.StatStruct = stat(fileName)
  lock(LINE_CACHE_LOCK)
  try
    local cached::CachedLines = get(LINE_CACHE, fileName, CachedLines(-1.0, -1, String[]))
    if cached.mtime == info.mtime && cached.size == Int64(info.size)
      return cached.lines
    end
    local lines::Vector{String} = splitLines(read(fileName, String))
    LINE_CACHE[fileName] = CachedLines(info.mtime, Int64(info.size), lines)
    return lines
  finally
    unlock(LINE_CACHE_LOCK)
  end
end

"""
    Streams_close(fileName)

Forget the cached lines of the file (ModelicaStreams_closeFile).
"""
function Streams_close(fileName::String)::Nothing
  lock(LINE_CACHE_LOCK)
  try
    delete!(LINE_CACHE, fileName)
  finally
    unlock(LINE_CACHE_LOCK)
  end
  return nothing
end

"""
    Streams_print(string, fileName)

Print `string` and a newline to standard output if `fileName` is empty, else append them to the file.
"""
function Streams_print(string::String, fileName::String)::Nothing
  if isempty(fileName)
    print(stdout, string, "\n")
  else
    Streams_close(fileName)
    local io::IOStream = open(fileName, "a")
    try
      print(io, string, "\n")
    finally
      close(io)
    end
  end
  return nothing
end

"""
    Streams_readLine(fileName, lineNumber)::Tuple{String, Bool}

Line `lineNumber` of the file without its `\\n`, and whether the end of the file was reached
(then the line is `""`).
"""
function Streams_readLine(fileName::String, lineNumber::Int64)::Tuple{String, Bool}
  local lines::Vector{String} = fileLines(fileName)
  lineNumber < 1 && return ("", false)
  lineNumber > length(lines) && return ("", true)
  return (lines[lineNumber], false)
end

"""
    Streams_countLines(fileName)::Int64

The number of lines of the file, counted as `Streams_readLine` reads them.
"""
function Streams_countLines(fileName::String)::Int64
  return Int64(length(fileLines(fileName)))
end

"""
    File_fullPathName(fileName)::String

The absolute name of the file with `/` as separator. An existing path is resolved (`realpath`, a
trailing `/` kept); another one is appended to the current directory unless it starts with `/`.
"""
function File_fullPathName(fileName::String)::String
  if Sys.iswindows()
    return replace(abspath(fileName), '\\' => '/')
  end
  if ispath(fileName)
    local full::String = realpath(fileName)
    return endswith(fileName, '/') && !endswith(full, '/') ? full * "/" : full
  end
  return startswith(fileName, '/') ? fileName : pwd() * "/" * fileName
end

"""
    File_stat(name)::Int64

The enumeration Modelica.Utilities.Types.FileType: 1 no file, 2 regular file, 3 directory,
4 special file (pipe, device, ...).
"""
function File_stat(name::String)::Int64
  ispath(name) || return Int64(1)
  isfile(name) && return Int64(2)
  isdir(name) && return Int64(3)
  return Int64(4)
end

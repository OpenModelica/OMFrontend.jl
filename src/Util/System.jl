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

module System

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll
import Printf
  #= Forward declarations for uniontypes until Julia adds support for mutual recursion =#
  const ForkFunction = Function


"""removes chars in charsToRemove from begin and end of inString"""
function trim(inString::String, charsToRemove::String = " \\f\\n\\r\\t\\v") ::String
  local outString::String

  @error "TODO: Defined in the runtime"
  outString
end

"""locates substring searchStr in str. If succeeds return position (starting from 0), otherwise return -1"""
function stringFind(str::String, searchStr::String) ::Int
  local outInteger::Int

  @error "TODO: Defined in the runtime"
  outInteger
end

"""
  Fails and sets Error.mo if the regex does not compile.

  The returned result is the same as POSIX regex():
  The first value is the complete matched string
  The rest are the substrings that you wanted.
  For example:
  regex(lorem,\\\" \\\\([A-Za-z]*\\\\) \\\\([A-Za-z]*\\\\) \\\",maxMatches=3)
  => {\\\" ipsum dolor \\\",\\\"ipsum\\\",\\\"dolor\\\"}
  This means if you have n groups, you want maxMatches=n+1
"""
function regex(str::String, re::String, maxMatches::Int #= The maximum number of matches that will be returned =#, extended::Bool = false #= Use POSIX extended or regular syntax =#, ignoreCase::Bool = false) ::Tuple{Integer, List{String}}
  local strs::List{String} #= This list has length = maxMatches. Substrings that did not match are filled with the empty string =#
  local numMatches::Int #= 0 means no match, else returns a number 1..maxMatches (1 if maxMatches<0) =#
  local pat::String = re
  if !extended
    #= POSIX basic syntax: \( \) delimit groups, bare parens are literal =#
    pat = replace(pat, "\\(" => "\x01", "\\)" => "\x02")
    pat = replace(pat, "(" => "\\(", ")" => "\\)")
    pat = replace(pat, "\x01" => "(", "\x02" => ")")
  end
  local m = match(Regex(pat, ignoreCase ? "i" : ""), str)
  local out = String[]
  numMatches = 0
  if m !== nothing
    push!(out, String(m.match))
    for c in m.captures
      push!(out, c === nothing ? "" : String(c))
    end
    numMatches = maxMatches < 0 ? 1 : min(length(out), maxMatches)
  end
  while length(out) < max(maxMatches, 0)
    push!(out, "")
  end
  maxMatches >= 0 && length(out) > maxMatches && (out = out[1:maxMatches])
  strs = list(out...)
  (numMatches #= 0 means no match, else returns a number 1..maxMatches (1 if maxMatches<0) =#, strs #= This list has length = maxMatches. Substrings that did not match are filled with the empty string =#)
end

function strncmp(inString1::String, inString2::String, len::Int) ::Int
  local outInteger::Int

  @error "TODO: Defined in the runtime"
  outInteger
end

function stringReplace(str::String, source::String, target::String) ::String
  return replace(str, source=>target)
end

""" Replaces unknown characters with _ """
function makeC89Identifier(str::String) ::String
  local res::String

  @error "TODO: internal function makeC89Identifier not defined in the runtime"
  res
end

function tolower(inString::String) ::String
  return Base.lowercase(inString)
end

#= Splits a string at any of the token's characters, empty pieces dropped (C strtok; omc's
   runtime System.strtok). =#
function strtok(string::String, token::String) ::List{String}
  local pieces = Base.split(string, Base.collect(token); keepempty = false)
  return list((String(p) for p in pieces)...)
end

function loadLibrary(inLib::String, inPrintDebug::Bool) ::Int
  local outLibHandle::Int

  @error "TODO: Defined in the runtime"
  outLibHandle
end

function lookupFunction(inLibHandle::Int, inFunc::String) ::Int
  local outFuncHandle::Int

  @error "TODO: Defined in the runtime"
  outFuncHandle
end

""" This function will write to the file given by first argument the given string """
function writeFile(fileNameToWrite::String #= a filename where to write the data =#, stringToBeWritten::String #= the data =#)
  write(fileNameToWrite, stringToBeWritten)
end

function appendFile(file::String, data::String)
  open(io -> write(io, data), file, "a")
  nothing
end

"""Does not fail. Returns strings describing the error instead."""
function readFile(inString::String) ::String
  local outString::String

  @error "TODO: Defined in the runtime"
  outString
end

function systemCall(command::String, outFile::String = "" #= empty file means no redirection unless it is part of the command =#) ::Int
  local outInteger::Int

  @error "TODO: Defined in the runtime"
  outInteger
end

function cd(inString::String) ::Int
  local outInteger::Int

  @error "TODO: Defined in the runtime"
  outInteger
end

function createDirectory(inString::String) ::Bool
  local outBool::Bool

  @error "TODO: Defined in the runtime"
  outBool
end

function pwd() ::String
  local outString::String

  @error "TODO: Defined in the runtime"
  outString
end

function time() ::AbstractFloat
  local outReal::AbstractFloat

  @error "TODO: Defined in the runtime"
  outReal
end

function directoryExists(inString::String) ::Bool
  local outBool::Bool

  @error "TODO: Defined in the runtime"
  outBool
end

"""
  @author Frenkel TUD
  this system function returns current time elapsed
  since the Epoch (00:00:00 UTC, January 1, 1970).
"""
function getCurrentDateTime() ::Tuple{Integer, Integer, Integer, Integer, Integer, Integer}
  local year::Int
  local mon::Int
  local mday::Int
  local hour::Int
  local min::Int
  local sec::Int

  @error "TODO: Defined in the runtime"
  (sec, min, hour, mday, mon, year)
end

#= TODO temporary structure introduced by Adrian=#
global GLOBAL_MEMORY = Vector{Any}(missing, 1024)
#= I put it as a constant for now! - John =#
"""
  @author: adrpo
  sets the external flag that signals the
  presence of expandable connectors in a model
"""
function setHasExpandableConnectors(hasExpandable::Bool)
  GLOBAL_MEMORY[1] = hasExpandable
end

"""
  @author: adrpo
  sets the external flag that signals the
  presence of overconstrained connectors in a model
"""
function setHasOverconstrainedConnectors(hasOverconstrained::Bool)
  GLOBAL_MEMORY[2] = hasOverconstrained
end

"""
  @author: adrpo
  retrieves the external flag that signals the
  presence of overconstrained connectors in a model
"""
function getHasOverconstrainedConnectors() ::Bool
  local hasOverconstrained::Bool = GLOBAL_MEMORY[2]
  hasOverconstrained
end

"""
  @author: adrpo
  sets the external flag that signals the
  presence of stream connectors in a model
"""
function setHasStreamConnectors(hasStream::Bool)
  GLOBAL_MEMORY[4] = hasStream
end

"""
  @author: adrpo
  retrieves the external flag that signals the
  presence of stream connectors in a model
"""
function getHasStreamConnectors() ::Bool
  local hasStream::Bool = GLOBAL_MEMORY[4]
  hasStream
end

"""Sets the external flag that signals the use of the cardinality operator."""
function setUsesCardinality(inUses::Bool)
  GLOBAL_MEMORY[5] = inUses
end

"""Retrieves the external flag that signals the use of the cardinality operator."""
function getUsesCardinality() ::Bool
  local outUses::Bool = GLOBAL_MEMORY[5]
  outUses
end

"""
  @author: adrpo
  sets the external flag that signals the presence
  of inner/outer comoponent definitions in a model
"""
function setHasInnerOuterDefinitions(hasInnerOuterDefinitions::Bool)
  GLOBAL_MEMORY[6] = hasInnerOuterDefinitions
end

"""Sets the flag that signals use of Connections.rooted/isRoot/uniqueRootIndices."""
function setUsesConnectionsOperators(inUses::Bool)
  GLOBAL_MEMORY[7] = inUses
end

"""Retrieves the flag that signals use of Connections.rooted/isRoot/uniqueRootIndices."""
function getUsesConnectionsOperators()::Bool
  local outUses::Bool = GLOBAL_MEMORY[7]
  outUses
end

"""
Returns a tick that can be reset.
"""
function tmpTickIndex(index::Int)::Int
  local tickNo::Int = getGlobalRoot(index)
  setGlobalRoot(index, tickNo + 1)
  return tickNo
end

"""
  Tock returns the time since the last tock; undefined if tick was never called.
  The clock index is 0-31. The function fails if the number is out of range.
"""
const _REALTIME_CLOCKS = Dict{Int, UInt64}()

"""
  Returns the name of the file without any leading directory path.
  See man 3 basename.
"""
function basename(filename::String) ::String
  local base::String

  @error "TODO: Defined in the runtime"
  base
end

"""
  Returns the name of the file without any leading directory path.
  See man 3 dirname.
"""
function dirname(filename::String) ::String
  local base::String

  @error "TODO: Defined in the runtime"
  base
end

"""
  Because list() requires escape-sequences to be in the AST, we need to be
  able to unescape them in some places of the code.
"""
function escapedString(unescapedString::String, unescapeNewline::Bool) ::String
  local escapedString::String

  @error "TODO: Defined in the runtime"
  escapedString
end

"""
  Because list() requires escape-sequences to be in the AST, we need to be
  able to unescape them in some places of the code.
"""
function unescapedString(escapedString::String) ::String
  local unescapedString::String = escapedString
  unescapedString
end

"""Returns the maximum integer that can be represent using this version of the compiler"""
#= As omc's runtime (meta_modelica_builtin.c): LONG_MAX / 2. =#
intMaxLit()::Int = typemax(Int) ÷ 2

"""Returns the maximum real that can be represent using this version of the compiler"""
#= As omc's runtime: DBL_MAX / 2048, in case a solver adds eps to it. =#
realMaxLit()::Float64 = floatmax(Float64) / 2048

"""
  # dgesv from LAPACK

  ## Purpose
  DGESV computes the solution to a real system of linear equations
  A * X = B,
  where A is an N-by-N matrix and X and B are N-by-NRHS matrices.

  The LU decomposition with partial pivoting and row interchanges is
  used to factor A as
  A = P * L * U,
  where P is a permutation matrix, L is unit lower triangular, and U is
  upper triangular. The factored form of A is then used to solve the
  system of equations A * X = B.

  ## Return values
  ### output list<Real> X
  On exit, if info = 0, the N-by-NRHS solution matrix X.

  ### output Integer info
  = 0:  successful exit
  < 0:  if INFO = -i, the i-th argument had an illegal value
  > 0:  if INFO = i, U(i,i) is exactly zero. The factorization
  has been completed, but the factor U is exactly
  singular, so the solution could not be computed.
"""
function dgesv(A::List, B::List)
  local n = listLength(B)
  local M = Base.Matrix{Float64}(undef, n, n + 1)
  local i = 0
  for row in A
    i += 1
    local j = 0
    for a in row
      j += 1
      M[i, j] = Float64(a)
    end
  end
  i = 0
  for b in B
    i += 1
    M[i, n + 1] = Float64(b)
  end
  # Gaussian elimination with partial pivoting; info = k on a singular pivot.
  for k in 1:n
    local piv = k
    for r in (k + 1):n
      abs(M[r, k]) > abs(M[piv, k]) && (piv = r)
    end
    if abs(M[piv, k]) < 1e-300
      local zeros_list = nil
      for _ in 1:n
        zeros_list = cons(0.0, zeros_list)
      end
      return (zeros_list, k)
    end
    if piv != k
      for c in k:(n + 1)
        M[k, c], M[piv, c] = M[piv, c], M[k, c]
      end
    end
    for r in (k + 1):n
      local f = M[r, k] / M[k, k]
      for c in k:(n + 1)
        M[r, c] -= f * M[k, c]
      end
    end
  end
  local Xvec = Base.Vector{Float64}(undef, n)
  for k in n:-1:1
    local acc = M[k, n + 1]
    for c in (k + 1):n
      acc -= M[k, c] * Xvec[c]
    end
    Xvec[k] = acc / M[k, k]
  end
  local X = nil
  for k in n:-1:1
    X = cons(Xvec[k], X)
  end
  return (X, 0)
end

"""
  The iconv() function converts one multibyte characters from one character
  set to another.
  See man (3) iconv for more information.
"""
function iconv(string::String, from::String, to::String) ::String
  local result::String

  @error "TODO: Defined in the runtime"
  result
end

#= /* Print errors */ =#

"""
  sprintf format string that takes one double as argument, but unlike snprintff
  it takes no buffer size as argument.

  NOTE: This function doesn't actually call sprintf, since that would be unsafe.
  It instead calls snprintf with a fixed buffer size that should be enough
  for most cases, and if that fails it resizes the buffer to the size
  snprintf said it needed and calls snprintf again.
"""
function sprintff(format::String, val::AbstractFloat) ::String
  #= Julia's Printf, not C's snprintf: Windows exports no snprintf symbol (the
     Universal CRT defines it inline), so the call failed there (String() of a
     constant, 2026-10-02); and snprintf is variadic, which a plain ccall got
     wrong on Apple arm64 before. Printf takes the same C conversions: flags,
     width, precision; f, e, E, g, G. =#
  return Printf.format(Printf.Format(format), Float64(val))
end

"""Choose a locale for subsequent gettext calls. Prints warnings on failures."""
function gettextInit(locale::String = "" #= Empty string choses automatically from the environment =#)
  @error "TODO: Defined in the runtime"
end

"""Translate a string from msgid to msgstr using the language of the chosen locale"""
function gettext(msgid::String) ::String
  local msgstr::String = msgid
  @error "TODO: gettext Defined in the runtime"
  return msgstr
end

function realpath(path::String) ::String
  local fullpath::String

  @error "TODO: Defined in the runtime"
  fullpath
end

function getSimulationHelpText(detailed::Bool = false, sphinx::Bool = false) ::String
  local text::String

  @error "TODO: Defined in the runtime"
  text
end

function getTerminalWidth() ::Int
  local width::Int

  @error "TODO: Defined in the runtime"
  width
end

function rename(source::String, dest::String) ::Bool
  local result::Bool

  @error "TODO: Defined in the runtime"
  result
end

"""Exits the compiler at this point with the given exit status."""
function exit(status::Int)
  @error "TODO: Defined in the runtime"
end

function stat(filename::String) ::Tuple{Bool, AbstractFloat, AbstractFloat}
  local st_mtime::AbstractFloat
  local st_size::AbstractFloat
  local success::Bool

  @error "TODO: Defined in the runtime"
  (success, st_size, st_mtime)
end

function alarm(seconds::Int) ::Int
  local previousAlarm::Int

  @error "TODO: Defined in the runtime"
  previousAlarm
end

function dladdr(symbol::T #= Function pointer =#)  where {T}
  local name::String = string(symbol)
  local file::String = "julia"
  local info::String = file + ": " + name
  (info, file, name)
end


function updateUriMapping(namesAndDirs::Array{<:String})
  @error "TODO: Defined in the runtime"
end

# Pure-Julia stand-in for OMC's C-backed StringAllocator: a string builder over an IOBuffer.
# The dumpers use it only to assemble a String. `destOffset` is accepted for signature
# compatibility but ignored; every caller writes sequentially with cumulative offsets.
mutable struct StringAllocator
  io::IOBuffer
end

StringAllocator(::Int = 0) = StringAllocator(IOBuffer())

function stringAllocatorStringCopy(dest::StringAllocator, source::AbstractString, destOffset::Int = 0)
  write(dest.io, source)
  return dest
end

stringAllocatorResult(sa::StringAllocator, @nospecialize(_template = "")) = String(take!(sa.io))

@exportAll()
end

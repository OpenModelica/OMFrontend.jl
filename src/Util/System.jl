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

"""C's strncmp: the order of the first `n` bytes of `s1` and `s2`, negative, 0 or positive."""
function strncmp(s1::String, s2::String, n::Int)::Int
  return cmp(view(codeunits(s1), 1:min(n, ncodeunits(s1))), view(codeunits(s2), 1:min(n, ncodeunits(s2))))
end

function stringReplace(str::String, source::String, target::String) ::String
  return replace(str, source=>target)
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
  Because list() requires escape-sequences to be in the AST, we need to be
  able to unescape them in some places of the code.
"""
function unescapedString(escapedString::String) ::String
  local unescapedString::String = escapedString
  unescapedString
end

"""
Returns the maximum integer that can be represent using this version of the compiler

As omc's runtime (meta_modelica_builtin.c): LONG_MAX / 2.
"""
intMaxLit()::Int = typemax(Int) ÷ 2

"""
Returns the maximum real that can be represent using this version of the compiler

As omc's runtime: DBL_MAX / 2048, in case a solver adds eps to it.
"""
realMaxLit()::Float64 = floatmax(Float64) / 2048

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

# Pure-Julia stand-in for OMC's C-backed StringAllocator: a string builder over an IOBuffer.
# The dumpers use it only to assemble a String. `destOffset` is accepted for signature
# compatibility but ignored; every caller writes sequentially with cumulative offsets.
mutable struct StringAllocator
  io::IOBuffer
end

StringAllocator(::Int = 0) = StringAllocator(IOBuffer())

function stringAllocatorStringCopy(dest::StringAllocator, source::AbstractString, ::Int = 0)
  write(dest.io, source)
  return dest
end

stringAllocatorResult(sa::StringAllocator, @nospecialize(_template = "")) = String(take!(sa.io))

@exportAll()
end

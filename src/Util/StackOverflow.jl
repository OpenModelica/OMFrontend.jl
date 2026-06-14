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

module StackOverflow

using MetaModelica
using ExportAll

import Frontend.System
import Frontend.Testsuite

function unmangle(inSymbol::String)::String
  local outSymbol::String

  @assign outSymbol = inSymbol
  if stringLength(inSymbol) > 4
    if substring(inSymbol, 1, 4) == "omc_"
      @assign outSymbol = substring(outSymbol, 5, stringLength(outSymbol))
      @assign outSymbol = System.stringReplace(outSymbol, "__", "#")
      @assign outSymbol = System.stringReplace(outSymbol, "_", ".")
      @assign outSymbol = System.stringReplace(outSymbol, "#", "_")
    end
  end
  return outSymbol
end

function stripAddresses(inSymbol::String)::String
  local outSymbol::String

  local n::Int
  local strs::List{String}
  local so::String
  local fun::String

  #=  regex for Linux messages
  =#
  @assign (n, strs) = System.regex(
    inSymbol,
    "^([^(]*)[(]([^+]*[^+]*)[+][^)]*[)] *[[]0x[0-9a-fA-F]*[]]",
    3,
    extended = true,
  )
  if n == 3
    @match list(_, so, fun) = strs
    @assign outSymbol = so + "(" + unmangle(fun) + ")"
  else
    @assign (n, strs) = System.regex(
      inSymbol,
      "^[0-9 ]*([A-Za-z0-9.]*) *0x[0-9a-fA-F]* ([A-Za-z0-9_]*) *[+] *[0-9]*",
      3,
      extended = true,
    )
    if n == 3
      @match list(_, so, fun) = strs
      @assign outSymbol = so + "(" + unmangle(fun) + ")"
    else
      @assign outSymbol = inSymbol
    end
  end
  #=  regex for OSX messages
  =#
  return outSymbol
end

function triggerStackOverflow()
  return @error "TODO: Defined in the runtime"
end

function generateReadableMessage(
  numFrames::Int = 1000,
  numSkip::Int = 4,
  delimiter::String = "\\n",
)::String
  local str::String

  StackOverflow.setStacktraceMessages(numSkip, numFrames)
  @assign str = getReadableMessage(delimiter = delimiter)
  return str
end

function getReadableMessage(delimiter::String = "\\n")::String
  local str::String

  @assign str = stringDelimitList(StackOverflow.readableStacktraceMessages(), delimiter)
  return str
end

function readableStacktraceMessages()::List{String}
  local symbols::List{String} = nil

  local prev::String = ""
  local n::Int = 1
  local prevN::Int = 1

  if Testsuite.isRunning()
    @assign symbols = list("[bt] [Symbols are not generated when running the test suite]")
    return symbols
  end
  for symbol in list(stripAddresses(s) for s in getStacktraceMessages())
    if prev == ""
    elseif symbol != prev
      @assign symbols = _cons("[bt] #" + String(prevN) + (
        if n != prevN
          "..." + String(n)
        else
          ""
        end
      ) + " " + prev, symbols)
      @assign n = n + 1
      @assign prevN = n
    else
      @assign n = n + 1
    end
    @assign prev = symbol
  end
  @assign symbols = _cons("[bt] #" + String(prevN) + (
    if n != prevN
      "..." + String(n)
    else
      ""
    end
  ) + " " + prev, symbols)
  @assign symbols = listReverse(symbols)
  return symbols
end

function getStacktraceMessages()::List{String}
  local symbols::List{String}

  @error "TODO: Defined in the runtime"
  return symbols
end

function setStacktraceMessages(numSkip::Int, numFrames::Int)
  return @error "TODO: Defined in the runtime"
end

function hasStacktraceMessages()::Bool
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function clearStacktraceMessages()
  return @error "TODO: Defined in the runtime"
end

@exportAll()
end

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

module StringUtil

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll

import ..System

using MetaModelica.Dangerous: listReverseInPlace, stringGetNoBoundsChecking

const NO_POS = 0::Int
const CHAR_NEWLINE = 10::Int
const CHAR_SPACE = 32::Int
const CHAR_DASH = 45::Int
const CHAR_DOT = 46::Int

"""
  Searches backwards for a given character in the given string, returning the
  index of the character if found. If not found returns NO_POS. The start and
  end position determines the section of the string to search in, and if not
  specified they are set to the start and end of the string.
"""
function rfindChar(
  inString::String,
  inChar::Int,
  inStartPos::Int = 0,
  inEndPos::Int = 1,
)::Int
  local outIndex::Int = NO_POS

  local len::Int = stringLength(inString)
  local start_pos::Int
  local end_pos::Int

  @assign start_pos = if inStartPos > 0
    min(inStartPos, len)
  else
    len
  end
  @assign end_pos = max(inEndPos, 1)
  for i = start_pos:(-1):end_pos
    if stringGetNoBoundsChecking(inString, i) == inChar
      @assign outIndex = i
      break
    end
  end
  return outIndex
end

"""
  Returns true if the given character represented by it's ASCII decimal number
  is an alphabetic character.
"""
function isAlpha(inChar::Int)::Bool
  local outIsAlpha::Bool = inChar >= 65 && inChar <= 90 || inChar >= 97 && inChar <= 122
  return outIsAlpha
end

"""
  Breaks the given string into lines which are no longer than the given wrap
  length. The function tries to break lines at word boundaries, i.e. at spaces,
  so that words are not split. It also wraps the string at any newline
  characters it finds. The function also takes two optional parameters to set
  the delimiter and raggedness.

  inDelimiter sets the delimiter which is prefixed to all lines except for the
  first one. The length of this delimiter is taken into account when wrapping
  the string, so it must be shorter than the wrap length. Otherwise the string
  will be returned unwrapped. The default is an empty string.

  inRaggedness determines the allowed raggedness of the lines, given as a ratio
  between 0 and 1. A raggedness of e.g. 0.2 means that each segment may be at
  most 20% smaller than the max line length. If a line would be shorter than
  this, due to a long word, then the function instead hyphenates the last word.
  This is not done according to any grammatical rules, the words are just
  broken so that the line is as long as allowed. The default is 0.3.

  This function operates on ASCII strings, and does not handle UTF-8 strings
  correctly.
"""
function wordWrap(
  inString::String,
  inWrapLength::Int,
  inDelimiter::String = "",
  inRaggedness::AbstractFloat = 0.3,
)::List{String}
  local outStrings::List{String} = nil

  local start_pos::Int = 1
  local end_pos::Int = inWrapLength
  local line_len::Int
  local pos::Int
  local next_char::Int
  local char::Int
  local gap_size::Int
  local str::String
  local delim::String = ""
  local lines::List{String}

  #= Check that the wrap length is larger than the delimiter, otherwise just
     return the string as it is. =#
  if stringLength(inDelimiter) >= inWrapLength - 1
    @assign outStrings = list(inString)
    return outStrings
  end
  #= Split the string at newlines. =#
  @assign lines = System.strtok(inString, "\\n")
  #= Calculate the length of each line, excluding the delimiter. =#
  @assign line_len = inWrapLength - stringLength(inDelimiter) - 1
  #= The gap size is how many characters a line may be shorter than the sought
     after line length. =#
  @assign gap_size = max(realInt(realMul(line_len, inRaggedness)), 0)
  #= Wrap each line separately. =#
  for line in lines
    while end_pos < stringLength(line)
      @assign next_char = stringGetNoBoundsChecking(line, end_pos + 1)
      if next_char != CHAR_SPACE && next_char != CHAR_DASH
        @assign pos = rfindChar(line, CHAR_SPACE, end_pos, end_pos - gap_size)
        if pos != NO_POS
          @assign str = substring(line, start_pos, pos - 1)
          @assign start_pos = pos + 1
        else
          @assign pos = rfindChar(line, CHAR_DASH, end_pos, start_pos + gap_size)
          if pos > 1
            @assign char = stringGetNoBoundsChecking(line, pos - 1)
            @assign pos = if isAlpha(char) && isAlpha(next_char)
              pos
            else
              NO_POS
            end
          end
          if pos != NO_POS
            @assign str = substring(line, start_pos, pos)
            @assign start_pos = pos + 1
          else
            @assign str = substring(line, start_pos, end_pos - 1) + "-"
            @assign start_pos = end_pos
          end
        end
      else
        @assign str = substring(line, start_pos, end_pos)
        @assign start_pos = end_pos + (
          if next_char == CHAR_SPACE
            2
          else
            1
          end
        )
      end
      @assign outStrings = _cons(delim + str, outStrings)
      @assign end_pos = start_pos + line_len
      @assign delim = inDelimiter
    end
    if start_pos < stringLength(line)
      @assign str = delim + substring(line, start_pos, stringLength(line))
      @assign outStrings = _cons(str, outStrings)
    end
    @assign start_pos = 1
    @assign end_pos = line_len
    @assign delim = inDelimiter
  end
  #= If the next character isn't a space or dash, search backwards for a space.
     A space was found, break the string here.
     No space was found, search for a dash instead.
     A dash was found, check that the previous character is alphabetic.
     A dash was found, break the string here.
     No dash was found, break the word and hyphenate it.
     The next character is a space or dash, split the string here.
     Skip the space.
     Add the string to the list and continue with the rest of the line.
     Add any remainder of the line to the list.
     Continue with the next line. =#
  @assign outStrings = listReverseInPlace(outStrings)
  return outStrings
end

"""Repeat str n times"""
function repeat(str::String, n::Int)::String
  local res::String = ""

  local len::Int = stringLength(str)
  local ext::System.StringAllocator = System.StringAllocator(len * n)

  for i = 0:(n - 1)
    System.stringAllocatorStringCopy(ext, str, len * i)
  end
  @assign res = System.stringAllocatorResult(ext, res)
  return res
end

@exportAll()
end

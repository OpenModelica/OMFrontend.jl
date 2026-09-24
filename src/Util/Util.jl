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

module Util

import ..Global
import ..System

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

@UniontypeDecl Status
@UniontypeDecl DateTime

const FuncType = Function
const CompareFunc = Function
const FuncT = Function

#= Used to signal success or failure of a function call =#
@Uniontype Status begin
  @Record SUCCESS begin
  end
  @Record FAILURE begin
  end
end

@Uniontype DateTime begin
  @Record DATETIME begin

    sec::Int
    min::Int
    hour::Int
    mday::Int
    mon::Int
    year::Int
  end
end

import ListUtil

const dummyInfo = SOURCEINFO("", false, 0, 0, 0, 0, 0.0)::SourceInfo

const derivativeNamePrefix = "DER"::String

"""Author: BZ"""
function isIntGreater(lhs::Int, rhs::Int)::Bool
  local b::Bool = lhs > rhs
  return b
end

"""Author: BZ"""
function isRealGreater(lhs::AbstractFloat, rhs::AbstractFloat)::Bool
  local b::Bool = lhs > rhs
  return b
end

"""If operating system is Linux/Unix, return a './', otherwise return empty string"""
function linuxDotSlash()::String
  local str::String

   str = Autoconf.os
   str = if str == "linux" || str == "OSX"
    "./"
  else
    ""
  end
  return str
end

"""
  author: x02lucpo
  Extracts the flagvalue from an argument list:
  flagValue('-s',{'-d','hej','-s','file'}) => 'file'
"""
function flagValue(flag::String, arguments::List{<:String})::String
  local flagVal::String

  local arg::String
  local rest::List{String} = arguments

  while !listEmpty(rest)
    @match _cons(arg, rest) = rest
    if arg == flag
      break
    end
  end
   flagVal = if listEmpty(rest)
    ""
  else
    listHead(rest)
  end
  return flagVal
end

"""
  Selects the first non-empty string from a list of strings.
  Returns an empty string if no such string exists.
"""
function selectFirstNonEmptyString(inStrings::List{<:String})::String
  local outResult::String

  for e in inStrings
    if e != ""
       outResult = e
      return outResult
    end
  end
   outResult = ""
  return outResult
end

"""
  Function could used with List.sort to sort a
  List as list< tuple<Integer, Type_a> > by first argument.
"""
function compareTupleIntGt(inTplA::Tuple, inTplB::Tuple)
  local res::Bool

  local a::Int
  local b::Int

   (a, _) = inTplA
   (b, _) = inTplB
   res = intGt(a, b)
  return res
end

"""
  Function could used with List.sort to sort a
  List as list< tuple<Integer, Type_a> > by first argument.
"""
function compareTupleIntLt(inTplA::Tuple, inTplB::Tuple)
  local res::Bool

  local a::Int
  local b::Int

   (a, _) = inTplA
   (b, _) = inTplB
   res = intLt(a, b)
  return res
end

"""
  Function could used with List.sort to sort a
  List as list< tuple<Type_a,Integer> > by second argument.
"""
function compareTuple2IntGt(inTplA::Tuple{T, Integer}, inTplB::Tuple{T, Integer}) where {T}
  local res::Bool

  local a::Int
  local b::Int

   (_, a) = inTplA
   (_, b) = inTplB
   res = intGt(a, b)
  return res
end

"""
  Function could used with List.sort to sort a
  List as list< tuple<Type_a,Integer> > by second argument.
"""
function compareTuple2IntLt(inTplA::Tuple{T, Integer}, inTplB::Tuple{T, Integer}) where {T}
  local res::Bool

  local a::Int
  local b::Int

   (_, a) = inTplA
   (_, b) = inTplB
   res = intLt(a, b)
  return res
end

"""
  Takes a tuple of two values and returns the first value.
  Example: tuple21(('a', 1)) => 'a'
"""
function tuple21(inTuple::Tuple{T1, T2}) where {T1, T2}
  local outValue::T1

   (outValue, _) = inTuple
  return outValue
end

"""
  Takes a tuple of two values and returns the second value.
  Example: tuple22(('a',1)) => 1
"""
function tuple22(inTuple::Tuple{T1, T2}) where {T1, T2}
  local outValue::T2

   (_, outValue) = inTuple
  return outValue
end

"""
  Takes an option tuple of two values and returns the second value.
  Example: optTuple22(SOME('a',1)) => 1
"""
function optTuple22(inTuple::Option{Tuple{T1, T2}}) where {T1, T2}
  local outValue::T2

  @match SOME((_, outValue)) = inTuple
  return outValue
end

"""
  Takes a tuple of three values and returns the tuple of the two first values.
  Example: tuple312(('a',1,2)) => ('a',1)
"""
function tuple312(inTuple::Tuple{T1, T2, T3}) where {T1, T2, T3}
  local outTuple::Tuple{T1, T2}

  local e1::T1
  local e2::T2

   (e1, e2, _) = inTuple
   outTuple = (e1, e2)
  return outTuple
end

"""
  Takes a tuple of three values and returns the first value.
  Example: tuple31(('a',1,2)) => 'a'
"""
function tuple31(inValue::Tuple{T1, T2, T3}) where {T1, T2, T3}
  local outValue::T1

   (outValue, _, _) = inValue
  return outValue
end

"""
  Takes a tuple of three values and returns the second value.
  Example: tuple32(('a',1,2)) => 1
"""
function tuple32(inValue::Tuple{T1, T2, T3}) where {T1, T2, T3}
  local outValue::T2

   (_, outValue, _) = inValue
  return outValue
end

"""
  Takes a tuple of three values and returns the first value.
  Example: tuple33(('a',1,2)) => 2
"""
function tuple33(inValue::Tuple{T1, T2, T3}) where {T1, T2, T3}
  local outValue::T3

   (_, _, outValue) = inValue
  return outValue
end

function tuple41(inTuple::Tuple{T1, T2, T3, T4}) where {T1, T2, T3, T4}
  local outValue::T1

   (outValue, _, _, _) = inTuple
  return outValue
end

function tuple42(inTuple::Tuple{T1, T2, T3, T4}) where {T1, T2, T3, T4}
  local outValue::T2

   (_, outValue, _, _) = inTuple
  return outValue
end

function tuple43(inTuple::Tuple{T1, T2, T3, T4}) where {T1, T2, T3, T4}
  local outValue::T3

   (_, _, outValue, _) = inTuple
  return outValue
end

function tuple44(inTuple::Tuple{T1, T2, T3, T4}) where {T1, T2, T3, T4}
  local outValue::T4

   (_, _, _, outValue) = inTuple
  return outValue
end

function tuple51(inTuple::Tuple{T1, T2, T3, T4, T5}) where {T1, T2, T3, T4, T5}
  local outValue::T1

   (outValue, _, _, _, _) = inTuple
  return outValue
end

function tuple52(inTuple::Tuple{T1, T2, T3, T4, T5}) where {T1, T2, T3, T4, T5}
  local outValue::T2

   (_, outValue, _, _, _) = inTuple
  return outValue
end

function tuple53(inTuple::Tuple{T1, T2, T3, T4, T5}) where {T1, T2, T3, T4, T5}
  local outValue::T3

   (_, _, outValue, _, _) = inTuple
  return outValue
end

function tuple54(inTuple::Tuple{T1, T2, T3, T4, T5}) where {T1, T2, T3, T4, T5}
  local outValue::T4

   (_, _, _, outValue, _) = inTuple
  return outValue
end

function tuple55(inTuple::Tuple{T1, T2, T3, T4, T5}) where {T1, T2, T3, T4, T5}
  local outValue::T5

   (_, _, _, _, outValue) = inTuple
  return outValue
end

function tuple61(inTuple::Tuple{T1, T2, T3, T4, T5, T6}) where {T1, T2, T3, T4, T5, T6}
  local outValue::T1

   (outValue, _, _, _, _, _) = inTuple
  return outValue
end

function tuple62(inTuple::Tuple{T1, T2, T3, T4, T5, T6}) where {T1, T2, T3, T4, T5, T6}
  local outValue::T2

   (_, outValue, _, _, _, _) = inTuple
  return outValue
end

"""Returns true if a string contains a specified character"""
function stringContainsChar(str::String, char::String)::Bool
  local res::Bool

   res = begin
    @matchcontinue () begin
      () => begin
        @match _cons(_, _cons(_, _)) = stringSplitAtChar(str, char)
        true
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""
  Author: BZ, 2009-11
  Same functionality as stringDelimitListPrint, but writes to print buffer instead of string variable.
  Usefull for heavy string operations(causes malloc error on some models when generating init file).
"""
function stringDelimitListPrintBuf(inStringLst::List{<:String}, inDelimiter::String)
  return  _ = begin
    local f::String
    local delim::String
    local str1::String
    local str2::String
    local str::String
    local r::List{String}
    @matchcontinue inStringLst begin
      nil() => begin
        ()
      end

      f <| nil() => begin
        Print.printBuf(f)
        ()
      end

      f <| r => begin
        stringDelimitListPrintBuf(r, inDelimiter)
        Print.printBuf(f)
        Print.printBuf(inDelimiter)
        ()
      end
    end
  end
end

"""Like print. However, adds a linebreak to the output."""
function println(str::String)
  return print(str + "\\n")
end

"""
  author: PA
  This function is similar to stringDelimitList, i.e it inserts string delimiters between
  consecutive strings in a list. But it also count the lists and inserts a second string delimiter
  when the counter is reached. This can be used when for instance outputting large lists of values
  and a newline is needed after ten or so items.
"""
function stringDelimitListAndSeparate(
  str::List{<:String},
  sep1::String,
  sep2::String,
  n::Int,
)::String
  local res::String

  local handle::Int

   handle = Print.saveAndClearBuf()
  stringDelimitListAndSeparate2(str, sep1, sep2, n, 0)
   res = Print.getString()
  Print.restoreBuf(handle)
  return res
end

"""
  author: PA
  Helper function to stringDelimitListAndSeparate
"""
function stringDelimitListAndSeparate2(
  inStringLst1::List{<:String},
  inString2::String,
  inString3::String,
  inInteger4::Int,
  inInteger5::Int,
)
  return  _ = begin
    local s::String
    local str1::String
    local str::String
    local f::String
    local sep1::String
    local sep2::String
    local r::List{String}
    local n::Int
    local iter_1::Int
    local iter::Int
    @matchcontinue (inStringLst1, inString2, inString3, inInteger4, inInteger5) begin
      (nil(), _, _, _, _) => begin
        ()
      end

      (s <| nil(), _, _, _, _) => begin
        Print.printBuf(s)
        ()
      end

      (f <| r, sep1, sep2, n, 0) => begin
        Print.printBuf(f)
        Print.printBuf(sep1)
        stringDelimitListAndSeparate2(r, sep1, sep2, n, 1) #= special case for first element =#
        ()
      end

      (f <| r, sep1, sep2, n, iter) => begin
        @match 0 = intMod(iter, n) #= insert second delimiter =#
         iter_1 = iter + 1
        Print.printBuf(f)
        Print.printBuf(sep1)
        Print.printBuf(sep2)
        stringDelimitListAndSeparate2(r, sep1, sep2, n, iter_1)
        ()
      end

      (f <| r, sep1, sep2, n, iter) => begin
         iter_1 = iter + 1 #= not inserting second delimiter =#
        Print.printBuf(f)
        Print.printBuf(sep1)
        stringDelimitListAndSeparate2(r, sep1, sep2, n, iter_1)
        ()
      end

      _ => begin
        print("- stringDelimitListAndSeparate2 failed\\n")
        fail()
      end
    end
  end
  #= /* iterator */ =#
end

"""
  the string delimiter inserted between those elements that are not empty.
  Example: stringDelimitListNonEmptyElts({\\\"x\\\",\\\"\\\",\\\"z\\\"}, \\\", \\\") => \\\"x, z\\\"
"""
function stringDelimitListNonEmptyElts(lst::List{<:String}, delim::String)::String
  local str::String

  local lst1::List{String}

   lst1 = ListUtil.select(lst, isNotEmptyString)
   str = stringDelimitList(lst1, delim)
  return str
end

"""splits the input string at the delimiter string in list of strings and converts to integer list which is then summarized"""
function mulStringDelimit2Int(inString::String, delim::String)::Int
  local i::Int

  local lst::List{String}
  local lst2::List{Integer}

   lst = stringSplitAtChar(inString, delim)
   lst2 = ListUtil.map(lst, stringInt)
  if !listEmpty(lst2)
     i = ListUtil.fold(lst2, intMul, 1)
  else
     i = 0
  end
  return i
end

"""
  Takes a string and two chars and replaces the first char with the second char:
  Example: string_replace_char(\\\"hej.b.c\\\",\\\".\\\",\\\"_\\\") => \\\"hej_b_c\\\"
  2007-11-26 BZ: Now it is possible to replace chars with emptychar, and
  replace a char with a string
  Example: string_replace_char(\\\"hej.b.c\\\",\\\".\\\",\\\"_dot_\\\") => \\\"hej_dot_b_dot_c\\\"
"""
function stringReplaceChar(inString1::String, inString2::String, inString3::String)::String
  local outString::String

   outString = System.stringReplace(inString1, inString2, inString3)
  return outString
end

"""
  Takes a string and a char and split the string at the char returning the list of components.
  Example: stringSplitAtChar(\\\"hej.b.c\\\",\\\".\\\") => {\\\"hej,\\\"b\\\",\\\"c\\\"}
"""
function stringSplitAtChar(string::String, token::String)::List{String}
  local strings::List{String} = nil

  local ch::Int = stringCharInt(token)
  local cur::List{String} = nil

  for c in stringListStringChar(string)
    if stringCharInt(c) == ch
       strings = _cons(stringAppendList(listReverse(cur)), strings)
       cur = nil
    else
       cur = _cons(c, cur)
    end
  end
  if !listEmpty(cur)
     strings = _cons(stringAppendList(listReverse(cur)), strings)
  end
   strings = listReverse(strings)
  return strings
end

"""
  Example:
  boolOrList({true,false,false})  => true
  boolOrList({false,false,false}) => false
"""
function boolOrList(inBooleanLst::List{<:Bool})::Bool
  local outBoolean::Bool = false

  for b in inBooleanLst
    if b
       outBoolean = true
      return outBoolean
    end
  end
  return outBoolean
end

"""
  Takes a list of boolean values and applies the boolean AND operator on the elements
  Example:
  boolAndList({}) => true
  boolAndList({true, true}) => true
  boolAndList({false,false,true}) => false
"""
function boolAndList(inBooleanLst::List{<:Bool})::Bool
  local outBoolean::Bool = true

  for b in inBooleanLst
    if !b
       outBoolean = false
      return outBoolean
    end
  end
  return outBoolean
end

"""
  Takes an option value and a function over the value. It returns in another
  option value, resulting from the application of the function on the value.

  Example:
  applyOption(SOME(1), intString) => SOME(\\\"1\\\")
  applyOption(NONE(),  intString) => NONE()
"""
function applyOption(inOption::Option{TI}, inFunc::FuncType) where {TI}
  local outOption::Option

   outOption = begin
    local ival::TI
    local oval
    @match inOption begin
      SOME(ival) => begin
        SOME(inFunc(ival))
      end

      _ => begin
        NONE()
      end
    end
  end
  return outOption
end

"""Like applyOption but takes an additional argument"""
function applyOption1(
  inOption::Option{TI},
  inFunc::FuncType,
  inArg::ArgT,
) where {TI, ArgT}
  local outOption::Option
  outOption = begin
    local ival::TI
    local oval
    @match inOption begin
      SOME(ival) => begin
        SOME(inFunc(ival, inArg))
      end
      _ => begin
        NONE()
      end
    end
  end
  return outOption
end

"""
  Takes an optional value, a function and an extra value. If the optional value
  is SOME, applies the function on that value and returns the result.
  Otherwise returns the extra value.
"""
function applyOptionOrDefault(
  inValue::Option{TI},
  inFunc::FuncType,
  inDefaultValue::TO,
) where {TI, TO}
  local outValue::TO

   outValue = begin
    local value::TI
    local res::TO
    @match inValue begin
      SOME(value) => begin
        inFunc(value)
      end

      _ => begin
        inDefaultValue
      end
    end
  end
  return outValue
end

"""
  Takes an optional value, a function, an extra argument and an extra value.
  If the optional value is SOME, applies the function on that value and the
  extra argument and returns the result. Otherwise returns the extra value.
"""
function applyOptionOrDefault1(
  inValue::Option{TI},
  inFunc::FuncType,
  inArg::ArgT,
  inDefaultValue::TO,
) where {TI, TO, ArgT}
  local outValue::TO

   outValue = begin
    local value::TI
    local res::TO
    @match inValue begin
      SOME(value) => begin
        inFunc(value, inArg)
      end

      _ => begin
        inDefaultValue
      end
    end
  end
  return outValue
end

"""
  Takes an optional value, a function, two extra arguments and an extra value.
  If the optional value is SOME, applies the function on that value and the
  extra argument and returns the result. Otherwise returns the extra value.
"""
function applyOptionOrDefault2(
  inValue::Option{TI},
  inFunc::FuncType,
  inArg1::ArgT1,
  inArg2::ArgT2,
  inDefaultValue::TO,
) where {TI, TO, ArgT1, ArgT2}
  local outValue::TO

   outValue = begin
    local value::TI
    local res::TO
    @match inValue begin
      SOME(value) => begin
        inFunc(value, inArg1, inArg2)
      end

      _ => begin
        inDefaultValue
      end
    end
  end
  return outValue
end

function applyOption_2(inValue1::Option{T}, inValue2::Option{T}, inFunc::FuncType) where {T}
  local outValue::Option{T}

   outValue = begin
    @match (inValue1, inValue2) begin
      (NONE(), _) => begin
        inValue2
      end

      (_, NONE()) => begin
        inValue1
      end

      _ => begin
        SOME(inFunc(getOption(inValue1), getOption(inValue2)))
      end
    end
  end
  return outValue
end

"""Makes a value into value option, using SOME(value)"""
function makeOption(inValue::T) where {T}
  local outOption::Option{T} = SOME(inValue)
  return outOption
end

function makeOptionOnTrue(inCondition::Bool, inValue::T) where {T}
  local outOption::Option{T} = if inCondition
    SOME(inValue)
  else
    NONE()
  end
  return outOption
end

"""
  @author johti17
"""
function makeQuotedIdentifier(str::String)
  local qi = Base.replace(str, "\\"=> "\\\\")
  qi = Base.replace(qi, "'" => "\\'")
  qi = string("'", qi, "'")
end

"""
  author: PA
  Returns string value or empty string from string option.
"""
function stringOption(inStringOption::Option{<:String})::String
  local outString::String

   outString = begin
    local s::String
    @match inStringOption begin
      SOME(s) => begin
        s
      end

      _ => begin
        ""
      end
    end
  end
  return outString
end

""" Returns an option value if SOME, otherwise fails """
function getOption(inOption::Option{T}) where {T}
  local outValue::T
  @match SOME(outValue) = inOption
  return outValue
end

"""Returns an option value if SOME, otherwise the default"""
function getOptionOrDefault(inOption::Option, inDefault)
  local outValue

   outValue = begin
    local value
    @match inOption begin
      SOME(value) => begin
        value
      end

      _ => begin
        inDefault
      end
    end
  end
  return outValue
end

"""Returns true if integer value is greater zero (> 0)"""
function intGreaterZero(v::Int)::Bool
  local res::Bool = v > 0
  return res
end

"""Returns true if integer value is positive (>= 0)"""
function intPositive(v::Int)::Bool
  local res::Bool = v >= 0
  return res
end

"""Returns true if integer value is negative (< 0)"""
function intNegative(v::Int)::Bool
  local res::Bool = v < 0
  return res
end

function intSign(i::Int)::Int
  local o::Int = if i == 0
    0
  elseif (i > 0)
    1
  else
    -1
  end
  return o
end

"""
  Compares two integers and return -1 if the first is smallest, 1 if the second
  is smallest, or 0 if they are equal.
"""
function intCompare(inN::Int, inM::Int)::Int
  local outResult::Int =
    if inN == inM
      0
    elseif (inN > inM)
      1
    else
      -1
    end
  return outResult
end

"""Performs integer exponentiation."""
function intPow(base::Int, exponent::Int)::Int
  local result::Int = 1

  if exponent >= 0
    for i = 1:exponent
       result = result * base
    end
  else
    fail()
  end
  return result
end

"""
  Compares two reals and return -1 if the first is smallest, 1 if the second
  is smallest, or 0 if they are equal.
"""
function realCompare(inN::AbstractFloat, inM::AbstractFloat)::Int
  local outResult::Int = if inN == inM
    0
  elseif (inN > inM)
    1
  else
    -1
  end
  return outResult
end

"""
  Compares two booleans and return -1 if the first is smallest, 1 if the second
  is smallest, or 0 if they are equal.
"""
function boolCompare(inN::Bool, inM::Bool)::Int
  local outResult::Int = if inN == inM
    0
  elseif (inN > inM)
    1
  else
    -1
  end
  return outResult
end

"""Returns true if string is not the empty string."""
function isNotEmptyString(inString::String)::Bool
  local outIsNotEmpty::Bool = stringLength(inString) > 0
  return outIsNotEmpty
end

"""
  This function tries to write to a file and if it fails then it
  outputs \\\"# Cannot write to file: <filename>.\\\" to errorBuf
"""
function writeFileOrErrorMsg(inFilename::String, inString::String)
  return try
    System.writeFile(inFilename, inString)
  catch
    Print.printErrorBuf("# Cannot write to file: " + inFilename + ".")
  end
end

function stringStartsWith(inString1::String, inString2::String)::Bool
  local outEqual::Bool

   outEqual = 0 == System.strncmp(inString1, inString2, stringLength(inString1))
  return outEqual
end

"""
  Compare two strings up to the nth character
  Returns true if they are equal.
"""
function strncmp(inString1::String, inString2::String, inLength::Int)::Bool
  local outEqual::Bool

   outEqual = 0 == System.strncmp(inString1, inString2, inLength)
  return outEqual
end

"""
  Compares two strings up to the nth character. Returns true if they are not
  equal.
"""
function notStrncmp(inString1::String, inString2::String, inLength::Int)::Bool
  local outEqual::Bool

   outEqual = 0 != System.strncmp(inString1, inString2, inLength)
  return outEqual
end

"""
  author: PA
  Returns tick as a string, i.e. an unique number.
"""
function tickStr()::String
  local s::String = intString(tick())
  return s
end

"""
  @author: adrpo
  replace \\\\ with path delimiter only in Windows!
"""
function replaceWindowsBackSlashWithPathDelimiter(inPath::String)::String
  local outPath::String

  if Autoconf.os == "Windows_NT"
     outPath = System.stringReplace(inPath, "\\\\", Autoconf.pathDelimiter)
  else
     outPath = inPath
  end
  return outPath
end

"""
  author: x02lucpo
  splits the filepath in directory and filename
  (\\\"c:\\\\programs\\\\file.mo\\\") => (\\\"c:\\\\programs\\\",\\\"file.mo\\\")
  (\\\"..\\\\work\\\\file.mo\\\") => (\\\"c:\\\\openmodelica123\\\\work\\\", \\\"file.mo\\\")
"""
function getAbsoluteDirectoryAndFile(filename::String)::Tuple{String, String}
  local basename::String
  local dirname::String

  local realpath::String

   realpath = System.realpath(filename)
   dirname = System.dirname(realpath)
   basename = System.basename(realpath)
   dirname = replaceWindowsBackSlashWithPathDelimiter(dirname)
  return (dirname, basename)
end

"""
  author: x02lucpo
  replace the double-backslash with backslash
"""
function rawStringToInputString(inString::String)::String
  local outString::String

   outString = System.stringReplace(inString, "\\\\\\", "\\") #= change backslash-double-quote to double-quote  =#
   outString = System.stringReplace(outString, "\\\\\\\\", "\\\\") #= double-backslash with backslash  =#
  return outString
end

function escapeModelicaStringToCString(modelicaString::String)::String
  local cString::String

  #=  C cannot handle newline in string constants
  =#
   cString = System.escapedString(modelicaString, true)
  return cString
end

function escapeModelicaStringToJLString(modelicaString::String)::String
  local cString::String

  #= TODO. Do this the proper way. We just remove all the dollars for now
  =#
   cString = System.stringReplace(modelicaString, "", "")
   cString = System.stringReplace(cString, "\\", "")
   cString = System.stringReplace(cString, "\\", "")
   cString = System.stringReplace(cString, "\\\\", "")
   cString = System.escapedString(cString, true)
  return cString
end

function escapeModelicaStringToXmlString(modelicaString::String)::String
  local xmlString::String

  #=  C cannot handle newline in string constants
  =#
   xmlString = System.stringReplace(modelicaString, "&", "&amp;")
   xmlString = System.stringReplace(xmlString, "\\", "&quot;")
   xmlString = System.stringReplace(xmlString, "<", "&lt;")
   xmlString = System.stringReplace(xmlString, ">", "&gt;")
  #=  TODO! FIXME!, we have issues with accented chars in comments
  =#
  #=  that end up in the Model_init.xml file and makes it not well
  =#
  #=  formed but the line below does not work if the xmlString is
  =#
  #=  already UTF-8. We should somehow detect the encoding.
  =#
  #=  xmlString := System.iconv(xmlString, \"\", \"UTF-8\");
  =#
  return xmlString
end

function makeTuple(inValue1::T1, inValue2::T2) where {T1, T2}
  local outTuple::Tuple{T1, T2} = (inValue1, inValue2)
  return outTuple
end

function makeTupleR(inValue1::T1, inValue2::T2) where {T1, T2}
  local outTuple::Tuple{T2, T1} = (inValue2, inValue1)
  return outTuple
end

function make3Tuple(inValue1::T1, inValue2::T2, inValue3::T3) where {T1, T2, T3}
  local outTuple::Tuple{T1, T2, T3} = (inValue1, inValue2, inValue3)
  return outTuple
end

function mulListIntegerOpt(inList::List{<:Option{<:Integer}}, inAccum::Int = 1)::Int
  local outResult::Int

   outResult = begin
    local i::Int
    local rest::List{Option{Integer}}
    @match inList begin
      nil() => begin
        inAccum
      end

      SOME(i) <| rest => begin
        mulListIntegerOpt(rest, i * inAccum)
      end

      NONE() <| rest => begin
        mulListIntegerOpt(rest, inAccum)
      end
    end
  end
  return outResult
end

const StatefulBoolean = Array  #= A single boolean value that can be updated (a destructive operation). NOTE: Use Mutable<Boolean> instead. This implementation is kept since Susan cannot use that type. =#

"""Create a boolean with state (that is, it is mutable)"""
function makeStatefulBoolean(b::Bool)::StatefulBoolean
  local sb::StatefulBoolean = arrayCreate(1, b)
  return sb
end

"""Create a boolean with state (that is, it is mutable)"""
function getStatefulBoolean(sb::StatefulBoolean)::Bool
  local b::Bool = sb[1]
  return b
end

"""Update the state of a mutable boolean"""
function setStatefulBoolean(sb::StatefulBoolean, b::Bool)
  return arrayUpdate(sb, 1, b)
end

"""Takes two options and a function to compare the type."""
function optionEqual(
  inOption1::Option{T1},
  inOption2::Option{T2},
  inFunc::CompareFunc,
) where {T1, T2}
  local outEqual::Bool

   outEqual = begin
    local val1::T1
    local val2::T2
    @match (inOption1, inOption2) begin
      (SOME(val1), SOME(val2)) => begin
        inFunc(val1, val2)
      end

      (NONE(), NONE()) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outEqual
end

"""Returns the value if the function call succeeds, otherwise the default"""
function makeValueOrDefault(inFunc::FuncType, inArg::TI, inDefaultValue::TO) where {TI, TO}
  local outValue::TO

  try
     outValue = inFunc(inArg)
  catch
     outValue = inDefaultValue
  end
  return outValue
end

"""Escapes a String so that it can be used in xml"""
function xmlEscape(s1::String)::String
  local s2::String

   s2 = stringReplaceChar(s1, "&", "&amp;")
   s2 = stringReplaceChar(s2, "<", "&lt;")
   s2 = stringReplaceChar(s2, ">", "&gt;")
   s2 = stringReplaceChar(s2, "\\", "&quot;")
  return s2
end

"""As strcmp, but has Boolean output as is expected by the sort function"""
function strcmpBool(s1::String, s2::String)::Bool
  local b::Bool = stringCompare(s1, s2) > 0
  return b
end

"""
  @author: adrpo
  This function will append the first string to the second string
"""
function stringAppendReverse(str1::String, str2::String)::String
  local str::String = stringAppend(str2, str1)
  return str
end

function stringAppendNonEmpty(inString1::String, inString2::String)::String
  local outString::String

   outString = begin
    @match inString2 begin
      "" => begin
        inString2
      end

      _ => begin
        stringAppend(inString1, inString2)
      end
    end
  end
  return outString
end

function getCurrentDateTime()::DateTime
  local dt::DateTime

  local sec::Int
  local min::Int
  local hour::Int
  local mday::Int
  local mon::Int
  local year::Int

   (sec, min, hour, mday, mon, year) = System.getCurrentDateTime()
   dt = DATETIME(sec, min, hour, mday, mon, year)
  return dt
end

function isSuccess(status::Status)::Bool
  local bool::Bool

   bool = begin
    @match status begin
      SUCCESS(__) => begin
        true
      end

      FAILURE(__) => begin
        false
      end
    end
  end
  return bool
end

function id(inValue::T) where {T}
  local outValue::T = inValue
  return outValue
end

"""
  Takes two lists of the same type and builds a string like x = val1, y = val2, ....
  Example: listThread({1,2,3},{4,5,6},'=',',') => 1=4, 2=5, 3=6
"""
function buildMapStr(
  inLst1::List{<:String},
  inLst2::List{<:String},
  inMiddleDelimiter::String,
  inEndDelimiter::String,
)::String
  local outStr::String

   outStr = begin
    local ra::List{String}
    local rb::List{String}
    local fa::String
    local fb::String
    local md::String
    local ed::String
    local str::String
    @match (inLst1, inLst2, inMiddleDelimiter, inEndDelimiter) begin
      (nil(), nil(), _, _) => begin
        ""
      end

      (fa <| nil(), fb <| nil(), md, _) => begin
         str = stringAppendList(list(fa, md, fb))
        str
      end

      (fa <| ra, fb <| rb, md, ed) => begin
         str = buildMapStr(ra, rb, md, ed)
         str = stringAppendList(list(fa, md, fb, ed, str))
        str
      end
    end
  end
  return outStr
end

"""
  assoc(key,lst) => value, where lst is a tuple of (key,value) pairs.
  Does linear search using equality(). This means it is slow for large
  inputs (many elements or large elements); if you have large inputs, you
  should use a hash-table instead.
"""
function assoc(inKey::Key, inList::List{Tuple{Key, Val}}) where {Key, Val}
  local outValue::Val

  local k::Key
  local v::Val

   (k, v) = listHead(inList)
   outValue = if valueEq(inKey, k)
    v
  else
    assoc(inKey, listRest(inList))
  end
  return outValue
end

"""Returns 1 if the given boolean is true, otherwise 0."""
function boolInt(inBoolean::Bool)::Int
  local outInteger::Int = if inBoolean
    1
  else
    0
  end
  return outInteger
end

"""Returns true if the given integer is larger than 0, otherwise false."""
function intBool(inInteger::Int)::Bool
  local outBoolean::Bool = inInteger > 0
  return outBoolean
end

"""
  Converts a string to a boolean value. true and yes is converted to true,
  false and no is converted to false. The function is case-insensitive.
"""
function stringBool(inString::String)::Bool
  local outBoolean::Bool

   outBoolean = stringBool2(System.tolower(inString))
  return outBoolean
end

"""Helper function to stringBool."""
function stringBool2(inString::String)::Bool
  local outBoolean::Bool

   outBoolean = begin
    @match inString begin
      "true" => begin
        true
      end

      "false" => begin
        false
      end

      "yes" => begin
        true
      end

      "no" => begin
        false
      end
    end
  end
  return outBoolean
end

function stringEqCaseInsensitive(str1::String, str2::String)::Bool
  local eq::Bool

   eq = stringEq(System.tolower(str1), System.tolower(str2))
  return eq
end

"""
  SOME(a) => {a}
  NONE()  => {}
"""
function optionList(inOption::Option{T}) where {T}
  local outList::List{T}

   outList = begin
    local value::T
    @match inOption begin
      SOME(value) => begin
        list(value)
      end

      _ => begin
        nil
      end
    end
  end
  return outList
end

"""
  @author johti17:
  {SOME(1), NONE, SOME(2)} => {1, 2}
  {NONE} => {}
"""
function listOfOptionToList(inOptLst::List{Option{T}}) where {T}
  local outLst::List{T}

   outLst = ListUtil.flatten(ListUtil.map(inOptLst, optionList))
  return outLst
end

"""
  Pads a string with the given padding so that the resulting string is as long
  as the given width. If the string is already longer nothing is done to it.
  Note that the length of the padding is assumed to be one, i.e. a single char.
"""
function stringPadRight(inString::String, inPadWidth::Int, inPadString::String)::String
  local outString::String

  local pad_length::Int
  local pad_str::String

   pad_length = inPadWidth - stringLength(inString)
  if pad_length > 0
     pad_str = stringAppendList(list(inPadString for i = 1:pad_length))
     outString = inString + pad_str
  else
     outString = inString
  end
  return outString
end

"""
  Pads a string with the given padding so that the resulting string is as long
  as the given width. If the string is already longer nothing is done to it.
  Note that the length of the padding is assumed to be one, i.e. a single char.
"""
function stringPadLeft(inString::String, inPadWidth::Int, inPadString::String)::String
  local outString::String

  local pad_length::Int
  local pad_str::String

   pad_length = inPadWidth - stringLength(inString)
  if pad_length > 0
     pad_str = stringAppendList(list(inPadString for i = 1:pad_length))
     outString = pad_str + inString
  else
     outString = inString
  end
  return outString
end

"""Returns all but the first character of a string."""
function stringRest(inString::String)::String
  local outRest::String

  local len::Int

   len = stringLength(inString)
   outRest = substring(inString, 2, len)
  return outRest
end

function intProduct(lst::List{<:Integer})::Int
  local i::Int = ListUtil.fold(lst, intMul, 1)
  return i
end

"""
  Given a positive integer, returns the closest prime number that is equal or
  larger. This algorithm checks every odd number larger than the given number
  until it finds a prime, but since the distance between primes is relatively
  small (the largest gap between primes up to 32 bit is only around 300) it's
  still reasonably fast. It's useful for e.g. determining a good size for a
  hash table with a known number of elements.
"""
function nextPrime(inN::Int)::Int
  local outNextPrime::Int

   outNextPrime = if inN <= 2
    2
  else
    nextPrime2(inN + intMod(inN + 1, 2))
  end
  return outNextPrime
end

"""
  Helper function to nextPrime2, does the actual work of finding the next
  prime.
"""
function nextPrime2(inN::Int)::Int
  local outNextPrime::Int

   outNextPrime = if nextPrime_isPrime(inN)
    inN
  else
    nextPrime2(inN + 2)
  end
  return outNextPrime
end

"""
  Helper function to nextPrime2, checks if a given number is a prime or not.
  Note that this function is not a general prime checker, it only works for
  positive odd numbers.
"""
function nextPrime_isPrime(inN::Int)::Bool
  local outIsPrime::Bool

  local i::Int = 3
  local q::Int = intDiv(inN, 3)

  #=  Check all factors up to sqrt(inN)
  =#
  while q >= i
    if inN == q * i
       outIsPrime = false
      return outIsPrime
    end
     i = i + 2
     q = intDiv(inN, i)
  end
  #=  The number is divisible by a factor => not a prime.
  =#
  #=  All factors have been checked, inN is a prime.
  =#
   outIsPrime = true
  return outIsPrime
end

"""Useful if you do not want to write an unparser"""
function anyToEmptyString(a::T) where {T}
  local empty::String = ""
  return empty
end

function removeLast3Char(str::String)::String
  local outStr::String

   outStr = substring(str, 1, stringLength(str) - 3)
  return outStr
end

function removeLast4Char(str::String)::String
  local outStr::String

   outStr = substring(str, 1, stringLength(str) - 4)
  return outStr
end

function removeLastNChar(str::String, n::Int)::String
  local outStr::String

   outStr = substring(str, 1, stringLength(str) - n)
  return outStr
end

function stringNotEqual(str1::String, str2::String)::Bool
  local b::Bool = !stringEq(str1, str2)
  return b
end

function swap(cond::Bool, in1, in2)
  local out2
  local out1

   (out1, out2) = begin
    @match cond begin
      true => begin
        (in2, in1)
      end

      _ => begin
        (in1, in2)
      end
    end
  end
  return (out1, out2)
end

function replace(replaced::T, arg::T) where {T}
  local outArg::T = arg
  return outArg
end

"""Calculates the size of a Real range given the start, step and stop values."""
function realRangeSize(
  inStart::AbstractFloat,
  inStep::AbstractFloat,
  inStop::AbstractFloat,
)::Int
  local outSize::Int

   outSize = integer(floor((inStop - inStart) / inStep + 5e-15)) + 1
   outSize = max(outSize, 0)
  return outSize
end

function createDirectoryTreeH(
  inString::String,
  parentDir::String,
  parentDirExists::Bool,
)::Bool
  local outBool::Bool

   outBool = begin
    local b::Bool
    @matchcontinue parentDirExists begin
      _ => begin
        @match true = stringEqual(parentDir, System.dirname(parentDir))
         b = System.createDirectory(inString)
        b
      end

      true => begin
         b = System.createDirectory(inString)
        b
      end

      false => begin
        @match true = createDirectoryTree(parentDir)
         b = System.createDirectory(inString)
        b
      end

      _ => begin
        false
      end
    end
  end
  return outBool
end

function createDirectoryTree(inString::String)::Bool
  local outBool::Bool

  local parentDir::String
  local parentDirExists::Bool

   parentDir = System.dirname(inString)
   parentDirExists = System.directoryExists(parentDir)
   outBool = createDirectoryTreeH(inString, parentDir, parentDirExists)
  return outBool
end

"""Rounds up to the nearest power of 2"""
function nextPowerOf2(i::Int)::Int
  local v::Int

   v = i - 1
   v = intBitOr(v, intBitLShift(v, 1))
   v = intBitOr(v, intBitLShift(v, 2))
   v = intBitOr(v, intBitLShift(v, 4))
   v = intBitOr(v, intBitLShift(v, 8))
   v = intBitOr(v, intBitLShift(v, 16))
   v = v + 1
  return v
end

function endsWith(inString::String, inSuffix::String)::Bool
  local outEndsWith::Bool

  local start::Int
  local stop::Int
  local str_len::Int
  local suf_len::Int

  if inString == ""
     outEndsWith = false
  else
     str_len = stringLength(inString)
     suf_len = stringLength(inSuffix)
     start = if str_len > suf_len
      str_len - suf_len + 1
    else
      1
    end
     outEndsWith = inSuffix == substring(inString, start, str_len)
  end
  return outEndsWith
end

function isCIdentifier(str::String)::Bool
  local b::Bool

  local i::Int

   (i, _) = System.regex(str, "^[_A-Za-z][_A-Za-z0-9]*", 0, true, false)
   b = i == 1
  return b
end

function isIntegerString(str::String)::Bool
  local b::Bool

  local i::Int

   (i, _) = System.regex(str, "^[0-9][0-9]*", 0, true, false)
   b = i == 1
  return b
end

"""
  @author:adrpo
  if the string is bigger than len keep only until len
  if not, return the same string
"""
function stringTrunc(str::String, len::Int)::String
  local truncatedStr::String

   truncatedStr = if stringLength(str) <= len
    str
  else
    substring(str, 0, len)
  end
  return truncatedStr
end

"""Create an iterator or the like with a unique name"""
function getTempVariableIndex()::String
  local name::String
  name = stringAppend("tmpVar", intString(System.tmpTickIndex(Global.tmpVariableIndex)))
  return name
end

function anyReturnTrue(a::T) where {T}
  local b::Bool = true
  return b
end

"""
  @author: adrpo
  returns the given path if it exists if not it considers it relative and returns that
"""
function absoluteOrRelative(inFileName::String)::String
  local outFileName::String

  local pwd::String
  local pd::String

   pwd = System.pwd()
   pd = Autoconf.pathDelimiter
   outFileName = if System.regularFileExists(inFileName)
    inFileName
  else
    stringAppendList(list(pwd, pd, inFileName))
  end
  return outFileName
end

function intLstString(lst::List{<:Integer})::String
  local s::String

   s = stringDelimitList(ListUtil.map(lst, intString), ", ")
  return s
end

"""Returns whether the given SourceInfo is empty or not."""
function sourceInfoIsEmpty(inInfo::SourceInfo)::Bool
  local outIsEmpty::Bool

   outIsEmpty = begin
    @match inInfo begin
      SOURCEINFO(fileName = "") => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsEmpty
end

"""Returns whether two SourceInfo are equal or not."""
function sourceInfoIsEqual(inInfo1::SourceInfo, inInfo2::SourceInfo)::Bool
  local outIsEqual::Bool

   outIsEqual = begin
    @match (inInfo1, inInfo2) begin
      (SOURCEINFO(__), SOURCEINFO(__)) => begin
        inInfo1.fileName == inInfo2.fileName &&
        inInfo1.isReadOnly == inInfo2.isReadOnly &&
        inInfo1.lineNumberStart == inInfo2.lineNumberStart &&
        inInfo1.columnNumberStart == inInfo2.columnNumberStart &&
        inInfo1.lineNumberEnd == inInfo2.lineNumberEnd &&
        inInfo1.columnNumberEnd == inInfo2.columnNumberEnd
      end

      _ => begin
        false
      end
    end
  end
  return outIsEqual
end

"""
  /*************************************************
  * profiler stuff
  ************************************************/
"""
function profilerinit()
  setGlobalRoot(Global.profilerTime1Index, 0.0)
  setGlobalRoot(Global.profilerTime2Index, 0.0)
  return System.realtimeTick(ClockIndexes.RT_PROFILER0)
end

function profilerresults()
  local tg::AbstractFloat
  local t1::AbstractFloat
  local t2::AbstractFloat

   tg = System.realtimeTock(ClockIndexes.RT_PROFILER0)
   t1 = profilertime1()
   t2 = profilertime2()
  print("Time all: ")
  print(realString(tg))
  print("\\n")
  print("Time t1: ")
  print(realString(t1))
  print("\\n")
  print("Time t2: ")
  print(realString(t2))
  print("\\n")
  print("Time all-t1-t2: ")
  print(realString(realSub(realSub(tg, t1), t2)))
  return print("\\n")
end

function profilertime1()::AbstractFloat
  local t1::AbstractFloat

   t1 = getGlobalRoot(Global.profilerTime1Index)
  return t1
end

function profilertime2()::AbstractFloat
  local t2::AbstractFloat

   t2 = getGlobalRoot(Global.profilerTime2Index)
  return t2
end

function profilerstart1()
  return System.realtimeTick(ClockIndexes.RT_PROFILER1)
end

function profilerstart2()
  return System.realtimeTick(ClockIndexes.RT_PROFILER2)
end

function profilerstop1()
  local t::AbstractFloat

   t = System.realtimeTock(ClockIndexes.RT_PROFILER1)
  return setGlobalRoot(
    Global.profilerTime1Index,
    realAdd(getGlobalRoot(Global.profilerTime1Index), t),
  )
end

function profilerstop2()
  local t::AbstractFloat

   t = System.realtimeTock(ClockIndexes.RT_PROFILER2)
  return setGlobalRoot(
    Global.profilerTime2Index,
    realAdd(getGlobalRoot(Global.profilerTime2Index), t),
  )
end

function profilerreset1()
  return setGlobalRoot(Global.profilerTime1Index, 0.0)
end

function profilerreset2()
  return setGlobalRoot(Global.profilerTime2Index, 0.0)
end

function profilertock1()::AbstractFloat
  local t::AbstractFloat

   t = System.realtimeTock(ClockIndexes.RT_PROFILER1)
  return t
end

function profilertock2()::AbstractFloat
  local t::AbstractFloat

   t = System.realtimeTock(ClockIndexes.RT_PROFILER2)
  return t
end

function applyTuple31(inTuple::Tuple{T1, T2, T3}, func::FuncT) where {T1, T2, T3}
  local outTuple::Tuple{T1, T2, T3}

  local t1::T1
  local t1_new::T1
  local t2::T2
  local t3::T3

   (t1, t2, t3) = inTuple
   t1_new = func(t1)
   outTuple = if referenceEq(t1, t1_new)
    inTuple
  else
    (t1_new, t2, t3)
  end
  return outTuple
end

"""
  Dangerous function used for reference compare.
  This is among other things used to compare instantiated nodes during function evaluation.
"""
function unsafe_pointer_from_objref(@nospecialize(x))
  ccall(:jl_value_ptr, Ptr{Cvoid}, (Any,), x)
end

"""
   Returns -1, 0, or 1 depending on whether the memory address of ref1 is less,
   equal, or greater than the address of ref2.
"""
function referenceCompare(ref1::T1, ref2::T2) where {T1, T2}
  local result::Int
  result = if ref1 === ref2
    0
  else
    t1 = UInt64(unsafe_pointer_from_objref(ref1))
    t2 = UInt64(unsafe_pointer_from_objref(ref2))
    result = Int((t1 < t2) ? -1 : (t1 > t2))
  end
  return result
end

@exportAll()
end

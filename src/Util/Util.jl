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

import ..ListUtil

const dummyInfo = SOURCEINFO("", false, 0, 0, 0, 0, 0.0)::SourceInfo

const derivativeNamePrefix = "DER"::String

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
  @author johti17
"""
function makeQuotedIdentifier(str::String)
  local qi = Base.replace(str, "\\"=> "\\\\")
  qi = Base.replace(qi, "'" => "\\'")
  qi = string("'", qi, "'")
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

"""
  Compare two strings up to the nth character
  Returns true if they are equal.
"""
function strncmp(inString1::String, inString2::String, inLength::Int)::Bool
  local outEqual::Bool

   outEqual = 0 == System.strncmp(inString1, inString2, inLength)
  return outEqual
end

function makeTuple(inValue1::T1, inValue2::T2) where {T1, T2}
  local outTuple::Tuple{T1, T2} = (inValue1, inValue2)
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

"""Escapes a String so that it can be used in xml"""
function xmlEscape(s1::String)::String
  local s2::String

   s2 = stringReplaceChar(s1, "&", "&amp;")
   s2 = stringReplaceChar(s2, "<", "&lt;")
   s2 = stringReplaceChar(s2, ">", "&gt;")
   s2 = stringReplaceChar(s2, "\\", "&quot;")
  return s2
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
  #= Float64 operands: compiled for abstract arguments, `floor(Int, ::Any)` was a dynamic call, and a package adding a
     `floor` method (FixedPointNumbers) invalidated this method and its 1241 callers at each load (2026-11-16) =#
  local steps::Float64 = (Float64(inStop) - Float64(inStart)) / Float64(inStep) + 5e-15
  outSize = floor(Int, steps) + 1
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

"""Create an iterator or the like with a unique name"""
function getTempVariableIndex()::String
  local name::String
  name = stringAppend("tmpVar", intString(System.tmpTickIndex(Global.tmpVariableIndex)))
  return name
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

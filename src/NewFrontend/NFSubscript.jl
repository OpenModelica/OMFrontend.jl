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

abstract type NFSubscript end
const Subscript = NFSubscript

struct SUBSCRIPT_WHOLE <: NFSubscript end

struct SUBSCRIPT_EXPANDED_SLICE <: NFSubscript
   indices::List{Subscript}
end

struct SUBSCRIPT_SLICE{T <: Expression} <: NFSubscript
  slice::T
end

struct SUBSCRIPT_INDEX{T <: Expression} <: NFSubscript
  index::T
end

struct SUBSCRIPT_UNTYPED{T <: Expression} <: NFSubscript
  exp::T
end

mutable struct SUBSCRIPT_RAW_SUBSCRIPT <: NFSubscript
  subscript::Absyn.Subscript
end


struct SUBSCRIPT_SPLIT_INDEX <: NFSubscript
  node:: InstNode
  dimIndex::Int
end

struct SUBSCRIPT_SPLIT_PROXY <: NFSubscript
  origin::InstNode
  parent::InstNode
end

function isSplitIndex(s::Subscript)::Bool
  return s isa SUBSCRIPT_SPLIT_INDEX
end

function toInteger(subscript::Subscript)::Int
  local int::Int

   int = begin
    @match subscript begin
      SUBSCRIPT_INDEX(__) => begin
        toInteger(subscript.index)
      end
    end
  end
  return int
end

function toExp(subscript::Subscript)
  local exp::Expression
   exp = begin
    @match subscript begin
      SUBSCRIPT_UNTYPED(__) => begin
        subscript.exp
      end

      SUBSCRIPT_INDEX(__) => begin
        subscript.index
      end

      SUBSCRIPT_SLICE(__) => begin
        subscript.slice
      end
    end
  end
  return exp
end

function fromExp(exp::Expression)::Subscript
  local subscript::Subscript

   subscript = begin
    @match exp begin
      INTEGER_EXPRESSION(__) => begin
        SUBSCRIPT_INDEX(exp)
      end

      BOOLEAN_EXPRESSION(__) => begin
        SUBSCRIPT_INDEX(exp)
      end

      ENUM_LITERAL_EXPRESSION(__) => begin
        SUBSCRIPT_INDEX(exp)
      end

      _ => begin
        SUBSCRIPT_UNTYPED(exp)
      end
    end
  end
  return subscript
end

"""
Backported function
"""
function fromTypedExp(exp::Expression)
  res = if isArray(typeOf(exp))
    SUBSCRIPT_SLICE(exp)
  else
    SUBSCRIPT_INDEX(exp)
  end
  return res
end

function isValidIndexType(ty::NFType)::Bool
  local b::Bool = isInteger(ty) || isBoolean(ty) || isEnumeration(ty)
  return b
end

function first(dim::Dimension)::Subscript
  local sub::Subscript
   sub = begin
    @match dim begin
      DIMENSION_INTEGER(__) => begin
        SUBSCRIPT_INDEX(INTEGER_EXPRESSION(1))
      end
      DIMENSION_BOOLEAN(__) => begin
        SUBSCRIPT_INDEX(BOOLEAN_EXPRESSION(false))
      end
      DIMENSION_ENUM(__) => begin
        SUBSCRIPT_INDEX(nthEnumLiteral(dim.enumType, 1))
      end
    end
  end
  return sub
end

"""
  Merges a list of subscripts with a list of 'existing' subscripts.
  This is done by e.g. subscripting existing slice and : subscripts,
  such that e.g. mergeList({1, :}, {3:5, 1:3, 4}) => {3, 1:3, 4}.
  The function will ensure that the output list contains at most as
  many subscripts as the given number of dimensions, and also returns
  the list of remaining subscripts that couldn't be added.
"""
function mergeList(
  newSubs::List{<:Subscript},
  oldSubs::List{<:Subscript},
  dimensions::Int,
)::Tuple{List{Subscript}, List{Subscript}} #= The number of dimensions to subscript =#
  local remainingSubs::List{Subscript} #= The subscripts that didn't fit =#
  local outSubs::List{Subscript} #= The merged subscripts, at most 'dimensions' many =#

  local subs_count::Int
  local new_sub::Subscript
  local old_sub::Subscript
  local rest_old_subs::List{Subscript}
  local merged::Bool = true

  #=  If there aren't any existing subscripts we just add as many subscripts
  =#
  #=  from the list of new subscripts as possible.
  =#
  if listEmpty(oldSubs)
    if listLength(newSubs) <= dimensions
       outSubs = newSubs
       remainingSubs = nil
    else
       (outSubs, remainingSubs) = ListUtil.split(newSubs, dimensions)
    end
    return (outSubs, remainingSubs) #= The subscripts that didn't fit =#
  end
   subs_count = listLength(oldSubs)
   remainingSubs = newSubs
   rest_old_subs = oldSubs
   outSubs = nil
  #=  Loop over the remaining subscripts as long as they can be merged.
  =#
  while merged && !listEmpty(remainingSubs)
    @match Cons{Subscript}(new_sub, remainingSubs) = remainingSubs
     merged = false
    while !merged
      if listEmpty(rest_old_subs)
         remainingSubs = Cons{Subscript}(new_sub, remainingSubs)
        break
      else
        @match Cons{Subscript}(old_sub, rest_old_subs) = rest_old_subs
         (merged, outSubs) = begin
          @match old_sub begin
            SUBSCRIPT_SLICE(__) => begin
              #=  Loop over the old subscripts while this new subscript hasn't been
              =#
              #=  merged and there's still old subscript left.
              =#
              #=  Try to replace the old subscript with the new.
              =#
              #=  If the old subscript is a slice, subscript it with the new subscript.
              =#
              #=  The old subscript only changes if the new is an index or slice, not :.
              =#
              if !isWhole(new_sub)
                 outSubs = Cons{Subscript}(
                  SUBSCRIPT_INDEX(applySubscript(
                    new_sub,
                    old_sub.slice,
                  )),
                  outSubs,
                )
              else
                 outSubs = Cons{Subscript}(old_sub, outSubs)
              end
              (true, outSubs)
            end

            SUBSCRIPT_WHOLE(__) => begin
              (true, Cons{Subscript}(new_sub, outSubs))
            end

            _ => begin
              (false, Cons{Subscript}(old_sub, outSubs))
            end
          end
        end
      end
    end
  end
  #=  If the old subscript is :, replace it with the new subscript.
  =#
  #=  If the old subscript is a scalar index it can't be replaced.
  =#
  #=  Append any remaining old subscripts.
  =#
  for s in rest_old_subs
     outSubs = Cons{Subscript}(s, outSubs)
  end
  #=  Append any remaining new subscripts to the end of the list as long as
  =#
  #=  there are dimensions left to fill.
  =#
  while !listEmpty(remainingSubs) && subs_count < dimensions
    @match Cons{Subscript}(new_sub, remainingSubs) = remainingSubs
     outSubs = Cons{Subscript}(new_sub, outSubs)
     subs_count = subs_count + 1
  end
   outSubs = listReverseInPlace(outSubs)
  return (outSubs, remainingSubs) #= The subscripts that didn't fit =#
end

function variabilityList(subscripts::List{<:Subscript})::VariabilityType
  local var::VariabilityType = Variability.CONSTANT

  for s in subscripts
     var = variabilityMax(var, variability(s))
  end
  return var
end

function variability(subscript::Subscript)::VariabilityType
  local var::VariabilityType

   var = begin
    @match subscript begin
      SUBSCRIPT_UNTYPED(__) => begin
        variability(subscript.exp)
      end

      SUBSCRIPT_INDEX(__) => begin
        variability(subscript.index)
      end

      SUBSCRIPT_SLICE(__) => begin
        variability(subscript.slice)
      end

      SUBSCRIPT_WHOLE(__) => begin
        Variability.CONSTANT
      end
    end
  end
  return var
end

function expandList(
  subscripts::List{<:Subscript},
  dimensions::List{<:Dimension},
)::List{Subscript}
  local outSubscripts::List{Subscript} = nil
  local dim::Dimension
  local rest_dims::List{Dimension} = dimensions
  local sub::Subscript
  for s in subscripts
    @match Cons{Dimension}(dim, rest_dims) = rest_dims
    @match (sub, _) = expand(s, dim)
    outSubscripts = Cons{Subscript}(sub, outSubscripts)
  end
  for d in rest_dims
    sub = SUBSCRIPT_EXPANDED_SLICE(map(
      fromDim(d),
      makeIndex,
    ))
    outSubscripts = Cons{Subscript}(sub, outSubscripts)
  end
  outSubscripts = listReverseInPlace(outSubscripts)
  return outSubscripts
end

function expandSlice(subscript::Subscript)::Tuple{Subscript, Bool}
  local expanded::Bool
  local outSubscript::Subscript
  (outSubscript, expanded) = begin
    local exp::Expression
    @match subscript begin
      SUBSCRIPT_SLICE(__) => begin
        (exp, _) = expand(subscript.slice)
        if isArray(exp)
          outSubscript = SUBSCRIPT_EXPANDED_SLICE(list(
            SUBSCRIPT_INDEX(e) for e in arrayElements(exp)
          ))
          expanded = true
        else
          outSubscript = subscript
          expanded = false
        end
        (outSubscript, expanded)
      end
      _ => begin
        (subscript, false)
      end
    end
  end
  return (outSubscript, expanded)
end

function expand(subscript::Subscript, dimension::Dimension)::Tuple{Subscript, Bool}
  local expandedBool::Bool
  local outSubscript::Subscript
  (outSubscript, expandedBool) = begin
    local exp::Expression
    local iter::RangeIterator
    @match subscript begin
      SUBSCRIPT_SLICE(__) => begin
        expandSlice(subscript)
      end
      SUBSCRIPT_WHOLE(__) => begin
        iter = fromDim(dimension)
        if isValid(iter)
          outSubscript =
            SUBSCRIPT_EXPANDED_SLICE(map(iter, makeIndex))
          expandedBool= true
        else
          outSubscript = subscript
          expandedBool = false
        end
        (outSubscript, expandedBool)
      end
      _ => begin
        (subscript, true)
      end
    end
  end
  return (outSubscript, expandedBool)
end

function scalarizeList(
  subscripts::List{<:Subscript},
  dimensions::List{<:Dimension},
)::List{List{Subscript}}
  local outSubscripts::List{List{Subscript}} = nil

  local dim::Dimension
  local rest_dims::List{Dimension} = dimensions
  local subs::List{Subscript}

  for s in subscripts
    @match Cons{Dimension}(dim, rest_dims) = rest_dims
     subs = scalarize(s, dim)
    if listEmpty(subs)
       outSubscripts = nil
      return outSubscripts
    else
       outSubscripts = Cons{Subscript}(subs, outSubscripts)
    end
  end
  for d in rest_dims
    subs = map(fromDim(d), makeIndex)
    if listEmpty(subs)
       outSubscripts = nil
      return outSubscripts
    else
      outSubscripts = Cons{Cons{Subscript}}(subs, outSubscripts)
    end
  end
   outSubscripts = listReverse(outSubscripts)
  return outSubscripts
end

function scalarize(subscript::Subscript, dimension::Dimension)::List{Subscript}
  local subscripts::List{Subscript}

   subscripts = begin
    @match subscript begin
      SUBSCRIPT_INDEX(__) => begin
        list(subscript)
      end

      SUBSCRIPT_SLICE(__) => begin
        list(
          SUBSCRIPT_INDEX(e)
          for
          e in
            arrayElements(expand(subscript.slice))
        )
      end

      SUBSCRIPT_WHOLE(__) => begin
        P_RangeIterator.RangeIterator.map(
          P_RangeIterator.RangeIterator.fromDim(dimension),
          makeIndex,
        )
      end
    end
  end
  return subscripts
end

"""  Returns a dimension representing the size of the given subscript. """
function toDimension(subscript::Subscript)::Dimension
  local dimension::Dimension
  dimension = begin
    @match subscript begin
      SUBSCRIPT_INDEX(__) => begin
        fromInteger(1)
      end
      SUBSCRIPT_SLICE(__) => begin
        listHead(arrayDims(typeOf(subscript.slice)))
      end
      SUBSCRIPT_WHOLE(__) => begin
        DIMENSION_UNKNOWN()
      end
    end
  end
  return dimension
end

# function simplifySubscript(subscript::Subscript)::Subscript
#   local outSubscript::Subscript
#   outSubscript = begin
#     @match subscript begin
#       SUBSCRIPT_INDEX(__) => begin
#         SUBSCRIPT_INDEX(simplify(subscript.index))
#       end
#       SUBSCRIPT_SLICE(__) => begin
#         SUBSCRIPT_SLICE(simplify(subscript.slice))
#       end
#       _ => begin
#         subscript
#       end
#     end
#   end
#   return outSubscript
# end

"""
  New variant of simplify with two arguments
"""
function simplify(subscript::Subscript, dimension::Dimension)
  local outSubscript::Subscript
  outSubscript = begin
    @match subscript begin
      SUBSCRIPT_INDEX(__) => begin
        SUBSCRIPT_INDEX(simplify(subscript.index))
      end
      SUBSCRIPT_SLICE(__) => begin
        simplifySlice(subscript.slice, dimension)
      end
      _ => begin
        subscript
      end
    end
  end
  return outSubscript
end

"""Check if an expression is the lower bound of an array index (i.e. 1)."""
function expIsLowerBound(exp::Expression)::Bool
  return @match exp begin
    INTEGER_EXPRESSION(value = 1) => true
    _ => false
  end
end

"""Check if an expression equals the upper bound of a dimension."""
function expIsUpperBound(exp::Expression, dim::Dimension)::Bool
  return @match (exp, dim) begin
    (INTEGER_EXPRESSION(__), DIMENSION_INTEGER(__)) => exp.value == dim.size
    _ => false
  end
end

function simplifySlice(slice::Expression, dimension::Dimension)
  exp = simplify(slice)
  outSubscript = @match exp begin
    RANGE_EXPRESSION(__) where{(isNone(exp.step) || isOne(Util.getOption(exp.step))) && expIsLowerBound(exp.start) && expIsUpperBound(exp.stop, dimension)} => begin
      SUBSCRIPT_WHOLE()
    end
    _ => SUBSCRIPT_SLICE(exp)
  end
  return outSubscript
end

function simplifyList(subscripts::List, dimensions::List ; trim = false)
  local outSubscripts::List = nil
  if listEmpty(dimensions)
    outSubscripts = list(simplify(s, DIMENSION_UNKNOWN()) for s in subscripts)
  else
    rest_d = ListUtil.lastN(dimensions, listLength(subscripts))
    for s in subscripts
      @match d <| rest_d = rest_d;
      outSubscripts = simplify(s, d) <| outSubscripts
    end
    if trim
      outSubscripts = listReverseInPlace(ListUtil.trim(outSubscripts, isWhole))
    else
      outSubscripts = listReverseInPlace(outSubscripts)
    end
  end
  return outSubscripts
end


function evalSubscript(
  subscript::Subscript,
  target::EvalTarget = EVALTARGET_IGNORE_ERRORS(),
)::Subscript
  local outSubscript::Subscript
  outSubscript = begin
    @match subscript begin
      SUBSCRIPT_INDEX(__) => begin
        SUBSCRIPT_INDEX(evalExp(subscript.index, target))
      end
      SUBSCRIPT_SLICE(__) => begin
        SUBSCRIPT_SLICE(evalExp(subscript.slice, target))
      end
      _ => begin
        subscript
      end
    end
  end
  return outSubscript
end

function toFlatStringList(subscripts::List{<:Subscript}; inFunction = false)::String
  local string::String
  local fn = sub -> toFlatString(sub; inFunction = inFunction)
  string = ListUtil.toString(subscripts, fn, "", "[", ",", "]", false)
  return string
end

function toFlatString(subscript::Subscript; inFunction = false)
  local string::String

   string = begin
    @match subscript begin
      SUBSCRIPT_RAW_SUBSCRIPT(__) => begin
        Dump.printSubscriptStr(subscript.subscript)
      end

      SUBSCRIPT_UNTYPED(__) => begin
        toFlatString(subscript.exp; inFunction = inFunction)
      end

      SUBSCRIPT_INDEX(__) => begin
        toFlatString(subscript.index; inFunction = inFunction)
      end

      SUBSCRIPT_SLICE(__) => begin
        toFlatString(subscript.slice; inFunction = inFunction)
      end

      SUBSCRIPT_EXPANDED_SLICE(__) => begin
        ListUtil.toString(subscript.indices, toString, "", "{", ", ", "}", false)
      end

      SUBSCRIPT_WHOLE(__) => begin
        ":"
      end
    end
  end
  return string
end

function toStringList(::Nil)::String
  ""
end

function toStringList(subscripts::List{Subscript})::String
  local string::String
  string = ListUtil.toString(subscripts, toString, "", "[", ", ", "]", false)
  return string
end

function toString(subscript::Subscript)::String
  local string::String

   string = begin
    @match subscript begin
      SUBSCRIPT_RAW_SUBSCRIPT(__) => begin
        Dump.printSubscriptStr(subscript.subscript)
      end

      SUBSCRIPT_UNTYPED(__) => begin
        toString(subscript.exp)
      end

      SUBSCRIPT_INDEX(__) => begin
        toString(subscript.index)
      end

      SUBSCRIPT_SLICE(__) => begin
        toString(subscript.slice)
      end

      SUBSCRIPT_EXPANDED_SLICE(__) => begin
        ListUtil.toString(subscript.indices, toString, "", "{", ", ", "}", false)
      end

      SUBSCRIPT_WHOLE(__) => begin
        ":"
      end
    end
  end
  return string
end

function toDAEExp(subscript::Subscript)::DAE.Exp
  local daeExp::DAE.Exp

   daeExp = begin
    @match subscript begin
      SUBSCRIPT_INDEX(__) => begin
        toDAE(subscript.index)
      end

      SUBSCRIPT_SLICE(__) => begin
        toDAE(subscript.slice)
      end

      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " failed on unknown subscript '" + toString(subscript) + "'",
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return daeExp
end

function toDAE(subscript::Subscript)::DAE.Subscript
  local daeSubscript::DAE.Subscript

   daeSubscript = begin
    @match subscript begin
      SUBSCRIPT_INDEX(__) => begin
        DAE.INDEX(toDAE(subscript.index))
      end

      SUBSCRIPT_SLICE(__) => begin
        DAE.SLICE(toDAE(subscript.slice))
      end

      SUBSCRIPT_WHOLE(__) => begin
        DAE.WHOLEDIM()
      end

      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " failed on unknown subscript",
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return daeSubscript
end

function mapFoldExpShallow(subscript::Subscript, func::MapFunc, arg::ArgT) where {ArgT}
  local outSubscript::Subscript
  outSubscript = begin
    local exp::Expression
    @match subscript begin
      SUBSCRIPT_UNTYPED(__) => begin
        (exp, arg) = func(subscript.exp, arg)
        if referenceEq(subscript.exp, exp)
          subscript
        else
          SUBSCRIPT_UNTYPED(exp)
        end
      end
      SUBSCRIPT_INDEX(__) => begin
        (exp, arg) = func(subscript.index, arg)
        if referenceEq(subscript.index, exp)
          subscript
        else
          fromTypedExp(exp)
        end
      end
      SUBSCRIPT_SLICE(__) => begin
        (exp, arg) = func(subscript.slice, arg)
        if referenceEq(subscript.slice, exp)
          subscript
        else
          fromTypedExp(exp)
        end
      end
      _ => begin
        subscript
      end
    end
  end
  return (outSubscript, arg)
end


"""
```
mapFoldExpShallowO1
```
Same as ```mapFoldExpShallow``` but returns only one argument.
"""
function mapFoldExpShallowO1(subscript::Subscript, func::MapFunc, arg::ArgT) where {ArgT}
  local outSubscript::Subscript
  outSubscript = begin
    local exp::Expression
    @match subscript begin
      SUBSCRIPT_UNTYPED(__) => begin
        (exp, _) = func(subscript.exp, arg)
        if referenceEq(subscript.exp, exp)
          subscript
        else
          SUBSCRIPT_UNTYPED(exp)
        end
      end
      SUBSCRIPT_INDEX(__) => begin
        (exp, _) = func(subscript.index, arg)
        if referenceEq(subscript.index, exp)
          subscript
        else
          fromTypedExp(exp)
        end
      end
      SUBSCRIPT_SLICE(__) => begin
        (exp, _) = func(subscript.slice, arg)
        if referenceEq(subscript.slice, exp)
          subscript
        else
          fromTypedExp(exp)
        end
      end
      _ => begin
        subscript
      end
    end
  end
  return outSubscript
end


function mapFoldExp(subscript::Subscript, func::MapFunc, arg::ArgT) where {ArgT}

  local outSubscript::Subscript

   outSubscript = begin
    local exp::Expression
    @match subscript begin
      SUBSCRIPT_UNTYPED(__) => begin
         (exp, arg) = mapFold(subscript.exp, func, arg)
        if referenceEq(subscript.exp, exp)
          subscript
        else
          SUBSCRIPT_UNTYPED(exp)
        end
      end

      SUBSCRIPT_INDEX(__) => begin
         (exp, arg) = mapFold(subscript.index, func, arg)
        if referenceEq(subscript.index, exp)
          subscript
        else
          fromTypedExp(exp)
        end
      end

      SUBSCRIPT_SLICE(__) => begin
         (exp, arg) = mapFold(subscript.slice, func, arg)
        if referenceEq(subscript.slice, exp)
          subscript
        else
          fromTypedExp(exp)
        end
      end

      _ => begin
        subscript
      end
    end
  end
  return (outSubscript, arg)
end

function foldExp(subscript::Subscript, func::FoldFunc, arg::ArgT) where {ArgT}
  local result = begin
    @match subscript begin
      SUBSCRIPT_UNTYPED(__) => begin
        fold(subscript.exp, func, arg)
      end

      SUBSCRIPT_INDEX(__) => begin
        fold(subscript.index, func, arg)
      end

      SUBSCRIPT_SLICE(__) => begin
        fold(subscript.slice, func, arg)
      end

      _ => begin
        arg
      end
    end
  end
  return result
end

function mapShallowExp(subscript::Subscript, func::MapFunc)::Subscript
  local outSubscript::Subscript

   outSubscript = begin
    local e1::Expression
    local e2::Expression
    @match subscript begin
      SUBSCRIPT_UNTYPED(exp = e1) => begin
         e2 = func(e1)
        if referenceEq(e1, e2)
          subscript
        else
          SUBSCRIPT_UNTYPED(e2)
        end
      end

      SUBSCRIPT_INDEX(index = e1) => begin
         e2 = func(e1)
        if referenceEq(e1, e2)
          subscript
        else
          fromTypedExp(e2)
        end
      end

      SUBSCRIPT_SLICE(slice = e1) => begin
         e2 = func(e1)
        if referenceEq(e1, e2)
          subscript
        else
          fromTypedExp(e2)
        end
      end

      _ => begin
        subscript
      end
    end
  end
  return outSubscript
end

function mapExp(subscript::Subscript, func::MapFunc)::Subscript
  local outSubscript::Subscript

   outSubscript = begin
    local e1::Expression
    local e2::Expression
    @match subscript begin
      SUBSCRIPT_UNTYPED(exp = e1) => begin
        e2 = map(e1, func)
        if referenceEq(e1, e2)
          subscript
        else
          SUBSCRIPT_UNTYPED(e2)
        end
      end

      SUBSCRIPT_INDEX(index = e1) => begin
        e2 = map(e1, func)
        if referenceEq(e1, e2)
          subscript
        else
          fromTypedExp(e2)
        end
      end

      SUBSCRIPT_SLICE(slice = e1) => begin
         e2 = map(e1, func)
        if referenceEq(e1, e2)
          subscript
        else
          fromTypedExp(e2)
        end
      end

      _ => begin
        subscript
      end
    end
  end
  return outSubscript
end

function applyExp(subscript::Subscript, func::ApplyFunc)
  return  () = begin
    @match subscript begin
      SUBSCRIPT_UNTYPED(__) => begin
        apply(subscript.exp, func)
        ()
      end

      SUBSCRIPT_INDEX(__) => begin
        apply(subscript.index, func)
        ()
      end

      SUBSCRIPT_SLICE(__) => begin
        apply(subscript.slice, func)
        ()
      end

      _ => begin
        ()
      end
    end
  end
end

function listContainsExpShallow(
  subscripts::List{<:Subscript},
  func::ContainsPred,
)::Bool
  local res::Bool

  for s in subscripts
    if containsExpShallow(s, func)
       res = true
      return res
    end
  end
   res = false
  return res
end

function containsExpShallow(
  subscript::Subscript,
  func::ContainsPred,
)::Bool
  local res::Bool

   res = begin
    @match subscript begin
      SUBSCRIPT_UNTYPED(__) => begin
        func(subscript.exp)
      end

      SUBSCRIPT_INDEX(__) => begin
        func(subscript.index)
      end

      SUBSCRIPT_SLICE(__) => begin
        func(subscript.slice)
      end

      _ => begin
        false
      end
    end
  end
  return res
end

function listContainsExp(
  subscripts::List{<:Subscript},
  func::ContainsPred,
)::Bool
  local res::Bool

  for s in subscripts
    if containsExp(s, func)
       res = true
      return res
    end
  end
   res = false
  return res
end

function containsExp(subscript::Subscript, func::ContainsPred)::Bool
  local res::Bool

   res = begin
    @match subscript begin
      SUBSCRIPT_UNTYPED(__) => begin
        contains(subscript.exp, func)
      end

      SUBSCRIPT_INDEX(__) => begin
        contains(subscript.index, func)
      end

      SUBSCRIPT_SLICE(__) => begin
        contains(subscript.slice, func)
      end

      _ => begin
        false
      end
    end
  end
  return res
end


function compareList(
  subscripts1::Nil,
  subscripts2::Nil
  )::Int
  return 0
end

function compareList(
  subscripts1::Nil,
  subscripts2::Cons{<:Subscript},
  )::Int
  return 1
end

function compareList(
  subscripts1::Cons{<:Subscript},
  subscripts2::Nil,
  )::Int
  return 1
end

function compareList(
  subscripts1::Cons{<:Subscript},
  subscripts2::Cons{<:Subscript},
)::Int
  local comp::Int

  local s2::Subscript
  local rest_s2::List{Subscript} = subscripts2

   comp = Util.intCompare(listLength(subscripts1), listLength(subscripts2))
  if comp != 0
    return comp
  end
  for s1 in subscripts1
    @match Cons{Subscript}(s2, rest_s2) = rest_s2
     comp = compare(s1, s2)
    if comp != 0
      return comp
    end
  end
   comp = 0
  return comp
end

function compare(subscript1::Subscript, subscript2::Subscript)::Int
  local comp::Int

  if referenceEq(subscript1, subscript2)
     comp = 0
    return comp
  end
   comp = Util.intCompare(valueConstructor(subscript1), valueConstructor(subscript2))
  if comp != 0
    return comp
  end
   comp = begin
    local e::Expression
    @match subscript1 begin
      SUBSCRIPT_UNTYPED(__) => begin
        @match SUBSCRIPT_UNTYPED(exp = e) = subscript2
        compare(subscript1.exp, e)
      end

      SUBSCRIPT_INDEX(__) => begin
        @match SUBSCRIPT_INDEX(index = e) = subscript2
        compare(subscript1.index, e)
      end

      SUBSCRIPT_SLICE(__) => begin
        @match SUBSCRIPT_SLICE(slice = e) = subscript2
        compare(subscript1.slice, e)
      end

      SUBSCRIPT_WHOLE(__) => begin
        0
      end
    end
  end
  return comp
end

function isEqualList(subscripts1::List{<:Subscript}, subscripts2::List{<:Subscript})::Bool
  local eq::Bool
  local s2::Subscript
  local rest::List{Subscript} = subscripts2
  for s1 in subscripts1
    if listEmpty(rest)
       eq = false
      return eq
    end
    @match Cons{Subscript}(s2, rest) = rest
    if !isEqual(s1, s2)
       eq = false
      return eq
    end
  end
   eq = listEmpty(rest)
  return eq
end

function isEqual(subscript1::Subscript, subscript2::Subscript)::Bool
  local eq::Bool

   eq = begin
    @match (subscript1, subscript2) begin
      (SUBSCRIPT_RAW_SUBSCRIPT(__), SUBSCRIPT_RAW_SUBSCRIPT(__)) => begin
        AbsynUtil.subscriptEqual(subscript1.subscript, subscript2.subscript)
      end

      (SUBSCRIPT_UNTYPED(__), SUBSCRIPT_UNTYPED(__)) => begin
        isEqual(subscript1.exp, subscript2.exp)
      end

      (SUBSCRIPT_INDEX(__), SUBSCRIPT_INDEX(__)) => begin
        isEqual(subscript1.index, subscript2.index)
      end

      (SUBSCRIPT_SLICE(__), SUBSCRIPT_SLICE(__)) => begin
        isEqual(subscript1.slice, subscript2.slice)
      end

      (SUBSCRIPT_WHOLE(__), SUBSCRIPT_WHOLE(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return eq
end

function isScalarLiteral(sub::Subscript)::Bool
  local isScalarLiteral::Bool
   isScalarLiteral = begin
    @match sub begin
      SUBSCRIPT_INDEX(__) => begin
        isScalarLiteral(sub.index)
      end
      _ => begin
        false
      end
    end
  end
  return isScalarLiteral
end

function isScalar(sub::Subscript)::Bool
  local isScalar::Bool
   isScalar = begin
    local ty::M_Type
    @match sub begin
      SUBSCRIPT_INDEX(__) => begin
         ty = typeOf(sub.index)
        isValidIndexType(ty)
      end

      _ => begin
        false
      end
    end
  end
  return isScalar
end

function isWhole(sub::Subscript)::Bool
  local isWhole::Bool
   isWhole = begin
    @match sub begin
      SUBSCRIPT_WHOLE(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isWhole
end

function isIndex(sub::Subscript)::Bool
  local isIndex::Bool
   isIndex = begin
    @match sub begin
      SUBSCRIPT_INDEX(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isIndex
end

function makeIndex(exp::Expression)::Subscript
  local subscript::Subscript
  local ty::M_Type
   ty = typeOf(exp)
  if isValidIndexType(ty)
     subscript = SUBSCRIPT_INDEX(exp)
  else
    Error.assertion(
      false,
      getInstanceName() + " got a non integer type exp to make an index sub",
      sourceInfo(),
    )
    fail()
  end
  return subscript
end

function isLiteral(sub::Subscript)
  local literal::Bool
  literal = @match sub begin
    SUBSCRIPT_UNTYPED(__) => isLiteral(sub.exp)
    SUBSCRIPT_INDEX(__) => isLiteral(sub.index)
    SUBSCRIPT_SLICE(__) => isLiteral(sub.slice)
    SUBSCRIPT_WHOLE(__) => true
    _ => false
  end
  return literal
end

function isSplit(sub::Subscript)
  res = @match sub begin
    SPLIT_PROXY(__) => true
    SPLIT_INDEX(__) => true
  end
  return res
end

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

abstract type RangeIterator end

struct RANGEITERATOR_INVALID_RANGE <: RangeIterator
  exp::Expression
end

struct RANGEITERATOR_ARRAY_RANGE <: RangeIterator
  values::List{Expression}
end

"""
An iterator over a Real range: `steps` values `start + stepsize * current`, `current` counting from 0. The fields are
concrete (`Float64`, `Int`), as every constructor call passes them, so a matched iterator's arithmetic is inferred: the
type parameters they had (`T0 <: AbstractFloat`, `T1 <: Integer`) left `current + 1` a dynamic `+(::Integer, ::Int)`,
which a package adding `+` methods invalidated with all its callers at each load (2026-11-16).
"""
struct RANGEITERATOR_REAL_RANGE <: RangeIterator
  start::Float64
  stepsize::Float64
  current::Int
  steps::Int
end

"""An iterator over an Integer range with a step (concrete `Int` fields, see `RANGEITERATOR_REAL_RANGE`)."""
struct RANGEITERATOR_INT_STEP_RANGE <: RangeIterator
  current::Int
  stepsize::Int
  last::Int
end

"""An iterator over an Integer range `current:last` (concrete `Int` fields, see `RANGEITERATOR_REAL_RANGE`)."""
struct RANGEITERATOR_INT_RANGE <: RangeIterator
  current::Int
  last::Int
end

function fold(iterator::RangeIterator, func::FuncT, arg::ArgT) where {ArgT}
  local iter::RangeIterator = iterator
  local exp::Expression
  while hasNext(iter)
    (iter, exp) = next(iter)
    arg = func(exp, arg)
  end
  return arg
end

function map(iterator::RangeIterator, func::FuncT)
  local lst::List{Subscript} = nil
  local iter::RangeIterator = iterator
  local exp::Expression
  while hasNext(iter)
    (iter, exp) = next(iter)
    lst = Cons{Subscript}(func(exp), lst)
  end
  tmp = lst
  lst = nil
  while tmp !== nil
    @match Cons{Subscript}(s, tmp) = tmp
    lst = Cons{Subscript}(s, lst)
  end
  return lst
end

function toListReverse(iterator::RangeIterator)::List{Expression}
  local expl::List{Expression} = nil
  local iter::RangeIterator = iterator
  local exp::Expression
  while hasNext(iter)
     (iter, exp) = next(iter)
    expl = _cons(exp, expl)
  end
  return expl
end

function toList(iterator::RangeIterator)::List{Expression}
  local expl::List{Expression} = listReverse(toListReverse(iterator))
  return expl
end

"""
    hasNext(iterator)

Whether `iterator` has another value. The counters are read as `Int` (the iterators of Integer and Real ranges count
in `Int`): read through the abstract `RangeIterator`, `iterator.current <= iterator.last` was a dynamic comparison,
which packages adding comparison methods invalidated with its callers at each load (2026-11-16).
"""
function hasNext(iterator::RangeIterator)::Bool
  local hasNext::Bool
  hasNext = begin
    @match iterator begin
      RANGEITERATOR_INT_RANGE(__) => begin
        (iterator.current::Int) <= (iterator.last::Int)
      end
      RANGEITERATOR_INT_STEP_RANGE(__) => begin
        if (iterator.stepsize::Int) > 0
          (iterator.current::Int) <= (iterator.last::Int)
        else
          (iterator.current::Int) >= (iterator.last::Int)
        end
      end
      RANGEITERATOR_REAL_RANGE(__) => begin
        (iterator.current::Int) < (iterator.steps::Int)
      end
      RANGEITERATOR_ARRAY_RANGE(__) => begin
        !listEmpty(iterator.values)
      end
      RANGEITERATOR_INVALID_RANGE(__) => begin
        Error.assertion(
          false,
          getInstanceName() +
          " got invalid range " +
          toString(iterator.exp),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return hasNext
end

function next(iterator::RangeIterator)::Tuple{RangeIterator, Expression}
  local nextExp::Expression
  nextExp = begin
    @match iterator begin
      RANGEITERATOR_INT_RANGE(__) => begin
        nextExp = INTEGER_EXPRESSION(iterator.current::Int)
        @assign iterator.current = (iterator.current::Int) + 1
        nextExp
      end

      RANGEITERATOR_INT_STEP_RANGE(__) => begin
        nextExp = INTEGER_EXPRESSION(iterator.current::Int)
        @assign iterator.current = (iterator.current::Int) + (iterator.stepsize::Int)
        nextExp
      end

      RANGEITERATOR_REAL_RANGE(__) => begin
        nextExp = REAL_EXPRESSION(
          (iterator.start::Float64) + (iterator.stepsize::Float64) * (iterator.current::Int),
        )
        @assign iterator.current = (iterator.current::Int) + 1
        nextExp
      end

      RANGEITERATOR_ARRAY_RANGE(__) => begin
        nextExp = listHead(iterator.values)
        @assign iterator.values = listRest(iterator.values)
        nextExp
      end

      RANGEITERATOR_INVALID_RANGE(__) => begin
        Error.assertion(
          false,
          getInstanceName() +
          " got invalid range " +
          toString(iterator.exp),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return (iterator, nextExp)
end

function fromDim(dim::Dimension)::RangeIterator
  local iterator::RangeIterator
  iterator = begin
    local ty::ModelicaType
    @match dim begin
      DIMENSION_INTEGER(__) => begin
        RANGEITERATOR_INT_RANGE(1, dim.size)
      end

      DIMENSION_BOOLEAN(__) => begin
        RANGEITERATOR_ARRAY_RANGE(list(
          BOOLEAN_EXPRESSION(false),
          BOOLEAN_EXPRESSION(true),
        ))
      end

       DIMENSION_ENUM(enumType = ty && TYPE_ENUMERATION(__)) => begin
        RANGEITERATOR_ARRAY_RANGE(makeEnumLiterals(ty))
      end

      #= RangeIterator_fromExp: fromExp is Subscript's in this namespace (a SUBSCRIPT_UNTYPED
         where an iterator was expected) =#
      DIMENSION_EXP(__) => begin
        RangeIterator_fromExp(dim.exp)
      end

      _ => begin
        Error.assertion(false, getInstanceName() + " got unknown dim", sourceInfo())
        fail()
      end
    end
  end
  return iterator
end

"""
Returns a RangeIterator created from the given expression. If the
expression isn't an expression that can be expanded into elements an
invalid range will be returned that will trigger an assertion when used.
The valididity of the returned iterator can be checked with isValid.
"""
function RangeIterator_fromExp(@nospecialize(exp::Expression))::RangeIterator
  local iterator::RangeIterator
  @assign iterator = begin
    local istart::Int
    local istep::Int
    local istop::Int
    local rstart::AbstractFloat
    local rstep::AbstractFloat
    local rstop::AbstractFloat
    local ty::ModelicaType
    local literals::List{String}
    local values::List{Expression}
    @match exp begin
      ARRAY_EXPRESSION(__) => begin
        RANGEITERATOR_ARRAY_RANGE(arrayList(exp.elements))
      end

      RANGE_EXPRESSION(
        start = INTEGER_EXPRESSION(istart),
        step = SOME(INTEGER_EXPRESSION(istep)),
        stop = INTEGER_EXPRESSION(istop),
      ) => begin
        RANGEITERATOR_INT_STEP_RANGE(istart, istep, istop)
      end

      RANGE_EXPRESSION(
        start = INTEGER_EXPRESSION(istart),
        step = NONE(),
        stop = INTEGER_EXPRESSION(istop),
      ) => begin
        RANGEITERATOR_INT_RANGE(istart, istop)
      end

      RANGE_EXPRESSION(
        start = REAL_EXPRESSION(rstart),
        step = SOME(REAL_EXPRESSION(rstep)),
        stop = REAL_EXPRESSION(rstop),
      ) => begin
        RANGEITERATOR_REAL_RANGE(rstart, rstep, 0, Util.realRangeSize(rstart, rstep, rstop))
      end

      RANGE_EXPRESSION(
        start = REAL_EXPRESSION(rstart),
        step = NONE(),
        stop = REAL_EXPRESSION(rstop),
      ) => begin
        RANGEITERATOR_REAL_RANGE(rstart, 1.0, 0, Util.realRangeSize(rstart, 1.0, rstop))
      end

      #= false:true, true:true, false:false, or empty (true:false), as omc. =#
      RANGE_EXPRESSION(
        start = BOOLEAN_EXPRESSION(__),
        stop = BOOLEAN_EXPRESSION(__),
      ) => begin
        local bvals::List{Expression} = nil
        for b in (true, false)
          exp.start.value <= b <= exp.stop.value && (bvals = Cons{Expression}(BOOLEAN_EXPRESSION(b), bvals))
        end
        RANGEITERATOR_ARRAY_RANGE(bvals)
      end

      RANGE_EXPRESSION(
        start = ENUM_LITERAL_EXPRESSION(ty = ty, index = istart),
        step = NONE(),
        stop = ENUM_LITERAL_EXPRESSION(index = istop),
      ) => begin
        @match TYPE_ENUMERATION(typePath = _, literals = literals) = ty
        values = nil
        if istart <= istop
          for i = 2:istart
            literals = listRest(literals)
          end
          for i = istart:istop
            values = _cons(
              ENUM_LITERAL_EXPRESSION(ty, listHead(literals), i),
              values,
            )
            literals = listRest(literals)
          end
          values = listReverse(values)
        end
        RANGEITERATOR_ARRAY_RANGE(values)
      end

      TYPENAME_EXPRESSION(
        ty = TYPE_ARRAY(elementType = ty && TYPE_ENUMERATION(literals = literals)),
      ) => begin
        #= enumeration type based range =#
        values = nil
        istep = 0
        for l in literals
          istep = istep + 1
          values =
            _cons(ENUM_LITERAL_EXPRESSION(ty, l, istep), values)
        end
        RANGEITERATOR_ARRAY_RANGE(values)
      end

      _ => begin
        RANGEITERATOR_INVALID_RANGE(exp)
      end
    end
  end
  return iterator
end

function isValid(iterator::RangeIterator)::Bool
  local valid::Bool
  valid = begin
    @match iterator begin
      RANGEITERATOR_INVALID_RANGE(__) => begin
        false
      end
      _ => begin
        true
      end
    end
  end
  return valid
end

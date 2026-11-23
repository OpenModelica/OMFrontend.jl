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

#= Shared for scalar components; dimension typing writes by index, so an
   empty vector is never mutated. =#
const EMPTY_RAW_DIMS = Dimension[]

using OpenModelicaParser.Absyn: Exp, Path #, Subscript

function foldExpList(dims::List{Dimension}, func::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}
  for dim in dims
    arg = foldExp(dim, func, arg, ArgT)
  end
  return arg
end

function foldExp(dim::Dimension, func::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}
  @match dim begin
    DIMENSION_UNTYPED(__) => fold(dim.dimension, func, arg, ArgT)
    DIMENSION_EXP(__) => fold(dim.exp, func, arg, ArgT)
    _ => arg
  end
end

@nospecialized function mapExp(dim::Dimension, func::MapFunc)::Dimension
  local e1::Expression
  local e2::Expression
  @match dim begin
    DIMENSION_UNTYPED(dimension = e1) => begin
      e2 = map(e1, func)
      if referenceEq(e1, e2)
        dim
      else
        DIMENSION_UNTYPED(e2, dim.isProcessing)
      end
    end

    DIMENSION_EXP(exp = e1) => begin
      e2 = map(e1, func)
      if referenceEq(e1, e2)
        dim
      else
        fromExp(e2, dim.var)
      end
    end

    _ => dim
  end
end

function variability(dim::Dimension)::VariabilityType

  @match dim begin
    DIMENSION_INTEGER(__) => dim.var

    DIMENSION_BOOLEAN(__) => Variability.CONSTANT

    DIMENSION_ENUM(__) => Variability.CONSTANT

    DIMENSION_EXP(__) => dim.var

    DIMENSION_UNKNOWN(__) => Variability.CONTINUOUS
  end
end

"""Whether `sizeExp(dim)` is defined: an integer, Boolean, enumeration or expression dimension."""
function hasSizeExp(dim::Dimension)::Bool
  local tag::DimensionTag = dim.tag
  return tag == DIMENSION_INTEGER_TAG || tag == DIMENSION_BOOLEAN_TAG || tag == DIMENSION_EXP_TAG ||
         (tag == DIMENSION_ENUM_TAG && isvariant(dim.enumType, TYPE_ENUMERATION))
end

"""Returns the size of a dimension as an Expression."""
function sizeExp(dim::Dimension)::Expression

  local ty::ModelicaType
  @match dim begin
    DIMENSION_INTEGER(__) => INTEGER_EXPRESSION(dim.size)

    DIMENSION_BOOLEAN(__) => INTEGER_EXPRESSION(2)

    DIMENSION_ENUM(enumType = ty && TYPE_ENUMERATION(__)) => INTEGER_EXPRESSION(listLength(ty.literals))

    DIMENSION_EXP(__) => dim.exp
  end
end

"""Returns an expression for the last index in a dimension."""
function endExp(dim::Dimension, cref::ComponentRef, index::Int)::Expression

  local ty::ModelicaType
  @match dim begin
    DIMENSION_INTEGER(__) => INTEGER_EXPRESSION(dim.size)

    DIMENSION_BOOLEAN(__) => BOOLEAN_EXPRESSION(true)

    DIMENSION_ENUM(enumType = ty && TYPE_ENUMERATION(__)) => makeEnumLiteral(ty, listLength(ty.literals))

    #= The dimension's expression may name a record field (V_flow[n] of a function's record
       input: pressure.n), which the function's replacements do not know: size() of the
       array instead (Buildings.Fluid.Movers.BaseClasses.Euler.power: pressure.V_flow[end]).
       Not a ragged one (its values over the enclosing arrays of components, typeDimensionUntyped):
       size() of the element's array. =#
    DIMENSION_EXP(__) where {isLiteral(dim.exp) && !(dim.exp isa ARRAY_EXPRESSION)} => dim.exp

    DIMENSION_EXP(__) || DIMENSION_UNKNOWN(__) => begin
      SIZE_EXPRESSION(
        CREF_EXPRESSION(
          TYPE_UNKNOWN(),
          stripSubscripts(cref)[1],
        ),
        SOME(INTEGER_EXPRESSION(index)),
      )
    end
  end
end

function toStringList(dims::List{<:Dimension})::String
  local parts = String[toString(d) for d in dims]
  local str::String = "[" * Base.join(parts, ", ") * "]"
  return str
end

function toString(dim::Dimension)::String

  local ty::ModelicaType
  @match dim begin
    DIMENSION_INTEGER(__) => string(dim.size)

    DIMENSION_BOOLEAN(__) => "Boolean"

    DIMENSION_ENUM(enumType = ty && TYPE_ENUMERATION(__)) => AbsynUtil.pathString(ty.typePath)

    DIMENSION_EXP(__) => toString(dim.exp)

    DIMENSION_UNKNOWN(__) => ":"

    DIMENSION_UNTYPED(__) => toString(dim.dimension)
  end
end

"""
Same as toString for now
"""
function toFlatString(dim::Dimension)::String

  local ty::ModelicaType
  @match dim begin
    DIMENSION_INTEGER(__) => string(dim.size)

    DIMENSION_BOOLEAN(__) => "Boolean"

    DIMENSION_ENUM(enumType = ty && TYPE_ENUMERATION(__)) => AbsynUtil.pathString(ty.typePath)

    DIMENSION_EXP(__) => toFlatString(dim.exp)

    DIMENSION_UNKNOWN(__) => ":"

    DIMENSION_UNTYPED(__) => toString(dim.dimension)
  end
end

"""Returns the expected type of a subscript for the given dimension."""
function subscriptType(dim::Dimension)::ModelicaType
  @match dim begin
    DIMENSION_INTEGER(__) => TYPE_INTEGER()
    DIMENSION_BOOLEAN(__) => TYPE_BOOLEAN()
    DIMENSION_ENUM(__) => dim.enumType
    #= A ragged dimension's values are its elements' sizes (typeDimensionUntyped). =#
    DIMENSION_EXP(__) => arrayElementType(typeOf(dim.exp))
    _ => TYPE_UNKNOWN()
  end
end

function isOne(dim::Dimension)::Bool

  @match dim begin
    DIMENSION_INTEGER(__) => dim.size == 1
    DIMENSION_ENUM(__) => enumSize(dim.enumType) == 1

    _ => false
  end
end

function isZero(dim::Dimension)::Bool
  @match dim begin
    DIMENSION_INTEGER(__) => dim.size == 0
    DIMENSION_ENUM(__) => enumSize(dim.enumType) == 0
    _ => false
  end
end

isUnknown(dim::Dimension)::Bool = isvariant(dim, DIMENSION_UNKNOWN)

function isKnown(dim::Dimension, allowExp::Bool = false)::Bool
  @match dim begin
    DIMENSION_INTEGER(__) => true
    DIMENSION_BOOLEAN(__) => true
    DIMENSION_ENUM(__) => true
    DIMENSION_EXP(__) => allowExp
    _ => false
  end
end

function isEqualKnown(dim1::Dimension, dim2::Dimension)::Bool
  local isEqual::Bool

  isEqual = begin
    @match (dim1, dim2) begin
      (DIMENSION_UNKNOWN(__), _) => false

      (_, DIMENSION_UNKNOWN(__)) => false

      (DIMENSION_EXP(__), DIMENSION_EXP(__)) => isEqual(dim1.exp, dim2.exp)

      (DIMENSION_EXP(__), _) => false

      (_, DIMENSION_EXP(__)) => false

      _ => size(dim1) == size(dim2)
    end
  end
  return isEqual
end

function isEqual(dim1::Dimension, dim2::Dimension)::Bool
  @match (dim1, dim2) begin
    (DIMENSION_UNKNOWN(__), _) => true
    (_, DIMENSION_UNKNOWN(__)) => true
    (DIMENSION_EXP(__), DIMENSION_EXP(__)) => isEqual(dim1.exp, dim2.exp)
    (DIMENSION_EXP(__), _) => true
    (_, DIMENSION_EXP(__)) => true
    _ => size(dim1) == size(dim2)
  end
end

function size(dim::Dimension)::Int
  local ty::ModelicaType
  @match dim begin
    DIMENSION_INTEGER(__) => dim.size

    DIMENSION_BOOLEAN(__) => 2
    DIMENSION_ENUM(enumType = ty && TYPE_ENUMERATION(__)) => listLength(ty.literals)
  end
end

function add(a::Dimension, b::Dimension)::Dimension
  @match (a, b) begin
    (DIMENSION_UNKNOWN(__), _) => DIMENSION_UNKNOWN()

    (_, DIMENSION_UNKNOWN(__)) => DIMENSION_UNKNOWN()

    (DIMENSION_INTEGER(__), DIMENSION_INTEGER(__)) => DIMENSION_INTEGER(a.size + b.size, variabilityMax(a.var, b.var))

    (DIMENSION_INTEGER(__), DIMENSION_EXP(__)) => begin
      DIMENSION_EXP(
        BINARY_EXPRESSION(
          b.exp,
          OPERATOR(TYPE_INTEGER(), Op.ADD),
          INTEGER_EXPRESSION(a.size),
        ),
        b.var,
      )
    end

    (DIMENSION_EXP(__), DIMENSION_INTEGER(__)) => begin
      DIMENSION_EXP(
        BINARY_EXPRESSION(
          a.exp,
          OPERATOR(TYPE_INTEGER(), Op.ADD),
          INTEGER_EXPRESSION(b.size),
        ),
        a.var,
      )
    end

    (DIMENSION_EXP(__), DIMENSION_EXP(__)) => begin
      DIMENSION_EXP(
        BINARY_EXPRESSION(
          a.exp,
          OPERATOR(TYPE_INTEGER(), Op.ADD),
          b.exp,
        ),
        variabilityMax(a.var, b.var),
      )
    end

    _ => DIMENSION_UNKNOWN()
  end
end

function fromExpList(expl::Union{Vector{Expression}, List{<:Expression}})::Dimension
  local dim::Dimension = DIMENSION_INTEGER(length(expl), Variability.CONSTANT)
  return dim
end

function fromInteger(n::Int, var::VariabilityType = Variability.CONSTANT)::Dimension
  local dim::Dimension = DIMENSION_INTEGER(n, var)
  return dim
end

function fromExp(@nospecialize(exp::Expression), var::VariabilityType)::Dimension
  local ty::ModelicaType
  @match exp begin
    INTEGER_EXPRESSION(__) => DIMENSION_INTEGER(exp.value, var)
    TYPENAME_EXPRESSION(ty = TYPE_ARRAY(elementType = ty)) => begin
      begin
        @match ty begin
          TYPE_BOOLEAN(__) => DIMENSION_BOOLEAN()
          TYPE_ENUMERATION(__) => DIMENSION_ENUM(ty)
          _ => begin
            Error.assertion(
              false,
              getInstanceName() + " got invalid typename",
              sourceInfo(),
            )
            fail()
          end
        end
      end
    end
    _ => DIMENSION_EXP(exp, var)
  end
end

#= Backported =#

#= The first index of a dimension (omc Dimension.lowerBoundExp). =#
function lowerBoundExp(dim::Dimension)::Expression
  @match dim begin
    DIMENSION_BOOLEAN(__) => BOOLEAN_EXPRESSION(false)
    DIMENSION_ENUM(__) => makeEnumLiteral(dim.enumType, 1)
    _ => INTEGER_EXPRESSION(1)
  end
end

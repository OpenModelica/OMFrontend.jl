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

struct FunctionTypeStruct
  FUNCTIONAL_PARAMETER::Int
  FUNCTION_REFERENCE::Int
  FUNCTIONAL_VARIABLE::Int
end
const FunctionType = FunctionTypeStruct(1, 2, 3)

abstract type NFType end

struct TYPE_SUBSCRIPTED  <: NFType
  name::String
  ty::M_Type
  subs::List{M_Type}
  subscriptedTy::M_Type
end

struct TYPE_ANY  <: NFType
end

struct TYPE_POLYMORPHIC  <: NFType
  name::String
end

struct TYPE_METABOXED  <: NFType
  ty::M_Type
end

mutable struct TYPE_FUNCTION  <: NFType
  fn::M_Function
  #= Specified by the function type struct. =#
  fnType::Int
end

struct TYPE_COMPLEX  <: NFType
  cls::InstNode
  complexTy::ComplexType
end

struct TYPE_UNKNOWN  <: NFType
end

struct TYPE_NORETCALL  <: NFType
end

struct TYPE_TUPLE  <: NFType
  types::List{M_Type}
  names::Option{List{String}}
end

mutable struct TYPE_ARRAY  <: NFType
  elementType::M_Type
  dimensions::List{Dimension}
end

struct TYPE_ENUMERATION_ANY  <: NFType
end

mutable struct TYPE_ENUMERATION  <: NFType
  typePath::Absyn.Path
  literals::List{String}
end

struct TYPE_CLOCK  <: NFType
end

struct TYPE_BOOLEAN  <: NFType
end

struct TYPE_STRING  <: NFType
end

struct TYPE_REAL  <: NFType
end

struct TYPE_INTEGER  <: NFType
end

function subscriptedTypeName(@nospecialize(expType::M_Type), subscriptTypes::List{<:M_Type})::String
  local str::String
  local strl::List{String}
  @assign strl = list(toString(t) for t in subscriptTypes)
  @assign strl = _cons("_", strl)
  @assign strl = _cons(toString(expType), strl)
  @assign strl = _cons("subscript", strl)
  @assign str = stringAppendList(strl)
  return str
end

function sizeType(@nospecialize(arrayTy::M_Type))::M_Type
  local sizeTy::M_Type

  if isUnknown(arrayTy)
    @assign sizeTy = TYPE_UNKNOWN()
  else
    @assign sizeTy = TYPE_ARRAY(
      TYPE_INTEGER(),
      list(fromInteger(dimensionCount(arrayTy))),
    )
  end
  #=  Return unknown type if the type is unknown, to avoid returning Array[0]
  =#
  #=  for untyped expressions.
  =#
  return sizeTy
end

function isBoxed(@nospecialize(ty::M_Type))::Bool
  local isBoxed::Bool

  @assign isBoxed = begin
    @match ty begin
      TYPE_METABOXED(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isBoxed
end

function unbox(@nospecialize(ty::M_Type))::M_Type
  local unboxedType::M_Type

  @assign unboxedType = begin
    @match ty begin
      TYPE_METABOXED(__) => begin
        ty.ty
      end

      _ => begin
        ty
      end
    end
  end
  return unboxedType
end

function box(@nospecialize(ty::M_Type))::M_Type
  local boxedType::M_Type

  @assign boxedType = begin
    @match ty begin
      TYPE_METABOXED(__) => begin
        ty
      end

      _ => begin
        TYPE_METABOXED(ty)
      end
    end
  end
  return boxedType
end

function enumSize(@nospecialize(ty::M_Type))::Int
  local size::Int
  local literals::List{String}
  @match TYPE_ENUMERATION(literals = literals) = ty
  @assign size = listLength(literals)
  return size
end

function enumName(@nospecialize(ty::M_Type))::Absyn.Path
  local name::Absyn.Path
  @match TYPE_ENUMERATION(typePath = name) = ty
  return name
end

function setRecordFields(fields::List{<:Field}, @nospecialize(recordType::M_Type))::M_Type
  @assign recordType = begin
    local rec_node::InstNode
    @match recordType begin
      COMPLEX(complexTy = COMPLEX_RECORD(constructor = rec_node)) => begin
        COMPLEX(recordType.cls, COMPLEX_RECORD(rec_node, fields))
      end

      _ => begin
        recordType
      end
    end
  end
  return recordType
end

function recordFields(@nospecialize(recordType::M_Type))::List{Field}
  local fields::List{Field}

  @assign fields = begin
    @match recordType begin
      TYPE_COMPLEX(complexTy = COMPLEX_RECORD(fields = fields)) => begin
        fields
      end

      _ => begin
        nil
      end
    end
  end
  return fields
end

@nospecializeinfer function lookupRecordFieldType(name::String, @nospecialize(recordType::M_Type))::M_Type
  local fieldType::M_Type

  @assign fieldType = begin
    @match recordType begin
      TYPE_COMPLEX(__) => begin
        entryInfo = lookupElement(name, getClass(recordType.cls))
        getType(entryInfo.node)
      end

      TYPE_ARRAY(__) => begin
        liftArrayLeftList(
          lookupRecordFieldType(name, recordType.elementType),
          recordType.dimensions,
        )
      end
    end
  end
  return fieldType
end

@nospecializeinfer function isDiscrete(@nospecialize(ty::M_Type))::Bool
  local b::Bool
  b = begin
    @match ty begin
      TYPE_INTEGER(__) => begin
        true
      end

      TYPE_STRING(__) => begin
        true
      end

      TYPE_BOOLEAN(__) => begin
        true
      end

      TYPE_ENUMERATION(__) => begin
        true
      end

      TYPE_ARRAY(__) => begin
        isDiscrete(ty.elementType)
      end

      TYPE_FUNCTION(__) => begin
        isDiscrete(returnType(ty.fn))
      end
      _ => begin
        false
      end
    end
  end
  return b
end

@nospecializeinfer function isEqual(@nospecialize(ty1::M_Type), @nospecialize(ty2::M_Type))::Bool
  local equal::Bool

  if referenceEq(ty1, ty2)
    @assign equal = true
    return equal
  end
  if valueConstructor(ty1) != valueConstructor(ty2)
    @assign equal = false
    return equal
  end
  @assign equal = begin
    local names1::List{String}
    local names2::List{String}
    @match (ty1, ty2) begin
      (TYPE_ENUMERATION(__), TYPE_ENUMERATION(__)) => begin
        ListUtil.isEqualOnTrue(ty1.literals, ty2.literals, stringEq)
      end

      (TYPE_ARRAY(__), TYPE_ARRAY(__)) => begin
        isEqual(ty1.elementType, ty2.elementType) && ListUtil.isEqualOnTrue(
          ty1.dimensions,
          ty2.dimensions,
          isEqualKnown,
        )
      end

      (TYPE_TUPLE(names = SOME(names1)), TYPE_TUPLE(names = SOME(names2))) => begin
        ListUtil.isEqualOnTrue(names1, names2, stringEq) &&
        ListUtil.isEqualOnTrue(ty1.types, ty2.types, isEqual)
      end

      (TYPE_TUPLE(names = NONE()), TYPE_TUPLE(names = NONE())) => begin
        ListUtil.isEqualOnTrue(ty1.types, ty2.types, isEqual)
      end

      (TYPE_TUPLE(__), TYPE_TUPLE(__)) => begin
        false
      end

      (TYPE_COMPLEX(__), TYPE_COMPLEX(__)) => begin
        isSame(ty1.cls, ty2.cls)
      end

      _ => begin
        true
      end
    end
  end
  return equal
end

"""Reduces a type's dimensions based on the given list of subscripts."""
function subscript(@nospecialize(ty::M_Type), subs::List{<:Subscript})::M_Type

  local dim::Dimension
  local dims::List{Dimension}
  local subbed_dims::List{Dimension} = nil

  if listEmpty(subs) || isUnknown(ty)
    return ty
  end
  @assign dims = arrayDims(ty)
  for sub in subs
    @match Cons{Dimension}(dim, dims) = dims
    @assign subbed_dims = begin
      @match sub begin
        SUBSCRIPT_INDEX(__) => begin
          subbed_dims
        end

        SUBSCRIPT_SLICE(__) => begin
          Cons{Dimension}(toDimension(sub), subbed_dims)
        end

        SUBSCRIPT_WHOLE(__) => begin
          Cons{Dimension}(dim, subbed_dims)
        end
      end
    end
  end
  ty = arrayElementType(ty)
  if !(listEmpty(subbed_dims) && listEmpty(dims))
    ty = TYPE_ARRAY(ty, listAppend(listReverse(subbed_dims), dims))
  end
  return ty
end

@nospecializeinfer function toDAE(@nospecialize(ty::NFType); makeTypeVars::Bool = true)::DAE.Type
  local daeTy::DAE.Type
  @assign daeTy = begin
    @match ty begin
      TYPE_INTEGER(__) => begin
        DAE.T_INTEGER_DEFAULT
      end
      TYPE_REAL(__) => begin
        DAE.T_REAL_DEFAULT
      end

      TYPE_STRING(__) => begin
        DAE.T_STRING_DEFAULT
      end

      TYPE_BOOLEAN(__) => begin
        DAE.T_BOOL_DEFAULT
      end

      TYPE_ENUMERATION(__) => begin
        DAE.T_ENUMERATION(NONE(), ty.typePath, ty.literals, nil, nil)
      end

      TYPE_CLOCK(__) => begin
        DAE.T_CLOCK_DEFAULT
      end

      TYPE_ARRAY(__) => begin
        DAE.T_ARRAY(
          toDAE(ty.elementType; makeTypeVars = makeTypeVars),
          list(toDAE(d) for d in ty.dimensions),
        )
      end

      TYPE_TUPLE(__) => begin
        DAE.T_TUPLE(list(toDAE(t) for t in ty.types), ty.names)
      end

      TYPE_FUNCTION(__) => begin
        begin
          @match ty.fnType begin
            FunctionType.FUNCTIONAL_PARAMETER => begin
              makeDAEType(ty.fn)
            end

            FunctionType.FUNCTION_REFERENCE => begin
              DAE.T_FUNCTION_REFERENCE_FUNC(
                isBuiltin(ty.fn),
                makeDAEType(ty.fn),
              )
            end

            FunctionType.FUNCTIONAL_VARIABLE => begin
              DAE.T_FUNCTION_REFERENCE_VAR(makeDAEType(ty.fn, true))
            end
          end
        end
      end

      TYPE_NORETCALL(__) => begin
        DAE.T_NORETCALL_DEFAULT
      end

      TYPE_UNKNOWN(__) => begin
        DAE.T_UNKNOWN_DEFAULT
       end

      TYPE_COMPLEX(__) => begin
        if makeTypeVars
          toFullDAEType(ty.cls)
        else
          toPartialDAEType(ty.cls)
        end
      end

      TYPE_METABOXED(__) => begin
        DAE.T_METABOXED(toDAE(ty.ty))
      end

      TYPE_POLYMORPHIC(__) => begin
        DAE.T_METAPOLYMORPHIC(ty.name)
      end

      TYPE_ANY(__) => begin
        DAE.T_ANYTYPE(NONE())
      end

      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " got unknown type: " + anyString(ty),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return daeTy
end

function typenameString(@nospecialize(ty::M_Type))::String
  local str::String

  @assign str = begin
    @match ty begin
      TYPE_ENUMERATION(__) => begin
        AbsynUtil.pathString(ty.typePath)
      end

      _ => begin
        toString(ty)
      end
    end
  end
  return str
end


@nospecializeinfer function toFlatString(@nospecialize(ty::M_Type))::String
  local str::String

  @assign str = begin
    @match ty begin
      TYPE_INTEGER(__) => begin
        "Integer"
      end

      TYPE_REAL(__) => begin
        "Real"
      end

      TYPE_STRING(__) => begin
        "String"
      end

      TYPE_BOOLEAN(__) => begin
        "Boolean"
      end

      TYPE_CLOCK(__) => begin
        "Clock"
      end

      TYPE_ENUMERATION(__) => begin
        "'" * AbsynUtil.pathString(ty.typePath) * "'"
      end

      TYPE_ENUMERATION_ANY(__) => begin
        "enumeration(:)"
      end

      TYPE_ARRAY(__) => begin
        toString(ty.elementType) +
        "[" +
        stringDelimitList(
          ListUtil.map(ty.dimensions, toFlatString, String),
          ", ",
        ) +
        "]"
      end

      TYPE_TUPLE(__) => begin
        "(" + stringDelimitList(ListUtil.map(ty.types, toString, String), ", ")
        +")"
      end

      TYPE_NORETCALL(__) => begin
        "()"
      end

      TYPE_UNKNOWN(__) => begin
        "unknown()"
      end

      TYPE_COMPLEX(__) => begin
        "'" * AbsynUtil.pathString(scopePath(ty.cls)) * "'"
      end

      TYPE_FUNCTION(__) => begin
        typeString(ty.fn)
      end

      TYPE_METABOXED(__) => begin
        "#" + toFlatString(ty.ty)
      end

      TYPE_POLYMORPHIC(__) => begin
        "<" + ty.name
        +">"
      end

      TYPE_ANY(__) => begin
        "ANY"
      end

      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " got unknown type: " + anyString(ty),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return str
end

function toFlatDeclarationStream(@nospecialize(ty::NFType), s::IOStream_M.IOSTREAM)
  #println("Type " * toString(ty))
  local index = 0
  @match ty begin
    TYPE_ENUMERATION(__) => begin
      s = IOStream_M.append(s, "type '")
      s = IOStream_M.append(s, AbsynUtil.pathString(ty.typePath))
      s = IOStream_M.append(s, "' = enumeration(")
      local tmpLits = ty.literals
      if ! listEmpty(tmpLits)
        s = IOStream_M.append(s, listHead(tmpLits))
        for l in listRest(tmpLits)
          s = IOStream_M.append(s, ", ")
          s = IOStream_M.append(s, l)
        end
      end
      s = IOStream_M.append(s, ")")
    end
    TYPE_COMPLEX(_, COMPLEX_RECORD(__)) =>  begin
      toFlatStream(ty.cls, s)
    end
    TYPE_COMPLEX(complexTy = COMPLEX_EXTERNAL_OBJECT(__)) =>  begin
      path = scopePath(ty.cls);
      name = Util.makeQuotedIdentifier(AbsynUtil.pathString(path))
      s = IOStream_M.append(s, "class ")
      s = IOStream_M.append(s, name)
      s = IOStream_M.append(s, "\n  extends ExternalObject;\n\n")
      local f = typeNodeCache(ty.complexTy.constructor)[1]
      s = toFlatStream(f, s, overrideName="constructor")
      s = IOStream_M.append(s, ";\n\n")
      f = typeNodeCache(ty.complexTy.destructor)[1]
      s = toFlatStream(f, s, overrideName="destructor")
      s = IOStream_M.append(s, ";\n\nend ")
      s = IOStream_M.append(s, name)
    end
    TYPE_SUBSCRIPTED(__) => begin
      s = IOStream_M.append(s, "function '")
      s = IOStream_M.append(s, ty.name)
      s = IOStream_M.append(s, "'\n")
      s = IOStream_M.append(s, "input ")
      s = IOStream_M.append(s, toString(ty.ty))
      s = IOStream_M.append(s, " exp;\n")
      index = 1
      for sub in ty.subs
        s = IOStream_M.append(s, "input ")
        s = IOStream_M.append(s, toString(sub))
        s = IOStream_M.append(s, " s")
        s = IOStream_M.append(s, String(index))
        s = IOStream_M.append(s, ";\n")
        index = index + 1
      end
      s = IOStream_M.append(s, "output ")
      s = IOStream_M.append(s, toString(ty.subscriptedTy))
      s = IOStream_M.append(s, " result = exp[")
      s = IOStream_M.append(s,
                          stringDelimitList(list("s" + String(i) for i in 1:listLength(ty.subs)), ","))
      s = IOStream_M.append(s, "];\n")

      s = IOStream_M.append(s, "end '")
      s = IOStream_M.append(s, ty.name)
      s = IOStream_M.append(s, "'")
    end
    _ => s
  end
end

@nospecializeinfer function toString(@nospecialize(ty::M_Type))::String
  local str::String
  str = begin
    @match ty begin
      TYPE_INTEGER(__) => begin
        "Integer"
      end

      TYPE_REAL(__) => begin
        "Real"
      end

      TYPE_STRING(__) => begin
        "String"
      end

      TYPE_BOOLEAN(__) => begin
        "Boolean"
      end

      TYPE_CLOCK(__) => begin
        "Clock"
      end

      TYPE_ENUMERATION(__) => begin
        "enumeration " + AbsynUtil.pathString(ty.typePath) + "(" + stringDelimitList(ty.literals, ", ") + ")"
      end

      TYPE_ENUMERATION_ANY(__) => begin
        "enumeration(:)"
      end

      TYPE_ARRAY(__) => begin
        toString(ty.elementType) +
        "[" +
        stringDelimitList(
          ListUtil.map(ty.dimensions, toString, String),
          ", ",
        ) +
        "]"
      end

      TYPE_TUPLE(__) => begin
        "(" + stringDelimitList(ListUtil.map(ty.types, toString, String), ", ")
        +")"
      end

      TYPE_NORETCALL(__) => begin
        "()"
      end

      TYPE_UNKNOWN(__) => begin
        "unknown()"
      end

      TYPE_COMPLEX(__) => begin
        "'" * AbsynUtil.pathString(scopePath(ty.cls)) * "'"
      end

      TYPE_FUNCTION(__) => begin
        typeString(ty.fn)
      end

      TYPE_METABOXED(__) => begin
        "#" + toString(ty.ty)
      end

      TYPE_POLYMORPHIC(__) => begin
        "<" + ty.name
        +">"
      end

      TYPE_ANY(__) => begin
        "ANY"
      end



      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " got unknown type: " + anyString(ty),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return str
end

"""TODO: Modified by me. Should have a string"""
function nthEnumLiteralAsString(@nospecialize(ty::M_Type), index::Int)::String
  local literal::String
  local literals::List{String}
  @match ENUMERATION(literals = literals) = ty
  @assign literal = listGet(literals, index)
  return literal
end

@nospecializeinfer function foldDims(@nospecialize(ty::M_Type), func::FuncT, arg::ArgT) where {ArgT}

  @assign arg = begin
    @match ty begin
      ARRAY(__) => begin
        ListUtil.fold(ty.dimensions, func, arg)
      end

      TUPLE(__) => begin
        ListUtil.fold(ty.types, (t, acc) -> foldDims(t, func, acc), arg)
      end

      TYPE_FUNCTION(__) => begin
        foldDims(returnType(ty.fn), func, arg)
      end

      TYPE_METABOXED(__) => begin
        foldDims(ty.ty, func, arg)
      end

      _ => begin
        arg
      end
    end
  end
  return arg
end

@nospecializeinfer function mapDims(@nospecialize(ty::M_Type), func::FuncT)
  local fn::M_Function
  #= Short-circuit when `func` is the identity on every dimension/sub-type,
     so callers can compare with `referenceEq` and skip downstream
     reallocation. The previous implementation always allocated a fresh
     TYPE_ARRAY/TYPE_TUPLE/... even when nothing changed. =#
  local retTy = @match ty begin
    TYPE_ARRAY(__) => begin
      local changed = false
      local newDims = nil
      for d in ty.dimensions
        local nd = func(d)
        changed = changed || !referenceEq(nd, d)
        newDims = _cons(nd, newDims)
      end
      if !changed
        ty
      else
        TYPE_ARRAY(ty.elementType, listReverse(newDims))
      end
    end
    TYPE_TUPLE(__) => begin
      local changed = false
      local newTypes = nil
      for t in ty.types
        local nt = mapDims(t, func)
        changed = changed || !referenceEq(nt, t)
        newTypes = _cons(nt, newTypes)
      end
      if !changed
        ty
      else
        TYPE_TUPLE(listReverse(newTypes), ty.names)
      end
    end
    TYPE_FUNCTION(fn = fn) => begin
      local oldRet = returnType(fn)
      local newRet = mapDims(oldRet, func)
      if referenceEq(oldRet, newRet)
        ty
      else
        TYPE_FUNCTION(setReturnType(newRet, fn), ty.fnType)
      end
    end
    TYPE_METABOXED(__) => begin
      local tyTy = mapDims(ty.ty, func)
      if referenceEq(tyTy, ty.ty)
        ty
      else
        TYPE_METABOXED(tyTy)
      end
    end
    _ => begin
      ty
    end
  end
  return retTy
end

function hasZeroDimension(@nospecialize(ty::M_Type))::Bool
  local hasZero::Bool
  @assign hasZero = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        ListUtil.exist(ty.dimensions, isZero)
      end
      _ => begin
        false
      end
    end
  end
  return hasZero
end

@nospecializeinfer function hasKnownSize(@nospecialize(ty::M_Type))::Bool
  local known::Bool

  @assign known = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        allowExp = false
        ListUtil.all(
          ty.dimensions,
          (x) -> isKnown(x, allowExp),
        )
      end
      TYPE_FUNCTION(__) => begin
        hasKnownSize(returnType(ty.fn))
      end
      _ => begin
        true
      end
    end
  end
  return known
end

function dimensionDiff(@nospecialize(ty1::M_Type), @nospecialize(ty2::M_Type))::Int
  local diff::Int = dimensionCount(ty1) - dimensionCount(ty2)
  return diff
end

@nospecializeinfer function dimensionCount(@nospecialize(ty::NFType))::Int
  local dimCount::Int
  @assign dimCount = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        listLength(ty.dimensions)
      end
      TYPE_FUNCTION(__) => begin
        dimensionCount(returnType(ty.fn))
      end
      TYPE_METABOXED(__) => begin
        dimensionCount(ty.ty)
      end
      _ => begin
        0
      end
    end
  end
  return dimCount
end

@nospecializeinfer function nthDimension(@nospecialize(ty::M_Type), index::Int)::Dimension
  local dim::Dimension

  @assign dim = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        listGet(ty.dimensions, index)
      end

      TYPE_FUNCTION(__) => begin
        nthDimension(returnType(ty.fn), index)
      end

      TYPE_METABOXED(__) => begin
        nthDimension(ty.ty, index)
      end
    end
  end
  return dim
end

"""
 Copies array dimensions from one type to another, discarding the existing
 dimensions of the destination type but keeping its element type.
"""
function copyDims(@nospecialize(srcType::M_Type), @nospecialize(dstType::M_Type))::M_Type
  local ty::M_Type
  if listEmpty(arrayDims(srcType))
    ty = arrayElementType(dstType)
  else
    ty = begin
      @match dstType begin
        TYPE_ARRAY(__) => begin
          TYPE_ARRAY(dstType.elementType, arrayDims(srcType))
        end
        _ => begin
          TYPE_ARRAY(dstType, arrayDims(srcType))
        end
      end
    end
  end
  return ty
end

@nospecializeinfer function arrayDims(@nospecialize(ty::NFType))::List{Dimension}
  @match ty begin
    TYPE_ARRAY(__) => begin
      ty.dimensions
    end
    TYPE_FUNCTION(__) => begin
      arrayDims(returnType(ty.fn))
    end
    TYPE_METABOXED(__) => begin
      arrayDims(ty.ty)
    end
    _ => begin
      nil
    end
  end
end

@nospecializeinfer function elementType(@nospecialize(ty::NFType))::NFType
  local elementTy::NFType
  @assign elementTy = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        ty.elementType
      end
      TYPE_FUNCTION(__) => begin
        elementType(returnType(ty.fn))
      end
      _ => begin
        ty
      end
    end
  end
  return elementTy
end

"""
Sets the common type of the elements in an array, if the type is an array
type. Otherwise it just returns the given element type.
"""
function setArrayElementType(@nospecialize(arrayTy::M_Type), @nospecialize(elementTy::NFType))::NFType
  local ty::NFType
 ty = begin
    @match arrayTy begin
      TYPE_ARRAY(__) => begin
        liftArrayLeftList(elementTy, arrayTy.dimensions)
      end
      _ => begin
        elementTy
      end
    end
  end
  return ty
end

"""
  Returns the common type of the elements in an array, or just the type
  itself if it's not an array type.
"""
function arrayElementType(@nospecialize(ty::M_Type))::M_Type
  local elementTy::M_Type

  @assign elementTy = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        ty.elementType
      end

      _ => begin
        ty
      end
    end
  end
  return elementTy
end

@nospecializeinfer function nthTupleType(@nospecialize(ty::M_Type), n::Int)::M_Type
  local outTy::M_Type
  outTy = begin
    @match ty begin
      TYPE_TUPLE(__) => begin
        listGet(ty.types, n)
      end
      TYPE_ARRAY(__) => begin
        TYPE_ARRAY(nthTupleType(ty.elementType, n), ty.dimensions)
      end
      _ => begin
        ty
      end
    end
  end
  return outTy
end

@nospecializeinfer function firstTupleType(@nospecialize(ty::M_Type))::M_Type
  local outTy::M_Type
  outTy = begin
    @match ty begin
      TYPE_TUPLE(__) => begin
        listHead(ty.types)
      end
      TYPE_ARRAY(__) => begin
        TYPE_ARRAY(firstTupleType(ty.elementType), ty.dimensions)
      end
      _ => begin
        ty
      end
    end
  end
  return outTy
end

function isPolymorphic(@nospecialize(ty::NFType))::Bool
  local isPolymorphic::Bool
  @assign isPolymorphic = begin
    @match ty begin
      TYPE_POLYMORPHIC(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isPolymorphic
end

function isKnown(@nospecialize(ty::NFType))::Bool
  local isKnown::Bool
  @assign isKnown = begin
    @match ty begin
      TYPE_UNKNOWN(__) => begin
        false
      end

      _ => begin
        true
      end
    end
  end
  return isKnown
end

function isUnknown(@nospecialize(ty::M_Type))::Bool
  local isUnknown::Bool
  @assign isUnknown = begin
    @match ty begin
      TYPE_UNKNOWN(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isUnknown
end

function isTuple(@nospecialize(ty::M_Type))::Bool
  local isTuple::Bool

  @assign isTuple = begin
    @match ty begin
      TYPE_TUPLE(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isTuple
end

""" #= Returns true for all the builtin scalar types such as Integer, Real, etc. =#"""
@nospecializeinfer function isScalarBuiltin(@nospecialize(ty::M_Type))::Bool
  local isScalarBuiltin::Bool

  @assign isScalarBuiltin = begin
    @match ty begin
      TYPE_INTEGER(__) => begin
        true
      end

      TYPE_REAL(__) => begin
        true
      end

      TYPE_STRING(__) => begin
        true
      end

      TYPE_BOOLEAN(__) => begin
        true
      end

      TYPE_CLOCK(__) => begin
        true
      end

      TYPE_ENUMERATION(__) => begin
        true
      end

      TYPE_ENUMERATION_ANY(__) => begin
        true
      end

      TYPE_FUNCTION(__) => begin
        isScalarBuiltin(returnType(ty.fn))
      end

      _ => begin
        false
      end
    end
  end
  return isScalarBuiltin
end

function isNumeric(@nospecialize(ty::M_Type))::Bool
  local isNumeric::Bool

  @assign isNumeric = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        isBasicNumeric(ty.elementType)
      end

      _ => begin
        isBasicNumeric(ty)
      end
    end
  end
  return isNumeric
end

function isBasicNumeric(@nospecialize(ty::M_Type))::Bool
  local isNumeric::Bool
  @assign isNumeric = begin
    @match ty begin
      TYPE_REAL(__) => begin
        true
      end
      TYPE_INTEGER(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isNumeric
end

@nospecializeinfer function isBasic(@nospecialize(ty::M_Type))::Bool
  local isNumeric::Bool
  @assign isNumeric = begin
    @match ty begin
      TYPE_REAL(__) => begin
        true
      end
      TYPE_INTEGER(__) => begin
        true
      end

      TYPE_BOOLEAN(__) => begin
        true
      end

      TYPE_STRING(__) => begin
        true
      end

      TYPE_ENUMERATION(__) => begin
        true
      end

      TYPE_CLOCK(__) => begin
        true
      end

      TYPE_FUNCTION(__) => begin
        isBasic(returnType(ty.fn))
      end

      _ => begin
        false
      end
    end
  end
  return isNumeric
end

function isScalarArray(@nospecialize(ty::M_Type))::Bool
  local isScalar::Bool

  @assign isScalar = begin
    @match ty begin
      TYPE_ARRAY(dimensions = _ <| nil()) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isScalar
end

function isRecord(@nospecialize(ty::M_Type))::Bool
  local isRecord::Bool

  @assign isRecord = begin
    @match ty begin
      TYPE_COMPLEX(complexTy = COMPLEX_RECORD(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isRecord
end

function isExternalObject(@nospecialize(ty::M_Type))::Bool
  local isEO::Bool

  @assign isEO = begin
    @match ty begin
      TYPE_COMPLEX(complexTy = COMPLEX_EXTERNAL_OBJECT(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isEO
end

function isExpandableConnector(@nospecialize(ty::M_Type))::Bool
  local isExpandable::Bool

  @assign isExpandable = begin
    @match ty begin
      TYPE_COMPLEX(complexTy = COMPLEX_EXPANDABLE_CONNECTOR(__)) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isExpandable
end

function isConnector(@nospecialize(ty::M_Type))::Bool
  local isaC::Bool

  @assign isaC = begin
    @match ty begin
      TYPE_COMPLEX(complexTy = COMPLEX_CONNECTOR(__)) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isaC
end

function isComplex(@nospecialize(ty::M_Type))::Bool
  local isComplex::Bool
  @assign isComplex = begin
    @match ty begin
      TYPE_COMPLEX(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isComplex
end

function complexNode(ty)
  local node::InstNode
  @match TYPE_COMPLEX(cls = node) = ty
  return node
end

function complexComponents(ty)
  getComponents(classTree(getClass(complexNode(ty))))
end

function isEnumeration(@nospecialize(ty::M_Type))::Bool
  local isEnum::Bool

  @assign isEnum = begin
    @match ty begin
      TYPE_ENUMERATION(__) => begin
        true
      end

      TYPE_ENUMERATION_ANY(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isEnum
end

function isSingleElementArray(@nospecialize(ty::M_Type))::Bool
  local isSingleElement::Bool
  @assign isSingleElement = begin
    local d::Dimension
    @match ty begin
      TYPE_ARRAY(dimensions = d <| nil()) => begin
        isKnown(d) && size(d) == 1
      end
      _ => begin
        false
      end
    end
  end
  return isSingleElement
end

function isEmptyArray(@nospecialize(ty::M_Type))::Bool
  local isEmpty::Bool
  isEmpty = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        ListUtil.exist(ty.dimensions, isZero)
      end
      _ => begin
        false
      end
    end
  end
  return isEmpty
end

function isSquareMatrix(@nospecialize(ty::M_Type))::Bool
  local isSquareMatrix::Bool

  @assign isSquareMatrix = begin
    local d1::Dimension
    local d2::Dimension
    @match ty begin
      TYPE_ARRAY(dimensions = d1 <| d2 <| nil()) => begin
        isEqualKnown(d1, d2)
      end

      _ => begin
        false
      end
    end
  end
  return isSquareMatrix
end

function isMatrix(@nospecialize(ty::M_Type))::Bool
  local isMatrix::Bool

  @assign isMatrix = begin
    @match ty begin
      TYPE_ARRAY(dimensions = _ <| _ <| nil()) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isMatrix
end

"""Return whether the type is a vector type or not, i.e. a 1-dimensional array."""
function isVector(@nospecialize(ty::M_Type))::Bool
  local isVector::Bool

  @assign isVector = begin
    @match ty begin
      TYPE_ARRAY(dimensions = _ <| nil()) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isVector
end

function isArray(@nospecialize(ty::M_Type))::Bool
  local isArray::Bool

  @assign isArray = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isArray
end

function isScalar(@nospecialize(ty::M_Type))::Bool
  local isScalar::Bool

  @assign isScalar = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        false
      end

      _ => begin
        true
      end
    end
  end
  return isScalar
end

function isClock(@nospecialize(ty::NFType))::Bool
  local isClock::Bool
  @assign isClock = begin
    @match ty begin
      TYPE_CLOCK(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isClock
end

function isString(@nospecialize(ty::M_Type))::Bool
  local isString::Bool

  @assign isString = begin
    @match ty begin
      TYPE_STRING(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isString
end

function isBoolean(@nospecialize(ty::NFType))::Bool
  local isBool::Bool
  @assign isBool = begin
    @match ty begin
      TYPE_BOOLEAN(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isBool
end

function isReal(@nospecialize(ty::M_Type))::Bool
  local isReal::Bool

  @assign isReal = begin
    @match ty begin
      TYPE_REAL(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isReal
end

function isInteger(@nospecialize(ty::M_Type))::Bool
  local isInteger::Bool

  @assign isInteger = begin
    @match ty begin
      TYPE_INTEGER(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isInteger
end

function unliftArrayN(N::Int, @nospecialize(ty::M_Type))::M_Type

  local el_ty::M_Type
  local dims::List{Dimension}

  @match TYPE_ARRAY(el_ty, dims) = ty
  for i = 1:N
    dims = listRest(dims)
  end
  if listEmpty(dims)
    ty = el_ty
  else
    ty = TYPE_ARRAY(el_ty, dims)
  end
  return ty
end

function unliftArray(@nospecialize(ty::M_Type))::M_Type

  local el_ty::M_Type
  local dims::List{Dimension}

  @match TYPE_ARRAY(el_ty, Cons{Dimension}(_, dims)) = ty
  if listEmpty(dims)
    @assign ty = el_ty
  else
    @assign ty = TYPE_ARRAY(el_ty, dims)
  end
  return ty
end

"""
  Adds array dimensions to a type on the left side, e.g.
  listArrayLeft(Real[2, 3], [4, 5]) => Real[2, 3, 4, 5].
"""
function liftArrayRightList(@nospecialize(ty::NFType), dims::List{<:Dimension})::NFType

  if listEmpty(dims)
    return ty
  end
  @assign ty = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        TYPE_ARRAY(ty.elementType, listAppend(ty.dimensions, dims))
      end

      _ => begin
        TYPE_ARRAY(ty, dims)
      end
    end
  end
  return ty
end

"""  Adds array dimensions to a type on the left side, e.g.
     listArrayLeft(Real[2, 3], [4, 5]) => Real[4, 5, 2, 3].
"""
function liftArrayLeftList(@nospecialize(ty::NFType), dims::List{<:Dimension})::NFType
  if listEmpty(dims)
    return ty
  end
  ty = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        TYPE_ARRAY(ty.elementType, listAppend(dims, ty.dimensions))
      end
      _ => begin
        TYPE_ARRAY(ty, dims)
      end
    end
  end
  return ty
end

"""
  Adds an array dimension to a type on the left side, e.g.
  listArrayLeft(Real[2, 3], [4]) => Real[4, 2, 3].
"""
function liftArrayLeft(@nospecialize(ty::M_Type), dim::Dimension)::TYPE_ARRAY
  @match ty begin
    TYPE_ARRAY(__) => begin
      return TYPE_ARRAY(ty.elementType, Cons{Dimension}(dim, ty.dimensions))
    end
    _ => begin
      return TYPE_ARRAY(ty, list(dim))
    end
  end
end

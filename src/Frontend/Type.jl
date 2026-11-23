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

#= The ModelicaType struct and its ModelicaTypeTag enum are in FrontendInterfaces/Interfaces.jl (see
   `ModelicaTypeImpl`). Here: its `TYPE_*` constructors (nullary types are shared singletons), the
   `@match` registrations and the functions on types. A variant is tested with `isvariant(x, TYPE_*)`. =#

#= ModelicaType is one concrete struct, so the generic valueConstructor (hash of the
   runtime type) is identical for every variant. Discriminate by the tag instead,
   so variant-mismatch guards (e.g. array-vs-scalar cast routing in NFTypeCheck)
   keep working. =#
MetaModelica.valueConstructor(value::ModelicaType) = Int(value.tag)

#= Base "all-empty" builder for the nullary/scalar tags. =#
@inline _nftype(tag::ModelicaTypeTag) =
  ModelicaType(tag, nothing, nothing, nil, nothing, nothing, 0, nothing, nothing,
         nil, NONE(), nothing, nil, nothing, nil)

# Nullary types are interned singletons.
const _TYPE_INTEGER        = _nftype(NFT_INTEGER)
const _TYPE_REAL           = _nftype(NFT_REAL)
const _TYPE_STRING         = _nftype(NFT_STRING)
const _TYPE_BOOLEAN        = _nftype(NFT_BOOLEAN)
const _TYPE_CLOCK          = _nftype(NFT_CLOCK)
const _TYPE_UNKNOWN        = _nftype(NFT_UNKNOWN)
const _TYPE_ANY            = _nftype(NFT_ANY)
const _TYPE_NORETCALL      = _nftype(NFT_NORETCALL)
const _TYPE_ENUMERATION_ANY = _nftype(NFT_ENUMERATION_ANY)
TYPE_INTEGER()        = _TYPE_INTEGER
TYPE_REAL()           = _TYPE_REAL
TYPE_STRING()         = _TYPE_STRING
TYPE_BOOLEAN()        = _TYPE_BOOLEAN
TYPE_CLOCK()          = _TYPE_CLOCK
TYPE_UNKNOWN()        = _TYPE_UNKNOWN
TYPE_ANY()            = _TYPE_ANY
TYPE_NORETCALL()      = _TYPE_NORETCALL
TYPE_ENUMERATION_ANY() = _TYPE_ENUMERATION_ANY

# Data-carrying constructors (positional, matching the old record fields).
TYPE_SUBSCRIPTED(name, ty, subs, subscriptedTy) =
  ModelicaType(NFT_SUBSCRIPTED, name, ty, subs, subscriptedTy, nothing, 0, nothing, nothing,
         nil, NONE(), nothing, nil, nothing, nil)
TYPE_POLYMORPHIC(name) =
  ModelicaType(NFT_POLYMORPHIC, name, nothing, nil, nothing, nothing, 0, nothing, nothing,
         nil, NONE(), nothing, nil, nothing, nil)
TYPE_METABOXED(ty) =
  ModelicaType(NFT_METABOXED, nothing, ty, nil, nothing, nothing, 0, nothing, nothing,
         nil, NONE(), nothing, nil, nothing, nil)
TYPE_FUNCTION(fn::MODELICA_FUNCTION, fnType::Int) =
  ModelicaType(NFT_FUNCTION, nothing, nothing, nil, nothing, fn, fnType, nothing, nothing,
         nil, NONE(), nothing, nil, nothing, nil)

"""
    functionOf(ty::ModelicaType)::MODELICA_FUNCTION

The function of a function type (`TYPE_FUNCTION`), for a caller that has checked the variant. The field is
`Union{Nothing, MODELICA_FUNCTION}` (other variants leave it empty); read it here, not as `ty.fn`.
"""
functionOf(ty::ModelicaType)::MODELICA_FUNCTION = ty.fn::MODELICA_FUNCTION
TYPE_COMPLEX(cls, complexTy) =
  ModelicaType(NFT_COMPLEX, nothing, nothing, nil, nothing, nothing, 0, cls, complexTy,
         nil, NONE(), nothing, nil, nothing, nil)
TYPE_TUPLE(types, names) =
  ModelicaType(NFT_TUPLE, nothing, nothing, nil, nothing, nothing, 0, nothing, nothing,
         types, names, nothing, nil, nothing, nil)
TYPE_ARRAY(elementType, dimensions) =
  ModelicaType(NFT_ARRAY, nothing, nothing, nil, nothing, nothing, 0, nothing, nothing,
         nil, NONE(), elementType, dimensions, nothing, nil)
TYPE_ENUMERATION(typePath, literals) =
  ModelicaType(NFT_ENUMERATION, nothing, nothing, nil, nothing, nothing, 0, nothing, nothing,
         nil, NONE(), nothing, nil, typePath, literals)

# @match / isvariant support: register each constructor's tag + field order.
MetaModelica.compacted_tag_info(::typeof(TYPE_INTEGER))        = (ModelicaType, :tag, NFT_INTEGER, ())
MetaModelica.compacted_tag_info(::typeof(TYPE_REAL))           = (ModelicaType, :tag, NFT_REAL, ())
MetaModelica.compacted_tag_info(::typeof(TYPE_STRING))         = (ModelicaType, :tag, NFT_STRING, ())
MetaModelica.compacted_tag_info(::typeof(TYPE_BOOLEAN))        = (ModelicaType, :tag, NFT_BOOLEAN, ())
MetaModelica.compacted_tag_info(::typeof(TYPE_CLOCK))          = (ModelicaType, :tag, NFT_CLOCK, ())
MetaModelica.compacted_tag_info(::typeof(TYPE_UNKNOWN))        = (ModelicaType, :tag, NFT_UNKNOWN, ())
MetaModelica.compacted_tag_info(::typeof(TYPE_ANY))            = (ModelicaType, :tag, NFT_ANY, ())
MetaModelica.compacted_tag_info(::typeof(TYPE_NORETCALL))      = (ModelicaType, :tag, NFT_NORETCALL, ())
MetaModelica.compacted_tag_info(::typeof(TYPE_ENUMERATION_ANY)) = (ModelicaType, :tag, NFT_ENUMERATION_ANY, ())
MetaModelica.compacted_tag_info(::typeof(TYPE_SUBSCRIPTED)) = (ModelicaType, :tag, NFT_SUBSCRIPTED, (:name, :ty, :subs, :subscriptedTy))
MetaModelica.compacted_tag_info(::typeof(TYPE_POLYMORPHIC))  = (ModelicaType, :tag, NFT_POLYMORPHIC, (:name,))
MetaModelica.compacted_tag_info(::typeof(TYPE_METABOXED))    = (ModelicaType, :tag, NFT_METABOXED, (:ty,))
MetaModelica.compacted_tag_info(::typeof(TYPE_FUNCTION))     = (ModelicaType, :tag, NFT_FUNCTION, (:fn, :fnType))
MetaModelica.compacted_tag_info(::typeof(TYPE_COMPLEX))      = (ModelicaType, :tag, NFT_COMPLEX, (:cls, :complexTy))
MetaModelica.compacted_tag_info(::typeof(TYPE_TUPLE))        = (ModelicaType, :tag, NFT_TUPLE, (:types, :names))
MetaModelica.compacted_tag_info(::typeof(TYPE_ARRAY))        = (ModelicaType, :tag, NFT_ARRAY, (:elementType, :dimensions))
MetaModelica.compacted_tag_info(::typeof(TYPE_ENUMERATION))  = (ModelicaType, :tag, NFT_ENUMERATION, (:typePath, :literals))

function subscriptedTypeName(expType::ModelicaType, subscriptTypes::List{<:ModelicaType})::String
  local str::String
  local strl::List{String}
  strl = list(toString(t) for t in subscriptTypes)
  strl = _cons("_", strl)
  strl = _cons(toString(expType), strl)
  strl = _cons("subscript", strl)
  str = stringAppendList(strl)
  return str
end

function sizeType(arrayTy::ModelicaType)::ModelicaType
  local sizeTy::ModelicaType

  if isUnknown(arrayTy)
    sizeTy = TYPE_UNKNOWN()
  else
    sizeTy = TYPE_ARRAY(
      TYPE_INTEGER(),
      list(fromInteger(dimensionCount(arrayTy))),
    )
  end
  #= Return unknown type if the type is unknown, to avoid returning Array[0]
     for untyped expressions. =#
  return sizeTy
end

isBoxed(ty::ModelicaType)::Bool = isvariant(ty, TYPE_METABOXED)

function unbox(ty::ModelicaType)::ModelicaType

  @match ty begin
    TYPE_METABOXED(__) => ty.ty

    _ => ty
  end
end

function box(ty::ModelicaType)::ModelicaType

  @match ty begin
    TYPE_METABOXED(__) => ty

    _ => TYPE_METABOXED(ty)
  end
end

function enumSize(ty::ModelicaType)::Int
  local size::Int
  local literals::List{String}
  @match TYPE_ENUMERATION(literals = literals) = ty
  size = listLength(literals)
  return size
end

function enumName(ty::ModelicaType)::Absyn.Path
  local name::Absyn.Path
  @match TYPE_ENUMERATION(typePath = name) = ty
  return name
end

function recordFields(recordType::ModelicaType)::List{Field}
  local fields::List{Field}

  fields = begin
    @match recordType begin
      TYPE_COMPLEX(complexTy = COMPLEX_RECORD(fields = fields)) => fields

      _ => nil
    end
  end
  return fields
end

@nospecializeinfer function lookupRecordFieldType(name::String, recordType::ModelicaType)::ModelicaType

  @match recordType begin
    TYPE_COMPLEX(__) => getType(lookupElementNode(name, getClass(recordType.cls)))

    TYPE_ARRAY(__) => begin
      liftArrayLeftList(
        lookupRecordFieldType(name, recordType.elementType),
        recordType.dimensions,
      )
    end
  end
end

@nospecializeinfer function isDiscrete(ty::ModelicaType)::Bool
  @match ty begin
    TYPE_INTEGER(__) => true

    TYPE_STRING(__) => true

    TYPE_BOOLEAN(__) => true

    TYPE_ENUMERATION(__) => true

    TYPE_ARRAY(__) => isDiscrete(ty.elementType)

    TYPE_FUNCTION(__) => isDiscrete(returnType(functionOf(ty)))
    _ => false
  end
end

@nospecializeinfer function isEqual(ty1::ModelicaType, ty2::ModelicaType)::Bool
  local equal::Bool

  if referenceEq(ty1, ty2)
    equal = true
    return equal
  end
  if valueConstructor(ty1) != valueConstructor(ty2)
    equal = false
    return equal
  end
  equal = begin
    local names1::List{String}
    local names2::List{String}
    @match (ty1, ty2) begin
      (TYPE_ENUMERATION(__), TYPE_ENUMERATION(__)) => ListUtil.isEqualOnTrue(ty1.literals, ty2.literals, stringEq)

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

      (TYPE_TUPLE(names = NONE()), TYPE_TUPLE(names = NONE())) => ListUtil.isEqualOnTrue(ty1.types, ty2.types, isEqual)

      (TYPE_TUPLE(__), TYPE_TUPLE(__)) => false

      (TYPE_COMPLEX(__), TYPE_COMPLEX(__)) => isSame(ty1.cls, ty2.cls)

      _ => true
    end
  end
  return equal
end

"""Reduces a type's dimensions based on the given list of subscripts."""
function subscript(ty::ModelicaType, subs::List{<:Subscript})::ModelicaType

  local dim::Dimension
  local dims::List{Dimension}
  local subbed_dims::List{Dimension} = nil

  if listEmpty(subs) || isUnknown(ty)
    return ty
  end
  dims = arrayDims(ty)
  for sub in subs
    @match Cons{Dimension}(dim, dims) = dims
    subbed_dims = begin
      @match sub begin
        SUBSCRIPT_INDEX(__) => subbed_dims

        SUBSCRIPT_SLICE(__) => Cons{Dimension}(toDimension(sub), subbed_dims)

        SUBSCRIPT_WHOLE(__) => Cons{Dimension}(dim, subbed_dims)
      end
    end
  end
  ty = arrayElementType(ty)
  if !(listEmpty(subbed_dims) && listEmpty(dims))
    ty = TYPE_ARRAY(ty, listAppend(listReverse(subbed_dims), dims))
  end
  return ty
end

function typenameString(ty::ModelicaType)::String

  @match ty begin
    TYPE_ENUMERATION(__) => AbsynUtil.pathString(ty.typePath)

    _ => toString(ty)
  end
end

@nospecializeinfer function toFlatString(ty::ModelicaType)::String

  @match ty begin
    TYPE_INTEGER(__) => "Integer"

    TYPE_REAL(__) => "Real"

    TYPE_STRING(__) => "String"

    TYPE_BOOLEAN(__) => "Boolean"

    TYPE_CLOCK(__) => "Clock"

    TYPE_ENUMERATION(__) => "'" * AbsynUtil.pathString(ty.typePath) * "'"

    TYPE_ENUMERATION_ANY(__) => "enumeration(:)"

    TYPE_ARRAY(__) => begin
      toString(ty.elementType) +
      "[" +
      stringDelimitList(
        ListUtil.map(ty.dimensions, toFlatString, String),
        ", ",
      ) +
      "]"
    end

    TYPE_TUPLE(__) => "(" + stringDelimitList(ListUtil.map(ty.types, toString, String), ", ") + ")"

    TYPE_NORETCALL(__) => "()"

    TYPE_UNKNOWN(__) => "unknown()"

    TYPE_COMPLEX(__) => "'" * AbsynUtil.pathString(scopePath(ty.cls)) * "'"

    TYPE_FUNCTION(__) => typeString(functionOf(ty))

    TYPE_METABOXED(__) => "#" + toFlatString(ty.ty)

    TYPE_POLYMORPHIC(__) => "<" + ty.name + ">"

    TYPE_ANY(__) => "ANY"

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

function toFlatDeclarationStream(ty::ModelicaType, s::IOStream_M.IOSTREAM)
  local index
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
    TYPE_COMPLEX(_, COMPLEX_RECORD(__)) => toFlatStream(ty.cls, s)
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
        s = IOStream_M.append(s, string(index))
        s = IOStream_M.append(s, ";\n")
        index = index + 1
      end
      s = IOStream_M.append(s, "output ")
      s = IOStream_M.append(s, toString(ty.subscriptedTy))
      s = IOStream_M.append(s, " result = exp[")
      s = IOStream_M.append(s,
                          stringDelimitList(list("s" + string(i) for i in 1:listLength(ty.subs)), ","))
      s = IOStream_M.append(s, "];\n")

      s = IOStream_M.append(s, "end '")
      s = IOStream_M.append(s, ty.name)
      s = IOStream_M.append(s, "'")
    end
    _ => s
  end
end

@nospecializeinfer function toString(ty::ModelicaType)::String
  @match ty begin
    TYPE_INTEGER(__) => "Integer"

    TYPE_REAL(__) => "Real"

    TYPE_STRING(__) => "String"

    TYPE_BOOLEAN(__) => "Boolean"

    TYPE_CLOCK(__) => "Clock"

    TYPE_ENUMERATION(__) => begin
      "enumeration " + AbsynUtil.pathString(ty.typePath) + "(" + stringDelimitList(ty.literals, ", ") + ")"
    end

    TYPE_ENUMERATION_ANY(__) => "enumeration(:)"

    TYPE_ARRAY(__) => begin
      toString(ty.elementType) +
      "[" +
      stringDelimitList(
        ListUtil.map(ty.dimensions, toString, String),
        ", ",
      ) +
      "]"
    end

    TYPE_TUPLE(__) => "(" + stringDelimitList(ListUtil.map(ty.types, toString, String), ", ") + ")"

    TYPE_NORETCALL(__) => "()"

    TYPE_UNKNOWN(__) => "unknown()"

    TYPE_COMPLEX(__) => "'" * AbsynUtil.pathString(scopePath(ty.cls)) * "'"

    TYPE_FUNCTION(__) => typeString(functionOf(ty))

    TYPE_METABOXED(__) => "#" + toString(ty.ty)

    TYPE_POLYMORPHIC(__) => "<" + ty.name + ">"

    TYPE_ANY(__) => "ANY"

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

function foldDims(ty::ModelicaType, func::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}

  arg = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        for d in ty.dimensions
          arg = func(d, arg)::ArgT
        end
        arg
      end

      TYPE_TUPLE(__) => begin
        for t in ty.types
          arg = foldDims(t, func, arg, ArgT)
        end
        arg
      end

      TYPE_FUNCTION(__) => foldDims(returnType(functionOf(ty)), func, arg, ArgT)

      TYPE_METABOXED(__) => foldDims(ty.ty, func, arg, ArgT)

      _ => arg
    end
  end
  return arg
end

@nospecializeinfer function mapDims(ty::ModelicaType, func::FuncT)
  local fn::MODELICA_FUNCTION
  #= Short-circuit when `func` is the identity on every dimension/sub-type,
     so callers can compare with `referenceEq` and skip downstream
     reallocation. The previous implementation always allocated a fresh
     TYPE_ARRAY/TYPE_TUPLE/... even when nothing changed. =#
  local retTy = @match ty begin
    TYPE_ARRAY(__) => begin
      local changed::Bool = false
      local newDims::List{Dimension} = nil
      for d::Dimension in ty.dimensions
        local nd::Dimension = func(d)
        changed = changed || !referenceEq(nd, d)
        newDims = Cons{Dimension}(nd, newDims)
      end
      if !changed
        ty
      else
        TYPE_ARRAY(ty.elementType, listReverse(newDims))
      end
    end
    TYPE_TUPLE(__) => begin
      local changed::Bool = false
      local newTypes::List{ModelicaType} = nil
      for t::ModelicaType in ty.types
        local nt::ModelicaType = mapDims(t, func)
        changed = changed || !referenceEq(nt, t)
        newTypes = Cons{ModelicaType}(nt, newTypes)
      end
      if !changed
        ty
      else
        TYPE_TUPLE(listReverse(newTypes), ty.names)
      end
    end
    TYPE_FUNCTION(__) => begin
      local fn::MODELICA_FUNCTION = functionOf(ty)
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
    _ => ty
  end
  return retTy
end

function hasZeroDimension(ty::ModelicaType)::Bool
  @match ty begin
    TYPE_ARRAY(__) => ListUtil.exist(ty.dimensions, isZero)
    _ => false
  end
end

@nospecializeinfer function hasKnownSize(ty::ModelicaType)::Bool

  @match ty begin
    TYPE_ARRAY(__) => begin
      allowExp = false
      ListUtil.all(
        ty.dimensions,
        (x) -> isKnown(x, allowExp),
      )
    end
    TYPE_FUNCTION(__) => hasKnownSize(returnType(functionOf(ty)))
    _ => true
  end
end

@nospecializeinfer function dimensionCount(ty::ModelicaType)::Int
  @match ty begin
    TYPE_ARRAY(__) => listLength(ty.dimensions)
    TYPE_FUNCTION(__) => dimensionCount(returnType(functionOf(ty)))
    TYPE_METABOXED(__) => dimensionCount(ty.ty)
    _ => 0
  end
end

@nospecializeinfer function nthDimension(ty::ModelicaType, index::Int)::Dimension

  @match ty begin
    TYPE_ARRAY(__) => listGet(ty.dimensions, index)

    TYPE_FUNCTION(__) => nthDimension(returnType(functionOf(ty)), index)

    TYPE_METABOXED(__) => nthDimension(ty.ty, index)
  end
end

"""
 Copies array dimensions from one type to another, discarding the existing
 dimensions of the destination type but keeping its element type.
"""
function copyDims(srcType::ModelicaType, dstType::ModelicaType)::ModelicaType
  local ty::ModelicaType
  if listEmpty(arrayDims(srcType))
    ty = arrayElementType(dstType)
  else
    ty = begin
      @match dstType begin
        TYPE_ARRAY(__) => TYPE_ARRAY(dstType.elementType, arrayDims(srcType))
        _ => TYPE_ARRAY(dstType, arrayDims(srcType))
      end
    end
  end
  return ty
end

@nospecializeinfer function arrayDims(ty::ModelicaType)::List{Dimension}
  @match ty begin
    TYPE_ARRAY(__) => ty.dimensions
    TYPE_FUNCTION(__) => arrayDims(returnType(functionOf(ty)))
    TYPE_METABOXED(__) => arrayDims(ty.ty)
    _ => nil
  end
end

@nospecializeinfer function elementType(ty::ModelicaType)::ModelicaType
  @match ty begin
    TYPE_ARRAY(__) => ty.elementType
    TYPE_FUNCTION(__) => elementType(returnType(functionOf(ty)))
    _ => ty
  end
end

"""
Sets the common type of the elements in an array, if the type is an array
type. Otherwise it just returns the given element type.
"""
function setArrayElementType(arrayTy::ModelicaType, elementTy::ModelicaType)::ModelicaType
 @match arrayTy begin
   TYPE_ARRAY(__) => liftArrayLeftList(elementTy, arrayTy.dimensions)
   _ => elementTy
 end
end

"""
  Returns the common type of the elements in an array, or just the type
  itself if it's not an array type.
"""
function arrayElementType(ty::ModelicaType)::ModelicaType

  @match ty begin
    TYPE_ARRAY(__) => ty.elementType

    _ => ty
  end
end

@nospecializeinfer function nthTupleType(ty::ModelicaType, n::Int)::ModelicaType
  @match ty begin
    TYPE_TUPLE(__) => listGet(ty.types, n)
    TYPE_ARRAY(__) => TYPE_ARRAY(nthTupleType(ty.elementType, n), ty.dimensions)
    _ => ty
  end
end

@nospecializeinfer function firstTupleType(ty::ModelicaType)::ModelicaType
  @match ty begin
    TYPE_TUPLE(__) => listHead(ty.types)
    TYPE_ARRAY(__) => TYPE_ARRAY(firstTupleType(ty.elementType), ty.dimensions)
    _ => ty
  end
end

isPolymorphic(ty::ModelicaType)::Bool = isvariant(ty, TYPE_POLYMORPHIC)

isKnown(ty::ModelicaType)::Bool = !isvariant(ty, TYPE_UNKNOWN)

isUnknown(ty::ModelicaType)::Bool = isvariant(ty, TYPE_UNKNOWN)

isTuple(ty::ModelicaType)::Bool = isvariant(ty, TYPE_TUPLE)

""" #= Returns true for all the builtin scalar types such as Integer, Real, etc. =#"""
@nospecializeinfer function isScalarBuiltin(ty::ModelicaType)::Bool

  @match ty begin
    TYPE_INTEGER(__) => true

    TYPE_REAL(__) => true

    TYPE_STRING(__) => true

    TYPE_BOOLEAN(__) => true

    TYPE_CLOCK(__) => true

    TYPE_ENUMERATION(__) => true

    TYPE_ENUMERATION_ANY(__) => true

    TYPE_FUNCTION(__) => isScalarBuiltin(returnType(functionOf(ty)))

    _ => false
  end
end

function isNumeric(ty::ModelicaType)::Bool

  @match ty begin
    TYPE_ARRAY(__) => isBasicNumeric(ty.elementType)

    _ => isBasicNumeric(ty)
  end
end

isBasicNumeric(ty::ModelicaType)::Bool = isvariant(ty, TYPE_REAL) || isvariant(ty, TYPE_INTEGER)

@nospecializeinfer function isBasic(ty::ModelicaType)::Bool
  @match ty begin
    TYPE_REAL(__) => true
    TYPE_INTEGER(__) => true

    TYPE_BOOLEAN(__) => true

    TYPE_STRING(__) => true

    TYPE_ENUMERATION(__) => true

    TYPE_CLOCK(__) => true

    TYPE_FUNCTION(__) => isBasic(returnType(functionOf(ty)))

    _ => false
  end
end

function isRecord(ty::ModelicaType)::Bool

  @match ty begin
    TYPE_COMPLEX(complexTy = COMPLEX_RECORD(__)) => true

    _ => false
  end
end

function isExternalObject(ty::ModelicaType)::Bool

  @match ty begin
    TYPE_COMPLEX(complexTy = COMPLEX_EXTERNAL_OBJECT(__)) => true

    _ => false
  end
end

function isExpandableConnector(ty::ModelicaType)::Bool

  @match ty begin
    TYPE_COMPLEX(complexTy = COMPLEX_EXPANDABLE_CONNECTOR(__)) => true
    _ => false
  end
end

function isConnector(ty::ModelicaType)::Bool

  @match ty begin
    TYPE_COMPLEX(complexTy = COMPLEX_CONNECTOR(__)) => true
    _ => false
  end
end

isComplex(ty::ModelicaType)::Bool = isvariant(ty, TYPE_COMPLEX)

function complexNode(ty)
  local node::InstNode
  @match TYPE_COMPLEX(cls = node) = ty
  return node
end

function complexComponents(ty)
  getComponents(classTree(getClass(complexNode(ty))))
end

isEnumeration(ty::ModelicaType)::Bool = isvariant(ty, TYPE_ENUMERATION) || isvariant(ty, TYPE_ENUMERATION_ANY)

function isSingleElementArray(ty::ModelicaType)::Bool
  local d::Dimension
  @match ty begin
    TYPE_ARRAY(dimensions = d <| nil()) => isKnown(d) && size(d) == 1
    _ => false
  end
end

function isEmptyArray(ty::ModelicaType)::Bool
  @match ty begin
    TYPE_ARRAY(__) => ListUtil.exist(ty.dimensions, isZero)
    _ => false
  end
end

function isSquareMatrix(ty::ModelicaType)::Bool

  local d1::Dimension
  local d2::Dimension
  @match ty begin
    TYPE_ARRAY(dimensions = d1 <| d2 <| nil()) => isEqualKnown(d1, d2)

    _ => false
  end
end

function isMatrix(ty::ModelicaType)::Bool

  @match ty begin
    TYPE_ARRAY(dimensions = _ <| _ <| nil()) => true

    _ => false
  end
end

"""Return whether the type is a vector type or not, i.e. a 1-dimensional array."""
function isVector(ty::ModelicaType)::Bool

  @match ty begin
    TYPE_ARRAY(dimensions = _ <| nil()) => true

    _ => false
  end
end

isArray(ty::ModelicaType)::Bool = isvariant(ty, TYPE_ARRAY)

isScalar(ty::ModelicaType)::Bool = !isvariant(ty, TYPE_ARRAY)

"Whether `ty` is a function type: a functional input (`input Base f`), a partial application (`function f(a = 1)`)."
function isFunction(ty::ModelicaType)::Bool
  return @match ty begin
    TYPE_FUNCTION(__) => true
    _ => false
  end
end

isClock(ty::ModelicaType)::Bool = isvariant(ty, TYPE_CLOCK)

isString(ty::ModelicaType)::Bool = isvariant(ty, TYPE_STRING)

isBoolean(ty::ModelicaType)::Bool = isvariant(ty, TYPE_BOOLEAN)

isReal(ty::ModelicaType)::Bool = isvariant(ty, TYPE_REAL)

isInteger(ty::ModelicaType)::Bool = isvariant(ty, TYPE_INTEGER)

function unliftArrayN(N::Int, ty::ModelicaType)::ModelicaType

  local el_ty::ModelicaType
  local dims::List{Dimension}

  N == 0 && return ty
  @match TYPE_ARRAY(el_ty, dims) = ty
  for _ = 1:N
    dims = listRest(dims)
  end
  if listEmpty(dims)
    ty = el_ty
  else
    ty = TYPE_ARRAY(el_ty, dims)
  end
  return ty
end

function unliftArray(ty::ModelicaType)::ModelicaType

  local el_ty::ModelicaType
  local dims::List{Dimension}

  @match TYPE_ARRAY(el_ty, Cons{Dimension}(_, dims)) = ty
  if listEmpty(dims)
    ty = el_ty
  else
    ty = TYPE_ARRAY(el_ty, dims)
  end
  return ty
end

"""  Adds array dimensions to a type on the left side, e.g.
     listArrayLeft(Real[2, 3], [4, 5]) => Real[4, 5, 2, 3].
"""
function liftArrayLeftList(ty::ModelicaType, dims::List{<:Dimension})::ModelicaType
  if listEmpty(dims)
    return ty
  end
  ty = begin
    @match ty begin
      TYPE_ARRAY(__) => TYPE_ARRAY(ty.elementType, listAppend(dims, ty.dimensions))
      _ => TYPE_ARRAY(ty, dims)
    end
  end
  return ty
end

"""
  Adds an array dimension to a type on the left side, e.g.
  listArrayLeft(Real[2, 3], [4]) => Real[4, 2, 3].
"""
function liftArrayLeft(ty::ModelicaType, dim::Dimension)::ModelicaType
  @match ty begin
    TYPE_ARRAY(__) => begin
      return TYPE_ARRAY(ty.elementType, Cons{Dimension}(dim, ty.dimensions))
    end
    _ => begin
      return TYPE_ARRAY(ty, list(dim))
    end
  end
end

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

#= The ModelicaType struct and its ModelicaTypeTag enum are in FrontendInterfaces/NFInterfaces.jl (see
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
  @assign strl = list(toString(t) for t in subscriptTypes)
  @assign strl = _cons("_", strl)
  @assign strl = _cons(toString(expType), strl)
  @assign strl = _cons("subscript", strl)
  @assign str = stringAppendList(strl)
  return str
end

function sizeType(arrayTy::ModelicaType)::ModelicaType
  local sizeTy::ModelicaType

  if isUnknown(arrayTy)
    @assign sizeTy = TYPE_UNKNOWN()
  else
    @assign sizeTy = TYPE_ARRAY(
      TYPE_INTEGER(),
      list(fromInteger(dimensionCount(arrayTy))),
    )
  end
  #= Return unknown type if the type is unknown, to avoid returning Array[0]
     for untyped expressions. =#
  return sizeTy
end

function isBoxed(ty::ModelicaType)::Bool
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

function unbox(ty::ModelicaType)::ModelicaType
  local unboxedType::ModelicaType

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

function box(ty::ModelicaType)::ModelicaType
  local boxedType::ModelicaType

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

function enumSize(ty::ModelicaType)::Int
  local size::Int
  local literals::List{String}
  @match TYPE_ENUMERATION(literals = literals) = ty
  @assign size = listLength(literals)
  return size
end

function enumName(ty::ModelicaType)::Absyn.Path
  local name::Absyn.Path
  @match TYPE_ENUMERATION(typePath = name) = ty
  return name
end

function recordFields(recordType::ModelicaType)::List{Field}
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

@nospecializeinfer function lookupRecordFieldType(name::String, recordType::ModelicaType)::ModelicaType
  local fieldType::ModelicaType

  @assign fieldType = begin
    @match recordType begin
      TYPE_COMPLEX(__) => begin
        getType(lookupElementNode(name, getClass(recordType.cls)))
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

@nospecializeinfer function isDiscrete(ty::ModelicaType)::Bool
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
        isDiscrete(returnType(functionOf(ty)))
      end
      _ => begin
        false
      end
    end
  end
  return b
end

@nospecializeinfer function isEqual(ty1::ModelicaType, ty2::ModelicaType)::Bool
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
function subscript(ty::ModelicaType, subs::List{<:Subscript})::ModelicaType

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

function typenameString(ty::ModelicaType)::String
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


@nospecializeinfer function toFlatString(ty::ModelicaType)::String
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
        "(" + stringDelimitList(ListUtil.map(ty.types, toString, String), ", ") + ")"
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
        typeString(functionOf(ty))
      end

      TYPE_METABOXED(__) => begin
        "#" + toFlatString(ty.ty)
      end

      TYPE_POLYMORPHIC(__) => begin
        "<" + ty.name + ">"
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

function toFlatDeclarationStream(ty::ModelicaType, s::IOStream_M.IOSTREAM)
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
        "(" + stringDelimitList(ListUtil.map(ty.types, toString, String), ", ") + ")"
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
        typeString(functionOf(ty))
      end

      TYPE_METABOXED(__) => begin
        "#" + toString(ty.ty)
      end

      TYPE_POLYMORPHIC(__) => begin
        "<" + ty.name + ">"
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

function foldDims(ty::ModelicaType, func::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}

  @assign arg = begin
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

      TYPE_FUNCTION(__) => begin
        foldDims(returnType(functionOf(ty)), func, arg, ArgT)
      end

      TYPE_METABOXED(__) => begin
        foldDims(ty.ty, func, arg, ArgT)
      end

      _ => begin
        arg
      end
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
    _ => begin
      ty
    end
  end
  return retTy
end

function hasZeroDimension(ty::ModelicaType)::Bool
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

@nospecializeinfer function hasKnownSize(ty::ModelicaType)::Bool
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
        hasKnownSize(returnType(functionOf(ty)))
      end
      _ => begin
        true
      end
    end
  end
  return known
end

@nospecializeinfer function dimensionCount(ty::ModelicaType)::Int
  local dimCount::Int
  @assign dimCount = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        listLength(ty.dimensions)
      end
      TYPE_FUNCTION(__) => begin
        dimensionCount(returnType(functionOf(ty)))
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

@nospecializeinfer function nthDimension(ty::ModelicaType, index::Int)::Dimension
  local dim::Dimension

  @assign dim = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        listGet(ty.dimensions, index)
      end

      TYPE_FUNCTION(__) => begin
        nthDimension(returnType(functionOf(ty)), index)
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
function copyDims(srcType::ModelicaType, dstType::ModelicaType)::ModelicaType
  local ty::ModelicaType
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

@nospecializeinfer function arrayDims(ty::ModelicaType)::List{Dimension}
  @match ty begin
    TYPE_ARRAY(__) => begin
      ty.dimensions
    end
    TYPE_FUNCTION(__) => begin
      arrayDims(returnType(functionOf(ty)))
    end
    TYPE_METABOXED(__) => begin
      arrayDims(ty.ty)
    end
    _ => begin
      nil
    end
  end
end

@nospecializeinfer function elementType(ty::ModelicaType)::ModelicaType
  local elementTy::ModelicaType
  @assign elementTy = begin
    @match ty begin
      TYPE_ARRAY(__) => begin
        ty.elementType
      end
      TYPE_FUNCTION(__) => begin
        elementType(returnType(functionOf(ty)))
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
function setArrayElementType(arrayTy::ModelicaType, elementTy::ModelicaType)::ModelicaType
  local ty::ModelicaType
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
function arrayElementType(ty::ModelicaType)::ModelicaType
  local elementTy::ModelicaType

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

@nospecializeinfer function nthTupleType(ty::ModelicaType, n::Int)::ModelicaType
  local outTy::ModelicaType
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

@nospecializeinfer function firstTupleType(ty::ModelicaType)::ModelicaType
  local outTy::ModelicaType
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

function isPolymorphic(ty::ModelicaType)::Bool
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

function isKnown(ty::ModelicaType)::Bool
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

function isUnknown(ty::ModelicaType)::Bool
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

function isTuple(ty::ModelicaType)::Bool
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
@nospecializeinfer function isScalarBuiltin(ty::ModelicaType)::Bool
  local res::Bool

  @assign res = begin
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
        isScalarBuiltin(returnType(functionOf(ty)))
      end

      _ => begin
        false
      end
    end
  end
  return res
end

function isNumeric(ty::ModelicaType)::Bool
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

function isBasicNumeric(ty::ModelicaType)::Bool
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

@nospecializeinfer function isBasic(ty::ModelicaType)::Bool
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
        isBasic(returnType(functionOf(ty)))
      end

      _ => begin
        false
      end
    end
  end
  return isNumeric
end

function isScalarArray(ty::ModelicaType)::Bool
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

function isRecord(ty::ModelicaType)::Bool
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

function isExternalObject(ty::ModelicaType)::Bool
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

function isExpandableConnector(ty::ModelicaType)::Bool
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

function isConnector(ty::ModelicaType)::Bool
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

function isComplex(ty::ModelicaType)::Bool
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

function isEnumeration(ty::ModelicaType)::Bool
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

function isSingleElementArray(ty::ModelicaType)::Bool
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

function isEmptyArray(ty::ModelicaType)::Bool
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

function isSquareMatrix(ty::ModelicaType)::Bool
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

function isMatrix(ty::ModelicaType)::Bool
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
function isVector(ty::ModelicaType)::Bool
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

function isArray(ty::ModelicaType)::Bool
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

function isScalar(ty::ModelicaType)::Bool
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

"Whether `ty` is a function type: a functional input (`input Base f`), a partial application (`function f(a = 1)`)."
function isFunction(ty::ModelicaType)::Bool
  return @match ty begin
    TYPE_FUNCTION(__) => true
    _ => false
  end
end

function isClock(ty::ModelicaType)::Bool
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

function isString(ty::ModelicaType)::Bool
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

function isBoolean(ty::ModelicaType)::Bool
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

function isReal(ty::ModelicaType)::Bool
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

function isInteger(ty::ModelicaType)::Bool
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

function unliftArrayN(N::Int, ty::ModelicaType)::ModelicaType

  local el_ty::ModelicaType
  local dims::List{Dimension}

  N == 0 && return ty
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

function unliftArray(ty::ModelicaType)::ModelicaType

  local el_ty::ModelicaType
  local dims::List{Dimension}

  @match TYPE_ARRAY(el_ty, Cons{Dimension}(_, dims)) = ty
  if listEmpty(dims)
    @assign ty = el_ty
  else
    @assign ty = TYPE_ARRAY(el_ty, dims)
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

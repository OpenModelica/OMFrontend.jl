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

#= Typing of the builtin functions with their own rules (omc: NFBuiltinCall.mo): `typeSpecial` picks the function by
   name; each returns the typed expression, its type and its variability. =#

"""Whether the untyped `call` is to a builtin function with its own typing rules (`typeSpecial`)."""
function needSpecialHandling(call::Call)::Bool
  if !(isvariant(call, UNTYPED_CALL))
    Error.assertion(false, getInstanceName() + " got unknown call: " + toString(call), sourceInfo())
    fail()
  end
  local special::Bool
  @match C_FUNCTION(specialBuiltin = special) = getFuncCache(classScope(node(call.ref)))
  return special
end

"""
Type a call to a builtin function with its own typing rules (`isSpecialBuiltinCall`): its typed call expression, type
and variability. Arguments are typed as subexpressions of `origin`.
"""
@nospecializeinfer function typeSpecial(call::Call, origin::ORIGIN_Type,
                                        info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local cref::ComponentRef
  @match UNTYPED_CALL(ref = cref) = call
  local o::ORIGIN_Type = setFlag(origin, ORIGIN_SUBEXPRESSION)
  return @match firstName(cref) begin
    "String"                 => typeStringCall(call, o, info)
    "actualStream"           => typeActualInStreamCall("actualStream", call, o, info)
    "branch"                 => typeBranchCall(call, o, info)
    "cardinality"            => typeCardinalityCall(call, o, info)
    "cat"                    => typeCatCall(call, o, info)
    "change"                 => typeChangeCall(call, o, info)
    "der"                    => typeDerCall(call, o, info)
    "diagonal"               => typeDiagonalCall(call, o, info)
    "edge"                   => typeEdgeCall(call, o, info)
    "fill"                   => typeFillCall(call, o, info)
    "getInstanceName"        => typeGetInstanceName(call)
    "initial"                => typeDiscreteCall(call, o, info)
    "inStream"               => typeActualInStreamCall("inStream", call, o, info)
    "isRoot"                 => typeIsRootCall(call, o, info)
    "matrix"                 => typeMatrixCall(call, o, info)
    "max"                    => typeMinMaxCall("max", call, o, info)
    "min"                    => typeMinMaxCall("min", call, o, info)
    "ndims"                  => typeNdimsCall(call, o, info)
    "noEvent"                => typeNoEventCall(call, o, info)
    "ones"                   => typeZerosOnesCall("ones", call, o, info)
    "potentialRoot"          => typePotentialRootCall(call, o, info)
    "pre"                    => typePreCall(call, o, info)
    "product"                => typeProductCall(call, o, info)
    "promote"                => typePromoteCall(call, o, info)
    "pure"                   => typePureCall(call, o, info)
    "root"                   => typeRootCall(call, o, info)
    "rooted"                 => typeRootedCall(call, o, info)
    "uniqueRoot"             => typeUniqueRootCall(call, o, info)
    "uniqueRootIndices"      => typeUniqueRootIndicesCall(call, o, info)
    "scalar"                 => typeScalarCall(call, o, info)
    "smooth"                 => typeSmoothCall(call, o, info)
    "sum"                    => typeSumCall(call, o, info)
    "symmetric"              => typeSymmetricCall(call, o, info)
    "terminal"               => typeDiscreteCall(call, o, info)
    "transpose"              => typeTransposeCall(call, o, info)
    "vector"                 => typeVectorCall(call, o, info)
    "zeros"                  => typeZerosOnesCall("zeros", call, o, info)
    "Clock" where (Config.synchronousFeaturesAllowed()) => typeClockCall(call, o, info)
    "sample"                 => typeSampleCall(call, o, info)
    "DynamicSelect"          => typeDynamicSelectCall("DynamicSelect", call, o, info)
    "initialStructuralState" => typeInitialStructuralStateCall(call, o, info)
    "structuralTransition"   => typeStructuralTransition(call, o, info)
    "recompilation"          => typeRecompilationCall(call, o, info)
    "agentic_recompilation"  => typeAgenticRecompilationCall(call, o, info)
    #= Not yet: hold, shiftSample, backSample, noClock, transition, initialState, activeState, ticksInState,
       timeInState (omc types them when synchronous features are allowed). =#
    _ => begin
      Error.assertion(false, getInstanceName() + " got unhandled builtin function: " + toString(call), sourceInfo())
      fail()
    end
  end
end

"""
The function reference and positional arguments of the untyped `call` of `name`. It takes no named arguments and a
number of positional ones in `nargs`; otherwise an error naming the call and `signature`.
"""
function _untypedArgs(call::Call, name::String, nargs::UnitRange{Int}, signature::String,
                      info::SourceInfo)::Tuple{ComponentRef, Vector{Expression}}
  local fnRef::ComponentRef
  local args::Vector{Expression}
  local namedArgs::Vector{NamedArg}
  @match UNTYPED_CALL(ref = fnRef, arguments = args, named_args = namedArgs) = call
  assertNoNamedParams(name, namedArgs, info)
  if !(length(args) in nargs)
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), signature), info)
  end
  return (fnRef, args)
end

"""An error if `origin` is a function: `name` may not be used there."""
function _notInFunction(origin::ORIGIN_Type, name::String, info::SourceInfo)::Nothing
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessageAndFail(Error.EXP_INVALID_IN_FUNCTION, list(name), info)
  end
  return nothing
end

"""The builtin function `fnRef` refers to."""
_builtinFunction(fnRef::ComponentRef)::MODELICA_FUNCTION = Base.first(typeRefCache(fnRef))

"""The typed call of the builtin `fnRef` with the arguments `args`, variability `var` and type `ty`."""
function _builtinCall(fnRef::ComponentRef, args::Vector{Expression}, var::VariabilityType,
                      ty::ModelicaType)::Expression
  return CALL_EXPRESSION(makeTypedCall(_builtinFunction(fnRef), args, var, ty))
end

_unaryCall(fnRef::ComponentRef, @nospecialize(arg::Expression), var::VariabilityType, ty::ModelicaType)::Expression =
  _builtinCall(fnRef, Expression[arg], var, ty)

"""`size(A)` or `size(A, i)` of the untyped arguments."""
function makeSizeExp(posArgs::Vector{Expression}, namedArgs::Vector{NamedArg}, info::SourceInfo)::Expression
  assertNoNamedParams("size", namedArgs, info)
  length(posArgs) == 1 && return SIZE_EXPRESSION(posArgs[1], NONE())
  length(posArgs) == 2 && return SIZE_EXPRESSION(posArgs[1], SOME(posArgs[2]))
  Error.addSourceMessage(Error.NO_MATCHING_FUNCTION_FOUND_NFINST,
                         list("size" + ListUtil.toString(posArgs, toString, "", "(", ", ", ")", true),
                              "size(Any[:, ...]) => Integer[:]\\n  size(Any[:, ...], Integer) => Integer"), info)
  fail()
end

"""`array(a, b, ...)` of the untyped arguments (at least one)."""
function makeArrayExp(posArgs::Union{List{<:Expression}, Vector{<:Expression}},
                      namedArgs::Union{List{<:NamedArg}, Vector{<:NamedArg}}, info::SourceInfo)::Expression
  assertNoNamedParams("array", namedArgs, info)
  if isempty(posArgs)
    Error.addSourceMessage(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list("array()", "array(Any, Any, ...) => Any[:]"), info)
    fail()
  end
  return makeArray(TYPE_UNKNOWN(), posArgs isa Vector ? list(posArgs...) : posArgs)
end

"""
The call `cat(n, args...)` of the typed arguments `args`, and its type: `makeCatExpRef` with a type `Ref` of its own.
"""
function makeCatExp(n::Int,
                    args::Vector{Expression},
                    tys::Vector{ModelicaType},
                    variability::VariabilityType, info::SourceInfo)::Tuple{CALL_EXPRESSION, ModelicaType}
  local tyRef::Base.RefValue{ModelicaType} = Ref{ModelicaType}(TYPE_UNKNOWN())
  local callExp::CALL_EXPRESSION = makeCatExpRef(n, args, tys, variability, info, tyRef)
  return (callExp, tyRef.x)
end

"""The common type of `tys`: each matched to the ones before it (matchExpressions); incompatible ones are skipped."""
function _catCommonType(tys::Vector{ModelicaType})::ModelicaType
  local zero::Expression = INTEGER_EXPRESSION(0)
  local common::ModelicaType = TYPE_UNKNOWN()
  for ty::ModelicaType in tys
    if isvariant(common, TYPE_UNKNOWN)
      common = ty
    else
      local (_, _, matched::ModelicaType, mk::MatchKindType) = matchExpressions(zero, ty, zero, common)
      isCompatibleMatch(mk) && (common = matched)
    end
  end
  return common
end

"""
The call `cat(n, args...)` of the typed arguments `args`; its type is set in `tyRef`, which also holds each argument's
matched type while the arguments are matched. The arguments are matched first to the common element type, then to the
common array type with dimension `n` unknown; dimension `n` of the result is the sum of the arguments'.
"""
function makeCatExpRef(n::Int,
                       args::Vector{Expression},
                       tys::Vector{ModelicaType},
                       variability::VariabilityType,
                       info::SourceInfo,
                       tyRef::Ref{ModelicaType})::CALL_EXPRESSION
  @assert length(args) == length(tys) && length(args) >= 1
  local mkRef::Base.RefValue{MatchKindType} = Ref{MatchKindType}(MatchKind.NOT_COMPATIBLE)
  #= The arguments' dimensions, last argument first (as omc). =#
  local dimsLst::Vector{List{Dimension}} = List{Dimension}[arrayDims(ty) for ty in Iterators.reverse(tys)]
  local ndims::Vector{Int} = Int[listLength(d) for d in dimsLst]
  local maxn::Int = maximum(ndims)
  if maxn != minimum(ndims)
    Error.addSourceMessageAndFail(Error.NF_DIFFERENT_NUM_DIM_IN_ARGUMENTS,
                                  list(Base.join(string.(ndims), ", "), "cat"), info)
  end
  if n < 1 || n > maxn
    Error.addSourceMessageAndFail(Error.NF_CAT_WRONG_DIMENSION, list(string(maxn), string(n)), info)
  end
  #= The arguments are numbered from the last (as omc's message). =#
  local argNumber(i::Int)::String = string(length(args) + 2 - i)
  #= First: each argument with the common element type. =#
  local elementTy::ModelicaType = _catCommonType(ModelicaType[arrayElementType(ty) for ty in tys])
  local args2::Vector{Expression} = Vector{Expression}(undef, length(args))
  local tys2::Vector{ModelicaType} = Vector{ModelicaType}(undef, length(args))
  for i::Int in eachindex(args)
    local elementTarget::ModelicaType = setArrayElementType(tys[i], elementTy)
    args2[i] = matchTypesRef(tys[i], elementTarget, args[i], tyRef, mkRef, #= allowUnknown =# true)
    if isIncompatibleMatch(mkRef.x)
      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list(argNumber(i), "cat", "arg", toString(args[i]),
                                                                  toString(tys[i]), toString(elementTarget)), info)
    end
    tys2[i] = tyRef.x
  end
  #= Second: each argument with the common type, dimension n unknown; dimension n of the result is the sum. =#
  local commonTy::ModelicaType = _catCommonType(tys2)
  local target::ModelicaType =
    TYPE_ARRAY(arrayElementType(commonTy), ListUtil.set(arrayDims(commonTy), n, DIMENSION_UNKNOWN(), Dimension))
  local sumDim::Dimension = fromInteger(0)
  for dims::List{Dimension} in dimsLst
    sumDim = add(sumDim, listGet(dims, n))
  end
  local resTy::ModelicaType =
    TYPE_ARRAY(arrayElementType(commonTy), ListUtil.set(arrayDims(commonTy), n, sumDim, Dimension))
  local res::Vector{Expression} = Expression[INTEGER_EXPRESSION(n)]
  for i::Int in eachindex(args2)
    push!(res, matchTypesRef(tys2[i], target, args2[i], tyRef, mkRef, #= allowUnknown =# true))
    if isIncompatibleMatch(mkRef.x)
      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list(argNumber(i), "cat", "arg", toString(args2[i]),
                                                                  toString(tys2[i]), toString(target)), info)
    end
  end
  tyRef.x = resTy
  return CALL_EXPRESSION(makeTypedCall(BuiltinFuncs.CAT, res, variability, resTy))
end

"""An error if `namedArgs` is not empty: the builtin `fnName` takes no named arguments."""
function assertNoNamedParams(fnName::String, namedArgs::Union{Vector{<:NamedArg}, List{<:NamedArg}},
                             info::SourceInfo)::Nothing
  if !isempty(namedArgs)
    Error.addSourceMessage(Error.NO_SUCH_PARAMETER, list(fnName, Util.tuple21(namedArgs[1])), info)
    fail()
  end
  return nothing
end

"""`String(x, ...)`: the builtin one, or the record's `'String'` overload."""
function typeStringCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local tyCall::Call = typeNormalCall(call, origin, info)
  local args::Vector{TypedArg}
  local namedArgs::Vector{TypedNamedArg}
  @match ARG_TYPED_CALL(_, args, namedArgs) = tyCall
  isempty(args) && fail()
  local argTy::ModelicaType = arrayElementType(args[1][2])
  if isComplex(argTy)
    return typeOverloadedStringCall(argTy, args, namedArgs, tyCall, origin, info)
  end
  return typeBuiltinStringCall(tyCall, origin, info)
end

function typeBuiltinStringCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local tyCall::Call = matchTypedNormalCall(call, origin, info)
  return (CALL_EXPRESSION(tyCall), typeOf(tyCall), variability(tyCall))
end

"""`String(r, ...)` of a record `r`: the call of the record's `'String'` operator that matches the arguments exactly."""
function typeOverloadedStringCall(overloadedType::ModelicaType, args::Vector{TypedArg},
                                  namedArgs::Vector{TypedNamedArg}, call::Call, origin::ORIGIN_Type,
                                  info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local recordNode::InstNode
  @match TYPE_COMPLEX(cls = recordNode) = overloadedType
  local fnRef::ComponentRef
  try
    fnRef = lookupFunctionSimple("'String'", recordNode)
  catch
    #= No 'String' overload: the builtin String call reports the error. =#
    typeBuiltinStringCall(call, origin, info)
    fail()
  end
  fnRef = instFunctionRef(fnRef, InstNode_info(recordNode))[1]
  local candidates::Vector{MODELICA_FUNCTION} = MODELICA_FUNCTION[fn for fn in typeRefCache(fnRef)]
  local matchedFunctions::Vector{MatchedFunction} = matchFunctionsSilent(candidates, args, namedArgs, info)
  local exactMatches::Vector{MatchedFunction} = getExactMatches(matchedFunctions)
  if isempty(exactMatches)
    Error.addSourceMessage(Error.NO_MATCHING_FUNCTION_FOUND_NFINST,
                           list(typedString(call), candidateFuncListString(candidates)), info)
    fail()
  end
  if length(exactMatches) > 1
    Error.addSourceMessage(Error.AMBIGUOUS_MATCHING_FUNCTIONS_NFINST,
                           list(typedString(call),
                                candidateFuncListString(MODELICA_FUNCTION[mfn.func for mfn in matchedFunctions])), info)
    fail()
  end
  local matched::MatchedFunction = exactMatches[1]
  local outType::ModelicaType = returnType(matched.func)
  local var::VariabilityType = Variability.CONSTANT
  for arg in matched.args
    var = variabilityMax(var, Util.tuple33(arg))
  end
  local fnArgs::Vector{Expression} = Expression[Util.tuple31(a) for a in matched.args]
  return (CALL_EXPRESSION(makeTypedCall(matched.func, fnArgs, var, outType)), outType, var)
end

"""
A call typed as a normal call, but discrete whatever the arguments' variability (`initial()`, `terminal()`).
"""
function typeDiscreteCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local tyCall::Call = typeMatchNormalCall(call, origin, info)
  return (CALL_EXPRESSION(unboxArgs(tyCall)), typeOf(tyCall), Variability.DISCRETE)
end

"""`ndims(A)`: always known, so evaluated here."""
function typeNdimsCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local args::Vector{Expression} = _untypedArgs(call, "ndims", 1:1, "ndims(Any) => Integer", info)[2]
  local argTy::ModelicaType = typeExp(args[1], origin, info)[2]
  return (INTEGER_EXPRESSION(dimensionCount(argTy)), TYPE_INTEGER(), Variability.PARAMETER)
end

typePreCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType} =
  typePreChangeCall("pre", call, origin, info)

function typeChangeCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (callExp::Expression, ty::ModelicaType, var::VariabilityType) = typePreChangeCall("change", call, origin, info)
  return (callExp, setArrayElementType(ty, TYPE_BOOLEAN()), var)
end

"""`pre(v)` or `change(v)` (`name`): `v` a discrete variable, not in a function. The call is discrete."""
function typePreChangeCall(name::String, call::Call, origin::ORIGIN_Type,
                           info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, name, 1:1, toString(call.ref) + "(Any) => Any", info)
  _notInFunction(origin, toString(fnRef), info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  if !isCref(arg)
    Error.addSourceMessage(Error.ARGUMENT_MUST_BE_VARIABLE, list("First", toString(fnRef), "<REMOVE ME>"), info)
    fail()
  end
  if var == Variability.CONTINUOUS
    Error.addSourceMessageAndFail(Error.INVALID_ARGUMENT_VARIABILITY,
                                  list("1", toString(fnRef), variabilityString(Variability.DISCRETE), toString(arg),
                                       variabilityString(var)), info)
  end
  return (_unaryCall(fnRef, arg, var, ty), ty, Variability.DISCRETE)
end

"""`der(x)`: `x` Real (or a non-discrete Integer, cast to Real), not discrete outside a discrete scope."""
function typeDerCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  _notInFunction(origin, "der", info)
  local (fnRef::ComponentRef, args::Vector{Expression}) = _untypedArgs(call, "der", 1:1, "der(Real) => Real", info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  local elementTy::ModelicaType = arrayElementType(ty)
  if isInteger(elementTy)
    #= omc: only an Integer that is not discrete (a parameter or constant) is differentiable. =#
    if var >= Variability.DISCRETE
      Error.addSourceMessageAndFail(Error.DER_OF_NONDIFFERENTIABLE_EXP, list(toString(arg)), info)
    end
    ty = setArrayElementType(ty, TYPE_REAL())
    arg = typeCast(arg, TYPE_REAL())
  elseif !isReal(elementTy)
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH,
                                  list("1", toString(fnRef), "", toString(arg), toString(ty), "Real"), info)
  end
  #= omc: the argument must be differentiable, i.e. not discrete, except in a discrete scope (when, initial). =#
  if var == Variability.DISCRETE && !flagSet(origin, ORIGIN_DISCRETE_SCOPE)
    Error.addSourceMessageAndFail(Error.DER_OF_NONDIFFERENTIABLE_EXP, list(toString(arg)), info)
  end
  return (_unaryCall(fnRef, arg, var, ty), ty, var)
end

"""`diagonal(v)`: the n x n matrix of the vector `v`."""
function typeDiagonalCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, "diagonal", 1:1, "diagonal(Any[n]) => Any[n, n]", info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  if !(isvariant(ty, TYPE_ARRAY) && listLength(ty.dimensions) == 1)
    Error.addSourceMessage(Error.ARG_TYPE_MISMATCH, list("1", toString(fnRef), "", toString(arg), toString(ty), "Any[:]"),
                           info)
    fail()
  end
  local dim::Dimension = listHead(ty.dimensions)
  local resTy::ModelicaType = TYPE_ARRAY(ty.elementType, list(dim, dim))
  return (_unaryCall(fnRef, arg, var, resTy), resTy, var)
end

"""`edge(b)`: `b` a variable, not in a function. The call is discrete."""
function typeEdgeCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  _notInFunction(origin, "edge", info)
  local argCall::Call = typeNormalCall(call, origin, info)
  local tyCall::Call = matchTypedNormalCall(argCall, origin, info)
  if !isCref(Util.tuple31(Base.first(argCall.arguments)))
    Error.addSourceMessage(Error.ARGUMENT_MUST_BE_VARIABLE, list("First", "edge", "<REMOVE ME>"), info)
    fail()
  end
  return (CALL_EXPRESSION(unboxArgs(tyCall)), typeOf(tyCall), Variability.DISCRETE)
end

"""omc typeMinMaxCall: the argument types min and max accept."""
function minMaxValidType(ty::ModelicaType)::Bool
  return isReal(ty) || isInteger(ty) || isBoolean(ty) || isEnumeration(ty)
end

function minMaxInvalidArgsError(call::Call, name::String, info::SourceInfo)
  Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST,
    list(toString(call),
         name + "(Real, Real) => Real\n  " +
         name + "(Integer, Integer) => Integer\n  " +
         name + "(Boolean, Boolean) => Boolean\n  " +
         name + "(enumeration(:), enumeration(:)) => enumeration(:)\n  " +
         name + "(Real[:, ...]) => Real\n  " +
         name + "(Integer[:, ...]) => Integer\n  " +
         name + "(Boolean[:, ...]) => Boolean\n  " +
         name + "(enumeration(:)[:, ...]) => enumeration(:)"), info)
end

"""`min`/`max` (`name`) of an array, or of two scalars matched to a common type."""
function typeMinMaxCall(name::String, call::Call, origin::ORIGIN_Type,
                        info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local fnRef::ComponentRef
  local args::Vector{Expression}
  local namedArgs::Vector{NamedArg}
  @match UNTYPED_CALL(ref = fnRef, arguments = args, named_args = namedArgs) = call
  assertNoNamedParams(name, namedArgs, info)
  if length(args) == 1
    local (arg::Expression, argTy::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
    local ty::ModelicaType = arrayElementType(argTy)
    (isArray(argTy) && minMaxValidType(ty)) || minMaxInvalidArgsError(call, name, info)
    #= An array of one element: that element, no call. =#
    if isSingleElementArray(argTy)
      return (applySubscript(first(listHead(arrayDims(argTy))), arg), ty, var)
    end
    return (_unaryCall(fnRef, arg, var, ty), ty, var)
  elseif length(args) == 2
    local (arg1::Expression, ty1::ModelicaType, var1::VariabilityType) = typeExp(args[1], origin, info)
    local (arg2::Expression, ty2::ModelicaType, var2::VariabilityType) = typeExp(args[2], origin, info)
    (minMaxValidType(ty1) && minMaxValidType(ty2)) || minMaxInvalidArgsError(call, name, info)
    local (m1::Expression, m2::Expression, commonTy::ModelicaType, mk::MatchKindType) = matchExpressions(arg1, ty1, arg2, ty2)
    isValidArgumentMatch(mk) || minMaxInvalidArgsError(call, name, info)
    local maxVar::VariabilityType = variabilityMax(var1, var2)
    return (_builtinCall(fnRef, Expression[m1, m2], maxVar, commonTy), commonTy, maxVar)
  end
  minMaxInvalidArgsError(call, name, info)
  fail()
end

"""`sum(A)` and `product(A)` (`name`): the element type of `A`."""
function _typeReductionCall(name::String, call::Call, origin::ORIGIN_Type,
                            info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, name, 1:1, name + "(Any[:, ...]) => Any", info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  local elementTy::ModelicaType = arrayElementType(ty)
  return (_unaryCall(fnRef, arg, var, elementTy), elementTy, var)
end

typeSumCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType} =
  _typeReductionCall("sum", call, origin, info)

typeProductCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType} =
  _typeReductionCall("product", call, origin, info)

"""`pure(f(x))`: the call of an impure function, made pure (omc typePureCall; the port has no purity on calls)."""
function typePureCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local tyCall::Call = typeMatchNormalCall(call, origin, info)
  local arg::Expression =
    length(tyCall.arguments) == 1 ? unbox(tyCall.arguments[1]) : EMPTY_EXPRESSION(TYPE_UNKNOWN())
  if !(arg isa CALL_EXPRESSION)
    Error.addSourceMessage(Error.FUNCTION_ARGUMENT_MUST_BE, list("pure", "a function call expression"), info)
    fail()
  end
  return (arg, typeOf(arg), variability(arg))
end

"""
`promote(A, n)`: `A` with trailing dimensions of size 1 up to `n` dimensions (omc typePromoteCall; needs
--std=experimental).
"""
function typePromoteCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  if !Config.languageStandardAtLeast(Config.LanguageStandard.experimental)
    Error.addSourceMessageAndFail(Error.EXPERIMENTAL_REQUIRED, list("promote"), info)
  end
  local args::Vector{Expression} =
    _untypedArgs(call, "promote", 2:2, "promote(Any[...], Integer) => Any[...]", info)[2]
  local (expArg::Expression, expTy::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  local (nArg::Expression, nTy::ModelicaType, nVar::VariabilityType) = typeExp(args[2], origin, info)
  if !isInteger(nTy)
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH,
                                  list("2", "promote", "", toString(nArg), toString(nTy), "Integer"), info)
  end
  if nVar > Variability.CONSTANT
    Error.addSourceMessageAndFail(Error.INVALID_ARGUMENT_VARIABILITY,
                                  list("2", "promote", variabilityString(Variability.CONSTANT), toString(nArg),
                                       variabilityString(nVar)), info)
  end
  local n::Int
  @match INTEGER_EXPRESSION(n) = evalExp(nArg, EVALTARGET_GENERIC(info))
  if n < dimensionCount(expTy)
    Error.addSourceMessageAndFail(Error.INVALID_NUMBER_OF_DIMENSIONS_FOR_PROMOTE,
                                  list(string(n), string(dimensionCount(expTy))), info)
  end
  local (callExp::Expression, ty::ModelicaType) = promote(expArg, typeOf(expArg), n)
  return (callExp, ty, var)
end

"""`smooth(p, expr)`: `p` an Integer parameter expression, `expr` Real (or an array of Real)."""
function typeSmoothCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, "smooth", 2:2, "smooth(Integer, Any) => Any", info)
  local (arg1::Expression, ty1::ModelicaType, var1::VariabilityType) = typeExp(args[1], origin, info)
  local (arg2::Expression, ty2::ModelicaType, var2::VariabilityType) = typeExp(args[2], origin, info)
  if !isInteger(ty1)
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH,
                                  list("1", toString(fnRef), "", toString(arg1), toString(ty1), "Integer"), info)
  end
  if var1 > Variability.PARAMETER
    Error.addSourceMessageAndFail(Error.INVALID_ARGUMENT_VARIABILITY,
                                  list("1", toString(fnRef), variabilityString(Variability.PARAMETER), toString(arg1),
                                       variabilityString(var1)), info)
  end
  #= TODO: records of Real components too. =#
  local (realArg::Expression, ty::ModelicaType, mk::MatchKindType) =
    matchTypes(ty2, setArrayElementType(ty2, TYPE_REAL()), arg2, #= allowUnknown =# true)
  if !isValidArgumentMatch(mk)
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH,
                                  list("2", toString(fnRef), "", toString(arg2), toString(ty2),
                                       "Real\\n  Real[:, ...]\\n  Real record\\n  Real record[:, ...]"), info)
  end
  return (_builtinCall(fnRef, Expression[arg1, realArg], var1, ty), ty, var2)
end

"""`fill(v, n1, n2, ...)`."""
function typeFillCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, "fill", 2:typemax(Int), "fill(Any, Integer, ...) => Any[:, ...]", info)
  local (fillArg::Expression, fillTy::ModelicaType, _) = typeExp(args[1], origin, info)
  return typeFillCall2(fnRef, fillTy, fillArg, args[2:end], origin, info)
end

"""
`fill`, `zeros` and `ones`: `fillArg` (of type `fillType`) in an array of the sizes `dimensionArgs` (Integer parameter
expressions outside algorithms). Evaluated when every size is a structural parameter; otherwise the call.
"""
function typeFillCall2(fnRef::ComponentRef,
                       fillType::ModelicaType,
                       @nospecialize(fillArg::Expression),
                       dimensionArgs::Vector{Expression},
                       origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local variability::VariabilityType = Variability.CONSTANT
  local tyArgs::Vector{Expression} = Expression[fillArg]
  local dims::Vector{Dimension} = Dimension[]
  local evaluated::Bool = true
  for (i::Int, dimArg::Expression) in enumerate(dimensionArgs)
    local (arg::Expression, argTy::ModelicaType, argVar::VariabilityType) = typeExp(dimArg, origin, info)
    if !(flagSet(origin, ORIGIN_ALGORITHM) || flagSet(origin, ORIGIN_FUNCTION)) && argVar > Variability.PARAMETER
      Error.addSourceMessageAndFail(Error.NON_PARAMETER_EXPRESSION_DIMENSION,
        list(toString(arg), intString(i),
             toString(fnRef) + "(" + Base.join([toString(e) for e in vcat(Expression[fillArg], dimensionArgs)], ", ") +
             ")"), info)
    end
    if argVar <= Variability.STRUCTURAL_PARAMETER && !flagSet(origin, ORIGIN_FUNCTION) && !containsIterator(arg, origin)
      arg = evalExp(arg)
      argTy = typeOf(arg)
    else
      evaluated = false
    end
    if !isInteger(argTy)
      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH,
                                    list(intString(length(tyArgs) + 1), toString(fnRef), "", toString(arg),
                                         toString(argTy), "Integer"), info)
    end
    variability = variabilityMax(variability, argVar)
    push!(tyArgs, arg)
    push!(dims, fromExp(arg, argVar))
  end
  local ty::ModelicaType = liftArrayLeftList(fillType, list(dims...))
  local callExp::Expression = evaluated ? evalBuiltinFill(tyArgs) : EVAL_FAILED
  #= Not evaluated, or sizes that did not evaluate to integers: the call. =#
  if isEvalFailure(callExp)
    callExp = CALL_EXPRESSION(makeTypedCall(BuiltinFuncs.FILL_FUNC, tyArgs, variability, ty))
  end
  return (callExp, ty, variability)
end

"""`zeros(n1, ...)` and `ones(n1, ...)` (`name`): `fill(0, ...)` and `fill(1, ...)`."""
function typeZerosOnesCall(name::String, call::Call, origin::ORIGIN_Type,
                           info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, name, 1:typemax(Int), toString(call.ref) + "(Integer, ...) => Integer[:, ...]", info)
  local fillArg::Expression = INTEGER_EXPRESSION(name == "ones" ? 1 : 0)
  return typeFillCall2(fnRef, TYPE_INTEGER(), fillArg, args, origin, info)
end

"""`scalar(A)`: the element of `A`, whose dimensions all have size 1."""
function typeScalarCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, "scalar", 1:1, "scalar(Any[1, ...]) => Any", info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  for dim in arrayDims(ty)
    if isKnown(dim) && size(dim) != 1
      Error.addSourceMessageAndFail(Error.INVALID_ARRAY_DIM_IN_SCALAR_OP, list(toString(ty)), info)
    end
  end
  local (expanded::Expression, isExpanded::Bool) = expand(arg)
  local elementTy::ModelicaType = arrayElementType(ty)
  if isExpanded
    local elements::List{Expression} = arrayScalarElements(expanded)
    if listLength(elements) != 1
      Error.assertion(false, getInstanceName() * " failed to expand scalar(" * toString(expanded) * ") correctly", info)
    end
    return (listHead(elements), elementTy, var)
  end
  return (_unaryCall(fnRef, expanded, var, elementTy), elementTy, var)
end

"""`vector(A)`: `A` with at most one dimension of size > 1, as a vector of that size."""
function typeVectorCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, "vector", 1:1, "vector(Any) => Any[:]\\n  vector(Any[:, ...]) => Any[:]", info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  local vectorDim::Dimension = fromInteger(1)
  local found::Bool = false
  for dim in arrayDims(ty)
    if !isKnown(dim) || size(dim) > 1
      if found
        Error.addSourceMessageAndFail(Error.NF_VECTOR_INVALID_DIMENSIONS, list(toString(ty), toString(call)), info)
      end
      vectorDim = dim
      found = true
    end
  end
  #= An empty array gives an empty vector, even with a dimension > 1. =#
  isEmptyArray(ty) && (vectorDim = fromInteger(0))
  local resTy::ModelicaType = TYPE_ARRAY(arrayElementType(ty), list(vectorDim))
  return (_unaryCall(fnRef, arg, var, resTy), resTy, var)
end

"""
`matrix(A)`: `promote(A, 2)` for a scalar or vector, `A` for a matrix; otherwise the first two dimensions, the others of
size 1.
"""
function typeMatrixCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, "matrix", 1:1, "matrix(Any) => Any[:, :]\\n  matrix(Any[:, :, ...]) => Any[:, :]", info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  local dims::List{Dimension} = arrayDims(ty)
  local ndims::Int = listLength(dims)
  if ndims < 2
    local (callExp::Expression, promotedTy::ModelicaType) = promote(arg, ty, 2)
    return (callExp, promotedTy, var)
  elseif ndims == 2
    return (arg, ty, var)
  end
  local dim1::Dimension
  local dim2::Dimension
  local rest::List{Dimension}
  @match _cons(dim1, _cons(dim2, rest)) = dims
  for (i::Int, dim::Dimension) in enumerate(rest)
    if isKnown(dim) && size(dim) > 1
      Error.addSourceMessageAndFail(Error.INVALID_ARRAY_DIM_IN_CONVERSION_OP,
                                    list(string(i + 2), "matrix", "1", toString(dim)), info)
    end
  end
  local resTy::ModelicaType = TYPE_ARRAY(arrayElementType(ty), list(dim1, dim2))
  return (_unaryCall(fnRef, arg, var, resTy), resTy, var)
end

"""`cat(n, A, B, ...)`: `n` an Integer parameter expression."""
function typeCatCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local args::Vector{Expression} =
    _untypedArgs(call, "cat", 2:typemax(Int), "cat(Integer, Any[:,:], ...) => Any[:]", info)[2]
  local (nArg::Expression, nTy::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  nArg = matchTypes(nTy, TYPE_INTEGER(), nArg)[1]
  if var > Variability.PARAMETER
    Error.addSourceMessageAndFail(Error.NF_CAT_FIRST_ARG_EVAL, list(toString(nArg), variabilityString(var)), info)
  end
  local n::Int
  @match INTEGER_EXPRESSION(n) = evalExp(nArg, EVALTARGET_GENERIC(info))
  local typedArgs::Vector{Expression} = Expression[]
  local tys::Vector{ModelicaType} = ModelicaType[]
  for a::Expression in args[2:end]
    local (arg::Expression, argTy::ModelicaType, argVar::VariabilityType) = typeExp(a, origin, info)
    var = variabilityMax(argVar, var)
    push!(typedArgs, arg)
    push!(tys, argTy)
  end
  local (callExp::CALL_EXPRESSION, ty::ModelicaType) = makeCatExp(n, typedArgs, tys, var, info)
  return (callExp, ty, var)
end

"""`symmetric(A)`: `A` a square matrix."""
function typeSymmetricCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, "symmetric", 1:1, "symmetric(Any[n, n]) => Any[n, n]", info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  if !isSquareMatrix(ty)
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH,
                                  list("1", toString(fnRef), "", toString(arg), toString(ty), "Any[n, n]"), info)
  end
  return (_unaryCall(fnRef, arg, var, ty), ty, var)
end

"""`transpose(A)`: the first two dimensions of `A` swapped."""
function typeTransposeCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, "transpose", 1:1, "transpose(Any[n, m, ...]) => Any[m, n, ...]", info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  if !(isvariant(ty, TYPE_ARRAY) && listLength(ty.dimensions) >= 2)
    Error.addSourceMessage(Error.ARG_TYPE_MISMATCH,
                           list("1", toString(fnRef), "", toString(arg), toString(ty), "Any[:, :, ...]"), info)
    fail()
  end
  local dim1::Dimension
  local dim2::Dimension
  local rest::List{Dimension}
  @match _cons(dim1, _cons(dim2, rest)) = ty.dimensions
  local resTy::ModelicaType = TYPE_ARRAY(ty.elementType, _cons(dim2, _cons(dim1, rest)))
  return (_unaryCall(fnRef, arg, var, resTy), resTy, var)
end

"""
`cardinality(c)`: `c` a scalar connector, only in the condition of an assert or an if (the specification says
if-statements; the MSL uses it in if-equations and asserts).
"""
function typeCardinalityCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  if !(flagSet(origin, ORIGIN_CONDITION) && (flagSet(origin, ORIGIN_IF) || flagSet(origin, ORIGIN_ASSERT)))
    Error.addSourceMessageAndFail(Error.INVALID_CARDINALITY_CONTEXT, nil, info)
  end
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, "cardinality", 1:1, toString(call.ref) + "(Connector) => Integer", info)
  _notInFunction(origin, toString(fnRef), info)
  local (arg::Expression, ty::ModelicaType) = typeExp(args[1], origin, info)
  if !isCref(arg)
    Error.addSourceMessageAndFail(Error.ARGUMENT_MUST_BE_VARIABLE, list("First", toString(fnRef), "<REMOVE ME>"), info)
  end
  local argNode::InstNode = node(toCref(arg))
  if !(isScalar(ty) && isComponent(argNode) && isConnector(component(argNode)))
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH,
                                  list("1", toString(fnRef), "", toString(arg), toString(ty), "connector"), info)
  end
  #= TODO: Check cardinality restrictions, 3.7.2.3. =#
  System.setUsesCardinality(true)
  return (_unaryCall(fnRef, arg, Variability.PARAMETER, TYPE_INTEGER()), TYPE_INTEGER(), Variability.PARAMETER)
end

"""`Connections.branch(a, b)`."""
function typeBranchCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, "Connections.branch", 2:2, toString(call.ref) + "(Connector, Connector)", info)
  _notInFunction(origin, toString(fnRef), info)
  local (arg1::Expression, ty1::ModelicaType) = typeExp(args[1], origin, info)
  checkConnectionsArgument(arg1, ty1, fnRef, 1, info)
  local (arg2::Expression, ty2::ModelicaType) = typeExp(args[2], origin, info)
  checkConnectionsArgument(arg2, ty2, fnRef, 2, info)
  local callExp::Expression = _builtinCall(fnRef, Expression[arg1, arg2], Variability.PARAMETER, TYPE_NORETCALL())
  return (callExp, TYPE_NORETCALL(), Variability.PARAMETER)
end

"""A reference to the model or parameter `arg` (a component reference), typed Any (extensions)."""
function _anyCref(@nospecialize(arg::Expression))::Expression
  local cref::ComponentRef
  @match CREF_EXPRESSION(cref = cref) = arg
  return CREF_EXPRESSION(TYPE_ANY(), cref)
end

"""
Author: johti17
Extension: `initialStructuralState(m)`, `m` the model the simulation starts in.
"""
function typeInitialStructuralStateCall(call::Call, ::ORIGIN_Type, ::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local fnRef::ComponentRef
  local args::Vector{Expression}
  @match UNTYPED_CALL(ref = fnRef, arguments = args) = call
  if length(args) != 1
    @error "More then one state passed to initialStructuralState"
    throw("Error typing!")
  end
  local callExp::Expression = _unaryCall(fnRef, _anyCref(args[1]), Variability.PARAMETER, TYPE_NORETCALL())
  return (callExp, TYPE_NORETCALL(), Variability.PARAMETER)
end

"""
Author: johti17
Extension: `agentic_recompilation(p1, ...)`: the parameters `p1, ...` get new values at runtime from an external
agent, which receives the model's metamodel and the simulation state.
"""
function typeAgenticRecompilationCall(call::Call, ::ORIGIN_Type, ::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local fnRef::ComponentRef
  local args::Vector{Expression}
  @match UNTYPED_CALL(ref = fnRef, arguments = args) = call
  isempty(args) && throw("Error typing! agentic_recompilation expects at least one argument")
  local typedArgs::Vector{Expression} = Expression[_anyCref(arg) for arg in args]
  local callExp::Expression = _builtinCall(fnRef, typedArgs, Variability.PARAMETER, TYPE_NORETCALL())
  return (callExp, TYPE_NORETCALL(), Variability.PARAMETER)
end

"""
Author: johti17
Extension: `recompilation(p, value)`: the model recompiled with the parameter `p` set to `value`. `p` is typed Any, so
the frontend does not simplify it.
"""
function typeRecompilationCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local fnRef::ComponentRef
  local args::Vector{Expression}
  @match UNTYPED_CALL(ref = fnRef, arguments = args) = call
  length(args) != 2 && throw("Error typing! expected two arguments to recompilation")
  local value::Expression = typeExp(args[2], origin, info)[1]
  local callExp::Expression =
    _builtinCall(fnRef, Expression[_anyCref(args[1]), value], Variability.PARAMETER, TYPE_NORETCALL())
  return (callExp, TYPE_NORETCALL(), Variability.PARAMETER)
end

"""
Author: johti17
Extension: `structuralTransition(from, to, condition)`: the switch from the model `from` to the model `to` when
`condition` becomes true.
"""
function typeStructuralTransition(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local fnRef::ComponentRef
  local args::Vector{Expression}
  @match UNTYPED_CALL(ref = fnRef, arguments = args) = call
  if length(args) != 3
    @error "To few arguments to initialStructuralState. Three arguments are expected."
    throw("Syntax error: To few arguments to initialStructuralState")
  end
  local condition::Expression = typeExp(args[3], origin, info)[1]
  local callExp::Expression = _builtinCall(fnRef, Expression[_anyCref(args[1]), _anyCref(args[2]), condition],
                                           Variability.PARAMETER, TYPE_NORETCALL())
  return (callExp, TYPE_NORETCALL(), Variability.PARAMETER)
end

"""
A `Connections` operator of one connector argument (`isRoot`, `root`, `rooted`) with the result type `resTy`.
"""
function _typeConnectionsUnaryCall(name::String, call::Call, origin::ORIGIN_Type, info::SourceInfo,
                                   resTy::ModelicaType)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, name, 1:1, toString(call.ref) + "(Connector)", info)
  _notInFunction(origin, toString(fnRef), info)
  local (arg::Expression, ty::ModelicaType) = typeExp(args[1], origin, info)
  checkConnectionsArgument(arg, ty, fnRef, 1, info)
  return (_unaryCall(fnRef, arg, Variability.PARAMETER, resTy), resTy, Variability.PARAMETER)
end

function typeIsRootCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  System.setUsesConnectionsOperators(true)
  return _typeConnectionsUnaryCall("Connections.isRoot", call, origin, info, TYPE_BOOLEAN())
end

typeRootCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType} =
  _typeConnectionsUnaryCall("Connections.root", call, origin, info, TYPE_NORETCALL())

function typeRootedCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  System.setUsesConnectionsOperators(true)
  local res::Tuple{Expression, ModelicaType, VariabilityType} =
    _typeConnectionsUnaryCall("Connections.rooted", call, origin, info, TYPE_BOOLEAN())
  if isSimple(call.ref)
    Error.addSourceMessage(Error.DEPRECATED_API_CALL, list("rooted", "Connections.rooted"), info)
  end
  return res
end

"""
A `Connections` operator of a connector and an optional argument named `optName` (`potentialRoot(c, priority = 0)`,
`uniqueRoot(c, message = "")`): the positional arguments followed by the named one, in a new vector (the untyped call
is not changed). `signature` is the operator's signature for the error message.
"""
function _connectionsArgsWithOptional(call::Call, optName::String, nargs::UnitRange{Int}, signature::String,
                                      origin::ORIGIN_Type, info::SourceInfo)::Tuple{ComponentRef, Vector{Expression}}
  local fnRef::ComponentRef
  local posArgs::Vector{Expression}
  local namedArgs::Vector{NamedArg}
  @match UNTYPED_CALL(ref = fnRef, arguments = posArgs, named_args = namedArgs) = call
  local args::Vector{Expression} = copy(posArgs)
  for (name::String, arg::Expression) in namedArgs
    name == optName || Error.addSourceMessageAndFail(Error.NO_SUCH_PARAMETER, list(toString(fnRef), name), info)
    push!(args, arg)
  end
  if !(length(args) in nargs)
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST,
                                  list(toString(call), toString(fnRef) + signature), info)
  end
  _notInFunction(origin, toString(fnRef), info)
  return (fnRef, args)
end

"""The optional argument `args[i]` typed and checked to be of `kind` (`isInteger`, `isString`), else `default`."""
function _optionalArg(args::Vector{Expression}, i::Int, kind::FT, kindName::String, default::Expression,
                      fnRef::ComponentRef, origin::ORIGIN_Type, info::SourceInfo)::Expression where {FT<:Function}
  length(args) < i && return default
  local (arg::Expression, ty::ModelicaType) = typeExp(args[i], origin, info)
  if !kind(ty)
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH,
                                  list(string(i), toString(fnRef), "", toString(arg), toString(ty), kindName), info)
  end
  return arg
end

"""`Connections.potentialRoot(c, priority = 0)`."""
function typePotentialRootCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _connectionsArgsWithOptional(call, "priority", 1:2, "(Connector, Integer = 0)", origin, info)
  local (arg1::Expression, ty1::ModelicaType) = typeExp(args[1], origin, info)
  checkConnectionsArgument(arg1, ty1, fnRef, 1, info)
  local arg2::Expression = _optionalArg(args, 2, isInteger, "Integer", INTEGER_EXPRESSION(0), fnRef, origin, info)
  local callExp::Expression = _builtinCall(fnRef, Expression[arg1, arg2], Variability.PARAMETER, TYPE_NORETCALL())
  return (callExp, TYPE_NORETCALL(), Variability.PARAMETER)
end

"""`Connections.uniqueRoot(c, message = "")` (non-standard); see also typeUniqueRootIndicesCall."""
function typeUniqueRootCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  Error.addSourceMessage(Error.NON_STANDARD_OPERATOR, list("Connections.uniqueRoot"), info)
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _connectionsArgsWithOptional(call, "message", 1:2, "(Connector, String = \\\\)", origin, info)
  local (arg1::Expression, ty1::ModelicaType) = typeExp(args[1], origin, info)
  checkConnectionsArgument(arg1, ty1, fnRef, 1, info)
  local arg2::Expression = _optionalArg(args, 2, isString, "String", STRING_EXPRESSION(""), fnRef, origin, info)
  local callExp::Expression = _builtinCall(fnRef, Expression[arg1, arg2], Variability.PARAMETER, TYPE_NORETCALL())
  return (callExp, TYPE_NORETCALL(), Variability.PARAMETER)
end

"""
`Connections.uniqueRootIndices(roots, nodes, message = "")`: the Integer array of the root indices. See
Modelica_StateGraph2 (https://github.com/modelica/Modelica_StateGraph2), Modelica ticket 984 and
http://www.ep.liu.se/ecp/043/041/ecp09430108.pdf for the specification.
"""
function typeUniqueRootIndicesCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  System.setUsesConnectionsOperators(true)
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _connectionsArgsWithOptional(call, "message", 2:3, "(Connector, Connector, String = \\\\)", origin, info)
  local (arg1::Expression, ty1::ModelicaType) = typeExp(args[1], origin, info)
  checkConnectionsArgument(arg1, ty1, fnRef, 1, info)
  local (arg2::Expression, ty2::ModelicaType) = typeExp(args[2], origin, info)
  checkConnectionsArgument(arg2, ty2, fnRef, 1, info)
  local arg3::Expression = _optionalArg(args, 3, isString, "String", STRING_EXPRESSION(""), fnRef, origin, info)
  Error.assertion(listLength(arrayDims(ty1)) == listLength(arrayDims(ty2)),
                  "the first two parameters need to have the same size", info)
  local ty::ModelicaType = TYPE_ARRAY(TYPE_INTEGER(), arrayDims(ty1))
  local callExp::Expression = _builtinCall(fnRef, Expression[arg1, arg2, arg3], Variability.PARAMETER, ty)
  return (callExp, ty, Variability.PARAMETER)
end

"""The element type of `ty` when `cref`'s subscripts select one element of it; otherwise `ty`."""
function _subscriptedType(cref::ComponentRef, ty::ModelicaType)::ModelicaType
  if isvariant(ty, TYPE_ARRAY) && listLength(subscriptsAllFlat(cref)) == listLength(ty.dimensions)
    return ty.elementType
  end
  return ty
end

"""
The argument `arg` (number `argIndex`) of the `Connections` operator `fnRef`: a reference `A.R` to the overdetermined
record `R` of a connector `A`. A reference to `R` alone is allowed with a warning (adrpo #5821).
"""
function checkConnectionsArgument(@nospecialize(arg::Expression), ty::ModelicaType, fnRef::ComponentRef, argIndex::Int,
                                  info::SourceInfo)::Nothing
  if !(arg isa CREF_EXPRESSION)
    Error.addSourceMessage(Error.ARG_TYPE_MISMATCH, list(string(argIndex), toString(fnRef), "", toString(arg),
                                                         toString(ty), "overconstrained type/record"), info)
    fail()
  end
  local cref::ComponentRef = arg.cref
  local (validCref::Bool, connector::Bool) = @match cref begin
    COMPONENT_REF_CREF(node = n, origin = Origin.CREF, restCref = COMPONENT_REF_CREF(ty = ty2, origin = Origin.CREF)) =>
      (isOverdetermined(getClass(n)), isConnector(_subscriptedType(cref, ty2)))
    COMPONENT_REF_CREF(node = n, ty = ty2) => (isOverdetermined(getClass(n)), isConnector(_subscriptedType(cref, ty2)))
    _ => (false, false)
  end
  (validCref && connector) && return nothing
  local msgArgs::List{String} = list(toString(cref), toString(fnRef))
  if validCref
    Error.addSourceMessage(argIndex == 1 ? Error.W_INVALID_ARGUMENT_TYPE_BRANCH_FIRST :
                                          Error.W_INVALID_ARGUMENT_TYPE_BRANCH_SECOND, msgArgs, info)
  else
    Error.addSourceMessageAndFail(argIndex == 1 ? Error.INVALID_ARGUMENT_TYPE_BRANCH_FIRST :
                                                 Error.INVALID_ARGUMENT_TYPE_BRANCH_SECOND, msgArgs, info)
  end
  return nothing
end

"""`noEvent(e)`: `e` typed in a noEvent scope."""
function typeNoEventCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) = _untypedArgs(call, "noEvent", 1:1, "noEvent(Any) => Any", info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], setFlag(origin, ORIGIN_NOEVENT), info)
  return (_unaryCall(fnRef, arg, var, ty), ty, var)
end

"""
getInstanceName(): the simulated model's name and the instance's path in it, as omc's
INCLUDING_ROOT scope (MLS 3.7.4: `Vehicle.engine.controller` for MyLib.Vehicle). The full class
path of the root (scopePath with includeRoot) was `Modelica.Blocks.Examples.Noise.Dryden
ContinuousTurbulence.whiteNoise`: every MSL noise block's automatic local seed, a hash of the name,
differed from omc's, and with it each random sequence.
"""
function typeGetInstanceName(call::Call)::Tuple{Expression, ModelicaType, VariabilityType}
  local scope::InstNode
  @match UNTYPED_CALL(call_scope = scope) = call
  local full::Vector{String} = listArray(AbsynUtil.pathToStringList(scopePath(scope, includeRoot = true)))
  local relative::Vector{String} = listArray(AbsynUtil.pathToStringList(scopePath(scope, includeRoot = false)))
  #= In a component: the root class's own name, then its path; in the root class itself (both paths full): its name. =#
  local name::Vector{String} =
    length(full) > length(relative) ? vcat(full[length(full) - length(relative)], relative) : [last(full)]
  return (STRING_EXPRESSION(Base.join(name, ".")), TYPE_STRING(), Variability.CONSTANT)
end

"""
`Clock()` (inferred), `Clock(interval)` (Real), `Clock(counter, resolution)` (Integer),
`Clock(condition, startInterval)` (Boolean) and `Clock(c, solverMethod)` (solver clock).
"""
function typeClockCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local args::Vector{Expression}
  @match TYPED_CALL(arguments = args) = typeMatchNormalCall(call, origin, info)
  local callExp::Expression
  if isempty(args)
    callExp = CLKCONST_EXPRESSION(INFERRED_CLOCK())
  elseif length(args) == 1
    callExp = CLKCONST_EXPRESSION(REAL_CLOCK(args[1]))
  else
    local e1::Expression = args[1]
    local e2::Expression = evalExp(args[2])
    callExp = @match typeOf(e2) begin
      TYPE_INTEGER(__) => begin
        Error.assertionOrAddSourceMessage(integerValue(e2) >= 1, Error.WRONG_VALUE_OF_ARG,
                                          list("Clock", "resolution", toString(e2), "=> 1"), info)
        CLKCONST_EXPRESSION(INTEGER_CLOCK(e1, e2))
      end
      TYPE_REAL(__) => CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e1, e2))
      TYPE_STRING(__) => CLKCONST_EXPRESSION(SOLVER_CLOCK(e1, e2))
    end
  end
  return (callExp, TYPE_CLOCK(), Variability.PARAMETER)
end

"""`sample(start, interval)`: a Boolean parameter call, `start` cast to Real if Integer."""
function _realSample(fn::MODELICA_FUNCTION, @nospecialize(start::Expression), startTy::ModelicaType,
                     @nospecialize(interval::Expression))::Tuple{Expression, ModelicaType, VariabilityType}
  local s::Expression = valueEq(startTy, TYPE_INTEGER()) ? CAST_EXPRESSION(TYPE_REAL(), start) : start
  local callExp::Expression =
    CALL_EXPRESSION(makeTypedCall(fn, Expression[s, interval], Variability.PARAMETER, TYPE_BOOLEAN()))
  return (callExp, TYPE_BOOLEAN(), Variability.PARAMETER)
end

"""`sample(u, c)`: the clocked sample of `u` (type `t`, variability `v`) with the clock `c`."""
function _clockedSample(fn::MODELICA_FUNCTION, @nospecialize(u::Expression), t::ModelicaType, v::VariabilityType,
                        @nospecialize(c::Expression))::Tuple{Expression, ModelicaType, VariabilityType}
  return (CALL_EXPRESSION(makeTypedCall(fn, Expression[u, c], v, t)), t, v)
end

"""
`sample(start, interval)` (the Boolean sample; `interval` positional or named), `sample(u)` (inferred clock) and
`sample(u, c)` (clock `c`, positional or named; the clocked ones need the synchronous features).
"""
function typeSampleCall(call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local fnRef::ComponentRef
  local args::Vector{TypedArg}
  local namedArgs::Vector{TypedNamedArg}
  @match ARG_TYPED_CALL(fnRef, args, namedArgs) = typeNormalCall(call, origin, info)
  fnRef = instFunctionRef(fnRef, InstNode_info(node(fnRef)))[1]
  local normalSample::MODELICA_FUNCTION
  local clockedSample::MODELICA_FUNCTION
  @match [normalSample, clockedSample, _...] = typeRefCache(fnRef)
  local sync::Bool = Config.synchronousFeaturesAllowed()
  return @match (args, namedArgs) begin
    ([(e, t, _), (e1, TYPE_INTEGER(__), _)], _) where (isempty(namedArgs)) => _realSample(normalSample, e, t, CAST_EXPRESSION(TYPE_REAL(), e1))
    ([(e, t, _), (e1, TYPE_REAL(__), _)], _) where (isempty(namedArgs)) => _realSample(normalSample, e, t, e1)
    ([(e, t, _)], [("interval", e1, TYPE_REAL(__), _)]) => _realSample(normalSample, e, t, e1)
    ([(e, t, v)], _) where (sync && isempty(namedArgs)) => _clockedSample(clockedSample, e, t, v, CLKCONST_EXPRESSION(INFERRED_CLOCK()))
    ([(e, t, v), (e1, TYPE_CLOCK(__), _)], _) where (sync && isempty(namedArgs)) => _clockedSample(clockedSample, e, t, v, e1)
    ([(e, t, v)], [("c", e1, TYPE_CLOCK(__), _)]) where (sync) => _clockedSample(clockedSample, e, t, v, e1)
    _ => begin
      Error.addSourceMessage(Error.WRONG_TYPE_OR_NO_OF_ARGS, list(toString(call), "<NO COMPONENT>"), info)
      fail()
    end
  end
end

"""`actualStream(v)` and `inStream(v)` (`name`): `v` a stream variable. The call is continuous."""
function typeActualInStreamCall(name::String, call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, name, 1:1, toString(call.ref) + "(stream variable) => Real", info)
  local (arg::Expression, ty::ModelicaType, var::VariabilityType) = typeExp(args[1], origin, info)
  local expanded::Expression = expand(arg)[1]
  local callExp::Expression = typeActualInStreamCall2(name, _builtinFunction(fnRef), expanded, var, info)
  return (callExp, ty, Variability.CONTINUOUS)
end

"""
The call of `fn` (`actualStream`/`inStream`, `name`) on the stream variable `arg`, or on each element of an array of
them. The subscripts of `arg` must be parameter expressions.
"""
function typeActualInStreamCall2(name::String, fn::MODELICA_FUNCTION, @nospecialize(arg::Expression),
                                 var::VariabilityType, info::SourceInfo)::Expression
  if arg isa CREF_EXPRESSION
    local argNode::InstNode = node(arg.cref)
    if !isComponent(argNode) || !isStream(connectorType(component(argNode)))
      Error.addSourceMessageAndFail(Error.NON_STREAM_OPERAND_IN_STREAM_OPERATOR, list(toString(arg.cref), name), info)
    end
    for sub in subscriptsAllFlat(arg.cref)
      if variability(sub) > Variability.PARAMETER
        Error.addSourceMessageAndFail(Error.CONNECTOR_NON_PARAMETER_SUBSCRIPT,
                                      list(toString(arg.cref), toString(sub)), info)
      end
    end
    return CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], var, arg.ty))
  elseif arg isa ARRAY_EXPRESSION
    #= The operator on each element: without it, `a.Xi_outflow = inStream(b.Xi_outflow)` became
       `a.Xi_outflow = b.Xi_outflow`. =#
    return ARRAY_EXPRESSION(arg.ty, Expression[typeActualInStreamCall2(name, fn, e, var, info) for e in arg.elements],
                            false)
  end
  Error.addSourceMessage(Error.NON_STREAM_OPERAND_IN_STREAM_OPERATOR, list(toString(arg), name), info)
  fail()
end

"""
`DynamicSelect(static, dynamic)` (`name`): the static expression, or the call when the API flag
NF_API_DYNAMIC_SELECT is set. A dynamic expression that does not type is ignored (OpenModelica ticket 5631).
"""
function typeDynamicSelectCall(name::String, call::Call, origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, ModelicaType, VariabilityType}
  local (fnRef::ComponentRef, args::Vector{Expression}) =
    _untypedArgs(call, name, 2:2, toString(call.ref) + "(static expression, dynamic expression)", info)
  local (arg1::Expression, ty1::ModelicaType, var1::VariabilityType) = typeExp(unbox(args[1]), origin, info)
  arg1 = expand(arg1)[1]
  local arg2::Expression
  local var2::VariabilityType
  try
    (arg2, _, var2) = typeExp(unbox(args[2]), origin, info)
  catch
    return (arg1, ty1, var1)
  end
  if Flags.isSet(Flags.NF_API_DYNAMIC_SELECT)
    arg2 = expand(arg2)[1]
    return (_builtinCall(fnRef, Expression[arg1, arg2], var2, ty1), ty1, var2)
  end
  return (arg1, ty1, var1)
end

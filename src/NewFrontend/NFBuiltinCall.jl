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

function needSpecialHandling(@nospecialize(call::Call)) ::Bool
  local special::Bool
  ##@debug "Calling needSpecialHandling with: " * toString(call)
  () = begin
    @match call begin
      UNTYPED_CALL(__)  => begin
        @match C_FUNCTION(specialBuiltin = special) = getFuncCache(classScope(node(call.ref)))
        ()
      end
      _  => begin
        Error.assertion(false, getInstanceName() + " got unknown call: " + toString(call), sourceInfo())
        fail()
      end
    end
  end
  #@debug "Is it special: " special
  special
end

@nospecializeinfer function typeSpecial(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local cref::ComponentRef
  local fn_node::InstNode
  local first::Expression
  local rest::List{Expression}
  local name::String
  local next_origin::ORIGIN_Type

  @match UNTYPED_CALL(ref = cref) = call
  @assign next_origin = setFlag(origin, ORIGIN_SUBEXPRESSION)
   (callExp, ty, variability) = begin
    @match firstName(cref) begin
      "String"  => begin
        typeStringCall(call, next_origin, info)
      end

      "actualStream"  => begin
        typeActualInStreamCall("actualStream", call, next_origin, info)
      end

      "branch"  => begin
        typeBranchCall(call, next_origin, info)
      end

      "cardinality"  => begin
        typeCardinalityCall(call, next_origin, info)
      end

      "cat"  => begin
        typeCatCall(call, next_origin, info)
      end

      "change"  => begin
        typeChangeCall(call, next_origin, info)
      end

      "der"  => begin
        typeDerCall(call, next_origin, info)
      end

      "diagonal"  => begin
        typeDiagonalCall(call, next_origin, info)
      end

      "edge"  => begin
        typeEdgeCall(call, next_origin, info)
      end

      "fill"  => begin
        typeFillCall(call, next_origin, info)
      end

      "getInstanceName"  => begin
        typeGetInstanceName(call)
      end

      "initial"  => begin
        typeDiscreteCall(call, next_origin, info)
      end

      "inStream"  => begin
        typeActualInStreamCall("inStream", call, next_origin, info)
      end

      "isRoot"  => begin
        typeIsRootCall(call, next_origin, info)
      end

      "matrix"  => begin
        typeMatrixCall(call, next_origin, info)
      end

      "max"  => begin
        typeMinMaxCall("max", call, next_origin, info)
      end

      "min"  => begin
        typeMinMaxCall("min", call, next_origin, info)
      end

      "ndims"  => begin
        typeNdimsCall(call, next_origin, info)
      end

      "noEvent"  => begin
        typeNoEventCall(call, next_origin, info)
      end

      "ones"  => begin
        typeZerosOnesCall("ones", call, next_origin, info)
      end

      "potentialRoot"  => begin
        typePotentialRootCall(call, next_origin, info)
      end

      "pre"  => begin
        typePreCall(call, next_origin, info)
      end

      "product"  => begin
        typeProductCall(call, next_origin, info)
      end

      "root"  => begin
        typeRootCall(call, next_origin, info)
      end

      "rooted"  => begin
        typeRootedCall(call, next_origin, info)
      end

      "uniqueRoot"  => begin
        typeUniqueRootCall(call, next_origin, info)
      end

      "uniqueRootIndices"  => begin
        typeUniqueRootIndicesCall(call, next_origin, info)
      end

      "scalar"  => begin
        typeScalarCall(call, next_origin, info)
      end

      "smooth"  => begin
        typeSmoothCall(call, next_origin, info)
      end

      "sum"  => begin
        typeSumCall(call, next_origin, info)
      end

      "symmetric"  => begin
        typeSymmetricCall(call, next_origin, info)
      end

      "terminal"  => begin
        typeDiscreteCall(call, next_origin, info)
      end

      "transpose"  => begin
        typeTransposeCall(call, next_origin, info)
      end

      "vector"  => begin
        typeVectorCall(call, next_origin, info)
      end

      "zeros"  => begin
        typeZerosOnesCall("zeros", call, next_origin, info)
      end

      "Clock" where (Config.synchronousFeaturesAllowed())  => begin
        typeClockCall(call, next_origin, info)
      end

      "sample"  => begin
        typeSampleCall(call, next_origin, info)
      end

      "DynamicSelect"  => begin
        typeDynamicSelectCall("DynamicSelect", call, next_origin, info)
      end
      "initialStructuralState" => begin
        typeInitialStructuralStateCall(call, next_origin, info)
      end

      "structuralTransition" => begin
        typeStructuralTransition(call, next_origin, info)
      end

      "recompilation" => begin
        typeRecompilationCall(call, next_origin, info)
      end

      "agentic_recompilation" => begin
        typeAgenticRecompilationCall(call, next_origin, info)
      end

      _  => begin
        #= /*
        case \"hold\" guard Config.synchronousFeaturesAllowed() then typeHoldCall(call, next_origin, info);
        case \"shiftSample\" guard Config.synchronousFeaturesAllowed() then typeShiftSampleCall(call, next_origin, info);
        case \"backSample\" guard Config.synchronousFeaturesAllowed() then typeBackSampleCall(call, next_origin, info);
        case \"noClock\" guard Config.synchronousFeaturesAllowed() then typeNoClockCall(call, next_origin, info);
        case \"transition\" guard Config.synchronousFeaturesAllowed() then typeTransitionCall(call, next_origin, info);
        case \"initialState\" guard Config.synchronousFeaturesAllowed() then typeInitialStateCall(call, next_origin, info);
        case \"activeState\" guard Config.synchronousFeaturesAllowed() then typeActiveStateCall(call, next_origin, info);
        case \"ticksInState\" guard Config.synchronousFeaturesAllowed() then typeTicksInStateCall(call, next_origin, info);
        case \"timeInState\" guard Config.synchronousFeaturesAllowed() then typeTimeInStateCall(call, next_origin, info);
        */ =#
        Error.assertion(false, getInstanceName() + " got unhandled builtin function: " + toString(call), sourceInfo())
        #@error getInstanceName() * " got unhandled builtin function: " * toString(call)
      end
    end
  end
(callExp, ty, variability)
end

function makeSizeExp(posArgs::Vector{Expression}, namedArgs::Vector{NamedArg}, info::SourceInfo) ::Expression
  local callExp::Expression
  local argc::Int = length(posArgs)
  local arg1::Expression
  local arg2::Expression
  assertNoNamedParams("size", namedArgs, info)
  callExp = begin
    @match posArgs begin
      [arg1]  => begin
        SIZE_EXPRESSION(arg1, NONE())
      end

      [arg1, arg2]  => begin
        SIZE_EXPRESSION(arg1, SOME(arg2))
      end
      _  => begin
        Error.addSourceMessage(Error.NO_MATCHING_FUNCTION_FOUND_NFINST,
                               list("size" + ListUtil.toString(posArgs, toString, "", "(", ", ", ")", true), "size(Any[:, ...]) => Integer[:]\\n  size(Any[:, ...], Integer) => Integer"), info)
        fail()
      end
    end
  end
  callExp
end

function makeArrayExp(posArgs::Union{List{<:Expression}, Vector{<:Expression}}, namedArgs::Union{List{<:NamedArg}, Vector{<:NamedArg}}, info::SourceInfo) ::Expression
  local arrayExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local ty::M_Type

  assertNoNamedParams("array", namedArgs, info)
  #=  array can take any number of arguments, but needs at least one.
  =#
  if isempty(posArgs)
    Error.addSourceMessage(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list("array()", "array(Any, Any, ...) => Any[:]"), info)
    fail()
  end
  local posArgsList = posArgs isa Vector ? list(posArgs...) : posArgs
  @assign arrayExp = makeArray(TYPE_UNKNOWN(), posArgsList)
  arrayExp
end

function makeCatExp(n::Int,
                    args::Vector{Expression},
                    tys::Vector{M_Type},
                    variability::VariabilityType, info::SourceInfo)::Tuple{CALL_EXPRESSION, M_Type}
  local ty::M_Type
  local callExp::Expression

  local arg2::Expression
  local args2::Vector{Expression} = Expression[]
  local res::Vector{Expression}
  local tys2::Vector{M_Type} = tys
  local tys3::Vector{M_Type}
  local dimsLst::List{List{Dimension}} = nil
  local dims::List{Dimension}
  local resTy::M_Type = TYPE_UNKNOWN()
  local ty1::M_Type
  local ty2::M_Type
  local resTyToMatch::M_Type
  local mk::MatchKindType
  local maxn::Int
  local pos::Int
  local sumDim::Dimension

  local INT_EXPR_ZERO = INTEGER_EXPRESSION(0)
  local tyRef = Ref{NFType}(TYPE_UNKNOWN())
  local mkRef = Ref{MatchKindType}(MatchKind.NOT_COMPATIBLE)
  @assert length(args) == length(tys) && length(args) >= 1
  #Error.assertion(, getInstanceName() + " got wrong input sizes", sourceInfo())
  #=  First: Get the number of dimensions and the element type
  =#
  for (i,arg) in enumerate(args)
    ty = tys2[i]
    dimsLst = Cons{List{Dimension}}(arrayDims(ty), dimsLst)
    if resTy isa TYPE_UNKNOWN
      resTy = arrayElementType(ty)
    else
       (_, _, ty1, mk) = matchExpressions(INT_EXPR_ZERO, arrayElementType(ty), INT_EXPR_ZERO, resTy)
      if isCompatibleMatch(mk)
        resTy = ty1
      end
    end
  end
  local mLst::List{Int} = nil
  maxn = 0
  for d in dimsLst
    maxn = max(maxn, listLength(d))
  end
  local minN = 99999999999999 #Some huge number. Note Could cause a bug (In theory..).
  mLst = nil
  for d in dimsLst
    minN = min(minN, listLength(d))
  end
  if maxn != minN
    Error.addSourceMessageAndFail(Error.NF_DIFFERENT_NUM_DIM_IN_ARGUMENTS, list(stringDelimitList(list(String(listLength(d)) for d in dimsLst), ", "), "cat"), info)
  end
  if n < 1 || n > maxn
    Error.addSourceMessageAndFail(Error.NF_CAT_WRONG_DIMENSION, list(String(maxn), String(n)), info)
  end
  tys2 = tys
  tys3 = M_Type[]
  args2 = Expression[]
  pos = length(args) + 2
  #=  Second: Try to match the element type of all the arguments
  =#
  local i = 1
  for arg in args
    ty = tys2[i]
    pos = pos - 1
    ty2 = setArrayElementType(ty, resTy)
    arg2 = matchTypesRef(ty, ty2, arg,tyRef, mkRef, #=allowUnknown =# true)
    mk = mkRef.x
    ty1 = tyRef.x
    if isIncompatibleMatch(mk)
      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list(String(pos), "cat", "arg", toString(arg), toString(ty), toString(ty2)), info)
    end
    #args2 = _cons(arg2, args2)
    #tys3 = _cons(ty1, tys3)
    push!(args2, arg2)
    push!(tys3, ty1)
    i += 1
  end
  #=  Third: We now have matched the element types of all arguments
  =#
  #=         Try to match the dimensions as well
  =#
  resTy = TYPE_UNKNOWN()
  tys2 = tys3
  for (i,arg) in enumerate(args2)
    ty = tys2[i]
    if resTy isa TYPE_UNKNOWN
      resTy = ty
    else
      (_, _, ty1, mk) = matchExpressions(INT_EXPR_ZERO, ty, INT_EXPR_ZERO, resTy)
      if isCompatibleMatch(mk)
        resTy = ty1
      end
    end
  end
  #=  Got the supertype of the dimensions; trying to match all arguments
  =#
  #=  with the concatenated dimension set to unknown.
  =#
  dims = arrayDims(resTy)
  resTyToMatch = TYPE_ARRAY(arrayElementType(resTy), ListUtil.set(dims, n, DIMENSION_UNKNOWN()))
  #dims = list(listGet(lst, n) for lst in dimsLst)
  dims = List{Dimension}(listGet(lst, n) for lst in dimsLst)
  sumDim = fromInteger(0)
  for d in dims
    sumDim = add(sumDim, d)
  end
  #=  Create the concatenated dimension
  =#
  resTy = TYPE_ARRAY(arrayElementType(resTy), ListUtil.set(arrayDims(resTy), n, sumDim))
  tys2 = tys3
  tys3 = M_Type[]
  res = Expression[]
  pos = length(args) + 2
  i = 1
  for arg in args2
    ty  = tys2[i]
    pos = pos - 1
    arg2 = matchTypesRef(ty, resTyToMatch, arg, tyRef, mkRef, #=allowUnknown=# true)
    ty1 = tyRef.x
    mk = mkRef.x
    if isIncompatibleMatch(mk)
      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list(String(pos), "cat", "arg", toString(arg), toString(ty), toString(resTyToMatch)), info)
    end
    push!(res, arg2)
    push!(tys3, ty1)
    i += 1
  end
  #=  We have all except dimension n having equal sizes; with matching types
  =#
  ty = resTy
  res = pushfirst!(res, INTEGER_EXPRESSION(n))
  callExp = CALL_EXPRESSION(makeTypedCall(NFBuiltinFuncs.CAT, res, variability, resTy))
  (callExp, ty)
end


"""
```
makeCatExpRef(n::Int,
                       args::Vector{Expression},
                       tys::Vector{M_Type},
                       variability::VariabilityType,
                       info::SourceInfo,
                       tyRef::Ref{NFType},)::CALL_EXPRESSION
```
Same as makeCatExp. Updates the tyValue in place instead of using Julia MRV.
"""
function makeCatExpRef(n::Int,
                       args::Vector{Expression},
                       tys::Vector{NFType},
                       variability::VariabilityType,
                       info::SourceInfo,
                       tyRef::Ref{NFType})::CALL_EXPRESSION
  local ty::M_Type
  local callExp::Expression
  local arg2::Expression
  local args2::Vector{Expression} = Expression[]
  local res::Vector{Expression}
  local tys2::Vector{M_Type} = tys
  local tys3::Vector{M_Type}
  local dimsLst::List{List{Dimension}} = nil
  local dims::List{Dimension}
  local resTy::M_Type = TYPE_UNKNOWN()
  local ty1::M_Type
  local ty2::M_Type
  local resTyToMatch::M_Type
  local mk::MatchKindType
  local maxn::Int
  local pos::Int
  local sumDim::Dimension

  local INT_EXPR_ZERO = INTEGER_EXPRESSION(0)
  #local tyRef = Ref{NFType}(TYPE_UNKNOWN())
  local mkRef = Ref{MatchKindType}(MatchKind.NOT_COMPATIBLE)
  @assert length(args) == length(tys) && length(args) >= 1
  #=
  First: Get the number of dimensions and the element type
  =#
  for (i,arg) in enumerate(args)
    ty = tys2[i]
    dimsLst = Cons{List{Dimension}}(arrayDims(ty), dimsLst)
    if resTy isa TYPE_UNKNOWN
      resTy = arrayElementType(ty)
    else
       (_, _, ty1, mk) = matchExpressions(INT_EXPR_ZERO, arrayElementType(ty), INT_EXPR_ZERO, resTy)
      if isCompatibleMatch(mk)
        resTy = ty1
      end
    end
  end
  local mLst::List{Int} = nil
  maxn = 0
  for d in dimsLst
    maxn = max(maxn, listLength(d))
  end
  local minN = 99999999999999 #Some huge number. Note Could cause a bug (In theory..).
  mLst = nil
  for d in dimsLst
    minN = min(minN, listLength(d))
  end
  if maxn != minN
    Error.addSourceMessageAndFail(Error.NF_DIFFERENT_NUM_DIM_IN_ARGUMENTS, list(stringDelimitList(list(String(listLength(d)) for d in dimsLst), ", "), "cat"), info)
  end
  if n < 1 || n > maxn
    Error.addSourceMessageAndFail(Error.NF_CAT_WRONG_DIMENSION, list(String(maxn), String(n)), info)
  end
  tys2 = tys
  tys3 = M_Type[]
  args2 = Expression[]
  pos = length(args) + 2
  #=  Second: Try to match the element type of all the arguments =#
  local i = 1
  for arg in args
    ty = tys2[i]
    pos = pos - 1
    ty2 = setArrayElementType(ty, resTy)
    arg2 = matchTypesRef(ty, ty2, arg,tyRef, mkRef, #=allowUnknown =# true)
    mk = mkRef.x
    ty1 = tyRef.x
    if isIncompatibleMatch(mk)
      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list(String(pos), "cat", "arg", toString(arg), toString(ty), toString(ty2)), info)
    end
    push!(args2, arg2)
    push!(tys3, ty1)
    i += 1
  end
  #=  Third: We now have matched the element types of all arguments
           Try to match the dimensions as well
  =#
  resTy = TYPE_UNKNOWN()
  tys2 = tys3
  for (i,arg) in enumerate(args2)
    ty = tys2[i]
    if resTy isa TYPE_UNKNOWN
      resTy = ty
    else
      (_, _, ty1, mk) = matchExpressions(INT_EXPR_ZERO, ty, INT_EXPR_ZERO, resTy)
      if isCompatibleMatch(mk)
        resTy = ty1
      end
    end
  end
  #=  Got the supertype of the dimensions; trying to match all arguments
  =#
  #=  with the concatenated dimension set to unknown.
  =#
  dims = arrayDims(resTy)
  resTyToMatch = TYPE_ARRAY(arrayElementType(resTy), ListUtil.set(dims, n, DIMENSION_UNKNOWN()))
  #dims = list(listGet(lst, n) for lst in dimsLst)
  dims = List{Dimension}(listGet(lst, n) for lst in dimsLst)
  sumDim = fromInteger(0)
  for d in dims
    sumDim = add(sumDim, d)
  end
  #=  Create the concatenated dimension
  =#
  resTy = TYPE_ARRAY(arrayElementType(resTy), ListUtil.set(arrayDims(resTy), n, sumDim))
  tys2 = tys3
  tys3 = M_Type[]
  res = Expression[]
  pos = length(args) + 2
  i = 1
  for arg in args2
    ty  = tys2[i]
    pos = pos - 1
    arg2 = matchTypesRef(ty, resTyToMatch, arg, tyRef, mkRef, #=allowUnknown=# true)
    ty1 = tyRef.x
    mk = mkRef.x
    if isIncompatibleMatch(mk)
      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list(String(pos), "cat", "arg", toString(arg), toString(ty), toString(resTyToMatch)), info)
    end
    push!(res, arg2)
    push!(tys3, ty1)
    i += 1
  end
  #=  We have all except dimension n having equal sizes; with matching types
  =#
  ty = resTy
  res = pushfirst!(res, INTEGER_EXPRESSION(n))
  callExp = CALL_EXPRESSION(makeTypedCall(NFBuiltinFuncs.CAT, res, variability, resTy))
  tyRef.x = ty
  callExp
end


function assertNoNamedParams(fnName::String, namedArgs::Union{Vector{<:NamedArg}, List{<:NamedArg}}, info::SourceInfo)
  if !isempty(namedArgs)
    Error.addSourceMessage(Error.NO_SUCH_PARAMETER, list(fnName, Util.tuple21(namedArgs[1])), info)
    fail()
  end
end

function typeStringCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType
  local outType::M_Type
  local callExp::Expression

  local arg_ty::M_Type
  local args::Vector{TypedArg}
  local named_args::Vector{TypedNamedArg}
  local ty_call::Call
  ty_call = @match ARG_TYPED_CALL(_, args, named_args) = typeNormalCall(call, origin, info)
  @match [(_, arg_ty, _), rest...] = args
  arg_ty = arrayElementType(arg_ty)
  if isComplex(arg_ty)
     (callExp, outType, var) = typeOverloadedStringCall(arg_ty, args, named_args, ty_call, origin, info)
  else
     (callExp, outType, var) = typeBuiltinStringCall(ty_call, origin, info)
  end
  (callExp, outType, var)
end

function typeBuiltinStringCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local ty_call::Call

  @assign ty_call = matchTypedNormalCall(call, origin, info)
  @assign ty = typeOf(ty_call)
  @assign var = variability(ty_call)
  @assign callExp = CALL_EXPRESSION(ty_call)
  (callExp, ty, var)
end

function typeOverloadedStringCall(@nospecialize(overloadedType::M_Type), args::List{<:TypedArg}, namedArgs::List{<:TypedNamedArg}, @nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.CONSTANT
  local outType::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local candidates::List{M_Function}
  local recopnode::InstNode
  local matchedFunc::MatchedFunction
  local matchedFunctions::List{MatchedFunction}
  local exactMatches::List{MatchedFunction}

  @match TYPE_COMPLEX(cls = recopnode) = overloadedType
  try
    @assign fn_ref = lookupFunctionSimple("'String'", recopnode)
  catch e
    @error "Error $e"
    typeBuiltinStringCall(call, origin, info)
    fail()
  end
  #=  If there's no 'String' overload, let the normal String handler print the error.
  =#
  @assign fn_ref = instFunctionRef(fn_ref, InstNode_info(recopnode))
  @assign candidates = typeRefCache(fn_ref)
  #= for fn in candidates loop
  =#
  #=   TypeCheck.checkValidOperatorOverload(\"'String'\", fn, recopnode);
  =#
  #= end for;
  =#
  @assign matchedFunctions = matchFunctionsSilent(candidates, args, namedArgs, info)
  @assign exactMatches = getExactMatches(matchedFunctions)
  if listEmpty(exactMatches)
    Error.addSourceMessage(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(typedString(call), candidateFuncListString(candidates)), info)
    fail()
  end
  if listLength(exactMatches) == 1
    @match _cons(matchedFunc, _) = exactMatches
    @assign outType = returnType(matchedFunc.func)
    for arg in matchedFunc.args
      @assign var = variabilityMax(var, Util.tuple33(arg))
    end
    @assign callExp = CALL_EXPRESSION(makeTypedCall(matchedFunc.func, Expression[Util.tuple31(a) for a in matchedFunc.args], var, outType))
    return (callExp, outType, var)
  else
    Error.addSourceMessage(Error.AMBIGUOUS_MATCHING_FUNCTIONS_NFINST, list(typedString(call), candidateFuncListString(list(mfn.func for mfn in matchedFunctions))), info)
    fail()
  end
  (callExp, outType, var)
end

"""
  Types a function call that can be typed normally, but which always has
  discrete variability regardless of the variability of the arguments.
"""
function typeDiscreteCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.DISCRETE
  local ty::M_Type
  local callExp::Expression
  local argtycall::Call
  local fn::M_Function
  local args::List{TypedArg}
  local start::TypedArg
  local interval::TypedArg
  @assign argtycall = typeMatchNormalCall(call, origin, info)
  @assign ty = typeOf(argtycall)
  @assign callExp = CALL_EXPRESSION(unboxArgs(argtycall))
  (callExp, ty, var)
end

function typeNdimsCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType = Variability.PARAMETER
  local ty::M_Type = TYPE_INTEGER()
  local callExp::Expression

  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg_ty::M_Type

  @match UNTYPED_CALL(arguments = args, named_args = named_args) = call
  assertNoNamedParams("ndims", named_args, info)
  if length(args) != 1
    Error.addSourceMessage(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "ndims(Any) => Integer"), info)
    fail()
  end
  #=  The number of dimensions an expression has is always known,
  =#
  #=  so we might as well evaluate the ndims call here.
  =#
   (_, arg_ty, _) = typeExp(args[1], origin, info)
  @assign callExp = INTEGER_EXPRESSION(dimensionCount(arg_ty))
  (callExp, ty, variability)
end

function typePreCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, NFType, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression
   (callExp, ty, variability) = typePreChangeCall("pre", call, origin, info)
  (callExp, ty, variability)
end

function typeChangeCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, NFType, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

   (callExp, ty, variability) = typePreChangeCall("change", call, origin, info)
  @assign ty = setArrayElementType(ty, TYPE_BOOLEAN())
  (callExp, ty, variability)
end

function typePreChangeCall(@nospecialize(name::String), @nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, NFType, VariabilityType}
  local variability::VariabilityType = Variability.DISCRETE
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local var::VariabilityType
  local fn::M_Function

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams(name, named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), toString(fn_ref) + "(Any) => Any"), info)
  end
  #=  pre/change may not be used in a function context.
  =#
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessageAndFail(Error.EXP_INVALID_IN_FUNCTION, list(toString(fn_ref)), info)
  end
   (arg, ty, var) = typeExp(Base.first(args), origin, info)
  if ! isCref(arg)
    Error.addSourceMessage(Error.ARGUMENT_MUST_BE_VARIABLE, list("First", toString(fn_ref), "<REMOVE ME>"), info)
    fail()
  end
  if var == Variability.CONTINUOUS
    Error.addSourceMessageAndFail(Error.INVALID_ARGUMENT_VARIABILITY, list("1", toString(fn_ref), variabilityString(Variability.DISCRETE), toString(arg), variabilityString(var)), info)
  end
    #@match list(fn) = typeRefCache(fn_ref)
  fn = Base.first(typeRefCache(fn_ref))
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], var, ty))
  (callExp, ty, variability)
end

function typeDerCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, NFType, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function
  local ety::M_Type

  #=  der may not be used in a function context.
  =#
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessage(Error.EXP_INVALID_IN_FUNCTION, list("der"), info)
    fail()
  end
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("der", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "der(Real) => Real"), info)
  end
  arg = Base.first(args)
  (arg, ty, variability) = typeExp(arg, origin, info)
  ety = arrayElementType(ty)
  if isInteger(ety)
    ty = setArrayElementType(ty, TYPE_REAL())
    arg = typeCast(arg, TYPE_REAL())
  elseif ! isReal(ety)
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("1", toString(fn_ref), "", toString(arg), toString(ty), "Real"), info)
  end
  fn = Base.first(typeRefCache(fn_ref))
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], variability, ty))
  (callExp, ty, variability)
end

function typeDiagonalCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local dim::Dimension
  local fn::M_Function
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("diagonal", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "diagonal(Any[n]) => Any[n, n]"), info)
  end
  (arg, ty, variability) = typeExp(Base.first(args), origin, info)
  ty = begin
    @match ty begin
      TYPE_ARRAY(dimensions = dim <|  nil())  => begin
        TYPE_ARRAY(ty.elementType, list(dim, dim))
      end
      _  => begin
        Error.addSourceMessage(Error.ARG_TYPE_MISMATCH, list("1", toString(fn_ref), "", toString(arg), toString(ty), "Any[:]"), info)
        fail()
      end
    end
  end
  @match [fn] = typeRefCache(fn_ref)
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], variability, ty))
  (callExp, ty, variability)
end

function typeEdgeCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, NFType, VariabilityType}
  local variability::VariabilityType = Variability.DISCRETE
  local ty::M_Type
  local callExp::Expression
  local argtycall::Call
  local fn::M_Function
  local args::Vector{TypedArg}
  local arg::TypedArg
  local fn_node::InstNode
  local ca::CallAttributes
  #=  edge may not be used in a function context. =#
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessage(Error.EXP_INVALID_IN_FUNCTION, list("edge"), info)
    fail()
  end
   argtycall = typeNormalCall(call, origin, info)
  #  @match (@match ARG_TYPED_CALL(CREF_EXPRESSION(node = fn_node), args, _) = argtycall) = typeNormalCall(call, origin, info)
  args = argtycall.arguments
  argtycall = matchTypedNormalCall(argtycall, origin, info)
  ty = typeOf(argtycall)
  callExp = CALL_EXPRESSION(unboxArgs(argtycall))
    #@match list(arg) = args
  arg = Base.first(args)
  if ! isCref(Util.tuple31(arg))
    Error.addSourceMessage(Error.ARGUMENT_MUST_BE_VARIABLE, list("First", "edge", "<REMOVE ME>"), info)
    fail()
  end
  (callExp, ty, variability)
end

function typeMinMaxCall(name::String, @nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function
  local arg1::Expression
  local arg2::Expression
  local ty1::M_Type
  local ty2::M_Type
  local var1::VariabilityType
  local var2::VariabilityType
  local mk::Int #TypeCheck.MatchKind
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams(name, named_args, info)
   (args, ty, var) = begin
    @match args begin
      [arg1]  => begin
        (arg1, ty1, var) = typeExp(arg1, origin, info)
        ty = arrayElementType(ty1)
        if ! (isArray(ty1) && isBasic(ty))
          Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("1", name, "", toString(arg1), toString(ty1), "Any[:, ...]"), info)
        end
        #=  If the argument is an array with a single element we can just
        =#
        #=  return that element instead of making a min/max call.
        =#
        if isSingleElementArray(ty1)
          callExp = applySubscript(first(listHead(arrayDims(ty1))), arg1)
          return (callExp, ty, var)
        end
        (Expression[arg1], ty, var)
      end

      [arg1, arg2]  => begin
        (arg1, ty1, var1) = typeExp(arg1, origin, info)
        (arg2, ty2, var2) = typeExp(arg2, origin, info)
        if ! isBasic(ty1)
          Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("1", name, "", toString(arg1), toString(ty1), "Any"), info)
        end
        if ! isBasic(ty2)
          Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("2", name, "", toString(arg2), toString(ty2), "Any"), info)
        end
        (arg1, arg2, ty, mk) = matchExpressions(arg1, ty1, arg2, ty2)
        if ! isValidArgumentMatch(mk)
          Error.addSourceMessage(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call),
                                                                               name
                                                                               + "(Any[:, ...]) => Any\n"
                                                                               + name
                                                                               + "(Any, Any) => Any"), info)
        end
        (Expression[arg1, arg2], ty, variabilityMax(var1, var2))
      end

      _  => begin
        Error.addSourceMessage(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), name + "(Any[:, ...]) => Any\\n" + name + "(Any, Any) => Any"), info)
        fail()
      end
    end
  end
  fn = Base.first(typeRefCache(fn_ref))
  callExp = CALL_EXPRESSION(makeTypedCall(fn, args, var, ty))
  (callExp, ty, var)
end

function typeSumCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function
  local expanded::Bool
  local op::Operator

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("sum", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "sum(Any[:, ...]) => Any"), info)
  end
  (arg, ty, variability) = typeExp(Base.first(args), origin, info)
  ty = arrayElementType(ty)
  fn = Base.first(typeRefCache(fn_ref))
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], variability, ty))
  (callExp, ty, variability)
end

function typeProductCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function
  local expanded::Bool
  local op::Operator

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("product", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "product(Any[:, ...]) => Any"), info)
  end
   (arg, ty, variability) = typeExp(args[1], origin, info)
  @assign ty = arrayElementType(ty)
  res = typeRefCache(fn_ref)
  fn = Base.first(res)
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], variability, ty))
  (callExp, ty, variability)
end

function typeSmoothCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg1::Expression
  local arg2::Expression
  local ty1::M_Type
  local ty2::M_Type
  local var::VariabilityType
  local fn::M_Function
  local mk::MatchKindType

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("smooth", named_args, info)
  if length(args) != 2
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "smooth(Integer, Any) => Any"), info)
  end
  @match [arg1, arg2] = args
   (arg1, ty1, var) = typeExp(arg1, origin, info)
   (arg2, ty2, variability) = typeExp(arg2, origin, info)
  #=  First argument must be Integer.
  =#
  if ! isInteger(ty1)
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("1", toString(fn_ref), "", toString(arg1), toString(ty1), "Integer"), info)
  end
  #=  First argument must be a parameter expression.
  =#
  if var > Variability.PARAMETER
    Error.addSourceMessageAndFail(Error.INVALID_ARGUMENT_VARIABILITY, list("1", toString(fn_ref), variabilityString(Variability.PARAMETER), toString(arg1), variabilityString(variability)), info)
  end
  #=  Second argument must be Real, array of allowed expressions or record
  =#
  #=  containing only components of allowed expressions.
  =#
  #=  TODO: Also handle records here.
  =#
  (arg2, ty, mk) = matchTypes(ty2, setArrayElementType(ty2, TYPE_REAL()), arg2, #= allowUnknown=# true)
  if ! isValidArgumentMatch(mk)
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("2", toString(fn_ref), "", toString(arg2), toString(ty2), "Real\\n  Real[:, ...]\\n  Real record\\n  Real record[:, ...]"), info)
  end
  @match [fn] = typeRefCache(fn_ref)
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg1, arg2], var, ty))
  (callExp, ty, variability)
end

function typeFillCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local fill_arg::Expression
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("fill", named_args, info)
  #=  fill can take any number of arguments, but needs at least two.
  =#
  if length(args) < 2
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "fill(Any, Integer, ...) => Any[:, ...]"), info)
  end
  @match [fill_arg, args...] = args
  #=  Type the first argument, which is the fill value. =#
  (fill_arg, ty, _) = typeExp(fill_arg, origin, info)
  (callExp, ty, variability) = typeFillCall2(fn_ref, ty, fill_arg, args, origin, info)
  (callExp, ty, variability)
end

function typeFillCall2(fnRef::ComponentRef,
                       @nospecialize(fillType::M_Type),
                       @nospecialize(fillArg::Expression),
                       dimensionArgs::Vector{Expression},
                       origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType = Variability.CONSTANT
  local ty::M_Type
  local callExp::Expression
  local ty_args::Vector{Expression} = Vector{Expression}(undef, length(dimensionArgs))
  local arg_var::VariabilityType
  local arg_ty::M_Type
  local fn::M_Function
  local dims::List{Dimension}
  local evaluated::Bool

  ty_args = Expression[fillArg]
  dims = nil
  evaluated = true
  #=  Type the dimension arguments.
  =#
  for (i,arg) in enumerate(dimensionArgs)
    (arg, arg_ty, arg_var) = typeExp(arg, origin, info)
    if arg_var <= Variability.STRUCTURAL_PARAMETER && ! flagSet(origin, ORIGIN_FUNCTION) && ! containsIterator(arg, origin)
      arg = evalExp(arg)
      arg_ty = typeOf(arg)
    else
      evaluated = false
    end
    if ! isInteger(arg_ty)
      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list(intString(listLength(ty_args) + 1), toString(fnRef), "", toString(arg), toString(arg_ty), "Integer"), info)
    end
    variability = variabilityMax(variability, arg_var)
    push!(ty_args, arg)
    dims = _cons(fromExp(arg, arg_var), dims)
  end
  #=  Each dimension argument must be an Integer expression. =#
  dims = listReverseInPlace(dims)
  @match [fn, T...]= typeRefCache(fnRef)
  ty = liftArrayLeftList(fillType, dims)
  if evaluated
    callExp = evalBuiltinFill(ty_args)
  else
    callExp = CALL_EXPRESSION(makeTypedCall(NFBuiltinFuncs.FILL_FUNC, ty_args, variability, ty))
  end
  (callExp, ty, variability)
end

function typeZerosOnesCall(name::String, @nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local fill_arg::Expression

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams(name, named_args, info)
  #=  zeros/ones can take any number of arguments, but needs at least one.
  =#
  if isempty(args)
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST,
                                  list(toString(call),
                                       toString(fn_ref) + "(Integer, ...) => Integer[:, ...]"), info)
  end
  fill_arg = INTEGER_EXPRESSION(if name == "ones"
                                  1
                                else
                                  0
                                end)
  (callExp, ty, variability) = typeFillCall2(fn_ref, TYPE_INTEGER(), fill_arg, args, origin, info)
  (callExp, ty, variability)
end

function typeScalarCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function
  local expanded::Bool

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("scalar", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "scalar(Any[1, ...]) => Any"), info)
  end
   (arg, ty, variability) = typeExp(args[1], origin, info)
  #=  scalar requires all dimensions of the array to be 1.
  =#
  for dim in arrayDims(ty)
    if isKnown(dim) && size(dim) != 1
      Error.addSourceMessageAndFail(Error.INVALID_ARRAY_DIM_IN_SCALAR_OP, list(toString(ty)), info)
    end
  end
   (arg, expanded) = expand(arg)
  @assign ty = arrayElementType(ty)
  if expanded
    @assign args = arrayScalarElements(arg)
    if length(args) != 1
      Error.assertion(false, getInstanceName() + " failed to expand scalar(" + toString(arg) + ") correctly", info)
    end
    @assign callExp = args[1]
  else
    @match Base.first(fn) = typeRefCache(fn_ref)
    @assign callExp = CALL(makeTypedCall(fn, Expression[arg], variability, ty))
  end
  (callExp, ty, variability)
end

function typeVectorCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local var::VariabilityType
  local fn::M_Function
  local vector_dim::Dimension = fromInteger(1)
  local dim_found::Bool = false

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("vector", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "vector(Any) => Any[:]\\n  vector(Any[:, ...]) => Any[:]"), info)
  end
  (arg, ty, variability) = typeExp(Base.first(args), origin, info)
  #=  vector requires that at most one dimension is > 1, and that dimension
  determines the type of the vector call.
  =#
  for dim in arrayDims(ty)
    if ! isKnown(dim) || size(dim) > 1
      if dim_found
        Error.addSourceMessageAndFail(Error.NF_VECTOR_INVALID_DIMENSIONS, list(toString(ty), toString(call)), info)
      else
        vector_dim = dim
        dim_found = true
      end
    end
  end
  ty = TYPE_ARRAY(arrayElementType(ty), list(vector_dim))
  @match [fn] = typeRefCache(fn_ref)
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], variability, ty))
  (callExp, ty, variability)
end

function typeMatrixCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local var::VariabilityType
  local fn::M_Function
  local dims::List{Dimension}
  local dim1::Dimension
  local dim2::Dimension
  local i::Int
  local ndims::Int
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("matrix", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST,
                                  list(toString(call),
                                       "vector(Any) => Any[:]\\n  vector(Any[:, ...]) => Any[:]"), info)
  end
  (arg, ty, variability) = typeExp(Base.first(args), origin, info)
  dims = arrayDims(ty)
  ndims = listLength(dims)
  if ndims < 2
    (callExp, ty) = promote(arg, ty, 2)
  elseif ndims == 2
    callExp = arg
  else
    @match _cons(dim1, _cons(dim2, dims)) = dims
    i = 3
    for dim in dims
      if isKnown(dim) && size(dim) > 1
        Error.addSourceMessageAndFail(Error.INVALID_ARRAY_DIM_IN_CONVERSION_OP, list(String(i), "matrix", "1", toString(dim)), info)
      end
      i = i + 1
    end
    ty = TYPE_ARRAY(arrayElementType(ty), list(dim1, dim2))
    @match [fn] = typeRefCache(fn_ref)
    callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], variability, ty))
  end
  #=  matrix(A) where A is a scalar or vector returns promote(A, 2).
  =#
  #=  matrix(A) where A is a matrix just returns A.
  =#
  #=  matrix requires all but the first two dimensions to have size 1.
  =#
  return (callExp, ty, variability)
end

function typeCatCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local res::Vector{Expression}
  local named_args::Vector{NamedArg}
  local tys::Vector{M_Type}
  local arg::Expression
  local var::VariabilityType
  local mk::MatchKindType
  local fn::M_Function
  local n::Int
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("cat", named_args, info)
  if length(args) < 2
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "cat(Integer, Any[:,:], ...) => Any[:]"), info)
  end
  @match [arg, args...] = args
  (arg, ty, variability) = typeExp(arg, origin, info)
  (arg, ty, mk) = matchTypes(ty, TYPE_INTEGER(), arg)
  if variability > Variability.PARAMETER
    Error.addSourceMessageAndFail(Error.NF_CAT_FIRST_ARG_EVAL, list(toString(arg), variabilityString(variability)), info)
  end
  @match INTEGER_EXPRESSION(n) = evalExp(arg, EVALTARGET_GENERIC(info))
  res = Expression[]
  tys = M_Type[]
  for a in args
    (arg, ty, var) = typeExp(a, origin, info)
    variability = variabilityMax(var, variability)
    res = push!(res, arg)
    tys = push!(tys, ty)
  end
  (callExp, ty) = makeCatExp(n, res, tys, variability, info)
  (callExp, ty, variability)
end

function typeSymmetricCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("symmetric", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "symmetric(Any[n, n]) => Any[n, n]"), info)
  end
   (arg, ty, variability) = typeExp(args[1], origin, info)
  if ! isSquareMatrix(ty)
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("1", toString(fn_ref), "", toString(arg), toString(ty), "Any[n, n]"), info)
  end
  @match [fn] = typeRefCache(fn_ref)
  @assign callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], variability, ty))
  (callExp, ty, variability)
end

function typeTransposeCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local dim1::Dimension
  local dim2::Dimension
  local rest_dims::List{Dimension}
  local fn::M_Function

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("transpose", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "transpose(Any[n, m, ...]) => Any[m, n, ...]"), info)
  end
  (arg, ty, variability) = typeExp(Base.first(args), origin, info)
  ty = begin
    @match ty begin
      TYPE_ARRAY(dimensions = dim1 <| dim2 <| rest_dims)  => begin
        TYPE_ARRAY(ty.elementType, _cons(dim2, _cons(dim1, rest_dims)))
      end
      _  => begin
        Error.addSourceMessage(Error.ARG_TYPE_MISMATCH, list("1", toString(fn_ref), "", toString(arg), toString(ty), "Any[:, :, ...]"), info)
        fail()
      end
    end
  end
  @match [fn] = typeRefCache(fn_ref)
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], variability, ty))
  (callExp, ty, variability)
end

function typeCardinalityCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.PARAMETER
  local ty::M_Type
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function
  local nodeVar::InstNode
  #=  cardinality may only be used in a condition of an assert or
  =#
  #=  if-statement/equation (the specification says only if-statement,
  =#
  #=  but e.g. the MSL only uses them in if-equations and asserts).
  =#
  if ! (flagSet(origin, ORIGIN_CONDITION) && (flagSet(origin, ORIGIN_IF) || flagSet(origin, ORIGIN_ASSERT)))
    Error.addSourceMessageAndFail(Error.INVALID_CARDINALITY_CONTEXT, nil, info)
  end
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("cardinality", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), toString(fn_ref) + "(Connector) => Integer"), info)
  end
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessageAndFail(Error.EXP_INVALID_IN_FUNCTION, list(toString(fn_ref)), info)
  end
  (arg, ty) = typeExp(Base.first(args), origin, info)
  if ! isCref(arg)
    Error.addSourceMessageAndFail(Error.ARGUMENT_MUST_BE_VARIABLE, list("First", toString(fn_ref), "<REMOVE ME>"), info)
  end
  nodeVar = node(toCref(arg))
  if ! (isScalar(ty) && isComponent(nodeVar) && isConnector(component(nodeVar)))
    Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("1", toString(fn_ref), "", toString(arg), toString(ty), "connector"), info)
  end
  @match [fn] = typeRefCache(fn_ref)
  ty = TYPE_INTEGER()
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], var, ty))
  #=  TODO: Check cardinality restrictions, 3.7.2.3. =#
  System.setUsesCardinality(true)
  return (callExp, ty, var)
end

function typeBranchCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.PARAMETER
  local ty::M_Type
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg1::Expression
  local arg2::Expression
  local fn::M_Function
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("Connections.branch", named_args, info)
  if length(args) != 2
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), toString(fn_ref) + "(Connector, Connector)"), info)
  end
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessageAndFail(Error.EXP_INVALID_IN_FUNCTION, list(toString(fn_ref)), info)
  end
  local newArgs = @match [arg1, arg2]  = args
  (newArgs[1], ty) = typeExp(arg1, origin, info)
  checkConnectionsArgument(newArgs[1], ty, fn_ref, 1, info)
  (newArgs[2], ty) = typeExp(arg2, origin, info)
  checkConnectionsArgument(newArgs[2], ty, fn_ref, 2, info)
  fn = Base.first(typeRefCache(fn_ref))
  ty = TYPE_NORETCALL()
  callExp = CALL_EXPRESSION(makeTypedCall(fn, newArgs, var, ty))
  (callExp, ty, var)
end

"""
Author: johti17
Extension. Types an initialStructuralState call.
"""
function typeInitialStructuralStateCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)
  local variabilityType::VariabilityType = Variability.PARAMETER
  #@debug "Typing..."
  @match UNTYPED_CALL(fn_ref, args, namedArgs) = call
  if length(args) != 1
    @error "More then one state passed to initialStructuralState" #=TODO add source info..=#
    throw("Error typing!")
  end
  #@debug "Type the head of the list. A model is used as a parameter"
  @match CREF_EXPRESSION(ty, argCref) = Base.first(args)

  local arg = CREF_EXPRESSION(TYPE_ANY() #= Reference to the model=#,
                        argCref#=Should be complex but use any for now=#)
  local retType = TYPE_NORETCALL()
  local fn = Base.first(typeRefCache(fn_ref))
  local callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], variabilityType, retType))
  return (callExp, retType, Variability.PARAMETER#=TODO should change this..=#)
end

"""
Author: johti17
Extension:
  Type an agentic_recompilation call.
  Takes one or more parameter references. The new values are determined at
  runtime by an external agent that receives the model metamodel and current
  simulation state. No second argument is required — the agent provides it.
"""
function typeAgenticRecompilationCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)
  local variabilityType::VariabilityType = Variability.PARAMETER
  @match UNTYPED_CALL(fn_ref, args, namedArgs) = call
  if length(args) < 1
    throw("Error typing! agentic_recompilation expects at least one argument")
  end
  typedArgs = Expression[]
  for arg in args
    @match CREF_EXPRESSION(_, argCref) = arg
    newCref = COMPONENT_REF_CREF(argCref.node,
                                  argCref.subscripts,
                                  argCref.ty,
                                  argCref.origin,
                                  argCref.restCref)
    push!(typedArgs, CREF_EXPRESSION(TYPE_ANY(), newCref))
  end
  local retType = TYPE_NORETCALL()
  fn = Base.first(typeRefCache(fn_ref))
  callExp = CALL_EXPRESSION(makeTypedCall(fn, typedArgs, variabilityType, retType))
  return (callExp, retType, variabilityType)
end

"""
Author:johti17
Extension:
  Type a recompilation call.
  Depending on what we do we create different calls.
  A call to recompilation means that a model should refer to itself to allow reflection.
"""
function typeRecompilationCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)
  local variabilityType::VariabilityType = Variability.PARAMETER
  @match UNTYPED_CALL(fn_ref, args, namedArgs) = call
  if length(args) != 2
    throw("Error typing! expected two arguments to recompilation")
  end
  #=
    We know we are going to change a parameter of the model we currently are operating on.
    Prepare the SCode for this model so that we can use it later.
  =#
  @match CREF_EXPRESSION(_, argCref1) = args[1]
  #=
    Change the variability of argCref1
    to avoid further simplifications in the frontend.
    We do this by creating a new component reference that is not pointing to a node.
  =#
  local newCref = COMPONENT_REF_CREF(argCref1.node,
                                     argCref1.subscripts,
                                     argCref1.ty,
                                     argCref1.origin,
                                     argCref1.restCref)
  local retType = TYPE_NORETCALL()
  local arg1 = CREF_EXPRESSION(TYPE_ANY() #= Reference to the parameter we are changing=#,
                               newCref #= Should be complex but use any for now=#)
  (arg2, _, _) = typeExp(args[2], origin, info)
  fn = Base.first(typeRefCache(fn_ref))
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg1, arg2], variabilityType, retType))
  return (callExp, retType, variabilityType)
end

"""
Author: johti17
Extension: Types a structural transition.
A structural transition have three arguments
1. Our current state. That is the model from which we make the transition.
2. Our next state. That is the model we transition to.
3. A condition. That is the when event at which the transition occurs.
"""
function typeStructuralTransition(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)
  @match UNTYPED_CALL(fn_ref, args, namedArgs) = call
  local variabilityType::VariabilityType = Variability.PARAMETER
  if length(args) != 3
    #=TODO add source info..=#
    @error "To few arguments to initialStructuralState. Three arguments are expected."
    throw("Syntax error: To few arguments to initialStructuralState")
  end
  @match CREF_EXPRESSION(_, argCref1) = args[1]
  @match CREF_EXPRESSION(_, argCref2) = args[2]
  local arg1 = CREF_EXPRESSION(TYPE_ANY() #= Reference to the model=#,
                               argCref1 #=Should be complex but use any for now=#)
  local arg2 = CREF_EXPRESSION(TYPE_ANY() #= Reference to the model=#,
                               argCref2 #=Should be complex but use any for now=#)
  #= The last expression here is a condition=#
  local (arg3, _, _) = typeExp(args[3], origin, info)
  local retType = TYPE_NORETCALL()
  local fn = Base.first(typeRefCache(fn_ref))
  local callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg1, arg2, arg3], variabilityType, retType))
  return (callExp, retType, Variability.PARAMETER#=TODO should change this..=#)
end

function typeIsRootCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.PARAMETER
  local ty::M_Type
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("Connections.isRoot", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), toString(fn_ref) + "(Connector)"), info)
  end
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessageAndFail(Error.EXP_INVALID_IN_FUNCTION, list(toString(fn_ref)), info)
  end
  (arg, ty) = typeExp(Base.first(args), origin, info)
  checkConnectionsArgument(arg, ty, fn_ref, 1, info)
  fn = Base.first(typeRefCache(fn_ref))
  ty = TYPE_BOOLEAN()
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], var, ty))
  (callExp, ty, var)
end

function typePotentialRootCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.PARAMETER
  local ty::M_Type
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg1::Expression
  local arg2::Expression
  local fn::M_Function
  local args_len::Int
  local name::String
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  for narg in named_args
     (name, arg2) = narg
    if name == "priority"
      push!(args, arg2)
    else
      Error.addSourceMessageAndFail(Error.NO_SUCH_PARAMETER, list(toString(fn_ref), name), info)
    end
  end
  args_len = length(args)
  if args_len < 1 || args_len > 2
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST,
                                  list(toString(call),
                                       toString(fn_ref) + "(Connector, Integer = 0)"), info)
  end
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessageAndFail(Error.EXP_INVALID_IN_FUNCTION, list(toString(fn_ref)), info)
  end
  @match [arg1, args...] = args
  (arg1, ty) = typeExp(arg1, origin, info)
  checkConnectionsArgument(arg1, ty, fn_ref, 1, info)
  if args_len == 2
    arg2 = Base.first(args)
    (arg2, ty) = typeExp(arg2, origin, info)
    if ! isInteger(ty)
      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("2", toString(fn_ref), "", toString(arg2), toString(ty), "Integer"), info)
    end
  else
    arg2 = INTEGER_EXPRESSION(0)
  end
  fn = Base.first(typeRefCache(fn_ref))
  ty = TYPE_NORETCALL()
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg1, arg2], var, ty))
  (callExp, ty, var)
end

function typeRootCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.PARAMETER
  local ty::M_Type
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("Connections.root", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), toString(fn_ref) + "(Connector)"), info)
  end
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessageAndFail(Error.EXP_INVALID_IN_FUNCTION, list(toString(fn_ref)), info)
  end
  (arg, ty) = typeExp(Base.first(args), origin, info)
  checkConnectionsArgument(arg, ty, fn_ref, 1, info)
  @match [fn] = typeRefCache(fn_ref)
  ty = TYPE_NORETCALL()
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], var, ty))
  return (callExp, ty, var)
end

function typeRootedCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.PARAMETER
  local ty::M_Type
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("Connections.rooted", named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), toString(fn_ref) + "(Connector)"), info)
  end
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessageAndFail(Error.EXP_INVALID_IN_FUNCTION, list(toString(fn_ref)), info)
  end
  (arg, ty) = typeExp(Base.first(args), origin, info)
  checkConnectionsArgument(arg, ty, fn_ref, 1, info)
  if isSimple(fn_ref)
    Error.addSourceMessage(Error.DEPRECATED_API_CALL, list("rooted", "Connections.rooted"), info)
  end
  fn = Base.first(typeRefCache(fn_ref))
  ty = TYPE_BOOLEAN()
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], var, ty))
  return (callExp, ty, var)
end

"""see also typeUniqueRootIndicesCall"""
function typeUniqueRootCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.PARAMETER
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg1::Expression
  local arg2::Expression
  local fn::M_Function
  local args_len::Int
  local name::String

  Error.addSourceMessage(Error.NON_STANDARD_OPERATOR, list("Connections.uniqueRoot"), info)
  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  for narg in named_args
     (name, arg2) = narg
    if name == "message"
      push!(args, arg2)
    else
      Error.addSourceMessageAndFail(Error.NO_SUCH_PARAMETER, list(toString(fn_ref), name), info)
    end
  end
  @assign args_len = length(args)
  if args_len < 1 || args_len > 2
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), toString(fn_ref) + "(Connector, String = \\\\)"), info)
  end
  if flagSet(origin, ORIGIN_FUNCTION)
    Error.addSourceMessageAndFail(Error.EXP_INVALID_IN_FUNCTION, list(toString(fn_ref)), info)
  end
  arg1 = args[1]; args = args[2:end]
   (arg1, ty) = typeExp(arg1, origin, info)
  checkConnectionsArgument(arg1, ty, fn_ref, 1, info)
  if args_len == 2
    @assign arg2 = args[1]
     (arg2, ty) = typeExp(arg2, origin, info)
    if ! isString(ty)
      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("2", toString(fn_ref), "", toString(arg2), toString(ty), "String"), info)
    end
  else
    @assign arg2 = STRING_EXPRESSION("")
  end
  fn = Base.first(typeRefCache(fn_ref))
  @assign ty = TYPE_NORETCALL()
  @assign callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg1, arg2], var, ty))
  (callExp, ty, var)
end

                """
                  See Modelica_StateGraph2:
                  https:github.com/modelica/Modelica_StateGraph2
                  and
                  https:trac.modelica.org/Modelica/ticket/984
                  and
                  http:www.ep.liu.se/ecp/043/041/ecp09430108.pdf
                  for a specification of this operator
                """
                function typeUniqueRootIndicesCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
                  local var::VariabilityType = Variability.PARAMETER
                  local ty::M_Type
                  local callExp::Expression

                  local fn_ref::ComponentRef
                  local args::Vector{Expression}
                  local named_args::Vector{NamedArg}
                  local arg1::Expression
                  local arg2::Expression
                  local arg3::Expression
                  local fn::M_Function
                  local args_len::Int
                  local name::String
                  local ty1::M_Type
                  local ty2::M_Type
                  local ty3::M_Type

#                  Error.addSourceMessage(Error.NON_STANDARD_OPERATOR, list("Connections.uniqueRootIndices"), info) TODO
                  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
                  for narg in named_args
                     (name, arg3) = narg
                    if name == "message"
                      push!(args, arg3)
                    else
#                      Error.addSourceMessageAndFail(Error.NO_SUCH_PARAMETER, list(toString(fn_ref), name), info) TODO
                    end
                  end
                  @assign args_len = length(args)
                  if args_len < 2 || args_len > 3
                    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), toString(fn_ref) + "(Connector, Connector, String = \\\\)"), info)
                  end
                  if flagSet(origin, ORIGIN_FUNCTION)
                    Error.addSourceMessageAndFail(Error.EXP_INVALID_IN_FUNCTION, list(toString(fn_ref)), info)
                  end
                  arg1 = args[1]; arg2 = args[2]; args = args[3:end]
                   (arg1, ty1) = typeExp(arg1, origin, info)
                  checkConnectionsArgument(arg1, ty1, fn_ref, 1, info)
                   (arg2, ty2) = typeExp(arg2, origin, info)
                  checkConnectionsArgument(arg2, ty2, fn_ref, 1, info)
                  if args_len == 3
                    @assign arg3 = args[1]
                     (arg3, ty3) = typeExp(arg3, origin, info)
                    if ! isString(ty3)
                      Error.addSourceMessageAndFail(Error.ARG_TYPE_MISMATCH, list("3", toString(fn_ref), "", toString(arg2), toString(ty3), "String"), info)
                    end
                  else
                    @assign arg2 = STRING_EXPRESSION("")
                  end
                  fn = Base.first(typeRefCache(fn_ref))
                  assert(listLength(arrayDims(ty1)) == listLength(arrayDims(ty2)), "the first two parameters need to have the same size")
                  @assign ty = TYPE_ARRAY(TYPE_INTEGER(), arrayDims(ty1))
                  @assign callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg1, arg2], var, ty))
                  (callExp, ty, var)
                end

"""
  This function checks the arguments to connectors
"""
function checkConnectionsArgument(@nospecialize(arg::Expression), @nospecialize(ty::M_Type), fnRef::ComponentRef, argIndex::Int, info::SourceInfo)
   () = begin
    local ty2::M_Type
    local node::InstNode
    local valid_cref::Bool
    local isConnectorBool::Bool
    @match arg begin
      CREF_EXPRESSION(__)  => begin
         (valid_cref, isConnectorBool) = begin
          @match arg.cref begin
            COMPONENT_REF_CREF(node = node, origin = Origin.CREF, restCref = COMPONENT_REF_CREF(ty = ty2, origin = Origin.CREF))  => begin
              #=  check form A.R
              =#
              @assign ty2 = begin
                @match ty2 begin
                  TYPE_ARRAY(__) where (listLength(subscriptsAllFlat(arg.cref)) == listLength(ty2.dimensions))  => begin
                    ty2.elementType
                  end

                  _  => begin
                    ty2
                  end
                end
              end
              (isOverdetermined(getClass(node)), isConnector(ty2))
            end

            COMPONENT_REF_CREF(node = node, ty = ty2)  => begin
              #=  adrpo #5821, allow for R only instead of A.R and issue a warning
              =#
              @assign ty2 = begin
                @match ty2 begin
                  TYPE_ARRAY(__) where (listLength(subscriptsAllFlat(arg.cref)) == listLength(ty2.dimensions))  => begin
                    ty2.elementType
                  end

                  _  => begin
                    ty2
                  end
                end
              end
              (isOverdetermined(getClass(node)), isConnector(ty2))
            end

            _  => begin
              (false, false)
            end
          end
        end
        if ! (valid_cref && isConnectorBool)
          if valid_cref
            Error.addSourceMessage(if argIndex == 1
                                   Error.W_INVALID_ARGUMENT_TYPE_BRANCH_FIRST
                                   else
                                   Error.W_INVALID_ARGUMENT_TYPE_BRANCH_SECOND
                                   end, list(toString(arg.cref), toString(fnRef)), info)
          else
            Error.addSourceMessageAndFail(if argIndex == 1
                                          Error.INVALID_ARGUMENT_TYPE_BRANCH_FIRST
                                          else
                                          Error.INVALID_ARGUMENT_TYPE_BRANCH_SECOND
                                          end, list(toString(arg.cref), toString(fnRef)), info)
          end
        end
        ()
      end

      _  => begin
        Error.addSourceMessage(Error.ARG_TYPE_MISMATCH, list(String(argIndex), toString(fnRef), "", toString(arg), toString(ty), "overconstrained type/record"), info)
        fail()
      end
    end
  end
end

function typeNoEventCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local fn::M_Function

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams("noEvent", named_args, info)
  #=  noEvent takes exactly one argument.
  =#
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), "noEvent(Any) => Any"), info)
  end
  @match [arg] = args
  (arg, ty, variability) = typeExp(arg, setFlag(origin, ORIGIN_NOEVENT), info)
  fn = Base.first(typeRefCache(fn_ref))
  callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], variability, ty))
  (callExp, ty, variability)
end

function typeGetInstanceName(@nospecialize(call::Call)) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.CONSTANT
  local ty::M_Type = TYPE_STRING()
  local result::Expression
  local scope::InstNode
  @match UNTYPED_CALL(call_scope = scope) = call
  result = STRING_EXPRESSION(AbsynUtil.pathString(scopePath(scope, includeRoot = true)))
  (result, ty, var)
end

function typeClockCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType = Variability.PARAMETER
  local outType::M_Type = TYPE_CLOCK()
  local callExp::Expression

  local ty_call::Call
  local args::Vector{Expression}
  local args_count::Int
  local e1::Expression
  local e2::Expression

  @match TYPED_CALL(arguments = args) = typeMatchNormalCall(call, origin, info)
  @assign args_count = length(args)
  @assign callExp = begin
    @match args begin
      nil()  => begin
        CLKCONST(P_Expression.P_ClockKind.Expression.INFERRED_CLOCK())
      end

      e1 <|  nil()  => begin
        CLKCONST(P_Expression.P_ClockKind.REAL_EXPRESSION_CLOCK(e1))
      end

      e1 <| e2 <|  nil()  => begin
        #=  Clock() - inferred clock.
        =#
        #=  Clock(interval) - real clock.
        =#
        @assign e2 = evalExp(e2)
        @assign callExp = begin
          @match typeOf(e2) begin
            TYPE_INTEGER(__)  => begin
              #=  Clock(intervalCounter, resolution) - integer clock.
              =#
              Error.assertionOrAddSourceMessage(integerValue(e2) >= 1, Error.WRONG_VALUE_OF_ARG, list("Clock", "resolution", toString(e2), "=> 1"), info)
              CLKCONST(INTEGER_EXPRESSION_CLOCK(e1, e2))
            end

            TYPE_REAL(__)  => begin
              CLKCONST(BOOLEAN_EXPRESSION_CLOCK(e1, e2))
            end

            TYPE_STRING(__)  => begin
              CLKCONST(SOLVER_CLOCK(e1, e2))
            end
          end
        end
        #=  Clock(condition, startInterval) - boolean clock.
        =#
        #=  Clock(c, solverMethod) - solver clock.
        =#
        callExp
      end
    end
  end
  (callExp, outType, var)
end

function typeSampleCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)::Tuple{Expression, M_Type, VariabilityType}
  local var::VariabilityType
  local outType::M_Type
  local callExp::Expression

  local ty_call::Call
  local arg_ty::M_Type
  local args::Vector{TypedArg}
  local namedArgs::Vector{TypedNamedArg}
  local e::Expression
  local e1::Expression
  local e2::Expression
  local t::M_Type
  local t1::M_Type
  local t2::M_Type
  local v::VariabilityType
  local v1::VariabilityType
  local v2::VariabilityType
  local fn_ref::ComponentRef
  local normalSample::M_Function
  local clockedSample::M_Function
  local recopnode::InstNode

  @match ARG_TYPED_CALL(fn_ref, args, namedArgs) = typeNormalCall(call, origin, info)
  recopnode = node(fn_ref)
  (fn_ref, _, _) = instFunctionRef(fn_ref, InstNode_info(recopnode))
  @match [normalSample, clockedSample,  T...] = typeRefCache(fn_ref)
  (callExp, outType, var) = begin
    @match (args, namedArgs) begin
      ([(e, t, v), (e1, TYPE_INTEGER(__), v1)],  _) where{isempty(namedArgs)}  => begin
        #=  sample(start, Real interval) - the usual stuff
        =#
        if valueEq(t, TYPE_INTEGER())
          e = CAST_EXPRESSION(TYPE_REAL(), e)
        end
        ty_call = makeTypedCall(normalSample, Expression[e, CAST_EXPRESSION(TYPE_REAL(), e1)], Variability.PARAMETER, TYPE_BOOLEAN())
        (CALL_EXPRESSION(ty_call), TYPE_BOOLEAN(), Variability.PARAMETER)
      end

      ([(e, t, v), (e1, TYPE_REAL(__), v1) ],  _) where{isempty(namedArgs)}  => begin
        #=  sample(start, Real interval) - the usual stuff
        =#
        if valueEq(t, TYPE_INTEGER())
          @assign e = CAST_EXPRESSION(TYPE_REAL(), e)
        end
        ty_call = makeTypedCall(normalSample, Expression[e, e1], Variability.PARAMETER, TYPE_BOOLEAN())
        (CALL_EXPRESSION(ty_call), TYPE_BOOLEAN(), Variability.PARAMETER)
      end

      ([(e, t, v)], [("interval", e1, TYPE_REAL(__), v1)])  => begin
        #=  sample(start, Real interval = value) - the usual stuff
        =#
        if valueEq(t, TYPE_INTEGER())
          @assign e = CAST_EXPRESSION(TYPE_REAL(), e)
        end
        @assign ty_call = makeTypedCall(normalSample, Expression[e, e1], Variability.PARAMETER, TYPE_BOOLEAN())
        (CALL_EXPRESSION(ty_call), TYPE_BOOLEAN(), Variability.PARAMETER)
      end

      ([(e, t, v)],  _) where (isempty(namedArgs) && Config.synchronousFeaturesAllowed())  => begin
        #=  sample(u) - inferred clock
        =#
        @assign ty_call = makeTypedCall(clockedSample, Expression[e, CLKCONST(P_Expression.P_ClockKind.Expression.INFERRED_CLOCK())], v, t)
        (CALL_EXPRESSION(ty_call), t, v)
      end

      ([(e, t, v), (e1, TYPE_CLOCK(__), v1)],  _) where (isempty(namedArgs) && Config.synchronousFeaturesAllowed())  => begin
        #=  sample(u, c) - specified clock
        =#
        @assign ty_call = makeTypedCall(clockedSample, Expression[e, e1], v, t)
        (CALL_EXPRESSION(ty_call), t, v)
      end

      ([(e, t, v)], [("c", e1, TYPE_CLOCK(__), v1)]) where (Config.synchronousFeaturesAllowed())  => begin
        #=  sample(u, Clock c = c) - specified clock
        =#
        ty_call = makeTypedCall(clockedSample, Expression[e, e1], v, t)
        (CALL_EXPRESSION(ty_call), t, v)
      end

      _  => begin
        Error.addSourceMessage(Error.WRONG_TYPE_OR_NO_OF_ARGS, list(toString(call), "<NO COMPONENT>"), info)
        fail()
      end
    end
  end
  (callExp, outType, var)
end

function typeActualInStreamCall(name::String, @nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType = Variability.DISCRETE
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local arg_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg::Expression
  local var::VariabilityType
  local fn::M_Function
  local arg_node::InstNode

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams(name, named_args, info)
  if length(args) != 1
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), toString(fn_ref) + "(stream variable) => Real"), info)
  end
  (arg, ty, var) = typeExp(args[1], origin, info)
  (arg, _) = expand(arg)
  fn = Base.first(typeRefCache(fn_ref))
  @assign callExp = typeActualInStreamCall2(name, fn, arg, var, info)
  (callExp, ty, Variability.CONTINUOUS)
end

function typeActualInStreamCall2(name::String, fn::M_Function, @nospecialize(arg::Expression), var::VariabilityType, info::SourceInfo) ::Expression
  local callExp::Expression

  @assign callExp = begin
    local arg_node::InstNode
    @match arg begin
      CREF_EXPRESSION(__)  => begin
        @assign arg_node = node(arg.cref)
        #=  The argument of actualStream/inStream must be a stream variable.
        =#
        if ! isComponent(arg_node) || ! isStream(connectorType(component(arg_node)))
          Error.addSourceMessageAndFail(Error.NON_STREAM_OPERAND_IN_STREAM_OPERATOR, list(toString(arg.cref), name), info)
        end
        #=  The argument of actualStream/inStream must have subscripts that can be evaluated.
        =#
        for sub in subscriptsAllFlat(arg.cref)
          if variability(sub) > Variability.PARAMETER
            Error.addSourceMessageAndFail(Error.CONNECTOR_NON_PARAMETER_SUBSCRIPT, list(toString(arg.cref), toString(sub)), info)
          end
        end
        CALL_EXPRESSION(makeTypedCall(fn, Expression[arg], var, arg.ty))
      end

      ARRAY_EXPRESSION(__)  => begin
        local argElements = list(typeActualInStreamCall2(name, fn, e, var, info) for e in arg.elements)
        ARRAY_EXPRESSION(arg.ty, argElements, arg.literal)
        arg
      end

      _  => begin
        Error.addSourceMessage(Error.NON_STREAM_OPERAND_IN_STREAM_OPERATOR, list(toString(arg), name), info)
        fail()
      end
    end
  end
  callExp
end

function typeDynamicSelectCall(name::String, @nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo) ::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType = Variability.CONTINUOUS
  local ty::M_Type
  local callExp::Expression

  local fn_ref::ComponentRef
  local arg_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local arg1::Expression
  local arg2::Expression
  local var1::VariabilityType
  local var2::VariabilityType
  local fn::M_Function
  local arg_node::InstNode
  local ty1::M_Type
  local ty2::M_Type
  local expStatic::Expression
  local expDynamic::Expression

  @match UNTYPED_CALL(ref = fn_ref, arguments = args, named_args = named_args) = call
  assertNoNamedParams(name, named_args, info)
  if length(args) != 2
    Error.addSourceMessageAndFail(Error.NO_MATCHING_FUNCTION_FOUND_NFINST, list(toString(call), toString(fn_ref) + "(static expression, dynamic expression)"), info)
  end
  @match list(expStatic, expDynamic) = list(unbox(arg) for arg in args)
   (arg1, ty1, var1) = typeExp(expStatic, origin, info)
  (arg1, _) = expand(arg1)
  #=  if we cannot typecheck the dynamic part, ignore it!
  =#
  #=  https:trac.openmodelica.org/OpenModelica/ticket/5631
  =#
  try
     (arg2, ty2, var2) = typeExp(expDynamic, origin, info)
  catch e
    @assign variability = var1
    @assign callExp = arg1
    return (callExp, ty, variability)
  end
  (arg2, _) = expand(arg2)
  @assign ty = ty1
  @assign variability = var2
  fn = Base.first(typeRefCache(fn_ref))
  if Flags.isSet(Flags.NF_API_DYNAMIC_SELECT)
    @assign callExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[arg1, arg2], variability, ty1))
  else
    @assign variability = var1
    @assign callExp = arg1
  end
  (callExp, ty, variability)
end

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

module ParameterTreeImpl

using MetaModelica
using ExportAll
import ..Frontend.Expression
import ..Frontend.toString

#= Modelica extend clause =#
const Key = String
const Value = Expression

"""Define the printing functions."""
function keyStr(key)
  return key
end

include("../Util/baseDictTreeCode.jl")
addConflictDefault = addConflictReplace
compFunc(inKey1::Key, inKey2::Key) = begin
  #Should it default to ==== instead since types are in many cases immutable?
  res = stringCompare(inKey1, inKey2)
  return res
end
#= Add comp function =#
keyCompare = compFunc
end #=ParameterTreeImpl=#

const ParameterTree = ParameterTreeImpl.Tree


abstract type CallAttributes end

"""
```CALL_ATTR```
This struct specifies the attributes for a call.
"""
mutable struct CALL_ATTR <: CallAttributes
  tuple_::Bool #=tuple =#
  builtin::Bool #=builtin Function call =#
  isImpure::Bool #=if the function has prefix *impure* is true, else false =#
  isFunctionPointerCall::Bool
  inlineType::DAE.InlineType
  tailCall::DAE.TailCall #=Input variables of the function if the call is tail-recursive =#
end

abstract type Call end

mutable struct TYPED_REDUCTION <: Call
  fn::M_Function
  ty::NFType
  var::VariabilityType
  exp::Expression
  iters::List{Tuple{InstNode, Expression}}
  defaultExp::Option{Expression}
  foldExp::Tuple{Option{Expression}, String, String}
end

mutable struct TYPED_ARRAY_CONSTRUCTOR <: Call
  ty::NFType
  var::VariabilityType
  exp::Expression
  iters::List{Tuple{InstNode, Expression}}
end

mutable struct TYPED_CALL <: Call
  fn::M_Function
  ty::NFType
  var::VariabilityType
  arguments::Vector{Expression}
  attributes::CallAttributes
end

mutable struct ARG_TYPED_CALL <: Call
  ref::ComponentRef
  arguments::Vector{TypedArg}
  named_args::Vector{TypedNamedArg}
  call_scope::InstNode
end

mutable struct UNTYPED_CALL <: Call
  ref::ComponentRef
  arguments::Vector{Expression}
  named_args::Vector{NamedArg}
  call_scope::InstNode
end

mutable struct UNTYPED_REDUCTION <: Call
  ref::ComponentRef
  exp::Expression
  iters::List{Tuple{InstNode, Expression}}
end

mutable struct UNTYPED_ARRAY_CONSTRUCTOR <: Call
  exp::Expression
  iters::List{Tuple{InstNode, Expression}}
end


@UniontypeDecl CallAttributes

function toDAE(attr::CallAttributes, @nospecialize(returnType::NFType))::DAE.CallAttributes
  local fattr::DAE.CallAttributes
   fattr = DAE.CALL_ATTR(
     toDAE(returnType),
    attr.tuple_,
    attr.builtin,
    attr.isImpure,
    attr.isFunctionPointerCall,
    attr.inlineType,
    attr.tailCall,
  )
  return fattr
end

function typeCast(callExp::CALL_EXPRESSION, ty::NFType)
  @match CALL_EXPRESSION(call = call) = callExp
  return _typeCastCall(call, ty, callExp)
end

function _typeCastCall(call::TYPED_CALL, ty::NFType, callExp::CALL_EXPRESSION)
  isBuiltin(call.fn) || return CAST_EXPRESSION(setArrayElementType(typeOf(call), ty), callExp)
  local cast_ty = setArrayElementType(call.ty, ty)
  local fn_name = AbsynUtil.pathFirstIdent(name(call.fn))
  if fn_name == "fill"
    return CALL_EXPRESSION(TYPED_CALL(call.fn, cast_ty, call.var,
      Expression[typeCast(Base.first(call.arguments), ty), call.arguments[2:end]...],
      call.attributes))
  elseif fn_name == "diagonal"
    return CALL_EXPRESSION(TYPED_CALL(call.fn, cast_ty, call.var,
      Expression[typeCast(call.arguments[1], ty)],
      call.attributes))
  else
    return CAST_EXPRESSION(cast_ty, callExp)
  end
end

function _typeCastCall(call::Call, ty::NFType, callExp::CALL_EXPRESSION)
  CAST_EXPRESSION(setArrayElementType(typeOf(call), ty), callExp)
end

function retype(@nospecialize(call::Call))::Call

   () = begin
    local ty::NFType
    local dims::List{Dimension}
    @match call begin
      TYPED_ARRAY_CONSTRUCTOR(__) => begin
         dims = nil
        for i in listReverse(call.iters)
           dims = listAppend(
            arrayDims(typeOf(Util.tuple22(i))),
            dims,
          )
        end
        callTy = liftArrayLeftList(arrayElementType(call.ty), dims)
        call = TYPED_ARRAY_CONSTRUCTOR(callTy, call.var, call.exp, call.iters)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return call
end

function isVectorizeable(@nospecialize(call::Call))::Bool
  isVect = begin
    local name::String
    @match call begin
      TYPED_CALL(fn = M_FUNCTION(path = Absyn.IDENT(name = name))) => begin
        begin
          @match name begin #TODO add other special functions here.
            "der" => begin
              false
            end
            "pre" => begin
              false
            end
            "previous" => begin
              false
            end
            _ => begin
              true
            end
          end
        end
      end
      _ => begin
        true
      end
    end
  end
  return isVect
end

function toDAE(@nospecialize(call::Call))
  local daeCall::DAE.Exp
   daeCall = begin
    local fold_id::String
    local res_id::String
    local fold_exp::Option{Expression}
    @match call begin
      TYPED_CALL(__) => begin
        DAE.CALL(
          nameConsiderBuiltin(call.fn),
          list(toDAE(e) for e in call.arguments),
          toDAE(call.attributes, call.ty),
        )
      end
      TYPED_ARRAY_CONSTRUCTOR(__) => begin
        fold_id = Util.getTempVariableIndex()
        res_id = Util.getTempVariableIndex()
        DAE.REDUCTION(
          DAE.REDUCTIONINFO(
            name(NFBuiltinFuncs.ARRAY_FUNC),
            Absyn.COMBINE(),
            toDAE(call.ty),
            NONE(),
            fold_id,
            res_id,
            NONE(),
          ),
          toDAE(call.exp),
          list(iteratorToDAE(iter) for iter in call.iters),
        )
      end

      TYPED_REDUCTION(__) => begin
         (fold_exp, fold_id, res_id) = call.foldExp
        DAE.REDUCTION(
          DAE.REDUCTIONINFO(
            name(call.fn),
            Absyn.COMBINE(),
            toDAE(call.ty),
            toDAEValueOpt(call.defaultExp),
            fold_id,
            res_id,
            toDAEOpt(fold_exp),
          ),
          toDAE(call.exp),
          list(iteratorToDAE(iter) for iter in call.iters),
        )
      end

      _ => begin
        Error.assertion(false, getInstanceName() + " got untyped call", sourceInfo())
        fail()
      end
    end
  end
  return daeCall
end

"""Like toString, but prefixes each argument with its type as a comment."""
function typedString(@nospecialize(call::Call))::String
  local str::String

  local name::String
  local arg_str::String
  local c::String
  local argexp::Expression

   str = begin
    @match call begin
      ARG_TYPED_CALL(__) => begin
         name = toString(call.ref)
         arg_str = stringDelimitList(
          list(
            "/*" +
            toString(Util.tuple32(arg)) +
            "*/ " +
            toString(Util.tuple31(arg))
            for arg in call.arguments
          ),
          ", ",
        )
        for arg in call.named_args
           c = if arg_str == ""
            ""
          else
            ", "
          end
           arg_str =
            arg_str +
            c +
            Util.tuple41(arg) +
            " = /*" +
            toString(Util.tuple43(arg)) +
            "*/ " +
            toString(Util.tuple42(arg))
        end
        name + "(" + arg_str + ")"
      end

      TYPED_CALL(__) => begin
         name = AbsynUtil.pathString(name(call.fn))
         arg_str = stringDelimitList(
          list(toStringTyped(arg) for arg in call.arguments),
          ", ",
        )
        name + "(" + arg_str + ")"
      end

      _ => begin
        toString(call)
      end
    end
  end
  return str
end

function toFlatString(@nospecialize(call::Call); inFunction = false)
  local str::String
  local nameVar::String
  local arg_str::String
  local c::String
  local argexp::Expression
  local iters::List{InstNode}
   str = begin
    @match call begin
      TYPED_CALL(__) => begin
        nameVar = AbsynUtil.pathString(name(call.fn))
        arg_str = stringDelimitList(
          list(toFlatString(arg; inFunction = inFunction) for arg in call.arguments),
          ", ",
        )
        if isBuiltin(call.fn)
          stringAppendList(list(nameVar, "(", arg_str, ")"))
        else
          stringAppendList(list("'", nameVar, "'(", arg_str, ")"))
        end
      end

      TYPED_ARRAY_CONSTRUCTOR(__) => begin
        if isVectorized(call)
           str = toFlatString(devectorizeCall(call); inFunction = inFunction)
        else
          nameVar = AbsynUtil.pathString(name(NFBuiltinFuncs.ARRAY_FUNC))
           arg_str = toFlatString(call.exp; inFunction = inFunction)
           c = stringDelimitList(
            list(
              toFlatString(Util.tuple21(iter); inFunction = inFunction) +
              " in " +
              toFlatString(Util.tuple22(iter); inFunction = inFunction)
              for iter in call.iters
            ),
            ", ",
          )
           str = stringAppendList(list("{", arg_str, " for ", c, "}"))
        end
        #=  Vectorized calls contains iterators with illegal Modelica names
        =#
        #=  (to avoid name conflicts), to make the flat output legal such
        =#
        #=  calls are reverted to their original form here.
        =#
        str
      end

      TYPED_REDUCTION(__) => begin
         nameVar = AbsynUtil.pathString(name(call.fn))
         arg_str = toFlatString(call.exp; inFunction = inFunction)
         c = stringDelimitList(
          list(
            toFlatString(Util.tuple21(iter); inFunction = inFunction) +
            " in " +
            toFlatString(Util.tuple22(iter); inFunction = inFunction)
            for iter in call.iters
          ),
          ", ",
        )
        if isBuiltin(call.fn)
          stringAppendList(list(nameVar, "(", arg_str, " for ", c, ")"))
        else
          stringAppendList(list("'", nameVar, "'(", arg_str, " for ", c, ")"))
        end
      end
    end
  end
  return str
end

function toString(@nospecialize(call::Call))::String
  local str::String
  local nameStr::String
  local arg_str::String
  local c::String
  local argexp::Expression
  local iters::List{InstNode}

   str = begin
    @match call begin
      UNTYPED_CALL(__) => begin
        nameStr = toString(call.ref)
         arg_str = stringDelimitList(
          list(toString(arg) for arg in call.arguments),
          ", ",
        )
        nameStr * "(" * arg_str * ")"
      end

      ARG_TYPED_CALL(__) => begin
        nameStr = toString(call.ref)
         arg_str = stringDelimitList(
          list(
            toString(Util.tuple31(arg)) for arg in call.arguments
          ),
          ", ",
        )
        for arg in call.named_args
           c = if arg_str == ""
            ""
          else
            ", "
          end
           arg_str =
            arg_str *
            c *
            Util.tuple41(arg) +
            " = " *
            toString(Util.tuple42(arg))
        end
        nameStr * "(" * arg_str * ")"
      end

      UNTYPED_ARRAY_CONSTRUCTOR(__) => begin
        nameStr = AbsynUtil.pathString(name(NFBuiltinFuncs.ARRAY_FUNC))
        arg_str = toString(call.exp)
        c = stringDelimitList(
          list(
            name(Util.tuple21(iter)) *
            " in " *
            toString(Util.tuple22(iter))
            for iter in call.iters
          ),
          ", ",
        )
        "{" * arg_str * " for " * c * "}"
      end

      UNTYPED_REDUCTION(__) => begin
        nameStr = toString(call.ref)
         arg_str = toString(call.exp)
         c = stringDelimitList(
          list(
            name(Util.tuple21(iter)) +
            " in " +
            toString(Util.tuple22(iter))
            for iter in call.iters
          ),
          ", ",
        )
        name + "(" + arg_str + " for " + c + ")"
      end

      TYPED_CALL(__) => begin
        nameStr = AbsynUtil.pathString(name(call.fn))
        arg_str = stringDelimitList(
          list(toString(arg) for arg in call.arguments),
          ", ",
        )
        nameStr + "(" + arg_str + ")"
      end

      TYPED_ARRAY_CONSTRUCTOR(__) => begin
        nameStr = AbsynUtil.pathString(name(NFBuiltinFuncs.ARRAY_FUNC))
        arg_str = toString(call.exp)
        c = stringDelimitList(
          list(
            name(Util.tuple21(iter)) *
            " in " *
            toString(Util.tuple22(iter))
            for iter in call.iters
          ),
          ", ",
        )
        "{" * arg_str * " for " * c * "}"
      end

      TYPED_REDUCTION(__) => begin
nameStr = AbsynUtil.pathString(name(call.fn))
         arg_str = toString(call.exp)
         c = stringDelimitList(
          list(
            name(Util.tuple21(iter)) +
            " in " +
            toString(Util.tuple22(iter))
            for iter in call.iters
          ),
          ", ",
        )
        name + "(" + arg_str + " for " + c + ")"
      end
    end
  end
  return str
end

function toRecordExpression(@nospecialize(call::Call), @nospecialize(ty::NFType))::Expression
  local exp::Expression
   exp = begin
    @match call begin
      TYPED_CALL(__) => begin
        evaluateRecordConstructor(call.fn, ty, call.arguments; evaluate = false)
      end
      _ => begin
        Error.assertion(false, getInstanceName() + " got unknown call", sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function arguments(@nospecialize(call::Call))::Vector{Expression}
  local arguments::Vector{Expression}
   arguments = begin
    @match call begin
      UNTYPED_CALL(__) => begin
        call.arguments
      end
      TYPED_CALL(__) => begin
        call.arguments
      end
    end
  end
  return arguments
end

const ARRAY_IDENTIFIER = Absyn.IDENT("array")
function functionName(@nospecialize(call::Call))::Absyn.Path
  local nameV::Absyn.Path
  nameV = begin
    @match call begin
      UNTYPED_CALL(__) => begin
        toPath(call.ref)
      end
      ARG_TYPED_CALL(__) => begin
        toPath(call.ref)
      end
      TYPED_CALL(__) => begin
        name(call.fn)
      end
      UNTYPED_ARRAY_CONSTRUCTOR(__) => begin
        ARRAY_IDENTIFIER
      end
      TYPED_ARRAY_CONSTRUCTOR(__) => begin
        ARRAY_IDENTIFIER
      end
      UNTYPED_REDUCTION(__) => begin
        toPath(call.ref)
      end
      TYPED_REDUCTION(__) => begin
        name(call.fn)
      end
    end
  end
  return nameV
end

function typedFunction(@nospecialize(call::Call))::M_Function
  local fn::M_Function
   fn = begin
    @match call begin
      TYPED_CALL(__) => begin
        call.fn
      end
      TYPED_ARRAY_CONSTRUCTOR(__) => begin
        NFBuiltinFuncs.ARRAY_FUNC
      end
      TYPED_REDUCTION(__) => begin
        call.fn
      end
      _ => begin
        Error.assertion(false, getInstanceName() + " got untyped function", sourceInfo())
        fail()
      end
    end
  end
  return fn
end

function inlineType(@nospecialize(call::Call))::DAE.InlineType
  local inlineTy::DAE.InlineType
   inlineTy = begin
    @match call begin
      TYPED_CALL(attributes = CALL_ATTR(inlineType = inlineTy)) => begin
        inlineTy
      end
      _ => begin
        DAE.NO_INLINE()
      end
    end
  end
  return inlineTy
end

function isRecordConstructor(@nospecialize(call::Call))::Bool
  local isConstructor::Bool

   isConstructor = begin
    @match call begin
      UNTYPED_CALL(__) => begin
        SCodeUtil.isRecord(definition(node(call.ref)))
      end
      TYPED_CALL(__) => begin
        SCodeUtil.isRecord(definition(call.fn.node))
      end
      _ => begin
        false
      end
    end
  end
  return isConstructor
end

function isImpure(@nospecialize(call::Call))::Bool
  local impure::Bool
  impure = begin
    @match call begin
      UNTYPED_CALL(__) => begin
        isImpure(Base.first(getRefCache(call.ref)))
      end
      TYPED_CALL(__) => begin
        isImpure(call.fn) || isOMImpure(call.fn)
      end
      _ => begin
        false
      end
    end
  end
  return impure
end

function isNotImpure(@nospecialize(call::Call))::Bool
  return !(isImpure(call))
end

function isExternal(@nospecialize(call::Call))::Bool
  local isExt::Bool
  isExt = begin
    @match call begin
      UNTYPED_CALL(__) => begin
        isExternalFunction(getClass(node(call.ref)))
      end
      ARG_TYPED_CALL(__) => begin
        isExternalFunction(getClass(node(call.ref)))
      end
      TYPED_CALL(__) => begin
        isExternal(call.fn) #Changed from just returning true johti17 2023-03-26
      end
      _ => begin
        false
      end
    end
  end
  return isExt
end

function compare(@nospecialize(call1::Call), @nospecialize(call2::Call))::Int
  local comp::Int
   comp = begin
    @match (call1, call2) begin
      (UNTYPED_CALL(__), UNTYPED_CALL(__)) => begin
        compare(call1.ref, call2.ref)
      end
      (TYPED_CALL(__), TYPED_CALL(__)) => begin
        AbsynUtil.pathCompare(name(call1.fn), name(call2.fn))
      end
      (UNTYPED_CALL(__), TYPED_CALL(__)) => begin
        AbsynUtil.pathCompare(
          toPath(call1.ref),
          name(call2.fn),
        )
      end
      (TYPED_CALL(__), UNTYPED_CALL(__)) => begin
        AbsynUtil.pathCompare(
          name(call1.fn),
          toPath(call2.ref),
        )
      end
    end
  end
  if comp == 0
    comp = compareVector(arguments(call1), arguments(call2))
  end
  return comp
end

function variability(@nospecialize(call::Call))::VariabilityType
  local var::VariabilityType
   var = begin
    local var_set::Bool
    @match call begin
      UNTYPED_CALL(__) => begin
         var_set = true
        if isSimple(call.ref)
           var = begin
            @match firstName(call.ref) begin
              "change" => Variability.DISCRETE
              "edge" => Variability.DISCRETE
              "pre" => Variability.DISCRETE
              "ndims" => Variability.PARAMETER
              "cardinality" => Variability.PARAMETER
              _ => begin
                 var_set = false
                Variability.CONTINUOUS
              end
            end
          end
        end
        if !var_set
           var = variabilityList(call.arguments)
          for narg in call.named_args
             var = variabilityMax(
              var,
              variability(Util.tuple22(narg)),
            )
          end
        end
        var
      end
      UNTYPED_ARRAY_CONSTRUCTOR(__) => variability(call.exp)
      UNTYPED_REDUCTION(__) => variability(call.exp)
      TYPED_CALL(__) => call.var
      TYPED_ARRAY_CONSTRUCTOR(__) => call.var
      TYPED_REDUCTION(__) => call.var
      _ => begin
        Error.assertion(false, getInstanceName() + " got untyped call", sourceInfo())
        fail()
      end
    end
  end
  return var
end

function setType(@nospecialize(call::Call), @nospecialize(ty::NFType))
  local callWithNewType = if call isa TYPED_CALL
    TYPED_CALL(call.fn, ty, call.var, call.arguments, call.attributes)
  elseif call isa TYPED_ARRAY_CONSTRUCTOR
    TYPED_ARRAY_CONSTRUCTOR(ty, call.var, call.exp, call.iters)
  elseif call isa TYPED_REDUCTION
    TYPED_REDUCTION(call.fn, ty, call.var, call.exp,
                    call.iters, call.defaultExp, call.foldExp)
  end
  return callWithNewType
end

function typeOf(@nospecialize(call::Call))::NFType
  local ty::NFType
   ty = begin
    @match call begin
      TYPED_CALL(__) || TYPED_ARRAY_CONSTRUCTOR(__) ||  TYPED_REDUCTION(__) =>  begin
        call.ty
      end
      _ => begin
        TYPE_UNKNOWN()
      end
    end
  end
  return ty
end

function matchTypedNormalCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)::Call
  local func::M_Function
  local args::Vector{Expression}
  local typed_args::Vector{TypedArg}
  local matchedFunc::MatchedFunction
  local scope::InstNode
  local var::VariabilityType
  local arg_var::VariabilityType
  local ty::NFType
  local arg_exp::Expression
  @match ARG_TYPED_CALL(call_scope = scope) = call
   matchedFunc = checkMatchingFunctions(call, info)
   func = matchedFunc.func
   typed_args = matchedFunc.args
   args = Vector{Expression}(undef, length(typed_args))
  #=  if is impure, make it a parameter expression
  =#
  #=  see https:trac.openmodelica.org/OpenModelica/ticket/5133
  =#
  var = if isImpure(func) || isOMImpure(func)
    Variability.PARAMETER
  else
    Variability.CONSTANT
  end
  for (i, a) in enumerate(typed_args)
    (arg_exp, _, arg_var) = a
    args[i] = arg_exp
    var = variabilityMax(var, arg_var)
  end
  ty = returnType(func)
  #=  Hack to fix return type of some builtin functions. =#
  if isPolymorphic(ty)
    ty = getSpecialReturnType(func, args)
  end
  if var == Variability.PARAMETER && isExternal(func)
    var = Variability.NON_STRUCTURAL_PARAMETER
  elseif isDiscrete(ty) && var == Variability.CONTINUOUS
    var = Variability.IMPLICITLY_DISCRETE
  end
  #=  Mark external functions with parameter expressions as non-structural,
  =#
  #=  to avoid them being marked as structural unnecessarily.
  =#
  #=  Functions that return a discrete type, e.g. Integer, should probably be
  =#
  #=  treated as implicitly discrete if the arguments are continuous.
  =#
  (ty, _) = evaluateCallType(ty, func, args)
  call = makeTypedCall(func, args, var, ty)
  #=  If the matching was a vectorized one then create a map call
  =#
  #=  using the vectorization dim. This means going through each argument
  =#
  #=  and subscipting it with an iterator for each dim and creating a map call.
  =#
  if isVectorized(matchedFunc)
    call = vectorizeCall(call, matchedFunc.mk, scope, info)
  end
  return call
end

function typeMatchNormalCall(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)::Call
  local argtycall::Call
  argtycall = typeNormalCall(call, origin, info)
  call = matchTypedNormalCall(argtycall, origin, info)
  return call
end

function unboxArgs(call::TYPED_CALL)
  local args = Expression[unbox(arg) for arg in call.arguments]#TODO: Can potentially be done inline
  return TYPED_CALL(call.fn, call.ty, call.var, args, call.attributes)
end

function makeTypedCall(
  @nospecialize(fn::M_Function),
  @nospecialize(args::Vector{Expression}),
  @nospecialize(variability::VariabilityType),
  returnType::NFType = fn.returnType,
)::Call
  local call::Call
  local ca::CallAttributes
   ca = CALL_ATTR(
    isTuple(returnType),
    isBuiltin(fn),
    isImpure(fn),
    isFunctionPointer(fn),
    inlineBuiltin(fn),
    DAE.NO_TAIL(),
  )
   call = TYPED_CALL(fn, returnType, variability, args, ca)
  return call
end

function typeNormalCall(call::UNTYPED_CALL, origin::ORIGIN_Type, info::SourceInfo)::Call
  local fnl::Vector{M_FUNCTION} = typeRefCache(call.ref)
  call = typeArgs(call, origin, info)
  return call
end

function typeCall(
  callExp::Expression,
  origin::ORIGIN_Type,
  info::SourceInfo,
  )::Tuple{Expression, NFType, Int64}
  arg1 = callExp
  arg2 = origin
  arg3 = info
  @match CALL_EXPRESSION(call = call) = callExp
  if call isa TYPED_ARRAY_CONSTRUCTOR || call isa TYPED_REDUCTION || call isa TYPED_CALL || call isa ARG_TYPED_CALL
    ty = call.ty
    var = call.var
    return (callExp, call.ty, call.var)
  end
  return typeCall2(
    arg1,
    arg2,
    arg3,
  )
end

function typeCall2(
  callExp::CALL_EXPRESSION,
  origin::ORIGIN_Type,
  info::SourceInfo,
  )::Tuple{Expression, NFType, Int64}
  local var::VariabilityType
  local ty::NFType
  local outExp::Expression
  local call::Call
  local ty_call::Call
  local args::Vector{Expression}
  local cref::ComponentRef
  @match CALL_EXPRESSION(call = call) = callExp
  outExp = begin
    @match call begin
      UNTYPED_CALL(ref = cref) => begin
        if needSpecialHandling(call)
          (outExp, ty, var) = typeSpecial(call, origin, info)
        else
          ty_call = typeMatchNormalCall(call, origin, info)
          ty = typeOf(ty_call)
          var = variability(ty_call)
          if isRecordConstructor(ty_call)
            outExp = toRecordExpression(ty_call, ty)
          else
            if hasUnboxArgs(typedFunction(ty_call))
              outExp = CALL_EXPRESSION(unboxArgs(ty_call))
            else
              outExp = CALL_EXPRESSION(ty_call)
            end
            outExp = inlineCallExp(outExp::CALL_EXPRESSION)
          end
        end
        outExp
      end
      UNTYPED_ARRAY_CONSTRUCTOR(__) => begin
        (ty_call, ty, var) = typeArrayConstructor(call, origin, info)
        CALL_EXPRESSION(ty_call)
      end
      UNTYPED_REDUCTION(__) => begin
        (ty_call, ty, var) = typeReduction(call, origin, info)
        CALL_EXPRESSION(ty_call)
      end
      _ => begin
        Error.assertion(
          false,
          "Typing call" + ": " + toString(callExp) + ". Internal type: $(typeof(call))",
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return (outExp, ty, var)
end

function instantiate(
  functionName::Absyn.ComponentRef,
  functionArgs::Absyn.FunctionArgs,
  scope::InstNode,
  info::SourceInfo
)::Expression
  local callExp::Expression
   callExp = begin
    @match functionArgs begin
      Absyn.FUNCTIONARGS(__) => begin
        instNormalCall(functionName, functionArgs, scope, info)
      end
      Absyn.FOR_ITER_FARG(__) => begin
        instIteratorCall(functionName, functionArgs, scope, info)
      end
      _ => begin
        Error.assertion(false, getInstanceName() + " got unknown call type", sourceInfo())
        fail()
      end
    end
  end
  return callExp
end

function getSpecialReturnType(fn::M_Function, args::List{<:Expression})::NFType
  local ty::NFType

   ty = begin
    @match fn.path begin
      Absyn.IDENT("min") => begin
        arrayElementType(typeOf(unbox(Base.first(
          args,
        ))))
      end

      Absyn.IDENT("max") => begin
        arrayElementType(typeOf(unbox(Base.first(
          args,
        ))))
      end

      Absyn.IDENT("sum") => begin
        arrayElementType(typeOf(unbox(Base.first(
          args,
        ))))
      end

      Absyn.IDENT("product") => begin
        arrayElementType(typeOf(unbox(Base.first(
          args,
        ))))
      end

      Absyn.IDENT("previous") => begin
        typeOf(unbox(Base.first(args)))
      end

      Absyn.IDENT("shiftSample") => begin
        typeOf(unbox(Base.first(args)))
      end

      Absyn.IDENT("backSample") => begin
        typeOf(unbox(Base.first(args)))
      end

      Absyn.IDENT("hold") => begin
        typeOf(unbox(Base.first(args)))
      end

      Absyn.IDENT("superSample") => begin
        typeOf(unbox(Base.first(args)))
      end

      Absyn.IDENT("subSample") => begin
        typeOf(unbox(Base.first(args)))
      end

      Absyn.IDENT("DynamicSelect") => begin
        typeOf(unbox(Base.first(args)))
      end

      _ => begin
        Error.assertion(
          false,
          getInstanceName() + ": unhandled case for " + AbsynUtil.pathString(fn.path),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return ty
end

function evaluateCallTypeDimExp(@nospecialize(exp::Expression), ptree::ParameterTree)::Expression
  local outExp::Expression
  outExp = begin
    local node::InstNode
    local e::Expression
    @match exp begin
      CREF_EXPRESSION(
        cref = COMPONENT_REF_CREF(
          node = node,
          restCref = COMPONENT_REF_EMPTY(__),
        ),
      ) => begin
        local v = ParameterTreeImpl.tryGet(ptree, name(node))
        if v !== nothing
          outExp = v
        end
        #=  TODO: Apply subscripts. =#
        outExp
      end
      _ => begin
        exp
      end
    end
  end
  return outExp
end

function buildParameterTree(
  fnArgs::Tuple{M_Function, Vector{Expression}},
  ptree::ParameterTree,
  )::ParameterTree
  #@info "Constructing a parameter tree...."
  local fn::M_Function
  local arg::Expression
  if !(ParameterTreeImpl.isEmpty(ptree))
    return ptree
  end
  local args::Vector{Expression}
  (fn, args) = fnArgs
  local ii = 1
  for i in fn.inputs
    arg = args[ii]
    ptree = ParameterTreeImpl.add(ptree, name(i), arg)
    ii += 1
  end
  #=  TODO: Add local variable bindings. =#
  return ptree
end

function evaluateCallTypeDim(
  dim::Dimension,
  fnArgs::Tuple{M_Function, Vector{Expression}},
  ptree::ParameterTree,
  )::Tuple{Dimension, ParameterTree}
   dim = begin
    local exp::Expression
    @match dim begin
      DIMENSION_EXP(__) => begin
        ptree = buildParameterTree(fnArgs, ptree)
        exp = map(
          dim.exp,
          (expArg) -> evaluateCallTypeDimExp(expArg, ptree),
        )
        ErrorExt.setCheckpoint(getInstanceName())
        try
          exp = evalExp(exp, EVALTARGET_IGNORE_ERRORS())
        catch e
          if e isa InterruptException
            rethrow()
          end
        end
        ErrorExt.rollBack(getInstanceName())
        fromExp(exp, Variability.CONSTANT)
      end

      _ => begin
        dim
      end
    end
  end
  return (dim, ptree)
end

function evaluateCallType(
  ty::NFType,
  fn::M_Function,
  args::Vector{Expression},
  ptree::ParameterTree = ParameterTreeImpl.EMPTY(),
  )::Tuple{NFType, ParameterTree}
   ty = begin
    local dims::List{Dimension}
    local tys::List{NFType}
    @match ty begin
      TYPE_ARRAY(__) => begin
        (dims, ptree) = ListUtil.map1Fold(ty.dimensions, evaluateCallTypeDim, (fn, args), ptree)
        tyDimensions = dims
        TYPE_ARRAY(ty.elementType, tyDimensions)
      end
      TYPE_TUPLE(__) => begin
        (tys, ptree) = ListUtil.map2Fold(ty.types, evaluateCallType, fn, args, ptree)
        tyTypes = tys
        TYPE_TUPLE(tyTypes, ty.names)
      end
      _ => begin
        ty
      end
    end
  end
  return (ty, ptree)
end

"""
  Transforms a vectorized call into a non-vectorized one. This function is
  used as a helper to output valid flat Modelica, and should probably not
  be used where e.g. correct types are required.
"""
function devectorizeCall(@nospecialize(call::Call))::Call
  local outCall::Call
  local exp::Expression
  local iter_exp::Expression
  local iters::List{Tuple{InstNode, Expression}}
  local iter_node::InstNode
  @match TYPED_ARRAY_CONSTRUCTOR(exp = exp, iters = iters) = call
  for i in iters
     (iter_node, iter_exp) = i
     exp = replaceIterator(exp, iter_node, iter_exp)
  end
  @match CALL_EXPRESSION(call = outCall) = exp
  return outCall
end

function isVectorized(@nospecialize(call::Call))::Bool
  local vectorized::Bool
   vectorized = begin
    @match call begin
      TYPED_ARRAY_CONSTRUCTOR(exp = CALL_EXPRESSION(__)) => begin
        stringGet(name(Util.tuple21(listHead(call.iters))), 1) == 36
      end
      _ => begin
        false
      end
    end
  end
  #=  A call is considered to be vectorized if the first iterator has a name
  =#
  #=  beginning with $.
  =#
  #= /* $ */ =#
  return vectorized
end

function vectorizeCall(
  base_call::Call,
  mk::FunctionMatchKind,
  scope::InstNode,
  info::SourceInfo,
  )::Call
  #@info "vectorizeCall" toString(base_call)
  local vectorized_call::Call
  local ty::NFType
  local vect_ty::NFType
  local exp::Expression
  local iters::List{Tuple{InstNode, Expression}}
  local iter::InstNode
  local i::Int
  local vect_idx::Int
  local b::Bool
  local call_args::Vector{Expression}
  local vect_args::Vector{Expression}
  local sub::Subscript
  local vect_idxs::List{Int}
  vectorized_call = begin
    @match (base_call, mk) begin
      (TYPED_CALL(arguments = call_args), VECTORIZED_MATCH_KIND(__)) => begin
         iters = nil
         i = 1
        for dim in mk.vectDims
          Error.assertion(
            isKnown(dim, true),
            getInstanceName() + " got unknown dimension for vectorized call",
            info,
          )
          ty = TYPE_ARRAY(TYPE_INTEGER(), list(dim))
          exp = RANGE_EXPRESSION(
            ty,
            INTEGER_EXPRESSION(1),
            NONE(),
            sizeExp(dim),
          )
          iter = fromComponent(
            "i" + intString(i),
            ITERATOR_COMPONENT(TYPE_INTEGER(), Variability.CONSTANT, info),
            scope,
          )
          iters = _cons((iter, exp), iters)
          exp = CREF_EXPRESSION(
            TYPE_INTEGER(),
            makeIterator(iter, TYPE_INTEGER()),
          )
          sub = SUBSCRIPT_INDEX(exp)
          call_args = ArrayUtil.mapIndices(
            call_args,
            listArray(mk.vectorizedArgs),
            (x) -> applySubscript(
              sub,
              x,
              list(),
            ),
          )
          i = i + 1
        end
        #=  Create the range on which we will iterate to vectorize.
        =#
        #=  Create the iterator.
        =#
        #=  Now that iterator is ready apply it, as a subscript, to each argument that is supposed to be vectorized
        =#
        #=  Make a cref expression from the iterator =#
        vect_ty = liftArrayLeftList(base_call.ty, mk.vectDims)
        base_call = TYPED_CALL(base_call.fn, base_call.ty, base_call.var, call_args, base_call.attributes)
        TYPED_ARRAY_CONSTRUCTOR(
          vect_ty,
          base_call.var,
          CALL_EXPRESSION(base_call),
          iters,
        )
      end

      _ => begin
        Error.addInternalError(getInstanceName() + " got unknown call", info)
        fail()
      end
    end
  end
  return vectorized_call
end

function iteratorToDAE(iter::Tuple{<:InstNode, Expression})::DAE.ReductionIterator
  local diter::DAE.ReductionIterator
  local iter_node::InstNode
  local iter_range::Expression
  local c::Component
  local b::Binding
   (iter_node, iter_range) = iter
   diter = DAE.REDUCTIONITER(
    name(iter_node),
    toDAE(iter_range),
    NONE(),
    toDAE(getType(iter_node)),
  )
  return diter
end

function checkMatchingFunctions(@nospecialize(call::Call), info::SourceInfo)
  local matchedFunc::MatchedFunction
  local matchedFunctions::Vector{MatchedFunction}
  local exactMatches::Vector{MatchedFunction}
  local func::M_Function
  local allfuncs::Vector{M_Function}
  local fn_node::InstNode
  local numerr::Int = 0 # TODO Error.getNumErrorMessages()
  local errors::List{Int}

  ErrorExt.setCheckpoint("NFCall:checkMatchingFunctions")
  matchedFunctions = begin
    @match call begin
      ARG_TYPED_CALL(ref = COMPONENT_REF_CREF(node = fn_node)) => begin
        allfuncs = getCachedFuncs(fn_node)
        if length(allfuncs) > 1
          allfuncs = M_FUNCTION[fn for fn in allfuncs if !isDefaultRecordConstructor(fn)]
        end
        matchFunctions(allfuncs, call.arguments, call.named_args, info)
      end
    end
  end
  if isempty(matchedFunctions)
    if length(allfuncs) > 1
      ErrorExt.rollBack("NFCall:checkMatchingFunctions")
      Error.addSourceMessage(
        Error.NO_MATCHING_FUNCTION_FOUND_NFINST,
        list(typedString(call), candidateFuncListString(allfuncs)),
        info,
      )
    elseif numerr == 0 #Error.getNumErrorMessages() TODO
      ErrorExt.rollBack("NFCall:checkMatchingFunctions")
      Error.addSourceMessage(
        Error.NO_MATCHING_FUNCTION_FOUND_NFINST,
        list(typedString(call), candidateFuncListString(allfuncs)),
        info,
      )
    else
      ErrorExt.delCheckpoint("NFCall:checkMatchingFunctions")
    end
    fail()
  end
  ErrorExt.rollBack("NFCall:checkMatchingFunctions")
  if length(matchedFunctions) > 1
     exactMatches = getExactMatches(matchedFunctions)
    if isempty(exactMatches)
       exactMatches = getExactVectorizedMatches(matchedFunctions)
    end
    if length(exactMatches) > 1
      Error.addSourceMessage(
        Error.AMBIGUOUS_MATCHING_FUNCTIONS_NFINST,
        list(
          typedString(call),
          candidateFuncListString(list(mfn.func for mfn in matchedFunctions)),
        ),
        info,
      )
      fail()
    end
    matchedFunc = Base.first(exactMatches)
  else
    matchedFunc = Base.first(matchedFunctions)
  end
  #=  Overwrite the actual function name with the overload name for builtin functions.
  =#
  if isBuiltin(matchedFunc.func)
    func = matchedFunc.func
    local funcPath = nameConsiderBuiltin(func)
    func = M_FUNCTION(funcPath,
               func.node,
               func.inputs,
               func.outputs,
               func.locals,
               func.slots,
               func.returnType,
               func.attributes,
               func.derivatives,
               func.status,
               func.callCounter)
    #@assign matchedFunc.func = func
    matchedFunc = MATCHED_FUNC(func, matchedFunc.args, matchedFunc.mk)
  end
  return matchedFunc
end

function typeArgs(@nospecialize(call::Call), origin::ORIGIN_Type, info::SourceInfo)::Call
   call = begin
    local arg::Expression
    local arg_ty::NFType
    local arg_var::VariabilityType
    local typedArgs::Vector{TypedArg}
    local typedNamedArgs::Vector{TypedNamedArg}
    local name::String
    local next_origin::ORIGIN_Type
    @match call begin
      UNTYPED_CALL(__) => begin
        typedArgs = Vector{TypedArg}(undef, length(call.arguments))
        next_origin = setFlag(origin, ORIGIN_SUBEXPRESSION)
        local tyRef = Ref{NFType}(TYPE_UNKNOWN())
        local varRef = Ref{VariabilityType}(Variability.CONSTANT)
        for (i, arg) in enumerate(call.arguments)
          e = typeExp2(arg, next_origin, info, tyRef, varRef)
          typedArgs[i] = (e, tyRef.x, varRef.x)
        end
        typedNamedArgs = Vector{TypedNamedArg}(undef, length(call.named_args))
        for (i,narg) in enumerate(call.named_args)
          #(name, arg) = narg
          typedNamedArgs[i] = (narg[1], typeExp(narg[2], next_origin, info)...)#::Tuple{Expression, NFType, Int}
          # = T#(name, arg, arg_ty, arg_var)
        end
        ARG_TYPED_CALL(call.ref, typedArgs, typedNamedArgs, call.call_scope)
      end
    end
   end
  return call
end

function reductionFoldIterator(name::String, ty::NFType)::Expression
  local iterExp::Expression

   iterExp = CREF_EXPRESSION(
    ty,
    makeIterator(NAME_NODE(name), ty),
  )
  return iterExp
end

function reductionFoldExpression(
  reductionFn::M_Function,
  reductionType::NFType,
  reductionVar::VariabilityType,
  foldId::String,
  resultId::String,
)::Option{Expression}
  local foldExp::Option{Expression}

  local ty::NFType
  local op_node::InstNode
  local fn::M_Function

  if isComplex(reductionType)
     foldExp = begin
      @match AbsynUtil.pathFirstIdent(name(reductionFn)) begin
        "sum" => begin
          @match TYPE_COMPLEX(cls = op_node) = reductionType
          @match ENTRY_INFO(op_node, _) = lookupElement("'+'", getClass(op_node))
          instFunctionNode(op_node)
          fns = typeNodeCache(op_node)
          fn = fns[1]
          SOME(CALL_EXPRESSION(makeTypedCall(
            fn,
            Expression[
              reductionFoldIterator(resultId, reductionType),
              reductionFoldIterator(foldId, reductionType),
            ],
            reductionVar,
          )))
        end
        _ => begin
          NONE()
        end
      end
    end
  else
     foldExp = begin
      @match AbsynUtil.pathFirstIdent(name(reductionFn)) begin
        "sum" => begin
          SOME(BINARY_EXPRESSION(
            reductionFoldIterator(resultId, reductionType),
            makeAdd(reductionType),
            reductionFoldIterator(foldId, reductionType),
          ))
        end

        "product" => begin
          SOME(BINARY_EXPRESSION(
            reductionFoldIterator(resultId, reductionType),
            makeMul(reductionType),
            reductionFoldIterator(foldId, reductionType),
          ))
        end

        "array" => begin
          NONE()
        end

        "array" => begin
          NONE()
        end

        "list" => begin
          NONE()
        end

        "listReverse" => begin
          NONE()
        end

        _ => begin
          SOME(CALL_EXPRESSION(makeTypedCall(
            reductionFn,
            Expression[
              reductionFoldIterator(foldId, reductionType),
              reductionFoldIterator(resultId, reductionType),
            ],
            reductionVar,
            reductionType,
          )))
        end
      end
    end
  end
  return foldExp
end

function reductionDefaultValue(fn::M_Function, ty::NFType)::Option{Expression}
  local defaultValue::Option{Expression}

  if isArray(ty)
     defaultValue = NONE()
  else
     defaultValue = begin
      @match AbsynUtil.pathFirstIdent(name(fn)) begin
        "sum" => begin
          SOME(makeZero(ty))
        end

        "product" => begin
          SOME(makeOne(ty))
        end

        "min" => begin
          SOME(makeMaxValue(ty))
        end

        "max" => begin
          SOME(makeMinValue(ty))
        end

        _ => begin
          Error.addSourceMessage(
            Error.INTERNAL_ERROR,
            list(
              getInstanceName() +
              " got unknown reduction name " +
              AbsynUtil.pathFirstIdent(name(fn)),
            ),
            sourceInfo(),
          )
          fail()
        end
      end
    end
  end
  return defaultValue
end

function typeReduction(
  call::Call,
  origin::ORIGIN_Type,
  info::SourceInfo,
)::Tuple{Call, NFType, VariabilityType}
  local variability::VariabilityType
  local ty::NFType
  local range::Expression
  local arg::Expression
  local default_exp::Option{Expression}
  local fold_exp::Option{Expression}
  local iter::InstNode
  local iter_var::VariabilityType
  local exp_var::VariabilityType
  local iters::List{Tuple{InstNode, Expression}} = nil
  local next_origin::ORIGIN_Type
  local fn::M_Function
  local fold_id::String
  local res_id::String
  local fold_tuple::Tuple{Option{Expression}, String, String}
  return (call, ty, variability) = begin
    @match call begin
      UNTYPED_REDUCTION(__) => begin
         variability = Variability.CONSTANT
         next_origin = setFlag(origin, ORIGIN_SUBEXPRESSION)
        for i in call.iters
           (iter, range) = i
           (range, _, iter_var) =
            typeIterator(iter, range, origin, false)
           variability = variabilityMax(variability, iter_var)
           iters = Cons{Tuple{InstNode, Expression}}((iter, range), iters)
        end
         iters = listReverseInPlace(iters)
        #=  ExpOrigin.FOR is used here as a marker that this expression may contain iterators.
        =#
        next_origin = intBitOr(next_origin, ORIGIN_FOR)
        (arg, ty, exp_var) = typeExp(call.exp, next_origin, info)
        variability = variabilityMax(variability, exp_var)
        @match [fn, rst...] = typeRefCache(call.ref)
        checkReductionType(ty, name(fn), call.exp, info)
        fold_id = Util.getTempVariableIndex()
        res_id = Util.getTempVariableIndex()
        default_exp = reductionDefaultValue(fn, ty)
        fold_exp = reductionFoldExpression(fn, ty, variability, fold_id, res_id)
        fold_tuple = (fold_exp, fold_id, res_id)
        (
          TYPED_REDUCTION(fn, ty, variability, arg, iters, default_exp, fold_tuple),
          ty,
          variability,
        )
      end
      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " got invalid reduction call",
          sourceInfo(),
        )
        fail()
      end
    end
  end
end

function typeArrayConstructor(
  @nospecialize(call::Call),
  @nospecialize(origin::ORIGIN_Type),
  @nospecialize(info::SourceInfo),
)::Tuple{Call, NFType, VariabilityType}
  local variability::VariabilityType
  local ty::NFType
  local arg::Expression
  local range::Expression
  local iter_ty::NFType
  local iter_var::VariabilityType
  local exp_var::VariabilityType
  local iter::InstNode
  local dims::List{Dimension} = nil
  local iters::List{Tuple{InstNode, Expression}} = nil
  local next_origin::ORIGIN_Type
  local is_structural::Bool

  (call, ty, variability) = begin
    @match call begin
      UNTYPED_ARRAY_CONSTRUCTOR(__) => begin
        variability = Variability.CONSTANT
        #=  The size of the expression must be known unless we're in a function. =#
        is_structural = flagNotSet(origin, ORIGIN_FUNCTION)
        next_origin = setFlag(origin, ORIGIN_SUBEXPRESSION)
        for i in call.iters
          (iter, range) = i
          (range, iter_ty, iter_var) =
            Base.inferencebarrier(typeIterator(iter, range, next_origin, is_structural)::Tuple{Expression, NFType, VariabilityType})
          if is_structural
            range = evalExp(range, EVALTARGET_RANGE(info))
            iter_ty = typeOf(range)
          end
          dims = listAppend(arrayDims(iter_ty), dims)
          variability = variabilityMax(variability, iter_var)
          iters = Cons{Tuple{InstNode, Expression}}((iter, range), iters)
        end
        iters = listReverseInPlace(iters)
        #=  ExpOrigin.FOR is used here as a marker that this expression may contain iterators.
        =#
        next_origin = intBitOr(next_origin, ORIGIN_FOR)
        (arg, ty, exp_var) = typeExp(call.exp, next_origin, info)
        variability = variabilityMax(variability, exp_var)
        ty = liftArrayLeftList(ty, dims)
        variability = variabilityMax(variability, exp_var)
        (TYPED_ARRAY_CONSTRUCTOR(ty, variability, arg, iters), ty, variability)
      end

      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " got invalid function call expression",
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return (call, ty, variability)
end

function instIterators(
  inIters::List{<:Absyn.ForIterator},
  scope::InstNode,
  info::SourceInfo,
)::Tuple{InstNode, List{Tuple{InstNode, Expression}}}
  local outIters::List{Tuple{InstNode, Expression}} = nil
  local outScope::InstNode = scope
  local range::Expression
  local iter::InstNode
  for i in inIters
    range = instExp(Util.getOption(i.range), outScope, info)
    (outScope, iter) = addIteratorToScope(i.name, outScope, info)
    outIters = Cons{Tuple{InstNode, Expression}}((iter, range), outIters)
  end
  outIters = listReverse(outIters)
  return (outScope, outIters)
end

function instIteratorCallArgs(
  args::Absyn.FunctionArgs,
  scope::InstNode,
  info::SourceInfo,
)::Tuple{Expression, List{Tuple{InstNode, Expression}}}
  local iters::List{Tuple{InstNode, Expression}}
  local exp::Expression
   _ = begin
    local for_scope::InstNode
    @match args begin
      Absyn.FOR_ITER_FARG(__) => begin
        (for_scope, iters) = instIterators(args.iterators, scope, info)
        exp = instExp(args.exp, for_scope, info)
        ()
      end
    end
  end
  return (exp, iters)
end

function instIteratorCall(
  functionName::Absyn.ComponentRef,
  functionArgs::Absyn.FunctionArgs,
  scope::InstNode,
  info::SourceInfo,
  )::Expression
  local callExp::Expression
  local fn_name::Absyn.ComponentRef
  local fn_ref::ComponentRef
  local exp::Expression
  local iters::List{Tuple{InstNode, Expression}}
  local is_array::Bool
  #=  The parser turns {exp for i in ...} into $array(exp for i in ...), but we
  =#
  #=  change it to just array here so we can handle array constructors uniformly.=#
   fn_name = begin
    @match functionName begin
      Absyn.CREF_IDENT("\$array") => begin
        Absyn.CREF_IDENT("array", nil)
      end
      _ => begin
        functionName
      end
    end
  end
  (exp, iters) = instIteratorCallArgs(functionArgs, scope, info)
  if AbsynUtil.crefFirstIdent(fn_name) == "array"
    callExp = CALL_EXPRESSION(UNTYPED_ARRAY_CONSTRUCTOR(exp, iters))
  else
    (fn_ref, _, _) = instFunction(fn_name, scope, info)
    callExp = CALL_EXPRESSION(UNTYPED_REDUCTION(fn_ref, exp, iters))
  end
  return callExp
end

function instNamedArg(absynArg::Absyn.NamedArg, scope::InstNode, info::SourceInfo)::NamedArg
  local arg::NamedArg
  local name::String
  local exp::Absyn.Exp
  @match Absyn.NAMEDARG(argName = name, argValue = exp) = absynArg
  arg = (name, instExp(exp, scope, info))
  return arg
end

function instArgs(
  args::Absyn.FunctionArgs,
  scope::InstNode,
  info::SourceInfo
)::Tuple{Vector{Expression}, Vector{NamedArg}}
  local namedArgs::Vector{NamedArg}
  local posArgs::Vector{Expression}
  #@debug "Calling inst args for $args"
   (posArgs, namedArgs) = begin
    @match args begin
      Absyn.FUNCTIONARGS(__) => begin
        #@debug "Matched function args"
        local arr1 = Expression[instExp(a, scope, info) for a in args.args]
        posArgs = arr1
        #@debug "Positional arguments done"
        local arr2 = NamedArg[instNamedArg(a, scope, info) for a in args.argNames]
        namedArgs = arr2#list(instNamedArg(a, scope, info) for a in args.argNames)
        #@debug "Named arguments done"
        (posArgs, namedArgs)
      end
      _ => begin
        #Error.assertion(false, getInstanceName() + " got unknown function args", sourceInfo())
        @error "Unknown arguments for the function @ $info"
        fail()
      end
    end
  end
  return (posArgs, namedArgs)
end

function instNormalCall(
  @nospecialize(functionName::Absyn.ComponentRef),
  @nospecialize(functionArgs::Absyn.FunctionArgs),
  @nospecialize(scope::InstNode),
  @nospecialize(info::SourceInfo),
)
  local callExp::Expression
  local fn_ref::ComponentRef
  local args::Vector{Expression}
  local named_args::Vector{NamedArg}
  local name::String
  name = AbsynUtil.crefFirstIdent(functionName)
  #=  try to inst the parameters =#
  try
    (args, named_args) = instArgs(functionArgs, scope, info)
 catch e
    if false #Config.getGraphicsExpMode() && stringEq(name, "DynamicSelect") #TODO =#
      callExp = begin
        @match functionArgs begin
          Absyn.FUNCTIONARGS(__) => begin
            instExp(listHead(functionArgs.args), scope, info)
          end
        end
      end
      return callExp
    else
      @error "Failed with error instantiating $(name). The full trace is supressed. The error is related to $(e)"
      fail()
    end
  end
  #=  didn't work, is this DynamicSelect dynamic part?! #5631
  =#
  #=  return just the first part of DynamicSelect
  =#
  callExp = begin
    @match name begin
      "size" => begin
        makeSizeExp(args, named_args, info)
      end
      "array" => begin
        makeArrayExp(args, named_args, info)
      end
      _ => begin
        #=  size creates Expression.SIZE instead of Expression.CALL.
        =#
        #=  array() call with no iterators creates Expression.ARRAY instead of Expression.CALL.
        =#
        #=  If it had iterators then it will not reach here. The args would have been parsed to
        =#
        #=  Absyn.FOR_ITER_FARG and that is handled in instIteratorCall.
        =#
        (fn_ref, _, _) = instFunction(functionName, scope, info)
        CALL_EXPRESSION(UNTYPED_CALL(fn_ref, args, named_args, scope))
      end
    end
  end
  return callExp
end


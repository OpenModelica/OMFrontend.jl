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

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll

module ReplTree

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll

import ..Frontend.Expression
import ..Frontend.InstNode
import ..Frontend.refCompare
import ..Frontend.toString
import ..Frontend.Util

const Key = InstNode
const Value = Expression

include("../Util/baseAvlTreeCode.jl")

keyStr(inKey::Key)::String = toString(inKey)
valueStr(inValue::Value)::String = toString(inValue)
const addConflictDefault = addConflictFail
keyCompare(inKey1::Key, inKey2::Key)::Int = refCompare(inKey1, inKey2)

@exportAll()
end

const FlowControlType = Int
"""
How a statement ends. `ASSERTION`: an assert failed with level error; `FAILURE`: the statement could not be
evaluated (an expression that does not evaluate, an unsupported assignment, a loop limit). Both end the
function's evaluation with `EVAL_FAILED`.
"""
struct FlowControlStruct{T}
  NEXT::T
  CONTINUE::T
  BREAK::T
  RETURN::T
  ASSERTION::T
  FAILURE::T
end
const FlowControl = FlowControlStruct{Int}(1,2,3,4,5,6)

"""An internal error of the function evaluation reported (omc Error.assertion without the failure)."""
function _internalError(msg::String)::Nothing
  Error.addSourceMessage(Error.INTERNAL_ERROR, list(msg), sourceInfo())
  return nothing
end

"""The value of `exp` in a statement, or `EVAL_FAILED` (Ceval's messages kept)."""
function _evalStmtExp(@nospecialize(exp::Expression), target::EvalTarget)::Expression
  local r::Expression = evalExp_impl(exp, target)
  return r isa EVAL_FAILURE ? r : getBindingExp(r)
end

const _EVAL_RECURSION_LIMIT_CACHE = Ref{Int}(-1)
@inline function _evalRecursionLimit()::Int
  local v::Int = _EVAL_RECURSION_LIMIT_CACHE[]
  if v < 0
    v = Int(Flags.getConfigInt(Flags.EVAL_RECURSION_LIMIT))
    _EVAL_RECURSION_LIMIT_CACHE[] = v
  end
  return v
end

"""The value of a call of `fn` with evaluated arguments, or `EVAL_FAILED` (messages reported)."""
function evaluate(fn::MODELICA_FUNCTION, args::Vector{Expression})::Expression
  #= A partial derivative is differentiated by the backend, not the function's body (omc). =#
  isPartialDerivative(fn) && return EVAL_FAILED
  return isExternal(fn) ? evaluateExternal(fn, args) : evaluateNormal(fn, args)
end

#= A function's evaluation depth in this task (EVAL_RECURSION_LIMIT), keyed by its call counter,
   which the copies of a function share. The counter itself was shared by the tasks of the
   parallel typing, and its read-then-write updates lost counts: it ended at 2 to 5, not 0, in
   flat models (Buildings' CoolingCoilHumidifyingHeating_ClosedLoop), a drift that would fail an
   evaluation that does not recurse once it reached the limit. =#
@inline function _evalDepths()::IdDict{Any, Int}
  local tls = task_local_storage()
  local d = get(tls, :OMF_EVAL_DEPTHS, nothing)
  if d === nothing
    d = IdDict{Any, Int}()
    tls[:OMF_EVAL_DEPTHS] = d
  end
  return d::IdDict{Any, Int}
end

#= Sets the depth; the entry goes at 0 (the table holds the functions being evaluated). =#
@inline function _setEvalDepth!(depths::IdDict{Any, Int}, counter::Base.RefValue{Int}, depth::Int)::Nothing
  depth > 0 ? (depths[counter] = depth) : delete!(depths, counter)
  return nothing
end

"""
The value of a call of a Modelica function by evaluating its algorithm, or `EVAL_FAILED`: a statement
that does not evaluate, an assert of level error, an output never assigned, the recursion limit.
"""
function evaluateNormal(fn::MODELICA_FUNCTION, args::Vector{Expression})::Expression
  local result::Expression
  local fn_body::Vector{Statement}
  local repl::ReplTree.Tree
  local call_count::Int
  local limit::Int
  local call_counter::Base.RefValue{Int} = fn.callCounter
  local ctrl::FlowControlType
  #= The function's evaluation depth in this task is increased by one at the
     start of each evaluation, and decreased by one when the evalution is
     finished. This is used to limit the number of recursive functions calls. =#
  local depths::IdDict{Any, Int} = _evalDepths()
  call_count = get(depths, call_counter, 0) + 1
  #= An overloaded record constructor called in its own evaluation (`output Complex result =
     Complex(re = re, im = im)` in Complex.'constructor'.fromReal) stays a call, its arguments
     evaluated, as omc's evaluation leaves it (omc OperatorOverloadSum1: the '0' operator). =#
  if call_count > 1 && isNonDefaultRecordConstructor(fn)
    return CALL_EXPRESSION(makeTypedCall(fn, args, Variability.CONSTANT, fn.returnType))
  end
  limit = _evalRecursionLimit()
  if call_count > limit
    _setEvalDepth!(depths, call_counter, 0)
    Error.addSourceMessage(
      Error.EVAL_RECURSION_LIMIT_REACHED,
      list(string(limit), AbsynUtil.pathString(name(fn))),
      InstNode_info(fn.node),
    )
    return EVAL_FAILED
  end
  _setEvalDepth!(depths, call_counter, call_count)
  #= The depth goes back down however the evaluation ends; an exception here is an internal error
     (evalNormalCall turns it into EVAL_FAILED). =#
  try
    fn_body = getBody(fn)
    repl = createReplacements(fn, args)
    fn_body = applyReplacements(repl, fn_body)
    fn_body = optimizeBody(fn_body)
    ctrl = evaluateStatements(fn_body)
    result = (ctrl == FlowControl.ASSERTION || ctrl == FlowControl.FAILURE) ? EVAL_FAILED : createResult(repl, fn.outputs)
  finally
    _setEvalDepth!(depths, call_counter, call_count - 1)
  end
  return result
end

function evaluateExternal(fn::MODELICA_FUNCTION, args::Vector{Expression})::Expression
  local result::Expression

  local name::String
  local lang::String
  local output_ref::ComponentRef
  local ann::Option{SCode.ANNOTATION}
  local ext_args::List{Expression}

  @match SECTIONS_EXTERNAL(
    name = name,
    args = ext_args,
    outputRef = output_ref,
    language = lang,
    ann = ann,
  ) = getSections(getClass(fn.node))
  if lang == "builtin"
    #= TODO: evalfn does not exist yet. This path is for builtin external functions. =#
    _internalError("evaluateExternal: evalfn not implemented for builtin external function: " * name)
    result = EVAL_FAILED
  elseif isKnownExternalFunc(name, ann)
    result = evaluateKnownExternal(name, list(args...))
  elseif (ffi = callExternalFunction(name, fn, args, ext_args, output_ref, ann)) !== nothing
    result = ffi
  else
    result = evaluateExternal2(name, fn, args, ext_args)
    if result isa EVAL_FAILURE
      _internalError("evaluateExternal failed on " * AbsynUtil.pathString(fn.path) *
                     ", evaluation of userdefined external functions not yet implemented")
    end
  end
  #= Functions defined as 'external \"builtin\"', delegate to Ceval.
     External functions that we know how to evaluate without generating code.
     TODO: Move this to EvalFunctionExt and unify evaluateKnownExternal and
     evaluateExternal2. This requires handling of outputRef though.
     External functions that we would need to generate code for and execute. =#
  return result
end

#= An external C function called at compile time (omc callExternalFunction, through libffi): the
   symbol from the process or from the libraries of its Library annotation; scalar Integer, Real,
   Boolean and String arguments and an explicit return value (omc DimUnknown16:
   `external "C" dim = strlen("aa")`). Nothing when the call is not of that form or the symbol is
   not found. =#
function callExternalFunction(name::String, fn::MODELICA_FUNCTION, args::Vector{Expression}, extArgs::List{Expression},
                              outputRef::ComponentRef, ann::Option{SCode.ANNOTATION})::Union{Expression, Nothing}
  isEmpty(outputRef) && return nothing
  local ret_ty = nodeType(outputRef)
  local cret = _externalCType(ret_ty)
  cret === nothing && return nothing
  local vals = Any[]
  local ctys = Any[]
  for a in extArgs
    local v = _externalArgValue(a, fn, args)
    v === nothing && return nothing
    push!(vals, v[1])
    push!(ctys, v[2])
  end
  local ptr = _externalSymbol(name, ann)
  ptr == C_NULL && return nothing
  local r = Core.eval(@__MODULE__, Expr(:call, :ccall, ptr, cret, Expr(:tuple, ctys...), vals...))
  return isInteger(ret_ty) ? INTEGER_EXPRESSION(Int(r)) :
         isReal(ret_ty) ? REAL_EXPRESSION(Float64(r)) :
         isBoolean(ret_ty) ? BOOLEAN_EXPRESSION(r != 0) :
         STRING_EXPRESSION(r == C_NULL ? "" : unsafe_string(r))
end

#= The C type of a scalar of the external interface (Modelica Integer and Boolean are int). =#
function _externalCType(ty::ModelicaType)::Any
  isInteger(ty) && return Cint
  isReal(ty) && return Cdouble
  isBoolean(ty) && return Cint
  isString(ty) && return Cstring
  return nothing
end

#= An external call's argument: a literal, or an input given a literal value. =#
function _externalArgValue(@nospecialize(a::Expression), fn::MODELICA_FUNCTION, args::Vector{Expression})::Union{Tuple{Any, Any}, Nothing}
  local e = a
  if e isa CREF_EXPRESSION
    local k = findfirst(i -> refEqual(i, node(e.cref)), Base.collect(fn.inputs))
    k === nothing && return nothing
    e = args[k]
  end
  e isa INTEGER_EXPRESSION && return (Cint(e.value), Cint)
  e isa REAL_EXPRESSION && return (Float64(e.value), Cdouble)
  e isa BOOLEAN_EXPRESSION && return (Cint(e.value ? 1 : 0), Cint)
  e isa STRING_EXPRESSION && return (e.value, Cstring)
  return nothing
end

#= An external function's symbol: from the libraries its Library annotation names, else the
   process's (libc). =#
function _externalSymbol(name::String, ann::Option{SCode.ANNOTATION})::Ptr{Cvoid}
  local L = Base.Libc.Libdl
  if isSome(ann)
    local mod = SCodeUtil.lookupAnnotationBinding(Util.getOption(ann), "Library")
    for lib in _annotationStrings(mod)
      local h = L.dlopen("lib" * lib, L.RTLD_LAZY; throw_error = false)
      h === nothing && continue
      local p = L.dlsym_e(h, name)
      p == C_NULL || return p
    end
  end
  #= The process's symbols: dlopen(NULL); on Windows the C runtime's. =#
  if Sys.iswindows()
    for crt in ("ucrtbase", "msvcrt")
      local hw = L.dlopen(crt; throw_error = false)
      hw === nothing && continue
      local pw = L.dlsym_e(hw, name)
      pw == C_NULL || return pw
    end
    return C_NULL
  end
  #= jl_dlopen maps Libdl's flags to the native ones (Libdl's RTLD_LAZY is glibc's RTLD_NOLOAD). =#
  local h = ccall(:jl_dlopen, Ptr{Cvoid}, (Ptr{Cvoid}, Cuint), C_NULL, L.RTLD_LAZY)
  h == C_NULL && return C_NULL
  return L.dlsym_e(h, name)
end

function _annotationStrings(omod::Option{Absyn.Exp})::Vector{String}
  isSome(omod) || return String[]
  local mod = Util.getOption(omod)
  mod isa Absyn.STRING && return String[mod.value]
  mod isa Absyn.ARRAY && return String[e.value for e in mod.arrayExp if e isa Absyn.STRING]
  return String[]
end

"""
  Evaluates a default record constructor call by replacing any field references
  with the given arguments, optionally constant evaluating the resulting expression.

  Example:
  record R
  Real x;
  constant Real y = x / 2.0;
  Real z;
  end R;

  CALL(R, {1.0, 2.0}) => RECORD(R, {1.0, 0.5, 2.0});
"""
function evaluateRecordConstructor(
  fn::MODELICA_FUNCTION,
  ty::ModelicaType,
  args::Vector{Expression};
  evaluate::Bool = true,
)::Expression
  local result::Expression
  local repl::ReplTree.Tree
  local arg::Expression
  local fields::List{Field}
  local rest_args::Vector{Expression} = args
  local inputs::List{InstNode} = fn.inputs
  local locals::List{InstNode} = fn.locals
  local node::InstNode
  repl = ReplTree.new()
  fields = recordFields(ty)
  #= Add the inputs and local variables to the replacement tree with their
     respective bindings. =#
  for (j,i) in enumerate(inputs)
    arg = rest_args[j]
    repl = ReplTree.add(repl, i, arg)
  end
  for l in locals
    repl = ReplTree.add(repl, l, getBindingExp(l, repl))
  end
  #=  Apply the replacements to all the variables (`built`, not reassigned: the closure does not box it). =#
  local built::ReplTree.Tree = repl
  repl = ReplTree.map(built, (nodeArg, expArg) -> applyBindingReplacement(nodeArg, expArg, built))
  #= Fetch the new binding expressions for all the variables, both inputs and
     locals. =#
  local expl::Vector{Expression} = Vector(undef, length(fields))
  for (i,f) in enumerate(fields)
    if isInput(f)
      @match node <| inputs = inputs
    else
      @match node <| locals = locals
    end
    e = ReplTree.get(repl, node)
    expl[i] = e
  end
  #=  Create a new record expression from the list of arguments. =#
  result = makeRecord(name(fn), ty, expl)
  #=  Constant evaluate the expression if requested. =#
  if evaluate
    result = evalExp(result)
  end
  return result
end

"""
The replacements of one evaluation of `fn` with the arguments `args`: each input's argument value, each output's
and local's binding in a cell (assignable), with the references among them replaced.
"""
function createReplacements(fn::MODELICA_FUNCTION, args::Vector{Expression})::ReplTree.Tree
  #= MODELICA_FUNCTION is the only MODELICA_FUNCTION: its fields typed =#
  local inputs::List{InstNode} = (fn::MODELICA_FUNCTION).inputs
  local outputs::List{InstNode} = (fn::MODELICA_FUNCTION).outputs
  local locals::List{InstNode} = (fn::MODELICA_FUNCTION).locals
  local repl::ReplTree.Tree = ReplTree.new()
  local arg::Expression
  local j::Int = 0
  #= Add inputs to the replacement tree. Since they can't be assigned to the
     replacements don't need to be mutable. =#
  for i in inputs
    j += 1
    arg = args[j]
    repl = addInputReplacement(i, arg, repl)
    #= A function pointer argument: calls to the parameter's function are calls to it (omc). =#
    if isFunctionPointerExp(arg)
      for pfn in _cachedFuncsOrEmpty(i)
        repl = ReplTree.add(repl, pfn.node, arg)
      end
    end
  end
  #= Add outputs and local variables to the replacement tree. These do need to
     be mutable to allow assigning to them. =#
  for node in outputs
    repl = addMutableReplacement(node, repl)
  end
  for node in locals
    repl = addMutableReplacement(node, repl)
  end
  #= The outputs' and locals' bindings in terms of the inputs and of each other, once all are in the tree. The inputs
     are evaluated arguments (Ceval.evalCall) with nothing to replace; each output and local is a cell whose content
     is replaced in place, so a reference to one is the cell and needs no rescan. =#
  for node in outputs
    _replaceCellContent(ReplTree.get(repl, node), repl)
  end
  for node in locals
    _replaceCellContent(ReplTree.get(repl, node), repl)
  end
  return repl
end

"""
The content of `cell` (a function output's or local's replacement, `addMutableReplacement`) with the replacements
`repl`, in place.
"""
function _replaceCellContent(@nospecialize(cell::Expression), repl::ReplTree.Tree)::Nothing
  local c::MUTABLE_EXPRESSION = cell::MUTABLE_EXPRESSION
  local content::Expression = P_Pointer.access(c.exp)::Expression
  P_Pointer.update(c.exp, map(content, (@nospecialize(expArg::Expression),) -> applyReplacements2(repl, expArg, false)))
  return nothing
end

function addMutableReplacement(node::InstNode, repl::ReplTree.Tree)::ReplTree.Tree

  local repl_exp::Expression

  @assign repl_exp = getBindingExp(node, repl)
  @assign repl_exp = makeMutable(repl_exp)
  @assign repl = ReplTree.add(repl, node, repl_exp)
  return repl
end

function getBindingExp(node::InstNode, repl::ReplTree.Tree)::Expression
  local bindingExp::Expression
  local binding::Binding
  @assign binding = getBinding(component(node))
  if isBound(binding)
    @assign bindingExp = getBindingExp(getExp(binding))
  else
    @assign bindingExp = buildBinding(node, repl)
  end
  return bindingExp
end

function buildBinding(node::InstNode, repl::ReplTree.Tree)::Expression
  local result::Expression
  local ty::ModelicaType
  ty = getType(node)
  ty = mapDims(ty, (expArg) -> applyReplacementsDim(repl, expArg))
  result = begin
    @match ty begin
      TYPE_ARRAY(__) where {(hasKnownSize(ty))} => begin
        #@info "Filling it beause it is an array"
        fillType(
          ty,
          EMPTY_EXPRESSION(arrayElementType(ty)),
        )
      end
      TYPE_COMPLEX(__) => begin
        #@info "It is a complex. Make a record"
        buildRecordBinding(node, repl)
      end
      _ => begin
        #@info "Is empty..."
        EMPTY_EXPRESSION(ty)
      end
    end
  end
  return result
end

function applyReplacementsDim(repl::ReplTree.Tree, dim::Dimension)::Dimension
  dim = begin
    local exp::Expression
    @match dim begin
      DIMENSION_EXP(__) => begin
        exp = map(
          dim.exp,
          (@nospecialize(expArg::Expression),) -> applyReplacements2(repl, expArg, true),
        )
        exp = evalExp(exp)
        fromExp(exp, Variability.CONSTANT)
      end
      _ => begin
        dim
      end
    end
  end
  return dim
end

"""
  Builds a binding for a record instance that doesn't have an explicit binding.
  Binding expressions will be taken from the record fields when available, and
  filled with empty expressions when not.
"""
function buildRecordBinding(recordNode::InstNode, repl::ReplTree.Tree)::Expression
  local result::Expression

  local cls_node::InstNode = classScope(recordNode)
  local cls::Class = getClass(cls_node)
  local comps::Vector{InstNode}
  local bindings::List{Expression}
  local exp::Expression
  local local_repl::ReplTree.Tree
  result = begin
    @match cls begin
      INSTANCED_CLASS(elements = CLASS_TREE_FLAT_TREE(components = comps)) =>
        begin
          bindings = nil
          #= Create a replacement tree for just the record instance. This is
             needed for records that contain local references such as:
             record R
             Real x;
             Real y = x;
             end R;
             In that case we need to replace the 'x' in the binding of 'y' with
             the binding expression of 'x'. =#
          local_repl = ReplTree.new()
          for i = arrayLength(comps):(-1):1
            exp = makeMutable(getBindingExp(comps[i], repl))
            local_repl = ReplTree.add(local_repl, comps[i], exp)
            bindings = Cons{Expression}(exp, bindings)
          end
          #= Add the expression to both the replacement tree and the list of bindings.
             Replace references to record fields with those fields' bindings in the tree.
             This will also update the list of bindings since they share mutable expresions. =#
          ReplTree.map(
            local_repl,
            (nodeArg, expArg) -> applyBindingReplacement(nodeArg, expArg, local_repl),
          )
          makeRecord(
            scopePath(cls_node),
            cls.ty,
            listArray(bindings),
          )
        end

      TYPED_DERIVED(__) => begin
        buildRecordBinding(cls.baseClass, repl)
      end
    end
  end
  return result
end

function addInputReplacement(
  node::InstNode,
  @nospecialize(argument::Expression),
  @nospecialize(repl::ReplTree.Tree),
)::ReplTree.Tree

  #= Passed by value: a record argument must not bring the caller's cells along. =#
  @assign repl = ReplTree.add(repl, node, detachCells(argument))
  return repl
end

function applyBindingReplacement(
  node::InstNode,
  @nospecialize(exp::Expression),
  repl::ReplTree.Tree,
)::Expression
  local outExp::Expression
  outExp =
    map(exp, (@nospecialize(expArg::Expression),) -> applyReplacements2(repl, expArg, true))
  return outExp
end

"""
The function body `fnBody` with the replacements `repl` (complete: `createReplacements`) for its parameters and
locals. A replacement is not rescanned (`applyReplacementCref`).
"""
function applyReplacements(repl::ReplTree.Tree, fnBody::Vector{Statement})::Vector{Statement}
  fnBody = mapExpList(
    fnBody,
    (@nospecialize(x::Expression),) -> map(x, (@nospecialize(expArg::Expression),) -> applyReplacements2(repl, expArg, false)),
  )
  return fnBody
end

"""
`exp` (one node of a bottom-up `map`: its subexpressions are replaced) with the replacement of a cref, a call through
a function pointer, or an unboxed expression. `rescan` (`applyReplacementCref`): the replacements are not yet in
terms of each other.
"""
function applyReplacements2(repl::ReplTree.Tree, @nospecialize(exp::Expression), rescan::Bool)::Expression
  exp = begin
    @match exp begin
      CREF_EXPRESSION(__) => begin
        applyReplacementCref(repl, exp.cref, exp, rescan)
      end
      CALL_EXPRESSION(__) => begin
        applyReplacementCall(repl, exp.call, exp)
      end
      UNBOX_EXPRESSION(__) => begin
        exp.exp
      end
      _ => begin
        exp
      end
    end
  end
  return exp
end

#= A function pointer: a cref to a function, or a function partial application (omc). =#
function isFunctionPointerExp(@nospecialize(exp::Expression))::Bool
  return (exp isa CREF_EXPRESSION && isvariant(exp.ty, TYPE_FUNCTION)) || exp isa PARTIAL_FUNCTION_APPLICATION_EXPRESSION
end

#= The functions cached on a node's class, none when it has no function cache. =#
function _cachedFuncsOrEmpty(node::InstNode)::Vector{MODELICA_FUNCTION}
  local cache = getFuncCache(classScope(node))
  return cache isa C_FUNCTION ? MODELICA_FUNCTION[f for f in cache.funcs] : MODELICA_FUNCTION[]
end

#= A call of a function given as a function pointer argument: a call of the function it points
   to, with the partial application's arguments merged in (omc applyReplacementCall). =#
function applyReplacementCall(repl::ReplTree.Tree, call::Call, @nospecialize(exp::Expression))::Expression
  @match call begin
    TYPED_CALL(__) => begin
      local repl_exp = ReplTree.tryGet(repl, call.fn.node)
      repl_exp === nothing && return exp
      if repl_exp isa CREF_EXPRESSION && isvariant(repl_exp.ty, TYPE_FUNCTION)
        local fn::MODELICA_FUNCTION = functionOf(repl_exp.ty)
        local args = mergeFunctionApplicationArgs(call.fn, call.arguments, fn, Expression[], String[])
        return CALL_EXPRESSION(TYPED_CALL(fn, call.ty, call.var, args, call.attributes))
      elseif repl_exp isa PARTIAL_FUNCTION_APPLICATION_EXPRESSION
        local fn = Base.first(getCachedFuncs(node(repl_exp.fn)))
        local args = mergeFunctionApplicationArgs(call.fn, call.arguments, fn,
                                                  Expression[a for a in repl_exp.args], String[n for n in repl_exp.argNames])
        return CALL_EXPRESSION(TYPED_CALL(fn, call.ty, call.var, args, call.attributes))
      end
      return exp
    end
    _ => begin
      return exp
    end
  end
end

#= The arguments of a call of newFn replacing one of oldFn: newFn's defaults, oldFn's arguments by
   name, then the partial application's named ones (omc mergeFunctionApplicationArgs). =#
function mergeFunctionApplicationArgs(oldFn::MODELICA_FUNCTION, oldArgs::Vector{Expression}, newFn::MODELICA_FUNCTION,
                                      newArgs::Vector{Expression}, argNames::Vector{String})::Vector{Expression}
  local arg_map = Dict{String, Expression}()
  for sl in newFn.slots
    if isSome(sl.default)
      arg_map[sl.name] = unbox(Util.getOption(sl.default))
    end
  end
  for (k, i) in enumerate(oldFn.inputs)
    arg_map[name(i)] = unbox(oldArgs[k])
  end
  for (k, n) in enumerate(argNames)
    arg_map[n] = unbox(newArgs[k])
  end
  return Expression[arg_map[name(i)] for i in newFn.inputs]
end

"""
The replacement of `cref` (its node's, then its record fields' and subscripts'), or `exp` when it has none. With
`rescan`, the replacement's own references are replaced too: needed while the replacements are rewritten in terms of
each other (`applyBindingReplacement`: a binding `z = y + 1` with `y = 2 * x`). A complete replacement (an
evaluated argument, a cell whose content was replaced in place) has nothing left to replace, and `map` replaced the
cref's subscripts before this call, so the function body is rewritten without a rescan: it walked every value again
at each reference (39 k node visits for 1.6 k crefs in MultiBody `Frames.from_nxy`).
"""
function applyReplacementCref(
  repl::ReplTree.Tree,
  cref::ComponentRef,
  @nospecialize(exp::Expression),
  rescan::Bool,
)::Expression
  local outExp::Expression
  local cref_parts::List{ComponentRef}
  local parent::InstNode
  local nodeVar::InstNode
  #=  Explode the cref into a list of parts in reverse order. =#
  @assign cref_parts = toListReverse(cref)
  #= Leading scope qualifiers never carry replacements; the replacement tree
     is keyed on component nodes, so start the lookup at the first CREF part. =#
  while !listEmpty(cref_parts) && listHead(cref_parts).origin == Origin.SCOPE
    cref_parts = listRest(cref_parts)
  end
  #= If the list is empty it's probably an iterator or _, which shouldn't be replaced. =#
  if listEmpty(cref_parts)
    @assign outExp = exp
  else
    @assign parent = node(listHead(cref_parts))
    local repl_exp = ReplTree.tryGet(repl, parent)
    if repl_exp !== nothing
      outExp = repl_exp
    else
      @assign outExp = exp
      return outExp
    end
    @assign outExp = applySubscripts(
      getSubscripts(listHead(cref_parts)),
      outExp,
    )
    @assign cref_parts = listRest(cref_parts)
    if !listEmpty(cref_parts)
      try
        for cr in cref_parts
          @assign nodeVar = node(cr)
          @assign outExp = makeImmutable(outExp)
          @assign outExp =
            recordElement(name(nodeVar), outExp)
          @assign outExp = applySubscripts(
            getSubscripts(cr),
            outExp,
          )
        end
      catch
        Error.assertion(
          false,
          getInstanceName() +
          " could not find replacement for " +
          toString(cref),
          sourceInfo(),
        )
      end
    end
    if rescan
      outExp = map(outExp, (@nospecialize(expArg::Expression),) -> applyReplacements2(repl, expArg, true))
    end
  end
  #= Look up the replacement for the first part in the replacement tree.
     If the cref consists of more than one identifier we need to look up
     the corresponding record field in the expression. =#
  return outExp
end

function optimizeBody(body::Vector{Statement})
  body = Statement[map(s, optimizeStatement) for s in body]
  return body
end

function optimizeStatement(stmt::Statement)::Statement
  () = begin
    local iter_exp::Expression
    #= Replace iterators in for loops with mutable expressions, so we don't need
       to do it each time we enter a for loop during evaluation. =#
    @match stmt begin
      ALG_FOR(__) => begin
        #=  Make a mutable expression with a placeholder value. =#
        iter_exp = makeMutable(EMPTY_EXPRESSION(TYPE_UNKNOWN()))
        #=  Replace the iterator with the expression in the body of the for loop. =#
        @assign stmt.body = replaceIteratorList(stmt.body, stmt.iterator, iter_exp)
        #=  Replace the iterator node with the mutable expression too. =#
        @assign stmt.iterator = EXP_NODE(iter_exp)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return stmt
end

function createResult(repl::ReplTree.Tree, outputs::List{<:InstNode})::Expression
  local exp::Expression
  local expl::List{Expression}
  local types::List{ModelicaType}
  local e::Expression
  #= The outputs as values, their cells detached (OpenModelica evaluates the fields): a
     record output's fields stayed cells, and one never assigned (MSL Spice3's
     diodeCalcTempDependencies sets m_tBrkdwnV only for a given breakdown voltage) was not
     seen as empty where the binding is split, then reached the flat model as #EMPTY#. =#
  local target::EvalTarget = EVALTARGET_IGNORE_ERRORS()
  if listLength(outputs) == 1
    exp = _evalStmtExp(ReplTree.get(repl, listHead(outputs)), target)
    exp isa EVAL_FAILURE && return exp
    exp = detachCells(exp)
    (exp isa EVAL_FAILURE || !assertAssignedOutput(listHead(outputs), exp)) && return EVAL_FAILED
  else
    expl = nil
    types = nil
    for o in outputs
      e = _evalStmtExp(ReplTree.get(repl, o), target)
      e isa EVAL_FAILURE && return e
      e = detachCells(e)
      (e isa EVAL_FAILURE || !assertAssignedOutput(o, e)) && return EVAL_FAILED
      expl = Cons{Expression}(e, expl)
    end
    expl = listReverseInPlace(expl)
    types = list(typeOf(e) for e in expl)
    exp = TUPLE_EXPRESSION(TYPE_TUPLE(types, NONE()), expl)
  end
  return exp
end

"""Whether an output was assigned; reports UNASSIGNED_FUNCTION_OUTPUT when it was not."""
function assertAssignedOutput(outputNode::InstNode, @nospecialize(value::Expression))::Bool
  value isa EMPTY_EXPRESSION || return true
  Error.addSourceMessage(Error.UNASSIGNED_FUNCTION_OUTPUT, list(name(outputNode)), InstNode_info(outputNode))
  return false
end

function evaluateStatements(stmts::Vector{Statement})
  local ctrl::FlowControlType = FlowControl.NEXT
  for s in stmts
    ctrl = evaluateStatement(s)
    if ctrl != FlowControl.NEXT
      if ctrl == FlowControl.CONTINUE
        ctrl = FlowControl.NEXT
      end
      break
    end
  end
  return ctrl
end

function evaluateStatement(stmt::Statement)::FlowControlType
  local ctrl::FlowControlType
  #= adrpo: we really need some error handling here to detect which statement cannot be evaluated
     try =#
  @assign ctrl = begin
    @match stmt begin
      ALG_ASSIGNMENT(__) => begin
        evaluateAssignment(stmt.lhs, stmt.rhs, stmt.source)
      end

      ALG_FOR(__) => begin
        evaluateFor(stmt.iterator, stmt.range, stmt.body, stmt.source)
      end

      ALG_IF(__) => begin
        evaluateIf(stmt.branches, stmt.source)
      end

      ALG_ASSERT(__) => begin
        evaluateAssert(stmt.condition, stmt)
      end

      ALG_NORETCALL(__) => begin
        evaluateNoRetCall(stmt.exp, stmt.source)
      end

      ALG_WHILE(__) => begin
        evaluateWhile(stmt.condition, stmt.body, stmt.source)
      end

      ALG_RETURN(__) => begin
        FlowControl.RETURN
      end

      ALG_BREAK(__) => begin
        FlowControl.BREAK
      end

      _ => begin
        _internalError("evaluateStatement failed on " * anyString(stmt))
        FlowControl.FAILURE
      end
    end
  end
  return ctrl
end

"""`lhs := rhs`; FAILURE when rhs does not evaluate or lhs cannot be assigned."""
function evaluateAssignment(
  @nospecialize(lhsExp::Expression),
  @nospecialize(rhsExp::Expression),
  source::SourceInfo,
)::FlowControlType
  local value::Expression = _evalStmtExp(rhsExp, EVALTARGET_STATEMENT(source))
  value isa EVAL_FAILURE && return FlowControl.FAILURE
  value = detachCells(value)
  value isa EVAL_FAILURE && return FlowControl.FAILURE
  return assignVariable(lhsExp, value) ? FlowControl.NEXT : FlowControl.FAILURE
end

"""
  The value with the variable cells in it replaced by their current values: cells
  at the top, in records, and in arrays and tuples of them (not cells nested in
  other expressions). A record variable evaluates to a record of its field cells;
  stored or passed as it is, the target would share those cells (`r2 := r1;
  r1.x := 7` would change r2.x). A cell is read without writing its value back
  into it; `EVAL_FAILED` when a cell's value does not evaluate.
"""
function detachCells(@nospecialize(exp::Expression))::Expression
  if exp isa MUTABLE_EXPRESSION
    local v::Expression = _evalStmtExp(P_Pointer.access(exp.exp), EVALTARGET_IGNORE_ERRORS())
    return v isa EVAL_FAILURE ? v : detachCells(v)
  elseif exp isa RECORD_EXPRESSION
    local relems::Vector{Expression} = detachElements(exp.elements)
    anyFailed(relems) && return EVAL_FAILED
    return relems === exp.elements ? exp : RECORD_EXPRESSION(exp.path, exp.ty, relems)
  elseif exp isa ARRAY_EXPRESSION && (!exp.literal || isComplex(arrayElementType(exp.ty)))
    #= An evaluated array is marked literal even when its records hold cells. =#
    local aelems::Vector{Expression} = detachElements(exp.elements)
    anyFailed(aelems) && return EVAL_FAILED
    return aelems === exp.elements ? exp : ARRAY_EXPRESSION(exp.ty, aelems, exp.literal)
  elseif exp isa TUPLE_EXPRESSION
    local telems::List{Expression} = ListUtil.map(exp.elements, detachCells, Expression)
    anyFailed(telems) && return EVAL_FAILED
    return all(referenceEq(d, e) for (d, e) in zip(telems, exp.elements)) ? exp : TUPLE_EXPRESSION(exp.ty, telems)
  end
  return exp
end

#= The elements with their cells detached; the same vector when none held a cell (an element can be
   EVAL_FAILED: the caller checks). =#
"""Whether one of the expressions failed to evaluate (`EVAL_FAILURE`)."""
function anyFailed(elems::Vector{Expression})::Bool
  for e in elems
    e isa EVAL_FAILURE && return true
  end
  return false
end

function anyFailed(elems::List{Expression})::Bool
  for e in elems
    e isa EVAL_FAILURE && return true
  end
  return false
end

function detachElements(elems::Vector{Expression})::Vector{Expression}
  local out::Vector{Expression} = elems
  for (i, e) in enumerate(elems)
    local d::Expression = detachCells(e)
    if !referenceEq(d, e)
      if out === elems
        out = copy(elems)
      end
      out[i] = d
    end
  end
  return out
end

"""`variable := value` (a cell, a tuple of them, a subscripted cell, or `_`); false when it cannot be assigned."""
function assignVariable(@nospecialize(variable::Expression), @nospecialize(value::Expression))::Bool
  if variable isa MUTABLE_EXPRESSION
    local new_val::Expression = assignExp(P_Pointer.access(variable.exp), value)
    new_val isa EVAL_FAILURE && return false
    P_Pointer.update(variable.exp, new_val)
    return true
  elseif variable isa TUPLE_EXPRESSION && value isa TUPLE_EXPRESSION &&
         listLength(value.elements) >= listLength(variable.elements)
    #= (var1, var2, ...) := (value1, value2, ...) =#
    for (var, val) in zip(variable.elements, value.elements)
      assignVariable(var, val) || return false
    end
    return true
  elseif variable isa SUBSCRIPTED_EXP_EXPRESSION && variable.exp isa MUTABLE_EXPRESSION
    #= variable[subscript1, subscript2, ...] := value =#
    return assignSubscriptedVariable(variable.exp.exp, variable.subscripts, value)
  elseif variable isa CREF_EXPRESSION && variable.cref isa COMPONENT_REF_WILD
    return true
  end
  _internalError("assignVariable failed on " * toString(variable) * " := " * toString(value))
  return false
end

"""`variable[subscripts] := value`; false when a subscript does not evaluate or the case is not supported."""
function assignSubscriptedVariable(
  variable::Pointer{<:Expression},
  subscripts::List{<:Subscript},
  @nospecialize(value::Expression),
)::Bool
  local target::EvalTarget = EVALTARGET_IGNORE_ERRORS()
  local subs::List{Subscript} = nil
  for s in subscripts
    if s isa SUBSCRIPT_INDEX || s isa SUBSCRIPT_SLICE
      local e::Expression = _evalStmtExp(s isa SUBSCRIPT_INDEX ? s.index : s.slice, target)
      e isa EVAL_FAILURE && return false
      subs = Cons{Subscript}(s isa SUBSCRIPT_INDEX ? SUBSCRIPT_INDEX(e) : SUBSCRIPT_SLICE(e), subs)
    else
      subs = Cons{Subscript}(s, subs)
    end
  end
  local new_val::Expression = assignArrayElement(P_Pointer.access(variable), listReverseInPlace(subs), value)
  new_val isa EVAL_FAILURE && return false
  P_Pointer.update(variable, new_val)
  return true
end

"""
The array `arrayExp` with the element at `subscripts` set to `value` (index, slice and whole subscripts, nested
for the rest), copied, not updated in place: the element vector can be shared with other arrays (fillType and
fill() repeat one row, and `y := x` shares x's elements, which may be a literal array from an argument or a
constant's binding). `EVAL_FAILED` for another case or an array that does not evaluate.
"""
function assignArrayElement(
  @nospecialize(arrayExp::Expression),
  subscripts::List{<:Subscript},
  @nospecialize(value::Expression),
)::Expression
  #= A variable's binding (fill(0.0, n), zeros(n)) is not evaluated when its cell is made:
     the element assignment needs the array (Buildings.Fluid.Movers.BaseClasses.Euler). =#
  if !(arrayExp isa ARRAY_EXPRESSION)
    arrayExp = _evalStmtExp(arrayExp, EVALTARGET_IGNORE_ERRORS())
    arrayExp isa EVAL_FAILURE && return arrayExp
  end
  if arrayExp isa ARRAY_EXPRESSION && !listEmpty(subscripts)
    local sub::Subscript = listHead(subscripts)
    local rest_subs::List{Subscript} = listRest(subscripts)
    local elems::Vector{Expression}
    if sub isa SUBSCRIPT_INDEX && isScalarLiteral(sub.index)
      elems = copy(arrayExp.elements)
      local idx::Int = toInteger(sub.index)
      elems[idx] = listEmpty(rest_subs) ? value : assignArrayElement(elems[idx], rest_subs, value)
      elems[idx] isa EVAL_FAILURE && return EVAL_FAILED
      return ARRAY_EXPRESSION(arrayExp.ty, elems, arrayExp.literal)
    elseif sub isa SUBSCRIPT_SLICE
      local subsV::Vector{Expression} = arrayElements(sub.slice)
      local valsV::Vector{Expression} = arrayElements(value)
      elems = copy(arrayExp.elements)
      for (i, s) in enumerate(subsV)
        local sidx::Int = toInteger(s)
        elems[sidx] = listEmpty(rest_subs) ? valsV[i] : assignArrayElement(elems[sidx], rest_subs, valsV[i])
        elems[sidx] isa EVAL_FAILURE && return EVAL_FAILED
      end
      return ARRAY_EXPRESSION(arrayExp.ty, elems, arrayExp.literal)
    elseif sub isa SUBSCRIPT_WHOLE
      local valElems::Vector{Expression} = arrayElements(value)
      if listEmpty(rest_subs)
        elems = valElems
      else
        elems = Vector{Expression}(undef, length(arrayExp.elements))
        for i in eachindex(arrayExp.elements)
          elems[i] = assignArrayElement(arrayExp.elements[i], rest_subs, valElems[i])
        end
        anyFailed(elems) && return EVAL_FAILED
      end
      return ARRAY_EXPRESSION(arrayExp.ty, elems, arrayExp.literal)
    end
  end
  _internalError("assignArrayElement: unimplemented case for " * toString(arrayExp) * toStringList(subscripts) *
                 " = " * toString(value))
  return EVAL_FAILED
end

"""The value of a variable after `lhs := rhs`: a record's fields assigned one by one, else `rhs`."""
function assignExp(@nospecialize(lhs::Expression), @nospecialize(rhs::Expression))::Expression
  #= TODO: Handle arrays. =#
  return lhs isa RECORD_EXPRESSION ? assignRecord(lhs, rhs) : rhs
end

"""
`lhs := rhs` for a record of field cells: from a record value field by field, from a record cref by its
fields' crefs; `EVAL_FAILED` when a field cannot be assigned.
"""
function assignRecord(lhs::RECORD_EXPRESSION, @nospecialize(rhs::Expression))::Expression
  local elems::Vector{Expression} = lhs.elements
  if rhs isa RECORD_EXPRESSION
    for (i, v) in enumerate(rhs.elements)
      assignVariable(elems[i], v) || return EVAL_FAILED
    end
    return lhs
  elseif rhs isa CREF_EXPRESSION
    local comps::Vector{InstNode} = getComponents(classTree(getClass(node(rhs.cref))))
    for (i, c) in enumerate(comps)
      local ty::ModelicaType = getType(c)
      local val::Expression = CREF_EXPRESSION(liftArrayLeftList(ty, arrayDims(rhs.ty)), prefixCref(c, ty, nil, rhs.cref))
      assignVariable(elems[i], val) || return EVAL_FAILED
    end
    return lhs
  end
  return rhs
end

"""
A for statement: the body for each value of the range, until a break, return, assertion or failure;
`FlowControl.FAILURE` when the range does not evaluate or the loop limit is reached.
"""
function evaluateFor(
  iterator::InstNode,
  range::Option,
  forBody::Vector{Statement},
  source::SourceInfo,
)::FlowControlType
  local ctrl::FlowControlType = FlowControl.NEXT
  local limit::Int = Flags.getConfigInt(Flags.EVAL_LOOP_LIMIT)
  local range_exp::Expression = _evalStmtExp(Util.getOption(range), EVALTARGET_STATEMENT(source))
  range_exp isa EVAL_FAILURE && return FlowControl.FAILURE
  local range_iter::RangeIterator = RangeIterator_fromExp(range_exp)
  hasNext(range_iter) || return ctrl
  local it::Expression = iterator.exp
  local iter_exp::Pointer{Expression} = (it::MUTABLE_EXPRESSION).exp
  local value::Expression
  local i::Int = 0
  while hasNext(range_iter)
    (range_iter, value) = next(range_iter)
    #= Update the mutable expression with the iteration value and evaluate the statement. =#
    P_Pointer.update(iter_exp, value)
    ctrl = evaluateStatements(forBody)
    if ctrl != FlowControl.NEXT
      ctrl == FlowControl.BREAK && (ctrl = FlowControl.NEXT)
      break
    end
    i += 1
    if i > limit
      Error.addSourceMessage(Error.EVAL_LOOP_LIMIT_REACHED, list(string(limit)), source)
      return FlowControl.FAILURE
    end
  end
  return ctrl
end

"""The body of the first branch whose condition is true; `FlowControl.FAILURE` when a condition does not evaluate."""
function evaluateIf(
  branches::Vector{Tuple{Expression, Vector{Statement}}},
  source::SourceInfo,
)::FlowControlType
  local target::EvalTarget = EVALTARGET_STATEMENT(source)
  for (cond, body) in branches
    local c::Expression = _evalStmtExp(cond, target)
    c isa EVAL_FAILURE && return FlowControl.FAILURE
    isTrue(c) && return evaluateStatements(body)
  end
  return FlowControl.NEXT
end

"""
An assert statement: a warning goes on, an error is `FlowControl.ASSERTION`; `FlowControl.FAILURE` when the
condition, message or level does not evaluate.
"""
function evaluateAssert(@nospecialize(condition::Expression), assertStmt::Statement)::FlowControlType
  local target::EvalTarget = EVALTARGET_STATEMENT(assertStmt.source)
  local cond::Expression = _evalStmtExp(condition, target)
  cond isa EVAL_FAILURE && return FlowControl.FAILURE
  isFalse(cond) || return FlowControl.NEXT
  local msgExp::Expression = assertStmt.message
  local lvlExp::Expression = assertStmt.level
  local msg::Expression = _evalStmtExp(msgExp, target)
  msg isa EVAL_FAILURE && return FlowControl.FAILURE
  local lvl::Expression = _evalStmtExp(lvlExp, target)
  lvl isa EVAL_FAILURE && return FlowControl.FAILURE
  if msg isa STRING_EXPRESSION && lvl isa ENUM_LITERAL_EXPRESSION
    if lvl.name == "warning"
      Error.addSourceMessage(Error.ASSERT_TRIGGERED_WARNING, list(msg.value), assertStmt.source)
      return FlowControl.NEXT
    elseif lvl.name == "error"
      Error.addSourceMessage(Error.ASSERT_TRIGGERED_ERROR, list(msg.value), assertStmt.source)
      return FlowControl.ASSERTION
    end
  end
  _internalError("evaluateAssert failed to evaluate assert(false, " * toString(msg) * ", " * toString(lvl) * ")")
  return FlowControl.FAILURE
end

"""A call statement without results; `FlowControl.FAILURE` when the call does not evaluate."""
function evaluateNoRetCall(@nospecialize(callExp::Expression), source::SourceInfo)::FlowControlType
  local r::Expression = evalExp_impl(callExp, EVALTARGET_STATEMENT(source))
  return r isa EVAL_FAILURE ? FlowControl.FAILURE : FlowControl.NEXT
end

"""
A while statement: the body while the condition is true, until a break, return, assertion or failure;
`FlowControl.FAILURE` when the condition does not evaluate or the loop limit is reached.
"""
function evaluateWhile(
  @nospecialize(condition::Expression),
  body::Vector{Statement},
  source::SourceInfo,
)::FlowControlType
  local ctrl::FlowControlType = FlowControl.NEXT
  local i::Int = 0
  local limit::Int = Flags.getConfigInt(Flags.EVAL_LOOP_LIMIT)
  local target::EvalTarget = EVALTARGET_STATEMENT(source)
  while true
    local c::Expression = _evalStmtExp(condition, target)
    c isa EVAL_FAILURE && return FlowControl.FAILURE
    isTrue(c) || break
    ctrl = evaluateStatements(body)
    if ctrl != FlowControl.NEXT
      ctrl == FlowControl.BREAK && (ctrl = FlowControl.NEXT)
      break
    end
    i += 1
    if i > limit
      Error.addSourceMessage(Error.EVAL_LOOP_LIMIT_REACHED, list(string(limit)), source)
      return FlowControl.FAILURE
    end
  end
  return ctrl
end

function isKnownExternalFunc(name::String, ann::Option{<:SCode.ANNOTATION})::Bool
  local isKnown::Bool

  if isKnownLibrary(ann)
    @assign isKnown = true
  else
    @assign isKnown = begin
      @match name begin
        "OpenModelica_regex" => begin
          true
        end

        _ => begin
          false
        end
      end
    end
  end
  return isKnown
end

function isKnownLibrary(extAnnotation::Option{<:SCode.ANNOTATION})::Bool
  local isKnown::Bool = false

  local ann::SCode.ANNOTATION
  local oexp::Option{Absyn.Exp}

  if isSome(extAnnotation)
    @match SOME(ann) = extAnnotation
    @assign oexp =
      SCodeUtil.getModifierBinding(SCodeUtil.lookupNamedAnnotation(ann, "Library"))
    if isSome(oexp)
      @assign isKnown = isKnownLibraryExp(Util.getOption(oexp))
    end
  end
  return isKnown
end

function isKnownLibraryExp(exp::Absyn.Exp)::Bool
  local isKnown::Bool

  @assign isKnown = begin
    @match exp begin
      Absyn.STRING("ModelicaExternalC") => begin
        true
      end

      Absyn.STRING("ModelicaIO") => begin
        true
      end

      Absyn.ARRAY(__) => begin
        ListUtil.exist(exp.arrayExp, isKnownLibraryExp)
      end

      _ => begin
        false
      end
    end
  end
  return isKnown
end

const FILE_TYPE_NAMES = list("NoFile", "RegularFile", "Directory", "SpecialFile")::List
const FILE_TYPE_PATH =
  Absyn.QUALIFIED(
    "Modelica",
    Absyn.QUALIFIED(
      "Utilities",
      Absyn.QUALIFIED("Types", Absyn.IDENT("FileType")),
    ),
  )::Absyn.Path
const FILE_TYPE_TYPE = TYPE_ENUMERATION(FILE_TYPE_PATH, FILE_TYPE_NAMES)::ModelicaType
const FILE_TYPE_LITERALS =
  list(
    ENUM_LITERAL_EXPRESSION(FILE_TYPE_TYPE, "NoFile", 1),
    ENUM_LITERAL_EXPRESSION(FILE_TYPE_TYPE, "RegularFile", 2),
    ENUM_LITERAL_EXPRESSION(FILE_TYPE_TYPE, "Directory", 3),
    ENUM_LITERAL_EXPRESSION(FILE_TYPE_TYPE, "SpecialFile", 4),
  )::List
const COMPARE_NAMES = list("Less", "Equal", "Greater")::List
const COMPARE_PATH =
  Absyn.QUALIFIED(
    "Modelica",
    Absyn.QUALIFIED(
      "Utilities",
      Absyn.QUALIFIED("Types", Absyn.IDENT("Compare")),
    ),
  )::Absyn.Path
const COMPARE_TYPE = TYPE_ENUMERATION(COMPARE_PATH, COMPARE_NAMES)::ModelicaType
const COMPARE_LITERALS =
  list(
    ENUM_LITERAL_EXPRESSION(COMPARE_TYPE, "Less", 1),
    ENUM_LITERAL_EXPRESSION(COMPARE_TYPE, "Equal", 2),
    ENUM_LITERAL_EXPRESSION(COMPARE_TYPE, "Greater", 3),
  )::List

function evaluateKnownExternal(name::String, args::List{<:Expression})::Expression
  local result::Expression
  @assign result = begin
    local s1::String
    local s2::String
    local i::Int
    local i2::Int
    local b::Bool
    local r::AbstractFloat
    local dims::Vector{Int}
    @match (name, args) begin
      ("ModelicaInternal_countLines", STRING_EXPRESSION(s1) <| nil()) =>
        begin
          INTEGER_EXPRESSION(ModelicaExternalC.Streams_countLines(s1))
        end

      ("ModelicaInternal_fullPathName", STRING_EXPRESSION(s1) <| nil()) =>
        begin
          STRING_EXPRESSION(ModelicaExternalC.File_fullPathName(s1))
        end

      (
        "ModelicaInternal_print",
        STRING_EXPRESSION(s1) <| STRING_EXPRESSION(s2) <| nil(),
      ) => begin
        ModelicaExternalC.Streams_print(s1, s2)
        INTEGER_EXPRESSION(0)
      end

      (
        "ModelicaInternal_readLine",
        STRING_EXPRESSION(s1) <| INTEGER_EXPRESSION(i) <| nil(),
      ) => begin
         (s1, b) = ModelicaExternalC.Streams_readLine(s1, i)
        TUPLE_EXPRESSION(
          TYPE_TUPLE(list(TYPE_STRING(), TYPE_BOOLEAN()), NONE()),
          list(STRING_EXPRESSION(s1), BOOLEAN_EXPRESSION(b)),
        )
      end

      ("ModelicaInternal_stat", STRING_EXPRESSION(s1) <| nil()) => begin
        @assign i = ModelicaExternalC.File_stat(s1)
        listGet(FILE_TYPE_LITERALS, i)
      end

      ("ModelicaStreams_closeFile", STRING_EXPRESSION(s1) <| nil()) => begin
        ModelicaExternalC.Streams_close(s1)
        INTEGER_EXPRESSION(0)
      end

      (
        "ModelicaStrings_compare",
        STRING_EXPRESSION(s1) <|
        STRING_EXPRESSION(s2) <| BOOLEAN_EXPRESSION(b) <| nil(),
      ) => begin
        @assign i = ModelicaExternalC.Strings_compare(s1, s2, b)
        listGet(COMPARE_LITERALS, i)
      end

      ("ModelicaStrings_length", STRING_EXPRESSION(s1) <| nil()) => begin
        INTEGER_EXPRESSION(stringLength(s1))
      end

      (
        "ModelicaStrings_scanReal",
        STRING_EXPRESSION(s1) <|
        INTEGER_EXPRESSION(i) <| BOOLEAN_EXPRESSION(b) <| nil(),
      ) => begin
         (i, r) = ModelicaExternalC.Strings_scanReal(s1, i, b)
        TUPLE_EXPRESSION(
          TYPE_TUPLE(list(TYPE_INTEGER(), TYPE_REAL()), NONE()),
          list(INTEGER_EXPRESSION(i), REAL_EXPRESSION(r)),
        )
      end

      (
        "ModelicaStrings_scanInteger",
        STRING_EXPRESSION(s1) <|
        INTEGER_EXPRESSION(i) <| BOOLEAN_EXPRESSION(b) <| nil(),
      ) => begin
         (i, i2) = ModelicaExternalC.Strings_scanInteger(s1, i, b)
        TUPLE_EXPRESSION(
          TYPE_TUPLE(list(TYPE_INTEGER(), TYPE_INTEGER()), NONE()),
          list(INTEGER_EXPRESSION(i), INTEGER_EXPRESSION(i2)),
        )
      end

      (
        "ModelicaStrings_scanString",
        STRING_EXPRESSION(s1) <| INTEGER_EXPRESSION(i) <| nil(),
      ) => begin
         (i, s2) = ModelicaExternalC.Strings_scanString(s1, i)
        TUPLE_EXPRESSION(
          TYPE_TUPLE(list(TYPE_INTEGER(), TYPE_STRING()), NONE()),
          list(INTEGER_EXPRESSION(i), STRING_EXPRESSION(s2)),
        )
      end

      (
        "ModelicaStrings_scanIdentifier",
        STRING_EXPRESSION(s1) <| INTEGER_EXPRESSION(i) <| nil(),
      ) => begin
         (i, s2) = ModelicaExternalC.Strings_scanIdentifier(s1, i)
        TUPLE_EXPRESSION(
          TYPE_TUPLE(list(TYPE_INTEGER(), TYPE_STRING()), NONE()),
          list(INTEGER_EXPRESSION(i), STRING_EXPRESSION(s2)),
        )
      end

      (
        "ModelicaStrings_skipWhiteSpace",
        STRING_EXPRESSION(s1) <| INTEGER_EXPRESSION(i) <| nil(),
      ) => begin
        INTEGER_EXPRESSION(ModelicaExternalC.Strings_skipWhiteSpace(s1, i))
      end

      (
        "ModelicaStrings_substring",
        STRING_EXPRESSION(s1) <|
        INTEGER_EXPRESSION(i) <| INTEGER_EXPRESSION(i2) <| nil(),
      ) => begin
        STRING_EXPRESSION(System.substring(s1, i, i2))
      end

      ("ModelicaStrings_hashString", STRING_EXPRESSION(s1) <| nil()) => begin
        INTEGER_EXPRESSION(ModelicaExternalC.Strings_hashString(s1))
      end

      ("OpenModelica_regex", _) => begin
        evaluateOpenModelicaRegex(args)
      end

      (
        "ModelicaIO_readMatrixSizes",
        STRING_EXPRESSION(s1) <| STRING_EXPRESSION(s2) <| nil(),
      ) => begin
        dims = ModelicaExternalC.ModelicaIO_readMatrixSizes(s1, s2)
        ARRAY_EXPRESSION(
          TYPE_ARRAY(TYPE_INTEGER(), list(fromInteger(2))),
          Expression[
            INTEGER_EXPRESSION(dims[1]),
            INTEGER_EXPRESSION(dims[2]),
          ],
          true,
        )
      end

      (
        "ModelicaIO_readRealMatrix",
        STRING_EXPRESSION(s1) <|
        STRING_EXPRESSION(s2) <|
        INTEGER_EXPRESSION(i) <|
        INTEGER_EXPRESSION(i2) <| BOOLEAN_EXPRESSION(b) <| nil(),
      ) => begin
        evaluateModelicaIO_readRealMatrix(s1, s2, i, i2, b)
      end

      _ => begin
        _internalError("evaluateKnownExternal: failed to evaluate " * name)
        EVAL_FAILED
      end
    end
  end
  return result
end

function evaluateOpenModelicaRegex(args::List{<:Expression})::Expression
  local result::Expression

  local n::Int
  local i::Int
  local str::String
  local re::String
  local extended::Bool
  local insensitive::Bool
  local strs::List{String}
  local expl::List{Expression}
  local strs_ty::ModelicaType
  local strs_exp::Expression

  @assign result = begin
    @match args begin
      STRING_EXPRESSION(str) <|
      STRING_EXPRESSION(re) <|
      INTEGER_EXPRESSION(i) <|
      BOOLEAN_EXPRESSION(extended) <|
      BOOLEAN_EXPRESSION(insensitive) <| nil() => begin
         (n, strs) = System.regex(str, re, i, extended, insensitive)
        @assign expl = list(STRING_EXPRESSION(s) for s in strs)
        @assign strs_ty =
          TYPE_ARRAY(TYPE_STRING(), list(fromInteger(i)))
        @assign strs_exp = makeArray(strs_ty, expl; literal=true)
        TUPLE_EXPRESSION(
          TYPE_TUPLE(list(TYPE_INTEGER(), strs_ty), NONE()),
          list(INTEGER_EXPRESSION(n), strs_exp),
        )
      end

      _ => begin
        _internalError("evaluateOpenModelicaRegex: failed on OpenModelica_regex" *
                       ListUtil.toString(args, toString, "", "(", ", ", ")", true))
        EVAL_FAILED
      end
    end
  end
  return result
end

function evaluateModelicaIO_readRealMatrix(
  fileName::String,
  matrixName::String,
  nrow::Int,
  ncol::Int,
  verboseRead::Bool,
)::Expression
  local result::Expression

  local matrix::Matrix{Float64}
  local ty::ModelicaType

  @assign matrix = ModelicaExternalC.ModelicaIO_readRealMatrix(
    fileName,
    matrixName,
    nrow,
    ncol,
    verboseRead,
  )
  @assign ty = TYPE_ARRAY(TYPE_REAL(), list(fromInteger(ncol)))
  local rowsV = Expression[]
  for r = 1:nrow
    local rowV = Expression[REAL_EXPRESSION(matrix[r, c]) for c in 1:ncol]
    push!(rowsV, ARRAY_EXPRESSION(ty, rowV, literal = true))
  end
  @assign ty = liftArrayLeft(ty, fromInteger(nrow))
  @assign result = ARRAY_EXPRESSION(ty, rowsV, literal = true)
  return result
end

function evaluateExternal2(
  name::String,
  fn::MODELICA_FUNCTION,
  args::Vector{Expression},
  extArgs::List{<:Expression},
)::Expression
  local result::Expression

  local repl::ReplTree.Tree
  local ext_args::List{Expression}

  @assign repl = createReplacements(fn, args)
  @assign ext_args = list(
    map(e, (@nospecialize(subexp::Expression),) -> applyReplacements2(repl, subexp, false))
    for e in extArgs
  )
  evaluateExternal3(name, ext_args) || return EVAL_FAILED
  @assign result = createResult(repl, fn.outputs)
  return result
end

"""Evaluates the LAPACK routine `name` on `args` (its outputs are cells); false for another name."""
function evaluateExternal3(name::String, args::List{<:Expression})::Bool
  @match name begin
    "dgeev" => (Lapack_dgeev(args); true)
    "dgegv" => (Lapack_dgegv(args); true)
    "dgels" => (Lapack_dgels(args); true)
    "dgelsx" => (Lapack_dgelsx(args); true)
    "dgelsy" => (Lapack_dgelsy(args); true)
    "dgesv" => (Lapack_dgesv(args); true)
    "dgglse" => (Lapack_dgglse(args); true)
    "dgtsv" => (Lapack_dgtsv(args); true)
    "dgbsv" => (Lapack_dgbsv(args); true)
    "dgesvd" => (Lapack_dgesvd(args); true)
    "dgetrf" => (Lapack_dgetrf(args); true)
    "dgetrs" => (Lapack_dgetrs(args); true)
    "dgetri" => (Lapack_dgetri(args); true)
    "dgeqpf" => (Lapack_dgeqpf(args); true)
    "dorgqr" => (Lapack_dorgqr(args); true)
    "dhseqr" => (Lapack_dhseqr(args); true)
    _ => false
  end
end

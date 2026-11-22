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

@UniontypeDecl EvalTarget
@Uniontype EvalTarget begin
  @Record EVALTARGET_IGNORE_ERRORS begin
  end

  @Record EVALTARGET_STATEMENT begin
    source::SourceInfo
  end

  @Record EVALTARGET_GENERIC begin
    info::SourceInfo
  end

  @Record EVALTARGET_CONDITION begin
    info::SourceInfo
  end

  @Record EVALTARGET_RANGE begin
    info::SourceInfo
  end

  @Record EVALTARGET_ATTRIBUTE begin
    binding::Binding
  end

  @Record EVALTARGET_DIMENSION begin
    component::InstNode
    index::Int
    exp::Expression
    info::SourceInfo
  end
end

"""The source position of an evaluation (for its messages); a dummy one when errors are ignored."""
function EvalTarget_getInfo(@nospecialize(target::EvalTarget))::SourceInfo
  target isa EVALTARGET_ATTRIBUTE && return Binding_getInfo(target.binding)
  target isa EVALTARGET_STATEMENT && return target.source
  target isa EVALTARGET_IGNORE_ERRORS && return AbsynUtil.dummyInfo
  target isa EVALTARGET_DIMENSION && return target.info
  target isa EVALTARGET_RANGE && return target.info
  target isa EVALTARGET_CONDITION && return target.info
  return (target::EVALTARGET_GENERIC).info
end

"""Whether the evaluation reports errors at a source position: every target except EVALTARGET_IGNORE_ERRORS."""
hasInfo(@nospecialize(target::EvalTarget))::Bool = !(target isa EVALTARGET_IGNORE_ERRORS)

"""Whether a range is evaluated as a range (a for-loop's), not expanded into its elements."""
isRange(@nospecialize(target::EvalTarget))::Bool = target isa EVALTARGET_RANGE

"""
The result of an evaluation that fails (where omc's Ceval fails): Ceval returns it instead of
throwing, and a step that gets it from a sub-evaluation returns it. It never leaves Ceval: the
entry points turn it into their own result (`tryEvalExp`: the argument; `evalExpChecked`: a
`false` flag; `evalExp`: an error). It has no other methods, so a value that leaks shows up as a
MethodError.
"""
struct EVAL_FAILURE <: Expression end

"""The evaluation failure (see `EVAL_FAILURE`)."""
const EVAL_FAILED = EVAL_FAILURE()

"""Whether an evaluation step failed (see `EVAL_FAILURE`)."""
isEvalFailure(@nospecialize(exp::Expression))::Bool = exp isa EVAL_FAILURE

toString(::EVAL_FAILURE)::String = "<evaluation failure>"

"""
 Attempts to evaluate an expression: the value, or the expression itself when it cannot be
 evaluated; the messages of the failed attempt are dropped (omc tryEvalExp).
"""
@nospecializeinfer function tryEvalExp(@nospecialize(exp::Expression), target::EvalTarget = EVALTARGET_IGNORE_ERRORS())::Expression
  ErrorExt.setCheckpoint("NFCeval.tryEvalExp")
  local result::Expression = evalExp_impl(exp, target)
  ErrorExt.rollBack("NFCeval.tryEvalExp")
  return result isa EVAL_FAILURE ? exp : getBindingExp(result)
end

"""
The value of an expression and `true`, or the expression itself and `false` when it cannot be
evaluated; the messages of a failed evaluation are kept (the caller reports or drops them).
"""
@nospecializeinfer function evalExpChecked(
  @nospecialize(exp::Expression),
  target::EvalTarget = EVALTARGET_IGNORE_ERRORS(),
)::Tuple{Bool, Expression}
  local result::Expression = evalExp_impl(exp, target)
  result isa EVAL_FAILURE && return (false, exp)
  return (true, getBindingExp(result))
end

"""
Evaluates an expression that must evaluate: a failure is an error of the model, reported by the
messages Ceval added, and ends the translation (a MetaModelica failure, as omc's fail). Callers
for which the failure is an answer use `evalExpChecked` or `tryEvalExp`.
"""
@nospecializeinfer function evalExp(
  @nospecialize(exp::Expression),
  target::EvalTarget = EVALTARGET_IGNORE_ERRORS(),
  )::Expression
  local result::Expression = evalExp_impl(exp, target)
  result isa EVAL_FAILURE && fail()
  return getBindingExp(result)
end

"""
The value of an expression, or `EVAL_FAILED` (see `EVAL_FAILURE`); binding information kept.
"""
@nospecializeinfer function evalExp_impl(@nospecialize(exp::Expression), target::EvalTarget)::Expression
  if exp isa CREF_EXPRESSION
    return evalCref(exp.cref, exp, target)
  elseif exp isa BINARY_EXPRESSION
    local b1::Expression = evalExp_impl(exp.exp1, target)
    b1 isa EVAL_FAILURE && return b1
    local b2::Expression = evalExp_impl(exp.exp2, target)
    b2 isa EVAL_FAILURE && return b2
    return evalBinaryOp(b1, exp.operator, b2, target)
  elseif exp isa CALL_EXPRESSION
    return evalCall(exp.call, target)
  elseif exp isa ARRAY_EXPRESSION
    exp.literal && return exp
    local elems::Vector{Expression} = Vector{Expression}(undef, length(exp.elements))
    for i in eachindex(exp.elements)
      local e::Expression = evalExp_impl(exp.elements[i], target)
      e isa EVAL_FAILURE && return e
      elems[i] = e
    end
    return makeArray(exp.ty, elems, literal = true)
  elseif exp isa UNARY_EXPRESSION
    local u::Expression = evalExp_impl(exp.exp, target)
    u isa EVAL_FAILURE && return u
    return evalUnaryOp(u, exp.operator)
  elseif exp isa RELATION_EXPRESSION
    local r1::Expression = evalExp_impl(exp.exp1, target)
    r1 isa EVAL_FAILURE && return r1
    local r2::Expression = evalExp_impl(exp.exp2, target)
    r2 isa EVAL_FAILURE && return r2
    return evalRelationOp(r1, exp.operator, r2)
  elseif exp isa LBINARY_EXPRESSION
    local l1::Expression = evalExp_impl(exp.exp1, target)
    l1 isa EVAL_FAILURE && return l1
    return evalLogicBinaryOp(l1, exp.operator, exp.exp2, target)
  elseif exp isa LUNARY_EXPRESSION
    local lu::Expression = evalExp_impl(exp.exp, target)
    lu isa EVAL_FAILURE && return lu
    return evalLogicUnaryOp(lu, exp.operator)
  elseif exp isa IF_EXPRESSION
    return evalIfExp(exp, target)
  elseif exp isa CAST_EXPRESSION
    local c::Expression = evalExp_impl(exp.exp, target)
    c isa EVAL_FAILURE && return c
    return evalCast(c, exp.ty)
  elseif exp isa SUBSCRIPTED_EXP_EXPRESSION
    return evalSubscriptedExp(exp.exp, exp.subscripts, target)
  elseif exp isa RANGE_EXPRESSION
    return evalRange(exp, target)
  elseif exp isa SIZE_EXPRESSION
    return evalSize(exp.exp, exp.dimIndex, target)
  elseif exp isa TYPENAME_EXPRESSION
    return evalTypename(exp.ty, exp, target)
  elseif exp isa RECORD_ELEMENT_EXPRESSION
    return evalRecordElement(exp, target)
  elseif exp isa MUTABLE_EXPRESSION
    #= A mutable cell holds a local/output variable's binding. Evaluate it
       once and write the value back, so repeated references to the same
       local (common in functions whose locals form a dependency DAG, e.g.
       MultiBody Frames.from_nxy) do not re-evaluate the whole binding tree.
       Algorithm assignments overwrite the cell, invalidating the cache. =#
    local cur::Expression = P_Pointer.access(exp.exp)
    local m::Expression = evalExp_impl(cur, target)
    m isa EVAL_FAILURE && return m
    referenceEq(m, cur) || P_Pointer.update(exp.exp, m)
    return m
  elseif exp isa BINDING_EXP
    local be::Expression = evalExp_impl(exp.exp, target)
    be isa EVAL_FAILURE && return be
    #= A new BINDING_EXP: the one evaluated is shared (a component's binding). =#
    return BINDING_EXP(be, exp.expType, exp.bindingType, exp.parents, exp.isEach)
  elseif exp isa TUPLE_EXPRESSION
    local tl::List{Expression} = nil
    for e in exp.elements
      local te::Expression = evalExp_impl(e, target)
      te isa EVAL_FAILURE && return te
      tl = Cons{Expression}(te, tl)
    end
    return TUPLE_EXPRESSION(exp.ty, listReverse(tl))
  elseif exp isa TUPLE_ELEMENT_EXPRESSION
    local t::Expression = evalExp_impl(exp.tupleExp, target)
    t isa EVAL_FAILURE && return t
    return tupleElement(t, exp.ty, exp.index)
  elseif exp isa UNBOX_EXPRESSION
    local ub::Expression = evalExp_impl(exp.exp, target)
    ub isa EVAL_FAILURE && return ub
    return UNBOX_EXPRESSION(ub, exp.ty)
  end
  #= Literals; a RECORD_EXPRESSION is not evaluated (OpenModelica evaluates the fields): a
     record variable's fields are its cells, which later `r.x := ...` update. Assignments and
     arguments take the current values through NFEvalFunction's detachCells. =#
  return exp
end

"""The evaluated option: `SOME(EVAL_FAILED)` when the expression fails (see `_failedOpt`)."""
function evalExpOpt(
  oexp::Option{Expression},
  @nospecialize(target::EvalTarget = EVALTARGET_IGNORE_ERRORS()),
)::Option{Expression}
  oexp isa SOME || return oexp
  return SOME(evalExp_impl(oexp.value, target))
end

"""Whether an `evalExpOpt` result failed."""
_failedOpt(oexp::Option{Expression})::Bool = oexp isa SOME && oexp.value isa EVAL_FAILURE

"""The state of a partial evaluation (`evalExpPartial`): the parts left unevaluated so far, and whether one failed."""
mutable struct PartialEvalState
  unevaluated::Int
  failed::Bool
end

"""
   Evaluates the parts of an expression that are possible to evaluate. This
   means leaving parts of the expression that contains e.g. iterators or mutable
   expressions. This can be used to optimize an expression that is expected to
   be evaluated many times, for example the expression in an array constructor.
   The expression and whether it was evaluated whole; `(EVAL_FAILED, false)` when a part fails.
"""
function evalExpPartial(
  @nospecialize(exp::Expression),
  @nospecialize(target::EvalTarget = EVALTARGET_IGNORE_ERRORS()),
)::Tuple{Expression, Bool}
  local state::PartialEvalState = PartialEvalState(0, false)
  local e::Expression = _evalPartial(exp, target, state)
  state.failed && return (EVAL_FAILED, false)
  return (e, state.unevaluated == 0)
end

"""
`evalExpPartial` of one part: its children first, then the part itself when they all evaluated.
A cref that does not resolve (the cref itself, or a SUBSCRIPTED_EXP whose iterator subscripts are not
replaced yet) and a mutable expression (usually a mutable iterator) are not evaluated: their parents
are not evaluated prematurely.
"""
function _evalPartial(@nospecialize(exp::Expression), @nospecialize(target::EvalTarget), state::PartialEvalState)::Expression
  local before::Int = state.unevaluated
  local e::Expression = mapShallow(exp, (@nospecialize(child::Expression),) -> _evalPartial(child, target, state))
  state.failed && return EVAL_FAILED
  if e isa CREF_EXPRESSION
    if isIterator(e.cref)
      state.unevaluated += 1
      return e
    end
    local c::Expression = evalCref(e.cref, e, target, evalSubscripts = false)
    c isa EVAL_FAILURE && (state.failed = true)
    (referenceEq(c, e) || c isa SUBSCRIPTED_EXP_EXPRESSION) && (state.unevaluated += 1)
    return c
  elseif e isa MUTABLE_EXPRESSION
    state.unevaluated += 1
    return e
  end
  state.unevaluated == before || return e
  local v::Expression = evalExp_impl(e, target)
  v isa EVAL_FAILURE && (state.failed = true; return v)
  return getBindingExp(v)
end


"""The value of a cref: the binding of a constant or structural parameter component, else `defaultExp` (the cref)."""
function evalCref(cref::ComponentRef, @nospecialize(defaultExp::Expression), target::EvalTarget;
                  evalSubscripts::Bool = true)::Expression
  (isvariant(cref, COMPONENT_REF_CREF) && isvariant(node(cref), COMPONENT_NODE) && !isIterator(cref) &&
   nodeVariability(cref) < Variability.NON_STRUCTURAL_PARAMETER) || return defaultExp
  return evalComponentBinding(node(cref), cref, defaultExp, target, evalSubscripts)
end

function evalComponentBinding(
  node::InstNode,
  cref::ComponentRef,
  @nospecialize(defaultExp::Expression),
  @nospecialize(target::EvalTarget),
  evalSubscripts::Bool = true,
)::Expression #= The expression returned if the binding couldn't be evaluated =#
  #= Typing plus evaluated-flag write-back must be atomic per node under
     parallel typing. =#
  local id = _refId(resolveOuter(node))
  #= A binding this task is evaluating, read again within itself: not evaluated there. Field
     by field acyclic, whole records read each other (Buildings' Templates: pla.cfg, through
     pla.THeaWatSup_nominal and datAll.pla.ctl.cfg, back to pla.cfg): a recursion without end,
     a stack overflow that killed the process. =#
  local evaluating = _evaluatingBindings()
  id in evaluating && return defaultExp
  push!(evaluating, id)
  try
    if _parallelTypingActive()
      return _withClaim(() -> evalComponentBinding2(node, cref, defaultExp, target, evalSubscripts), id)
    end
    return evalComponentBinding2(node, cref, defaultExp, target, evalSubscripts)
  finally
    delete!(evaluating, id)
  end
end

#= The component bindings the current task is evaluating (evalComponentBinding). =#
_evaluatingBindings()::Set{UInt64} = get!(() -> Set{UInt64}(), task_local_storage(), :NFCevalEvaluatingBindings)::Set{UInt64}

#= The element context of binding evaluation (omc 1.27: split subscripts, SPLIT_PROXY/SPLIT_INDEX,
   which this port does not have): the crefs naming an element of an array of components
   (`pendulum[1].string.r`) whose bindings the current task is evaluating. A binding read inside
   such a binding has a cref without the element's subscripts (`L` in `string(r = {0, L, 0})` of
   `Pendulum[n] pendulum(L = lengths)`); its value propagated from the array's modifier is
   subscripted by the element the context names (subscriptEvaluatedBinding2), not the whole array
   (MSL MultiBody shape, omc CevalBinding8: a final record parameter evaluated per element). =#
_elementContext()::Vector{ComponentRef} =
  get!(() -> ComponentRef[], task_local_storage(), :NFCevalElementContext)::Vector{ComponentRef}

_isEmptyContext()::Bool = isempty(_elementContext())

#= Counts the reads that took their element from the context: a binding evaluated with one is that
   element's value and is not cached in the component the elements share. =#
_elementContextUses()::Base.RefValue{Int} =
  get!(() -> Ref(0), task_local_storage(), :NFCevalElementContextUses)::Base.RefValue{Int}

#= Whether a cref has subscripts on an enclosing part (names an element of an array of components). =#
function _hasEnclosingSubscripts(cref::ComponentRef)::Bool
  isEmpty(cref) && return false
  local cr = rest(cref)
  while !isEmpty(cr)
    listEmpty(getSubscripts(cr)) || return true
    cr = rest(cr)
  end
  return false
end

#= The subscripts of a cref's enclosing parts (outermost first), an array part without them taking
   the element context's subscripts of its node; nothing when the context has none for one. =#
function _enclosingContextSubscripts(cref::ComponentRef)::Union{Vector{Subscript}, Nothing}
  _isEmptyContext() && return nothing
  local subs = Subscript[]
  local cr = rest(cref)
  local used = false
  while !isEmpty(cr)
    local own = getSubscripts(cr)
    if listEmpty(own) && dimensionCount(getType(node(cr))) > 0
      own = _contextSubscriptsOf(node(cr))
      listEmpty(own) && return nothing
      used = true
    end
    for s in reverse(Base.collect(own))
      pushfirst!(subs, s)
    end
    cr = rest(cr)
  end
  return used ? subs : nothing
end

#= The subscripts the innermost element context has on a node, or nil. =#
function _contextSubscriptsOf(n::InstNode)::List{Subscript}
  local ctx = _elementContext()
  for i in length(ctx):-1:1
    local cr = ctx[i]
    while !isEmpty(cr)
      if refEqual(node(cr), n)
        local s = getSubscripts(cr)
        listEmpty(s) || return s
        break
      end
      cr = rest(cr)
    end
  end
  return nil
end

#= The subscripts the element context gives the binding parents left over by a cref without
   them (outermost first, as subscriptEvaluatedBinding2 collects them), or nil. =#
function _elementContextSubscripts(parents::List{InstNode})::List{Subscript}
  local ctx = _elementContext()
  for i in length(ctx):-1:1
    local cr = ctx[i]
    while !isEmpty(cr) && !refEqual(node(cr), listHead(parents))
      cr = rest(cr)
    end
    isEmpty(cr) && continue
    local subs::List{Subscript} = nil
    local ps = parents
    while !listEmpty(ps) && !isEmpty(cr) && refEqual(listHead(ps), node(cr))
      subs = listAppend(getSubscripts(cr), subs)
      ps = listRest(ps)
      cr = rest(cr)
    end
    listEmpty(subs) && continue
    _elementContextUses()[] += 1
    return subs
  end
  return nil
end

#= The dimensions of an evaluated value: an array literal's nesting under any binding info
   (its type can be the element's: `abs(dp_nominal)` evaluated over the array modifier). =#
function _valueDimensionCount(@nospecialize(exp::Expression))::Int
  local e = stripBindingInfo(exp)
  local depth = 0
  local x = e
  while x isa ARRAY_EXPRESSION && !isempty(x.elements)
    depth += 1
    x = Base.first(x.elements)
  end
  return max(depth, dimensionCount(typeOf(e)))
end

#= An evaluated value over the enclosing component arrays (`extra` dimensions more than the
   component), for one element: subscripted by the cref's innermost enclosing parts. Each element's
   if-equation condition had been the whole array (Buildings' counter-flow coils, `if
   {true, false, false, false} then assert(...)` for hex.ele[1]: computeFlowResistance of the
   elements' array modifiers). A cref without them (the array itself) keeps the value. =#
function _subscriptByEnclosingElements(@nospecialize(exp::Expression), cref::ComponentRef, extra::Int,
                                       evalSubscripts::Bool, readsOwnElement::Bool)::Expression
  local subs = Subscript[]
  local cr = rest(cref)
  while !isEmpty(cr)
    for s in reverse(Base.collect(getSubscripts(cr)))
      pushfirst!(subs, s)
    end
    cr = rest(cr)
  end
  local value = stripBindingInfo(exp)
  local depth = 0
  local x = value
  while x isa ARRAY_EXPRESSION && !isempty(x.elements)
    depth += 1
    x = Base.first(x.elements)
  end
  depth >= extra || return exp
  if length(subs) < extra
    #= No element subscripts: in an element's own context (a binding in the elements' shared
       class, evaluated once for all) every element's value when they are all the same. Buildings
       ElectricChillerParallel: pum[num](per = per), per = fill(perCHWPum, numChi), WMot_nominal's
       `power.P[1] > eps` read {P, P} and P[1] picked a pump ({0.0} > eps). =#
    readsOwnElement || return exp
    #= Read inside the binding of a named element (`pendulum.L` in pendulum[1].string.r's
       binding): that element's (see _elementContext). =#
    local csubs = _enclosingContextSubscripts(cref)
    if csubs !== nothing && length(csubs) >= extra
      local cown = csubs[end - extra + 1:end]
      if evalSubscripts
        local (cok::Bool, csubsEval::Vector{Subscript}) = _evalSubscripts(Vector{Subscript}(cown))
        cok || return EVAL_FAILED
        cown = csubsEval
      end
      _elementContextUses()[] += 1
      return applySubscripts(list(cown...), value)
    end
    local shared = _sharedElementValue(value, extra)
    return shared === nothing ? exp : shared
  end
  local own = subs[end - extra + 1:end]
  if evalSubscripts
    local (ok::Bool, ownEval::Vector{Subscript}) = _evalSubscripts(Vector{Subscript}(own))
    ok || return EVAL_FAILED
    own = ownEval
  end
  return applySubscripts(list(own...), value)
end

#= The value every element of `extra` enclosing arrays has, or nothing when they differ. =#
function _sharedElementValue(@nospecialize(value::Expression), extra::Int)::Union{Expression, Nothing}
  local x::Expression = value
  for _ in 1:extra
    (x isa ARRAY_EXPRESSION && !isempty(x.elements)) || return nothing
    local elems::Vector{Expression} = x.elements
    local first_el::Expression = elems[1]
    # A loop: `all` with a closure over `first_el` compiled per element type.
    for i in 2:length(elems)
      isEqual(elems[i], first_el) || return nothing
    end
    x = first_el
  end
  return x
end

#= Whether a cref without its enclosing elements' subscripts reads its own element (its type
   has not their dimensions: a binding in the elements' shared class) rather than the array
   (`bld.m_flow_nominal` read from outside, typed over bld). =#
function _readsOwnElement(cref::ComponentRef, @nospecialize(defaultExp::Expression), compType::ModelicaType,
                          extra::Int)::Bool
  local own = dimensionCount(compType) - count(isScalar, getSubscripts(cref))
  return dimensionCount(typeOf(defaultExp)) < own + extra
end

function evalComponentBinding2(
  node::InstNode,
  cref::ComponentRef,
  @nospecialize(defaultExp::Expression),
  @nospecialize(target::EvalTarget),
  evalSubscripts::Bool = true,
)::Expression #= The expression returned if the binding couldn't be evaluated =#
  local exp::Expression
  local exp_origin::ORIGIN_Type = isFunction(explicitParent(node)) ? ORIGIN_FUNCTION : ORIGIN_CLASS
  node = typeComponentBinding(node, exp_origin, false)
  local comp::Component = component(node)
  local binding::Binding = getBinding(comp)
  if isUnbound(binding)
    #= Constructed for the node, for example a record with bindings on its fields but none on
       the record instance; else the component's start value (already evaluated). =#
    binding = makeComponentBinding(comp, node, toCref(defaultExp), target)
    if isUnbound(binding)
      local (has_start::Bool, start_exp::Expression) =
        evalComponentStartBinding(node, comp, cref, target, evalSubscripts)
      has_start && return start_exp
    end
  end
  if isvariant(binding, TYPED_BINDING) && binding.evaluated
    exp = binding.bindingExp
  elseif isvariant(binding, TYPED_BINDING)
    #= Evaluated in the element context of the cref (see _elementContext). =#
    local ctx::Vector{ComponentRef} = _elementContext()
    local in_element::Bool = _hasEnclosingSubscripts(cref)
    in_element && push!(ctx, cref)
    local uses::Base.RefValue{Int} = _elementContextUses()
    local uses0::Int = uses[]
    exp = evalExp_impl(binding.bindingExp, target)
    in_element && pop!(ctx)
    #= Not evaluable: the cref itself when errors are ignored, else the failure. =#
    exp isa EVAL_FAILURE && return target isa EVALTARGET_IGNORE_ERRORS ? defaultExp : exp
    #= The binding updated and marked evaluated; not a value with more dimensions than the
       component (a binding in an array of components evaluated in its class, which the elements
       share, its references to the elements' array modifiers whole: every element's binding
       became the array, Buildings' PressureDrop[nRes] resSeries, dp_nominal_pos =
       abs(dp_nominal) evaluated for an if-equation's condition), and not one that read the
       element context (one element's value, not the shared one's). =#
    local extra::Int = _valueDimensionCount(exp) - dimensionCount(getType(comp))
    if extra > 0
      exp = _subscriptByEnclosingElements(exp, cref, extra, evalSubscripts,
                                          _readsOwnElement(cref, defaultExp, getType(comp), extra))
    elseif uses[] == uses0
      @assign binding.bindingExp = exp
      @assign binding.evaluated = true
      comp = setBinding(binding, comp)
      node = updateComponent!(comp, node)
    end
  elseif isvariant(binding, CEVAL_BINDING)
    #= Over the enclosing component arrays too (a record field's value from its parent's, the
       parent bound to an array of records: Buildings' Templates pumps, pum[nPum](per = per),
       each element's `per.haveWMot_nominal` the array {false, true}): its element. =#
    exp = binding.bindingExp
    local cextra::Int = _valueDimensionCount(exp) - dimensionCount(getType(comp))
    cextra > 0 && (exp = _subscriptByEnclosingElements(exp, cref, cextra, evalSubscripts,
                                                       _readsOwnElement(cref, defaultExp, getType(comp), cextra)))
  elseif isvariant(binding, UNBOUND)
    return printUnboundError(comp, target, defaultExp) ? EVAL_FAILED : defaultExp
  else
    Error.addInternalError("evalComponentBinding2 failed on untyped binding", sourceInfo())
    return EVAL_FAILED
  end
  exp isa EVAL_FAILURE && return exp
  #= The cref's subscripts applied to the binding's value. =#
  exp = subscriptEvaluatedBinding(exp, cref, evalSubscripts)
  exp isa EVAL_FAILURE && return exp
  return _liftToCrefDims(exp, defaultExp)
end

#= The value of a cref over an array of components, with the cref's dimensions (omc: liftExp).
   A cref naming the array (`bld.m_flow_nominal`, no subscript on bld) reads every element:
   - a binding propagated from a modifier on the array (a BINDING_EXP over its elements) is
     the plain array; a builtin call mapped it per element (sum of each element);
   - the elements' shared class binding (propagated through no dimension) is one value for
     all, lifted to the cref's dimensions; sum had summed the scalar.
   Buildings DHC: mDis_flow_nominal = sum(bld.m_flow_nominal)*1.2, read by a dimension. In an
   element's own context the cref has fewer dimensions than the value: kept for the mapping. =#
function _liftToCrefDims(@nospecialize(exp::Expression), @nospecialize(defaultExp::Expression))::Expression
  exp isa BINDING_EXP || dimensionCount(typeOf(exp)) < dimensionCount(typeOf(defaultExp)) || return exp
  local value = exp
  while value isa BINDING_EXP
    value = value.exp
  end
  contains(value, isBindingExp) && return exp
  local cref_ty = typeOf(defaultExp)
  local diff = dimensionCount(cref_ty) - dimensionCount(typeOf(value))
  diff == 0 && return value
  diff > 0 || return exp
  local lift = Base.collect(Dimension, arrayDims(cref_ty))[1:diff]
  all(d -> isKnown(d), lift) || return exp
  for d in reverse(lift)
    value = Base.first(liftArray(d, value))
  end
  return value
end

"""Of BINDING_EXPs nested directly in each other, the innermost."""
function flattenBindingExp(@nospecialize(exp::Expression))::Expression
  while exp isa BINDING_EXP && exp.exp isa BINDING_EXP
    exp = exp.exp
  end
  return exp
end

"""
  Takes subscripts from the given component reference and applies them to an
  evaluated expression.
"""
function subscriptEvaluatedBinding(
  @nospecialize(exp::Expression),
  cref::ComponentRef,
  evalSubscripts::Bool,
)::Expression

  #= The subscripts of the first part of the cref are always applied; the rest of the cref
     contributes subscripts by where the expression comes from in the instance tree. =#
  local subs::List{Subscript} = getSubscripts(cref)
  local cr::ComponentRef = Base.first(stripSubscripts(cref))
  if evalSubscripts
    local (ok::Bool, evaluated::List{Subscript}) = _evalSubscripts(subs)
    ok || return EVAL_FAILED
    subs = evaluated
  end
  return subscriptEvaluatedBinding2(exp, cr, evalSubscripts, subs, subs)
end

function subscriptEvaluatedBinding2(
  @nospecialize(exp::Expression),
  cref::ComponentRef,
  evalSubscripts::Bool,
  subscripts::List{<:Subscript} = nil,
  bindingSubs::List{<:Subscript} = nil,
)::Expression

  exp isa BINDING_EXP || return applySubscripts(subscripts, exp)
  local bind_ty::ModelicaType = exp.bindingType
  local parents::List{InstNode} = exp.isEach ? list(listHead(exp.parents)) : exp.parents
  local cr::ComponentRef = cref
  local accum_subs::List{Subscript} = subscripts
  local subs::List{Subscript} = nil
  if !isEmpty(cr)
    #= The binding's parents dropped up to the one of the first cref node; the subscripts of the
       cref parts that correspond to the remaining parents collected. =#
    local cr_node::InstNode = node(cr)
    while !(listEmpty(parents) || refEqual(listHead(parents), cr_node))
      parents = listRest(parents)
    end
    while !listEmpty(parents) && refEqual(listHead(parents), cr_node)
      subs = listAppend(getSubscripts(cr), subs)
      parents = listRest(parents)
      cr = rest(cr)
      isEmpty(cr) && break
      cr_node = node(cr)
    end
    #= Parents the cref has no parts for (a binding read inside an element's binding): their
       subscripts from the element context. =#
    if isEmpty(cr) && !listEmpty(parents) && !_isEmptyContext()
      subs = listAppend(_elementContextSubscripts(parents), subs)
    end
    if evalSubscripts
      local (ok::Bool, evaluated::List{Subscript}) = _evalSubscripts(subs)
      ok || return EVAL_FAILED
      subs = evaluated
    end
    accum_subs = listAppend(subs, accum_subs)
  end
  #= The binding type subscripted if bindingSubs was given. =#
  if !listEmpty(bindingSubs)
    subs = bindingSubs
    bind_ty = subscript(bind_ty, subs)
  end
  local e::Expression = subscriptEvaluatedBinding2(exp.exp, cr, evalSubscripts, accum_subs, subs)
  e isa EVAL_FAILURE && return e
  return BINDING_EXP(e, typeOf(e), bind_ty, exp.parents, exp.isEach)
end

#= Installs the evaluated start binding. Under parallel typing on the start node's component as it
   is under that node's claim: attribute typing writes the same node under it (the caller holds the
   parent's claim only). =#
function setStartBinding!(start_node::InstNode, binding::Binding, @nospecialize(exp::Expression))::Nothing
  binding.bindingExp = exp
  if _parallelTypingActive()
    _withClaim(() -> updateComponent!(setBinding(binding, component(start_node)), start_node), _refId(start_node))
  else
    updateComponent!(setBinding(binding, component(start_node)), start_node)
  end
  return nothing
end

"""
The evaluated start value of a fixed parameter: `(true, value)` (the value `EVAL_FAILED` when it
could not be evaluated), `(false, EVAL_FAILED)` when the component is no fixed parameter or has
no start value.
"""
function evalComponentStartBinding(
  node::InstNode,
  comp::Component,
  cref::ComponentRef,
  @nospecialize(target::EvalTarget),
  evalSubscripts::Bool,
)::Tuple{Bool, Expression}
  local var::VariabilityType = variability(comp)
  (var == Variability.PARAMETER || var == Variability.STRUCTURAL_PARAMETER) && getFixedAttribute(comp) ||
    return (false, EVAL_FAILED)
  #= "start" looked up in the class (getClass gives the node back when it has none); an actual
     start attribute, not some other element named start. =#
  local cls = getClass(node)
  cls isa Class || return (false, EVAL_FAILED)
  local start_node::InstNode = lookupElementNode("start", cls)
  isvariant(start_node, EMPTY_NODE) && return (false, EVAL_FAILED)
  local start_comp::Component = component(start_node)
  isTypeAttribute(start_comp) || return (false, EVAL_FAILED)
  local binding::Binding = getBinding(start_comp)
  isvariant(binding, UNTYPED_BINDING) && (binding = typeBinding(binding, ORIGIN_BINDING))
  isvariant(binding, TYPED_BINDING) || return (false, EVAL_FAILED)
  #= evalExp, as omc: the value without the start modifier's propagation (BINDING_EXP), which
     applies per element; as the component's value the propagated start of r[3](start = {...})
     vectorized from_nxy(r, ...). =#
  local exp::Expression = _evalValue(binding.bindingExp, target)
  if !(exp isa EVAL_FAILURE) && !referenceEq(exp, binding.bindingExp)
    setStartBinding!(start_node, binding, exp)
  end
  return (true, exp)
end

function makeComponentBinding(
  component::Component,
  node::InstNode,
  cref::ComponentRef,
  @nospecialize(target::EvalTarget),
)::Binding
  #= A record field without an explicit binding: the field of its parent's binding, if the parent
     has one. =#
  local exp::Expression = makeRecordFieldBindingFromParent(cref, target)
  exp isa EVAL_FAILURE || return CEVAL_BINDING(exp)
  #= A record or record array component without an explicit binding: one made from its children. =#
  isvariant(component, TYPED_COMPONENT) || return EMPTY_BINDING
  local ty::ModelicaType = component.ty
  local is_array::Bool = isvariant(ty, TYPE_ARRAY)
  local elem_ty::ModelicaType = is_array ? ty.elementType : ty
  (isvariant(elem_ty, TYPE_COMPLEX) && elem_ty.complexTy isa COMPLEX_RECORD) || return EMPTY_BINDING
  exp = makeRecordBindingExp(component.classInst, elem_ty.complexTy.constructor, ty, cref)
  exp isa EVAL_FAILURE && return EMPTY_BINDING
  is_array && (exp = splitRecordArrayExp(exp))
  local exp_ty::ModelicaType = typeOf(exp)
  local binding::Binding = CEVAL_BINDING(BINDING_EXP(exp, exp_ty, exp_ty, list(node), true))
  hasSubscripts(cref) || updateComponent!(setBinding(binding, component), node)
  return binding
end

"""
The value of the record field `cref` without a binding, from the binding of its nearest bound parent (omc
makeRecordFieldBindingFromParent), evaluated level by level. A parent bound to another record (`stack.stackData =
stackData`) gives a reference to that record's field (`stackData.cellData`), which is not evaluated at its level but
extended by the fields below (`stackData.cellData.nRC`) and evaluated as that field: evaluated whole, `stackData.cellData`
had its binding replaced by the value (MSL CCCV_StackRC: `stackData.cellData[1, 1].Qnom = 18000.0` for omc's
`= stackData.cellDataDegraded.Qnom`).
"""
function makeRecordFieldBindingFromParent(cref::ComponentRef, @nospecialize(target::EvalTarget))::Expression
  local (exp::Expression, evaluated::Bool) = recordFieldFromParent(cref, target)
  (evaluated || exp isa EVAL_FAILURE) && return exp
  return _evalValue(exp, target)
end

"""`evalExp` within Ceval: the value without binding information, or `EVAL_FAILED`."""
function _evalValue(@nospecialize(exp::Expression), @nospecialize(target::EvalTarget))::Expression
  local v::Expression = evalExp_impl(exp, target)
  return v isa EVAL_FAILURE ? v : getBindingExp(v)
end

"""
    _evalSubscript(subscript) -> (Bool, Subscript)
A subscript with its index or slice evaluated (`NFSubscript.evalSubscript`, which throws), and `true`; `false`
and the subscript when its expression does not evaluate.
"""
function _evalSubscript(subscript::Subscript)::Tuple{Bool, Subscript}
  local e::Expression
  if isvariant(subscript, SUBSCRIPT_INDEX)
    e = _evalValue(subscript.index, EVALTARGET_IGNORE_ERRORS())
    e isa EVAL_FAILURE && return (false, subscript)
    return (true, SUBSCRIPT_INDEX(e))
  elseif isvariant(subscript, SUBSCRIPT_SLICE)
    e = _evalValue(subscript.slice, EVALTARGET_IGNORE_ERRORS())
    e isa EVAL_FAILURE && return (false, subscript)
    return (true, SUBSCRIPT_SLICE(e))
  end
  return (true, subscript)
end

"""`_evalSubscript` over subscripts: `(true, evaluated)`, or `(false, subscripts)` at the first failure."""
function _evalSubscripts(subscripts::Vector{Subscript})::Tuple{Bool, Vector{Subscript}}
  local out::Vector{Subscript} = Vector{Subscript}(undef, length(subscripts))
  for i in eachindex(subscripts)
    local (ok::Bool, sub::Subscript) = _evalSubscript(subscripts[i])
    ok || return (false, subscripts)
    out[i] = sub
  end
  return (true, out)
end

function _evalSubscripts(subscripts::List{Subscript})::Tuple{Bool, List{Subscript}}
  local out::List{Subscript} = nil
  for s in subscripts
    local (ok::Bool, sub::Subscript) = _evalSubscript(s)
    ok || return (false, subscripts)
    out = Cons{Subscript}(sub, out)
  end
  return (true, listReverse(out))
end

"""
`bindingExpMap` with a Ceval step: `EVAL_FAILED` when the step fails for an element (the
elements after it are not evaluated; the failed one keeps its input so the map's types hold).
"""
function _bindingExpMapEval(@nospecialize(exp::Expression), f::F)::Expression where {F}
  local failed::Base.RefValue{Bool} = Ref(false)
  local g = (@nospecialize(x::Expression),) -> begin
    failed[] && return x
    local r::Expression = f(x)
    r isa EVAL_FAILURE || return r
    failed[] = true
    return x
  end
  local result::Expression = bindingExpMap(exp, g)
  return failed[] ? EVAL_FAILED : result
end

"""`bindingExpMap2` with a Ceval step (see `_bindingExpMapEval`)."""
function _bindingExpMap2Eval(@nospecialize(exp::Expression), f::F, count::Int, @nospecialize(maxExp::Expression))::Expression where {F}
  local failed::Base.RefValue{Bool} = Ref(false)
  local g = (x::Expression) -> begin
    failed[] && return x
    local r::Expression = f(x)
    r isa EVAL_FAILURE || return r
    failed[] = true
    return x
  end
  local result::Expression = bindingExpMap2(exp, g, count, maxExp)
  return failed[] ? EVAL_FAILED : result
end

"""
The record field `cref` from its nearest bound parent and whether it is evaluated: a reference to another record's
field is returned as it is (see makeRecordFieldBindingFromParent), anything else evaluated at its level. Parents without
a binding: the parent's value, its field evaluated again (its record's fields are not evaluated by evalExp_impl: a
record field of a field set by a record constructor, Buildings' borefield conDat.mBorFie_flow_nominal).
"""
function recordFieldFromParent(cref::ComponentRef, @nospecialize(target::EvalTarget))::Tuple{Expression, Bool}
  local parent_cr::ComponentRef = rest(cref)
  #= No parent component (not a record field): nothing to take the field from. =#
  (isvariant(parent_cr, COMPONENT_REF_CREF) && isvariant(node(parent_cr), COMPONENT_NODE)) || return (EVAL_FAILED, false)
  local parent::InstNode = typeComponentBinding(node(parent_cr), ORIGIN_CLASS, #= typeChildren =# false)
  local binding::Binding = getBinding(component(parent))
  local subs::List{Subscript} = getSubscripts(parent_cr)
  local exp::Expression
  if hasExp(binding)
    exp = recordElement(firstName(cref), applySubscripts(subs, getExp(binding)))
    _isCrefExp(exp) && return (exp, false)
    return (_evalValue(exp, target), true)
  end
  local evaluated::Bool
  (exp, evaluated) = recordFieldFromParent(parent_cr, target)
  exp isa EVAL_FAILURE && return (exp, false)
  exp = recordElement(firstName(cref), applySubscripts(subs, exp))
  (!evaluated && _isCrefExp(exp)) && return (exp, false)
  return (_evalValue(exp, target), true)
end

"Whether `exp` is a component reference, under any binding information."
_isCrefExp(@nospecialize(exp::Expression))::Bool = stripBindingInfo(exp) isa CREF_EXPRESSION

function makeRecordBindingExp(
  typeNode::InstNode,
  recordNode::InstNode,
  recordType::ModelicaType,
  cref::ComponentRef,
  )::Expression
  local comps::Vector{InstNode} = getComponents(classTree(getClass(typeNode)))
  local args::Vector{Expression} = Vector{Expression}(undef, length(comps))
  for (i, c) in enumerate(comps)
    local ty::ModelicaType = getType(c)
    local arg::Expression = CREF_EXPRESSION(ty, COMPONENT_REF_CREF(c, nil, ty, Origin.CREF, cref))
    if variability(component(c)) <= Variability.PARAMETER
      arg = evalExp_impl(arg, EVALTARGET_IGNORE_ERRORS())
      arg isa EVAL_FAILURE && return arg
    end
    args[i] = arg
  end
  return makeRecord(scopePath(recordNode), recordType, args)
end

function splitRecordArrayExp(exp::RECORD_EXPRESSION)::Expression
  return fillType(exp.ty, makeRecord(exp.path, arrayElementType(exp.ty), exp.elements))
end

"""A typename expanded into an array only when used as a range; kept as a typename elsewhere (as a dimension)."""
function evalTypename(ty::ModelicaType, @nospecialize(originExp::Expression), @nospecialize(target::EvalTarget))::Expression
  return isRange(target) ? expandTypename(ty) : originExp
end

function evalRange(rangeExp::RANGE_EXPRESSION, @nospecialize(target::EvalTarget))::Expression
  local start_exp::Expression = _evalValue(rangeExp.start, target)
  start_exp isa EVAL_FAILURE && return start_exp
  local step_exp::Option{Expression} = evalExpOpt(rangeExp.step, target)
  _failedOpt(step_exp) && return EVAL_FAILED
  local stop_exp::Expression = _evalValue(rangeExp.stop, target)
  stop_exp isa EVAL_FAILURE && return stop_exp
  if isRange(target)
    local ty::ModelicaType = getRangeType(start_exp, step_exp, stop_exp, arrayElementType(rangeExp.ty),
                                          EvalTarget_getInfo(target))
    return RANGE_EXPRESSION(ty, start_exp, step_exp, stop_exp)
  end
  return _bindingExpMapEval(RANGE_EXPRESSION(rangeExp.ty, start_exp, step_exp, stop_exp),
                            (r) -> evalRangeExp(r::RANGE_EXPRESSION))
end

"""The elements of an evaluated range: Integer, Real, Boolean or enumeration bounds (a step for the first two)."""
function evalRangeExp(rangeExp::RANGE_EXPRESSION)::Expression
  local start::Expression = rangeExp.start
  local stop::Expression = rangeExp.stop
  local ty::ModelicaType
  local expl::Vector{Expression}
  if isSome(rangeExp.step)
    local step::Expression = Util.getOption(rangeExp.step)
    if start isa INTEGER_EXPRESSION && step isa INTEGER_EXPRESSION && stop isa INTEGER_EXPRESSION
      (ty, expl) = (TYPE_INTEGER(), Expression[INTEGER_EXPRESSION(i) for i::Int = start.value:step.value:stop.value])
    elseif start isa REAL_EXPRESSION && step isa REAL_EXPRESSION && stop isa REAL_EXPRESSION
      (ty, expl) = (TYPE_REAL(), evalRangeReal(start.value, step.value, stop.value))
    else
      printWrongArgsError("evalRangeExp", list(start, step, stop), sourceInfo())
      return EVAL_FAILED
    end
  elseif start isa INTEGER_EXPRESSION && stop isa INTEGER_EXPRESSION
    (ty, expl) = (TYPE_INTEGER(), Expression[INTEGER_EXPRESSION(i) for i::Int = start.value:stop.value])
  elseif start isa REAL_EXPRESSION && stop isa REAL_EXPRESSION
    (ty, expl) = (TYPE_REAL(), evalRangeReal(start.value, 1.0, stop.value))
  elseif start isa BOOLEAN_EXPRESSION && stop isa BOOLEAN_EXPRESSION
    (ty, expl) = (TYPE_BOOLEAN(), Expression[BOOLEAN_EXPRESSION(b) for b::Bool = start.value:stop.value])
  elseif start isa ENUM_LITERAL_EXPRESSION && stop isa ENUM_LITERAL_EXPRESSION && isvariant(start.ty, TYPE_ENUMERATION)
    ty = start.ty
    expl = Expression[ENUM_LITERAL_EXPRESSION(ty, listGet(ty.literals, i), i) for i::Int = start.index:stop.index]
  else
    printWrongArgsError("evalRangeExp", list(start, stop), sourceInfo())
    return EVAL_FAILED
  end
  return makeArray(TYPE_ARRAY(ty, list(fromInteger(length(expl)))), expl; literal = true)
end

function evalRangeReal(start::Float64, step::Float64, stop::Float64)::Vector{Expression}
  local steps::Int = Util.realRangeSize(start, step, stop)
  #=  Real ranges are tricky, make sure that start and stop are reproduced exactly if they are
      part of the range. =#
  steps == 0 && return Expression[]
  steps == 1 && return Expression[REAL_EXPRESSION(start)]
  local result = Vector{Expression}(undef, steps)
  result[1] = REAL_EXPRESSION(start)
  for i in 1:(steps - 2)
    result[i + 1] = REAL_EXPRESSION(start + i * step)
  end
  result[steps] = REAL_EXPRESSION(stop)
  return result
end

function printFailedEvalError(name::String, @nospecialize(exp::Expression), info::SourceInfo)
  return Error.addInternalError(
    name + " failed to evaluate ‘" + toString(exp) + "’",
    info,
  )
end

function evalBinaryOp(
  @nospecialize(exp1::Expression),
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  @nospecialize(target::EvalTarget = EVALTARGET_IGNORE_ERRORS()),
)::Expression
  local (max_prop_exp::Expression, max_prop_count::Int) = mostPropagatedSubExpBinary(exp1, exp2)
  max_prop_count >= 0 || return evalBinaryOp_dispatch(exp1, op, exp2, target)
  return _bindingExpMap2Eval(BINARY_EXPRESSION(exp1, op, exp2), (x) -> evalBinaryExp(x::BINARY_EXPRESSION, target),
                             max_prop_count, max_prop_exp)
end

"""A binary expression whose operands bindingExpMap unwrapped: they may still be unevaluated (a SUBSCRIPTED_EXP)."""
function evalBinaryExp(binaryExp::BINARY_EXPRESSION, @nospecialize(target::EvalTarget))::Expression
  local e1::Expression = evalExp_impl(binaryExp.exp1, target)
  e1 isa EVAL_FAILURE && return e1
  local e2::Expression = evalExp_impl(binaryExp.exp2, target)
  e2 isa EVAL_FAILURE && return e2
  return evalBinaryOp_dispatch(e1, binaryExp.operator, e2, target)
end

function evalBinaryOp_dispatch(
  @nospecialize(exp1::Expression),
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  @nospecialize(target::EvalTarget = EVALTARGET_IGNORE_ERRORS()),
)::Expression
  local o::Int = op.op
  o == Op.ADD && return evalBinaryAdd(exp1, exp2)
  o == Op.SUB && return evalBinarySub(exp1, exp2)
  o == Op.MUL && return evalBinaryMul(exp1, exp2)
  o == Op.DIV && return evalBinaryDiv(exp1, exp2, target)
  o == Op.POW && return evalBinaryPow(exp1, exp2)
  # array op array (omc f3c163ba5b); the functions above go element by element over two arrays.
  o == Op.ADD_EW && return evalBinaryAdd(exp1, exp2)
  o == Op.SUB_EW && return evalBinarySub(exp1, exp2)
  o == Op.MUL_EW && return evalBinaryMul(exp1, exp2)
  o == Op.DIV_EW && return evalBinaryDiv(exp1, exp2, target)
  o == Op.POW_EW && return evalBinaryPow(exp1, exp2)
  o == Op.ADD_SCALAR_ARRAY && return evalBinaryScalarArray(exp1, exp2, evalBinaryAdd)
  o == Op.ADD_ARRAY_SCALAR && return evalBinaryArrayScalar(exp1, exp2, evalBinaryAdd)
  o == Op.SUB_SCALAR_ARRAY && return evalBinaryScalarArray(exp1, exp2, evalBinarySub)
  o == Op.SUB_ARRAY_SCALAR && return evalBinaryArrayScalar(exp1, exp2, evalBinarySub)
  o == Op.MUL_SCALAR_ARRAY && return evalBinaryScalarArray(exp1, exp2, evalBinaryMul)
  o == Op.MUL_ARRAY_SCALAR && return evalBinaryArrayScalar(exp1, exp2, evalBinaryMul)
  o == Op.MUL_VECTOR_MATRIX && return evalBinaryMulVectorMatrix(exp1, exp2)
  o == Op.MUL_MATRIX_VECTOR && return evalBinaryMulMatrixVector(exp1, exp2)
  o == Op.SCALAR_PRODUCT && return evalBinaryScalarProduct(exp1, exp2)
  o == Op.MATRIX_PRODUCT && return evalBinaryMatrixProduct(exp1, exp2)
  o == Op.DIV_SCALAR_ARRAY && return evalBinaryScalarArray(exp1, exp2, (x, y) -> evalBinaryDiv(x, y, target))
  o == Op.DIV_ARRAY_SCALAR && return evalBinaryArrayScalar(exp1, exp2, (x, y) -> evalBinaryDiv(x, y, target))
  o == Op.POW_SCALAR_ARRAY && return evalBinaryScalarArray(exp1, exp2, evalBinaryPow)
  o == Op.POW_ARRAY_SCALAR && return evalBinaryArrayScalar(exp1, exp2, evalBinaryPow)
  o == Op.POW_MATRIX && return evalBinaryPowMatrix(exp1, exp2)
  Error.addInternalError("evalBinaryOp_dispatch: unimplemented case for " + toString(BINARY_EXPRESSION(exp1, op, exp2)),
                         sourceInfo())
  return EVAL_FAILED
end

"""
Element by element `f(a[i], b[i])` over two arrays of the same length, as a literal array of
`a`'s type; `EVAL_FAILED` when an element fails.
"""
function _evalElementwise(f::F, a::ARRAY_EXPRESSION, b::ARRAY_EXPRESSION)::Expression where {F}
  local n::Int = length(a.elements)
  local out::Vector{Expression} = Vector{Expression}(undef, n)
  for i in 1:n
    local e::Expression = f(a.elements[i], b.elements[i])
    e isa EVAL_FAILURE && return e
    out[i] = e
  end
  return ARRAY_EXPRESSION(a.ty, out, true)
end

"""
`f` on each element: the array of the results with type `ty`, or `EVAL_FAILED` at the first
element that fails.
"""
function _mapElements(f::F, elements::Vector{Expression}, ty::ModelicaType, literal::Bool)::Expression where {F}
  local out::Vector{Expression} = Vector{Expression}(undef, length(elements))
  for i in eachindex(elements)
    local e::Expression = f(elements[i])
    e isa EVAL_FAILURE && return e
    out[i] = e
  end
  return ARRAY_EXPRESSION(ty, out, literal)
end

"""Whether both operands are arrays of the same length (an element-by-element operation)."""
_sameLength(@nospecialize(a::Expression), @nospecialize(b::Expression))::Bool =
  a isa ARRAY_EXPRESSION && b isa ARRAY_EXPRESSION && length(a.elements) == length(b.elements)

#= An Integer with a Real: both as Reals, as typing would have cast them (a function body
   evaluated with Integer arguments, an Integer literal in a Real array: Buildings' Movers). =#
@inline function _mixedAsReal(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))
  exp1 isa INTEGER_EXPRESSION && exp2 isa REAL_EXPRESSION && return (REAL_EXPRESSION(Float64(exp1.value)), exp2)
  exp1 isa REAL_EXPRESSION && exp2 isa INTEGER_EXPRESSION && return (exp1, REAL_EXPRESSION(Float64(exp2.value)))
  return (exp1, exp2)
end

"""The error of an arithmetic operation on values it is not defined for, and `EVAL_FAILED`."""
function _failedBinary(@nospecialize(exp1::Expression), op::OPERATOR, @nospecialize(exp2::Expression), name::String)::Expression
  printFailedEvalError(name, BINARY_EXPRESSION(exp1, op, exp2), sourceInfo())
  return EVAL_FAILED
end

function evalBinaryAdd(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  exp1 isa INTEGER_EXPRESSION && exp2 isa INTEGER_EXPRESSION && return INTEGER_EXPRESSION(_intOf(exp1) + _intOf(exp2))
  exp1 isa REAL_EXPRESSION && exp2 isa REAL_EXPRESSION && return REAL_EXPRESSION(_realOf(exp1) + _realOf(exp2))
  exp1 isa STRING_EXPRESSION && exp2 isa STRING_EXPRESSION && return STRING_EXPRESSION(_stringOf(exp1) * _stringOf(exp2))
  _sameLength(exp1, exp2) && return _evalElementwise(evalBinaryAdd, exp1::ARRAY_EXPRESSION, exp2::ARRAY_EXPRESSION)
  return _failedBinary(exp1, makeAdd(TYPE_UNKNOWN()), exp2, "evalBinaryAdd")
end

function evalBinarySub(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  exp1 isa INTEGER_EXPRESSION && exp2 isa INTEGER_EXPRESSION && return INTEGER_EXPRESSION(_intOf(exp1) - _intOf(exp2))
  exp1 isa REAL_EXPRESSION && exp2 isa REAL_EXPRESSION && return REAL_EXPRESSION(_realOf(exp1) - _realOf(exp2))
  _sameLength(exp1, exp2) && return _evalElementwise(evalBinarySub, exp1::ARRAY_EXPRESSION, exp2::ARRAY_EXPRESSION)
  return _failedBinary(exp1, makeSub(TYPE_UNKNOWN()), exp2, "evalBinarySub")
end

function evalBinaryMul(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  exp1 isa INTEGER_EXPRESSION && exp2 isa INTEGER_EXPRESSION && return INTEGER_EXPRESSION(_intOf(exp1) * _intOf(exp2))
  exp1 isa REAL_EXPRESSION && exp2 isa REAL_EXPRESSION && return REAL_EXPRESSION(_realOf(exp1) * _realOf(exp2))
  _sameLength(exp1, exp2) && return _evalElementwise(evalBinaryMul, exp1::ARRAY_EXPRESSION, exp2::ARRAY_EXPRESSION)
  return _failedBinary(exp1, makeMul(TYPE_UNKNOWN()), exp2, "evalBinaryMul")
end

"""
`exp1 / exp2`. A division by zero is an error where the target reports errors, and stays the
division otherwise.
"""
function evalBinaryDiv(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression), @nospecialize(target::EvalTarget))::Expression
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  if exp2 isa REAL_EXPRESSION && _realOf(exp2) == 0.0
    hasInfo(target) || return BINARY_EXPRESSION(exp1, makeDiv(TYPE_REAL()), exp2)
    Error.addSourceMessage(Error.DIVISION_BY_ZERO, list(toString(exp1), toString(exp2)), EvalTarget_getInfo(target))
    return EVAL_FAILED
  end
  exp1 isa REAL_EXPRESSION && exp2 isa REAL_EXPRESSION && return REAL_EXPRESSION(_realOf(exp1) / _realOf(exp2))
  _sameLength(exp1, exp2) &&
    return _evalElementwise((x, y) -> evalBinaryDiv(x, y, target), exp1::ARRAY_EXPRESSION, exp2::ARRAY_EXPRESSION)
  return _failedBinary(exp1, makeDiv(TYPE_UNKNOWN()), exp2, "evalBinaryDiv")
end

function evalBinaryPow(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  exp1 isa REAL_EXPRESSION && exp2 isa REAL_EXPRESSION && return REAL_EXPRESSION(_realOf(exp1)^_realOf(exp2))
  _sameLength(exp1, exp2) && return _evalElementwise(evalBinaryPow, exp1::ARRAY_EXPRESSION, exp2::ARRAY_EXPRESSION)
  return _failedBinary(exp1, makePow(TYPE_UNKNOWN()), exp2, "evalBinaryPow")
end

"""`opFunc(scalar, element)` over every element of a (nested) array."""
function evalBinaryScalarArray(@nospecialize(scalarExp::Expression), @nospecialize(arrayExp::Expression), opFunc::FuncT)::Expression
  arrayExp isa ARRAY_EXPRESSION || return opFunc(scalarExp, arrayExp)
  return _mapElements((@nospecialize(e::Expression),) -> evalBinaryScalarArray(scalarExp, e, opFunc), arrayExp.elements, arrayExp.ty, true)
end

"""`opFunc(element, scalar)` over every element of a (nested) array."""
function evalBinaryArrayScalar(@nospecialize(arrayExp::Expression), @nospecialize(scalarExp::Expression), opFunc::FuncT)::Expression
  arrayExp isa ARRAY_EXPRESSION || return opFunc(arrayExp, scalarExp)
  return _mapElements(e -> evalBinaryArrayScalar(e, scalarExp, opFunc), arrayExp.elements, arrayExp.ty, true)
end

"""Whether a type is a two-dimensional array (a matrix)."""
_isMatrixType(ty::ModelicaType)::Bool = ty.tag == NFT_ARRAY && listLength(ty.dimensions) == 2

"""The vector type of a matrix's rows' count: `T[n]` for a matrix of type `T[n, m]`."""
_firstDimVectorType(ty::ModelicaType)::ModelicaType = TYPE_ARRAY(ty.elementType::ModelicaType, list(listHead(ty.dimensions)))

function evalBinaryMulVectorMatrix(@nospecialize(vectorExp::Expression), @nospecialize(matrixExp::Expression))::Expression
  local t::Expression = transposeArray(matrixExp)
  t isa ARRAY_EXPRESSION && _isMatrixType(t.ty) &&
    return _mapElements(e -> evalBinaryScalarProduct(vectorExp, e), t.elements, _firstDimVectorType(t.ty), true)
  return _failedBinary(vectorExp, makeMul(TYPE_UNKNOWN()), matrixExp, "evalBinaryMulVectorMatrix")
end

function evalBinaryMulMatrixVector(@nospecialize(matrixExp::Expression), @nospecialize(vectorExp::Expression))::Expression
  matrixExp isa ARRAY_EXPRESSION && _isMatrixType(matrixExp.ty) &&
    return _mapElements(e -> evalBinaryScalarProduct(e, vectorExp), matrixExp.elements, _firstDimVectorType(matrixExp.ty), true)
  return _failedBinary(matrixExp, makeMul(TYPE_UNKNOWN()), vectorExp, "evalBinaryMulMatrixVector")
end

"""
The kind of a scalar product of two literal vectors: 1 Integer (the first vector's element type
Integer and every element an Integer), 2 Real (every element an Integer or a Real), 0 neither
(record elements: the product element by element).
"""
function _numericProductKind(a::Vector{Expression}, b::Vector{Expression}, integerElements::Bool)::Int
  local allInt::Bool = integerElements
  for v in (a, b), e in v
    if e isa REAL_EXPRESSION
      allInt = false
    elseif !(e isa INTEGER_EXPRESSION)
      return 0
    end
  end
  return allInt ? 1 : 2
end

_asReal(@nospecialize(e::Expression))::Float64 = e isa INTEGER_EXPRESSION ? Float64(_intOf(e)) : _realOf(e)

"""
The scalar product of two literal vectors, summed in order from zero as the element-by-element
evaluation (`0 + a[1]*b[1] + a[2]*b[2] + ...`), on the values: no expression per product and sum.
"""
function evalBinaryScalarProduct(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  if !(exp1 isa ARRAY_EXPRESSION && exp2 isa ARRAY_EXPRESSION && exp1.ty.tag == NFT_ARRAY &&
       length(exp1.elements) == length(exp2.elements))
    return _failedBinary(exp1, makeMul(TYPE_UNKNOWN()), exp2, "evalBinaryScalarProduct")
  end
  local a::Vector{Expression} = exp1.elements
  local b::Vector{Expression} = exp2.elements
  local elemTy::ModelicaType = exp1.ty.elementType::ModelicaType
  local kind::Int = _numericProductKind(a, b, isInteger(elemTy))
  if kind == 1
    local si::Int = 0
    for i in eachindex(a)
      si = si + _intOf(a[i]) * _intOf(b[i])
    end
    return INTEGER_EXPRESSION(si)
  elseif kind == 2
    local sr::Float64 = 0.0
    for i in eachindex(a)
      sr = sr + _asReal(a[i]) * _asReal(b[i])
    end
    return REAL_EXPRESSION(sr)
  end
  local exp::Expression = makeZero(elemTy)
  for i in eachindex(a)
    local p::Expression = evalBinaryMul(a[i], b[i])
    p isa EVAL_FAILURE && return p
    exp = evalBinaryAdd(exp, p)
    exp isa EVAL_FAILURE && return exp
  end
  return exp
end

function evalBinaryMatrixProduct(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  local e2::Expression = transposeArray(exp2)
  if !(exp1 isa ARRAY_EXPRESSION && e2 isa ARRAY_EXPRESSION && _isMatrixType(exp1.ty) && _isMatrixType(e2.ty))
    return _failedBinary(exp1, makeMul(TYPE_UNKNOWN()), exp2, "evalBinaryMatrixProduct")
  end
  local elem_ty::ModelicaType = exp1.ty.elementType::ModelicaType
  local p::Dimension = listHead(e2.ty.dimensions)
  local mat_ty::ModelicaType = TYPE_ARRAY(elem_ty, list(listHead(exp1.ty.dimensions), p))
  isempty(e2.elements) && return makeZero(mat_ty)
  local row_ty::ModelicaType = TYPE_ARRAY(elem_ty, list(p))
  local cols::Vector{Expression} = e2.elements
  return _mapElements(r -> _mapElements(c -> evalBinaryScalarProduct(r, c), cols, row_ty, true), exp1.elements, mat_ty, true)
end

function evalBinaryPowMatrix(@nospecialize(matrixExp::Expression), @nospecialize(nExp::Expression))::Expression
  nExp isa INTEGER_EXPRESSION || return _failedBinary(matrixExp, makePow(TYPE_UNKNOWN()), nExp, "evalBinaryPowMatrix")
  _intOf(nExp) == 0 && matrixExp isa ARRAY_EXPRESSION &&
    return makeIdentityMatrix(size(listHead(arrayDims(matrixExp.ty))), TYPE_REAL())
  return evalBinaryPowMatrix2(matrixExp, _intOf(nExp))
end

"""A^n by squaring: A^1 = A, A^(2m) = A^m * A^m, A^n = A * A^(n-1)."""
function evalBinaryPowMatrix2(@nospecialize(matrix::Expression), n::Int)::Expression
  n == 1 && return matrix
  n == 2 && return evalBinaryMatrixProduct(matrix, matrix)
  if iseven(n)
    local half::Expression = evalBinaryPowMatrix2(matrix, n ÷ 2)
    half isa EVAL_FAILURE && return half
    return evalBinaryMatrixProduct(half, half)
  end
  local rest::Expression = evalBinaryPowMatrix2(matrix, n - 1)
  rest isa EVAL_FAILURE && return rest
  return evalBinaryMatrixProduct(matrix, rest)
end

function evalUnaryOp(@nospecialize(exp1::Expression), op::OPERATOR)::Expression
  op.op == Op.UMINUS && return _bindingExpMapEval(exp1, evalUnaryMinus)
  Error.addInternalError("evalUnaryOp: unimplemented case for " + toString(UNARY_EXPRESSION(op, exp1)),
                         sourceInfo())
  return EVAL_FAILED
end

function evalUnaryMinus(@nospecialize(exp1::Expression))::Expression
  exp1 isa INTEGER_EXPRESSION && return INTEGER_EXPRESSION(-_intOf(exp1))
  exp1 isa REAL_EXPRESSION && return REAL_EXPRESSION(-_realOf(exp1))
  exp1 isa ARRAY_EXPRESSION && return _mapElements(evalUnaryMinus, exp1.elements, exp1.ty, exp1.literal)
  printFailedEvalError("evalUnaryMinus", UNARY_EXPRESSION(makeUMinus(TYPE_UNKNOWN()), exp1), sourceInfo())
  return EVAL_FAILED
end

function evalLogicBinaryOp(
  @nospecialize(exp1::Expression),
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  @nospecialize(target::EvalTarget = EVALTARGET_IGNORE_ERRORS()),
)::Expression
  local (max_prop_exp::Expression, max_prop_count::Int) = mostPropagatedSubExpBinary(exp1, exp2)
  max_prop_count >= 0 || return evalLogicBinaryOp_dispatch(exp1, op, exp2, target)
  #= The second operand evaluated first, so that it too is taken per element: evaluated
     lazily, within each element's pass, it was the whole array again, a cross product
     (Buildings' movers over per[nPum]: `sum(pressure.V_flow) > eps and sum(pressure.dp) >
     eps` gave {{true, true}, {true, true}}). Where it cannot be evaluated, lazily as before
     (its messages dropped). =#
  ErrorExt.setCheckpoint("NFCeval.evalLogicBinaryOp")
  local e2::Expression = evalExp_impl(exp2, target)
  if e2 isa EVAL_FAILURE
    ErrorExt.rollBack("NFCeval.evalLogicBinaryOp")
  else
    ErrorExt.delCheckpoint("NFCeval.evalLogicBinaryOp")
    exp2 = e2
    (max_prop_exp, max_prop_count) = mostPropagatedSubExpBinary(exp1, exp2)
  end
  return _bindingExpMap2Eval(LBINARY_EXPRESSION(exp1, op, exp2),
                             (x) -> evalLogicBinaryExp(x::LBINARY_EXPRESSION, target),
                             max_prop_count, max_prop_exp)
end

evalLogicBinaryExp(b::LBINARY_EXPRESSION, @nospecialize(target::EvalTarget))::Expression =
  evalLogicBinaryOp_dispatch(b.exp1, b.operator, b.exp2, target)

function evalLogicBinaryOp_dispatch(
  @nospecialize(exp1::Expression),
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  @nospecialize(target::EvalTarget),
)::Expression
  if op.op == Op.AND || op.op == Op.OR
    local e1::Expression = _evalValue(exp1, target)
    e1 isa EVAL_FAILURE && return e1
    return op.op == Op.AND ? evalLogicBinaryAnd(e1, exp2, target) : evalLogicBinaryOr(e1, exp2, target)
  end
  Error.addInternalError("evalLogicBinaryOp_dispatch: unimplemented case for " + toString(LBINARY_EXPRESSION(exp1, op, exp2)),
                         sourceInfo())
  return EVAL_FAILED
end

"""`exp1 and exp2`, `exp2` evaluated only when needed (short circuit)."""
function evalLogicBinaryAnd(
  @nospecialize(exp1::Expression),
  @nospecialize(exp2::Expression),
  @nospecialize(target::EvalTarget),
)::Expression
  exp1 isa BOOLEAN_EXPRESSION && return exp1.value ? evalExp_impl(exp2, target) : exp1
  exp1 isa ARRAY_EXPRESSION && return _evalLogicArrays(exp1, exp2, target, evalLogicBinaryAnd)
  printFailedEvalError("evalLogicBinaryAnd", LBINARY_EXPRESSION(exp1, makeAnd(TYPE_UNKNOWN()), exp2), sourceInfo())
  return EVAL_FAILED
end

"""`exp1 or exp2`, `exp2` evaluated only when needed (short circuit)."""
function evalLogicBinaryOr(
  @nospecialize(exp1::Expression),
  @nospecialize(exp2::Expression),
  @nospecialize(target::EvalTarget),
)::Expression
  exp1 isa BOOLEAN_EXPRESSION && return exp1.value ? exp1 : evalExp_impl(exp2, target)
  exp1 isa ARRAY_EXPRESSION && return _evalLogicArrays(exp1, exp2, target, evalLogicBinaryOr)
  printFailedEvalError("evalLogicBinaryOr", LBINARY_EXPRESSION(exp1, makeOr(TYPE_UNKNOWN()), exp2), sourceInfo())
  return EVAL_FAILED
end

"""A logical operation element by element on an array and the (evaluated) array `exp2`."""
function _evalLogicArrays(exp1::ARRAY_EXPRESSION, @nospecialize(exp2::Expression), @nospecialize(target::EvalTarget),
                          f::F)::Expression where {F}
  local a2::Expression = evalExp_impl(exp2, target)
  a2 isa EVAL_FAILURE && return a2
  a2 isa ARRAY_EXPRESSION || return EVAL_FAILED
  local n::Int = min(length(exp1.elements), length(a2.elements))
  local expl::Vector{Expression} = Vector{Expression}(undef, n)
  for i in 1:n
    local e::Expression = f(exp1.elements[i], a2.elements[i], target)
    e isa EVAL_FAILURE && return e
    expl[i] = e
  end
  return makeArray(setArrayElementType(exp1.ty, TYPE_BOOLEAN()), expl, literal = true)
end

function evalLogicUnaryOp(@nospecialize(exp1::Expression), op::OPERATOR)::Expression
  op.op == Op.NOT && return _bindingExpMapEval(exp1, evalLogicUnaryNot)
  Error.addInternalError("evalLogicUnaryOp: unimplemented case for " + toString(LUNARY_EXPRESSION(op, exp1)),
                         sourceInfo())
  return EVAL_FAILED
end

function evalLogicUnaryNot(@nospecialize(exp1::Expression))::Expression
  exp1 isa BOOLEAN_EXPRESSION && return BOOLEAN_EXPRESSION(!_boolOf(exp1))
  exp1 isa ARRAY_EXPRESSION && return _mapElements(evalLogicUnaryNot, exp1.elements, exp1.ty, exp1.literal)
  printFailedEvalError("evalLogicUnaryNot", LUNARY_EXPRESSION(makeNot(TYPE_UNKNOWN()), exp1), sourceInfo())
  return EVAL_FAILED
end

function evalRelationOp(@nospecialize(exp1::Expression), op::OPERATOR, @nospecialize(exp2::Expression))::Expression
  local (max_prop_exp::Expression, max_prop_count::Int) = mostPropagatedSubExpBinary(exp1, exp2)
  max_prop_count >= 0 || return evalRelationOp_dispatch(exp1, op, exp2)
  return _bindingExpMap2Eval(RELATION_EXPRESSION(exp1, op, exp2), (x) -> evalRelationExp(x::RELATION_EXPRESSION),
                             max_prop_count, max_prop_exp)
end

evalRelationExp(r::RELATION_EXPRESSION)::Expression = evalRelationOp_dispatch(r.exp1, r.operator, r.exp2)

"""A relation of two literals: `BOOLEAN_EXPRESSION`, or `EVAL_FAILED` for other operands."""
function evalRelationOp_dispatch(
  @nospecialize(exp1::Expression),
  op::OPERATOR,
  @nospecialize(exp2::Expression),
)::Expression
  local o::Int = op.op
  if !(o == Op.LESS || o == Op.LESSEQ || o == Op.GREATER || o == Op.GREATEREQ || o == Op.EQUAL || o == Op.NEQUAL)
    Error.addInternalError("evalRelationOp_dispatch: unimplemented case for " + toString(RELATION_EXPRESSION(exp1, op, exp2)),
                           sourceInfo())
    return EVAL_FAILED
  end
  local (ok::Bool, res::Bool) = _relation(o, exp1, exp2)
  if !ok
    printFailedEvalError("evalRelationOp_dispatch", RELATION_EXPRESSION(exp1, OPERATOR(TYPE_UNKNOWN(), o), exp2), sourceInfo())
    return EVAL_FAILED
  end
  return BOOLEAN_EXPRESSION(res)
end

"""
The values of literal expressions, typed: read through the abstract `Expression` (the matched tuple's elements are not
narrowed), `exp1.value > exp2.value` was a dynamic `>(::Any, ::Any)`, and packages adding comparison methods
(CommonWorldInvalidations, Symbolics) invalidated the evaluators and their 1507 callers at each load (2026-11-16).
The frontend makes Integer literals of `Int` and Real ones of `Float64`.
"""
_intOf(e::Expression)::Int = (e::INTEGER_EXPRESSION).value::Int
_realOf(e::Expression)::Float64 = (e::REAL_EXPRESSION).value::Float64
_boolOf(e::Expression)::Bool = (e::BOOLEAN_EXPRESSION).value::Bool
_stringOf(e::Expression)::String = (e::STRING_EXPRESSION).value::String
_enumIndexOf(e::Expression)::Int = (e::ENUM_LITERAL_EXPRESSION).index

"""`a op b` for one relational operator (an `Op` value) on two values of one type."""
@inline function _relate(o::Int, a::T, b::T)::Bool where {T}
  o == Op.LESS && return a < b
  o == Op.LESSEQ && return a <= b
  o == Op.GREATER && return a > b
  o == Op.GREATEREQ && return a >= b
  o == Op.EQUAL && return a == b
  return a != b
end

"""
A relation of two literals of the same kind (an Integer with a Real compared as Reals):
`(true, result)`, or `(false, false)` for other operands.
"""
function _relation(o::Int, @nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Tuple{Bool, Bool}
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  exp1 isa INTEGER_EXPRESSION && exp2 isa INTEGER_EXPRESSION && return (true, _relate(o, _intOf(exp1), _intOf(exp2)))
  exp1 isa REAL_EXPRESSION && exp2 isa REAL_EXPRESSION && return (true, _relate(o, _realOf(exp1), _realOf(exp2)))
  exp1 isa BOOLEAN_EXPRESSION && exp2 isa BOOLEAN_EXPRESSION && return (true, _relate(o, _boolOf(exp1), _boolOf(exp2)))
  exp1 isa STRING_EXPRESSION && exp2 isa STRING_EXPRESSION &&
    return (true, _relate(o, stringCompare(_stringOf(exp1), _stringOf(exp2)), 0))
  exp1 isa ENUM_LITERAL_EXPRESSION && exp2 isa ENUM_LITERAL_EXPRESSION &&
    return (true, _relate(o, _enumIndexOf(exp1), _enumIndexOf(exp2)))
  return (false, false)
end

function evalIfExp(e::IF_EXPRESSION, @nospecialize(target::EvalTarget))::Expression
  local cond::Expression = evalExp_impl(e.condition, target)
  cond isa EVAL_FAILURE && return cond
  return _bindingExpMapEval(IF_EXPRESSION(cond, e.trueBranch, e.falseBranch), (x) -> evalIfExp2(x::IF_EXPRESSION, target))
end

function evalIfExp2(e::IF_EXPRESSION, @nospecialize(target::EvalTarget))::Expression
  local cond::Expression = e.condition
  cond isa BOOLEAN_EXPRESSION && return evalExp_impl(cond.value ? e.trueBranch : e.falseBranch, target)
  Error.addInternalError("evalIfExp2: unimplemented case for " + toString(e), sourceInfo())
  return EVAL_FAILED
end

"""The value cast to `castTy`; `EVAL_FAILED` when typeCast cannot (it returns a CAST then)."""
function evalCast(@nospecialize(castExp::Expression), castTy::ModelicaType)::Expression
  local exp::Expression = typeCast(castExp, castTy)
  exp isa CAST_EXPRESSION || return exp
  printFailedEvalError("evalCast", CAST_EXPRESSION(castTy, castExp), sourceInfo())
  return EVAL_FAILED
end

"""A typed call: its arguments evaluated, then the builtin (`ceval`) or the function (NFEvalFunction)."""
@nospecializeinfer function evalCall(c::Call, target::EvalTarget)::Expression
  if isvariant(c, TYPED_CALL)
    local args0::Vector{Expression} = c.arguments::Vector{Expression}
    local cArgs::Vector{Expression} = args0
    for i in eachindex(args0)
      local a::Expression = evalExp_impl(args0[i], target)
      a isa EVAL_FAILURE && return a
      if !referenceEq(a, args0[i])
        cArgs === args0 && (cArgs = copy(args0))
        cArgs[i] = a
      end
    end
    cArgs === args0 || (c = TYPED_CALL(c.fn, c.ty, c.var, cArgs, c.attributes))
    isBuiltin(c.fn) && return _bindingExpMapEval(CALL_EXPRESSION(c), @closure (x) -> evalBuiltinCallExp(x::CALL_EXPRESSION, target))
    return _bindingExpMapEval(CALL_EXPRESSION(c), (x) -> evalNormalCallExp(x::CALL_EXPRESSION))
  end
  isvariant(c, TYPED_ARRAY_CONSTRUCTOR) && return evalArrayConstructor(c.exp, c.iters)
  isvariant(c, TYPED_REDUCTION) && return evalReduction(c.fn, c.exp, c.iters)
  Error.addInternalError("evalCall got untyped call", sourceInfo())
  return EVAL_FAILED
end

"""A builtin call with evaluated arguments (omc evalBuiltinCallExp)."""
function evalBuiltinCallExp(callExp::CALL_EXPRESSION, @nospecialize(target::EvalTarget))::Expression
  local call::Call = callExp.call
  return ceval(call.fn, call.arguments::Vector{Expression}, target)
end

"""A builtin function's call with evaluated arguments, by the function's name."""
function ceval(fn::MODELICA_FUNCTION, args::Vector{Expression}, @nospecialize(target::EvalTarget))::Expression
  local fn_path::Absyn.Path = nameConsiderBuiltin(fn)
  return @match AbsynUtil.pathFirstIdent(fn_path) begin
    "abs" => evalBuiltinAbs(Base.first(args))
    "acos" => evalBuiltinAcos(Base.first(args), target)
    "array" => evalBuiltinArray(args)
    "asin" => evalBuiltinAsin(Base.first(args), target)
    "atan2" => evalBuiltinAtan2(args)
    "atan" => evalBuiltinAtan(Base.first(args))
    "cat" => evalBuiltinCat(Base.first(args), args[2:end], target)
    "ceil" => evalBuiltinCeil(Base.first(args))
    "cosh" => evalBuiltinCosh(Base.first(args))
    "cos" => evalBuiltinCos(Base.first(args))
    "der" => evalBuiltinDer(Base.first(args))
    "diagonal" => evalBuiltinDiagonal(unbox(Base.first(args)))
    "div" => evalBuiltinDiv(args, target)
    "exp" => evalBuiltinExp(Base.first(args))
    "fill" => evalBuiltinFill(args)
    "floor" => evalBuiltinFloor(Base.first(args))
    "identity" => evalBuiltinIdentity(Base.first(args))
    "integer" => evalBuiltinInteger(Base.first(args))
    "Integer" => evalBuiltinIntegerEnum(Base.first(args))
    "log10" => evalBuiltinLog10(Base.first(args), target)
    "log" => evalBuiltinLog(Base.first(args), target)
    "matrix" => evalBuiltinMatrix(Base.first(args))
    "max" => evalBuiltinMax(args, fn)
    "min" => evalBuiltinMin(args, fn)
    "mod" => evalBuiltinMod(args, target)
    "noEvent" => Base.first(args)
    "ones" => evalBuiltinOnes(args)
    "product" => evalBuiltinProduct(Base.first(args))
    "promote" => evalBuiltinPromote(args[1], args[2])
    "rem" => evalBuiltinRem(args, target)
    "scalar" => evalBuiltinScalar(args)
    "sign" => evalBuiltinSign(Base.first(args))
    "sinh" => evalBuiltinSinh(Base.first(args))
    "sin" => evalBuiltinSin(Base.first(args))
    "skew" => evalBuiltinSkew(Base.first(args))
    "smooth" => args[2]
    "sqrt" => evalBuiltinSqrt(Base.first(args))
    "String" => evalBuiltinString(args)
    "sum" => evalBuiltinSum(Base.first(args))
    "symmetric" => evalBuiltinSymmetric(Base.first(args))
    "tanh" => evalBuiltinTanh(Base.first(args))
    "tan" => evalBuiltinTan(Base.first(args))
    "transpose" => evalBuiltinTranspose(Base.first(args))
    "vector" => evalBuiltinVector(Base.first(args))
    "zeros" => evalBuiltinZeros(args)
    "OpenModelica_uriToFilename" => evalUriToFilename(fn, args, target)
    "intBitAnd" => evalIntBitAnd(args)
    "intBitOr" => evalIntBitOr(args)
    "intBitXor" => evalIntBitXor(args)
    "intBitLShift" => evalIntBitLShift(args)
    "intBitRShift" => evalIntBitRShift(args)
    "inferredClock" => evalInferredClock(args)
    "rationalClock" => evalRationalClock(args)
    "realClock" => evalRealClock(args)
    "booleanClock" => evalBooleanClock(args)
    "solverClock" => evalSolverClock(args)
    "DynamicSelect" => evalBuiltinDynamicSelect(fn, args, target)
    _ => begin
      Error.addInternalError("ceval: unimplemented case for " + AbsynUtil.pathString(fn_path), sourceInfo())
      EVAL_FAILED
    end
  end
end

"""A call of a user-defined function with evaluated arguments."""
function evalNormalCallExp(callExp::CALL_EXPRESSION)::Expression
  local call::Call = callExp.call
  return evalNormalCall(call.fn, call.arguments::Vector{Expression})
end

"""
    evalNormalCall(fn, args) -> Expression
A user-defined function's call evaluated (NFEvalFunction), or `EVAL_FAILED`. NFEvalFunction still reports a
function it cannot evaluate by throwing (`fail()`, its own catch-all): this is the boundary where that becomes
the evaluation's failure, until NFEvalFunction returns its failures too.
"""
function evalNormalCall(fn::MODELICA_FUNCTION, args::Vector{Expression})::Expression
  try
    return evaluate(fn, args)::Expression
  catch e
    e isa InterruptException && rethrow()
    return EVAL_FAILED
  end
end

"""The wrong-arguments error of builtin `name`; `EVAL_FAILED`."""
function _wrongArgs(name::String, args::Union{List{Expression}, Vector{Expression}})::Expression
  printWrongArgsError(name, args, sourceInfo())
  return EVAL_FAILED
end
_wrongArgs(name::String, @nospecialize(arg::Expression))::Expression = _wrongArgs(name, Expression[arg])

"""An argument out of the range of builtin `name` (`range`), reported when the target has a source position; `EVAL_FAILED`."""
function _outOfRange(name::String, x::String, range::String, @nospecialize(target::EvalTarget))::Expression
  hasInfo(target) && Error.addSourceMessage(Error.ARGUMENT_OUT_OF_RANGE, list(x, name, range), EvalTarget_getInfo(target))
  return EVAL_FAILED
end

"""`f(x)` of a Real argument as a Real; else the wrong-arguments error of builtin `name`."""
function _realFunc(f::F, @nospecialize(arg::Expression), name::String)::Expression where {F<:Function}
  arg isa REAL_EXPRESSION || return _wrongArgs(name, arg)
  return REAL_EXPRESSION(f(arg.value))
end

"""`f(x)` of a Real argument with `inDomain(x)`; out of the domain the range error (`range`)."""
function _realFuncInDomain(f::F, inDomain::D, @nospecialize(arg::Expression), name::String, range::String,
                           @nospecialize(target::EvalTarget))::Expression where {F<:Function, D<:Function}
  arg isa REAL_EXPRESSION || return _wrongArgs(name, arg)
  local x::Float64 = arg.value
  inDomain(x) || return _outOfRange(name, string(x), range, target)
  return REAL_EXPRESSION(f(x))
end

"""
`fi(x, y)` of two Integers, `fr(x, y)` of two Reals (div, mod, rem); a zero divisor gives `msg`
when the target has a source position.
"""
function _evalIntRealDivision(fi::FI, fr::FR, args::Vector{Expression}, name::String, msg::ErrorTypes.Message,
                              @nospecialize(target::EvalTarget))::Expression where {FI<:Function, FR<:Function}
  length(args) == 2 || return _wrongArgs(name, args)
  local (x::Expression, y::Expression) = (args[1], args[2])
  local zero_divisor::Bool
  local result::Expression
  if x isa INTEGER_EXPRESSION && y isa INTEGER_EXPRESSION
    zero_divisor = y.value == 0
    zero_divisor || (result = INTEGER_EXPRESSION(fi(x.value, y.value)))
  elseif x isa REAL_EXPRESSION && y isa REAL_EXPRESSION
    zero_divisor = y.value == 0.0
    zero_divisor || (result = REAL_EXPRESSION(fr(x.value, y.value)))
  else
    return _wrongArgs(name, args)
  end
  zero_divisor || return result
  hasInfo(target) && Error.addSourceMessage(msg, list(_numberString(x), _numberString(y)), EvalTarget_getInfo(target))
  return EVAL_FAILED
end

"""The value of an Integer or Real literal as `string` writes it (for messages)."""
_numberString(@nospecialize(e::Expression))::String = e isa INTEGER_EXPRESSION ? string(e.value) : string((e::REAL_EXPRESSION).value)

function evalBuiltinAbs(@nospecialize(arg::Expression))::Expression
  arg isa INTEGER_EXPRESSION && return INTEGER_EXPRESSION(abs(arg.value))
  return _realFunc(abs, arg, "abs")
end

evalBuiltinAcos(@nospecialize(arg::Expression), @nospecialize(target::EvalTarget))::Expression =
  _realFuncInDomain(acos, x -> -1.0 <= x <= 1.0, arg, "acos", "-1 <= x <= 1", target)

function evalBuiltinArray(args::Union{List{Expression}, Vector{Expression}})::Expression
  local ty::ModelicaType = liftArrayLeft(typeOf(Base.first(args)), fromInteger(length(args)))
  return makeArray(ty, args, literal = true)
end

evalBuiltinAsin(@nospecialize(arg::Expression), @nospecialize(target::EvalTarget))::Expression =
  _realFuncInDomain(asin, x -> -1.0 <= x <= 1.0, arg, "asin", "-1 <= x <= 1", target)

function evalBuiltinAtan2(args::Union{List{Expression}, Vector{Expression}})::Expression
  (length(args) == 2 && Base.first(args) isa REAL_EXPRESSION && Base.last(args) isa REAL_EXPRESSION) ||
    return _wrongArgs("atan2", args)
  return REAL_EXPRESSION(atan(_realOf(Base.first(args)), _realOf(Base.last(args))))
end

evalBuiltinAtan(@nospecialize(arg::Expression))::Expression = _realFunc(atan, arg, "atan")

function evalBuiltinCat(@nospecialize(argN::Expression), args::Vector{Expression}, @nospecialize(target::EvalTarget))::Expression
  argN isa INTEGER_EXPRESSION || return _wrongArgs("cat", argN)
  local n::Int = argN.value
  local nd::Int = dimensionCount(typeOf(Base.first(args)))
  (1 <= n <= nd) || return _outOfRange("cat", string(n), "1 <= x <= " + string(nd), target)
  local es::Vector{Expression} = Expression[]
  for e in args
    isEmptyArray(e) || push!(es, e)
  end
  isempty(es) && return Base.first(args)
  length(es) == 1 && return Base.first(es)
  #= A ragged argument, or one that is no array along the first dimension: not evaluated (no message). =#
  n > 1 && !_allCatPartsRegular(es, n) && return EVAL_FAILED
  n == 1 && !_allArrays(es) && return EVAL_FAILED
  local dims::List{Int}
  (es, dims) = evalCat(n, es)
  local dim_list::List{Dimension} = nil
  for d in listReverse(dims)
    dim_list = Cons{Dimension}(fromInteger(d), dim_list)
  end
  return arrayFromVector(es, typeOf(Base.first(es)), dim_list)
end

evalBuiltinCeil(@nospecialize(arg::Expression))::Expression = _realFunc(ceil, arg, "ceil")
evalBuiltinCosh(@nospecialize(arg::Expression))::Expression = _realFunc(cosh, arg, "cosh")

"""
    roundingZero(value, arg)

A sine, cosine or tangent value within its argument's rounding of zero is zero: the argument is
a multiple of π (of π/2 for the cosine) up to the rounding of its own computation. sin(2π) gave
-2.4e-16, and MSL's symmetrical-component matrices folded such values into equation coefficients
(QuasiStatic IMC_DOL's zero-sequence current, `-1.6e-16 * i[3].im`) that tearing then divided by.
"""
function roundingZero(value::T, arg::T)::T where {T <: AbstractFloat}
  return abs(value) <= 4 * eps(arg) ? zero(T) : value
end

evalBuiltinCos(@nospecialize(arg::Expression))::Expression = _realFunc(x -> roundingZero(cos(x), x), arg, "cos")

evalBuiltinDer(@nospecialize(arg::Expression))::Expression = fillType(typeOf(arg), REAL_EXPRESSION(0.0))

"""`diagonal(v)`: the square matrix with `v` on its diagonal, zero elsewhere."""
function evalBuiltinDiagonal(@nospecialize(arg::Expression))::Expression
  arg isa ARRAY_EXPRESSION || return _wrongArgs("diagonal", arg)
  local elems::Vector{Expression} = arg.elements
  isempty(elems) && return arg
  local n::Int = length(elems)
  local elem_ty::ModelicaType = typeOf(elems[1])
  local row_ty::ModelicaType = liftArrayLeft(elem_ty, fromInteger(n))
  local zero::Expression = makeZero(elem_ty)
  local rows::Vector{Expression} = Vector{Expression}(undef, n)
  local arg_lit::Bool = true
  for i in 1:n
    local e_lit::Bool = isLiteral(elems[i])
    arg_lit = arg_lit && e_lit
    rows[i] = ARRAY_EXPRESSION(row_ty, Expression[j == i ? elems[i] : zero for j in 1:n], e_lit)
  end
  return ARRAY_EXPRESSION(liftArrayLeft(row_ty, fromInteger(n)), rows, arg_lit)
end

"""`div(x, y)`: the quotient truncated towards zero."""
evalBuiltinDiv(args::Vector{Expression}, @nospecialize(target::EvalTarget))::Expression =
  _evalIntRealDivision(intDiv, (x, y) -> trunc(x / y), args, "div", Error.DIVISION_BY_ZERO, target)

evalBuiltinExp(@nospecialize(arg::Expression))::Expression = _realFunc(exp, arg, "exp")

evalBuiltinFill(args::Vector{Expression})::Expression = evalBuiltinFill2(Base.first(args), @view args[2:end])

function evalBuiltinFill2(@nospecialize(fillValue::Expression),
                          dims::Union{Vector{Expression}, List{Expression}, SubArray{Expression}})::Expression
  local result::Expression = fillValue
  local arr_ty::ModelicaType = typeOf(result)
  local literal::Bool = isLiteral(fillValue)
  for d in reverse(dims)
    d isa INTEGER_EXPRESSION || return _wrongArgs("fill", d)
    arr_ty = liftArrayLeft(arr_ty, fromInteger(d.value))
    result = makeArray(arr_ty, Expression[result for _ in 1:d.value]; literal = literal)
  end
  return result
end

evalBuiltinFloor(@nospecialize(arg::Expression))::Expression = _realFunc(floor, arg, "floor")

function evalBuiltinIdentity(@nospecialize(arg::Expression))::Expression
  arg isa INTEGER_EXPRESSION || return _wrongArgs("identity", arg)
  return makeIdentityMatrix(arg.value, TYPE_INTEGER())
end

function evalBuiltinInteger(@nospecialize(arg::Expression))::Expression
  arg isa INTEGER_EXPRESSION && return arg
  arg isa REAL_EXPRESSION && return INTEGER_EXPRESSION(realInt(arg.value))
  return _wrongArgs("integer", arg)
end

function evalBuiltinIntegerEnum(@nospecialize(arg::Expression))::Expression
  arg isa ENUM_LITERAL_EXPRESSION || return _wrongArgs("Integer", arg)
  return INTEGER_EXPRESSION(arg.index)
end

evalBuiltinLog10(@nospecialize(arg::Expression), @nospecialize(target::EvalTarget))::Expression =
  _realFuncInDomain(log10, x -> x > 0.0, arg, "log10", "x > 0", target)

evalBuiltinLog(@nospecialize(arg::Expression), @nospecialize(target::EvalTarget))::Expression =
  _realFuncInDomain(log, x -> x > 0.0, arg, "log", "x > 0", target)

"""`matrix(A)`: a scalar or vector promoted to two dimensions; an array of more, its trailing dimensions (of size one) dropped."""
function evalBuiltinMatrix(@nospecialize(arg::Expression))::Expression
  if !(arg isa ARRAY_EXPRESSION)
    isScalar(typeOf(arg)) && return promote(arg, typeOf(arg), 2)[1]
    return _wrongArgs("matrix", arg)
  end
  local ty::ModelicaType = arg.ty
  local dim_count::Int = dimensionCount(ty)
  dim_count < 2 && return promote(arg, ty, 2)[1]
  dim_count == 2 && return arg
  local dims::List{Dimension} = arrayDims(ty)
  local row_ty::ModelicaType = liftArrayLeft(arrayElementType(ty), listHead(listRest(dims)))
  return _mapElements(e -> evalBuiltinMatrix2(e, row_ty), arg.elements, liftArrayLeft(row_ty, listHead(dims)), false)
end

function evalBuiltinMatrix2(@nospecialize(arg::Expression), ty::ModelicaType)::Expression
  arg isa ARRAY_EXPRESSION || return _wrongArgs("matrix", arg)
  return ARRAY_EXPRESSION(ty, Expression[toScalar(e) for e in arg.elements], arg.literal)
end

"""
    foldArrayElements(exp, func, acc, ArgT) -> ArgT

`func(element, acc)::ArgT` over the scalar elements of an evaluated (nested) array in order, for the array
reductions (min, max, sum, product, vector). A walk over the elements only: `fold` compiles a large method per
callback and visits every subexpression.
"""
function foldArrayElements(@nospecialize(exp::Expression), func::FT, acc::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}
  if exp isa ARRAY_EXPRESSION
    for e in exp.elements
      acc = foldArrayElements(e, func, acc, ArgT)
    end
    return acc
  end
  return func(exp, acc)::ArgT
end

"""
    allArrayElementsAre(exp, T) -> Bool
Whether every scalar element of an evaluated (nested) array is a `T`: the check before a fold that
reads the elements' values (sum, product).
"""
function allArrayElementsAre(@nospecialize(exp::Expression), ::Type{T})::Bool where {T<:Expression}
  if exp isa ARRAY_EXPRESSION
    for e in exp.elements
      allArrayElementsAre(e, T) || return false
    end
    return true
  end
  return exp isa T
end

"""
`max(a, b)`/`min(a, b)` of two scalars, or `max(A)`/`min(A)` over the elements of an array; of an
empty array the call itself.
"""
function _evalBuiltinMinMax(args::Vector{Expression}, fn::MODELICA_FUNCTION, isMax::Bool)::Expression
  length(args) == 2 && return _evalBuiltinMinMax2(args[1], args[2], isMax)
  (length(args) == 1 && args[1] isa ARRAY_EXPRESSION) || return _wrongArgs(isMax ? "max" : "min", args)
  local ty::ModelicaType = args[1].ty
  local result::Expression = foldArrayElements(args[1],
    (e, acc) -> acc isa EVAL_FAILURE ? acc : _evalBuiltinMinMax2(e, acc, isMax), EMPTY_EXPRESSION(ty), Expression)
  result isa EMPTY_EXPRESSION || return result
  return CALL_EXPRESSION(makeTypedCall(fn, Expression[makeEmptyArray(ty)], Variability.CONSTANT, arrayElementType(ty)))
end

evalBuiltinMax(args::Vector{Expression}, fn::MODELICA_FUNCTION)::Expression = _evalBuiltinMinMax(args, fn, true)
evalBuiltinMin(args::Vector{Expression}, fn::MODELICA_FUNCTION)::Expression = _evalBuiltinMinMax(args, fn, false)

"""Whether `max`/`min` (`isMax`) of `a` and `b` is `b`."""
@inline _takesSecond(a::T, b::T, isMax::Bool) where {T} = isMax ? a < b : a > b

function _evalBuiltinMinMax2(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression), isMax::Bool)::Expression
  exp1 isa INTEGER_EXPRESSION && exp2 isa INTEGER_EXPRESSION && return _takesSecond(exp1.value, exp2.value, isMax) ? exp2 : exp1
  exp1 isa REAL_EXPRESSION && exp2 isa REAL_EXPRESSION && return _takesSecond(exp1.value, exp2.value, isMax) ? exp2 : exp1
  exp1 isa BOOLEAN_EXPRESSION && exp2 isa BOOLEAN_EXPRESSION && return _takesSecond(exp1.value, exp2.value, isMax) ? exp2 : exp1
  exp1 isa ENUM_LITERAL_EXPRESSION && exp2 isa ENUM_LITERAL_EXPRESSION &&
    return _takesSecond(exp1.index, exp2.index, isMax) ? exp2 : exp1
  exp1 isa ARRAY_EXPRESSION && return exp2
  exp2 isa EMPTY_EXPRESSION && return exp1
  return _wrongArgs(isMax ? "max" : "min", Expression[exp1, exp2])
end

evalBuiltinMax2(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression = _evalBuiltinMinMax2(exp1, exp2, true)
evalBuiltinMin2(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression = _evalBuiltinMinMax2(exp1, exp2, false)

evalBuiltinMod(args::Vector{Expression}, @nospecialize(target::EvalTarget))::Expression =
  _evalIntRealDivision(mod, mod, args, "mod", Error.MODULO_BY_ZERO, target)

evalBuiltinOnes(args::Union{List{Expression}, Vector{Expression}})::Expression = evalBuiltinFill2(INTEGER_EXPRESSION(1), args)

"""`sum`/`product` of an array of Integers or Reals: `init` folded with `op` over the elements."""
function _evalArrayReduction(@nospecialize(arg::Expression), op::F, name::String, intInit::Int,
                             realInit::Float64)::Expression where {F<:Function}
  arg isa ARRAY_EXPRESSION || return _wrongArgs(name, arg)
  local el_ty::ModelicaType = arrayElementType(arg.ty)
  isvariant(el_ty, TYPE_INTEGER) && allArrayElementsAre(arg, INTEGER_EXPRESSION) &&
    return INTEGER_EXPRESSION(foldArrayElements(arg, (e, acc::Int) -> op(acc, _intOf(e)), intInit, Int))
  isvariant(el_ty, TYPE_REAL) && allArrayElementsAre(arg, REAL_EXPRESSION) &&
    return REAL_EXPRESSION(foldArrayElements(arg, (e, acc::Float64) -> op(acc, _realOf(e)), realInit, Float64))
  return _wrongArgs(name, arg)
end

evalBuiltinProduct(@nospecialize(arg::Expression))::Expression = _evalArrayReduction(arg, *, "product", 1, 1.0)

function evalBuiltinPromote(@nospecialize(arg::Expression), @nospecialize(argN::Expression))::Expression
  argN isa INTEGER_EXPRESSION || return _wrongArgs("promote", Expression[arg, argN])
  return promote(arg, typeOf(arg), argN.value)[1]
end

"""`rem(x, y)`: `x - div(x, y) * y`."""
evalBuiltinRem(args::Vector{Expression}, @nospecialize(target::EvalTarget))::Expression =
  _evalIntRealDivision((x, y) -> x - div(x, y) * y, (x, y) -> x - div(x, y) * y, args, "rem", Error.REM_ARG_ZERO, target)

function evalBuiltinScalar(args::Union{List{Expression}, Vector{Expression}})::Expression
  local exp::Expression = Base.first(args)
  return exp isa ARRAY_EXPRESSION ? evalBuiltinScalar(exp.elements) : exp
end

"""`sign(x)`: 1, -1 or 0 (also of NaN)."""
@inline _sign(x::T) where {T<:Real} = x > 0 ? 1 : x < 0 ? -1 : 0

function evalBuiltinSign(@nospecialize(arg::Expression))::Expression
  arg isa REAL_EXPRESSION && return INTEGER_EXPRESSION(_sign(arg.value))
  arg isa INTEGER_EXPRESSION && return INTEGER_EXPRESSION(_sign(arg.value))
  return _wrongArgs("sign", arg)
end

evalBuiltinSinh(@nospecialize(arg::Expression))::Expression = _realFunc(sinh, arg, "sinh")
evalBuiltinSin(@nospecialize(arg::Expression))::Expression = _realFunc(x -> roundingZero(sin(x), x), arg, "sin")

"""`skew(x)`: the skew-symmetric 3x3 matrix of a 3-vector."""
function evalBuiltinSkew(@nospecialize(arg::Expression))::Expression
  (arg isa ARRAY_EXPRESSION && length(arg.elements) == 3) || return _wrongArgs("skew", arg)
  local (x1::Expression, x2::Expression, x3::Expression) = (arg.elements[1], arg.elements[2], arg.elements[3])
  local ty::ModelicaType = arg.ty
  local zero::Expression = makeZero(arrayElementType(ty))
  local rows::Vector{Expression} = Expression[
    ARRAY_EXPRESSION(ty, Expression[zero, negate(x3), x2], arg.literal),
    ARRAY_EXPRESSION(ty, Expression[x3, zero, negate(x1)], arg.literal),
    ARRAY_EXPRESSION(ty, Expression[negate(x2), x1, zero], arg.literal)]
  return ARRAY_EXPRESSION(liftArrayLeft(ty, fromInteger(3)), rows, arg.literal)
end

evalBuiltinSqrt(@nospecialize(arg::Expression))::Expression = _realFunc(sqrt, arg, "sqrt")

"""
`String(value, minimumLength, leftJustified)` of an Integer, Boolean or enumeration literal,
`String(real, significantDigits, minimumLength, leftJustified)`, `String(real, format)`.
"""
function evalBuiltinString(args::Union{List{Expression}, Vector{Expression}})::Expression
  local n_args::Int = length(args)
  if n_args == 3 && args[2] isa INTEGER_EXPRESSION && args[3] isa BOOLEAN_EXPRESSION
    local arg::Expression = args[1]
    local str::String
    if arg isa INTEGER_EXPRESSION
      str = intString(arg.value)
    elseif arg isa BOOLEAN_EXPRESSION
      str = boolString(arg.value)
    elseif arg isa ENUM_LITERAL_EXPRESSION
      str = arg.name
    else
      return _wrongArgs("String", args)
    end
    local pad::Int = args[2].value - length(str)
    pad > 0 && (str = args[3].value ? str * " "^pad : " "^pad * str)
    return STRING_EXPRESSION(str)
  elseif n_args == 4 && args[1] isa REAL_EXPRESSION && args[2] isa INTEGER_EXPRESSION && args[3] isa INTEGER_EXPRESSION &&
         args[4] isa BOOLEAN_EXPRESSION
    local format::String = "%" * (args[4].value ? "-" : "") * intString(args[3].value) * "." * intString(args[2].value) * "g"
    return STRING_EXPRESSION(System.sprintff(format, args[1].value))
  elseif n_args == 2 && args[1] isa REAL_EXPRESSION && args[2] isa STRING_EXPRESSION
    #= C's printf with "%" + format, as OpenModelica (flags, width, precision, then f, e, E, g or
       G: another conversion of a double is not defined). =#
    occursin(r"^[#0 +-]*[0-9]*(\.[0-9]*)?[feEgG]$", args[2].value) || return _wrongArgs("String", args)
    return STRING_EXPRESSION(System.sprintff("%" * args[2].value, args[1].value))
  end
  return _wrongArgs("String", args)
end

evalBuiltinSum(@nospecialize(arg::Expression))::Expression = _evalArrayReduction(arg, +, "sum", 0, 0.0)

"""`symmetric(A)`: the upper triangle mirrored to the lower."""
function evalBuiltinSymmetric(@nospecialize(arg::Expression))::Expression
  (arg isa ARRAY_EXPRESSION && isMatrix(arg.ty)) || return _wrongArgs("symmetric", arg)
  local mat::Vector{Vector{Expression}} = Vector{Expression}[arrayElements(row) for row in arg.elements]
  local n::Int = length(mat)
  local row_ty::ModelicaType = unliftArray(arg.ty)
  local rows::Vector{Expression} = Vector{Expression}(undef, n)
  for i in 1:n
    rows[i] = ARRAY_EXPRESSION(row_ty, Expression[i > j ? mat[j][i] : mat[i][j] for j in 1:n], true)
  end
  return ARRAY_EXPRESSION(arg.ty, rows, true)
end

evalBuiltinTanh(@nospecialize(arg::Expression))::Expression = _realFunc(tanh, arg, "tanh")
evalBuiltinTan(@nospecialize(arg::Expression))::Expression = _realFunc(x -> roundingZero(tan(x), x), arg, "tan")

"""`transpose(A)`: the first two dimensions swapped."""
function evalBuiltinTranspose(@nospecialize(arg::Expression))::Expression
  if !(arg isa ARRAY_EXPRESSION && arg.ty.tag == NFT_ARRAY && listLength(arg.ty.dimensions) >= 2)
    printWrongArgsError("evalBuiltinTranspose", list(arg), sourceInfo())
    return EVAL_FAILED
  end
  local dim1::Dimension = listHead(arg.ty.dimensions)
  local dim2::Dimension = listHead(listRest(arg.ty.dimensions))
  local rows::Vector{Vector{Expression}} = Vector{Expression}[arrayElements(e) for e in arg.elements]
  local ncols::Int = isempty(rows) ? 0 : length(rows[1])
  local col_ty::ModelicaType = liftArrayLeft(arg.ty.elementType::ModelicaType, dim1)
  local cols::Vector{Expression} = Vector{Expression}(undef, ncols)
  for j in 1:ncols
    cols[j] = ARRAY_EXPRESSION(col_ty, Expression[r[j] for r in rows], arg.literal)
  end
  return ARRAY_EXPRESSION(liftArrayLeft(col_ty, dim2), cols, arg.literal)
end

"""`vector(A)`: the scalar elements of an array in order, as a vector."""
function evalBuiltinVector(@nospecialize(arg::Expression))::Expression
  local expl::Vector{Expression} = foldArrayElements(arg, (e, acc::Vector{Expression}) -> push!(acc, e), Expression[],
                                                     Vector{Expression})
  local ty::ModelicaType = liftArrayLeft(arrayElementType(typeOf(arg)), fromInteger(length(expl)))
  return makeArray(ty, expl, literal = true)
end

evalBuiltinZeros(args::Union{List{Expression}, Vector{Expression}})::Expression = evalBuiltinFill2(INTEGER_EXPRESSION(0), args)

function evalUriToFilename(fn::MODELICA_FUNCTION, args::Vector{Expression}, @nospecialize(target::EvalTarget))::Expression
  args[1] isa STRING_EXPRESSION || return _wrongArgs("uriToFilename", args[1])
  return STRING_EXPRESSION(resolveModelicaUri(args[1].value))
end

"""
Resolve a modelica:// URI to an absolute file path.
Handles URIs of the form modelica://PackageName/path/to/resource.
Searches the OMFrontend lib directory and the openmodelica libraries cache.
Falls back to returning the input unchanged for non-URI strings.
"""
function resolveModelicaUri(uri::String)::String
  local prefix = "modelica://"
  if !startswith(uri, prefix)
    return uri
  end
  local rest = uri[length(prefix)+1:end]
  local slashIdx = findfirst('/', rest)
  if slashIdx === nothing
    return uri
  end
  local packageName = rest[1:slashIdx-1]
  #= the URI's path in the platform's separators (Windows: Resources\data.txt, not Resources/data.txt) =#
  local resourcePath = joinpath(Base.split(rest[slashIdx+1:end], "/")...)
  #= The directory the library was loaded from (OMFrontend.LIBRARY_ROOTS: an installed library, a package directory
     given by path), wherever that is =#
  local roots = getglobal(Base.moduleroot(@__MODULE__), :LIBRARY_ROOTS)
  local top = Base.first(Base.split(packageName, "."))
  if haskey(roots, top)
    local fromRoot = joinpath(roots[top], Base.split(packageName, ".")[2:end]..., resourcePath)
    isfile(fromRoot) && return fromRoot
  end
  #= Search in OMFrontend bundled lib directory =#
  local packagePath = something(pkgdir(@__MODULE__), normpath(joinpath(@__DIR__, "..", "..")))
  local libDir = joinpath(packagePath, "lib", packageName)
  local resolved = joinpath(libDir, resourcePath)
  if isfile(resolved)
    return resolved
  end
  #= Search the directories of installed libraries (OM.jl's, then OpenModelica's: OMFrontend.libraryDirectories) =#
  for omLibDir in getglobal(Base.moduleroot(@__MODULE__), :libraryDirectories)()
    isdir(omLibDir) || continue
    for entry in readdir(omLibDir)
      if startswith(entry, packageName)
        local candidate = joinpath(omLibDir, entry, resourcePath)
        if isfile(candidate)
          return candidate
        end
      end
    end
  end
  @warn "resolveModelicaUri: resource not found" uri
  return resolved
end

"""`intBitAnd` etc. of two Integers."""
function _evalIntBits(f::F, args::Vector{Expression}, name::String)::Expression where {F<:Function}
  (length(args) == 2 && args[1] isa INTEGER_EXPRESSION && args[2] isa INTEGER_EXPRESSION) || return _wrongArgs(name, args)
  return INTEGER_EXPRESSION(f(args[1].value, args[2].value))
end

evalIntBitAnd(args::Vector{Expression})::Expression = _evalIntBits(intBitAnd, args, "intBitAnd")
evalIntBitOr(args::Vector{Expression})::Expression = _evalIntBits(intBitOr, args, "intBitOr")
evalIntBitXor(args::Vector{Expression})::Expression = _evalIntBits(intBitXor, args, "intBitXor")
evalIntBitLShift(args::Vector{Expression})::Expression = _evalIntBits(intBitLShift, args, "intBitLShift")
evalIntBitRShift(args::Vector{Expression})::Expression = _evalIntBits(intBitRShift, args, "intBitRShift")

function evalInferredClock(args::Vector{Expression})::Expression
  isempty(args) || return _wrongArgs("Clock", args)
  return CLKCONST_EXPRESSION(INFERRED_CLOCK())
end

function evalRationalClock(args::Vector{Expression})::Expression
  (length(args) == 2 && args[1] isa INTEGER_EXPRESSION && args[2] isa INTEGER_EXPRESSION) || return _wrongArgs("Clock", args)
  return CLKCONST_EXPRESSION(INTEGER_CLOCK(args[1], args[2]))
end

function evalRealClock(args::Vector{Expression})::Expression
  (length(args) == 1 && args[1] isa REAL_EXPRESSION) || return _wrongArgs("Clock", args)
  return CLKCONST_EXPRESSION(REAL_CLOCK(args[1]))
end

function evalBooleanClock(args::Vector{Expression})::Expression
  (length(args) == 2 && args[1] isa BOOLEAN_EXPRESSION && args[2] isa REAL_EXPRESSION) || return _wrongArgs("Clock", args)
  return CLKCONST_EXPRESSION(BOOLEAN_CLOCK(args[1], args[2]))
end

function evalSolverClock(args::Vector{Expression})::Expression
  (length(args) == 2 && args[1] isa CLKCONST_EXPRESSION && args[2] isa STRING_EXPRESSION) || return _wrongArgs("Clock", args)
  return CLKCONST_EXPRESSION(SOLVER_CLOCK(args[1], args[2]))
end

"""`DynamicSelect(static, dynamic)`: the static value."""
function evalBuiltinDynamicSelect(fn::MODELICA_FUNCTION, args::Vector{Expression}, @nospecialize(target::EvalTarget))::Expression
  length(args) == 2 || return _wrongArgs("DynamicSelect", args)
  return _evalValue(unbox(args[1]), target)
end

function evalArrayConstructor(@nospecialize(exp::Expression), iterators::List{<:Tuple{<:InstNode, Expression}})::Expression
  local result::Expression = Base.first(evalExpPartial(exp))
  result isa EVAL_FAILURE && return result
  return _bindingExpMapEval(result, (expArg) -> evalArrayConstructor2(expArg, iterators))
end

function evalArrayConstructor2(@nospecialize(exp::Expression), iterators::List{<:Tuple{<:InstNode, Expression}})::Expression
  local (e::Expression, ranges::List{Expression}, iters::List{Pointer{Expression}}) = createIterationRanges(exp, iterators)
  return evalArrayConstructor3(e, ranges, iters)
end

function createIterationRanges(
  @nospecialize(exp::Expression),
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Tuple{Expression, List{Expression}, List{Pointer{Expression}}}
  local iters::List{Pointer{Expression}} = nil
  local ranges::List{Expression} = nil
  #= The iterator is also replaced in the ranges collected so far, which may use it (`j in 1:i,
     i in 1:4`); the ranges are evaluated when their loop starts (omc createIterationRanges). =#
  for (node::InstNode, range::Expression) in iterators
    local iter::Pointer{Expression} = P_Pointer.create(INTEGER_EXPRESSION(0), Expression)
    local iter_exp::Expression = MUTABLE_EXPRESSION(iter)
    ranges = list(replaceIterator(r, node, iter_exp) for r in ranges)
    exp = replaceIterator(exp, node, iter_exp)
    iters = _cons(iter, iters)
    ranges = _cons(range, ranges)
  end
  return (exp, ranges, iters)
end

#= The arrays' types from their elements (a range can depend on an enclosing iterator; omc
   evalArrayConstructor2). =#
function evalArrayConstructor3(
  @nospecialize(exp::Expression),
  ranges::List{Expression},
  iterators::List{<:Pointer{Expression}},
)::Expression
  listEmpty(ranges) && return evalExp_impl(exp, EVALTARGET_IGNORE_ERRORS())
  local ranges_rest::List{Expression} = listRest(ranges)
  local iter::Pointer{Expression} = listHead(iterators)
  local iters_rest::List{Pointer{Expression}} = listRest(iterators)
  local range_exp::Expression = evalExp_impl(listHead(ranges), EVALTARGET_IGNORE_ERRORS())
  range_exp isa EVAL_FAILURE && return range_exp
  local range_iter::ExpressionIterator = fromExpToExpressionIterator(range_exp)
  local expV::Vector{Expression} = Expression[]
  local value::Expression
  while hasNext(range_iter)
    (range_iter, value) = next(range_iter)
    P_Pointer.update(iter, value)
    local element::Expression = evalArrayConstructor3(exp, ranges_rest, iters_rest)
    element isa EVAL_FAILURE && return element
    push!(expV, element)
  end
  local ty::ModelicaType = isempty(expV) ?
    liftArrayLeftList(typeOf(exp), ListUtil.mapFlat(ranges_rest, r -> arrayDims(typeOf(r)), Dimension)) : typeOf(expV[1])
  return makeArray(liftArrayLeft(ty, fromInteger(length(expV))), expV, literal = true)
end

function evalReduction(
  fn::MODELICA_FUNCTION,
  @nospecialize(exp::Expression),
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Expression
  local result::Expression = Base.first(evalExpPartial(exp))
  result isa EVAL_FAILURE && return result
  return _bindingExpMapEval(result, (e) -> evalReduction2(fn, e, iterators))
end

function evalReduction2(
  fn::MODELICA_FUNCTION,
  @nospecialize(exp::Expression),
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Expression
  #= The type before the iterators are replaced by their (Integer-initialized) values. =#
  local ty::ModelicaType = typeOf(exp)
  local (e::Expression, ranges::List{Expression}, iters::List{Pointer{Expression}}) = createIterationRanges(exp, iterators)
  local fn_name::String = AbsynUtil.pathString(name(fn))
  fn_name == "sum" && return evalReduction3(e, ranges, iters, makeZero(ty), evalBinaryAdd)
  fn_name == "product" && return evalReduction3(e, ranges, iters, makeOne(ty), evalBinaryMul)
  fn_name == "min" && return evalReduction3(e, ranges, iters, makeMaxValue(ty), evalBuiltinMin2)
  fn_name == "max" && return evalReduction3(e, ranges, iters, makeMinValue(ty), evalBuiltinMax2)
  Error.addInternalError("evalReduction2 got unknown reduction function " + fn_name, sourceInfo())
  return EVAL_FAILED
end

function evalReduction3(
  @nospecialize(exp::Expression),
  ranges::List{Expression},
  iterators::List{<:Pointer{Expression}},
  @nospecialize(foldExp::Expression),
  fn::F,
)::Expression where {F<:Function}
  if listEmpty(ranges)
    local e::Expression = evalExp_impl(exp, EVALTARGET_IGNORE_ERRORS())
    e isa EVAL_FAILURE && return e
    return fn(foldExp, e)::Expression
  end
  local ranges_rest::List{Expression} = listRest(ranges)
  local iter::Pointer{Expression} = listHead(iterators)
  local iters_rest::List{Pointer{Expression}} = listRest(iterators)
  local range_exp::Expression = evalExp_impl(listHead(ranges), EVALTARGET_IGNORE_ERRORS())
  range_exp isa EVAL_FAILURE && return range_exp
  local range_iter::ExpressionIterator = fromExpToExpressionIterator(range_exp)
  local result::Expression = foldExp
  local value::Expression
  while hasNext(range_iter)
    (range_iter, value) = next(range_iter)
    P_Pointer.update(iter, value)
    result = evalReduction3(exp, ranges_rest, iters_rest, result, fn)
    result isa EVAL_FAILURE && return result
  end
  return result
end

function evalSize(
  @nospecialize(exp::Expression),
  optIndex::Option{Expression},
  @nospecialize(target::EvalTarget),
  )::Expression
  local info::SourceInfo = EvalTarget_getInfo(target)
  if isSome(optIndex)
    #= The index, the index'd dimension of the expression, its size expression evaluated. =#
    local index_exp::Expression = evalExp_impl(Util.getOption(optIndex), target)
    (index_exp isa INTEGER_EXPRESSION || index_exp isa BOOLEAN_EXPRESSION || index_exp isa ENUM_LITERAL_EXPRESSION) ||
      return EVAL_FAILED
    local index::Int = toInteger(index_exp)
    local (dim::Dimension, _, ty_err::TypingError) = typeExpDim(exp, index, ORIGIN_CLASS, info)
    checkSizeTypingError(ty_err, exp, index, info) || return EVAL_FAILED
    hasSizeExp(dim) || return EVAL_FAILED
    return evalExp_impl(sizeExp(dim), target)
  end
  local ty::ModelicaType = typeExp(exp, ORIGIN_CLASS, info)[2]
  local expl::Vector{Expression} = Expression[]
  for d in arrayDims(ty)
    hasSizeExp(d) || return EVAL_FAILED
    local e::Expression = evalExp_impl(sizeExp(d), target)
    e isa EVAL_FAILURE && return e
    push!(expl, e)
  end
  return makeArray(TYPE_ARRAY(TYPE_INTEGER(), list(fromInteger(length(expl), Variability.PARAMETER))), expl)
end

function evalSubscriptedExp(
  @nospecialize(exp::Expression),
  subscripts::List{<:Subscript},
  @nospecialize(target::EvalTarget),
)::Expression
  #= A subscripted range keeps its range form (its bounds evaluated), not expanded. =#
  local result::Expression
  if exp isa RANGE_EXPRESSION
    local start::Expression = _evalValue(exp.start, target)
    start isa EVAL_FAILURE && return start
    local step::Option{Expression} = evalExpOpt(exp.step, target)
    _failedOpt(step) && return EVAL_FAILED
    local stop::Expression = _evalValue(exp.stop, target)
    stop isa EVAL_FAILURE && return stop
    result = RANGE_EXPRESSION(exp.ty, start, step, stop)
  else
    result = evalExp_impl(exp, target)
    result isa EVAL_FAILURE && return result
  end
  local subs::List{Subscript} = nil
  for s in subscripts
    local (ok::Bool, sub::Subscript) = evalSubscriptWithTarget(s, target)
    ok || return EVAL_FAILED
    subs = Cons{Subscript}(sub, subs)
  end
  return applySubscripts(listReverse(subs), result)
end

"""
A subscript with its expression evaluated, as `mapShallowExp(subscript, x -> evalExp_impl(x, target))` without the
closure: the closure over the abstract `target` was a heap object per subscripted expression (HeatingSystem: 33k).
`(true, subscript)`, or `(false, subscript)` when its expression does not evaluate.
"""
function evalSubscriptWithTarget(subscript::Subscript, @nospecialize(target::EvalTarget))::Tuple{Bool, Subscript}
  local e1::Expression
  if subscript isa SUBSCRIPT_UNTYPED
    e1 = subscript.exp
  elseif subscript isa SUBSCRIPT_INDEX
    e1 = subscript.index
  elseif subscript isa SUBSCRIPT_SLICE
    e1 = subscript.slice
  else
    return (true, subscript)
  end
  local e2::Expression = evalExp_impl(e1, target)
  e2 isa EVAL_FAILURE && return (false, subscript)
  referenceEq(e1, e2) && return (true, subscript)
  return (true, subscript isa SUBSCRIPT_UNTYPED ? SUBSCRIPT_UNTYPED(e2) : fromTypedExp(e2))
end

function evalRecordElement(exp::RECORD_ELEMENT_EXPRESSION, @nospecialize(target::EvalTarget))::Expression
  local result::Expression
  local e::Expression = evalExp_impl(exp.recordExp, target)
  e isa EVAL_FAILURE && return e
  local index::Int = exp.index
  result = _bindingExpMapEval(e, @closure (x) -> _recordElementOf(x, index, exp.ty, exp.fieldName))
  if result isa EVAL_FAILURE
    Error.addSourceMessage(Error.INTERNAL_ERROR, list("evalRecordElement could not evaluate " + toString(exp)), sourceInfo())
    return result
  end
  #= A record expression's fields are not evaluated (evalExp_impl): the field is, as it
     is read (a record constructor's array constructor argument: Buildings' Movers). =#
  return evalExp_impl(result, target)
end

#= The field of a record, or of each record of an array of records (Buildings' chillers'
   perChi[numChi]: its records' nCapFunT); EVAL_FAILED for an expression that is neither. =#
function _recordElementOf(@nospecialize(x::Expression), index::Int, @nospecialize(ty::ModelicaType), fieldName::String)::Expression
  if x isa ARRAY_EXPRESSION
    local ety::ModelicaType = isArray(ty) ? unliftArray(ty) : ty
    return _mapElements((@nospecialize(el::Expression),) -> _recordElementOf(el, index, ety, fieldName), x.elements, ty, x.literal)
  end
  #= A record (array) variable is not evaluated (evalCref): its field is the field's cref,
     sliced over the array (r3.r2.r.x, omc SlicedCref2). =#
  x isa CREF_EXPRESSION && return recordElement(fieldName, x)
  x isa RECORD_EXPRESSION || return EVAL_FAILED
  return x.elements[index]
end

"""
    printUnboundError(component, target, exp) -> Bool
Reports an unbound component read in an evaluation; true when the evaluation fails (a dimension, a condition,
an unbound constant), false when the default expression is used.
"""
function printUnboundError(component::Component, @nospecialize(target::EvalTarget), @nospecialize(exp::Expression))::Bool
  target isa EVALTARGET_IGNORE_ERRORS && return false
  if target isa EVALTARGET_DIMENSION
    Error.addSourceMessage(Error.STRUCTURAL_PARAMETER_OR_CONSTANT_WITH_NO_BINDING,
                           list(toString(exp), name(target.component)), target.info)
    return true
  end
  if target isa EVALTARGET_CONDITION
    Error.addSourceMessage(Error.CONDITIONAL_EXP_WITHOUT_VALUE, list(toString(exp)), target.info)
    return true
  end
  local var::VariabilityType = variability(component)
  if (var == Variability.STRUCTURAL_PARAMETER || var == Variability.PARAMETER) && getEvaluateAnnotation(component)
    #= A parameter with annotation(Evaluate = true) and no binding: an error only with fixed = true. =#
    getFixedAttribute(component) && Error.addMultiSourceMessage(Error.UNBOUND_PARAMETER_EVALUATE_TRUE,
      list(toString(exp) + "(fixed = true)"), _unboundInfos(exp, target))
    return false
  end
  #= A constant with no binding. =#
  Error.addMultiSourceMessage(Error.UNBOUND_CONSTANT, list(toString(exp)), _unboundInfos(exp, target))
  return true
end

"""The positions of an unbound component's declaration and of its use."""
_unboundInfos(@nospecialize(exp::Expression), @nospecialize(target::EvalTarget))::List{SourceInfo} =
  list(InstNode_info(node(toCref(exp))), EvalTarget_getInfo(target))

#= args: the List (list(arg) builds e.g. a Cons{CALL_EXPRESSION}) or Vector the evalBuiltin* functions take. =#
function printWrongArgsError(evalFunc::String, args::Union{List{<:Expression}, Vector{<:Expression}}, info::SourceInfo)
  return Error.addInternalError(
    evalFunc +
    " got invalid arguments (" +
    stringDelimitList(list(toString(a) for a in args), ", ") + ")",
    info,
  )
end

"""
    _catPartRegular(e, dim) -> Bool
Whether the argument `e` of cat along `dim` is a regular array to depth `dim` (the elements at each level the
same length): the check before `_catPart`.
"""
function _catPartRegular(@nospecialize(e::Expression), dim::Int)::Bool
  local level::Vector{Expression} = Expression[e]
  for _ in 1:dim
    _allArrays(level) || break
    local n::Int = length((level[1]::ARRAY_EXPRESSION).elements)
    _allLength(level, n) || return false
    level = _nextLevel(level)
  end
  return true
end

"""Whether every argument of cat along `dim` is regular (`_catPartRegular`)."""
function _allCatPartsRegular(exps::Vector{Expression}, dim::Int)::Bool
  for e in exps
    _catPartRegular(e, dim) || return false
  end
  return true
end

"""Whether every expression of `level` is an array expression."""
function _allArrays(level::Vector{Expression})::Bool
  for x in level
    x isa ARRAY_EXPRESSION || return false
  end
  return true
end

"""Whether every array expression of `level` has `n` elements."""
function _allLength(level::Vector{Expression}, n::Int)::Bool
  for x in level
    length((x::ARRAY_EXPRESSION).elements) == n || return false
  end
  return true
end

"""The elements of the array expressions of `level`, in order: the next level, row-major."""
function _nextLevel(level::Vector{Expression})::Vector{Expression}
  local out::Vector{Expression} = Expression[]
  for x in level
    append!(out, (x::ARRAY_EXPRESSION).elements)
  end
  return out
end

"""
    _catPart(e, dim) -> (elements, sizes)

An argument of cat along `dim` (regular: `_catPartRegular`): its subexpressions at depth `dim` in row-major order and
the sizes of those `dim` levels; one of fewer dimensions gets trailing ones (Modelica's promote, a vector a column).
"""
function _catPart(@nospecialize(e::Expression), dim::Int)::Tuple{Vector{Expression}, Vector{Int}}
  local sizes::Vector{Int} = Int[]
  local level::Vector{Expression} = Expression[e]
  for _ in 1:dim
    _allArrays(level) || break
    push!(sizes, length((level[1]::ARRAY_EXPRESSION).elements))
    level = _nextLevel(level)
  end
  while length(sizes) < dim
    push!(sizes, 1)
  end
  return (level, sizes)
end

"""
    evalCat(dim, exps) -> (elements, sizes)

`cat(dim, exps...)` of regular arrays (`_catPartRegular`): the result's scalar elements in row-major
order and its sizes. As omc's ExpressionBasics.evalCat: each argument as its subexpressions at depth dim
(row-major), concatenated along dim (an argument of fewer dimensions promoted: [identity(n - 1), zeros(n - 1)],
Polynomials.roots). In row-major order, for each index of the dimensions before dim, each argument contributes one
contiguous block (its extent along dim times the sizes after dim).
"""
function evalCat(dim::Int, exps::Vector{Expression})::Tuple{Vector{Expression}, List{Int}}
  if dim > 1
    local n::Int = length(exps)
    local partElems::Vector{Vector{Expression}} = Vector{Vector{Expression}}(undef, n)
    local sizes::Vector{Int} = Int[]
    for i in 1:n
      local (elems::Vector{Expression}, partSizes::Vector{Int}) = _catPart(exps[i], dim)
      partElems[i] = elems
      if i == 1
        sizes = partSizes
      else
        sizes[dim] += partSizes[dim]
      end
    end
    local outer::Int = prod(@view sizes[1:dim - 1])
    local out::Vector{Expression} = Expression[]
    sizehint!(out, outer * prod(@view sizes[dim:end]))
    for o in 0:outer - 1, i in 1:n
      local block::Int = length(partElems[i]) ÷ outer
      append!(out, @view partElems[i][o * block + 1:(o + 1) * block])
    end
    return (out, arrayList(sizes))
  end
  local flat::Vector{Expression} = Expression[]
  for e in exps
    append!(flat, (e::ARRAY_EXPRESSION).elements)
  end
  return (flat, list(length(flat)))
end

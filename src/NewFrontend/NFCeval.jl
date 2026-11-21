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
function EvalTarget_getInfo(@nospecialize(target::EvalTarget))::SourceInfo
  local info::SourceInfo
  info = begin
    @match target begin
      EVALTARGET_DIMENSION(__) => begin
        target.info
      end

      EVALTARGET_ATTRIBUTE(__) => begin
        Binding_getInfo(target.binding)
      end

      EVALTARGET_RANGE(__) => begin
        target.info
      end

      EVALTARGET_CONDITION(__) => begin
        target.info
      end

      EVALTARGET_GENERIC(__) => begin
        target.info
      end

      EVALTARGET_STATEMENT(__) => begin
        target.source
      end

      _ => begin
        AbsynUtil.dummyInfo
      end
    end
  end
  return info
end

function hasInfo(@nospecialize(target::EvalTarget))::Bool
  local hasInfo::Bool
  hasInfo = begin
    @match target begin
      EVALTARGET_DIMENSION(__) => begin
        true
      end

      EVALTARGET_ATTRIBUTE(__) => begin
        true
      end

      EVALTARGET_RANGE(__) => begin
        true
      end

      EVALTARGET_CONDITION(__) => begin
        true
      end

      EVALTARGET_GENERIC(__) => begin
        true
      end

      EVALTARGET_STATEMENT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return hasInfo
end

function isRange(@nospecialize(target::EvalTarget))::Bool
  local isR::Bool
  isR = begin
    @match target begin
      EVALTARGET_RANGE(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isR
end

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

"""
   Evaluates the parts of an expression that are possible to evaluate. This
   means leaving parts of the expression that contains e.g. iterators or mutable
   expressions. This can be used to optimize an expression that is expected to
   be evaluated many times, for example the expression in an array constructor.
   `(EVAL_FAILED, false)` when a part fails.
"""
function evalExpPartial(
  @nospecialize(exp::Expression),
  @nospecialize(target::EvalTarget = EVALTARGET_IGNORE_ERRORS()),
  evaluated::Bool = true,
  )::Tuple{Expression, Bool}
  local outEvaluated::Bool #= True if the whole expression is evaluated, otherwise false. =#
  local outExp::Expression
  local e::Expression
  #= Each child evaluated partially; the fold argument is true while every child so far is fully
     evaluated. A child that fails sets `failed` (the fold rebuilds the expression around it). =#
  local failed::Base.RefValue{Bool} = Ref(false)
  local f = (expArg::Expression, boolArg::Bool) -> begin
    local r::Tuple{Expression, Bool} = evalExpPartial(expArg, target, boolArg)
    r[1] isa EVAL_FAILURE && (failed[] = true)
    r
  end
  (e, outEvaluated) = mapFoldShallow(exp, f, true)
  failed[] && return (EVAL_FAILED, false)
  outExp = begin
    @match e begin
      CREF_EXPRESSION(__) => begin
        if isIterator(e.cref)
          outExp = e
          outEvaluated = false
        else
          outExp = evalCref(e.cref, e, target, evalSubscripts = false)
          #=  If evalCref could not resolve the cref (returned the original),
              mark as not fully evaluated so parent expressions are not
              incorrectly treated as constant. =#
          if referenceEq(outExp, e)
            outEvaluated = false
          elseif outExp isa SUBSCRIPTED_EXP_EXPRESSION
            #=  evalCref resolved the binding but could not apply subscripts
                (e.g. iterator subscripts not yet replaced). Mark as not
                fully evaluated so the parent is not prematurely evaluated. =#
            outEvaluated = false
          end
        end
        outExp
      end

      MUTABLE_EXPRESSION(__) => begin
        #=  Don't evaluate mutable expressions. While they could technically be
        =#
        #=  evaluated they're usually used as mutable iterators.
        =#
         outEvaluated = false
        e
      end

      _ => begin
        if outEvaluated
          local v::Expression = evalExp_impl(e, target)
          v isa EVAL_FAILURE && return (v, false)
          getBindingExp(v)
        else
          e
        end
      end
    end
  end
  outExp isa EVAL_FAILURE && return (outExp, false)
   outEvaluated = evaluated && outEvaluated
  return (outExp, outEvaluated) #= True if the whole expression is evaluated, otherwise false. =#
end


function evalCref(cref::ComponentRef,
                  @nospecialize(defaultExp::Expression),
                  target::EvalTarget;
                  evalSubscripts::Bool = true)
  local exp::Expression
  local c::InstNode
  local evaled::Bool
  exp = begin
    @match cref begin
      COMPONENT_REF_CREF(
        node = c && COMPONENT_NODE(__),
      ) where {(!isIterator(cref)) && nodeVariability(cref) < Variability.NON_STRUCTURAL_PARAMETER} => begin
        evalComponentBinding(c, cref, defaultExp, target, evalSubscripts)
      end

      COMPONENT_REF_CREF(node = c && COMPONENT_NODE(__)) => begin
        defaultExp
      end

      _ => begin
        defaultExp
      end
    end
  end
  return exp
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
  local x = value
  for _ in 1:extra
    (x isa ARRAY_EXPRESSION && !isempty(x.elements)) || return nothing
    local first_el = x.elements[1]
    all(e -> isEqual(e, first_el), x.elements) || return nothing
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
  local exp_origin::ORIGIN_Type
  local comp::Component
  local binding::Binding
  local evaluated::Bool
  local var::VariabilityType
  local start_exp::Option{Expression}
   exp_origin = if isFunction(explicitParent(node))
    ORIGIN_FUNCTION
  else
    ORIGIN_CLASS
   end
  node = typeComponentBinding(node, exp_origin, false)
  comp = component(node)
  binding = getBinding(comp)
  parent_cr = rest(cref)
  if isUnbound(binding)
    #=
    In some cases we need to construct a binding for the node, for example when
    a record has bindings on the fields but not on the record instance as a whole.
    =#
     binding =
       makeComponentBinding(comp, node, toCref(defaultExp), target)
    if isUnbound(binding)
      #=
      If we couldn't construct a binding, try to use the start value instead.
      =#
       start_exp =
         evalComponentStartBinding(node, comp, cref, target, evalSubscripts)
      #=
      The component had a valid start value. The value has already been
      evaluated by evalComponentStartBinding, so skip the rest of the function.
      =#
      if isSome(start_exp)
        @match SOME(exp) = start_exp
        return exp
      end
    end
  end
   (exp, evaluated) = begin
    @match binding begin
      TYPED_BINDING(__) => begin
        if binding.evaluated
           exp = binding.bindingExp
        else
          #= Try to evaluate the binding, in the element context of the cref (see _elementContext). =#
          local ctx = _elementContext()
          local in_element = _hasEnclosingSubscripts(cref)
          in_element && push!(ctx, cref)
          local uses = _elementContextUses()
          local uses0 = uses[]
          exp = evalExp_impl(binding.bindingExp, target)
          in_element && pop!(ctx)
          if exp isa EVAL_FAILURE
            #= Not evaluable: the cref itself when errors are ignored, else the failure. =#
            return target isa EVALTARGET_IGNORE_ERRORS ? defaultExp : exp
          end
          local per_element = uses[] != uses0
          #= Update the binding and set is as evaluated; not a value with more dimensions than
             the component (a binding in an array of components evaluated in its class, which
             the elements share, its references to the elements' array modifiers whole: every
             element's binding became the array, Buildings' PressureDrop[nRes] resSeries,
             dp_nominal_pos = abs(dp_nominal) evaluated for an if-equation's condition). =#
          local extra = _valueDimensionCount(exp) - dimensionCount(getType(comp))
          if extra <= 0
            #= Not when it read the element context: one element's value, not the shared one's. =#
            if !per_element
              @assign binding.bindingExp = exp
              @assign binding.evaluated = true
              comp = setBinding(binding, comp)
              node = updateComponent!(comp, node)
            end
          else
            exp = _subscriptByEnclosingElements(exp, cref, extra, evalSubscripts,
                                                _readsOwnElement(cref, defaultExp, getType(comp), extra))
          end
        end
        (exp, true)
      end

      CEVAL_BINDING(__) => begin
        #= Over the enclosing component arrays too (a record field's value from its parent's,
           the parent bound to an array of records: Buildings' Templates pumps, pum[nPum](per =
           per), each element's `per.haveWMot_nominal` the array {false, true}): its element. =#
        local cexp = binding.bindingExp
        local extra = _valueDimensionCount(cexp) - dimensionCount(getType(comp))
        extra > 0 && (cexp = _subscriptByEnclosingElements(cexp, cref, extra, evalSubscripts,
                                                           _readsOwnElement(cref, defaultExp, getType(comp), extra)))
        (cexp, true)
      end

      UNBOUND(__) => begin
        printUnboundError(comp, target, defaultExp) ? (EVAL_FAILED, false) : (defaultExp, false)
      end

      _ => begin
        Error.addInternalError(getInstanceName() + " failed on untyped binding", sourceInfo())
        (EVAL_FAILED, false)
      end
    end
  end
  exp isa EVAL_FAILURE && return exp
  #=  Apply subscripts from the cref to the binding expression as needed.
  =#
  if evaluated
     exp = subscriptEvaluatedBinding(exp, cref, evalSubscripts)
     exp isa EVAL_FAILURE && return exp
     exp = _liftToCrefDims(exp, defaultExp)
  end
  return exp
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

function flattenBindingExp(@nospecialize(exp::Expression))::Expression
  local outExp::Expression
   outExp = begin
    @match exp begin
      BINDING_EXP(exp = BINDING_EXP(__)) => begin
        flattenBindingExp(exp.exp)
      end
      _ => begin
        exp
      end
    end
  end
  return outExp
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

  local subs::List{Subscript}
  local cr::ComponentRef

  #=  The subscripts of the first part of the cref are always applied. =#
  subs = getSubscripts(cref)
  (cr, _) = stripSubscripts(cref)
  if evalSubscripts
    local (ok::Bool, evaluated::List{Subscript}) = _evalSubscripts(subs)
    ok || return EVAL_FAILED
    subs = evaluated
  end
  #=  The rest of the cref contributes subscripts based on where the expressions
  =#
  #=  comes from in the instance tree.
  =#
  exp = subscriptEvaluatedBinding2(exp, cr, evalSubscripts, subs, subs)
  return exp
end

function subscriptEvaluatedBinding2(
  @nospecialize(exp::Expression),
  cref::ComponentRef,
  evalSubscripts::Bool,
  subscripts::List{<:Subscript} = nil,
  bindingSubs::List{<:Subscript} = nil,
)::Expression

   exp = begin
    local e::Expression
    local exp_ty::ModelicaType
    local bind_ty::ModelicaType
    local parents::List{InstNode}
    local accum_subs::List{Subscript}
    local subs::List{Subscript}
    local cr::ComponentRef
    local cr_node::InstNode
    @match exp begin
      BINDING_EXP(bindingType = bind_ty, parents = parents) =>
        begin
          if exp.isEach
             parents = list(listHead(parents))
          end
           cr = cref
           accum_subs = subscripts
           subs = nil
          if !isEmpty(cr)
             cr_node = node(cr)
            while !(listEmpty(parents) || refEqual(listHead(parents), cr_node))
               parents = listRest(parents)
            end
            while !listEmpty(parents)
              if !refEqual(listHead(parents), cr_node)
                break
              end
               subs =
                listAppend(getSubscripts(cr), subs)
               parents = listRest(parents)
               cr = rest(cr)
              if isEmpty(cr)
                break
              end
               cr_node = node(cr)
            end
            #= Parents the cref has no parts for (a binding read inside an element's binding):
               their subscripts from the element context. =#
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
          #=  Remove binding parents until we find one referring to the first
          =#
          #=  cref node, or we run out of parents.
          =#
          #=  Collect subscripts from the part of the cref corresponding to the
          =#
          #=  remaining parents.
          =#
          #=  Subscript the binding type if bindingSubs was given.
          =#
          if !listEmpty(bindingSubs)
            subs = bindingSubs
            bind_ty = subscript(bind_ty, subs)
          end
          e =
            subscriptEvaluatedBinding2(exp.exp, cr, evalSubscripts, accum_subs, subs)
          e isa EVAL_FAILURE && return e
          exp_ty = typeOf(e)
          BINDING_EXP(e, exp_ty, bind_ty, exp.parents, exp.isEach)
        end

      _ => begin
        applySubscripts(subscripts, exp)
      end
    end
  end
  return exp
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
Tries to evaluate the given component's start value. NONE() is returned if
the component isn't a fixed parameter or if it doesn't have a start value.
Otherwise the evaluated binding expression is returned if it could be
evaluated, or the function will fail if it couldn't be.
"""
function evalComponentStartBinding(
  node::InstNode,
  comp::Component,
  cref::ComponentRef,
  @nospecialize(target::EvalTarget),
  evalSubscripts::Bool,
)::Option{Expression}
  local outExp::Option{Expression} = NONE()

  local var::VariabilityType
  local start_node::InstNode
  local start_comp::Component
  local binding::Binding
  local exp::Expression
  local subs::List{Subscript}
  local pcount::Int

  #=  Only use the start value if the component is a fixed parameter. =#
  var = variability(comp)
  #@info "Component was:" toString("Component", comp)
  #@info "It was named" toString(cref)
  #@info "Variability was" Variability.variabilityAsString(var)
  local notParamAndNotStructuralParam = (var != Variability.PARAMETER && var != Variability.STRUCTURAL_PARAMETER)
  #@info "notParamAndNotStructuralParam" notParamAndNotStructuralParam
  if (notParamAndNotStructuralParam) || !getFixedAttribute(comp)
    return outExp
  end
  #=  Look up \"start\" in the class (getClass gives the node back when it has none). =#
  local cls = getClass(node)
  cls isa Class || return outExp
  start_node = lookupElementNode("start", cls)
  isvariant(start_node, EMPTY_NODE) && return outExp
  #=
  Make sure we have an actual start attribute, and didn't just find some
  other element named start in the class.
  =#
  start_comp = component(start_node)
  if !isTypeAttribute(start_comp)
    return outExp
  end
  #=  Try to evaluate the binding if one exists. =#
  binding = getBinding(start_comp)
  outExp = begin
    @match binding begin
      #=
      In case the binding is not typed. We type it and then evaluate it.
      added John: Feb 2024
      =#
      UNTYPED_BINDING(__) => begin
        binding = typeBinding(binding, ORIGIN_BINDING)
        #= evalExp, as omc: the value without the start modifier's propagation
           (BINDING_EXP), which applies per element; as the component's value the
           propagated start of r[3](start = {...}) vectorized from_nxy(r, ...). =#
        exp = _evalValue(binding.bindingExp, target)
        if !(exp isa EVAL_FAILURE) && !referenceEq(exp, binding.bindingExp)
          setStartBinding!(start_node, binding, exp)
        end
        SOME(exp)
      end

      TYPED_BINDING(__) => begin
        exp = _evalValue(binding.bindingExp, target)
        if !(exp isa EVAL_FAILURE) && !referenceEq(exp, binding.bindingExp)
          setStartBinding!(start_node, binding, exp)
        end
        SOME(exp)
      end

      _ => begin
        outExp
      end
    end
  end
  return outExp
end

function makeComponentBinding(
  component::Component,
  node::InstNode,
  cref::ComponentRef,
  @nospecialize(target::EvalTarget),
)::Binding
  local binding::Binding
  local ty::ModelicaType
  local exp_ty::ModelicaType
  local rec_node::InstNode
  local exp::Expression
  #=  A record field without an explicit binding: the field of its parent's binding, if the
      parent has one. =#
  exp = makeRecordFieldBindingFromParent(cref, target)
  exp isa EVAL_FAILURE || return CEVAL_BINDING(exp)
  binding = begin
    @match (component, cref) begin
      (
        TYPED_COMPONENT(
          ty = TYPE_COMPLEX(complexTy = COMPLEX_RECORD(rec_node)),
        ),
        _,
      ) => begin
        #=  A record component without an explicit binding, create one from its children.
        =#
        exp =
          makeRecordBindingExp(component.classInst, rec_node, component.ty, cref)
        exp isa EVAL_FAILURE && return EMPTY_BINDING
        exp_ty = typeOf(exp)
        exp =
          BINDING_EXP(exp, exp_ty, exp_ty, list(node), true)
        binding = CEVAL_BINDING(exp)
        if !hasSubscripts(cref)
          node = updateComponent!(setBinding(binding, component), node)
        end
        binding
      end

      (
        TYPED_COMPONENT(
          ty = ty && TYPE_ARRAY(
            elementType = TYPE_COMPLEX(complexTy = COMPLEX_RECORD(rec_node)),
          ),
        ),
        _,
      ) => begin
        #=  A record array component without an explicit binding, create one from its children.
        =#
        exp =
          makeRecordBindingExp(component.classInst, rec_node, component.ty, cref)
        exp isa EVAL_FAILURE && return EMPTY_BINDING
        exp = splitRecordArrayExp(exp)
        exp_ty = typeOf(exp)
        exp =
          BINDING_EXP(exp, exp_ty, exp_ty, list(node), true)
        binding = CEVAL_BINDING(exp)
        if !hasSubscripts(cref)
          node = updateComponent!(setBinding(binding, component), node)
        end
        binding
      end

      _ => begin
        EMPTY_BINDING
      end
    end
  end
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
  local g = (x::Expression) -> begin
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
  local exp::Expression
  local tree::ClassTree
  local comps::Vector{InstNode}
  local args::Vector{Expression} = Expression[]
  local fields::List{Field}
  local ty::ModelicaType
  local c::InstNode
  local cr::ComponentRef
  local arg::Expression
  tree = classTree(getClass(typeNode))
  comps = getComponents(tree)
  for i = 1:arrayLength(comps)
    c = comps[i]
    ty = getType(c)
    cr = COMPONENT_REF_CREF(c, nil, ty, Origin.CREF, cref)
    arg = CREF_EXPRESSION(ty, cr)
    if variability(component(c)) <= Variability.PARAMETER
      arg = evalExp_impl(arg, EVALTARGET_IGNORE_ERRORS())
      arg isa EVAL_FAILURE && return arg
    end
    args = push!(args, arg) #Cons{Expression}(arg, args)
  end
   exp = makeRecord(scopePath(recordNode), recordType, args)
  return exp
end

function splitRecordArrayExp(@nospecialize(exp::Expression))::Expression

  local path::Absyn.Path
  local ty::ModelicaType
  local expl::Vector{Expression}

  @match RECORD_EXPRESSION(path, ty, expl) = exp
   exp = makeRecord(path, arrayElementType(ty), expl)
   exp = fillType(ty, exp)
  return exp
end

function evalTypename(ty::ModelicaType, @nospecialize(originExp::Expression), @nospecialize(target::EvalTarget))::Expression
  local exp::Expression

  #=  Only expand the typename into an array if it's used as a range, and keep
  =#
  #=  them as typenames when used as e.g. dimensions.
  =#
   exp = if isRange(target)
    expandTypename(ty)
  else
    originExp
  end
  return exp
end

function evalRange(@nospecialize(rangeExp::Expression), @nospecialize(target::EvalTarget))::Expression
  local result::Expression

  local ty::ModelicaType
  local start_exp::Expression
  local stop_exp::Expression
  local step_exp::Option{Expression}
  local max_prop_exp::Expression
  local max_prop_count::Int

  @match RANGE_EXPRESSION(
    ty = ty,
    start = start_exp,
    step = step_exp,
    stop = stop_exp,
  ) = rangeExp
   start_exp = _evalValue(start_exp, target)
   start_exp isa EVAL_FAILURE && return start_exp
   step_exp = evalExpOpt(step_exp, target)
   _failedOpt(step_exp) && return EVAL_FAILED
   stop_exp = _evalValue(stop_exp, target)
   stop_exp isa EVAL_FAILURE && return stop_exp
  if isRange(target)
     ty = getRangeType(
      start_exp,
      step_exp,
      stop_exp,
      arrayElementType(ty),
      EvalTarget_getInfo(target),
    )
     result = RANGE_EXPRESSION(ty, start_exp, step_exp, stop_exp)
  else
     result = RANGE_EXPRESSION(ty, start_exp, step_exp, stop_exp)
     result = _bindingExpMapEval(result, evalRangeExp)
  end
  return result
end

function evalRangeExp(@nospecialize(rangeExp::Expression))::Expression
  local exp::Expression

  local start::Expression
  local step::Expression
  local stop::Expression
  local opt_step::Option{Expression}
  local expl::Vector{Expression}
  local ty::ModelicaType
  local literals::List{String}
  local istep::Int

  @match RANGE_EXPRESSION(start = start, step = opt_step, stop = stop) =
    rangeExp
  if isSome(opt_step)
    @match SOME(step) = opt_step
     (ty, expl) = begin
      @match (start, step, stop) begin
        (
          INTEGER_EXPRESSION(__),
          INTEGER_EXPRESSION(istep),
          INTEGER_EXPRESSION(__),
        ) => begin
          #=  The compiler decided to randomly dislike using step.value here, hence istep.
          =#
           expl = Expression[INTEGER_EXPRESSION(i) for i::Int = _intOf(start):istep:_intOf(stop)]
          (TYPE_INTEGER(), expl)
        end

        (
          REAL_EXPRESSION(__),
          REAL_EXPRESSION(__),
          REAL_EXPRESSION(__),
        ) => begin
           expl = evalRangeReal(_realOf(start), _realOf(step), _realOf(stop))
          (TYPE_REAL(), expl)
        end

        _ => begin
          printWrongArgsError(getInstanceName(), list(start, step, stop), sourceInfo())
          return EVAL_FAILED
        end
      end
    end::Tuple{ModelicaType, Vector{Expression}}
  else
     (ty, expl) = begin
      @match (start, stop) begin
        (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) =>
          begin
             expl =
               Expression[INTEGER_EXPRESSION(i) for i::Int = _intOf(start):_intOf(stop)]
            (TYPE_INTEGER(), expl)
          end

        (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
           expl = evalRangeReal(_realOf(start), 1.0, _realOf(stop))
          (TYPE_REAL(), expl)
        end

        (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) =>
          begin
             expl =
              Expression[BOOLEAN_EXPRESSION(b) for b::Bool = _boolOf(start):_boolOf(stop)]
            (TYPE_BOOLEAN(), expl)
          end

        (
          ENUM_LITERAL_EXPRESSION(ty = ty && TYPE_ENUMERATION(__)),
          ENUM_LITERAL_EXPRESSION(__),
        ) => begin
          expl =
            Expression[ENUM_LITERAL_EXPRESSION(ty, listGet(ty.literals, i), i) for i::Int = (start::ENUM_LITERAL_EXPRESSION).index:(stop::ENUM_LITERAL_EXPRESSION).index]
          (ty, expl)
        end

        _ => begin
          printWrongArgsError(getInstanceName(), list(start, stop), sourceInfo())
          return EVAL_FAILED
        end
      end
     end::Tuple{ModelicaType, Vector{Expression}}
  end
  exp = makeArray(
    TYPE_ARRAY(ty, list(fromInteger(length(expl)))), expl
    ;literal = true,
  )
  return exp
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
  local exp::Expression

  local max_prop_exp::Expression
  local max_prop_count::Int

   (max_prop_exp, max_prop_count) =
    mostPropagatedSubExpBinary(exp1, exp2)
  if max_prop_count >= 0
     exp = _bindingExpMap2Eval(
      BINARY_EXPRESSION(exp1, op, exp2),
      (x) -> evalBinaryExp(x, target),
      max_prop_count,
      max_prop_exp,
    )
  else
     exp = evalBinaryOp_dispatch(exp1, op, exp2, target)
  end
  return exp
end

function evalBinaryExp(@nospecialize(binaryExp::Expression), @nospecialize(target::EvalTarget))::Expression
  local result::Expression
  local e1::Expression
  local e2::Expression
  local op::OPERATOR

  @match BINARY_EXPRESSION(exp1 = e1, operator = op, exp2 = e2) = binaryExp
  #= After bindingExpMap unwraps binding expressions, operands may still
     contain unevaluated forms (e.g. SUBSCRIPTED_EXP). Evaluate them
     before dispatching to the concrete arithmetic functions. =#
   e1 = evalExp_impl(e1, target)
   e1 isa EVAL_FAILURE && return e1
   e2 = evalExp_impl(e2, target)
   e2 isa EVAL_FAILURE && return e2
   result = evalBinaryOp_dispatch(e1, op, e2, target)
  return result
end

function evalBinaryOp_dispatch(
  @nospecialize(exp1::Expression),
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  @nospecialize(target::EvalTarget = EVALTARGET_IGNORE_ERRORS()),
)::Expression
  local exp::Expression

   exp = begin
    @match op.op begin
      Op.ADD => begin
        evalBinaryAdd(exp1, exp2)
      end

      Op.SUB => begin
        evalBinarySub(exp1, exp2)
      end

      Op.MUL => begin
        evalBinaryMul(exp1, exp2)
      end

      Op.DIV => begin
        evalBinaryDiv(exp1, exp2, target)
      end

      Op.POW => begin
        evalBinaryPow(exp1, exp2)
      end

      Op.ADD_SCALAR_ARRAY => begin
        evalBinaryScalarArray(exp1, exp2, evalBinaryAdd)
      end

      Op.ADD_ARRAY_SCALAR => begin
        evalBinaryArrayScalar(exp1, exp2, evalBinaryAdd)
      end

      Op.SUB_SCALAR_ARRAY => begin
        evalBinaryScalarArray(exp1, exp2, evalBinarySub)
      end

      Op.SUB_ARRAY_SCALAR => begin
        evalBinaryArrayScalar(exp1, exp2, evalBinarySub)
      end

      Op.MUL_SCALAR_ARRAY => begin
        evalBinaryScalarArray(exp1, exp2, evalBinaryMul)
      end

      Op.MUL_ARRAY_SCALAR => begin
        evalBinaryArrayScalar(exp1, exp2, evalBinaryMul)
      end

      Op.MUL_VECTOR_MATRIX => begin
        evalBinaryMulVectorMatrix(exp1, exp2)
      end

      Op.MUL_MATRIX_VECTOR => begin
        evalBinaryMulMatrixVector(exp1, exp2)
      end

      Op.SCALAR_PRODUCT => begin
        evalBinaryScalarProduct(exp1, exp2)
      end

      Op.MATRIX_PRODUCT => begin
        evalBinaryMatrixProduct(exp1, exp2)
      end

      Op.DIV_SCALAR_ARRAY => begin
        evalBinaryScalarArray(exp1, exp2, (x, y) -> evalBinaryDiv(x, y, target))
      end

      Op.DIV_ARRAY_SCALAR => begin
        evalBinaryArrayScalar(exp1, exp2, (x, y) -> evalBinaryDiv(x, y, target))
      end

      Op.POW_SCALAR_ARRAY => begin
        evalBinaryScalarArray(exp1, exp2, evalBinaryPow)
      end

      Op.POW_ARRAY_SCALAR => begin
        evalBinaryArrayScalar(exp1, exp2, evalBinaryPow)
      end

      Op.POW_MATRIX => begin
        evalBinaryPowMatrix(exp1, exp2)
      end

      _ => begin
        Error.addInternalError(
          getInstanceName() +
          ": unimplemented case for " +
          toString(BINARY_EXPRESSION(exp1, op, exp2)),
          sourceInfo(),
        )
        return EVAL_FAILED
      end
    end
  end
  return exp
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
  return makeArray(a.ty, out; literal = true)
end

#= An Integer with a Real: both as Reals, as typing would have cast them (a function body
   evaluated with Integer arguments, an Integer literal in a Real array: Buildings' Movers). =#
@inline function _mixedAsReal(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))
  exp1 isa INTEGER_EXPRESSION && exp2 isa REAL_EXPRESSION && return (REAL_EXPRESSION(Float64(exp1.value)), exp2)
  exp1 isa REAL_EXPRESSION && exp2 isa INTEGER_EXPRESSION && return (exp1, REAL_EXPRESSION(Float64(exp2.value)))
  return (exp1, exp2)
end

function evalBinaryAdd(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  local exp::Expression

   exp = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        INTEGER_EXPRESSION(exp1.value + exp2.value)
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        REAL_EXPRESSION(exp1.value + exp2.value)
      end

      (STRING_EXPRESSION(__), STRING_EXPRESSION(__)) => begin
        STRING_EXPRESSION(exp1.value + exp2.value)
      end

      (
        ARRAY_EXPRESSION(__),
        ARRAY_EXPRESSION(__),
      ) where {(length(exp1.elements) == length(exp2.elements))} => begin
        _evalElementwise(evalBinaryAdd, exp1, exp2)
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makeAdd(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return exp
end

function evalBinarySub(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  local exp::Expression

   exp = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        INTEGER_EXPRESSION(exp1.value - exp2.value)
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        REAL_EXPRESSION(exp1.value - exp2.value)
      end

      (
        ARRAY_EXPRESSION(__),
        ARRAY_EXPRESSION(__),
      ) where {(length(exp1.elements) == length(exp2.elements))} => begin
        _evalElementwise(evalBinarySub, exp1, exp2)
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makeSub(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return exp
end

function evalBinaryMul(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  local exp::Expression

   exp = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        INTEGER_EXPRESSION(exp1.value * exp2.value)
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        REAL_EXPRESSION(exp1.value * exp2.value)
      end

      (INTEGER_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        REAL_EXPRESSION(Float64(exp1.value) * exp2.value)
      end

      (REAL_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        REAL_EXPRESSION(exp1.value * Float64(exp2.value))
      end

      (
        ARRAY_EXPRESSION(__),
        ARRAY_EXPRESSION(__),
      ) where {(length(exp1.elements) == length(exp2.elements))} => begin
        _evalElementwise(evalBinaryMul, exp1, exp2)
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makeMul(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return exp
end

function evalBinaryDiv(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression), @nospecialize(target::EvalTarget))::Expression
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  local exp::Expression

   exp = begin
    @match (exp1, exp2) begin
      (_, REAL_EXPRESSION(0.0)) => begin
        if hasInfo(target)
          Error.addSourceMessage(
            Error.DIVISION_BY_ZERO,
            list(
              toString(exp1),
              toString(exp2),
            ),
            EvalTarget_getInfo(target),
          )
          return EVAL_FAILED
        else
           exp = BINARY_EXPRESSION(
            exp1,
            makeDiv(TYPE_REAL()),
            exp2,
          )
        end
        exp
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        REAL_EXPRESSION(exp1.value / exp2.value)
      end

      (
        ARRAY_EXPRESSION(__),
        ARRAY_EXPRESSION(__),
      ) where {(length(exp1.elements) == length(exp2.elements))} => begin
        _evalElementwise((x, y) -> evalBinaryDiv(x, y, target), exp1, exp2)
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makeDiv(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return exp
end

function evalBinaryPow(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  (exp1, exp2) = _mixedAsReal(exp1, exp2)
  local exp::Expression

   exp = begin
    @match (exp1, exp2) begin
      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        REAL_EXPRESSION(exp1.value^exp2.value)
      end

      (
        ARRAY_EXPRESSION(__),
        ARRAY_EXPRESSION(__),
      ) where {(length(exp1.elements) == length(exp2.elements))} => begin
        _evalElementwise(evalBinaryPow, exp1, exp2)
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makePow(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return exp
end

"""
`f` on each element: `(true, values)`, or `(false, Expression[])` at the first element that
fails (see `EVAL_FAILURE`).
"""
function _mapChecked(f::F, elements::Vector{Expression})::Tuple{Bool, Vector{Expression}} where {F}
  local out::Vector{Expression} = Vector{Expression}(undef, length(elements))
  for i in eachindex(elements)
    local e::Expression = f(elements[i])
    e isa EVAL_FAILURE && return (false, Expression[])
    out[i] = e
  end
  return (true, out)
end

"""`opFunc(scalar, element)` over every element of a (nested) array."""
function evalBinaryScalarArray(
  @nospecialize(scalarExp::Expression),
  @nospecialize(arrayExp::Expression),
  opFunc::FuncT,
)::Expression
  arrayExp isa ARRAY_EXPRESSION || return opFunc(scalarExp, arrayExp)
  local (ok::Bool, expl::Vector{Expression}) = _mapChecked(e -> evalBinaryScalarArray(scalarExp, e, opFunc), arrayExp.elements)
  ok || return EVAL_FAILED
  return makeArray(arrayExp.ty, expl, literal = true)
end

"""`opFunc(element, scalar)` over every element of a (nested) array."""
function evalBinaryArrayScalar(
  @nospecialize(arrayExp::Expression),
  @nospecialize(scalarExp::Expression),
  opFunc::FuncT,
)::Expression
  arrayExp isa ARRAY_EXPRESSION || return opFunc(arrayExp, scalarExp)
  local (ok::Bool, expl::Vector{Expression}) = _mapChecked(e -> evalBinaryArrayScalar(e, scalarExp, opFunc), arrayExp.elements)
  ok || return EVAL_FAILED
  return ARRAY_EXPRESSION(arrayExp.ty, expl, true)
end

"""Whether a type is a two-dimensional array (a matrix)."""
_isMatrixType(ty::ModelicaType)::Bool = ty.tag == NFT_ARRAY && listLength(ty.dimensions) == 2

"""The error of an arithmetic operation on values it is not defined for, and `EVAL_FAILED`."""
function _failedBinary(@nospecialize(exp1::Expression), op::OPERATOR, @nospecialize(exp2::Expression), name::String)::Expression
  printFailedEvalError(name, BINARY_EXPRESSION(exp1, op, exp2), sourceInfo())
  return EVAL_FAILED
end

function evalBinaryMulVectorMatrix(@nospecialize(vectorExp::Expression), @nospecialize(matrixExp::Expression))::Expression
  local t::Expression = transposeArray(matrixExp)
  if t isa ARRAY_EXPRESSION && _isMatrixType(t.ty)
    local (ok::Bool, expl::Vector{Expression}) = _mapChecked(e -> evalBinaryScalarProduct(vectorExp, e), t.elements)
    ok || return EVAL_FAILED
    return makeArray(TYPE_ARRAY(t.ty.elementType::ModelicaType, list(listHead(t.ty.dimensions))), expl, literal = true)
  end
  return _failedBinary(vectorExp, makeMul(TYPE_UNKNOWN()), matrixExp, getInstanceName())
end

function evalBinaryMulMatrixVector(@nospecialize(matrixExp::Expression), @nospecialize(vectorExp::Expression))::Expression
  if matrixExp isa ARRAY_EXPRESSION && _isMatrixType(matrixExp.ty)
    local (ok::Bool, expl::Vector{Expression}) = _mapChecked(e -> evalBinaryScalarProduct(e, vectorExp), matrixExp.elements)
    ok || return EVAL_FAILED
    return makeArray(TYPE_ARRAY(matrixExp.ty.elementType::ModelicaType, list(listHead(matrixExp.ty.dimensions))), expl, literal = true)
  end
  return _failedBinary(matrixExp, makeMul(TYPE_UNKNOWN()), vectorExp, getInstanceName())
end

function evalBinaryScalarProduct(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  if exp1 isa ARRAY_EXPRESSION && exp2 isa ARRAY_EXPRESSION && exp1.ty.tag == NFT_ARRAY &&
     length(exp1.elements) == length(exp2.elements)
    local exp::Expression = makeZero(exp1.ty.elementType::ModelicaType)
    for i in eachindex(exp1.elements)
      local p::Expression = evalBinaryMul(exp1.elements[i], exp2.elements[i])
      p isa EVAL_FAILURE && return p
      exp = evalBinaryAdd(exp, p)
      exp isa EVAL_FAILURE && return exp
    end
    return exp
  end
  return _failedBinary(exp1, makeMul(TYPE_UNKNOWN()), exp2, getInstanceName())
end

function evalBinaryMatrixProduct(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  local e2::Expression = transposeArray(exp2)
  if exp1 isa ARRAY_EXPRESSION && e2 isa ARRAY_EXPRESSION && _isMatrixType(exp1.ty) && _isMatrixType(e2.ty)
    local elem_ty::ModelicaType = exp1.ty.elementType::ModelicaType
    local n::Dimension = listHead(exp1.ty.dimensions)
    local p::Dimension = listHead(e2.ty.dimensions)
    local mat_ty::ModelicaType = TYPE_ARRAY(elem_ty, list(n, p))
    isempty(e2.elements) && return makeZero(mat_ty)
    local row_ty::ModelicaType = TYPE_ARRAY(elem_ty, list(p))
    local rows::Vector{Expression} = Vector{Expression}(undef, length(exp1.elements))
    for i in eachindex(exp1.elements)
      local r::Expression = exp1.elements[i]
      local (ok::Bool, row::Vector{Expression}) = _mapChecked(c -> evalBinaryScalarProduct(r, c), e2.elements)
      ok || return EVAL_FAILED
      rows[i] = makeArray(row_ty, row, literal = true)
    end
    return makeArray(mat_ty, rows, literal = true)
  end
  return _failedBinary(exp1, makeMul(TYPE_UNKNOWN()), exp2, getInstanceName())
end

function evalBinaryPowMatrix(@nospecialize(matrixExp::Expression), @nospecialize(nExp::Expression))::Expression
  if nExp isa INTEGER_EXPRESSION
    if nExp.value == 0 && matrixExp isa ARRAY_EXPRESSION
      return makeIdentityMatrix(size(listHead(arrayDims(matrixExp.ty))), TYPE_REAL())
    end
    return evalBinaryPowMatrix2(matrixExp, nExp.value)
  end
  return _failedBinary(matrixExp, makePow(TYPE_UNKNOWN()), nExp, getInstanceName())
end

"""A^n by squaring: A^1 = A, A^(2m) = A^m * A^m, A^n = A * A^(n-1)."""
function evalBinaryPowMatrix2(@nospecialize(matrix::Expression), n::Int)::Expression
  n == 1 && return matrix
  n == 2 && return evalBinaryMatrixProduct(matrix, matrix)
  if intMod(n, 2) == 0
    local half::Expression = evalBinaryPowMatrix2(matrix, intDiv(n, 2))
    half isa EVAL_FAILURE && return half
    return evalBinaryMatrixProduct(half, half)
  end
  local rest::Expression = evalBinaryPowMatrix2(matrix, n - 1)
  rest isa EVAL_FAILURE && return rest
  return evalBinaryMatrixProduct(matrix, rest)
end

function evalUnaryOp(@nospecialize(exp1::Expression), op::OPERATOR)::Expression
  op.op == Op.UMINUS && return _bindingExpMapEval(exp1, evalUnaryMinus)
  Error.addInternalError(getInstanceName() + ": unimplemented case for " + toString(UNARY_EXPRESSION(op, exp1)),
                         sourceInfo())
  return EVAL_FAILED
end

function evalUnaryMinus(@nospecialize(exp1::Expression))::Expression
  exp1 isa INTEGER_EXPRESSION && return INTEGER_EXPRESSION(-exp1.value)
  exp1 isa REAL_EXPRESSION && return REAL_EXPRESSION(-exp1.value)
  if exp1 isa ARRAY_EXPRESSION
    local (ok::Bool, expl::Vector{Expression}) = _mapChecked(evalUnaryMinus, exp1.elements)
    ok || return EVAL_FAILED
    return ARRAY_EXPRESSION(exp1.ty, expl, exp1.literal)
  end
  printFailedEvalError(getInstanceName(), UNARY_EXPRESSION(makeUMinus(TYPE_UNKNOWN()), exp1), sourceInfo())
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
                             (binaryExpArg) -> evalLogicBinaryExp(binaryExpArg, target),
                             max_prop_count, max_prop_exp)
end

function evalLogicBinaryExp(@nospecialize(binaryExp::Expression), @nospecialize(target::EvalTarget))::Expression
  local b::LBINARY_EXPRESSION = binaryExp::LBINARY_EXPRESSION
  return evalLogicBinaryOp_dispatch(b.exp1, b.operator, b.exp2, target)
end

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
  Error.addInternalError(getInstanceName() + ": unimplemented case for " + toString(LBINARY_EXPRESSION(exp1, op, exp2)),
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
  printFailedEvalError(getInstanceName(), LBINARY_EXPRESSION(exp1, makeAnd(TYPE_UNKNOWN()), exp2), sourceInfo())
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
  printFailedEvalError(getInstanceName(), LBINARY_EXPRESSION(exp1, makeOr(TYPE_UNKNOWN()), exp2), sourceInfo())
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
  Error.addInternalError(getInstanceName() + ": unimplemented case for " + toString(LUNARY_EXPRESSION(op, exp1)),
                         sourceInfo())
  return EVAL_FAILED
end

function evalLogicUnaryNot(@nospecialize(exp1::Expression))::Expression
  exp1 isa BOOLEAN_EXPRESSION && return BOOLEAN_EXPRESSION(!exp1.value)
  if exp1 isa ARRAY_EXPRESSION
    local (ok::Bool, expl::Vector{Expression}) = _mapChecked(evalLogicUnaryNot, exp1.elements)
    ok || return EVAL_FAILED
    return ARRAY_EXPRESSION(exp1.ty, expl, exp1.literal)
  end
  printFailedEvalError(getInstanceName(), LUNARY_EXPRESSION(makeNot(TYPE_UNKNOWN()), exp1), sourceInfo())
  return EVAL_FAILED
end

function evalRelationOp(@nospecialize(exp1::Expression), op::OPERATOR, @nospecialize(exp2::Expression))::Expression
  local (max_prop_exp::Expression, max_prop_count::Int) = mostPropagatedSubExpBinary(exp1, exp2)
  max_prop_count >= 0 || return evalRelationOp_dispatch(exp1, op, exp2)
  return _bindingExpMap2Eval(RELATION_EXPRESSION(exp1, op, exp2), evalRelationExp, max_prop_count, max_prop_exp)
end

function evalRelationExp(@nospecialize(relationExp::Expression))::Expression
  local r::RELATION_EXPRESSION = relationExp::RELATION_EXPRESSION
  return evalRelationOp_dispatch(r.exp1, r.operator, r.exp2)
end

"""A relation of two literals: `BOOLEAN_EXPRESSION`, or `EVAL_FAILED` for other operands."""
function evalRelationOp_dispatch(
  @nospecialize(exp1::Expression),
  op::OPERATOR,
  @nospecialize(exp2::Expression),
)::Expression
  local o::Int = op.op
  if !(o == Op.LESS || o == Op.LESSEQ || o == Op.GREATER || o == Op.GREATEREQ || o == Op.EQUAL || o == Op.NEQUAL)
    Error.addInternalError(getInstanceName() + ": unimplemented case for " + toString(RELATION_EXPRESSION(exp1, op, exp2)),
                           sourceInfo())
    return EVAL_FAILED
  end
  local (ok::Bool, res::Bool) = _relation(o, exp1, exp2)
  if !ok
    printFailedEvalError(getInstanceName(), RELATION_EXPRESSION(exp1, OPERATOR(TYPE_UNKNOWN(), o), exp2), sourceInfo())
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

function evalIfExp(@nospecialize(ifExp::Expression), @nospecialize(target::EvalTarget))::Expression
  local e::IF_EXPRESSION = ifExp::IF_EXPRESSION
  local cond::Expression = evalExp_impl(e.condition, target)
  cond isa EVAL_FAILURE && return cond
  return _bindingExpMapEval(IF_EXPRESSION(cond, e.trueBranch, e.falseBranch), (x) -> evalIfExp2(x, target))
end

function evalIfExp2(@nospecialize(ifExp::Expression), @nospecialize(target::EvalTarget))::Expression
  local e::IF_EXPRESSION = ifExp::IF_EXPRESSION
  local cond::Expression = e.condition
  cond isa BOOLEAN_EXPRESSION && return evalExp_impl(cond.value ? e.trueBranch : e.falseBranch, target)
  Error.addInternalError(getInstanceName() + ": unimplemented case for " + toString(e), sourceInfo())
  return EVAL_FAILED
end

function evalCast(@nospecialize(castExp::Expression), castTy::ModelicaType)::Expression
  local exp::Expression

   exp = typeCast(castExp, castTy)
  #=  Expression.typeCast will just create a CAST if it can't typecast
  =#
  #=  the expression, so make sure we actually got something else back.
  =#
   () = begin
    @match exp begin
      CAST_EXPRESSION(__) => begin
         exp = CAST_EXPRESSION(castTy, castExp)
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        return EVAL_FAILED
      end

      _ => begin
        ()
      end
    end
  end
  return exp
end

@nospecializeinfer function evalCall(call::Call, target::EvalTarget)::Expression
  local exp::Expression
  local c::Call = call
  # @info "evalCall..."
  # println(replace(toString(call), "\n\n" => "\n"))
  exp = begin
    local args::List{Expression}
    @match c begin
      TYPED_CALL(__) => begin
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
        if cArgs !== args0
          c = TYPED_CALL(c.fn, c.ty, c.var, cArgs, c.attributes)
        end
        if isBuiltin(c.fn)
          _bindingExpMapEval(CALL_EXPRESSION(c), @closure (x) -> evalxp(x, target))
        else
          _bindingExpMapEval(CALL_EXPRESSION(c), evalNormalCallExp)
        end
      end
      TYPED_ARRAY_CONSTRUCTOR(__) => begin
        evalArrayConstructor(c.exp, c.iters)
      end
      TYPED_REDUCTION(__) => begin
        evalReduction(c.fn, c.exp, c.iters)
      end
      _ => begin
        Error.addInternalError(getInstanceName() + " got untyped call", sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return exp
end

#Note was originally called evalBuiltinCallExp, but the translator seems to have butchered the name for this function..
function evalxp(@nospecialize(callExp::Expression), @nospecialize(target::EvalTarget))::Expression
  local result::Expression
  local fn::MODELICA_FUNCTION
  local args::Vector{Expression}
  @match CALL_EXPRESSION(call = TYPED_CALL(fn = fn, arguments = args)) = callExp
  result = ceval(fn, args, target)
  return result
end

function ceval(
  fn::MODELICA_FUNCTION,
  args::Vector{Expression},
  @nospecialize(target::EvalTarget),
)::Expression
  local result::Expression
  local fn_path::Absyn.Path = nameConsiderBuiltin(fn)
   result = begin
    @match AbsynUtil.pathFirstIdent(fn_path) begin
      "abs" => begin
        evalBuiltinAbs(Base.first(args))
      end

      "acos" => begin
        evalBuiltinAcos(Base.first(args), target)
      end

      "array" => begin
        evalBuiltinArray(args)
      end

      "asin" => begin
        evalBuiltinAsin(Base.first(args), target)
      end

      "atan2" => begin
        evalBuiltinAtan2(args)
      end

      "atan" => begin
        evalBuiltinAtan(Base.first(args))
      end

      "cat" => begin
        evalBuiltinCat(Base.first(args), args[2:end]#=TODO: Check if views can be used.=#, target)
      end

      "ceil" => begin
        evalBuiltinCeil(Base.first(args))
      end

      "cosh" => begin
        evalBuiltinCosh(Base.first(args))
      end

      "cos" => begin
        evalBuiltinCos(Base.first(args))
      end

      "der" => begin
        evalBuiltinDer(Base.first(args))
      end

      "diagonal" => begin
        evalBuiltinDiagonal(unbox(Base.first(args)))
      end

      "div" => begin
        evalBuiltinDiv(args, target)
      end

      "exp" => begin
        evalBuiltinExp(Base.first(args))
      end

      "fill" => begin
        evalBuiltinFill(args)
      end

      "floor" => begin
        evalBuiltinFloor(Base.first(args))
      end

      "identity" => begin
        evalBuiltinIdentity(Base.first(args))
      end

      "integer" => begin
        evalBuiltinInteger(Base.first(args))
      end

      "Integer" => begin
        evalBuiltinIntegerEnum(Base.first(args))
      end

      "log10" => begin
        evalBuiltinLog10(Base.first(args), target)
      end

      "log" => begin
        evalBuiltinLog(Base.first(args), target)
      end

      "matrix" => begin
        evalBuiltinMatrix(Base.first(args))
      end

      "max" => begin
        evalBuiltinMax(args, fn)
      end

      "min" => begin
        evalBuiltinMin(args, fn)
      end

      "mod" => begin
        evalBuiltinMod(args, target)
      end

      "noEvent" => begin
        Base.first(args)
      end

      "ones" => begin
        evalBuiltinOnes(args)
      end

      "product" => begin
        evalBuiltinProduct(Base.first(args))
      end

      "promote" => begin
        evalBuiltinPromote(args[1], args[2])
      end

      "rem" => begin
        evalBuiltinRem(args, target)
      end

      "scalar" => begin
        evalBuiltinScalar(args)
      end

      "sign" => begin
        evalBuiltinSign(Base.first(args))
      end

      "sinh" => begin
        evalBuiltinSinh(Base.first(args))
      end

      "sin" => begin
        evalBuiltinSin(Base.first(args))
      end

      "skew" => begin
        evalBuiltinSkew(Base.first(args))
      end

      "smooth" => begin
        args[2]
      end

      "sqrt" => begin
        evalBuiltinSqrt(Base.first(args))
      end

      "String" => begin
        evalBuiltinString(args)
      end

      "sum" => begin
        evalBuiltinSum(Base.first(args))
      end

      "symmetric" => begin
        evalBuiltinSymmetric(Base.first(args))
      end

      "tanh" => begin
        evalBuiltinTanh(Base.first(args))
      end

      "tan" => begin
        evalBuiltinTan(Base.first(args))
      end

      "transpose" => begin
        evalBuiltinTranspose(Base.first(args))
      end

      "vector" => begin
        evalBuiltinVector(Base.first(args))
      end

      "zeros" => begin
        evalBuiltinZeros(args)
      end

      "OpenModelica_uriToFilename" => begin
        evalUriToFilename(fn, args, target)
      end

      "intBitAnd" => begin
        evalIntBitAnd(args)
      end

      "intBitOr" => begin
        evalIntBitOr(args)
      end

      "intBitXor" => begin
        evalIntBitXor(args)
      end

      "intBitLShift" => begin
        evalIntBitLShift(args)
      end

      "intBitRShift" => begin
        evalIntBitRShift(args)
      end

      "inferredClock" => begin
        evalInferredClock(args)
      end

      "rationalClock" => begin
        evalRationalClock(args)
      end

      "realClock" => begin
        evalRealClock(args)
      end

      "booleanClock" => begin
        evalBooleanClock(args)
      end

      "solverClock" => begin
        evalSolverClock(args)
      end

      "DynamicSelect" => begin
        evalBuiltinDynamicSelect(fn, args, target)
      end

      _ => begin
        #=  TODO: Fix typing of diagonal so the argument isn't boxed.
        =#
        #=  No events during ceval, just return the argument.
        =#
        Error.addInternalError(
          getInstanceName() + ": unimplemented case for " + AbsynUtil.pathString(fn_path),
          sourceInfo(),
        )
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalNormalCallExp(@nospecialize(callExp::Expression))::Expression
  local result::Expression
  local fn::MODELICA_FUNCTION
  local args::Vector{Expression}
  @match CALL_EXPRESSION(call = TYPED_CALL(fn = fn, arguments = args)) = callExp
  result = evalNormalCall(fn, args)
  return result
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

function evalBuiltinAbs(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      INTEGER_EXPRESSION(__) => begin
        INTEGER_EXPRESSION(abs(_intOf(arg)))
      end

      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(abs(_realOf(arg)))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinAcos(@nospecialize(arg::Expression), @nospecialize(target::EvalTarget))::Expression
  local result::Expression

  local x::AbstractFloat

   result = begin
    @match arg begin
      REAL_EXPRESSION(value = x) => begin
        if x < (-1.0) || x > 1.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.ARGUMENT_OUT_OF_RANGE,
              list(string(x), "acos", "-1 <= x <= 1"),
              EvalTarget_getInfo(target),
            )
          end
          return EVAL_FAILED
        end
        REAL_EXPRESSION(acos(x))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinArray(args::Union{List{Expression}, Vector{Expression}})::Expression
  local result::Expression
  local ty::ModelicaType
  ty = typeOf(Base.first(args))
  ty = liftArrayLeft(ty, fromInteger(length(args)))
  result = makeArray(ty, args, literal = true)
  return result
end

function evalBuiltinAsin(@nospecialize(arg::Expression), @nospecialize(target::EvalTarget))::Expression
  local result::Expression

  local x::AbstractFloat

   result = begin
    @match arg begin
      REAL_EXPRESSION(value = x) => begin
        if x < (-1.0) || x > 1.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.ARGUMENT_OUT_OF_RANGE,
              list(string(x), "asin", "-1 <= x <= 1"),
              EvalTarget_getInfo(target),
            )
          end
          return EVAL_FAILED
        end
        REAL_EXPRESSION(asin(x))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinAtan2(args::Union{List{Expression}, Vector{Expression}})::Expression
  local result::Expression
  local y::AbstractFloat
  local x::AbstractFloat
  if length(args) == 2 && Base.first(args) isa REAL_EXPRESSION && Base.last(args) isa REAL_EXPRESSION
    result = REAL_EXPRESSION(atan(_realOf(Base.first(args)), _realOf(Base.last(args))))
  else
    printWrongArgsError(getInstanceName(), args, sourceInfo())
    return EVAL_FAILED
  end
  return result
end

function evalBuiltinAtan(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(atan(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinCat(
  @nospecialize(argN::Expression),
  args::Vector{Expression},
  @nospecialize(target::EvalTarget),
  )::Expression
  local result::Expression
  local n::Int
  local nd::Int
  local sz::Int
  local ty::ModelicaType
  local es::Vector{Expression}
  local dims::List{Int}
  if !(argN isa INTEGER_EXPRESSION)
    printWrongArgsError(getInstanceName(), Expression[argN], sourceInfo())
    return EVAL_FAILED
  end
  n = _intOf(argN)
  ty = typeOf(Base.first(args))
  nd = dimensionCount(ty)
  if n > nd || n < 1
    if hasInfo(target)
      Error.addSourceMessage(
        Error.ARGUMENT_OUT_OF_RANGE,
        list(string(n), "cat", "1 <= x <= " + string(nd)),
        EvalTarget_getInfo(target),
      )
    end
    return EVAL_FAILED
  end
  es = Expression[e for e in args if !isEmptyArray(e)]
  sz = length(es)
  if sz == 0
    result = Base.first(args)
  elseif sz == 1
    result = Base.first(es)
  else
    #= A ragged argument: not evaluated (no message, as before). =#
    n > 1 && !all(e::Expression -> _catPartRegular(e, n), es) && return EVAL_FAILED
    (es, dims) = evalCat(n, es, arrayElements, toString)
    argL::List{Dimension} = nil
    tmp = listReverse(dims)
    while tmp !== nil
      @match Cons{Int}(d, tmp) = tmp
      argL = Cons{Dimension}(fromInteger(d), argL)
    end
    result = arrayFromVector(es, typeOf(Base.first(es)), argL)
    #    @info "Made array" toString(result)
  end
  #println("Result:\n" * toString(result))
  return result
end

function evalBuiltinCeil(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(ceil(_realOf(arg)))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinCosh(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(cosh(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

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

function evalBuiltinCos(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(roundingZero(cos(_realOf(arg)), _realOf(arg)))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinDer(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = fillType(
    typeOf(arg),
    REAL_EXPRESSION(0.0),
  )
  return result
end

function evalBuiltinDiagonal(@nospecialize(arg::Expression))::Expression
  local result::Expression

  local elem_ty::ModelicaType
  local row_ty::ModelicaType
  local zero::Expression
  local elems::Vector{Expression}
  local n::Int
  local e_lit::Bool
  local arg_lit::Bool = true
   result = begin
    @match arg begin
      ARRAY_EXPRESSION(__) where {isempty(arg.elements)} => begin
        arg
      end
      ARRAY_EXPRESSION(elements = elems) => begin
         n = length(elems)
        elem_ty = typeOf(Base.first(elems))
        row_ty = liftArrayLeft(elem_ty, fromInteger(n))
         zero = makeZero(elem_ty)
        local rows = Expression[]
        for (idx, e) in enumerate(elems)
          local row = Expression[j == idx ? e : zero for j in 1:n]
           e_lit = isLiteral(e)
           arg_lit = arg_lit && e_lit
          push!(rows, makeArray(row_ty, row; literal = e_lit))
        end
        makeArray(
          liftArrayLeft(row_ty, fromInteger(n)),
          rows;
          literal = arg_lit,
        )
      end
      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinDiv(args::Vector{Expression}, @nospecialize(target::EvalTarget))::Expression
  local result::Expression
  local rx::AbstractFloat
  local ry::AbstractFloat
  local ix::Int
  local iy::Int
   result = begin
    @match args begin
      [INTEGER_EXPRESSION(ix), INTEGER_EXPRESSION(iy)] => begin
        if iy == 0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.DIVISION_BY_ZERO,
              list(string(ix), string(iy)),
              EvalTarget_getInfo(target),
            )
          end
          return EVAL_FAILED
        end
        INTEGER_EXPRESSION(intDiv(ix, iy))
      end

      [REAL_EXPRESSION(rx), REAL_EXPRESSION(ry)] =>
        begin
          if ry == 0.0
            if hasInfo(target)
              Error.addSourceMessage(
                Error.DIVISION_BY_ZERO,
                list(string(rx), string(ry)),
                EvalTarget_getInfo(target),
              )
            end
            return EVAL_FAILED
          end
           rx = rx / ry
          REAL_EXPRESSION(if rx < 0.0
            ceil(rx)
          else
            floor(rx)
          end)
        end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinExp(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(exp(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinFill(args::Vector{Expression})::Expression
  local result::Expression
  result = evalBuiltinFill2(Base.first(args), args[2:end])
  return result
end

function evalBuiltinFill2(@nospecialize(fillValue::Expression), dims::Union{Vector{Expression}, List{Expression}})::Expression
  local result::Expression = fillValue
  local dim_size::Int
  local arr::Vector{Expression}
  local arr_ty::ModelicaType = typeOf(result)
  for d in reverse(dims)
    dim_size = begin
      @match d begin
        INTEGER_EXPRESSION(value = dim_size) => dim_size
        _ => begin
          printWrongArgsError(getInstanceName(), list(d), sourceInfo())
          return EVAL_FAILED
        end
      end
    end
    arr = Expression[result for e = 1:dim_size]
    arr_ty = liftArrayLeft(arr_ty, fromInteger(dim_size))
    result = makeArray(
      arr_ty,
      arr;
      literal = isLiteral(fillValue),
    )
  end
  return result
end

function evalBuiltinFloor(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(floor(_realOf(arg)))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinIdentity(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      INTEGER_EXPRESSION(__) => begin
        makeIdentityMatrix(arg.value, TYPE_INTEGER())
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinInteger(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      INTEGER_EXPRESSION(__) => begin
        arg
      end

      REAL_EXPRESSION(__) => begin
        INTEGER_EXPRESSION(realInt(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinIntegerEnum(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      ENUM_LITERAL_EXPRESSION(__) => begin
        INTEGER_EXPRESSION(arg.index)
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinLog10(@nospecialize(arg::Expression), @nospecialize(target::EvalTarget))::Expression
  local result::Expression

  local x::AbstractFloat

   result = begin
    @match arg begin
      REAL_EXPRESSION(value = x) => begin
        if x <= 0.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.ARGUMENT_OUT_OF_RANGE,
              list(string(x), "log10", "x > 0"),
              EvalTarget_getInfo(target),
            )
          end
          return EVAL_FAILED
        end
        REAL_EXPRESSION(log10(x))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinLog(@nospecialize(arg::Expression), @nospecialize(target::EvalTarget))::Expression
  local result::Expression

  local x::AbstractFloat

   result = begin
    @match arg begin
      REAL_EXPRESSION(value = x) => begin
        if x <= 0.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.ARGUMENT_OUT_OF_RANGE,
              list(string(x), "log", "x > 0"),
              EvalTarget_getInfo(target),
            )
          end
          return EVAL_FAILED
        end
        REAL_EXPRESSION(log(x))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinMatrix(@nospecialize(arg::Expression))::Expression
  local result::Expression
   result = begin
    local dim_count::Int
    local dim1::Dimension
    local dim2::Dimension
    local ty::ModelicaType
    @match arg begin
      ARRAY_EXPRESSION(ty = ty) => begin
         dim_count = dimensionCount(ty)
        if dim_count < 2
           result = promote(arg, ty, 2)
        elseif dim_count == 2
           result = arg
        else
          @match _cons(dim1, _cons(dim2, _)) = arrayDims(ty)
           ty = liftArrayLeft(arrayElementType(ty), dim2)
          local expl = Expression[evalBuiltinMatrix2(e, ty) for e in arg.elements]
           ty = liftArrayLeft(ty, dim1)
           result = makeArray(ty, expl)
        end
        result
      end

      _ => begin
         ty = typeOf(arg)
        if isScalar(ty)
           result = promote(arg, ty, 2)
        else
          printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
          return EVAL_FAILED
        end
        result
      end
    end
  end
  return result
end

function evalBuiltinMatrix2(@nospecialize(arg::Expression), ty::ModelicaType)::Expression
  local result::Expression

   result = begin
    @match arg begin
      ARRAY_EXPRESSION(__) => begin
        makeArray(
          ty,
          Expression[toScalar(e) for e in arg.elements];
          literal = arg.literal,
        )
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
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

function evalBuiltinMax(args::Vector{Expression}, fn::MODELICA_FUNCTION)::Expression
  local result::Expression
  local e1::Expression
  local e2::Expression
  local ty::ModelicaType
  result = begin
    @match args begin
      [e1, e2] => begin
        evalBuiltinMax2(e1, e2)
      end
      [e1] && [ARRAY_EXPRESSION(ty = ty)] => begin
        result = foldArrayElements(e1, (e, acc) -> acc isa EVAL_FAILURE ? acc : evalBuiltinMax2(e, acc), EMPTY_EXPRESSION(ty), Expression)
        result isa EVAL_FAILURE && return result
        if isEmpty(result)
          result = CALL_EXPRESSION(makeTypedCall(
            fn,
            Expression[makeEmptyArray(ty)],
            Variability.CONSTANT,
            arrayElementType(ty),
          ))
        end
        result
      end
      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinMax2(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  local result::Expression

   result = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        if _intOf(exp1) < _intOf(exp2)
          exp2
        else
          exp1
        end
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        if _realOf(exp1) < _realOf(exp2)
          exp2
        else
          exp1
        end
      end

      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        if _boolOf(exp1) < _boolOf(exp2)
          exp2
        else
          exp1
        end
      end

      (
        ENUM_LITERAL_EXPRESSION(__),
        ENUM_LITERAL_EXPRESSION(__),
      ) => begin
        if exp1.index < exp2.index
          exp2
        else
          exp1
        end
      end

      (ARRAY_EXPRESSION(__), _) => begin
        exp2
      end

      (_, EMPTY_EXPRESSION(__)) => begin
        exp1
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(exp1, exp2), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinMin(args::Union{List{Expression}, Vector{Expression}}, fn::MODELICA_FUNCTION)::Expression
  local result::Expression
  local e1::Expression
  local ty::ModelicaType
  local nArgs::Int = length(args)

  if nArgs == 2
    result = evalBuiltinMin2(Base.first(args), Base.last(args))
  elseif nArgs == 1
    e1 = Base.first(args)
    if !(e1 isa ARRAY_EXPRESSION)
      printWrongArgsError(getInstanceName(), args, sourceInfo())
      return EVAL_FAILED
    end
    ty = e1.ty
    result = foldArrayElements(e1, (e, acc) -> acc isa EVAL_FAILURE ? acc : evalBuiltinMin2(e, acc), EMPTY_EXPRESSION(ty), Expression)
    result isa EVAL_FAILURE && return result
    if isEmpty(result)
      result = CALL_EXPRESSION(makeTypedCall(
        fn,
        Expression[makeEmptyArray(ty)],
        Variability.CONSTANT,
        arrayElementType(ty),
      ))
    end
  else
    printWrongArgsError(getInstanceName(), args, sourceInfo())
    return EVAL_FAILED
  end
  return result
end

function evalBuiltinMin2(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  local result::Expression

   result = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        if _intOf(exp1) > _intOf(exp2)
          exp2
        else
          exp1
        end
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        if _realOf(exp1) > _realOf(exp2)
          exp2
        else
          exp1
        end
      end

      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        if _boolOf(exp1) > _boolOf(exp2)
          exp2
        else
          exp1
        end
      end

      (
        ENUM_LITERAL_EXPRESSION(__),
        ENUM_LITERAL_EXPRESSION(__),
      ) => begin
        if exp1.index > exp2.index
          exp2
        else
          exp1
        end
      end

      (ARRAY_EXPRESSION(__), _) => begin
        exp2
      end

      (_, EMPTY_EXPRESSION(__)) => begin
        exp1
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(exp1, exp2), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinMod(args::Vector{Expression}, @nospecialize(target::EvalTarget))::Expression
  local result::Expression
  local x::Expression
  local y::Expression
  @match [x, y] = args
  result = begin
    @match (x, y) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        if y.value == 0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.MODULO_BY_ZERO,
              list(string(x.value), string(y.value)),
              EvalTarget_getInfo(target),
            )
          end
          return EVAL_FAILED
        end
        INTEGER_EXPRESSION(mod(x.value, y.value))
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        if y.value == 0.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.MODULO_BY_ZERO,
              list(string(x.value), string(y.value)),
              EvalTarget_getInfo(target),
            )
          end
          return EVAL_FAILED
        end
        REAL_EXPRESSION(mod(x.value, y.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinOnes(args::Union{List{Expression}, Vector{Expression}})::Expression
  local result::Expression
  result = evalBuiltinFill2(INTEGER_EXPRESSION(1), args)
  return result
end

function evalBuiltinProduct(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      ARRAY_EXPRESSION(__) => begin
        begin
          @match arrayElementType(typeOf(arg)) begin
            TYPE_INTEGER(__) where allArrayElementsAre(arg, INTEGER_EXPRESSION) => begin
              INTEGER_EXPRESSION(foldArrayElements(arg, evalBuiltinProductInt, 1, Int))
            end

            TYPE_REAL(__) where allArrayElementsAre(arg, REAL_EXPRESSION) => begin
              REAL_EXPRESSION(foldArrayElements(arg, evalBuiltinProductReal, 1.0, Float64))
            end

            _ => begin
              printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
              return EVAL_FAILED
            end
          end
        end
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

"""Product fold over an array whose elements were checked to be integers (allArrayElementsAre)."""
evalBuiltinProductInt(@nospecialize(exp::Expression), result::Int)::Int = result * _intOf(exp)

"""Product fold over an array whose elements were checked to be reals (allArrayElementsAre)."""
evalBuiltinProductReal(@nospecialize(exp::Expression), result::Float64)::Float64 = result * _realOf(exp)

function evalBuiltinPromote(@nospecialize(arg::Expression), @nospecialize(argN::Expression))::Expression
  local result::Expression
  local n::Int
  if argN isa INTEGER_EXPRESSION
    (result, _) = promote(arg, typeOf(arg), _intOf(argN))
  else
    printWrongArgsError(getInstanceName(), list(arg, argN), sourceInfo())
    return EVAL_FAILED
  end
  return result
end

function evalBuiltinRem(args::Union{List{Expression}, Vector{Expression}}, @nospecialize(target::EvalTarget))::Expression
  local result::Expression

  local x::Expression
  local y::Expression

  x = args[1]
  y = args[2]
   result = begin
    @match (x, y) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        if y.value == 0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.REM_ARG_ZERO,
              list(string(x.value), string(y.value)),
              EvalTarget_getInfo(target),
            )
          end
          return EVAL_FAILED
        end
        INTEGER_EXPRESSION(x.value - div(x.value, y.value) * y.value)
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        if y.value == 0.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.REM_ARG_ZERO,
              list(string(x.value), string(y.value)),
              EvalTarget_getInfo(target),
            )
          end
          return EVAL_FAILED
        end
        REAL_EXPRESSION(x.value - div(x.value, y.value) * y.value)
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinScalar(args::Union{List{Expression}, Vector{Expression}})::Expression
  local result::Expression
  local exp::Expression = Base.first(args)
  result = begin
    @match exp begin
      ARRAY_EXPRESSION(__) => begin
        evalBuiltinScalar(exp.elements)
      end

      _ => begin
        exp
      end
    end
  end
  return result
end

function evalBuiltinSign(@nospecialize(arg::Expression))::Expression
  local result::Expression
  result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        INTEGER_EXPRESSION(if _realOf(arg) > 0
          1
        else
          if _realOf(arg) < 0
            -1
          else
            0
          end
        end)
      end

      INTEGER_EXPRESSION(__) => begin
        INTEGER_EXPRESSION(if _intOf(arg) > 0
          1
        else
          if _intOf(arg) < 0
            -1
          else
            0
          end
        end)
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinSinh(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(sinh(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinSin(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(roundingZero(sin(_realOf(arg)), _realOf(arg)))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinSkew(@nospecialize(arg::Expression))::Expression
  local result::Expression

  local x1::Expression
  local x2::Expression
  local x3::Expression
  local y1::Expression
  local y2::Expression
  local y3::Expression
  local ty::ModelicaType
  local zero::Expression
  local literal::Bool

   result = begin
    @match arg begin
      ARRAY_EXPRESSION(
        ty = ty,
        literal = literal,
      ) where {length(arg.elements) == 3} => begin
         x1, x2, x3 = arg.elements[1], arg.elements[2], arg.elements[3]
         zero = makeZero(arrayElementType(ty))
         y1 = makeArray(
          ty,
          Expression[zero, negate(x3), x2],
          literal,
        )
         y2 = makeArray(
          ty,
          Expression[x3, zero, negate(x1)],
          literal,
        )
         y3 = makeArray(
          ty,
          Expression[negate(x2), x1, zero],
          literal,
        )
         ty = liftArrayLeft(ty, fromInteger(3))
        makeArray(ty, Expression[y1, y2, y3]; literal=literal)
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinSqrt(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(sqrt(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinString(args::Union{List{Expression}, Vector{Expression}})::Expression
  local result::Expression
  local arg::Expression
  local min_len::Int
  local str_len::Int
  local significant_digits::Int
  local left_justified::Bool
  local str::String
  local format::String
  local r::AbstractFloat
  local nArgs::Int = length(args)

  if nArgs == 3 && args[2] isa INTEGER_EXPRESSION && args[3] isa BOOLEAN_EXPRESSION
    #= String(value, minimumLength, leftJustified) for Integer/Boolean/Enum =#
    arg = args[1]
    min_len = args[2].value
    left_justified = args[3].value
    str = begin
      @match arg begin
        INTEGER_EXPRESSION(__) => intString(arg.value)
        BOOLEAN_EXPRESSION(__) => boolString(arg.value)
        ENUM_LITERAL_EXPRESSION(__) => arg.name
        _ => begin
          printWrongArgsError(getInstanceName(), args, sourceInfo())
          return EVAL_FAILED
        end
      end
    end
    str_len = stringLength(str)
    if str_len < min_len
      if left_justified
        str = str + stringAppendList(ListUtil.fill(" ", min_len - str_len, String))
      else
        str = stringAppendList(ListUtil.fill(" ", min_len - str_len, String)) + str
      end
    end
    result = STRING_EXPRESSION(str)
  elseif nArgs == 4 && args[1] isa REAL_EXPRESSION && args[2] isa INTEGER_EXPRESSION && args[3] isa INTEGER_EXPRESSION && args[4] isa BOOLEAN_EXPRESSION
    #= String(real, significantDigits, minimumLength, leftJustified) =#
    r = args[1].value
    significant_digits = args[2].value
    min_len = args[3].value
    left_justified = args[4].value
    format = "%" + (if left_justified; "-"; else; ""; end) + intString(min_len) + "." + intString(significant_digits) + "g"
    str = System.sprintff(format, r)
    result = STRING_EXPRESSION(str)
  elseif nArgs == 2 && args[1] isa REAL_EXPRESSION && args[2] isa STRING_EXPRESSION
    #= String(real, format): C's printf with "%" + format, as OpenModelica
       (flags, width, precision, then f, e, E, g or G: another conversion of a
       double is not defined). =#
    r = args[1].value
    format = args[2].value
    if !occursin(r"^[#0 +-]*[0-9]*(\.[0-9]*)?[feEgG]$", format)
      printWrongArgsError(getInstanceName(), args, sourceInfo())
      return EVAL_FAILED
    end
    str = System.sprintff("%" + format, r)
    result = STRING_EXPRESSION(str)
  else
    printWrongArgsError(getInstanceName(), args, sourceInfo())
    return EVAL_FAILED
  end
  return result
end

function evalBuiltinSum(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      ARRAY_EXPRESSION(__) => begin
        begin
          @match arrayElementType(typeOf(arg)) begin
            TYPE_INTEGER(__) where allArrayElementsAre(arg, INTEGER_EXPRESSION) => begin
              INTEGER_EXPRESSION(foldArrayElements(arg, evalBuiltinSumInt, 0, Int))
            end

            TYPE_REAL(__) where allArrayElementsAre(arg, REAL_EXPRESSION) => begin
              REAL_EXPRESSION(foldArrayElements(arg, evalBuiltinSumReal, 0.0, Float64))
            end

            _ => begin
              printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
              return EVAL_FAILED
            end
          end
        end
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

"""Sum fold over an array whose elements were checked to be integers (allArrayElementsAre)."""
evalBuiltinSumInt(@nospecialize(exp::Expression), result::Int)::Int = result + _intOf(exp)

"""Sum fold over an array whose elements were checked to be reals (allArrayElementsAre)."""
evalBuiltinSumReal(@nospecialize(exp::Expression), result::Float64)::Float64 = result + _realOf(exp)

function evalBuiltinSymmetric(@nospecialize(arg::Expression))::Expression
  local result::Expression

  local n::Int
  local row_ty::ModelicaType

   result = begin
    @match arg begin
      ARRAY_EXPRESSION(__) where {(isMatrix(arg.ty))} => begin
        local mat = Vector{Vector{Expression}}(undef, length(arg.elements))
        for (k, row) in enumerate(arg.elements)
          mat[k] = arrayElements(row)
        end
         n = length(mat)
         row_ty = unliftArray(arg.ty)
        local rows = Expression[]
        for i in 1:n
          local row_elems = Expression[i > j ? mat[j][i] : mat[i][j] for j in 1:n]
          push!(rows, makeArray(row_ty, row_elems, literal = true))
        end
        makeArray(arg.ty, rows, literal = true)
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinTanh(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(tanh(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinTan(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(roundingZero(tan(_realOf(arg)), _realOf(arg)))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinTranspose(@nospecialize(arg::Expression))::Expression
  local result::Expression
  local dim1::Dimension
  local dim2::Dimension
  local ty::ModelicaType
  local literal::Bool
  result = begin
    @match arg begin
      ARRAY_EXPRESSION(
        ty = TYPE_ARRAY(elementType = ty, dimensions = dim1 <| dim2 <| _),
        literal = literal,
      ) => begin
        local mat = [arrayElements(e) for e in arg.elements]
        local nrows = length(mat)
        local ncols = nrows > 0 ? length(mat[1]) : 0
        local transposed = [Expression[mat[i][j] for i in 1:nrows] for j in 1:ncols]
        ty = liftArrayLeft(ty, dim1)
        local new_rows = Expression[makeArray(ty, col, literal = literal) for col in transposed]
        ty = liftArrayLeft(ty, dim2)
        makeArray(ty, new_rows, literal = literal)
      end
      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinVector(@nospecialize(arg::Expression))::Expression
  local result::Expression

  local expl::List{Expression}
  local ty::ModelicaType

   expl = foldArrayElements(arg, evalBuiltinVector2, nil, List{Expression})
   ty = liftArrayLeft(
    arrayElementType(typeOf(arg)),
    fromInteger(listLength(expl)),
  )
   result = makeArray(ty, listReverse(expl), literal = true)
  return result
end

evalBuiltinVector2(@nospecialize(exp::Expression), expl::List{Expression})::List{Expression} = _cons(exp, expl)

function evalBuiltinZeros(args::Union{List{Expression}, Vector{Expression}})::Expression
  local result::Expression
  result = evalBuiltinFill2(INTEGER_EXPRESSION(0), args)
  return result
end

function evalUriToFilename(
  fn::MODELICA_FUNCTION,
  args::Union{List{Expression}, Vector{<:Expression}},
  @nospecialize(target::EvalTarget),
)::Expression
  local result::Expression

  local e::Expression
  local arg::Expression
  local s::String
  local f::MODELICA_FUNCTION

   arg = args[1]
   result = begin
    @match arg begin
      STRING_EXPRESSION(__) => begin
         s = resolveModelicaUri(arg.value)
         STRING_EXPRESSION(s)
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
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

function evalIntBitAnd(args::List{Expression})::Expression
  local result::Expression

  local i1::Int
  local i2::Int

   result = begin
    @match args begin
      INTEGER_EXPRESSION(value = i1) <|
      INTEGER_EXPRESSION(value = i2) <| nil() => begin
        INTEGER_EXPRESSION(intBitAnd(i1, i2))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalIntBitOr(args::List{Expression})::Expression
  local result::Expression

  local i1::Int
  local i2::Int

   result = begin
    @match args begin
      INTEGER_EXPRESSION(value = i1) <|
      INTEGER_EXPRESSION(value = i2) <| nil() => begin
        INTEGER_EXPRESSION(intBitOr(i1, i2))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalIntBitXor(args::List{Expression})::Expression
  local result::Expression

  local i1::Int
  local i2::Int

   result = begin
    @match args begin
      INTEGER_EXPRESSION(value = i1) <|
      INTEGER_EXPRESSION(value = i2) <| nil() => begin
        INTEGER_EXPRESSION(intBitXor(i1, i2))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalIntBitLShift(args::List{Expression})::Expression
  local result::Expression

  local i1::Int
  local i2::Int

   result = begin
    @match args begin
      INTEGER_EXPRESSION(value = i1) <|
      INTEGER_EXPRESSION(value = i2) <| nil() => begin
        INTEGER_EXPRESSION(intBitLShift(i1, i2))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalIntBitRShift(args::List{Expression})::Expression
  local result::Expression

  local i1::Int
  local i2::Int

   result = begin
    @match args begin
      INTEGER_EXPRESSION(value = i1) <|
      INTEGER_EXPRESSION(value = i2) <| nil() => begin
        INTEGER_EXPRESSION(intBitRShift(i1, i2))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalInferredClock(args::List{Expression})::Expression
  local result::Expression

   result = begin
    @match args begin
      nil() => begin
        CLKCONST_EXPRESSION(INFERRED_CLOCK())
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalRationalClock(args::List{Expression})::Expression
  local result::Expression

   result = begin
    local interval::Expression
    local resolution::Expression
    @match args begin
      interval &&
      INTEGER_EXPRESSION(__) <| resolution &&
      INTEGER_EXPRESSION(__) <| nil() => begin
        CLKCONST_EXPRESSION(INTEGER_CLOCK(
          interval,
          resolution,
        ))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalRealClock(args::List{Expression})::Expression
  local result::Expression

   result = begin
    local interval::Expression
    @match args begin
      (interval && REAL_EXPRESSION(__)) <| nil() => begin
        CLKCONST_EXPRESSION(REAL_CLOCK(
          interval,
        ))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBooleanClock(args::List{Expression})::Expression
  local result::Expression

   result = begin
    local condition::Expression
    local interval::Expression
    @match args begin
      condition &&
      BOOLEAN_EXPRESSION(__) <| interval &&
      REAL_EXPRESSION(__) <| nil() => begin
        CLKCONST_EXPRESSION(BOOLEAN_CLOCK(
          condition,
          interval,
        ))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalSolverClock(args::List{Expression})::Expression
  local result::Expression

   result = begin
    local c::Expression
    local solver::Expression
    @match args begin
      c &&
      CLKCONST_EXPRESSION(__) <| solver &&
      STRING_EXPRESSION(__) <| nil() => begin
        CLKCONST_EXPRESSION(SOLVER_CLOCK(
          c,
          solver,
        ))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        return EVAL_FAILED
      end
    end
  end
  return result
end

function evalBuiltinDynamicSelect(
  fn::MODELICA_FUNCTION,
  args::List{Expression},
  @nospecialize(target::EvalTarget),
)::Expression
  local result::Expression
  local s::Expression
  local d::Expression
  @match list(s, d) = list(unbox(arg) for arg in args)
  result = _evalValue(s, target)
  return result
end

function evalArrayConstructor(
  @nospecialize(exp::Expression),
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Expression
  local result::Expression
  (result, ) = evalExpPartial(exp)
  result isa EVAL_FAILURE && return result
  result = _bindingExpMapEval(
    result,
    (expArg) -> evalArrayConstructor2(expArg, iterators),
  )
  return result
end

function evalArrayConstructor2(
  @nospecialize(exp::Expression),
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Expression
  local result::Expression

  local e::Expression
  local ranges::List{Expression}
  local iters::List{Pointer{Expression}}
  local types::List{ModelicaType} = nil
  local ty::ModelicaType

   (e, ranges, iters) = createIterationRanges(exp, iterators)
   result = evalArrayConstructor3(e, ranges, iters)
  return result
end

function createIterationRanges(
  @nospecialize(exp::Expression),
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Tuple{Expression, List{Expression}, List{Pointer{Expression}}}
  local iters::List{Pointer{Expression}} = nil
  local ranges::List{Expression} = nil

  local node::InstNode
  local range::Expression
  local iter::Pointer{Expression}

  #= The iterator is also replaced in the ranges collected so far, which may use it (`j in 1:i,
     i in 1:4`); the ranges are evaluated when their loop starts (omc createIterationRanges). =#
  for i in iterators
     (node, range) = i
     iter = P_Pointer.create(INTEGER_EXPRESSION(0), Expression)
     ranges = list(replaceIterator(r, node, MUTABLE_EXPRESSION(iter)) for r in ranges)
     exp = replaceIterator(
      exp,
      node,
      MUTABLE_EXPRESSION(iter),
    )
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
  local range::Expression
  local ranges_rest::List{Expression}
  local expV::Vector{Expression} = Expression[]
  local iter::Pointer{Expression}
  local iters_rest::List{Pointer{Expression}}
  local range_iter::ExpressionIterator
  local value::Expression
  local ty::ModelicaType
  if listEmpty(ranges)
    return evalExp_impl(exp, EVALTARGET_IGNORE_ERRORS())
  end
  @match _cons(range, ranges_rest) = ranges
  @match _cons(iter, iters_rest) = iterators
  local range_exp::Expression = evalExp_impl(range, EVALTARGET_IGNORE_ERRORS())
  range_exp isa EVAL_FAILURE && return range_exp
  range_iter = fromExpToExpressionIterator(range_exp)
  while hasNext(range_iter)
    (range_iter, value) = next(range_iter)
    P_Pointer.update(iter, value)
    local element::Expression = evalArrayConstructor3(exp, ranges_rest, iters_rest)
    element isa EVAL_FAILURE && return element
    push!(expV, element)
  end
  ty = if isempty(expV)
    liftArrayLeftList(typeOf(exp), ListUtil.mapFlat(ranges_rest, r -> arrayDims(typeOf(r)), Dimension))
  else
    typeOf(expV[1])
  end
  ty = liftArrayLeft(ty, fromInteger(length(expV)))
  return makeArray(ty, expV, literal = true)
end

function evalReduction(
  fn::MODELICA_FUNCTION,
  @nospecialize(exp::Expression),
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Expression
  local result::Expression

  #= evalExpPartial returns (exp, evaluated); evalReduction2 with fn and iterators fixed
     (a partial application in the Modelica original). =#
  (result, _) = evalExpPartial(exp)
  result isa EVAL_FAILURE && return result
  result = _bindingExpMapEval(result, (e) -> evalReduction2(fn, e, iterators))
  return result
end

function evalReduction2(
  fn::MODELICA_FUNCTION,
  @nospecialize(exp::Expression),
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Expression
  local result::Expression

  local e::Expression
  local default_exp::Expression
  local ranges::List{Expression}
  local iters::List{Pointer{Expression}}
  local red_fn::Function
  local ty::ModelicaType

   #= The type before the iterators are replaced by their (Integer-initialized) values. =#
   ty = typeOf(exp)
   (e, ranges, iters) = createIterationRanges(exp, iterators)
   (red_fn, default_exp) = begin
    @match AbsynUtil.pathString(name(fn)) begin
      "sum" => begin
        (evalBinaryAdd, makeZero(ty))
      end

      "product" => begin
        (evalBinaryMul, makeOne(ty))
      end

      "min" => begin
        (evalBuiltinMin2, makeMaxValue(ty))
      end

      "max" => begin
        (evalBuiltinMax2, makeMinValue(ty))
      end

      _ => begin
        Error.addInternalError(
          getInstanceName() + " got unknown reduction function " + AbsynUtil.pathString(name(fn)),
          sourceInfo(),
        )
        return EVAL_FAILED
      end
    end
  end
   result = evalReduction3(e, ranges, iters, default_exp, red_fn)
  return result
end

function evalReduction3(
  @nospecialize(exp::Expression),
  ranges::List{Expression},
  iterators::List{<:Pointer{Expression}},
  @nospecialize(foldExp::Expression),
  fn::Function,
)::Expression
  local result::Expression

  local range::Expression
  local ranges_rest::List{Expression}
  local expl::List{Expression} = nil
  local iter::Pointer{Expression}
  local iters_rest::List{Pointer{Expression}}
  local range_iter::ExpressionIterator
  local value::Expression
  local el_ty::ModelicaType

  if listEmpty(ranges)
    local e::Expression = evalExp_impl(exp, EVALTARGET_IGNORE_ERRORS())
    e isa EVAL_FAILURE && return e
    result = fn(foldExp, e)
  else
    @match _cons(range, ranges_rest) = ranges
    @match _cons(iter, iters_rest) = iterators
    local range_exp::Expression = evalExp_impl(range, EVALTARGET_IGNORE_ERRORS())
    range_exp isa EVAL_FAILURE && return range_exp
    range_iter = fromExpToExpressionIterator(range_exp)
    result = foldExp
    while hasNext(range_iter)
      (range_iter, value) = next(range_iter)
      P_Pointer.update(iter, value)
      result = evalReduction3(exp, ranges_rest, iters_rest, result, fn)
      result isa EVAL_FAILURE && return result
    end
  end
  return result
end

function evalSize(
  @nospecialize(exp::Expression),
  optIndex::Option{Expression},
  @nospecialize(target::EvalTarget),
  )::Expression
  local outExp::Expression
  local index_exp::Expression
  local index::Int
  local ty_err::TypingError
  local dim::Dimension
  local ty::ModelicaType
  local expl::List{Expression}
  local info::SourceInfo
  info = EvalTarget_getInfo(target)
  if isSome(optIndex)
    #= The index, the index'd dimension of the expression, its size expression evaluated. =#
    index_exp = evalExp_impl(Util.getOption(optIndex), target)
    (index_exp isa INTEGER_EXPRESSION || index_exp isa BOOLEAN_EXPRESSION || index_exp isa ENUM_LITERAL_EXPRESSION) ||
      return EVAL_FAILED
    index = toInteger(index_exp)
    (dim, _, ty_err) = typeExpDim(exp, index, ORIGIN_CLASS, info)
    checkSizeTypingError(ty_err, exp, index, info) || return EVAL_FAILED
    hasSizeExp(dim) || return EVAL_FAILED
    outExp = evalExp_impl(sizeExp(dim), target)
  else
    (outExp, ty) = typeExp(exp, ORIGIN_CLASS, info)
    expl = nil
    for d in arrayDims(ty)
      hasSizeExp(d) || return EVAL_FAILED
      local e::Expression = evalExp_impl(sizeExp(d), target)
      e isa EVAL_FAILURE && return e
      expl = Cons{Expression}(e, expl)
    end
    expl = listReverse(expl)
    dim = fromInteger(listLength(expl), Variability.PARAMETER)
    outExp =
      makeArray(TYPE_ARRAY(TYPE_INTEGER(), list(dim)), expl)
  end
  return outExp
end

function evalSubscriptedExp(
  @nospecialize(exp::Expression),
  subscripts::List{<:Subscript},
  @nospecialize(target::EvalTarget),
)::Expression
  local result::Expression

  local subs::List{Subscript}

   result = begin
    @match exp begin
      RANGE_EXPRESSION(__) => begin
        local start::Expression = _evalValue(exp.start, target)
        start isa EVAL_FAILURE && return start
        local step::Option{Expression} = evalExpOpt(exp.step, target)
        _failedOpt(step) && return EVAL_FAILED
        local stop::Expression = _evalValue(exp.stop, target)
        stop isa EVAL_FAILURE && return stop
        RANGE_EXPRESSION(exp.ty, start, step, stop)
      end

      _ => begin
        evalExp_impl(exp, target)
      end
    end
  end
  result isa EVAL_FAILURE && return result
  subs = nil
  for s in subscripts
    local (ok::Bool, sub::Subscript) = evalSubscriptWithTarget(s, target)
    ok || return EVAL_FAILED
    subs = Cons{Subscript}(sub, subs)
  end
  subs = listReverse(subs)
  result = applySubscripts(subs, result)
  return result
end

"""
A subscript with its expression evaluated, as `mapShallowExp(subscript, x -> evalExp_impl(x, target))` without the
closure: the closure over the abstract `target` was a heap object per subscripted expression (HeatingSystem: 33k).
`(true, subscript)`, or `(false, subscript)` when its expression does not evaluate.
"""
function evalSubscriptWithTarget(subscript::Subscript, @nospecialize(target::EvalTarget))::Tuple{Bool, Subscript}
  local e1::Expression
  local e2::Expression
  return @match subscript begin
    SUBSCRIPT_UNTYPED(exp = e1) => begin
      e2 = evalExp_impl(e1, target)
      e2 isa EVAL_FAILURE && return (false, subscript)
      (true, referenceEq(e1, e2) ? subscript : SUBSCRIPT_UNTYPED(e2))
    end
    SUBSCRIPT_INDEX(index = e1) => begin
      e2 = evalExp_impl(e1, target)
      e2 isa EVAL_FAILURE && return (false, subscript)
      (true, referenceEq(e1, e2) ? subscript : fromTypedExp(e2))
    end
    SUBSCRIPT_SLICE(slice = e1) => begin
      e2 = evalExp_impl(e1, target)
      e2 isa EVAL_FAILURE && return (false, subscript)
      (true, referenceEq(e1, e2) ? subscript : fromTypedExp(e2))
    end
    _ => (true, subscript)
  end
end

function evalRecordElement(exp::RECORD_ELEMENT_EXPRESSION, @nospecialize(target::EvalTarget))::Expression
  local result::Expression
  local e::Expression = evalExp_impl(exp.recordExp, target)
  e isa EVAL_FAILURE && return e
  local index::Int = exp.index
  result = _bindingExpMapEval(e, @closure (x) -> _recordElementOf(x, index, exp.ty, exp.fieldName))
  if result isa EVAL_FAILURE
    Error.addSourceMessage(Error.INTERNAL_ERROR, list(getInstanceName() + " could not evaluate " + toString(exp)), sourceInfo())
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
    local (ok::Bool, elements::Vector{Expression}) = _mapChecked(el::Expression -> _recordElementOf(el, index, ety, fieldName), x.elements)
    ok || return EVAL_FAILED
    return ARRAY_EXPRESSION(ty, elements, x.literal)
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
  return begin
    @match target begin
      EVALTARGET_IGNORE_ERRORS(__) => begin
        false
      end

      EVALTARGET_DIMENSION(__) => begin
        Error.addSourceMessage(
          Error.STRUCTURAL_PARAMETER_OR_CONSTANT_WITH_NO_BINDING,
          list(toString(exp), name(target.component)),
          target.info,
        )
        true
      end

      EVALTARGET_CONDITION(__) => begin
        Error.addSourceMessage(
          Error.CONDITIONAL_EXP_WITHOUT_VALUE,
          list(toString(exp)),
          target.info,
        )
        true
      end

      _ => begin
        #=  check if we have a parameter with (fixed = true), annotation(Evaluate = true) and no binding
        =#
        if listMember(
          variability(component),
          list(Variability.STRUCTURAL_PARAMETER, Variability.PARAMETER),
        ) && getEvaluateAnnotation(component)
          if getFixedAttribute(component)
            Error.addMultiSourceMessage(
              Error.UNBOUND_PARAMETER_EVALUATE_TRUE,
              list(toString(exp) + "(fixed = true)"),
              list(
                InstNode_info(node(toCref(
                  exp,
                ))),
                EvalTarget_getInfo(target),
              ),
            )
          end
        else
          Error.addMultiSourceMessage(
            Error.UNBOUND_CONSTANT,
            list(toString(exp)),
            list(
              InstNode_info(node(toCref(
                exp,
              ))),
              EvalTarget_getInfo(target),
            ),
          )
          return true
        end
        #=  only add an error if fixed = true
        =#
        #=  constant with no binding
        =#
        false
      end
    end
  end
end

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
    all(x::Expression -> x isa ARRAY_EXPRESSION, level) || break
    local n::Int = length((level[1]::ARRAY_EXPRESSION).elements)
    all(x::Expression -> length((x::ARRAY_EXPRESSION).elements) == n, level) || return false
    level = Expression[y for x in level for y in (x::ARRAY_EXPRESSION).elements]
  end
  return true
end

#= An argument of cat along dim (regular: _catPartRegular): its subexpressions at depth dim as an
   array of dim dimensions; one of fewer dimensions gets trailing ones (Modelica's promote, a
   vector a column). =#
function _catPart(@nospecialize(e::Expression), dim::Int)::Array{Expression}
  local sizes = Int[]
  local level = Expression[e]
  for _ in 1:dim
    all(x -> x isa ARRAY_EXPRESSION, level) || break
    local n::Int = length((level[1]::ARRAY_EXPRESSION).elements)
    push!(sizes, n)
    level = Expression[y for x in level for y in (x::ARRAY_EXPRESSION).elements]
  end
  while length(sizes) < dim
    push!(sizes, 1)
  end
  #= level is in row-major order of sizes =#
  return _catPartArray(level, sizes, Val(dim))::Array{Expression}
end

"""
    _catPartArray(level, sizes, Val(N)) -> Array{Expression, N}

`level` (row-major in `sizes`) as an array of rank N in column-major order (`_catPart`). The rank as a type parameter:
`reshape` and `permutedims` with a tuple of unknown length were dynamic calls (invalidated by packages' methods).
"""
function _catPartArray(level::Vector{Expression}, sizes::Vector{Int}, ::Val{N})::Array{Expression, N} where {N}
  local dims::NTuple{N, Int} = ntuple(k::Int -> sizes[N + 1 - k], Val(N))
  return Base.permutedims(Base.reshape(level, dims), ntuple(k::Int -> N + 1 - k, Val(N)))
end

"""
  Custom reimplementation of evalCat
  @author johti17
"""
function evalCat(dim::Int,
                 exps::Vector{Expression},
                 getArrayContents::Function,
                 toString::Function)::Tuple{Vector{Expression}, List{Int}}
  if dim > 1
    #= omc's ExpressionBasics.evalCat: each argument as an array of its subexpressions at depth
       dim, concatenated along dim; the result in row-major order with its first dim sizes. The
       former version took the arguments' rows as one matrix (wrong beyond two matrices of rows)
       and failed on a vector argument ([identity(n - 1), zeros(n - 1)], Polynomials.roots). =#
    local parts = Array{Expression}[_catPart(e, dim) for e in exps]
    local c = Base.cat(parts...; dims = dim)
    local outExpFlat = Vector{Expression}(Base.vec(Base.permutedims(c, Tuple(dim:-1:1))))
    local outDims = list(Base.size(c)...)
  else
    local outExpsAsVector = Base.map(x-> x.elements, exps)
    local outExpFlat = Expression[]
    for vec in outExpsAsVector
      for arr in vec
        push!(outExpFlat, arr)
      end
    end
    local outDims = list(length(outExpFlat))
  end
  return (outExpFlat, outDims)
end

"""
Custom reimplementation of evalCatGetFlatArray
@author johti17
"""
function evalCatGetFlatArray(@nospecialize(e::Expression), dim::Int, getArrayContents::Function, toString::Function)::Tuple{List{Expression}, List{Int}}
  local arr::List
  local dims::List
  local i::Int
  #= output =#
  local outDims::List{Int} = nil
  local outExps::List{Expression} = nil
  if dim == 1
    local contents = getArrayContents(e)
    outExps = arrayList(contents)
    outDims = list(length(contents))
    return (outExps, outDims)
  end
  i = 0
  for exp in reverse(getArrayContents(e))
    (arr, dims) = evalCatGetFlatArray(exp, dim - 1, getArrayContents::Function, toString::Function)
    if listEmpty(outDims)
      outDims = dims
    elseif !(valueEq(dims, outDims))
      @error "Got unbalanced array from" * toString(e)
    else
      continue
    end
    outExps = listAppend(arr, outExps)
    i += 1
  end
  outDims = i <| outDims
  return(outExps, outDims)
end

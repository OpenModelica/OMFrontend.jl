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
function EvalTarget_getInfo(target::EvalTarget)::SourceInfo
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
        DAE.ElementSource_getInfo(target.source)
      end

      _ => begin
        AbsynUtil.dummyInfo
      end
    end
  end
  return info
end

function hasInfo(target::EvalTarget)::Bool
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

function isRange(target::EvalTarget)::Bool
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
    source::DAE.ElementSource
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
 Attempts to evaluate an expression.
 Continues if it fails
"""
@nospecializeinfer function tryEvalExp(@nospecialize(exp::Expression))
  local outExp = exp
  try
    outExp = evalExp(exp)
  catch
  end
  return outExp
end


"""
  Evaluates an expression.
"""
@nospecializeinfer function evalExp(
  @nospecialize(exp::Expression),
  target::EvalTarget = EVALTARGET_IGNORE_ERRORS(),
  )::Expression
  exp = evalExp_impl(exp, target)
  #println("evalExp_impl:" * toString(exp))
  exp = getBindingExp(exp)
  #println("getBindingExp" * toString(exp))
  return exp
end

@nospecializeinfer function evalExp_impl(@nospecialize(exp::Expression), target::EvalTarget)::Expression
  exp = begin
    local c::InstNode
    local binding::Binding
    local exp1::Expression
    local exp2::Expression
    local exp3::Expression
    local expl::List{Expression} = nil
    local call::Call
    local comp::Component
    local oexp::Option{Expression}
    local cref::ComponentRef
    local dim::Dimension
    @match exp begin
      CREF_EXPRESSION(__) => begin
        evalCref(exp.cref, exp, target)
      end
      TYPENAME_EXPRESSION(__) => begin
        evalTypename(exp.ty, exp, target)
      end
      ARRAY_EXPRESSION(__) => begin
        if exp.literal
          exp
        else
          makeArray(
            exp.ty,
            Expression[evalExp_impl(e, target) for e in exp.elements],
            literal = true,
          )
        end
      end
      RANGE_EXPRESSION(__) => begin
        evalRange(exp, target)
      end
      TUPLE_EXPRESSION(__) => begin
         exp.elements = list(evalExp_impl(e, target) for e in exp.elements)
        exp
      end
      RECORD_EXPRESSION(__) => begin
        #= In place handling...  =#
        for (i, e) in enumerate(exp.elements)
          exp.elements[i] = e
        end
        exp
      end
      CALL_EXPRESSION(__) => begin
        evalCall(exp.call, target)
      end
      SIZE_EXPRESSION(__) => begin
        evalSize(exp.exp, exp.dimIndex, target)
      end
      BINARY_EXPRESSION(__) => begin
         exp1 = evalExp_impl(exp.exp1, target)
         exp2 = evalExp_impl(exp.exp2, target)
        evalBinaryOp(exp1, exp.operator, exp2, target)
      end
      UNARY_EXPRESSION(__) => begin
         exp1 = evalExp_impl(exp.exp, target)
        evalUnaryOp(exp1, exp.operator)
      end
      LBINARY_EXPRESSION(__) => begin
         exp1 = evalExp_impl(exp.exp1, target)
        evalLogicBinaryOp(exp1, exp.operator, exp.exp2, target)
      end
      LUNARY_EXPRESSION(__) => begin
         exp1 = evalExp_impl(exp.exp, target)
        evalLogicUnaryOp(exp1, exp.operator)
      end
      RELATION_EXPRESSION(__) => begin
         exp1 = evalExp_impl(exp.exp1, target)
         exp2 = evalExp_impl(exp.exp2, target)
        evalRelationOp(exp1, exp.operator, exp2)
      end
      IF_EXPRESSION(__) => begin
        evalIfExp(exp, target)
      end

      CAST_EXPRESSION(__) => begin
         exp1 = evalExp_impl(exp.exp, target)
        evalCast(exp1, exp.ty)
      end

      UNBOX_EXPRESSION(__) => begin
         exp1 = evalExp_impl(exp.exp, target)
        UNBOX_EXPRESSION(exp1, exp.ty)
      end

      SUBSCRIPTED_EXP_EXPRESSION(__) => begin
        evalSubscriptedExp(exp.exp, exp.subscripts, target)
      end

      TUPLE_ELEMENT_EXPRESSION(__) => begin
         exp1 = evalExp_impl(exp.tupleExp, target)
        tupleElement(exp1, exp.ty, exp.index)
      end

      RECORD_ELEMENT_EXPRESSION(__) => begin
        evalRecordElement(exp, target)
      end

      MUTABLE_EXPRESSION(__) => begin
         exp1 = evalExp_impl(P_Pointer.access(exp.exp), target)
        exp1
      end

      BINDING_EXP(__) => begin
        @assign exp.exp = evalExp_impl(exp.exp, target)
        exp
      end

      _ => begin
        exp
      end
    end
  end
  return exp
end

function evalExpOpt(
  oexp::Option{Expression},
  target::EvalTarget = EVALTARGET_IGNORE_ERRORS(),
)::Option{Expression}

   oexp = begin
    local e::Expression
    @match oexp begin
      SOME(e) => begin
        SOME(evalExp_impl(e, target))
      end

      _ => begin
        oexp
      end
    end
  end
  return oexp
end

"""
   Evaluates the parts of an expression that are possible to evaluate. This
   means leaving parts of the expression that contains e.g. iterators or mutable
   expressions. This can be used to optimize an expression that is expected to
   be evaluated many times, for example the expression in an array constructor.
"""
function evalExpPartial(
  exp::Expression,
  target::EvalTarget = EVALTARGET_IGNORE_ERRORS(),
  evaluated::Bool = true,
  )::Tuple{Expression, Bool}
  local outEvaluated::Bool #= True if the whole expression is evaluated, otherwise false. =#
  local outExp::Expression
  local e::Expression
  local e1::Expression
  local e2::Expression
  local eval1::Bool
  local eval2::Bool
  local outEvaluatedRef::Ref{Bool} = Ref{Bool}(true)
  local f = @closure (expArg, boolArg) -> begin
    result = evalExpPartialRef(expArg, outEvaluatedRef, target)
    (result, boolArg && outEvaluatedRef.x)
  end
  e = mapFoldShallowRef(
    exp,
    f,
    true,
    outEvaluatedRef
  )
  outEvaluated = outEvaluatedRef.x
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
          evalExp(e, target)
        else
          e
        end
      end
    end
  end
   outEvaluated = evaluated && outEvaluated
  return (outExp, outEvaluated) #= True if the whole expression is evaluated, otherwise false. =#
end


function evalExpPartialRef(
  exp::Expression,
  outEvaluatedRef::Ref{Bool},
  target::EvalTarget = EVALTARGET_IGNORE_ERRORS())::Expression
  local outEvaluated::Bool #= True if the whole expression is evaluated, otherwise false. =#
  local outExp::Expression
  local e::Expression
  local e1::Expression
  local e2::Expression
  local eval1::Bool
  local eval2::Bool
  local f = @closure (expArg, z) -> begin
    result = evalExpPartialRef(expArg, outEvaluatedRef, target)
    (result, z && outEvaluatedRef.x)
  end
  e = mapFoldShallowRef(exp, f, true, outEvaluatedRef)
  outEvaluated = outEvaluatedRef.x
  local evaluated = true
  outExp = begin
    @match e begin
      CREF_EXPRESSION(__) => begin
        if isIterator(e.cref)
          outExp = e
          outEvaluated = false
        else
          outExp = evalCref(e.cref, e, target, evalSubscripts = false)
          #=  If evalCref could not resolve the cref (returned the original),
              mark as not fully evaluated. =#
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
        outEvaluated = false
        e
      end

      _ => begin
        if outEvaluated
          evalExp(e, target)
        else
          e
        end
      end
    end
  end
  outEvaluated = evaluated && outEvaluated
  outEvaluatedRef.x = outEvaluated
  return outExp
end

function evalCref(@nospecialize(cref::ComponentRef),
                  defaultExp::Expression,
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
  defaultExp::Expression,
  target::EvalTarget,
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
  typeComponentBinding(node, exp_origin, false)
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
          #= Try to evaluate the binding =#
          try
            exp = evalExp_impl(binding.bindingExp, target)
          catch e
            @assign binding.evaluated = false
            @debug "evalComponentBinding: failed to evaluate binding" toString(binding.bindingExp) toString(cref)
            if target isa EVALTARGET_IGNORE_ERRORS
              return defaultExp
            end
            throw(e)
          end
          #= Update the binding and set is as evaluated =#
          @assign binding.bindingExp = exp
          @assign binding.evaluated = true
          comp = setBinding(binding, comp)
          updateComponent!(comp, node)
        end
        (exp, true)
      end

      CEVAL_BINDING(__) => begin
        (binding.bindingExp, true)
      end

      UNBOUND(__) => begin
        printUnboundError(comp, target, defaultExp)
        (defaultExp, false)
      end

      _ => begin
        Error.addInternalError(getInstanceName() + " failed on untyped binding", sourceInfo())
        fail()
      end
    end
  end
  #=  Apply subscripts from the cref to the binding expression as needed.
  =#
  if evaluated
     exp = subscriptEvaluatedBinding(exp, cref, evalSubscripts)
  end
  return exp
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
  exp::Expression,
  cref::ComponentRef,
  evalSubscripts::Bool,
)::Expression

  local subs::List{Subscript}
  local cr::ComponentRef

  #=  The subscripts of the first part of the cref are always applied. =#
  subs = getSubscripts(cref)
  (cr, _) = stripSubscripts(cref)
  if evalSubscripts
    subs = list(evalSubscript(s) for s in subs)
  end
  #=  The rest of the cref contributes subscripts based on where the expressions
  =#
  #=  comes from in the instance tree.
  =#
  exp = subscriptEvaluatedBinding2(exp, cr, evalSubscripts, subs, subs)
  return exp
end

function subscriptEvaluatedBinding2(
  exp::Expression,
  cref::ComponentRef,
  evalSubscripts::Bool,
  subscripts::List{<:Subscript} = nil,
  bindingSubs::List{<:Subscript} = nil,
)::Expression

   exp = begin
    local e::Expression
    local exp_ty::M_Type
    local bind_ty::M_Type
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
            if evalSubscripts
              subs = list(evalSubscript(s) for s in subs)
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
  target::EvalTarget,
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
  #=  Look up \"start\" in the class. =#
  #@info "Checking start in the class"
  try
    @match ENTRY_INFO(start_node, isImport) = lookupElement("start", getClass(node))
  catch e
    @debug "lookupElement(start) not found in class"
    return outExp
  end
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
        exp = evalExp_impl(binding.bindingExp, target)
        if !referenceEq(exp, binding.bindingExp)
          binding.bindingExp = exp
          start_comp = setBinding(binding, start_comp)
          updateComponent!(start_comp, start_node)
        end
        SOME(exp)
      end

      TYPED_BINDING(__) => begin
        exp = evalExp_impl(binding.bindingExp, target)
        if !referenceEq(exp, binding.bindingExp)
          binding.bindingExp = exp
          start_comp = setBinding(binding, start_comp)
          updateComponent!(start_comp, start_node)
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
  target::EvalTarget,
)::Binding
  local binding::Binding
  local tree::ClassTree
  local comps::Vector{InstNode}
  local fields::List{Expression}
  local ty::M_Type
  local exp_ty::M_Type
  local rec_node::InstNode
  local exp::Expression
  local rest_cr::ComponentRef
  binding = begin
    @matchcontinue (component, cref) begin
      (_, _) => begin
        #=  A record field without an explicit binding, evaluate the parent's binding
        =#
        #=  if it has one and fetch the binding from it instead.
        =#
        #try
        exp = makeRecordFieldBindingFromParent(cref, target)
        CEVAL_BINDING(exp)
        #catch e
          #println(e)
          #throw(e)
        #end
      end
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
        exp_ty = typeOf(exp)
        exp =
          BINDING_EXP(exp, exp_ty, exp_ty, list(node), true)
        binding = CEVAL_BINDING(exp)
        if !hasSubscripts(cref)
          updateComponent!(setBinding(binding, component), node)
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
        exp = splitRecordArrayExp(exp)
        exp_ty = typeOf(exp)
        exp =
          BINDING_EXP(exp, exp_ty, exp_ty, list(node), true)
        binding = CEVAL_BINDING(exp)
        if !hasSubscripts(cref)
          updateComponent!(setBinding(binding, component), node)
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
```
  makeRecordFieldBindingFromParent(cref::ComponentRef, target::EvalTarget)
```
  Updated with code from the latest frontend.
"""
function makeRecordFieldBindingFromParent(
  cref::ComponentRef,
  target::EvalTarget,
  )::Expression
  local exp::Expression
  local parent_cr::ComponentRef
  local parent_ty::M_Type
  parent_cr = rest(cref)
  #println("Make record fieldbinding from Parent")
  #println(toString(cref))
  #println(toString(parent_cr))
  parent_ty = nodeType(parent_cr)
  #@match true = isRecord(arrayElementType(parent_ty))
  #= NEW =#
  parent = node(parent_cr)
  typeComponentBinding(parent, ORIGIN_CLASS, #= typeChildren =# false);
  comp = component(parent)
  binding = getBinding(comp)
  subs = getSubscripts(parent_cr)
  if hasExp(binding)
    exp = getExp(binding)
    exp = applySubscripts(subs, exp)
    exp = recordElement(firstName(cref), exp)
    exp = evalExp(exp, target)
    indicesToKeep = nodesIncludingSplitSubs(cref)
    exp = map(exp, (x) -> expandNonListedSplitIndices(x, indicesToKeep))
  else
    #= Try parent instead=#
    exp = makeRecordFieldBindingFromParent(parent_cr, target);
    exp = applySubscripts(subs, exp);
    exp = recordElement(firstName(cref), exp);
  end
  return exp
end

function makeRecordBindingExp(
  typeNode::InstNode,
  recordNode::InstNode,
  recordType::M_Type,
  cref::ComponentRef,
  )
  local exp::Expression
  local tree::ClassTree
  local comps::Vector{InstNode}
  local args::Vector{Expression} = Expression[]
  local fields::List{Field}
  local ty::M_Type
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
    end
    args = push!(args, arg) #Cons{Expression}(arg, args)
  end
   exp = makeRecord(scopePath(recordNode), recordType, args)
  return exp
end

function splitRecordArrayExp(@nospecialize(exp::Expression))::Expression

  local path::Absyn.Path
  local ty::M_Type
  local expl::Vector{Expression}

  @match RECORD_EXPRESSION(path, ty, expl) = exp
   exp = makeRecord(path, arrayElementType(ty), expl)
   exp = fillType(ty, exp)
  return exp
end

function evalTypename(@nospecialize(ty::M_Type), @nospecialize(originExp::Expression), target::EvalTarget)::Expression
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

function evalRange(@nospecialize(rangeExp::Expression), target::EvalTarget)::Expression
  local result::Expression

  local ty::M_Type
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
   start_exp = evalExp(start_exp, target)
   step_exp = evalExpOpt(step_exp, target)
   stop_exp = evalExp(stop_exp, target)
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
     result = bindingExpMap(result, evalRangeExp)
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
  local ty::M_Type
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
           expl = INTEGER_EXPRESSION[INTEGER_EXPRESSION(i) for i = (start.value):istep:(stop.value)]
          (TYPE_INTEGER(), expl)
        end

        (
          REAL_EXPRESSION(__),
          REAL_EXPRESSION(__),
          REAL_EXPRESSION(__),
        ) => begin
           expl = evalRangeReal(start.value, step.value, stop.value)
          (TYPE_REAL(), expl)
        end

        _ => begin
          printWrongArgsError(getInstanceName(), list(start, step, stop), sourceInfo())
          fail()
        end
      end
    end
  else
     (ty, expl) = begin
      @match (start, stop) begin
        (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) =>
          begin
             expl =
               INTEGER_EXPRESSION[INTEGER_EXPRESSION(i) for i = (start.value):(stop.value)]
            (TYPE_INTEGER(), expl)
          end

        (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
           expl = evalRangeReal(start.value, 1.0, stop.value)
          (TYPE_REAL(), expl)
        end

        (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) =>
          begin
             expl =
              INTEGER_EXPRESSION[BOOLEAN_EXPRESSION(b) for b = (start.value):(stop.value)]
            (TYPE_BOOLEAN(), expl)
          end

        (
          ENUM_LITERAL_EXPRESSION(ty = ty && TYPE_ENUMERATION(__)),
          ENUM_LITERAL_EXPRESSION(__),
        ) => begin
          expl =
            ENUM_LITERAL_EXPRESSION[ENUM_LITERAL_EXPRESSION(ty, listGet(ty.literals, i), i) for i = (start.index):(stop.index)]
          (ty, expl)
        end

        _ => begin
          printWrongArgsError(getInstanceName(), list(start, stop), sourceInfo())
          fail()
        end
      end
     end
  end
  exp = makeArray(
    TYPE_ARRAY(ty, list(fromInteger(length(expl)))), expl
    ;literal = true,
  )
  return exp
end

function evalRangeReal(
  start::Float64,
  step::Float64,
  stop::Float64,
)::Vector{REAL_EXPRESSION}
  local result::Vector{Expression}
  local steps::Int
  steps = Util.realRangeSize(start, step, stop)
  #=  Real ranges are tricky, make sure that start and stop are reproduced
  =#
  #=  exactly if they are part of the range.
  =#
  if steps == 0
     result = REAL_EXPRESSION[]
  elseif steps == 1
    result = REAL_EXPRESSION[REAL_EXPRESSION(start)]
  else
     result = REAL_EXPRESSION[REAL_EXPRESSION(stop)]
    for i = (steps - 2):(-1):1
      result = REAL_EXPRESSION[REAL_EXPRESSION(start + i * step), result]
    end
    result = REAL_EXPRESSION[REAL_EXPRESSION(start), result]
  end
  reverse!(result)
  return result
end

function printFailedEvalError(name::String, @nospecialize(exp::Expression), info::SourceInfo)
  return Error.addInternalError(
    name + " failed to evaluate ‘" + toString(exp) + "’",
    info,
  )
end

function evalBinaryOp(
  exp1::Expression,
  op::Operator,
  exp2::Expression,
  target::EvalTarget = EVALTARGET_IGNORE_ERRORS(),
)::Expression
  local exp::Expression

  local max_prop_exp::Expression
  local max_prop_count::Int

   (max_prop_exp, max_prop_count) =
    mostPropagatedSubExpBinary(exp1, exp2)
  if max_prop_count >= 0
     exp = bindingExpMap2(
      BINARY_EXPRESSION(exp1, op, exp2),
      (x) -> evalBinaryExp(x, target), #Change by me:) John
      max_prop_count,
      max_prop_exp,
    )
  else
     exp = evalBinaryOp_dispatch(exp1, op, exp2, target)
  end
  return exp
end

function evalBinaryExp(@nospecialize(binaryExp::Expression), target::EvalTarget)::Expression
  local result::Expression
  local e1::Expression
  local e2::Expression
  local op::Operator

  @match BINARY_EXPRESSION(exp1 = e1, operator = op, exp2 = e2) = binaryExp
  #= After bindingExpMap unwraps binding expressions, operands may still
     contain unevaluated forms (e.g. SUBSCRIPTED_EXP). Evaluate them
     before dispatching to the concrete arithmetic functions. =#
   e1 = evalExp_impl(e1, target)
   e2 = evalExp_impl(e2, target)
   result = evalBinaryOp_dispatch(e1, op, e2, target)
  return result
end

function evalBinaryOp_dispatch(
  exp1::Expression,
  op::Operator,
  exp2::Expression,
  target::EvalTarget = EVALTARGET_IGNORE_ERRORS(),
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
        fail()
      end
    end
  end
  return exp
end

function evalBinaryAdd(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
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
        makeArray(
          exp1.ty,
          list(@do_threaded_for evalBinaryAdd(e1, e2) (e1, e2) (
            exp1.elements,
            exp2.elements,
          )),
          literal = true,
        )
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makeAdd(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalBinarySub(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
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
        local tmp = @do_threaded_for evalBinarySub(e1, e2) (e1, e2) (
          exp1.elements,
          exp2.elements,
        )
        local arr = Expression[tmp...]
        makeArray(
          exp1.ty,
          arr,
          literal = true,
        )
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makeSub(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalBinaryMul(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
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
        makeArray(
          exp1.ty,
          list(@do_threaded_for evalBinaryMul(e1, e2) (e1, e2) (
            exp1.elements,
            exp2.elements,
          )),
          literal = true,
        )
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makeMul(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalBinaryDiv(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression), target::EvalTarget)::Expression
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
          fail()
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
        makeArray(
          exp1.ty,
          list(@do_threaded_for evalBinaryDiv(e1, e2, target) (e1, e2) (
            exp1.elements,
            exp2.elements,
          )),
          literal = true,
        )
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makeDiv(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalBinaryPow(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
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
        makeArray(
          exp1.ty,
          list(@do_threaded_for evalBinaryPow(e1, e2) (e1, e2) (
            exp1.elements,
            exp2.elements,
          )),
          literal = true,
        )
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makePow(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalBinaryScalarArray(
  scalarExp::Expression,
  arrayExp::Expression,
  opFunc::FuncT,
)::Expression
  local exp::Expression
   exp = begin
    @match arrayExp begin
      ARRAY_EXPRESSION(__) => begin
        makeArray(
          arrayExp.ty,
          list(evalBinaryScalarArray(scalarExp, e, opFunc) for e in arrayExp.elements),
          literal = true,
        )
      end
      _ => begin
        opFunc(scalarExp, arrayExp)
      end
    end
  end
  return exp
end

function evalBinaryArrayScalar(
  arrayExp::Expression,
  scalarExp::Expression,
  opFunc::FuncT,
)::Expression
  local exp::Expression
  exp = begin
    @match arrayExp begin
      ARRAY_EXPRESSION(__) => begin
        ARRAY_EXPRESSION(
          arrayExp.ty,
          Expression[evalBinaryArrayScalar(e, scalarExp, opFunc) for e in arrayExp.elements],
          true,
        )
      end
      _ => begin
        opFunc(arrayExp, scalarExp)
      end
    end
  end
  return exp
end

function evalBinaryMulVectorMatrix(@nospecialize(vectorExp::Expression), @nospecialize(matrixExp::Expression))::Expression
  local exp::Expression

  local expl::Vector{Expression}
  local m::Dimension
  local ty::M_Type

   exp = begin
    @match transposeArray(matrixExp) begin
      ARRAY_EXPRESSION(TYPE_ARRAY(ty, m <| _ <| nil()), expl) => begin
         expl = Expression[evalBinaryScalarProduct(vectorExp, e) for e in expl]
        makeArray(TYPE_ARRAY(ty, list(m)), expl, literal = true)
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          vectorExp,
          makeMul(TYPE_UNKNOWN()),
          matrixExp,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalBinaryMulMatrixVector(@nospecialize(matrixExp::Expression), @nospecialize(vectorExp::Expression))::Expression
  local exp::Expression

  local expl::Vector{Expression}
  local n::Dimension
  local ty::M_Type

   exp = begin
    @match matrixExp begin
      ARRAY_EXPRESSION(TYPE_ARRAY(ty, n <| _ <| nil()), expl) => begin
         expl = Expression[evalBinaryScalarProduct(e, vectorExp) for e in expl]
        makeArray(TYPE_ARRAY(ty, list(n)), expl, literal = true)
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          matrixExp,
          makeMul(TYPE_UNKNOWN()),
          vectorExp,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalBinaryScalarProduct(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  local exp::Expression

   exp = begin
    local elem_ty::M_Type
    @match (exp1, exp2) begin
      (
        ARRAY_EXPRESSION(ty = TYPE_ARRAY(elem_ty)),
        ARRAY_EXPRESSION(__),
      ) where {(length(exp1.elements) == length(exp2.elements))} => begin
         exp = makeZero(elem_ty)
         local elems1 = exp1.elements
         local elems2 = exp2.elements
        for i in eachindex(elems1)
           exp = evalBinaryAdd(exp, evalBinaryMul(elems1[i], elems2[i]))
        end
        exp
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makeMul(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalBinaryMatrixProduct(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  local exp::Expression

  local e2::Expression
  local expl1::Vector{Expression}
  local expl2::Vector{Expression}
  local elem_ty::M_Type
  local row_ty::M_Type
  local mat_ty::M_Type
  local n::Dimension
  local p::Dimension

   e2 = transposeArray(exp2)
   exp = begin
    @match (exp1, e2) begin
      (
        ARRAY_EXPRESSION(TYPE_ARRAY(elem_ty, n <| _ <| nil()), expl1),
        ARRAY_EXPRESSION(TYPE_ARRAY(_, p <| _ <| nil()), expl2),
      ) => begin
         mat_ty = TYPE_ARRAY(elem_ty, list(n, p))
        if isempty(expl2)
           exp = makeZero(mat_ty)
        else
           row_ty = TYPE_ARRAY(elem_ty, list(p))
           expl1 = Expression[
            makeArray(
              row_ty,
              Expression[evalBinaryScalarProduct(r, c) for c in expl2],
              literal = true,
            ) for r in expl1
          ]
           exp = makeArray(mat_ty, expl1, literal = true)
        end
        exp
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          exp1,
          makeMul(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalBinaryPowMatrix(@nospecialize(matrixExp::Expression), @nospecialize(nExp::Expression))::Expression
  local exp::Expression

  local n::Int

   exp = begin
    @match (matrixExp, nExp) begin
      (ARRAY_EXPRESSION(__), INTEGER_EXPRESSION(value = 0)) =>
        begin
           n = size(listHead(arrayDims(matrixExp.ty)))
          makeIdentityMatrix(n, TYPE_REAL())
        end

      (_, INTEGER_EXPRESSION(value = n)) => begin
        evalBinaryPowMatrix2(matrixExp, n)
      end

      _ => begin
         exp = BINARY_EXPRESSION(
          matrixExp,
          makePow(TYPE_UNKNOWN()),
          nExp,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalBinaryPowMatrix2(@nospecialize(matrix::Expression), n::Int)::Expression
  local exp::Expression

   exp = begin
    @match n begin
      1 => begin
        matrix
      end

      2 => begin
        evalBinaryMatrixProduct(matrix, matrix)
      end

      _ where {(intMod(n, 2) == 0)} => begin
        #=  A^1 = A
        =#
        #=  A^2 = A * A
        =#
        #=  A^n = A^m * A^m where n = 2*m
        =#
         exp = evalBinaryPowMatrix2(matrix, intDiv(n, 2))
        evalBinaryMatrixProduct(exp, exp)
      end

      _ => begin
        #=  A^n = A * A^(n-1)
        =#
         exp = evalBinaryPowMatrix2(matrix, n - 1)
        evalBinaryMatrixProduct(matrix, exp)
      end
    end
  end
  return exp
end

function evalUnaryOp(@nospecialize(exp1::Expression), op::Operator)::Expression
  local exp::Expression

   exp = begin
    @match op.op begin
      Op.UMINUS => begin
        bindingExpMap(exp1, evalUnaryMinus)
      end

      _ => begin
        Error.addInternalError(
          getInstanceName() +
          ": unimplemented case for " +
          toString(UNARY_EXPRESSION(op, exp1)),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return exp
end

function evalUnaryMinus(@nospecialize(exp1::Expression))::Expression
  local exp::Expression

   exp = begin
    @match exp1 begin
      INTEGER_EXPRESSION(__) => begin
        INTEGER_EXPRESSION(-exp1.value)
      end

      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(-exp1.value)
      end

      ARRAY_EXPRESSION(__) => begin
        @assign exp1.elements = Expression[evalUnaryMinus(e) for e in exp1.elements]
        exp1
      end

      _ => begin
         exp = UNARY_EXPRESSION(
          makeUMinus(TYPE_UNKNOWN()),
          exp1,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalLogicBinaryOp(
  exp1::Expression,
  op::Operator,
  exp2::Expression,
  target::EvalTarget = EVALTARGET_IGNORE_ERRORS(),
)::Expression
  local exp::Expression

  local e1::Expression
  local max_prop_exp::Expression
  local max_prop_count::Int

   (max_prop_exp, max_prop_count) =
    mostPropagatedSubExpBinary(exp1, exp2)
  if max_prop_count >= 0
     exp = bindingExpMap2(
      LBINARY_EXPRESSION(exp1, op, exp2),
      (binaryExpArg) -> evalLogicBinaryExp(binaryExpArg, target),
      max_prop_count,
      max_prop_exp,
    )
  else
     exp = evalLogicBinaryOp_dispatch(exp1, op, exp2, target)
  end
  return exp
end

function evalLogicBinaryExp(@nospecialize(binaryExp::Expression), target::EvalTarget)::Expression
  local result::Expression

  local e1::Expression
  local e2::Expression
  local op::Operator

  @match LBINARY_EXPRESSION(exp1 = e1, operator = op, exp2 = e2) = binaryExp
   result = evalLogicBinaryOp_dispatch(e1, op, e2, target)
  return result
end

function evalLogicBinaryOp_dispatch(
  exp1::Expression,
  op::Operator,
  exp2::Expression,
  target::EvalTarget,
)::Expression
  local exp::Expression

   exp = begin
    @match op.op begin
      Op.AND => begin
        evalLogicBinaryAnd(evalExp(exp1, target), exp2, target)
      end

      Op.OR => begin
        evalLogicBinaryOr(evalExp(exp1, target), exp2, target)
      end

      _ => begin
        Error.addInternalError(
          getInstanceName() +
          ": unimplemented case for " +
          toString(LBINARY_EXPRESSION(exp1, op, exp2)),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return exp
end

function evalLogicBinaryAnd(
  exp1::Expression,
  exp2::Expression,
  target::EvalTarget,
)::Expression
  local exp::Expression

   exp = begin
    local expl
    @matchcontinue exp1 begin
      BOOLEAN_EXPRESSION(__) => begin
        if exp1.value
          evalExp_impl(exp2, target)
        else
          exp1
        end
      end

      ARRAY_EXPRESSION(__) => begin
        @match ARRAY_EXPRESSION(elements = expl) = evalExp_impl(exp2, target)
         expl = Expression[evalLogicBinaryAnd(e1, e2, target) for (e1, e2) in zip(exp1.elements, expl)]
        makeArray(
          setArrayElementType(exp1.ty, TYPE_BOOLEAN()),
          expl,
          literal = true,
        )
      end

      _ => begin
         exp = LBINARY_EXPRESSION(
          exp1,
          makeAnd(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalLogicBinaryOr(
  exp1::Expression,
  exp2::Expression,
  target::EvalTarget,
)::Expression
  local exp::Expression

   exp = begin
    local expl
    @match exp1 begin
      BOOLEAN_EXPRESSION(__) => begin
        if exp1.value
          exp1
        else
          evalExp_impl(exp2, target)
        end
      end

      ARRAY_EXPRESSION(__) => begin
        @match ARRAY_EXPRESSION(elements = expl) = evalExp_impl(exp2, target)
         expl = Expression[evalLogicBinaryOr(e1, e2, target) for (e1, e2) in zip(exp1.elements, expl)]
        makeArray(
          setArrayElementType(exp1.ty, TYPE_BOOLEAN()),
          expl,
          literal = true,
        )
      end

      _ => begin
         exp = LBINARY_EXPRESSION(
          exp1,
          makeOr(TYPE_UNKNOWN()),
          exp2,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalLogicUnaryOp(@nospecialize(exp1::Expression), op::Operator)::Expression
  local exp::Expression

   exp = begin
    @match op.op begin
      Op.NOT => begin
        bindingExpMap(exp1, evalLogicUnaryNot)
      end

      _ => begin
        Error.addInternalError(
          getInstanceName() +
          ": unimplemented case for " +
          toString(LUNARY_EXPRESSION(op, exp1)),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return exp
end

function evalLogicUnaryNot(@nospecialize(exp1::Expression))::Expression
  local exp::Expression

   exp = begin
    @match exp1 begin
      BOOLEAN_EXPRESSION(__) => begin
        BOOLEAN_EXPRESSION(!exp1.value)
      end

      ARRAY_EXPRESSION(__) => begin
        mapArrayElements(exp1, evalLogicUnaryNot)
      end

      _ => begin
         exp = LUNARY_EXPRESSION(
          makeNot(TYPE_UNKNOWN()),
          exp1,
        )
        printFailedEvalError(getInstanceName(), exp, sourceInfo())
        fail()
      end
    end
  end
  return exp
end

function evalRelationOp(@nospecialize(exp1::Expression), op::Operator, @nospecialize(exp2::Expression))::Expression
  local exp::Expression

  local max_prop_exp::Expression
  local max_prop_count::Int

   (max_prop_exp, max_prop_count) =
    mostPropagatedSubExpBinary(exp1, exp2)
  if max_prop_count >= 0
     exp = bindingExpMap2(
      RELATION_EXPRESSION(exp1, op, exp2),
      evalRelationExp,
      max_prop_count,
      max_prop_exp,
    )
  else
     exp = evalRelationOp_dispatch(exp1, op, exp2)
  end
  return exp
end

function evalRelationExp(@nospecialize(relationExp::Expression))::Expression
  local result::Expression

  local e1::Expression
  local e2::Expression
  local op::Operator

  @match RELATION_EXPRESSION(exp1 = e1, operator = op, exp2 = e2) = relationExp
   result = evalRelationOp_dispatch(e1, op, e2)
  return result
end

function evalRelationOp_dispatch(
  exp1::Expression,
  op::Operator,
  exp2::Expression,
)::Expression
  local exp::Expression

  local res::Bool

   res = begin
    @match op.op begin
      Op.LESS => begin
        evalRelationLess(exp1, exp2)
      end

      Op.LESSEQ => begin
        evalRelationLessEq(exp1, exp2)
      end

      Op.GREATER => begin
        evalRelationGreater(exp1, exp2)
      end

      Op.GREATEREQ => begin
        evalRelationGreaterEq(exp1, exp2)
      end

      Op.EQUAL => begin
        evalRelationEqual(exp1, exp2)
      end

      Op.NEQUAL => begin
        evalRelationNotEqual(exp1, exp2)
      end

      _ => begin
        Error.addInternalError(
          getInstanceName() +
          ": unimplemented case for " +
          toString(RELATION_EXPRESSION(
            exp1,
            op,
            exp2,
          )),
          sourceInfo(),
        )
        fail()
      end
    end
  end
   exp = BOOLEAN_EXPRESSION(res)
  return exp
end

function evalRelationLess(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Bool
  local res::Bool

   res = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        exp1.value < exp2.value
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        exp1.value < exp2.value
      end

      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        exp1.value < exp2.value
      end

      (STRING_EXPRESSION(__), STRING_EXPRESSION(__)) => begin
        stringCompare(exp1.value, exp2.value) < 0
      end

      (
        ENUM_LITERAL_EXPRESSION(__),
        ENUM_LITERAL_EXPRESSION(__),
      ) => begin
        exp1.index < exp2.index
      end

      _ => begin
        printFailedEvalError(
          getInstanceName(),
          RELATION_EXPRESSION(
            exp1,
            makeLess(TYPE_UNKNOWN()),
            exp2,
          ),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return res
end

function evalRelationLessEq(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Bool
  local res::Bool

   res = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        exp1.value <= exp2.value
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        exp1.value <= exp2.value
      end

      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        exp1.value <= exp2.value
      end

      (STRING_EXPRESSION(__), STRING_EXPRESSION(__)) => begin
        stringCompare(exp1.value, exp2.value) <= 0
      end

      (
        ENUM_LITERAL_EXPRESSION(__),
        ENUM_LITERAL_EXPRESSION(__),
      ) => begin
        exp1.index <= exp2.index
      end

      _ => begin
        printFailedEvalError(
          getInstanceName(),
          RELATION_EXPRESSION(
            exp1,
            makeLessEq(TYPE_UNKNOWN()),
            exp2,
          ),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return res
end

function evalRelationGreater(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Bool
  local res::Bool

   res = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        exp1.value > exp2.value
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        exp1.value > exp2.value
      end

      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        exp1.value > exp2.value
      end

      (STRING_EXPRESSION(__), STRING_EXPRESSION(__)) => begin
        stringCompare(exp1.value, exp2.value) > 0
      end

      (
        ENUM_LITERAL_EXPRESSION(__),
        ENUM_LITERAL_EXPRESSION(__),
      ) => begin
        exp1.index > exp2.index
      end

      _ => begin
        printFailedEvalError(
          getInstanceName(),
          RELATION_EXPRESSION(
            exp1,
            makeGreater(TYPE_UNKNOWN()),
            exp2,
          ),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return res
end

function evalRelationGreaterEq(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Bool
  local res::Bool

   res = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        exp1.value >= exp2.value
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        exp1.value >= exp2.value
      end

      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        exp1.value >= exp2.value
      end

      (STRING_EXPRESSION(__), STRING_EXPRESSION(__)) => begin
        stringCompare(exp1.value, exp2.value) >= 0
      end

      (
        ENUM_LITERAL_EXPRESSION(__),
        ENUM_LITERAL_EXPRESSION(__),
      ) => begin
        exp1.index >= exp2.index
      end

      _ => begin
        printFailedEvalError(
          getInstanceName(),
          RELATION_EXPRESSION(
            exp1,
            makeGreaterEq(TYPE_UNKNOWN()),
            exp2,
          ),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return res
end

function evalRelationEqual(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Bool
  local res::Bool

   res = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        exp1.value == exp2.value
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        exp1.value == exp2.value
      end

      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        exp1.value == exp2.value
      end

      (STRING_EXPRESSION(__), STRING_EXPRESSION(__)) => begin
        stringCompare(exp1.value, exp2.value) == 0
      end

      (
        ENUM_LITERAL_EXPRESSION(__),
        ENUM_LITERAL_EXPRESSION(__),
      ) => begin
        exp1.index == exp2.index
      end

      _ => begin
        printFailedEvalError(
          getInstanceName(),
          RELATION_EXPRESSION(
            exp1,
            makeEqual(TYPE_UNKNOWN()),
            exp2,
          ),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return res
end

function evalRelationNotEqual(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Bool
  local res::Bool

   res = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        exp1.value != exp2.value
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        exp1.value != exp2.value
      end

      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        exp1.value != exp2.value
      end

      (STRING_EXPRESSION(__), STRING_EXPRESSION(__)) => begin
        stringCompare(exp1.value, exp2.value) != 0
      end

      (
        ENUM_LITERAL_EXPRESSION(__),
        ENUM_LITERAL_EXPRESSION(__),
      ) => begin
        exp1.index != exp2.index
      end

      _ => begin
        printFailedEvalError(
          getInstanceName(),
          RELATION_EXPRESSION(
            exp1,
            makeNotEqual(TYPE_UNKNOWN()),
            exp2,
          ),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return res
end

function evalIfExp(@nospecialize(ifExp::Expression), target::EvalTarget)::Expression
  local result::Expression

  local cond::Expression
  local btrue::Expression
  local bfalse::Expression

  @match IF_EXPRESSION(
    condition = cond,
    trueBranch = btrue,
    falseBranch = bfalse,
  ) = ifExp
   result = IF_EXPRESSION(evalExp_impl(cond, target), btrue, bfalse)
   result =
    bindingExpMap(result, (x) -> evalIfExp2(x, target))
  return result
end

function evalIfExp2(@nospecialize(ifExp::Expression), target::EvalTarget)::Expression
  local result::Expression
  local cond::Expression
  local btrue::Expression
  local bfalse::Expression
  @match IF_EXPRESSION(
    condition = cond,
    trueBranch = btrue,
    falseBranch = bfalse,
  ) = ifExp
  result = begin
    @match cond begin
      BOOLEAN_EXPRESSION(__) => begin
        evalExp_impl(if cond.value
          btrue
        else
          bfalse
        end, target)
      end
      _ => begin
        Error.addInternalError(
          getInstanceName() +
          ": unimplemented case for " +
          toString(IF_EXPRESSION(cond, btrue, bfalse)),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return result
end

function evalCast(@nospecialize(castExp::Expression), @nospecialize(castTy::M_Type))::Expression
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
        fail()
      end

      _ => begin
        ()
      end
    end
  end
  return exp
end

@nospecializeinfer function evalCall(@nospecialize(call::Call), target::EvalTarget)::Expression
  local exp::Expression
  local c::Call = call
  # @info "evalCall..."
  # println(replace(toString(call), "\n\n" => "\n"))
  exp = begin
    local args::List{Expression}
    @match c begin
      TYPED_CALL(__) => begin
        local cArgs = try
          mapPreservingEq(c.arguments, arg -> evalExp_impl(arg, target))
        catch e
          @debug "evalCall: failed to evaluate arguments" AbsynUtil.pathString(name(c.fn)) [toString(a) for a in c.arguments]
          rethrow()
        end
        if cArgs !== c.arguments
          c = TYPED_CALL(c.fn, c.ty, c.var, cArgs, c.attributes)
        end
        if isBuiltin(c.fn)
          res = bindingExpMap(
            CALL_EXPRESSION(c),
            @closure (x) -> evalxp(x, target)
          )
          res
        else
          bindingExpMap(
            CALL_EXPRESSION(c),
            evalNormalCallExp,
          )
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
        fail()
      end
    end
  end
  return exp
end

#Note was originally called evalBuiltinCallExp, but the translator seems to have butchered the name for this function..
function evalxp(@nospecialize(callExp::Expression), target::EvalTarget)::Expression
  local result::Expression
  local fn::M_Function
  local args::Vector{Expression}
  @match CALL_EXPRESSION(call = TYPED_CALL(fn = fn, arguments = args)) = callExp
  result = ceval(fn, args, target)
  return result
end

function ceval(
  fn::M_Function,
  args::Vector{Expression},
  target::EvalTarget,
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

      "Int" => begin
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
        fail()
      end
    end
  end
  return result
end

function evalNormalCallExp(@nospecialize(callExp::Expression))::Expression
  local result::Expression
  local fn::M_Function
  local args::Vector{Expression}
  @match CALL_EXPRESSION(call = TYPED_CALL(fn = fn, arguments = args)) = callExp
  result = evalNormalCall(fn, args)
  return result
end

function evalNormalCall(fn::M_Function, args::Vector{Expression})::Expression
  local result::Expression = evaluate(fn, args) #=TODO: Fix the interface here later.=#
  return result
end

function evalBuiltinAbs(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      INTEGER_EXPRESSION(__) => begin
        INTEGER_EXPRESSION(abs(arg.value))
      end

      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(abs(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
      end
    end
  end
  return result
end

function evalBuiltinAcos(@nospecialize(arg::Expression), target::EvalTarget)::Expression
  local result::Expression

  local x::AbstractFloat

   result = begin
    @match arg begin
      REAL_EXPRESSION(value = x) => begin
        if x < (-1.0) || x > 1.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.ARGUMENT_OUT_OF_RANGE,
              list(String(x), "acos", "-1 <= x <= 1"),
              EvalTarget_getInfo(target),
            )
          end
          fail()
        end
        REAL_EXPRESSION(acos(x))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
      end
    end
  end
  return result
end

function evalBuiltinArray(args::Union{List{Expression}, Vector{Expression}})::Expression
  local result::Expression
  local ty::M_Type
  ty = typeOf(Base.first(args))
  ty = liftArrayLeft(ty, fromInteger(length(args)))
  result = makeArray(ty, args, literal = true)
  return result
end

function evalBuiltinAsin(@nospecialize(arg::Expression), target::EvalTarget)::Expression
  local result::Expression

  local x::AbstractFloat

   result = begin
    @match arg begin
      REAL_EXPRESSION(value = x) => begin
        if x < (-1.0) || x > 1.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.ARGUMENT_OUT_OF_RANGE,
              list(String(x), "asin", "-1 <= x <= 1"),
              EvalTarget_getInfo(target),
            )
          end
          fail()
        end
        REAL_EXPRESSION(asin(x))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
      end
    end
  end
  return result
end

function evalBuiltinAtan2(args::Union{List{Expression}, Vector{Expression}})::Expression
  local result::Expression
  local y::AbstractFloat
  local x::AbstractFloat
  if length(args) == 2
    @match REAL_EXPRESSION(value = y) = Base.first(args)
    @match REAL_EXPRESSION(value = x) = Base.last(args)
    result = REAL_EXPRESSION(atan2(y, x))
  else
    printWrongArgsError(getInstanceName(), args, sourceInfo())
    fail()
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
        fail()
      end
    end
  end
  return result
end

function evalBuiltinCat(
  argN::Expression,
  args::Vector{Expression},
  target::EvalTarget,
  )::Expression
  local result::Expression
  local n::Int
  local nd::Int
  local sz::Int
  local ty::M_Type
  local es::Vector{Expression}
  local dims::List{Int}
  @match INTEGER_EXPRESSION(n) = argN
  ty = typeOf(Base.first(args))
  nd = dimensionCount(ty)
  if n > nd || n < 1
    if hasInfo(target)
      Error.addSourceMessage(
        Error.ARGUMENT_OUT_OF_RANGE,
        list(String(n), "cat", "1 <= x <= " + String(nd)),
        EvalTarget_getInfo(target),
      )
    end
    fail()
  end
  es = Expression[e for e in args if !isEmptyArray(e)]
  sz = length(es)
  if sz == 0
    result = Base.first(args)
  elseif sz == 1
    result = Base.first(es)
  else
    # print("\nBEFORE EVAL CAT {");
    # for e in es
    #   print(toString(e));
    #   print(",");
    # end
    #   print("}\n");
     (es, dims) = evalCat(
       n,
       es,
       arrayElements,
       toString,
     )
    # print("\nEVAL CAT {");
    # for e in es
    #   print(toString(e));
    #   print(",");
    # end
    # print("}\n");
    # print("\nDimensions {")
    # for d in dims
    #   print(String(d))
    #   print(",")
    # end
    # print("}\n")
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
        REAL_EXPRESSION(ceil(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
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
        fail()
      end
    end
  end
  return result
end

function evalBuiltinCos(@nospecialize(arg::Expression))::Expression
  local result::Expression

   result = begin
    @match arg begin
      REAL_EXPRESSION(__) => begin
        REAL_EXPRESSION(cos(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
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

  local elem_ty::M_Type
  local row_ty::M_Type
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
        fail()
      end
    end
  end
  return result
end

function evalBuiltinDiv(args::Vector{Expression}, target::EvalTarget)::Expression
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
              list(String(ix), String(iy)),
              EvalTarget_getInfo(target),
            )
          end
          fail()
        end
        INTEGER_EXPRESSION(intDiv(ix, iy))
      end

      [REAL_EXPRESSION(rx), REAL_EXPRESSION(ry)] =>
        begin
          if ry == 0.0
            if hasInfo(target)
              Error.addSourceMessage(
                Error.DIVISION_BY_ZERO,
                list(String(rx), String(ry)),
                EvalTarget_getInfo(target),
              )
            end
            fail()
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
        fail()
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
        fail()
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
  local arr_ty::M_Type = typeOf(result)
  for d in reverse(dims)
    dim_size = begin
      @match d begin
        INTEGER_EXPRESSION(value = dim_size) => dim_size
        _ => begin
          printWrongArgsError(getInstanceName(), list(d), sourceInfo())
          fail()
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
        REAL_EXPRESSION(floor(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
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
        fail()
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
        fail()
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
        fail()
      end
    end
  end
  return result
end

function evalBuiltinLog10(@nospecialize(arg::Expression), target::EvalTarget)::Expression
  local result::Expression

  local x::AbstractFloat

   result = begin
    @match arg begin
      REAL_EXPRESSION(value = x) => begin
        if x <= 0.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.ARGUMENT_OUT_OF_RANGE,
              list(String(x), "log10", "x > 0"),
              EvalTarget_getInfo(target),
            )
          end
          fail()
        end
        REAL_EXPRESSION(log10(x))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
      end
    end
  end
  return result
end

function evalBuiltinLog(@nospecialize(arg::Expression), target::EvalTarget)::Expression
  local result::Expression

  local x::AbstractFloat

   result = begin
    @match arg begin
      REAL_EXPRESSION(value = x) => begin
        if x <= 0.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.ARGUMENT_OUT_OF_RANGE,
              list(String(x), "log", "x > 0"),
              EvalTarget_getInfo(target),
            )
          end
          fail()
        end
        REAL_EXPRESSION(log(x))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
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
    local ty::M_Type
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
          fail()
        end
        result
      end
    end
  end
  return result
end

function evalBuiltinMatrix2(@nospecialize(arg::Expression), @nospecialize(ty::M_Type))::Expression
  local result::Expression

   result = begin
    @match arg begin
      ARRAY_EXPRESSION(__) => begin
        makeArray(
          ty,
          list(toScalar(e) for e in arg.elements),
          arg.literal,
        )
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
      end
    end
  end
  return result
end

function evalBuiltinMax(args::Vector{Expression}, fn::M_Function)::Expression
  local result::Expression
  local e1::Expression
  local e2::Expression
  local ty::M_Type
  result = begin
    @match args begin
      [e1, e2] => begin
        evalBuiltinMax2(e1, e2)
      end
      [e1] && [ARRAY_EXPRESSION(ty = ty)] => begin
        result = fold(
          e1,
          evalBuiltinMax2,
          EMPTY_EXPRESSION(ty),
        )
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
        fail()
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
        if exp1.value < exp2.value
          exp2
        else
          exp1
        end
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        if exp1.value < exp2.value
          exp2
        else
          exp1
        end
      end

      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        if exp1.value < exp2.value
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
        fail()
      end
    end
  end
  return result
end

function evalBuiltinMin(args::Union{List{Expression}, Vector{Expression}}, fn::M_Function)::Expression
  local result::Expression
  local e1::Expression
  local ty::M_Type
  local nArgs::Int = length(args)

  if nArgs == 2
    result = evalBuiltinMin2(Base.first(args), Base.last(args))
  elseif nArgs == 1
    e1 = Base.first(args)
    @match ARRAY_EXPRESSION(ty = ty) = e1
    result = fold(e1, evalBuiltinMin2, EMPTY(ty))
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
    fail()
  end
  return result
end

function evalBuiltinMin2(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  local result::Expression

   result = begin
    @match (exp1, exp2) begin
      (INTEGER_EXPRESSION(__), INTEGER_EXPRESSION(__)) => begin
        if exp1.value > exp2.value
          exp2
        else
          exp1
        end
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        if exp1.value > exp2.value
          exp2
        else
          exp1
        end
      end

      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        if exp1.value > exp2.value
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

      (_, EMPTY(__)) => begin
        exp1
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(exp1, exp2), sourceInfo())
        fail()
      end
    end
  end
  return result
end

function evalBuiltinMod(args::Vector{Expression}, target::EvalTarget)::Expression
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
              list(String(x.value), String(y.value)),
              EvalTarget_getInfo(target),
            )
          end
          fail()
        end
        INTEGER_EXPRESSION(mod(x.value, y.value))
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        if y.value == 0.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.MODULO_BY_ZERO,
              list(String(x.value), String(y.value)),
              EvalTarget_getInfo(target),
            )
          end
          fail()
        end
        REAL_EXPRESSION(mod(x.value, y.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        fail()
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
            TYPE_INTEGER(__) => begin
              INTEGER_EXPRESSION(fold(
                arg,
                evalBuiltinProductInt,
                1,
              ))
            end

            TYPE_REAL(__) => begin
              REAL_EXPRESSION(fold(
                arg,
                evalBuiltinProductReal,
                1.0,
              ))
            end

            _ => begin
              printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
              fail()
            end
          end
        end
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
      end
    end
  end
  return result
end

function evalBuiltinProductInt(@nospecialize(exp::Expression), result::Int)::Int

   result = begin
    @match exp begin
      INTEGER_EXPRESSION(__) => begin
        result * exp.value
      end

      ARRAY_EXPRESSION(__) => begin
        result
      end

      _ => begin
        fail()
      end
    end
  end
  return result
end

function evalBuiltinProductReal(@nospecialize(exp::Expression), result::AbstractFloat)::AbstractFloat

   result = begin
    @match exp begin
      REAL_EXPRESSION(__) => begin
        result * exp.value
      end

      ARRAY_EXPRESSION(__) => begin
        result
      end

      _ => begin
        fail()
      end
    end
  end
  return result
end

function evalBuiltinPromote(@nospecialize(arg::Expression), @nospecialize(argN::Expression))::Expression
  local result::Expression
  local n::Int
  if isInteger(argN)
    @match INTEGER_EXPRESSION(n) = argN
    (result, _) = promote(arg, typeOf(arg), n)
  else
    printWrongArgsError(getInstanceName(), list(arg, argN), sourceInfo())
    fail()
  end
  return result
end

function evalBuiltinRem(args::Union{List{Expression}, Vector{Expression}}, target::EvalTarget)::Expression
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
              list(String(x.value), String(y.value)),
              EvalTarget_getInfo(target),
            )
          end
          fail()
        end
        INTEGER_EXPRESSION(x.value - div(x.value, y.value) * y.value)
      end

      (REAL_EXPRESSION(__), REAL_EXPRESSION(__)) => begin
        if y.value == 0.0
          if hasInfo(target)
            Error.addSourceMessage(
              Error.REM_ARG_ZERO,
              list(String(x.value), String(y.value)),
              EvalTarget_getInfo(target),
            )
          end
          fail()
        end
        REAL_EXPRESSION(x.value - div(x.value, y.value) * y.value)
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        fail()
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
        INTEGER_EXPRESSION(if arg.value > 0
          1
        else
          if arg.value < 0
            -1
          else
            0
          end
        end)
      end

      INTEGER_EXPRESSION(__) => begin
        INTEGER_EXPRESSION(if arg.value > 0
          1
        else
          if arg.value < 0
            -1
          else
            0
          end
        end)
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
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
        fail()
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
        REAL_EXPRESSION(sin(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
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
  local ty::M_Type
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
        fail()
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
        fail()
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
          fail()
        end
      end
    end
    str_len = stringLength(str)
    if str_len < min_len
      if left_justified
        str = str + stringAppendList(ListUtil.fill(" ", min_len - str_len))
      else
        str = stringAppendList(ListUtil.fill(" ", min_len - str_len)) + str
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
    #= String(real, format) =#
    r = args[1].value
    format = args[2].value
    str = System.sprintff(format, r)
    result = STRING_EXPRESSION(str)
  else
    printWrongArgsError(getInstanceName(), args, sourceInfo())
    fail()
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
            TYPE_INTEGER(__) => begin
              INTEGER_EXPRESSION(fold(
                arg,
                evalBuiltinSumInt,
                0,
              ))
            end

            TYPE_REAL(__) => begin
              REAL_EXPRESSION(fold(
                arg,
                evalBuiltinSumReal,
                0.0,
              ))
            end

            _ => begin
              printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
              fail()
            end
          end
        end
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
      end
    end
  end
  return result
end

function evalBuiltinSumInt(@nospecialize(exp::Expression), result::Int)::Int

   result = begin
    @match exp begin
      INTEGER_EXPRESSION(__) => begin
        result + exp.value
      end

      ARRAY_EXPRESSION(__) => begin
        result
      end

      _ => begin
        fail()
      end
    end
  end
  return result
end

function evalBuiltinSumReal(@nospecialize(exp::Expression), result::AbstractFloat)::AbstractFloat

   result = begin
    @match exp begin
      REAL_EXPRESSION(__) => begin
        result + exp.value
      end

      ARRAY_EXPRESSION(__) => begin
        result
      end

      _ => begin
        fail()
      end
    end
  end
  return result
end

function evalBuiltinSymmetric(@nospecialize(arg::Expression))::Expression
  local result::Expression

  local n::Int
  local row_ty::M_Type

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
        fail()
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
        fail()
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
        REAL_EXPRESSION(tan(arg.value))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
      end
    end
  end
  return result
end

function evalBuiltinTranspose(@nospecialize(arg::Expression))::Expression
  local result::Expression
  local dim1::Dimension
  local dim2::Dimension
  local ty::M_Type
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
        fail()
      end
    end
  end
  return result
end

function evalBuiltinVector(@nospecialize(arg::Expression))::Expression
  local result::Expression

  local expl::List{Expression}
  local ty::M_Type

   expl = fold(arg, evalBuiltinVector2, nil)
   ty = liftArrayLeft(
    arrayElementType(typeOf(arg)),
    fromInteger(listLength(expl)),
  )
   result = makeArray(ty, listReverse(expl), literal = true)
  return result
end

function evalBuiltinVector2(@nospecialize(exp::Expression), expl::List{Expression})::List{Expression}

   expl = begin
    @match exp begin
      ARRAY_EXPRESSION(__) => begin
        expl
      end

      _ => begin
        _cons(exp, expl)
      end
    end
  end
  return expl
end

function evalBuiltinZeros(args::Union{List{Expression}, Vector{Expression}})::Expression
  local result::Expression
  result = evalBuiltinFill2(INTEGER_EXPRESSION(0), args)
  return result
end

function evalUriToFilename(
  fn::M_Function,
  args::Union{List{Expression}, Vector{<:Expression}},
  target::EvalTarget,
)::Expression
  local result::Expression

  local e::Expression
  local arg::Expression
  local s::String
  local f::M_Function

   arg = args[1]
   result = begin
    @match arg begin
      STRING_EXPRESSION(__) => begin
         s = resolveModelicaUri(arg.value)
         STRING_EXPRESSION(s)
      end

      _ => begin
        printWrongArgsError(getInstanceName(), list(arg), sourceInfo())
        fail()
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
  local resourcePath = rest[slashIdx+1:end]
  #= Search in OMFrontend bundled lib directory =#
  local packagePath = dirname(dirname(realpath(Base.find_package("OMFrontend"))))
  local libDir = joinpath(packagePath, "lib", packageName)
  local resolved = joinpath(libDir, resourcePath)
  if isfile(resolved)
    return resolved
  end
  #= Search in openmodelica libraries cache =#
  local omLibDir = joinpath(homedir(), ".openmodelica", "libraries")
  if isdir(omLibDir)
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
        fail()
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
        fail()
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
        fail()
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
        fail()
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
        fail()
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
        CLKCONST(P_Expression.P_ClockKind.Expression.INFERRED_CLOCK())
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        fail()
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
        CLKCONST(P_Expression.P_ClockKind.Expression.INTEGER_CLOCK(
          interval,
          resolution,
        ))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        fail()
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
      interval && REAL_EXPRESSION(__) <| nil() => begin
        CLKCONST(P_Expression.P_ClockKind.REAL_EXPRESSION_CLOCK(
          interval,
        ))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        fail()
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
        CLKCONST(P_Expression.P_ClockKind.BOOLEAN_EXPRESSION_CLOCK(
          condition,
          interval,
        ))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        fail()
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
      CLKCONST(__) <| solver &&
      STRING_EXPRESSION(__) <| nil() => begin
        CLKCONST(P_Expression.P_ClockKind.Expression.SOLVER_CLOCK(
          c,
          solver,
        ))
      end

      _ => begin
        printWrongArgsError(getInstanceName(), args, sourceInfo())
        fail()
      end
    end
  end
  return result
end

function evalBuiltinDynamicSelect(
  fn::M_Function,
  args::List{Expression},
  target::EvalTarget,
)::Expression
  local result::Expression
  local s::Expression
  local d::Expression
  @match list(s, d) = list(unbox(arg) for arg in args)
  s = evalExp(s, target)
  result = s
  return result
end

function evalArrayConstructor(
  exp::Expression,
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Expression
  local result::Expression
  (result, ) = evalExpPartial(exp)
  result = bindingExpMap(
    result,
    (expArg) -> evalArrayConstructor2(expArg, iterators),
  )
  return result
end

function evalArrayConstructor2(
  exp::Expression,
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Expression
  local result::Expression

  local e::Expression
  local ranges::List{Expression}
  local iters::List{Pointer{Expression}}
  local types::List{M_Type} = nil
  local ty::M_Type

   (e, ranges, iters) = createIterationRanges(exp, iterators)
  #=  Precompute all the types we're going to need for the arrays created.
  =#
   ty = typeOf(e)
  for r in ranges
     ty =
      liftArrayLeftList(ty, arrayDims(typeOf(r)))
     types = Cons{NFType}(ty, types)
  end
   result = evalArrayConstructor3(e, ranges, iters, types)
  return result
end

function createIterationRanges(
  exp::Expression,
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Tuple{Expression, List{Expression}, List{Pointer{Expression}}}
  local iters::List{Pointer{Expression}} = nil
  local ranges::List{Expression} = nil

  local node::InstNode
  local range::Expression
  local iter::Pointer{Expression}

  for i in iterators
     (node, range) = i
     iter = P_Pointer.create(INTEGER_EXPRESSION(0), Expression)
     exp = replaceIterator(
      exp,
      node,
      MUTABLE_EXPRESSION(iter),
    )
     iters = _cons(iter, iters)
     ranges = _cons(evalExp_impl(range, EVALTARGET_IGNORE_ERRORS()), ranges)
  end
  return (exp, ranges, iters)
end

function evalArrayConstructor3(
  exp::Expression,
  ranges::List{Expression},
  iterators::List{<:Pointer{Expression}},
  types::List{<:M_Type},
)::Expression
  local result::Expression
  local range::Expression
  local e::Expression
  local ranges_rest::List{Expression}
  local expV::Vector{Expression} = Expression[]
  local iter::Pointer{Expression}
  local iters_rest::List{Pointer{Expression}}
  local range_iter::ExpressionIterator
  local value::Expression
  local ty::M_Type
  local rest_ty::List{M_Type}
  if listEmpty(ranges)
    result = evalExp_impl(exp, EVALTARGET_IGNORE_ERRORS())
  else
    @match _cons(range, ranges_rest) = ranges
    @match _cons(iter, iters_rest) = iterators
    @match _cons(ty, rest_ty) = types
    range_iter = fromExpToExpressionIterator(range)
    while hasNext(range_iter)
      (range_iter, value) = next(range_iter)
      P_Pointer.update(iter, value)
      push!(expV, evalArrayConstructor3(exp, ranges_rest, iters_rest, rest_ty))#expl = _cons(evalArrayConstructor3(exp, ranges_rest, iters_rest, rest_ty), expl)
    end
    result = makeArray(ty, expV, literal = true)
  end
  return result
end

function evalReduction(
  fn::M_Function,
  exp::Expression,
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Expression
  local result::Expression

   result = evalExpPartial(exp)
   result = bindingExpMap(
    result,
    (fn, iterators) -> evalReduction2(fn = fn, iterators = iterators),
  )
  return result
end

function evalReduction2(
  fn::M_Function,
  exp::Expression,
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Expression
  local result::Expression

  local e::Expression
  local default_exp::Expression
  local ranges::List{Expression}
  local iters::List{Pointer{Expression}}
  local red_fn::Function
  local ty::M_Type

   (e, ranges, iters) = createIterationRanges(exp, iterators)
   ty = typeOf(e)
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
        Error.assertion(
          false,
          getInstanceName() +
          " got unknown reduction function " +
          AbsynUtil.pathString(name(fn)),
          sourceInfo(),
        )
        fail()
      end
    end
  end
   result = evalReduction3(e, ranges, iters, default_exp, red_fn)
  return result
end

function evalReduction3(
  exp::Expression,
  ranges::List{Expression},
  iterators::List{<:Pointer{Expression}},
  foldExp::Expression,
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
  local el_ty::M_Type

  if listEmpty(ranges)
     result = fn(foldExp, evalExp_impl(exp, EVALTARGET_IGNORE_ERRORS()))
  else
    @match _cons(range, ranges_rest) = ranges
    @match _cons(iter, iters_rest) = iterators
     range_iter = P_ExpressionIterator.ExpressionIterator.fromExp(range)
     result = foldExp
    while P_ExpressionIterator.ExpressionIterator.hasNext(range_iter)
       (range_iter, value) = P_ExpressionIterator.ExpressionIterator.next(range_iter)
      P_Pointer.update(iter, value)
       result = evalReduction3(exp, ranges_rest, iters_rest, result, fn)
    end
  end
  return result
end

function evalSize(
  exp::Expression,
  optIndex::Option{Expression},
  target::EvalTarget,
  )::Expression
  local outExp::Expression
  local index_exp::Expression
  local index::Int
  local ty_err::TypingError
  local dim::Dimension
  local ty::M_Type
  local expl::List{Expression}
  local info::SourceInfo
  info = EvalTarget_getInfo(target)
  if isSome(optIndex)
    index_exp = evalExp_impl(Util.getOption(optIndex), target)
    index = toInteger(index_exp)
    (dim, _, ty_err) = typeExpDim(exp, index, ORIGIN_CLASS, info)
    checkSizeTypingError(ty_err, exp, index, info)
    outExp = sizeExp(dim)
  else
    (outExp, ty) = typeExp(exp, ORIGIN_CLASS, info)
    expl = list(sizeExp(d) for d in arrayDims(ty))
    dim = fromInteger(listLength(expl), Variability.PARAMETER)
    outExp =
      makeArray(TYPE_ARRAY(TYPE_INTEGER(), list(dim)), expl)
  end
  #=  Evaluate the index.
  =#
  #=  Get the index'd dimension of the expression.
  =#
  #=  Return the size expression for the found dimension.
  =#
  return outExp
end

function evalSubscriptedExp(
  exp::Expression,
  subscripts::List{<:Subscript},
  target::EvalTarget,
)::Expression
  local result::Expression

  local subs::List{Subscript}

   result = begin
    @match exp begin
      RANGE_EXPRESSION(__) => begin
        RANGE_EXPRESSION(
          exp.ty,
          evalExp(exp.start, target),
          evalExpOpt(exp.step, target),
          evalExp(exp.stop, target),
        )
      end

      _ => begin
        evalExp_impl(exp, target)
      end
    end
  end
   subs = list(
    mapShallowExp(s, @closure (x) -> evalExp_impl(x, target))
    for s in subscripts
  )
  result = applySubscripts(subs, result)
  return result
end

function evalRecordElement(exp::RECORD_ELEMENT_EXPRESSION, target::EvalTarget)
  local result::Expression
  local e::Expression
  local index::Int
  e = exp.recordExp
  index = exp.index
  e = evalExp_impl(e, target)
  try
    result =
      bindingExpMap(e, @closure (x) -> evalRecordElement2(x, index))
  catch
    Error.assertion(
      false,
      getInstanceName() + " could not evaluate " + toString(exp),
      sourceInfo(),
    )
  end
  return result
end

function evalRecordElement2(exp::RECORD_EXPRESSION, index::Int)
  exp.elements[index]
end

function printUnboundError(component::Component, target::EvalTarget, @nospecialize(exp::Expression))
  return  () = begin
    @match target begin
      EVALTARGET_IGNORE_ERRORS(__) => begin
        ()
      end

      EVALTARGET_DIMENSION(__) => begin
        Error.addSourceMessage(
          Error.STRUCTURAL_PARAMETER_OR_CONSTANT_WITH_NO_BINDING,
          list(toString(exp), name(target.component)),
          target.info,
        )
        fail()
      end

      EVALTARGET_CONDITION(__) => begin
        Error.addSourceMessage(
          Error.CONDITIONAL_EXP_WITHOUT_VALUE,
          list(toString(exp)),
          target.info,
        )
        fail()
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
          fail()
        end
        #=  only add an error if fixed = true
        =#
        #=  constant with no binding
        =#
        ()
      end
    end
  end
end

function printWrongArgsError(evalFunc::String, args::List{Expression}, info::SourceInfo)
  return Error.addInternalError(
    evalFunc +
    " got invalid arguments " +
    ListUtil.toString(args, toString, "", "(", ", ", ")", true),
    info,
  )
end

"""
  @author:johti17
  input: The set of initial equations
  output: A mapping between the component references of the variables and the values of the initial equations
(Where the lhs of the equation system is a variable)
"""
function evalInitialEqMapping(ieq)
  local mapping::Dict = Dict()
  for eq in ieq
    var = Variable_fromCref(toCref(eq.lhs))
    push!(mapping, toString(var.name) => eq.rhs)
  end
  return mapping
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
    local jlmatrix = modelicaMatrixToJuliaMatrix(exps)::Matrix{ARRAY_EXPRESSION}
    local matrixCat = Base.cat(jlmatrix; dims = dim)
    local outExps = jlMatrixToModelicaArrayExpVector(matrixCat)
    #= Convert the outExps to a flat array =#
    local outDims = list(length(outExps), length(Base.first(outExps).elements))
    local outExpsAsVector = Base.map((x) -> x.elements, outExps)
    local outExpFlat = Expression[]
    for vec in outExpsAsVector
      for e in vec
        push!(outExpFlat, e)
      end
    end
    local outDims = list(length(outExps), length(Base.first(outExps).elements))
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

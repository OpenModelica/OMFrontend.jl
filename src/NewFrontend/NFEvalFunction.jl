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
using ExportAll

module ReplTree

using MetaModelica
using ExportAll

import ..Frontend.NFExpression
import ..Frontend.InstNode
import ..Frontend.refCompare
import ..Frontend.toString
import ..Frontend.Util

const Expression = NFExpression
const Key = InstNode
const Value = Expression

include("../Util/baseAvlTreeCode.jl")

function keyStr(inKey)
  toString(inKey)
end

function valueStr(inValue)
  toString(inValue);
end

keyCompare = (inKey1::InstNode, inKey2::InstNode) -> begin
  refCompare(inKey1, inKey2)
end

@exportAll()
end

const FlowControlType = Int
struct FlowControlStruct{T}
  NEXT::T
  CONTINUE::T
  BREAK::T
  RETURN::T
  ASSERTION::T
end
const FlowControl = FlowControlStruct{Int}(1,2,3,4,5)

const _EVAL_RECURSION_LIMIT_CACHE = Ref{Int}(-1)
@inline function _evalRecursionLimit()::Int
  local v::Int = _EVAL_RECURSION_LIMIT_CACHE[]
  if v < 0
    v = Int(Flags.getConfigInt(Flags.EVAL_RECURSION_LIMIT))
    _EVAL_RECURSION_LIMIT_CACHE[] = v
  end
  return v
end

function evaluate(fn::M_Function, args::Vector{Expression})::Expression
  local result::Expression
  if isExternal(fn)
    result = evaluateExternal(fn, args)
  else
    result = evaluateNormal(fn, args)
  end
  return result
end

function evaluateNormal(fn::M_Function, args::Vector{Expression})::Expression
  local result::Expression
  local fn_body::Vector{Statement}
  local bindings::List{Binding}
  local repl::ReplTree.Tree
  local call_count::Int
  local limit::Int
  local call_counter::Pointer = fn.callCounter
  local ctrl::FlowControlType
  #=
  Functions contain a mutable call counter that's increased by one at the
  start of each evaluation, and decreased by one when the evalution is
  finished. This is used to limit the number of recursive functions calls.
  =#
  call_count = P_Pointer.access(call_counter) + 1
  limit = _evalRecursionLimit()
  if call_count > limit
    Pointer.update(call_counter, 0)
    Error.addSourceMessage(
      Error.EVAL_RECURSION_LIMIT_REACHED,
      list(String(limit), AbsynUtil.pathString(name(fn))),
      info(fn.node),
    )
    fail()
  end
  P_Pointer.update(call_counter, call_count)
  try
    fn_body = getBody(fn)
    repl = createReplacements(fn, args)
    fn_body = applyReplacements(repl, fn_body)
    fn_body = optimizeBody(fn_body)
    ctrl = evaluateStatements(fn_body)
    if ctrl != FlowControl.ASSERTION
      @assign result = createResult(repl, fn.outputs)
    else
      fail()
    end
  catch e
    P_Pointer.update(call_counter, call_count - 1)
    fail()
  end
  #=  TODO: Also apply replacements to the replacements themselves, i.e. the
          bindings of the function parameters. But they probably need to be
         sorted by dependencies first.
  Make sure we always decrease the call counter even if the evaluation fails.
  =#
  P_Pointer.update(call_counter, call_count - 1)
  return result
end

function evaluateExternal(fn::M_Function, args::Vector{Expression})::Expression
  local result::Expression

  local name::String
  local lang::String
  local output_ref::ComponentRef
  local ann::Option{SCode.Annotation}
  local ext_args::Vector{Expression}

  @match SECTIONS_EXTERNAL(
    name = name,
    args = ext_args,
    outputRef = output_ref,
    language = lang,
    ann = ann,
  ) = getSections(getClass(fn.node))
  if lang == "builtin"
    #= TODO: evalfn does not exist yet. This path is for builtin external functions. =#
    error("evalfn not implemented for builtin external function: " * name)
  elseif isKnownExternalFunc(name, ann)
    result = evaluateKnownExternal(name, list(args...))
  else
    try
      result = evaluateExternal2(name, fn, args, ext_args)
    catch
      Error.assertion(
        false,
        getInstanceName() +
        " failed on " +
        AbsynUtil.pathString(fn.path) +
        ", evaluation of userdefined external functions not yet implemented",
        sourceInfo(),
      )
      fail()
    end
  end
  #=  Functions defined as 'external \"builtin\"', delegate to Ceval.
  =#
  #=  External functions that we know how to evaluate without generating code.
  =#
  #=  TODO: Move this to EvalFunctionExt and unify evaluateKnownExternal and
  =#
  #=        evaluateExternal2. This requires handling of outputRef though.
  =#
  #=  External functions that we would need to generate code for and execute. =#
  return result
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
  fn::M_Function,
  ty::M_Type,
  args::Vector{Expression};
  evaluate::Bool = true,
)::Expression
  local result::Expression
  local repl::ReplTree.Tree
  local arg::Expression
  local repl_exp::Expression
  local fields::List{Field}
  local rest_args::Vector{Expression} = args
  local inputs::List{InstNode} = fn.inputs
  local locals::List{InstNode} = fn.locals
  local node::InstNode
  repl = ReplTree.new()
  fields = recordFields(ty)
  #=
  Add the inputs and local variables to the replacement tree with their
  respective bindings.
  =#
  for (j,i) in enumerate(inputs)
    arg = rest_args[j]
    repl = ReplTree.add(repl, i, arg)
  end
  for l in locals
    repl = ReplTree.add(repl, l, getBindingExp(l, repl))
  end
  #=  Apply the replacements to all the variables. =#
  repl = ReplTree.map(repl, (nodeArg, expArg) -> applyBindingReplacement(nodeArg, expArg, repl))
  #=
  Fetch the new binding expressions for all the variables, both inputs and
  locals.
  =#
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

function createReplacements(fn::M_Function, args::Vector{Expression})::ReplTree.Tree
  local repl::ReplTree.Tree

  local arg::Expression
  local rest_args::Vector{Expression} = args

  repl = ReplTree.new()
  #=  Add inputs to the replacement tree. Since they can't be assigned to the
    replacements don't need to be mutable.
  =#
  for (j,i) in enumerate(fn.inputs)
    arg = rest_args[j]
    repl = addInputReplacement(i, arg, repl)
  end
  #=
  Add outputs and local variables to the replacement tree. These do need to
  be mutable to allow assigning to them.
  =#
  #@info "Outputs was..." typeof(fn.outputs)
  #@info "REPL TREE BEFORE:" ReplTree.printTreeStr(repl)
  repl = ListUtil.fold(fn.outputs, addMutableReplacement, repl)
  #@info "Done..."
  #@info "REPL TREE:" ReplTree.printTreeStr(repl)
  repl = ListUtil.fold(fn.locals, addMutableReplacement, repl)
  #=  Apply the replacements to the replacements themselves. This is done after
  =#
  #=  building the tree to make sure all the replacements are available.
  =#
  repl = ReplTree.map(repl, (nodeArg, expArg) -> applyBindingReplacement(nodeArg, expArg, repl))
  return repl
end

function addMutableReplacement(node::InstNode, repl::ReplTree.Tree)::ReplTree.Tree

  local binding::Binding
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
  local ty::M_Type
  ty = getType(node)
  ty = mapDims(ty, (expArg) -> applyReplacementsDim(repl, expArg))
  #@info "Our node is a " toString(ty) typeof(ty)
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
  #@info "Done buildbinding..." string(dump(result; maxdepth=5))
  return result
end

function applyReplacementsDim(repl::ReplTree.Tree, dim::Dimension)::Dimension
  dim = begin
    local exp::Expression
    @match dim begin
      DIMENSION_EXP(__) => begin
        exp = map(
          dim.exp,
          (expArg) -> applyReplacements2(repl, expArg),
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
          #=  Create a replacement tree for just the record instance. This is
          =#
          #=  needed for records that contain local references such as:
          =#
          #=    record R
          =#
          #=      Real x;
          =#
          #=      Real y = x;
          =#
          #=    end R;
          =#
          #=  In that case we need to replace the 'x' in the binding of 'y' with
          =#
          #=  the binding expression of 'x'.
          =#
          local_repl = ReplTree.new()
          for i = arrayLength(comps):(-1):1
            exp = makeMutable(getBindingExp(comps[i], repl))
            local_repl = ReplTree.add(local_repl, comps[i], exp)
            bindings = Cons{Expression}(exp, bindings)
          end
          #=  Add the expression to both the replacement tree and the list of bindings.
          =#
          #=  Replace references to record fields with those fields' bindings in the tree.
          =#
          #=  This will also update the list of bindings since they share mutable expresions.
          =#
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
  argument::Expression,
  repl::ReplTree.Tree,
)::ReplTree.Tree

  @assign repl = ReplTree.add(repl, node, argument)
  return repl
end

function applyBindingReplacement(
  node::InstNode,
  exp::Expression,
  repl::ReplTree.Tree,
)::Expression
  local outExp::Expression
  outExp =
    map(exp, (expArg) -> applyReplacements2(repl, expArg))
  return outExp
end

function applyReplacements(repl::ReplTree.Tree, fnBody::Vector{Statement})
  fnBody = mapExpList(
    fnBody,
    (x) -> map(x, (expArg) -> applyReplacements2(repl, expArg)),
  )#= AbsyntoJulia.dumpPattern: UNHANDLED Abyn.Exp  =#
  return fnBody
end

function applyReplacements2(repl::ReplTree.Tree, @nospecialize(exp::Expression))::Expression
  exp = begin
    @match exp begin
      CREF_EXPRESSION(__) => begin
        applyReplacementCref(repl, exp.cref, exp)
      end
      _ => begin
        exp
      end
    end
  end
  return exp
end

function applyReplacementCref(
  repl::ReplTree.Tree,
  cref::ComponentRef,
  exp::Expression,
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
  #=  If the list is empty it's probably an iterator or _, which shouldn't be replaced.
  =#
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
    outExp =
      map(outExp, (expArg) -> applyReplacements2(repl, expArg))
  end
  #=  Look up the replacement for the first part in the replacement tree.
  =#
  #=  If the cref consists of more than one identifier we need to look up
  =#
  #=  the corresponding record field in the expression.
  =#
  return outExp
end

function optimizeBody(body::Vector{Statement})
  body = Statement[map(s, optimizeStatement) for s in body]
  return body
end

function optimizeStatement(stmt::Statement)::Statement
  () = begin
    local iter_exp::Expression
    #=
    Replace iterators in for loops with mutable expressions, so we don't need
    to do it each time we enter a for loop during evaluation.
    =#
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
  local types::List{M_Type}
  local e::Expression
  if listLength(outputs) == 1
    exp = evalExp(ReplTree.get(repl, listHead(outputs)))
    assertAssignedOutput(listHead(outputs), exp)
  else
    expl = nil
    types = nil
    for o in outputs
      e = evalExp(ReplTree.get(repl, o))
      assertAssignedOutput(o, e)
      expl = Cons{Expression}(e, expl)
    end
    expl = listReverseInPlace(expl)
    types = list(typeOf(e) for e in expl)
    exp = TUPLE_EXPRESSION(TYPE_TUPLE(types, NONE()), expl)
  end
  return exp
end

function assertAssignedOutput(outputNode::InstNode, @nospecialize(value::Expression))
  return  () = begin
    @match value begin
      EMPTY_EXPRESSION(__) => begin
        Error.addSourceMessage(
          Error.UNASSIGNED_FUNCTION_OUTPUT,
          list(name(outputNode)),
          info(outputNode),
        )
        fail()
      end

      _ => begin
        ()
      end
    end
  end
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
  #=  adrpo: we really need some error handling here to detect which statement cannot be evaluated
  =#
  #=  try
  =#
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
        Error.assertion(
          false,
          getInstanceName() + " failed on " + anyString(stmt) + "\\n",
          sourceInfo(),
        )
        fail()
      end
    end
  end
  #= else
  =#
  #=    Error.assertion(false, getInstanceName() + \" failed to evaluate statement \" + Statement.toString(stmt) + \"\\n\", sourceInfo());
  =#
  #=    fail();
  =#
  #= end try;
  =#
  return ctrl
end

function evaluateAssignment(
  lhsExp::Expression,
  rhsExp::Expression,
  source::DAE.ElementSource,
)::FlowControlType
  local ctrl::FlowControlType = FlowControl.NEXT
  assignVariable(lhsExp, evalExp(rhsExp, EVALTARGET_STATEMENT(source)))
  return ctrl
end

function assignVariable(@nospecialize(variable::Expression), @nospecialize(value::Expression))
  return  () = begin
    local var::Expression
    local val::Expression
    local vals::List{Expression}
    local var_ptr::Pointer{Expression}
    #=  variable := value =#
    @match (variable, value) begin
      (MUTABLE_EXPRESSION(exp = var_ptr), _) => begin
        P_Pointer.update(var_ptr, assignExp(P_Pointer.access(var_ptr), value))
        ()
      end
      #=  (var1, var2, ...) := (value1, value2, ...) =#
      (TUPLE_EXPRESSION(__), TUPLE_EXPRESSION(elements = vals)) => begin
        for var in variable.elements
          @match _cons(val, vals) = vals
          assignVariable(var, val)
        end
        ()
      end

      (
        SUBSCRIPTED_EXP_EXPRESSION(
          exp = MUTABLE_EXPRESSION(exp = var_ptr),
        ),
        _,
      ) => begin
        #=  variable[subscript1, subscript2, ...] := value =#
        assignSubscriptedVariable(var_ptr, variable.subscripts, value)
        ()
      end

      (CREF_EXPRESSION(cref = WILD(__)), _) =>
        begin
          ()
        end

      _ => begin
        #=  _ := value
        =#
        Error.assertion(
          false,
          getInstanceName() +
          " failed on " +
          toString(variable) +
          " := " +
          toString(value),
          sourceInfo(),
        )
        fail()
      end
    end
  end
end

function assignSubscriptedVariable(
  variable::Pointer{<:Expression},
  subscripts::List{<:Subscript},
  value::Expression,
)
  local subs::List{Subscript}

  @assign subs = list(evalSubscript(s) for s in subscripts)
  return P_Pointer.update(variable, assignArrayElement(P_Pointer.access(variable), subs, value))
end

function assignArrayElement(
  arrayExp::Expression,
  subscripts::List{<:Subscript},
  value::Expression,
)::Expression
  local result::ARRAY_EXPRESSION
  local sub::Expression
  local val::Expression
  local rest_subs::List{Subscript}
  local idx::Int
  local subs
  local vals
  result = begin
    @match (arrayExp, subscripts) begin
      (
        ARRAY_EXPRESSION(__),
        SUBSCRIPT_INDEX(sub) <| rest_subs,
      ) where {(isScalarLiteral(sub))} => begin
        idx = toInteger(sub)
        arrayExpElements = arrayExp.elements
        if listEmpty(rest_subs)
          arrayExpElements[idx] = value # arrayExp.elements[idx] = value #ListUtil.set(arrayExp.elements, idx, value)
        else
          arrayExpElements[idx] = assignArrayElement(arrayExp.elements[idx], rest_subs, value) #Recheck this John
        end
        ARRAY_EXPRESSION(arrayExp.ty, arrayExpElements, arrayExp.literal)
      end

      (ARRAY_EXPRESSION(__), SUBSCRIPT_SLICE(sub) <| rest_subs) => begin
        local subsV = arrayElements(sub)
        local valsV = arrayElements(value)
        arrayExpElements = copy(arrayExp.elements)
        if listEmpty(rest_subs)
          for (i, s) in enumerate(subsV)
            idx = toInteger(s)
            arrayExpElements[idx] = valsV[i]
          end
        else
          for (i, s) in enumerate(subsV)
            idx = toInteger(s)
            arrayExpElements[idx] = assignArrayElement(arrayExpElements[idx], rest_subs, valsV[i])
          end
        end
        ARRAY_EXPRESSION(arrayExp.ty, arrayExpElements, arrayExp.literal)
      end

      (ARRAY_EXPRESSION(__), SUBSCRIPT_WHOLE(__) <| rest_subs) =>
        begin
          if listEmpty(rest_subs)
            arrayExpElements = arrayElements(value)
          else
            local valElems = arrayElements(value)
            arrayExpElements = Expression[assignArrayElement(e, rest_subs, valElems[i]) for (i, e) in enumerate(arrayExp.elements)]
          end
          ARRAY_EXPRESSION(arrayExp.ty, arrayExpElements, arrayExp.literal)
        end

      _ => begin
        Error.assertion(
          false,
          getInstanceName() +
          ": unimplemented case for " +
          toString(arrayExp) +
          toStringList(subscripts) +
          " = " +
          toString(value),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return result
end

function assignExp(@nospecialize(lhs::Expression), @nospecialize(rhs::Expression))::Expression
  local result::Expression
  result = begin
    @match lhs begin
      RECORD_EXPRESSION(__) => begin
        assignRecord(lhs, rhs)
      end

      _ => begin
        rhs
      end
    end
  end
  #=  TODO: Handle arrays.
  =#
  return result
end

function assignRecord(@nospecialize(lhs::Expression), @nospecialize(rhs::Expression))::Expression
  local result::Expression
  result = begin
    local elems::Vector{Expression}
    local e::Expression
    local val::Expression
    local cls_tree::ClassTree
    local comps::Vector{InstNode}
    local binding_exp::Option{Expression}
    local ty::M_Type
    @match rhs begin
      RECORD_EXPRESSION(__) => begin
        @match RECORD_EXPRESSION(elements = elems) = lhs
        for (i, v) in enumerate(rhs.elements)
          assignVariable(elems[i], v)
        end
        lhs
      end
      CREF_EXPRESSION(__) => begin
        @match RECORD_EXPRESSION(elements = elems) = lhs
        cls_tree =
          classTree(getClass(node(rhs.cref)))
        comps = getComponents(cls_tree)
        for (i, c) in enumerate(comps)
          e = elems[i]
          ty = getType(c)
          val = CREF_EXPRESSION(
            liftArrayLeftList(ty, arrayDims(rhs.ty)),
            prefixCref(c, ty, nil, rhs.cref),
          )
          assignVariable(e, val)
        end
        lhs
      end
      _ => begin
        rhs
      end
    end
  end
  return result
end

function evaluateFor(
  iterator::InstNode,
  range::Option{Expression},
  forBody::Vector{Statement},
  source::DAE.ElementSource,
)::FlowControlType
  local ctrl::FlowControlType = FlowControl.NEXT
  local range_iter::RangeIterator
  local iter_exp::Pointer{Expression}
  local range_exp::Expression
  local value::Expression
  local body::Vector{Statement} = forBody
  local i::Int = 0
  local limit::Int = Flags.getConfigInt(Flags.EVAL_LOOP_LIMIT)
  range_exp = evalExp(Util.getOption(range), EVALTARGET_STATEMENT(source))
  range_iter = RangeIterator_fromExp(range_exp)
    #=  Loop through each value in the iteration range. =#
  if hasNext(range_iter)
    @match EXP_NODE(exp = MUTABLE_EXPRESSION(exp = iter_exp)) =
      iterator
    while hasNext(range_iter)
      (range_iter, value) = next(range_iter)
      #=  Update the mutable expression with the iteration value and evaluate the statement. =#
      P_Pointer.update(iter_exp, value)
      ctrl = evaluateStatements(body)
      if ctrl != FlowControl.NEXT
        if ctrl == FlowControl.BREAK
          ctrl = FlowControl.NEXT
        end
        break
      end
      i = i + 1
      if i > limit
        Error.addSourceMessage(
          Error.EVAL_LOOP_LIMIT_REACHED,
          list(String(limit)),
          ElementSource_getInfo(source),
        )
        fail()
      end
    end
  end
  return ctrl
end

function evaluateIf(
  branches::Vector{Tuple{Expression, Vector{Statement}}},
  source::DAE.ElementSource,
)::FlowControlType
  local ctrl::FlowControlType
  local cond::Expression
  local body::Vector{Statement}
  for branch in branches
    (cond, body) = branch
    if isTrue(evalExp(cond, EVALTARGET_STATEMENT(DAE.emptyElementSource)))
      ctrl = evaluateStatements(body)
      return ctrl
    end
  end
  ctrl = FlowControl.NEXT
  return ctrl
end

"""
Evaluates assert statments
"""
function evaluateAssert(@nospecialize(condition::Expression), assertStmt::Statement)::FlowControlType
  local ctrl::FlowControlType = FlowControl.NEXT
  local cond::Expression
  local msg::Expression
  local lvl::Expression
  local source::DAE.ElementSource
  local target::EvalTarget = EVALTARGET_STATEMENT(DAE.emptyElementSource)#source(assertStmt))
  if isFalse(evalExp(condition, target))
    @match ALG_ASSERT(message = msg, level = lvl, source = source) =assertStmt
    msg = evalExp(msg, target)
    lvl = evalExp(lvl, target)
    () = begin
      @match (msg, lvl) begin
        (
          STRING_EXPRESSION(__),
          ENUM_LITERAL_EXPRESSION(name = "warning"),
        ) => begin
          Error.addSourceMessage(
            Error.ASSERT_TRIGGERED_WARNING,
            list(msg.value),
            ElementSource_getInfo(source),
          )
          ()
        end

        (
          STRING_EXPRESSION(__),
          ENUM_LITERAL_EXPRESSION(name = "error"),
        ) => begin
          Error.addSourceMessage(
            Error.ASSERT_TRIGGERED_ERROR,
            list(msg.value),
            ElementSource_getInfo(source),
          )
          ctrl = FlowControl.ASSERTION
          ()
        end
        _ => begin
          Error.assertion(
            false,
            getInstanceName() +
            " failed to evaluate assert(false, " +
            toString(msg) +
            ", " +
            toString(lvl) +
            ")",
            sourceInfo(),
          )
          fail()
        end
      end
    end
  end
  return ctrl
end

function evaluateNoRetCall(@nospecialize(callExp::Expression), source::DAE.ElementSource)::FlowControlType
  local ctrl::FlowControlType = FlowControl.NEXT

  evalExp(callExp, EVALTARGET_STATEMENT(source))
  return ctrl
end

function evaluateWhile(
  condition::Expression,
  body::Vector{Statement},
  source::DAE.ElementSource,
)::FlowControlType
  local ctrl::FlowControlType = FlowControl.NEXT

  local i::Int = 0
  local limit::Int = Flags.getConfigInt(Flags.EVAL_LOOP_LIMIT)
  local target::EvalTarget = EVALTARGET_STATEMENT(source)

  while isTrue(evalExp(condition, target))
    @assign ctrl = evaluateStatements(body)
    if ctrl != FlowControl.NEXT
      if ctrl == FlowControl.BREAK
        @assign ctrl = FlowControl.NEXT
      end
      break
    end
    @assign i = i + 1
    if i > limit
      Error.addSourceMessage(
        Error.EVAL_LOOP_LIMIT_REACHED,
        list(String(limit)),
        ElementSource_getInfo(source),
      )
      fail()
    end
  end
  return ctrl
end

function isKnownExternalFunc(name::String, ann::Option{<:SCode.Annotation})::Bool
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

function isKnownLibrary(extAnnotation::Option{<:SCode.Annotation})::Bool
  local isKnown::Bool = false

  local ann::SCode.Annotation
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
const FILE_TYPE_TYPE = TYPE_ENUMERATION(FILE_TYPE_PATH, FILE_TYPE_NAMES)::M_Type
const FILE_TYPE_LITERALS =
  list(
    ENUM_LITERAL_EXPRESSION{TYPE_ENUMERATION, String, Int64}(FILE_TYPE_TYPE, "NoFile", 1),
    ENUM_LITERAL_EXPRESSION{TYPE_ENUMERATION, String, Int64}(FILE_TYPE_TYPE, "RegularFile", 2),
    ENUM_LITERAL_EXPRESSION{TYPE_ENUMERATION, String, Int64}(FILE_TYPE_TYPE, "Directory", 3),
    ENUM_LITERAL_EXPRESSION{TYPE_ENUMERATION, String, Int64}(FILE_TYPE_TYPE, "SpecialFile", 4),
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
const COMPARE_TYPE = TYPE_ENUMERATION(COMPARE_PATH, COMPARE_NAMES)::M_Type
const COMPARE_LITERALS =
  list(
    ENUM_LITERAL_EXPRESSION{TYPE_ENUMERATION, String, Int64}(COMPARE_TYPE, "Less", 1),
    ENUM_LITERAL_EXPRESSION{TYPE_ENUMERATION, String, Int64}(COMPARE_TYPE, "Equal", 2),
    ENUM_LITERAL_EXPRESSION{TYPE_ENUMERATION, String, Int64}(COMPARE_TYPE, "Greater", 3),
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
          list(
            INTEGER_EXPRESSION(dims[1]),
            INTEGER_EXPRESSION(dims[2]),
          ),
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
        Error.assertion(
          false,
          getInstanceName() + ": failed to evaluate " + name,
          sourceInfo(),
        )
        fail()
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
  local strs_ty::M_Type
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
        Error.assertion(
          false,
          getInstanceName() +
          " failed on OpenModelica_regex" +
          ListUtil.toString(
            args,
            toString,
            "",
            "(",
            ", ",
            ")",
            true,
          ),
          sourceInfo(),
        )
        fail()
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
  local ty::M_Type

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
  fn::M_Function,
  args::List{<:Expression},
  extArgs::List{<:Expression},
)::Expression
  local result::Expression

  local repl::ReplTree.Tree
  local ext_args::List{Expression}

  @assign repl = createReplacements(fn, args)
  @assign ext_args = list(
    map(e, (subexp) -> applyReplacements2(repl, subexp))
    for e in extArgs
  )
  evaluateExternal3(name, ext_args)
  @assign result = createResult(repl, fn.outputs)
  return result
end

function evaluateExternal3(name::String, args::List{<:Expression})
  return  () = begin
    @match name begin
      "dgeev" => begin
        EvalFunctionExt.Lapack_dgeev(args)
        ()
      end

      "dgegv" => begin
        EvalFunctionExt.Lapack_dgegv(args)
        ()
      end

      "dgels" => begin
        EvalFunctionExt.Lapack_dgels(args)
        ()
      end

      "dgelsx" => begin
        EvalFunctionExt.Lapack_dgelsx(args)
        ()
      end

      "dgelsy" => begin
        EvalFunctionExt.Lapack_dgelsy(args)
        ()
      end

      "dgesv" => begin
        EvalFunctionExt.Lapack_dgesv(args)
        ()
      end

      "dgglse" => begin
        EvalFunctionExt.Lapack_dgglse(args)
        ()
      end

      "dgtsv" => begin
        EvalFunctionExt.Lapack_dgtsv(args)
        ()
      end

      "dgbsv" => begin
        EvalFunctionExt.Lapack_dgtsv(args)
        ()
      end

      "dgesvd" => begin
        EvalFunctionExt.Lapack_dgesvd(args)
        ()
      end

      "dgetrf" => begin
        EvalFunctionExt.Lapack_dgetrf(args)
        ()
      end

      "dgetrs" => begin
        EvalFunctionExt.Lapack_dgetrs(args)
        ()
      end

      "dgetri" => begin
        EvalFunctionExt.Lapack_dgetri(args)
        ()
      end

      "dgeqpf" => begin
        EvalFunctionExt.Lapack_dgeqpf(args)
        ()
      end

      "dorgqr" => begin
        EvalFunctionExt.Lapack_dorgqr(args)
        ()
      end
    end
  end
end

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

"""
```
evaluate(flatModel::FLAT_MODEL)
```

Evaluates the flat model.
Basically this routine does constant evaluations by resolving parts of the model that is known statically.
"""
function evaluate(flatModel::FLAT_MODEL)::FLAT_MODEL
  local const_var::VariabilityType = Variability.STRUCTURAL_PARAMETER
  @assign begin
    flatModel.variables = VARIABLE[evaluateVariable(v, const_var) for v in flatModel.variables]
    flatModel.initialEquations = evaluateEquations(flatModel.initialEquations, const_var)
    flatModel.equations = evaluateEquations(flatModel.equations, const_var)
    flatModel.algorithms = evaluateAlgorithms(flatModel.algorithms, const_var)
    flatModel.initialAlgorithms = evaluateAlgorithms(flatModel.initialAlgorithms, const_var)
  end
  return flatModel
end

function evaluateVariable(var::VARIABLE, constVariability::VariabilityType)::VARIABLE
  local binding::Binding
  binding = evaluateBinding(
    var.binding,
    variability(var) <= constVariability,
    constVariability,
    variability(var),
  )
  if !referenceEq(binding, var.binding)
    @assign var.binding = binding
  end
  #= Evaluate dimensions of the variable type (e.g. Real[dim1[1], dim1[2]] -> Real[3, 2]) =#
  @assign var.ty = mapDims(var.ty, evaluateDimension)
  @assign var.typeAttributes = [
    evaluateTypeAttribute(a, Variability.STRUCTURAL_PARAMETER) for a in var.typeAttributes
      ]
  return var
end

function evaluateBinding(
  binding::Binding,
  structural::Bool,
  constVariability::VariabilityType,
  variability::VariabilityType = Variability.CONSTANT,
)::Binding
  local exp::Expression
  local eexp::Expression
  if isBound(binding)
    exp = getTypedExp(binding)
    if structural
      #= A structural parameter not evaluated in earlier stages (Evaluate=true) is not critical
         to evaluate: kept as it is when it can't be (omc tryEvalExp; CevalBinding10, an external
         function). A constant must be. =#
      eexp = variability > Variability.CONSTANT ?
        tryEvalExp(exp, EVALTARGET_ATTRIBUTE(binding)) : evalExp(exp, EVALTARGET_ATTRIBUTE(binding))
    else
      eexp = evaluateExp(exp, constVariability)
    end
    if !referenceEq(exp, eexp)
      binding = setTypedExp(eexp, binding)
    end
  end
  return binding
end

function evaluateTypeAttribute(
  attribute::Tuple{<:String, Binding},
  constVariability::VariabilityType,
)::Tuple{String, Binding}
  local name::String
  local binding::Binding
  local sbinding::Binding
  local structural::Bool
   (name, binding) = attribute
  structural = name == "fixed" || name == "stateSelect"
  sbinding = evaluateBinding(binding, structural, constVariability)
  if !referenceEq(binding, sbinding)
    attribute = (name, sbinding)
  end
  return attribute
end

function evaluateExp(@nospecialize(exp::Expression), constVariability::VariabilityType)::Expression
  local outExp::Expression
  (outExp, _) = evaluateExpTraverser(exp, constVariability, false)
  return outExp
end

"""
omc EvalConstants evaluates a constant with a real target, so an unbound one is
UNBOUND_CONSTANT (Ceval.printUnboundError); here evaluation ignores Ceval errors, so that case
is checked on its own: a typed constant with no binding, not a record (whose fields may be
bound) nor a field of a component, and no start value.
"""
function checkConstantHasValue(cref::ComponentRef)
  isvariant(cref, COMPONENT_REF_CREF) || return nothing
  local n::InstNode = node(cref)
  isComponent(n) || return nothing
  #= A field of a component (a record instance) may get its value from the parent's binding
     (omc makeComponentBinding). =#
  (isvariant(cref.restCref, COMPONENT_REF_CREF) && isComponent(node(cref.restCref))) && return nothing
  local comp::Component = component(n)
  @match comp begin
    TYPED_COMPONENT(__) => ()
    _ => return nothing
  end
  isUnbound(getBinding(comp)) || return nothing
  isRecord(arrayElementType(getType(comp))) && return nothing
  Base.first(evalComponentStartBinding(n, comp, cref, EVALTARGET_IGNORE_ERRORS(), false)) && return nothing
  Error.addSourceMessage(Error.UNBOUND_CONSTANT, list(toString(cref)), InstNode_info(n))
  fail()
end

function evaluateExpTraverser(
  exp::Expression,
  constVariability::VariabilityType,
  changed::Bool,
)::Tuple{Expression, Bool}
  local outChanged::Bool
  local outExp::Expression
  local cref::ComponentRef
  local ty::ModelicaType
  outExp = begin
    @match exp begin
      CREF_EXPRESSION(__) => begin
        #@debug "Evaluate exp traverser"
        (outExp, outChanged) = mapFoldShallow(exp, (x, boolArg) -> evaluateExpTraverser(x, constVariability, boolArg), false)
        cref = outExp.cref
        ty = outExp.ty
        #=  Evaluate constants and structural parameters.=#
        if nodeVariability(cref) <= constVariability
          nodeVariability(cref) == Variability.CONSTANT && checkConstantHasValue(cref)
          local value::Expression = stripBindingInfo(evalCref(cref, outExp, EVALTARGET_IGNORE_ERRORS(),
                                                              evalSubscripts = false))
          #= Arrays kept: a parameter field of a component array read in its class (`res.dp_nominal_pos` in
             `res[3]`'s `dp = dp_nominal_pos * time`, typed Real) evaluates to the field over all the components
             (Real[3]), an operand of a different type than the operation was typed for. Kept as the reference,
             which the backend reads per element (a parameter stays in the flat model). Not in a scalarizing
             flatten: there the class is flattened per element, and the field's value over the components
             is the one structural sizes read (omc's CevalRecordArray9: `{i for i in layers.nSta}` over
             `layers.nLay`). =#
          if !Flags.isSet(Flags.FRONTEND_SCALARIZE) && nodeVariability(cref) > Variability.CONSTANT &&
             dimensionCount(value) > dimensionCount(ty)
            value = outExp
          end
          outExp = value
          outChanged = true
        elseif outChanged
          outExp = CREF_EXPRESSION(
            getSubscriptedType(cref),
            cref,
          )
        end
        #= Evaluate all constants and structural parameters.
           If the cref's subscripts changed, recalculate its type. =#
        outExp
      end
      _ => begin
        func = (@nospecialize(x::Expression), y::Bool) -> evaluateExpTraverser(x, constVariability, false)
        (outExp, outChanged) = mapFoldShallow(exp, func, false)
        if outChanged
          retype(outExp)
        else
          outExp
        end
      end
    end
  end
  outChanged = changed || outChanged
  return (outExp, outChanged)
end

function evaluateDimension(dim::Dimension)::Dimension
  local e::Expression
  @match dim begin
    DIMENSION_EXP(__) where {contains(dim.exp, isIterator)} => begin
      #= A dimension depending on a for-loop iterator (x[:, 1:i] in a for-equation): only its
         constants are evaluated (omc evaluateDimension; omc FuncBuiltinFill3). =#
      e = evaluateExp(dim.exp, Variability.STRUCTURAL_PARAMETER)
      if referenceEq(e, dim.exp)
        dim
      else
        fromExp(e, dim.var)
      end
    end

    DIMENSION_EXP(__) => begin
      e = evalExp(dim.exp, EVALTARGET_IGNORE_ERRORS())
      if referenceEq(e, dim.exp)
        dim
      else
        fromExp(e, dim.var)
      end
    end

    _ => dim
  end
end

function evaluateEquations(
  eql::Vector{Equation},
  constVariability::VariabilityType,
)
  local outEql = Equation[evaluateEquation(e, constVariability) for e in eql]
  return outEql
end

"""
Evaluates an equation.
Note that an optimization that can be done to this function is to instead use the inline map! functions defined in NFEquation.
"""
function evaluateEquation(@nospecialize(eq::Equation), constVariability::VariabilityType)::Equation
  eq = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local ty::ModelicaType
    @match eq begin
      EQUATION_EQUALITY(__) => begin
        local ty = mapDims(eq.ty, evaluateDimension)
        local e1 = evaluateExp(eq.lhs, constVariability)
        local e2 = evaluateExp(eq.rhs, constVariability)
        EQUATION_EQUALITY(e1, e2, ty, eq.source)
      end
      EQUATION_ARRAY_EQUALITY(__) => begin
        local ty = mapDims(eq.ty, evaluateDimension)
        local e2 = evaluateExp(eq.rhs, constVariability)
        local aeq = EQUATION_ARRAY_EQUALITY(eq.lhs, e2, ty, eq.source)
      end
      EQUATION_FOR(__) => begin
        local eqRange = Util.applyOption(
          eq.range,
          (x) -> evaluateExp(x, constVariability),
        )
        local eqBody = evaluateEquations(eq.body, constVariability)
        EQUATION_FOR(eq.iterator, eqRange, eqBody, eq.source)
      end
      EQUATION_IF(__) => begin
        local eqBranches = EquationBranch[evaluateEqBranch(b, constVariability) for b in eq.branches]
        EQUATION_IF(eqBranches, eq.source)
      end
      EQUATION_WHEN(__) => begin
        local eqBranches = EquationBranch[evaluateEqBranch(b, constVariability) for b in eq.branches]
        EQUATION_WHEN(eqBranches, eq.source)
      end
      EQUATION_ASSERT(__) => begin
        local e1 = evaluateExp(eq.condition, constVariability)
        local e2 = evaluateExp(eq.message, constVariability)
        local e3 = evaluateExp(eq.level, constVariability)
        EQUATION_ASSERT(e1, e2, e3, eq.source)
      end
      EQUATION_TERMINATE(__) => begin
        local eqMessage = evaluateExp(eq.message, constVariability)
        EQUATION_TERMINATE(eqMessage, eq.source)
      end
      EQUATION_REINIT(__) => begin
        local eqReinitExp = evaluateExp(eq.reinitExp, constVariability)
        EQUATION_REINIT(eq.cref, eqReinitExp, eq.source)
      end
      EQUATION_NORETCALL(__) => begin
        local eqExp = evaluateExp(eq.exp, constVariability)
        EQUATION_NORETCALL(eqExp, eq.source)
      end
      _ => eq
    end
  end
  return eq
end

function evaluateEqBranch(branch::EquationBranch, constVariability::VariabilityType)
  local outBranch::EquationBranch
  outBranch = begin
    local condition::Expression
    local body
    @match branch begin
      EQUATION_BRANCH(condition = condition, body = body) => begin
        condition = evaluateExp(condition, Variability.STRUCTURAL_PARAMETER)
        body = evaluateEquations(body, constVariability)
        EQUATION_BRANCH(condition, branch.conditionVar, body)
      end
      _ => branch
    end
  end
  return outBranch
end

function evaluateAlgorithms(
  algs::Vector{ALGORITHM},
  constVariability::VariabilityType,
)
  local outAlgs::Vector{ALGORITHM} = [evaluateAlgorithm(a, constVariability) for a in algs]
  return outAlgs
end

function evaluateAlgorithm(alg::ALGORITHM, constVariability::VariabilityType)
  @assign alg.statements = evaluateStatements(alg.statements, constVariability)
  return alg
end

function evaluateStatements(
  stmts::Vector{Statement},
  constVariability::VariabilityType,
  )
  local outStmts::Vector{Statement} = Statement[evaluateStatement(s, constVariability) for s in stmts]
  return outStmts
end

function evaluateStatement(stmt::Statement, constVariability::VariabilityType)::Statement
  stmt = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local ty::ModelicaType
    @match stmt begin
      ALG_ASSIGNMENT(__) => begin
        ty = mapDims(stmt.ty, evaluateDimension)
        e1 = evaluateExp(stmt.lhs, constVariability)
        e2 = evaluateExp(stmt.rhs, constVariability)
        ALG_ASSIGNMENT(e1, e2, ty, stmt.source)
      end

      ALG_FOR(__) => begin
        @assign stmt.range = Util.applyOption(
          stmt.range,
          (x) -> evaluateExp(x, constVariability),
        )
        @assign stmt.body = evaluateStatements(stmt.body, constVariability)
        stmt
      end

      ALG_IF(__) => begin
        @assign stmt.branches =
          Tuple{Expression, Vector{Statement}}[evaluateStmtBranch(b, constVariability) for b in stmt.branches]
        stmt
      end

      ALG_WHEN(__) => begin
        @assign stmt.branches =
          Tuple{Expression, Vector{Statement}}[evaluateStmtBranch(b, constVariability) for b in stmt.branches]
        stmt
      end

      ALG_ASSERT(__) => begin
        e1 = evaluateExp(stmt.condition, constVariability)
        e2 = evaluateExp(stmt.message, constVariability)
        e3 = evaluateExp(stmt.level, constVariability)
        ALG_ASSERT(e1, e2, e3, stmt.source)
      end

      ALG_TERMINATE(__) => begin
        @assign stmt.message = evaluateExp(stmt.message, constVariability)
        stmt
      end

      ALG_REINIT(__) => begin
        @assign stmt.reinitExp = evaluateExp(stmt.reinitExp, constVariability)
        stmt
      end

      ALG_NORETCALL(__) => begin
        @assign stmt.exp = evaluateExp(stmt.exp, constVariability)
        stmt
      end

      ALG_WHILE(__) => begin
        @assign stmt.condition = evaluateExp(stmt.condition, constVariability)
        @assign stmt.body = evaluateStatements(stmt.body, constVariability)
        stmt
      end
      _ => stmt
    end
  end
  return stmt
end

function evaluateStmtBranch(
  branch::Tuple{Expression, Vector{Statement}},
  constVariability::VariabilityType,
)::Tuple{Expression, Vector{Statement}}
  local outBranch::Tuple{Expression, Vector{Statement}}
  local cond::Expression
  local body::Vector{Statement}
  (cond, body) = branch
  cond = evaluateExp(cond, Variability.STRUCTURAL_PARAMETER)
  body = evaluateStatements(body, constVariability)
  outBranch = (cond, body)
  return outBranch
end

function evaluateFunction(func::MODELICA_FUNCTION)::MODELICA_FUNCTION
  if !isEvaluated(func)
    markEvaluated(func)
    local node::InstNode = func.node
    func = mapExp(func, (@nospecialize(x::Expression),) -> evaluateFuncExp(x, node))
    for fn_der in func.derivatives
      for der_fn in getCachedFuncs(fn_der.derivativeFn)
        evaluateFunction(der_fn)
      end
    end
  end
  return func
end

function evaluateFuncExp(@nospecialize(exp::Expression), fnNode::InstNode)::Expression
  local outExp::Expression
  (outExp, _) = evaluateFuncExpTraverser(exp, fnNode, false)
  return outExp
end

function evaluateFuncExpTraverser(
  exp::Expression,
  fnNode::InstNode,
  changed::Bool,
)::Tuple{Expression, Bool}
  local outChanged::Bool
  local outExp::Expression
  local e::Expression
  (e, outChanged) = mapFoldShallow(
    exp,
    (@nospecialize(x::Expression), y::Bool) -> evaluateFuncExpTraverser(x, fnNode, y),
    false,
  )
  outExp = begin
    @match e begin
      CREF_EXPRESSION(__) => begin
        if !isLocalFunctionVariable(e.cref, fnNode)
          outExp = evalCref(
            e.cref,
            e,
            EVALTARGET_IGNORE_ERRORS(),
            evalSubscripts = false,
          )
          outExp = stripBindingInfo(outExp)
          outChanged = true
        elseif outChanged
          #=  If the cref's subscripts changed, recalculate its type. =#
          outExp = CREF_EXPRESSION(
            getSubscriptedType(e.cref),
            e.cref,
          )
        else
          outExp = e
        end
        outExp
      end

      _ => begin
        if outChanged
          retype(e)
        else
          e
        end
      end
    end
  end
  outChanged = changed || outChanged
  return (outExp, outChanged)
end

function isLocalFunctionVariable(cref::ComponentRef, fnNode::InstNode)::Bool
  local res::Bool
  local nodeVar::InstNode
  if isPackageConstant(cref)
    res = false
  elseif nodeVariability(cref) <= Variability.PARAMETER
    nodeVar =
      derivedParent(node(firstNonScope(
        cref,
      )))
    res = refEqual(fnNode, nodeVar)
  else
    res = true
  end
  return res
end

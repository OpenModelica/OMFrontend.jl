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

const SimplifyFunc = Function
const MakeElement = Function
const MakeFunc = Function

function simplifyFlatModel(flatModel::FlatModel)::FlatModel
  @assign begin
    flatModel.variables = simplifyVariables(flatModel.variables)
    flatModel.equations = simplifyEquations(flatModel.equations)
    flatModel.initialEquations = simplifyEquations(flatModel.initialEquations)
    flatModel.algorithms = simplifyAlgorithms(flatModel.algorithms)
    flatModel.initialAlgorithms = simplifyAlgorithms(flatModel.initialAlgorithms)
  end
#  execStat(getInstanceName()) TODO
  return flatModel
end

function simplifyVariables(variables::Vector{Variable})
  for (i, v) in enumerate(variables)
    @inbounds variables[i] = simplifyVariable(v)
  end
  return variables
end

function simplifyVariable(var::Variable)::Variable
  varBinding = simplifyBinding(var.binding)
  varTypeAttributes = simplifyTypeAttributes(var.typeAttributes)
  VARIABLE(
    var.name,
    var.ty,
    varBinding,
    var.visibility,
    var.attributes,
    varTypeAttributes,
    var.comment,
    var.info
  )
end

function simplifyBinding(binding::Binding)
  local exp::Expression
  local sexp::Expression
  if isBound(binding)
    exp = getTypedExp(binding)
    sexp = simplify(exp)
    sexp = removeEmptyFunctionArguments(sexp)
    if !referenceEq(exp, sexp)
      binding = setTypedExp(sexp, binding)
    end
  end
  return binding
end

function simplifyTypeAttributes(typeAttributes)
  for (i, a) in enumerate(typeAttributes)
    @inbounds typeAttributes[i] = simplifyTypeAttribute(a)
  end
  return typeAttributes
end

function simplifyTypeAttribute(attribute::Tuple{<:String, Binding})::Tuple{String, Binding}
  local name::String
  local binding::Binding
  local sbinding::Binding
  (name, binding) = attribute
  sbinding = simplifyBinding(binding)
  if !referenceEq(binding, sbinding)
    attribute = (name, sbinding)
  end
  return attribute
end

function simplifyDimension(dim::Dimension)::Dimension
  local outDim::Dimension

  @assign outDim = begin
    local e::Expression
    @match dim begin
      DIMENSION_EXP(__) => begin
        @assign e = simplify(dim.exp)
        if referenceEq(e, dim.exp)
          dim
        else
          fromExp(e, dim.var)
        end
      end
      _ => begin
        dim
      end
    end
  end
  return outDim
end

function simplifyEquations(eql::Vector{<:Equation})
  local outEql::Vector{Equation} = Equation[]
  for eq in eql
    outEql = simplifyEquation(eq, outEql)
  end
  outEql = outEql
  return outEql
end


function simplifyBranch(b)
  @match b begin
    EQUATION_BRANCH(__) => begin
      @assign b.condition = simplify(b.condition)
      @assign b.body = simplifyEquations(b.body)
      b
    end
  end
end

function simplifyEquation(@nospecialize(eq::Equation), equations::Vector{Equation})
  #@info "Called simplify equation for" toString(eq)
  equations = begin
    local e::Expression
    local lhs::Expression
    local rhs::Expression
    local ty::M_Type
    @match eq begin
      EQUATION_EQUALITY(__) => begin
        simplifyEqualityEquation(eq, equations)
      end

      EQUATION_ARRAY_EQUALITY(__) => begin
        @assign ty = mapDims(eq.ty, simplifyDimension)
        if !isEmptyArray(ty)
          rhs = simplify(eq.rhs)
          rhs = removeEmptyFunctionArguments(rhs)
          push!(equations,
                EQUATION_ARRAY_EQUALITY(eq.lhs, rhs, ty, eq.source))
        end
        equations
      end

      EQUATION_FOR(SOME(e)) => begin
        body = simplifyEquations(eq.body)
        if ! containsExpList(body, (x) -> containsIterator(x, eq.iterator))
          # Remove the surrounding loop if the equations inside aren't using the iterator.
          equations = ArrayUtil.append_reverse(body, equations)
        else
          @assign eq.range = simplifyOpt(eq.range)
          @assign eq.body = body
          push!(equations, eq)
        end
      end

      EQUATION_IF(__) => begin
        simplifyIfEqBranches(eq.branches, eq.source, equations)
      end

      EQUATION_WHEN(__) => begin
        @assign eq.branches = Equation_Branch[simplifyBranch(b) for b in eq.branches]
        push!(equations, eq)
      end

      EQUATION_ASSERT(__) => begin
        @assign eq.condition = simplify(eq.condition)
        if isTrue(eq.condition)
          equations
        else
          push!(equations, eq)
        end
      end

      EQUATION_REINIT(__) => begin
        @assign eq.reinitExp = simplify(eq.reinitExp)
        push!(equations, eq)
      end

      EQUATION_NORETCALL(__) => begin
        e = simplify(eq.exp)
        if isCall(e)
          @assign eq.exp = removeEmptyFunctionArguments(e)
          push!(equations, eq)
        end
        equations
      end

      _ => begin
        push!(equations, eq)
      end
    end
  end
  return equations
end

function simplifyEqualityEquation(eq::EQUATION_EQUALITY, equations::Vector{Equation})
  local lhs::Expression
  local rhs::Expression
  local ty::M_Type
  local src::DAE.ElementSource
  #@info "Simplify equality equation..." toString(eq)
  if typeof(eq.rhs) == ARRAY_EXPRESSION
    #= If it is an empty array we have no eq to compute. =#
    if isEmptyArray(eq.rhs)
      return equations
    end
  end
  @match EQUATION_EQUALITY(lhs = lhs, rhs = rhs, ty = ty, source = src) = eq
  ty = mapDims(ty, simplifyDimension)
  if isEmptyArray(ty)
    return equations
  end
  lhs = simplify(lhs)
  lhs = removeEmptyTupleElements(lhs)
  rhs = simplify(rhs)
  rhs = removeEmptyFunctionArguments(rhs)
  equations = begin
    @match (lhs, rhs) begin
      (TUPLE_EXPRESSION(__), TUPLE_EXPRESSION(__)) => begin
        simplifyTupleElement(
          lhs.elements,
          rhs.elements,
          ty,
          src,
          makeEquality,
          equations,
        )
      end

      _ => begin
        push!(equations, EQUATION_EQUALITY(lhs, rhs, ty, src))
      end
    end
  end
  return equations
end

function simplifyAlgorithms(algs::Vector{Algorithm})
  local outAlgs::Vector{Algorithm} = Algorithm[]
  for alg in algs
    alg = simplifyAlgorithm(alg)
    if !isempty(alg.statements)
      push!(outAlgs, alg)
    end
  end
  return outAlgs
end

function simplifyAlgorithm(alg::Algorithm)::Algorithm

  @assign alg.statements = simplifyStatements(alg.statements)
  return alg
end

function simplifyStatements(stmts::Vector{Statement})
  local outStmts::Vector{Statement} = Statement[]
  for s in stmts
    outStmts = simplifyStatement(s, outStmts)
  end
  return outStmts
end

function simplifyStatement(stmt::Statement, statements::Vector{Statement})
  statements = begin
    local e::Expression
    local lhs::Expression
    local rhs::Expression
    local ty::M_Type
    local dim::Dimension
    local body::Vector{Statement}
    @match stmt begin
      ALG_ASSIGNMENT(__) => begin
        simplifyAssignment(stmt, statements)
      end
      ALG_FOR(range = SOME(e)) => begin
        ty = typeOf(e)
        dim = nthDimension(ty, 1)
        if !isZero(dim)
          @assign stmt.range = SOME(simplify(e))
          @assign stmt.body = simplifyStatements(stmt.body)
          push!(statements, stmt)
        end
        statements
      end
      ALG_IF(__) => begin
        simplifyIfStmtBranches(
          stmt.branches,
          stmt.source,
          makeIf,
          simplifyStatements,
          statements,
        )
      end
      ALG_WHEN(__) => begin
        @assign stmt.branches = [
          (simplify(Util.tuple21(b)), simplifyStatements(Util.tuple22(b))) for b in stmt.branches
            ]
        push!(statements, stmt)
      end
      ALG_NORETCALL(__) => begin
        e = simplify(stmt.exp)
        if isCall(e)
          @assign stmt.exp = removeEmptyFunctionArguments(e)
          push!(statements, stmt)
        end
        statements
      end
      _ => begin
        push!(statements, stmt)
      end
    end
  end
  return statements
end

function simplifyAssignment(stmt::Statement, statements::Vector{Statement})
  local lhs::Expression
  local rhs::Expression
  local rhs_exp::Expression
  local rhs_rest::List{Expression}
  local ty::M_Type
  local src::DAE.ElementSource
  @match ALG_ASSIGNMENT(lhs = lhs, rhs = rhs, ty = ty, source = src) = stmt
  ty = mapDims(ty, simplifyDimension)
  if isEmptyArray(ty)
    return statements
  end
  lhs = simplify(lhs)
  lhs = removeEmptyTupleElements(lhs)
  rhs = simplify(rhs)
  rhs = removeEmptyFunctionArguments(rhs)
  statements = begin
    @match (lhs, rhs) begin
      (TUPLE_EXPRESSION(__), TUPLE_EXPRESSION(__)) => begin
        simplifyTupleElement(
          lhs.elements,
          rhs.elements,
          ty,
          src,
          makeAssignment,
          statements,
        )
      end
      _ => begin
        push!(statements, ALG_ASSIGNMENT(lhs, rhs, ty, src))
      end
    end
  end
  return statements
end

"""
   Helper function to simplifyEqualityEquation/simplifyAssignment.
   Handles Expression.TUPLE() := Expression.TUPLE() assignments by splitting
   them into a separate assignment statement for each pair of tuple elements.
"""
function simplifyTupleElement(
  lhsTuple::List{Expression},
  rhsTuple::List{Expression},
  ty::M_Type,
  src::DAE.ElementSource,
  makeFn::MakeElement,
  statements::Vector{Statement},
)
  local rhs::Expression
  local rest_rhs::List{Expression} = rhsTuple
  local ety::M_Type
  local rest_ty::List{M_Type}
  @match TYPE_TUPLE(types = rest_ty) = ty
  for lhs in lhsTuple
    @match _cons(rhs, rest_rhs) = rest_rhs
    @match _cons(ety, rest_ty) = rest_ty
    if !isWildCref(lhs)
      push!(statements, makeFn(lhs, rhs, ety, src))
    end
  end
  return statements
end

"""Replaces tuple elements that has one or more zero dimension with _."""
function removeEmptyTupleElements(exp::Expression)
  local tyl::List{M_Type}
  local rExp
  rExp = @match exp begin
    TUPLE_EXPRESSION(ty = TYPE_TUPLE(types = tyl)) => begin
      local expElements = list(@do_threaded_for if isEmptyArray(t)
                                 CREF_EXPRESSION(t, COMPONENT_REF_WILD())
                               else
                                 e
                               end (e, t) (exp.elements, tyl))
      TUPLE_EXPRESSION(exp.ty, expElements)
    end
    _ => begin
      exp
    end
  end
  return rExp
end

function removeEmptyFunctionArguments(@nospecialize(exp::Expression), isArg = false)
  local outExp::Expression
  local is_arg::Bool
  if isArg
    @match exp begin
      CREF_EXPRESSION(__) where {isEmptyArray(exp.ty)} => begin
        outExp = fillType(exp.ty, INTEGER_EXPRESSION(0))
      end
      _ => begin
        ()
      end
    end
  end
  is_arg = isArg || isCall(exp)
  outExp = mapShallow(exp, (x) -> removeEmptyFunctionArguments(x, is_arg))
  return outExp
end

function simplifyIfEqBranches(
  branches::Vector{Equation_Branch},
  src::DAE.ElementSource,
  elements::Vector{Equation},
)::Vector{Equation}
  local cond::Expression
  local body::Vector{Equation}
  local var::VariabilityType
  local accum::Vector{Equation_Branch} = Equation_Branch[]
  for branch in branches
    accum = begin
      @match branch begin
        EQUATION_BRANCH(cond, var, body) => begin
          cond = simplify(cond)
          #=  A branch with condition true will always be selected when encountered. =#
          if isTrue(cond)
            if isempty(accum)
              for eq in body
                elements = simplifyEquation(eq, elements)
              end
              return elements
            else
              accum = push!(accum, makeBranch(cond, simplifyEquations(body)))
              elements = push!(
                elements,
                makeIf(accum, src)
              )
              return elements
            end
          elseif !isFalse(cond)
            @assign accum = push!(accum, makeBranch(cond, simplifyEquations(body)))
          end
          #=  If it's the first branch, remove the if and keep only the branch body.
          =#
          #=  Otherwise just discard the rest of the branches.
          =#
          #=  Keep branches that are neither literal true or false.
          =#
          accum
        end
        EQUATION_INVALID_BRANCH(
          branch = EQUATION_BRANCH(
            condition = cond,
            conditionVar = var,
          ),
        ) => begin
          if var <= Variability.STRUCTURAL_PARAMETER
            @assign cond = evalExp(cond)
          end
          #=  An invalid branch that can't be removed will trigger the errors
          =#
          #=  stored in it.
          =#
          if !isFalse(cond)
            triggerErrors(branch)
          end
          accum
        end

        _ => begin
          push!(accum, branch)
        end
      end
    end
  end
  if !isempty(accum)
    push!(elements, makeIf(accum, src))
  end
  return elements
end

"""
Note possible recheck to make sure the order is right
"""
function simplifyIfStmtBranches(
  branches::Vector{Tuple{Expression, Vector{Statement}}},
  src::DAE.ElementSource,
  makeFunc::MakeFunc,
  simplifyFunc::SimplifyFunc,
  elements::Vector{Statement},
)
  local cond::Expression
  local body::Vector{Statement}
  local accum = Tuple{Expression, Vector{Statement}}[]
  for branch in branches
    (cond, body) = branch
    cond = simplify(cond)
    #=  A branch with condition true will always be selected when encountered. =#
    if isTrue(cond)
      #=  If it's the first branch, remove the if and keep only the branch body. =#
      if isempty(accum)
        append!(simplifyFunc(body), elements)
        return elements
      else   #=  Keep branches that are neither literal true or false. =#
        push!(accum, (cond, simplifyFunc(body)))
        break
      end
    elseif !isFalse(cond)
      push!(accum, (cond, simplifyFunc(body)))
    end
  end
  #=  Otherwise just discard the rest of the branches. =#
  if !isempty(accum)
    push!(elements, makeFunc(accum, src))
  end
  return elements
end

function simplifyFunction(func::M_Function)
  local cls::Class
  local fn_body::Algorithm
  local sections::Sections
  return if !isSimplified(func)
    markSimplified(func)
    mapExp(func, simplify, false)
    cls = getClass(func.node)
    () = begin
      @match cls begin
        INSTANCED_CLASS(sections = sections) => begin
          () = begin
            @match sections begin
              SECTIONS(algorithms = [fn_body]) => begin
                @assign fn_body.statements = simplifyStatements(fn_body.statements)
                @assign sections.algorithms = [fn_body]
                @assign cls.sections = sections
                updateClass(cls, func.node)
                ()
              end

              _ => begin
                ()
              end
            end
          end
          ()
        end
        _ => begin
          ()
        end
      end
    end
    for fn_der in func.derivatives
      for der_fn in getCachedFuncs(fn_der.derivativeFn)
        simplifyFunction(der_fn)
      end
    end
  end
end

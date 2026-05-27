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

function scalarize(flatModel::FlatModel, name::String)::FlatModel
  local vars::Vector{Variable} = Variable[]
  for v in flatModel.variables
    scalarizeVariable(v, vars)
  end
  local equations = scalarizeEquations(mapExpList(flatModel.equations, expandComplexCref))
  local initialEquations = scalarizeEquations(mapExpList(flatModel.initialEquations, expandComplexCref))
  local algorithms = Algorithm[scalarizeAlgorithm(a) for a in flatModel.algorithms]
  local initialAlgorithms = Algorithm[scalarizeAlgorithm(a) for a in flatModel.initialAlgorithms]
  @assign begin
    flatModel.variables = vars
    flatModel.equations = equations
    flatModel.initialEquations = initialEquations
    flatModel.algorithms = algorithms
    flatModel.initialAlgorithms = initialAlgorithms
  end
  #execStat(getInstanceName() + "(" + name + ")")
  return flatModel
end

function scalarizeVariable(var::Variable, vars::Vector{Variable})
  local name::ComponentRef
  local binding::Binding
  local ty::M_Type
  local vis::VisibilityType
  local attr::Attributes
  local ty_attr::Vector{Tuple{String, Binding}}
  local cmt::Option{SCode.Comment}
  local info::SourceInfo
  local binding_iter::ExpressionIterator
  local crefs::List{ComponentRef}
  local exp::Expression
  local v::Variable
  local ty_attr_names::Vector{String}
  local ty_attr_iters::Vector{ExpressionIterator}
  local bind_var::VariabilityType
  if isArray(var.ty) && hasKnownSize(var.ty)
    #= Skip zero-size array variables entirely =#
    if isEmptyArray(var.ty)
      return vars
    end
    try
      @match VARIABLE(
        name,
        ty,
        binding,
        vis,
        attr,
        ty_attr,
        cmt,
        info,
      ) = var
      crefs = scalarize(name)
      if listEmpty(crefs)
        return vars
      end
      ty = arrayElementType(ty)
      (ty_attr_names, ty_attr_iters) = scalarizeTypeAttributes(ty_attr)
      #= Addition by me //John =#
      if isBound(binding)
        #        @info "bound" toString(binding)
        binding_iter = fromExpToExpressionIterator(expandComplexCref(getTypedExp(binding)))
        bind_var = variability(binding)
        #= Some other checks in omc currently... =#
        for cr in crefs
          #@info "Looping..."
          if hasNext(binding_iter)
            #@info "Had next"
            (binding_iter, exp) = next(binding_iter)
            binding = FLAT_BINDING(exp, bind_var)
            ty_attr = nextTypeAttributes(ty_attr_names, ty_attr_iters)
            push!(
              vars,
              VARIABLE(cr, ty, binding, vis, attr, ty_attr, cmt, info)
            )
          else #= Did not have a next =#
            # push!(
            #   vars,
            #   VARIABLE(cr, ty, binding, vis, attr, ty_attr, cmt, info)
            # )
          end
        end
      else
        for cr in crefs
          ty_attr = nextTypeAttributes(ty_attr_names, ty_attr_iters)
          push!(vars,
                VARIABLE(cr, ty, binding, vis, attr, ty_attr, cmt, info))
        end
      end
    catch e
      Error.assertion(
        false,
        getInstanceName() +
          " failed on " +
          toString(var, "", true),
        var.info,
      )
    end
  else
    local res
    res = mapExp(var.binding, expandComplexCref_traverser)
    @assign var.binding = res
    push!(vars, var)
  end
  #@info "Scalarize var res:" toString(vars)
  return vars
end

function scalarizeTypeAttributes(attrs::Vector{Tuple{String, Binding}},
  )
  local iters::Vector{ExpressionIterator}
  local names::Vector{String} = String[]
  local len::Int
  local i::Int
  local name::String
  local binding::Binding
  len = length(attrs)
  iters = arrayCreateNoInit(len, EXPRESSION_NONE_ITERATOR())
  i = len
  for attr in attrs
    (name, binding) = attr
    pushfirst!(names, name)
    iters[i] = fromBinding(binding)
    i = i - 1
  end
  return (names, iters)
end

function nextTypeAttributes(
  names::Vector{String},
  iters::Vector{ExpressionIterator},
)::Vector{Tuple{String, Binding}}
  local attrs = Tuple{String, Binding}[]
  local i::Int = 1
  local iter::ExpressionIterator
  local exp::Expression
  for name in names
    (iter, exp) = next(iters[i])
    iters[i] = iter
    i = i + 1
    attrs = push!(attrs, (name, FLAT_BINDING(exp, Variability.PARAMETER)))
  end
  return attrs
end

function expandComplexCref(exp::Expression)
  exp = map(exp, expandComplexCref_traverser)
  return exp
end


function expandComplexCref_traverser(exp::Expression)
  @match exp begin
    CREF_EXPRESSION(ty = TYPE_ARRAY(__)) => begin
      #=  Expand crefs where any of the prefix nodes are arrays. For example if
      =#
      #=  b in a.b.c is SomeType[2] we expand it into {a.b[1].c, a.b[2].c}.
      =#
      #=  TODO: This is only done due to backend issues and shouldn't be
      =#
      #=        necessary.
      =#
      if isComplexArray(exp.cref)
        @match (exp, _) = expand(exp)
      end

    end
    _ => begin
    end
  end
  return exp
end

function scalarizeEquations(eql::Vector{Equation})
  local equations::Vector{Equation} = Equation[]
  for eq in eql
    equations = scalarizeEquation(eq, equations)
  end
  return equations
end

function scalarizeEquation(@nospecialize(eq::Equation), equations::Vector{Equation})
  #= Expand record-typed equations to field-level equations.
     For CREF = CREF: expand both sides to their record fields.
     For CREF = CALL (function returning record): keep as record-level. =#
  if eq isa EQUATION_EQUALITY && isComplex(eq.ty)
    local rec_lhs = eq.lhs
    local rec_rhs = eq.rhs
    local lhs_expandable = rec_lhs isa CREF_EXPRESSION || rec_lhs isa RECORD_EXPRESSION
    local rhs_expandable = rec_rhs isa CREF_EXPRESSION || rec_rhs isa RECORD_EXPRESSION
    if lhs_expandable && rhs_expandable
      @match TYPE_COMPLEX(cls = rec_cls) = eq.ty
      local rec_comps::Vector{InstNode} = getComponents(classTree(getClass(rec_cls)))
      for (i, comp) in enumerate(rec_comps)
        local fty = getType(comp)
        local flhs = if rec_lhs isa CREF_EXPRESSION
          CREF_EXPRESSION(fty, prefixCref(comp, fty, nil, rec_lhs.cref))
        else
          rec_lhs.elements[i]
        end
        local frhs = if rec_rhs isa CREF_EXPRESSION
          CREF_EXPRESSION(fty, prefixCref(comp, fty, nil, rec_rhs.cref))
        else
          rec_rhs.elements[i]
        end
        local feq = EQUATION_EQUALITY(flhs, frhs, fty, eq.source)
        equations = scalarizeEquation(feq, equations)
      end
      return equations
    else
      push!(equations, eq)
      return equations
    end
  end
  #= Pre-process: try to expand EQUATION_ARRAY_EQUALITY with TYPED_ARRAY_CONSTRUCTOR
     before the @match block, since Revise cannot update @match cases. =#
  if eq isa EQUATION_ARRAY_EQUALITY
    local _expanded = tryExpandArrayEqualityToScalar(eq)
    if _expanded !== nothing
      for _eq in _expanded
        equations = scalarizeEquation(_eq, equations)
      end
      return equations
    end
  end
  equations = begin
    local lhs_iter::ExpressionIterator
    local rhs_iter::ExpressionIterator
    local lhs::Expression
    local rhs::Expression
    local ty::M_Type
    local src::DAE.ElementSource
    local info::SourceInfo
    @match eq begin

      EQUATION_EQUALITY(
        lhs,
        rhs,
        ty,
        src,
      ) where{isArray(ty)} => begin

        local lhs = eq.lhs
      if hasArrayCall(lhs) || hasArrayCall(rhs)
        #= Try to expand array comprehensions/calls before giving up.
           expand() handles TYPED_ARRAY_CONSTRUCTOR and broadcasts. =#
        local _exp_ok = true
        local _exp_lhs = lhs
        local _exp_rhs = eq.rhs
        try
          (_exp_lhs, _) = expand(lhs)
          (_exp_rhs, _) = expand(eq.rhs)
        catch
          _exp_ok = false
        end
        if !_exp_ok
          equations = push!(equations, EQUATION_ARRAY_EQUALITY(lhs, eq.rhs, ty, src))
          return equations
        end
        lhs_iter = fromExpToExpressionIterator(_exp_lhs)
        rhs_iter = fromExpToExpressionIterator(_exp_rhs)
      else
        lhs_iter = fromExpToExpressionIterator(lhs)
        rhs_iter = fromExpToExpressionIterator(rhs)
        #= If the RHS cannot be expanded into elements (e.g. arithmetic over
           array slices like 0.5*(rhos[1:1]+rhos[2:2])), keep the equation
           as an array equality for the backend to handle. =#
        if !hasNext(rhs_iter) && hasNext(lhs_iter)
          equations = push!(equations, EQUATION_ARRAY_EQUALITY(eq.lhs, eq.rhs, eq.ty, src))
          return equations
        end
      end
      local rhs_is_scalar = !isArray(typeOf(eq.rhs))
      local scalar_rhs::Expression = eq.rhs
      ty = arrayElementType(ty)
      while hasNext(lhs_iter)
        if !hasNext(rhs_iter)
          if rhs_is_scalar
            #= Scalar RHS broadcast to all LHS elements =#
            (lhs_iter, lhs) = next(lhs_iter)
            equations = scalarizeEquation(EQUATION_EQUALITY(lhs, scalar_rhs, ty, src), equations)
            continue
          end
          local msg = string(" could not expand rhs " + toString(eq.rhs) * " to match " * toString(eq.lhs),
                             " rhs type was: $(toString(eq.ty)) & lhs type was: $(toString(eq.ty))")
          @info "scalarizeEquation: RHS exhausted before LHS" toString(eq.lhs) toString(eq.rhs) toString(eq.ty)
          Error.addInternalError(
            getInstanceName() +
              msg,
            src.info,
          )
          fail()
        end
        (lhs_iter, lhs) = next(lhs_iter)
        (rhs_iter, rhs) = next(rhs_iter)
        equations = scalarizeEquation(EQUATION_EQUALITY(lhs, rhs, ty, src), equations)
      end
      equations
      end
      EQUATION_ARRAY_EQUALITY(
        CREF_EXPRESSION(__),
        rhs,
        ty,
        src) where{isArray(ty) && (isArray(eq.rhs) || isArray(eq.lhs))} => begin
          local lhs = eq.lhs
          if hasArrayCall(lhs) || hasArrayCall(rhs)
            equations = push!(equations, EQUATION_ARRAY_EQUALITY(lhs, rhs, ty, src))
          else
            lhs_iter = fromExpToExpressionIterator(lhs)
            rhs_iter = fromExpToExpressionIterator(rhs)
            ty = arrayElementType(ty)
            while hasNext(lhs_iter)
              if !hasNext(rhs_iter)
                local msg =   string(" could not expand rhs " + toString(eq.rhs) * " to match " * toString(eq.lhs),
                                     " rhs type was: $(toString(rhs.ty)) & lhs type was: $(toString(lhs.ty)). Full Equation: $(toString(eq))")
                Error.addInternalError(
                  getInstanceName() +
                    msg,
                  src.info,
                )
                fail()
              end
              (lhs_iter, lhs) = next(lhs_iter)
              (rhs_iter, rhs) = next(rhs_iter)
              local arrEq = EQUATION_EQUALITY(lhs, rhs, ty, src)
              equations = push!(equations, arrEq)
            end
          end
          equations

        end

      EQUATION_ARRAY_EQUALITY(CREF_EXPRESSION(__), CALL_EXPRESSION(call), TYPE_ARRAY(__))  where {call isa TYPED_ARRAY_CONSTRUCTOR}=> begin
        local newExp = tryEvalExp(eq.rhs)
        local aeq = EQUATION_ARRAY_EQUALITY(eq.lhs, newExp, eq.ty, eq.source)
        push!(equations, aeq)
      end

      EQUATION_ARRAY_EQUALITY(__) => begin
        #= Try to expand/eval and scalarize before falling through. =#
        try
          local _aexp_lhs = tryEvalExp(eq.lhs)
          local _aexp_rhs = tryEvalExp(eq.rhs)
          (_aexp_lhs, _) = expand(_aexp_lhs)
          (_aexp_rhs, _) = expand(_aexp_rhs)
          local _a_lhs_iter = fromExpToExpressionIterator(_aexp_lhs)
          local _a_rhs_iter = fromExpToExpressionIterator(_aexp_rhs)
          if hasNext(_a_lhs_iter) && hasNext(_a_rhs_iter)
            local _a_ty = arrayElementType(eq.ty)
            while hasNext(_a_lhs_iter) && hasNext(_a_rhs_iter)
              (_a_lhs_iter, lhs) = next(_a_lhs_iter)
              (_a_rhs_iter, rhs) = next(_a_rhs_iter)
              equations = scalarizeEquation(EQUATION_EQUALITY(lhs, rhs, _a_ty, eq.source), equations)
            end
            return equations
          end
        catch _aexp_err
          #= Expansion failed; keep as array equality for toFlatStream. =#
        end
        push!(equations, EQUATION_ARRAY_EQUALITY(eq.lhs, eq.rhs, eq.ty, eq.source))
      end

      EQUATION_CONNECT(__) => begin
        equations
      end

      EQUATION_IF(__) => begin
        scalarizeIfEquation(eq.branches, eq.source, equations)
      end

      EQUATION_WHEN(__) => begin
        scalarizeWhenEquation(eq.branches, eq.source, equations)
      end

      _ => begin
        push!(equations, eq)
      end
    end
  end
  return equations
end

"""
Remove branches with no equations after scalarization.
Add the scalarized if equation to the list of equations unless we don't
have any branches left.
"""
function scalarizeIfEquation(
  branches::Vector{Equation_Branch},
  source::DAE.ElementSource,
  equations::Vector{Equation},
)
  local bl::Vector{Equation_Branch} = Equation_Branch[]
  local cond::Expression
  local body::Vector{Equation}
  local var::VariabilityType
  for b in branches
    @match EQUATION_BRANCH(cond, var, body) = b
    body = scalarizeEquations(body)
    if !isempty(body)
      push!(bl, makeBranch(cond, body, var))
    end
  end
  if !isempty(bl)
    push!(equations, EQUATION_IF(bl, source))
  end
  return equations
end

function scalarizeWhenEquation(
  branches::Vector{Equation_Branch},
  source::DAE.ElementSource,
  equations::Vector{Equation},
  )
  local bl::Vector{Equation_Branch} = Equation_Branch[]
  local cond::Expression
  local body::Vector{Equation}
  local var::VariabilityType
  for b in branches
    @match EQUATION_BRANCH(cond, var, body) = b
    body = scalarizeEquations(body)
    if isArray(typeOf(cond))
      (cond, _) = expand(cond)
    end
    push!(bl, makeBranch(cond, body, var))
  end
  push!(equations, EQUATION_WHEN(bl, source))
  return equations
end

function scalarizeAlgorithm(alg::Algorithm)::Algorithm
  @assign alg.statements = scalarizeStatements(alg.statements)
  return alg
end

function scalarizeStatements(stmts::Vector{Statement})
  local statements::Vector{Statement} = Statement[]
  for s in stmts
    statements = scalarizeStatement(s, statements)
  end
  statements = statements
  return statements
end

function scalarizeStatement(stmt::Statement, statements::Vector{Statement})
  statements = begin
    @match stmt begin
      ALG_FOR(__) => begin
        push!(
          statements,
          ALG_FOR(
            stmt.iterator,
            stmt.range,
            scalarizeStatements(stmt.body),
            stmt.source,
          ),
        )
      end
      ALG_IF(__) => begin
        scalarizeIfStatement(stmt.branches, stmt.source, statements)
      end
      ALG_WHEN(__) => begin
        scalarizeWhenStatement(stmt.branches, stmt.source, statements)
      end
      ALG_WHILE(__) => begin
        push!(
          statements,
          ALG_WHILE(
            stmt.condition,
            scalarizeStatements(stmt.body),
            stmt.source,
          ),
        )
      end
      _ => begin
        push!(statements, stmt)#_cons(stmt, statements)
      end
    end
  end
  return statements
end

function scalarizeIfStatement(
  branches::Vector{Tuple{Expression, Vector{Statement}}},
  source::DAE.ElementSource,
  statements::Vector{Statement},
)
  local bl::Vector{Tuple{Expression, Vector{Statement}}} = Tuple{Expression, Vector{Statement}}[]
  local cond::Expression
  local body::Vector{Statement}
  for b in branches
    (cond, body) = b
    body = scalarizeStatements(body)
    if !isempty(body)
      push!(bl, (cond, body))
    end
  end
  #=  Remove branches with no statements after scalarization.
  =#
  #=  Add the scalarized if statement to the list of statements unless we don't
  =#
  #=  have any branches left.
  =#
  if !isempty(bl)
    push!(statements, ALG_IF(bl, source))
  end
  return statements
end

"""
  Scalarizes a when statement.
"""
function scalarizeWhenStatement(
  branches::Vector{Tuple{Expression, Vector{Statement}}},
  source::DAE.ElementSource,
  statements::Vector{Statement},
)
  local bl::Vector{Tuple{Expression, Vector{Statement}}} = Tuple{Expression, Vector{Statement}}[]
  local cond::Expression
  local body::Vector{Statement}
  for b in branches
    (cond, body) = b
    body = scalarizeStatements(body)
    if isArray(typeOf(cond))
      (cond, _) = expand(cond)
    end
    push!(bl, (cond, body))
  end
  statements = push!(statements, ALG_WHEN(bl, source))
  return statements
end

"""
Check whether both sides of a record equation can be expanded to field-level.
Returns true if both LHS and RHS are component references or record expressions.
Returns false if either side is a function call (which returns a record and
cannot be trivially split into per-field calls).
"""
function canExpandRecordEquationSides(@nospecialize(lhs::Expression), @nospecialize(rhs::Expression))::Bool
  lhs_ok = lhs isa CREF_EXPRESSION || lhs isa RECORD_EXPRESSION
  rhs_ok = rhs isa CREF_EXPRESSION || rhs isa RECORD_EXPRESSION
  return lhs_ok && rhs_ok
end

"""
Expand a record equation into per-field scalar equations.
For each field of the record type, creates a new EQUATION_EQUALITY
with the field appended to both LHS and RHS crefs.
The generated field equations are recursively scalarized to handle
array-typed fields (e.g. X :: Real[2]).
"""
function expandRecordEquation(
  @nospecialize(lhs::Expression),
  @nospecialize(rhs::Expression),
  ty::M_Type,
  src::DAE.ElementSource,
  equations::Vector{Equation},
)::Vector{Equation}
  @match TYPE_COMPLEX(cls = cls) = ty
  local comps::Vector{InstNode} = getComponents(classTree(getClass(cls)))
  for (i, comp) in enumerate(comps)
    local field_ty = getType(comp)
    local field_lhs = expandRecordFieldExp(lhs, comp, field_ty, i)
    local field_rhs = expandRecordFieldExp(rhs, comp, field_ty, i)
    local field_eq = EQUATION_EQUALITY(field_lhs, field_rhs, field_ty, src)
    equations = scalarizeEquation(field_eq, equations)
  end
  return equations
end

"""
Create a field-level expression from a record-level expression.
For CREF_EXPRESSION: appends the field component to get cref.field
For RECORD_EXPRESSION: extracts the i-th element
"""
function expandRecordFieldExp(
  @nospecialize(exp::Expression),
  fieldNode::InstNode,
  @nospecialize(field_ty::M_Type),
  fieldIndex::Int,
)::Expression
  @match exp begin
    CREF_EXPRESSION(__) => begin
      local field_cr = prefixCref(fieldNode, field_ty, nil, exp.cref)
      CREF_EXPRESSION(field_ty, field_cr)
    end
    RECORD_EXPRESSION(__) => begin
      exp.elements[fieldIndex]
    end
    _ => begin
      exp
    end
  end
end

"""
Try to expand an EQUATION_ARRAY_EQUALITY into scalar equations.
Handles cases where the RHS is a TYPED_ARRAY_CONSTRUCTOR (possibly wrapped
in binary operations) and the LHS is an iterable array.
Returns a vector of scalar equations, or nothing if expansion is not possible.
"""
function tryExpandArrayEqualityToScalar(eq::Equation)
  local lhs_exp = eq.lhs
  local rhs_exp = eq.rhs
  #= Extract the TYPED_ARRAY_CONSTRUCTOR from the RHS, handling binary wrappers. =#
  local constructor = nothing
  local wrapper_op = nothing
  local wrapper_scalar = nothing
  local wrapper_is_lhs = false
  if rhs_exp isa CALL_EXPRESSION && rhs_exp.call isa TYPED_ARRAY_CONSTRUCTOR
    constructor = rhs_exp.call
  elseif rhs_exp isa BINARY_EXPRESSION
    local e1 = rhs_exp.exp1
    local e2 = rhs_exp.exp2
    if e1 isa CALL_EXPRESSION && e1.call isa TYPED_ARRAY_CONSTRUCTOR
      constructor = e1.call
      wrapper_op = rhs_exp.operator
      wrapper_scalar = e2
      wrapper_is_lhs = false
    elseif e2 isa CALL_EXPRESSION && e2.call isa TYPED_ARRAY_CONSTRUCTOR
      constructor = e2.call
      wrapper_op = rhs_exp.operator
      wrapper_scalar = e1
      wrapper_is_lhs = true
    end
  end
  if constructor === nothing
    return nothing
  end
  #= Get LHS elements =#
  local lhs_elements::Vector{Expression}
  if lhs_exp isa ARRAY_EXPRESSION
    lhs_elements = lhs_exp.elements
  else
    try
      local (exp_lhs, _) = expand(lhs_exp)
      if exp_lhs isa ARRAY_EXPRESSION
        lhs_elements = exp_lhs.elements
      else
        return nothing
      end
    catch
      return nothing
    end
  end
  #= Iterate over the constructor's range and substitute =#
  local body = constructor.exp
  local iters = constructor.iters
  if listLength(iters) != 1
    return nothing
  end
  local (iter_node, range_exp) = listHead(iters)
  local range_iter = fromExpToExpressionIterator(range_exp)
  local result_eqs = Equation[]
  local idx = 1
  local elem_ty = arrayElementType(eq.ty)
  while hasNext(range_iter)
    if idx > length(lhs_elements)
      return nothing
    end
    local value::Expression
    (range_iter, value) = next(range_iter)
    local substituted = simplify(replaceIterator(body, iter_node, value))
    #= Re-apply the binary wrapper if present =#
    local rhs_elem = if wrapper_op !== nothing
      if wrapper_is_lhs
        BINARY_EXPRESSION(wrapper_scalar, wrapper_op, substituted)
      else
        BINARY_EXPRESSION(substituted, wrapper_op, wrapper_scalar)
      end
    else
      substituted
    end
    push!(result_eqs, EQUATION_EQUALITY(lhs_elements[idx], rhs_elem, elem_ty, eq.source))
    idx += 1
  end
  if idx - 1 != length(lhs_elements)
    return nothing
  end
  return result_eqs
end

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

function verify(flatModel::FlatModel)
  for var in flatModel.variables
    verifyVariable(var)
  end
  for eq in flatModel.equations
    verifyEquation(eq)
    verifyEquationBounds(eq)
  end
  for ieq in flatModel.initialEquations
    verifyEquation(ieq)
    verifyEquationBounds(ieq)
  end
  for alg in Iterators.flatten((flatModel.algorithms, flatModel.initialAlgorithms))
    for stmt in alg.statements
      verifyStatementBounds(stmt)
    end
  end
#  return execStat(getInstanceName())
end

"""
omc's subscript bounds check (VerifyModel.checkSubscriptBounds): literal subscripts of
crefs against known dimensions, in bindings, equations (shallow, as omc's
Equation.applyExpShallow) and statements.
"""
function verifyVariable(var::Variable)
  verifyBindingBounds(var.binding)
  for attr in var.typeAttributes
    verifyBindingBounds(Util.tuple22(attr))
  end
  return nothing
end

#= A CEVAL_BINDING is a value: the binding the constant evaluation made for a record
   without one from its fields (NFCeval.makeComponentBinding), which a collected package
   constant keeps (MSL SimpleNaturalGas's SingleGasesData.C2H6). getTypedExp has no case
   for it, and it has no subscripts to check. =#
function verifyBindingBounds(binding::Binding)
  if isBound(binding) && !isvariant(binding, CEVAL_BINDING)
    checkSubscriptBounds(getTypedExp(binding), Binding_getInfo(binding))
  end
  return nothing
end

function verifyEquationBounds(eq::Equation)
  local info::SourceInfo = DAE.ElementSource_getInfo(source(eq))
  @match eq begin
    EQUATION_EQUALITY(__) || EQUATION_CONNECT(__) => begin
      checkSubscriptBounds(eq.lhs, info)
      checkSubscriptBounds(eq.rhs, info)
    end
    EQUATION_FOR(__) => begin
      isSome(eq.range) && checkSubscriptBounds(Util.getOption(eq.range), info)
    end
    EQUATION_IF(__) || EQUATION_WHEN(__) => begin
      for b in eq.branches
        @match b begin
          EQUATION_BRANCH(__) => checkSubscriptBounds(b.condition, info)
          _ => ()
        end
      end
    end
    EQUATION_ASSERT(__) => begin
      checkSubscriptBounds(eq.condition, info)
      checkSubscriptBounds(eq.message, info)
      checkSubscriptBounds(eq.level, info)
    end
    EQUATION_TERMINATE(__) => checkSubscriptBounds(eq.message, info)
    EQUATION_REINIT(__) => begin
      checkSubscriptBounds(eq.cref, info)
      checkSubscriptBounds(eq.reinitExp, info)
    end
    EQUATION_NORETCALL(__) => checkSubscriptBounds(eq.exp, info)
    _ => ()
  end
  return nothing
end

function verifyStatementBounds(stmt::Statement)
  local info::SourceInfo = DAE.ElementSource_getInfo(stmt.source)
  @match stmt begin
    ALG_ASSIGNMENT(__) => begin
      checkSubscriptBounds(stmt.lhs, info)
      checkSubscriptBounds(stmt.rhs, info)
    end
    ALG_FOR(__) => begin
      isSome(stmt.range) && checkSubscriptBounds(Util.getOption(stmt.range), info)
      foreach(verifyStatementBounds, stmt.body)
    end
    ALG_IF(__) || ALG_WHEN(__) => begin
      for b in stmt.branches
        checkSubscriptBounds(Util.tuple21(b), info)
        foreach(verifyStatementBounds, Util.tuple22(b))
      end
    end
    ALG_WHILE(__) => begin
      checkSubscriptBounds(stmt.condition, info)
      foreach(verifyStatementBounds, stmt.body)
    end
    ALG_ASSERT(__) => begin
      checkSubscriptBounds(stmt.condition, info)
      checkSubscriptBounds(stmt.message, info)
      checkSubscriptBounds(stmt.level, info)
    end
    ALG_TERMINATE(__) => checkSubscriptBounds(stmt.message, info)
    ALG_REINIT(__) => begin
      checkSubscriptBounds(stmt.cref, info)
      checkSubscriptBounds(stmt.reinitExp, info)
    end
    ALG_NORETCALL(__) => checkSubscriptBounds(stmt.exp, info)
    _ => ()
  end
  return nothing
end

function checkSubscriptBounds(@nospecialize(exp::Expression), info::SourceInfo)
  fold(exp, (e, arg) -> begin
    @match e begin
      CREF_EXPRESSION(__) => checkSubscriptBoundsCref(e.cref, info)
      _ => ()
    end
    arg
  end, nothing)
  return nothing
end

function checkSubscriptBoundsCref(cref::ComponentRef, info::SourceInfo)
  @match cref begin
    COMPONENT_REF_CREF(subscripts = subs) where {!listEmpty(subs) && isArray(cref.ty)} => begin
      local dims::List{Dimension} = arrayDims(cref.ty)
      local index::Int = 1
      for s in subs
        listEmpty(dims) && break
        local d::Dimension = listHead(dims)
        dims = listRest(dims)
        if isScalarLiteral(s) && isKnown(d)
          local int_sub::Int = toInteger(s)
          if int_sub < 1 || int_sub > size(d)
            Error.addSourceMessage(Error.ARRAY_INDEX_OUT_OF_BOUNDS,
              list(toString(s), intString(index), toString(d), firstName(cref)), info)
            fail()
          end
        end
        index += 1
      end
      checkSubscriptBoundsCref(cref.restCref, info)
    end
    _ => ()
  end
  return nothing
end

function expandCrefSet(crefs::List{<:ComponentRef})
  local outCrefs::List{ComponentRef} = nil
  local exp::Expression
  local expl::List{Expression}
  for cref in crefs
    exp = fromCref(cref)
    (exp, _) = expandCref(exp)
    if isArray(exp)
      expl = arrayElements(exp)
      outCrefs =
        listAppend(list(toCref(e) for e in expl), outCrefs)
    else
      outCrefs = Cons{ComponentRef}(cref, outCrefs)
    end
  end
  outCrefs = ListUtil.sort(outCrefs, isGreater)
  outCrefs = ListUtil.sortedUnique(outCrefs, isEqual)
  return outCrefs
end

function checkCrefSetEquality(
  crefs1::List{<:ComponentRef},
  crefs2::List{<:ComponentRef},
  errMsg #= TODO=#,
  source::DAE.ElementSource,
)
  #=  Assume the user isn't mixing different ways of subscripting array
  =#
  #=  varibles in the different branches, and just check the sets as is.
  =#
  if ListUtil.isEqualOnTrue(crefs1, crefs2, isEqual)
    return
  end
  #=  If the sets didn't match, expand arrays into scalars and try again.
  =#
  if ListUtil.isEqualOnTrue(
    expandCrefSet(crefs1),
    expandCrefSet(crefs2),
    isEqual,
  )
    return
  end
  #=  Couldn't get the sets to match, print an error and fail.
  =#
  Error.addSourceMessage(errMsg, nil, DAE.ElementSource_getInfo(source))
  return fail()
end

"""
  Checks that the left-hand sides of the given if-equation branches consists
  of the same set of crefs, and adds that set to the given set of crefs.
"""
function whenEquationIfCrefs(
  branches::List{<:Equation},
  source::DAE.ElementSource,
  crefs::List{<:ComponentRef},
)::List{ComponentRef}
  local crefs1::List{ComponentRef}
  local crefs2::List{ComponentRef}
  local rest_branches::List{P_Equation.Equation}
  local body::List{Equation}
  @match _cons(P_Equation.Equation.BRANCH(body = body), rest_branches) = branches
  @assign crefs1 = whenEquationBranchCrefs(body)
  for branch in rest_branches
    @match P_Equation.Equation.BRANCH(body = body) = branch
    @assign crefs2 = whenEquationBranchCrefs(body)
    checkCrefSetEquality(crefs1, crefs2, Error.WHEN_IF_VARIABLE_MISMATCH, source)
  end
  #=  All the branches must have the same set of crefs on the lhs.
  =#
  @assign crefs = listAppend(crefs1, crefs)
  return crefs
end

function whenEquationEqualityCrefs(
  lhsExp::Expression,
  crefs::List{<:ComponentRef},
)::List{ComponentRef}
  @assign crefs = begin
    @match lhsExp begin
      CREF_EXPRESSION(__) => begin
        Cons{ComponentRef}(lhsExp.cref, crefs)
      end

      TUPLE_EXPRESSION(__) => begin
        ListUtil.fold(lhsExp.elements, whenEquationEqualityCrefs, crefs)
      end
    end
  end
  return crefs
end

"""
  Helper function to verifyWhenEquation, returns the set of crefs that the
  given list of equations contains on the lhs.
"""
function whenEquationBranchCrefs(eql::Union{List{<:Equation}, Vector{<:Equation}})::List{ComponentRef}
  local crefs::List{ComponentRef} = nil
  for eq in eql
    @assign crefs = begin
      @match eq begin
        EQUATION_EQUALITY(__) => begin
          whenEquationEqualityCrefs(eq.lhs, crefs)
        end
        EQUATION_CREF_EQUALITY(__) => begin
          Cons{ComponentRef}(eq.lhs, crefs)
        end
        EQUATION_ARRAY_EQUALITY(__) => begin
          whenEquationEqualityCrefs(eq.lhs, crefs)
        end
        #= A reinit is not an equation for a variable: the branches of a
           when-equation need not reinit the same states (as OpenModelica). =#
        EQUATION_IF(__) => begin
          whenEquationIfCrefs(eq.branches, eq.source, crefs)
        end
        _ => begin
          crefs
        end
      end
    end
  end
  crefs = ListUtil.sort(crefs, isGreater)
  crefs = ListUtil.sortedUnique(crefs, isEqual)
  return crefs
end

""" Checks that each branch in a when-equation has the same set of crefs on the lhs. """
function verifyWhenEquation(
  branches::List{<:Equation_Branch},
  source::DAE.ElementSource,
)
  local crefs1::List{ComponentRef}
  local crefs2::List{ComponentRef}
  local rest_branches::List{Equation_Branch}
  local body::Vector{Equation}
  #=  Only when-equation with more than one branch needs to be checked. =#
  if ListUtil.hasOneElement(branches)
    return
  end
  @match EQUATION_BRANCH(body = body) <| rest_branches = branches
  @assign crefs1 = whenEquationBranchCrefs(body)
  #=TODO: Should the return be here or is it a translation error =#
  return for branch in rest_branches
    @match EQUATION_BRANCH(body = body) = branch
    crefs2 = whenEquationBranchCrefs(body)
    checkCrefSetEquality(
      crefs1,
      crefs2,
      Error.DIFFERENT_VARIABLES_SOLVED_IN_ELSEWHEN,
      source,
    )
  end
end

function verifyEquation(eq::Equation)
  return  () = begin
    @match eq begin
      EQUATION_WHEN(__) => begin
        verifyWhenEquation(arrayList(eq.branches), eq.source)
        ()
      end
      _ => begin
        ()
      end
    end
  end
end

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
  for eq in flatModel.equations
    verifyEquation(eq)
  end
#  return execStat(getInstanceName())
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

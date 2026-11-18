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

module AbsynUtil

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

const FuncTplToTpl = Function

const FuncTplToTpl = Function

const FuncType = Function

const ModFunc = Function

const MapFunc = Function

const FuncType = Function

const FuncT = Function

const FuncType = Function

using OMParser.Absyn

import ..ListUtil

import ..Frontend.Util
import ..Frontend.System

const dummyParts = PARTS(nil, nil, nil, nil, NONE())::ClassDef

const dummyInfo = SOURCEINFO("", false, 0, 0, 0, 0, 0.0)::Info

const dummyProgram = PROGRAM(nil, TOP())::Program
TypeA = Any
Type_a = Any
Argument = Any
Arg = Any
#=  stefan
=#

"""
  Traverses all subequations of an equation.
  Takes a function and an extra argument passed through the traversal
"""
function traverseEquation(
  inEquation::Equation,
  inFunc::FuncTplToTpl,
  inTypeA::TypeA,
)::Tuple{Equation, TypeA}
  local outTpl::Tuple{Equation, TypeA}

  @assign outTpl = begin
    local arg::TypeA
    local arg_1::TypeA
    local arg_2::TypeA
    local arg_3::TypeA
    local arg_4::TypeA
    local eq::Equation
    local eq_1::Equation
    local rel::FuncTplToTpl
    local e::Exp
    local e_1::Exp
    local eqilst::List{EquationItem}
    local eqilst1::List{EquationItem}
    local eqilst2::List{EquationItem}
    local eqilst_1::List{EquationItem}
    local eqilst1_1::List{EquationItem}
    local eqilst2_1::List{EquationItem}
    local eeqitlst::List{Tuple{Exp, List{EquationItem}}}
    local eeqitlst_1::List{Tuple{Exp, List{EquationItem}}}
    local fis::ForIterators
    local fis_1::ForIterators
    local ei::EquationItem
    local ei_1::EquationItem
    @matchcontinue (inEquation, inFunc, inTypeA) begin
      (eq && EQ_IF(e, eqilst1, eeqitlst, eqilst2), rel, arg) => begin
        @assign (eqilst1_1, arg_1) = traverseEquationItemList(eqilst1, rel, arg)
        @assign (eeqitlst_1, arg_2) = traverseExpEqItemTupleList(eeqitlst, rel, arg_1)
        @assign (eqilst2_1, arg_3) = traverseEquationItemList(eqilst2, rel, arg_2)
        @match (EQ_IF(), arg_4) = rel((eq, arg_3))
        (EQ_IF(e, eqilst1_1, eeqitlst_1, eqilst2_1), arg_4)
      end

      (eq && EQ_FOR(_, eqilst), rel, arg) => begin
        @assign (eqilst_1, arg_1) = traverseEquationItemList(eqilst, rel, arg)
        @match (EQ_FOR(fis_1, _), arg_2) = rel((eq, arg_1))
        (EQ_FOR(fis_1, eqilst_1), arg_2)
      end

      (eq && EQ_WHEN_E(_, eqilst, eeqitlst), rel, arg) => begin
        @assign (eqilst_1, arg_1) = traverseEquationItemList(eqilst, rel, arg)
        @assign (eeqitlst_1, arg_2) = traverseExpEqItemTupleList(eeqitlst, rel, arg_1)
        @match (EQ_WHEN_E(e_1, _, _), arg_3) = rel((eq, arg_2))
        (EQ_WHEN_E(e_1, eqilst_1, eeqitlst_1), arg_3)
      end

      (eq && EQ_FAILURE(ei), rel, arg) => begin
        @assign (ei_1, arg_1) = traverseEquationItem(ei, rel, arg)
        @match (EQ_FAILURE(), arg_2) = rel((eq, arg_1))
        (EQ_FAILURE(ei_1), arg_2)
      end

      (eq, rel, arg) => begin
        @assign (eq_1, arg_1) = rel((eq, arg))
        (eq_1, arg_1)
      end
    end
  end
  return outTpl
end

#=  stefan
=#

"""Traverses the equation inside an equationitem"""
function traverseEquationItem(
  inEquationItem::EquationItem,
  inFunc::FuncTplToTpl,
  inTypeA::TypeA,
)::Tuple{EquationItem, TypeA}
  local outTpl::Tuple{EquationItem, TypeA}

  @assign outTpl = begin
    local ei::EquationItem
    local rel::FuncTplToTpl
    local arg::TypeA
    local arg_1::TypeA
    local eq::Equation
    local eq_1::Equation
    local oc::Option{Comment}
    local info::Info
    @matchcontinue (inEquationItem, inFunc, inTypeA) begin
      (EQUATIONITEM(eq, oc, info), rel, arg) => begin
        @assign (eq_1, arg_1) = traverseEquation(eq, rel, arg)
        (EQUATIONITEM(eq_1, oc, info), arg_1)
      end

      (ei, _, arg) => begin
        (ei, arg)
      end
    end
  end
  return outTpl
end

#=  stefan
=#

"""calls traverseEquationItem on every element of the given list"""
function traverseEquationItemList(
  inEquationItemList::List{<:EquationItem},
  inFunc::FuncTplToTpl,
  inTypeA::TypeA,
)::Tuple{List{EquationItem}, TypeA}
  local outTpl::Tuple{List{EquationItem}, TypeA}

  local arg2::TypeA = inTypeA

  @assign outTpl = (
    list(
      begin
        local ei::EquationItem
        local ei_1::EquationItem
        @match el begin
          ei => begin
            @assign (ei_1, arg2) = traverseEquationItem(ei, inFunc, arg2)
            ei_1
          end
        end
      end for el in inEquationItemList
    ),
    arg2,
  )
  return outTpl
end

#=  stefan
=#

"""
  traverses a list of Exp * EquationItem list tuples
  mostly used for else-if blocks
"""
function traverseExpEqItemTupleList(
  inList::List{<:Tuple{<:Exp, List{<:EquationItem}}},
  inFunc::FuncTplToTpl,
  inTypeA::TypeA,
)::Tuple{List{Tuple{Exp, List{EquationItem}}}, TypeA}
  local outTpl::Tuple{List{Tuple{Exp, List{EquationItem}}}, TypeA}

  local arg2::TypeA = inTypeA

  @assign outTpl = (
    list(
      begin
        local e::Exp
        local eilst::List{EquationItem}
        local eilst_1::List{EquationItem}
        @match el begin
          (e, eilst) => begin
            @assign (eilst_1, arg2) = traverseEquationItemList(eilst, inFunc, arg2)
            (e, eilst_1)
          end
        end
      end for el in inList
    ),
    arg2,
  )
  return outTpl
end

#=  stefan
=#

"""
  Traverses all subalgorithms of an algorithm
  Takes a function and an extra argument passed through the traversal
"""
function traverseAlgorithm(
  inAlgorithm::Algorithm,
  inFunc::FuncTplToTpl,
  inTypeA::TypeA,
)::Tuple{Algorithm, TypeA}
  local outTpl::Tuple{Algorithm, TypeA}

  @assign outTpl = begin
    local arg::TypeA
    local arg_1::TypeA
    local arg1_1::TypeA
    local arg2_1::TypeA
    local arg3_1::TypeA
    local alg::Algorithm
    local alg_1::Algorithm
    local alg1_1::Algorithm
    local alg2_1::Algorithm
    local alg3_1::Algorithm
    local ailst::List{AlgorithmItem}
    local ailst1::List{AlgorithmItem}
    local ailst2::List{AlgorithmItem}
    local ailst_1::List{AlgorithmItem}
    local ailst1_1::List{AlgorithmItem}
    local ailst2_1::List{AlgorithmItem}
    local eaitlst::List{Tuple{Exp, List{AlgorithmItem}}}
    local eaitlst_1::List{Tuple{Exp, List{AlgorithmItem}}}
    local rel::FuncTplToTpl
    local ai::AlgorithmItem
    local ai_1::AlgorithmItem
    local e::Exp
    local e_1::Exp
    local fis::ForIterators
    local fis_1::ForIterators
    @matchcontinue (inAlgorithm, inFunc, inTypeA) begin
      (alg && ALG_IF(_, ailst1, eaitlst, ailst2), rel, arg) => begin
        @assign (ailst1_1, arg1_1) = traverseAlgorithmItemList(ailst1, rel, arg)
        @assign (eaitlst_1, arg2_1) = traverseExpAlgItemTupleList(eaitlst, rel, arg1_1)
        @assign (ailst2_1, arg3_1) = traverseAlgorithmItemList(ailst2, rel, arg2_1)
        @match (ALG_IF(e_1, _, _, _), arg_1) = rel((alg, arg3_1))
        (ALG_IF(e_1, ailst1_1, eaitlst_1, ailst2_1), arg_1)
      end

      (alg && ALG_FOR(_, ailst), rel, arg) => begin
        @assign (ailst_1, arg1_1) = traverseAlgorithmItemList(ailst, rel, arg)
        @match (ALG_FOR(fis_1, _), arg_1) = rel((alg, arg1_1))
        (ALG_FOR(fis_1, ailst_1), arg_1)
      end

      (alg && ALG_PARFOR(_, ailst), rel, arg) => begin
        @assign (ailst_1, arg1_1) = traverseAlgorithmItemList(ailst, rel, arg)
        @match (ALG_PARFOR(fis_1, _), arg_1) = rel((alg, arg1_1))
        (ALG_PARFOR(fis_1, ailst_1), arg_1)
      end

      (alg && ALG_WHILE(_, ailst), rel, arg) => begin
        @assign (ailst_1, arg1_1) = traverseAlgorithmItemList(ailst, rel, arg)
        @match (ALG_WHILE(e_1, _), arg_1) = rel((alg, arg1_1))
        (ALG_WHILE(e_1, ailst_1), arg_1)
      end

      (alg && ALG_WHEN_A(_, ailst, eaitlst), rel, arg) => begin
        @assign (ailst_1, arg1_1) = traverseAlgorithmItemList(ailst, rel, arg)
        @assign (eaitlst_1, arg2_1) = traverseExpAlgItemTupleList(eaitlst, rel, arg1_1)
        @match (ALG_WHEN_A(e_1, _, _), arg_1) = rel((alg, arg2_1))
        (ALG_WHEN_A(e_1, ailst_1, eaitlst_1), arg_1)
      end

      (alg, rel, arg) => begin
        @assign (alg_1, arg_1) = rel((alg, arg))
        (alg_1, arg_1)
      end
    end
  end
  return outTpl
end

#=  stefan
=#

"""
  traverses the Algorithm contained in an AlgorithmItem, if any
  see traverseAlgorithm
"""
function traverseAlgorithmItem(
  inAlgorithmItem::AlgorithmItem,
  inFunc::FuncTplToTpl,
  inTypeA::TypeA,
)::Tuple{AlgorithmItem, TypeA}
  local outTpl::Tuple{AlgorithmItem, TypeA}

  @assign outTpl = begin
    local rel::FuncTplToTpl
    local arg::TypeA
    local arg_1::TypeA
    local alg::Algorithm
    local alg_1::Algorithm
    local oc::Option{Comment}
    local ai::AlgorithmItem
    local info::Info
    @matchcontinue (inAlgorithmItem, inFunc, inTypeA) begin
      (ALGORITHMITEM(alg, oc, info), rel, arg) => begin
        @assign (alg_1, arg_1) = traverseAlgorithm(alg, rel, arg)
        (ALGORITHMITEM(alg_1, oc, info), arg_1)
      end

      (ai, _, arg) => begin
        (ai, arg)
      end
    end
  end
  return outTpl
end

#=  stefan
=#

"""calls traverseAlgorithmItem on each item in a list of AlgorithmItems"""
function traverseAlgorithmItemList(
  inAlgorithmItemList::List{<:AlgorithmItem},
  inFunc::FuncTplToTpl,
  inTypeA::TypeA,
)::Tuple{List{AlgorithmItem}, TypeA}
  local outTpl::Tuple{List{AlgorithmItem}, TypeA}

  @assign outTpl = begin
    local rel::FuncTplToTpl
    local arg::TypeA
    local arg_1::TypeA
    local arg_2::TypeA
    local ai::AlgorithmItem
    local ai_1::AlgorithmItem
    local cdr::List{AlgorithmItem}
    local cdr_1::List{AlgorithmItem}
    @match (inAlgorithmItemList, inFunc, inTypeA) begin
      (nil(), _, arg) => begin
        (nil, arg)
      end

      (ai <| cdr, rel, arg) => begin
        @assign (ai_1, arg_1) = traverseAlgorithmItem(ai, rel, arg)
        @assign (cdr_1, arg_2) = traverseAlgorithmItemList(cdr, rel, arg_1)
        (_cons(ai_1, cdr_1), arg_2)
      end
    end
  end
  return outTpl
end

#=  stefan
=#

"""
  traverses a list of Exp * AlgorithmItem list tuples
  mostly used for else-if blocks
"""
function traverseExpAlgItemTupleList(
  inList::List{<:Tuple{<:Exp, List{<:AlgorithmItem}}},
  inFunc::FuncTplToTpl,
  inTypeA::TypeA,
)::Tuple{List{Tuple{Exp, List{AlgorithmItem}}}, TypeA}
  local outTpl::Tuple{List{Tuple{Exp, List{AlgorithmItem}}}, TypeA}

  @assign outTpl = begin
    local rel::FuncTplToTpl
    local arg::TypeA
    local arg_1::TypeA
    local arg_2::TypeA
    local cdr::List{Tuple{Exp, List{AlgorithmItem}}}
    local cdr_1::List{Tuple{Exp, List{AlgorithmItem}}}
    local e::Exp
    local ailst::List{AlgorithmItem}
    local ailst_1::List{AlgorithmItem}
    @match (inList, inFunc, inTypeA) begin
      (nil(), _, arg) => begin
        (nil, arg)
      end

      ((e, ailst) <| cdr, rel, arg) => begin
        @assign (ailst_1, arg_1) = traverseAlgorithmItemList(ailst, rel, arg)
        @assign (cdr_1, arg_2) = traverseExpAlgItemTupleList(cdr, rel, arg_1)
        (_cons((e, ailst_1), cdr_1), arg_2)
      end
    end
  end
  return outTpl
end

"""
  Traverses all subexpressions of an Exp expression.
  Takes a function and an extra argument passed through the traversal.
"""
function traverseExpTopDown(inExp::Exp, inFunc::FuncType, inArg::Type_a)::Tuple{Exp, Type_a}
  local outArg::Type_a
  local outExp::Exp

  @assign (outExp, outArg) = traverseExpBidir(inExp, inFunc, dummyTraverseExp, inArg)
  return (outExp, outArg)
end

"""
  Traverses a list of expressions, calling traverseExpBidir on each
  expression.
"""
function traverseExpListBidir(
  inExpl::List{<:Exp},
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{List{Exp}, Argument}
  local outArg::Argument
  local outExpl::List{Exp}

  @assign (outExpl, outArg) =
    ListUtil.map2FoldCheckReferenceEq(inExpl, traverseExpBidir, enterFunc, exitFunc, inArg)
  return (outExpl, outArg)
end

"""
  This function takes an expression and a tuple with an enter function, an exit
  function, and an extra argument. For each expression it encounters it calls
  the enter function with the expression and the extra argument. It then
  traverses all subexpressions in the expression and calls traverseExpBidir on
  them with the updated argument. Finally it calls the exit function, again with
  the updated argument. This means that this function is bidirectional, and can
  be used to emulate both top-down and bottom-up traversal.
"""
function traverseExpBidir(
  inExp::Exp,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{Exp, Argument}
  local arg::Argument
  local e::Exp

  @assign (e, arg) = enterFunc(inExp, inArg)
  @assign (e, arg) = traverseExpBidirSubExps(e, enterFunc, exitFunc, arg)
  @assign (e, arg) = exitFunc(e, arg)
  return (e, arg)
end

"""
  Same as traverseExpBidir, but with an optional expression. Calls
  traverseExpBidir if the option is SOME(), or just returns the input if it's
  NONE()
"""
function traverseExpOptBidir(
  inExp::Option{<:Exp},
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{Option{Exp}, Argument}
  local arg::Argument
  local outExp::Option{Exp}

  @assign (outExp, arg) = begin
    local e1::Exp
    local e2::Exp
    local tup::Tuple{FuncType, FuncType, Argument}
    @match (inExp, enterFunc, exitFunc, inArg) begin
      (SOME(e1), _, _, _) => begin
        @assign (e2, arg) = traverseExpBidir(e1, enterFunc, exitFunc, inArg)
        (if referenceEq(e1, e2)
          inExp
        else
          SOME(e2)
        end, arg)
      end

      _ => begin
        (inExp, inArg)
      end
    end
  end
  return (outExp, arg)
end

"""
  Helper function to traverseExpBidir. Traverses the subexpressions of an
  expression and calls traverseExpBidir on them.
"""
function traverseExpBidirSubExps(
  inExp::Exp,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{Exp, Argument}
  local arg::Argument
  local e::Exp

  @assign (e, arg) = begin
    local e1::Exp
    local e1m::Exp
    local e2::Exp
    local e2m::Exp
    local e3::Exp
    local e3m::Exp
    local oe1::Option{Exp}
    local oe1m::Option{Exp}
    local tup::Tuple{FuncType, FuncType, Argument}
    local op::Operator
    local cref::ComponentRef
    local crefm::ComponentRef
    local else_ifs1::List{Tuple{Exp, Exp}}
    local else_ifs2::List{Tuple{Exp, Exp}}
    local expl1::List{Exp}
    local expl2::List{Exp}
    local mat_expl::List{List{Exp}}
    local fargs1::FunctionArgs
    local fargs2::FunctionArgs
    local error_msg::String
    local id::Ident
    local enterName::Ident
    local exitName::Ident
    local match_ty::MatchType
    local match_decls::List{ElementItem}
    local match_cases::List{Case}
    local cmt::Option{String}
    @match (inExp, enterFunc, exitFunc, inArg) begin
      (INTEGER(__), _, _, _) => begin
        (inExp, inArg)
      end

      (REAL(__), _, _, _) => begin
        (inExp, inArg)
      end

      (STRING(__), _, _, _) => begin
        (inExp, inArg)
      end

      (BOOL(__), _, _, _) => begin
        (inExp, inArg)
      end

      (CREF(componentRef = cref), _, _, arg) => begin
        @assign (crefm, arg) = traverseExpBidirCref(cref, enterFunc, exitFunc, arg)
        (if referenceEq(cref, crefm)
          inExp
        else
          CREF(crefm)
        end, arg)
      end

      (BINARY(exp1 = e1, op = op, exp2 = e2), _, _, arg) => begin
        @assign (e1m, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (e2m, arg) = traverseExpBidir(e2, enterFunc, exitFunc, arg)
        (if referenceEq(e1, e1m) && referenceEq(e2, e2m)
          inExp
        else
          BINARY(e1m, op, e2m)
        end, arg)
      end

      (UNARY(op = op, exp = e1), _, _, arg) => begin
        @assign (e1m, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        (if referenceEq(e1, e1m)
          inExp
        else
          UNARY(op, e1m)
        end, arg)
      end

      (LBINARY(exp1 = e1, op = op, exp2 = e2), _, _, arg) => begin
        @assign (e1m, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (e2m, arg) = traverseExpBidir(e2, enterFunc, exitFunc, arg)
        (if referenceEq(e1, e1m) && referenceEq(e2, e2m)
          inExp
        else
          LBINARY(e1m, op, e2m)
        end, arg)
      end

      (LUNARY(op = op, exp = e1), _, _, arg) => begin
        @assign (e1m, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        (if referenceEq(e1, e1m)
          inExp
        else
          LUNARY(op, e1m)
        end, arg)
      end

      (RELATION(exp1 = e1, op = op, exp2 = e2), _, _, arg) => begin
        @assign (e1m, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (e2m, arg) = traverseExpBidir(e2, enterFunc, exitFunc, arg)
        (if referenceEq(e1, e1m) && referenceEq(e2, e2m)
          inExp
        else
          RELATION(e1m, op, e2m)
        end, arg)
      end

      (
        IFEXP(ifExp = e1, trueBranch = e2, elseBranch = e3, elseIfBranch = else_ifs1),
        _,
        _,
        arg,
      ) => begin
        @assign (e1m, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (e2m, arg) = traverseExpBidir(e2, enterFunc, exitFunc, arg)
        @assign (e3m, arg) = traverseExpBidir(e3, enterFunc, exitFunc, arg)
        @assign (else_ifs2, arg) = ListUtil.map2FoldCheckReferenceEq(
          else_ifs1,
          traverseExpBidirElseIf,
          enterFunc,
          exitFunc,
          arg,
        )
        (
          if referenceEq(e1, e1m) &&
             referenceEq(e2, e2m) &&
             referenceEq(e3, e3m) &&
             referenceEq(else_ifs1, else_ifs2)
            inExp
          else
            IFEXP(e1m, e2m, e3m, else_ifs2)
          end,
          arg,
        )
      end

      (CALL(function_ = cref, functionArgs = fargs1), _, _, arg) => begin
        @assign (fargs2, arg) =
          traverseExpBidirFunctionArgs(fargs1, enterFunc, exitFunc, arg)
        (if referenceEq(fargs1, fargs2)
          inExp
        else
          CALL(cref, fargs2)
        end, arg)
      end

      (PARTEVALFUNCTION(function_ = cref, functionArgs = fargs1), _, _, arg) => begin
        @assign (fargs2, arg) =
          traverseExpBidirFunctionArgs(fargs1, enterFunc, exitFunc, arg)
        (if referenceEq(fargs1, fargs2)
          inExp
        else
          PARTEVALFUNCTION(cref, fargs2)
        end, arg)
      end

      (ARRAY(arrayExp = expl1), _, _, arg) => begin
        @assign (expl2, arg) = traverseExpListBidir(expl1, enterFunc, exitFunc, arg)
        (if referenceEq(expl1, expl2)
          inExp
        else
          ARRAY(expl2)
        end, arg)
      end

      (MATRIX(matrix = mat_expl), _, _, arg) => begin
        @assign (mat_expl, arg) = ListUtil.map2FoldCheckReferenceEq(
          mat_expl,
          traverseExpListBidir,
          enterFunc,
          exitFunc,
          arg,
        )
        (MATRIX(mat_expl), arg)
      end

      (RANGE(start = e1, step = oe1, stop = e2), _, _, arg) => begin
        @assign (e1m, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (oe1m, arg) = traverseExpOptBidir(oe1, enterFunc, exitFunc, arg)
        @assign (e2m, arg) = traverseExpBidir(e2, enterFunc, exitFunc, arg)
        (if referenceEq(e1, e1m) && referenceEq(e2, e2m) && referenceEq(oe1, oe1m)
          inExp
        else
          RANGE(e1m, oe1m, e2m)
        end, arg)
      end

      (END(__), _, _, _) => begin
        (inExp, inArg)
      end

      (TUPLE(expressions = expl1), _, _, arg) => begin
        @assign (expl2, arg) = traverseExpListBidir(expl1, enterFunc, exitFunc, arg)
        (if referenceEq(expl1, expl2)
          inExp
        else
          TUPLE(expl2)
        end, arg)
      end

      (AS(id = id, exp = e1), _, _, arg) => begin
        @assign (e1m, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        (if referenceEq(e1, e1m)
          inExp
        else
          AS(id, e1m)
        end, arg)
      end

      (CONS(head = e1, rest = e2), _, _, arg) => begin
        @assign (e1m, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (e2m, arg) = traverseExpBidir(e2, enterFunc, exitFunc, arg)
        (if referenceEq(e1, e1m) && referenceEq(e2, e2m)
          inExp
        else
          CONS(e1m, e2m)
        end, arg)
      end

      (
        MATCHEXP(
          matchTy = match_ty,
          inputExp = e1,
          localDecls = match_decls,
          cases = match_cases,
          comment = cmt,
        ),
        _,
        _,
        arg,
      ) => begin
        @assign (e1, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (match_cases, arg) = ListUtil.map2FoldCheckReferenceEq(
          match_cases,
          traverseMatchCase,
          enterFunc,
          exitFunc,
          arg,
        )
        (MATCHEXP(match_ty, e1, match_decls, match_cases, cmt), arg)
      end

      (LIST(exps = expl1), _, _, arg) => begin
        @assign (expl2, arg) = traverseExpListBidir(expl1, enterFunc, exitFunc, arg)
        (if referenceEq(expl1, expl2)
          inExp
        else
          LIST(expl2)
        end, arg)
      end

      (CODE(__), _, _, _) => begin
        (inExp, inArg)
      end

      (DOT(__), _, _, arg) => begin
        @assign (e1, arg) = traverseExpBidir(inExp.exp, enterFunc, exitFunc, arg)
        @assign (e2, arg) = traverseExpBidir(inExp.index, enterFunc, exitFunc, arg)
        (if referenceEq(inExp.exp, e1) && referenceEq(inExp.index, e2)
          inExp
        else
          DOT(e1, e2)
        end, arg)
      end

      _ => begin
        @assign (_, _, enterName) = System.dladdr(enterFunc)
        @assign (_, _, exitName) = System.dladdr(exitFunc)
        @assign error_msg =
          "in traverseExpBidirSubExps(" +
          enterName +
          ", " +
          exitName +
          ") - Unknown expression: "
        @assign error_msg = error_msg + printExp(inExp)
        Error.addMessage(Error.INTERNAL_ERROR, list(error_msg))
        fail()
      end
    end
  end
  return (e, arg)
end

"""
  Helper function to traverseExpBidirSubExps. Traverses any expressions in a
  component reference (i.e. in it's subscripts).
"""
function traverseExpBidirCref(
  inCref::ComponentRef,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{ComponentRef, Argument}
  local arg::Argument
  local outCref::ComponentRef

  @assign (outCref, arg) = begin
    local name::Ident
    local cr1::ComponentRef
    local cr2::ComponentRef
    local subs1::List{Subscript}
    local subs2::List{Subscript}
    local tup::Tuple{FuncType, FuncType, Argument}
    @match (inCref, enterFunc, exitFunc, inArg) begin
      (CREF_FULLYQUALIFIED(componentRef = cr1), _, _, arg) => begin
        @assign (cr2, arg) = traverseExpBidirCref(cr1, enterFunc, exitFunc, arg)
        (if referenceEq(cr1, cr2)
          inCref
        else
          crefMakeFullyQualified(cr2)
        end, arg)
      end

      (CREF_QUAL(name = name, subscripts = subs1, componentRef = cr1), _, _, arg) => begin
        @assign (subs2, arg) = ListUtil.map2FoldCheckReferenceEq(
          subs1,
          traverseExpBidirSubs,
          enterFunc,
          exitFunc,
          arg,
        )
        @assign (cr2, arg) = traverseExpBidirCref(cr1, enterFunc, exitFunc, arg)
        (if referenceEq(cr1, cr2) && referenceEq(subs1, subs2)
          inCref
        else
          CREF_QUAL(name, subs2, cr2)
        end, arg)
      end

      (CREF_IDENT(name = name, subscripts = subs1), _, _, arg) => begin
        @assign (subs2, arg) = ListUtil.map2FoldCheckReferenceEq(
          subs1,
          traverseExpBidirSubs,
          enterFunc,
          exitFunc,
          arg,
        )
        (if referenceEq(subs1, subs2)
          inCref
        else
          CREF_IDENT(name, subs2)
        end, arg)
      end

      (ALLWILD(__), _, _, _) => begin
        (inCref, inArg)
      end

      (WILD(__), _, _, _) => begin
        (inCref, inArg)
      end
    end
  end
  return (outCref, arg)
end

"""
  Helper function to traverseExpBidirCref. Traverses expressions in a
  subscript.
"""
function traverseExpBidirSubs(
  inSubscript::Subscript,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{Subscript, Argument}
  local arg::Argument
  local outSubscript::Subscript

  @assign (outSubscript, arg) = begin
    local e1::Exp
    local e2::Exp
    @match (inSubscript, enterFunc, exitFunc, inArg) begin
      (SUBSCRIPT(subscript = e1), _, _, arg) => begin
        @assign (e2, arg) = traverseExpBidir(e1, enterFunc, exitFunc, inArg)
        (if referenceEq(e1, e2)
          inSubscript
        else
          SUBSCRIPT(e2)
        end, arg)
      end

      (NOSUB(__), _, _, _) => begin
        (inSubscript, inArg)
      end
    end
  end
  return (outSubscript, arg)
end

"""
  Helper function to traverseExpBidirSubExps. Traverses the expressions in an
  elseif branch.
"""
function traverseExpBidirElseIf(
  inElseIf::Tuple{<:Exp, Exp},
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{Tuple{Exp, Exp}, Argument}
  local arg::Argument
  local outElseIf::Tuple{Exp, Exp}

  local e1::Exp
  local e2::Exp
  local tup::Tuple{FuncType, FuncType, Argument}

  @assign (e1, e2) = inElseIf
  @assign (e1, arg) = traverseExpBidir(e1, enterFunc, exitFunc, inArg)
  @assign (e2, arg) = traverseExpBidir(e2, enterFunc, exitFunc, arg)
  @assign outElseIf = (e1, e2)
  return (outElseIf, arg)
end

"""
  Helper function to traverseExpBidirSubExps. Traverses the expressions in a
  list of function argument.
"""
function traverseExpBidirFunctionArgs(
  inArgs::FunctionArgs,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{FunctionArgs, Argument}
  local outArg::Argument
  local outArgs::FunctionArgs

  @assign (outArgs, outArg) = begin
    local e1::Exp
    local e2::Exp
    local expl1::List{Exp}
    local expl2::List{Exp}
    local named_args1::List{NamedArg}
    local named_args2::List{NamedArg}
    local iters1::ForIterators
    local iters2::ForIterators
    local arg::Argument
    local iterType::ReductionIterType
    @match (inArgs, enterFunc, exitFunc, inArg) begin
      (FUNCTIONARGS(args = expl1, argNames = named_args1), _, _, arg) => begin
        @assign (expl2, arg) = traverseExpListBidir(expl1, enterFunc, exitFunc, arg)
        @assign (named_args2, arg) = ListUtil.map2FoldCheckReferenceEq(
          named_args1,
          traverseExpBidirNamedArg,
          enterFunc,
          exitFunc,
          arg,
        )
        (if referenceEq(expl1, expl2) && referenceEq(named_args1, named_args2)
          inArgs
        else
          FUNCTIONARGS(expl2, named_args2)
        end, arg)
      end

      (FOR_ITER_FARG(e1, iterType, iters1), _, _, arg) => begin
        @assign (e2, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (iters2, arg) = ListUtil.map2FoldCheckReferenceEq(
          iters1,
          traverseExpBidirIterator,
          enterFunc,
          exitFunc,
          arg,
        )
        (if referenceEq(e1, e2) && referenceEq(iters1, iters2)
          inArgs
        else
          FOR_ITER_FARG(e2, iterType, iters2)
        end, arg)
      end
    end
  end
  return (outArgs, outArg)
end

"""
  Helper function to traverseExpBidirFunctionArgs. Traverses the expressions in
  a named function argument.
"""
function traverseExpBidirNamedArg(
  inArg::NamedArg,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inExtra::Argument,
)::Tuple{NamedArg, Argument}
  local outExtra::Argument
  local outArg::NamedArg

  local name::Ident
  local value1::Exp
  local value2::Exp

  @match NAMEDARG(name, value1) = inArg
  @assign (value2, outExtra) = traverseExpBidir(value1, enterFunc, exitFunc, inExtra)
  @assign outArg = if referenceEq(value1, value2)
    inArg
  else
    NAMEDARG(name, value2)
  end
  return (outArg, outExtra)
end

"""
  Helper function to traverseExpBidirFunctionArgs. Traverses the expressions in
  an iterator.
"""
function traverseExpBidirIterator(
  inIterator::ForIterator,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{ForIterator, Argument}
  local outArg::Argument
  local outIterator::ForIterator

  local name::Ident
  local guardExp1::Option{Exp}
  local guardExp2::Option{Exp}
  local range1::Option{Exp}
  local range2::Option{Exp}

  @match ITERATOR(name = name, guardExp = guardExp1, range = range1) = inIterator
  @assign (guardExp2, outArg) = traverseExpOptBidir(guardExp1, enterFunc, exitFunc, inArg)
  @assign (range2, outArg) = traverseExpOptBidir(range1, enterFunc, exitFunc, outArg)
  @assign outIterator = if referenceEq(guardExp1, guardExp2) && referenceEq(range1, range2)
    inIterator
  else
    ITERATOR(name, guardExp2, range2)
  end
  return (outIterator, outArg)
end

function traverseMatchCase(
  inMatchCase::Case,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{Case, Argument}
  local outArg::Argument
  local outMatchCase::Case

  @assign (outMatchCase, outArg) = begin
    local arg::Argument
    local pattern::Exp
    local result::Exp
    local info::Info
    local resultInfo::Info
    local pinfo::Info
    local ldecls::List{ElementItem}
    local cp::ClassPart
    local cmt::Option{String}
    local patternGuard::Option{Exp}
    @match (inMatchCase, enterFunc, exitFunc, inArg) begin
      (
        CASE(pattern, patternGuard, pinfo, ldecls, cp, result, resultInfo, cmt, info),
        _,
        _,
        arg,
      ) => begin
        @assign (pattern, arg) = traverseExpBidir(pattern, enterFunc, exitFunc, arg)
        @assign (patternGuard, arg) =
          traverseExpOptBidir(patternGuard, enterFunc, exitFunc, arg)
        @assign (cp, arg) = traverseClassPartBidir(cp, enterFunc, exitFunc, arg)
        @assign (result, arg) = traverseExpBidir(result, enterFunc, exitFunc, arg)
        (CASE(pattern, patternGuard, pinfo, ldecls, cp, result, resultInfo, cmt, info), arg)
      end

      (
        ELSE(
          localDecls = ldecls,
          classPart = cp,
          result = result,
          resultInfo = resultInfo,
          comment = cmt,
          info = info,
        ),
        _,
        _,
        arg,
      ) => begin
        @assign (cp, arg) = traverseClassPartBidir(cp, enterFunc, exitFunc, arg)
        @assign (result, arg) = traverseExpBidir(result, enterFunc, exitFunc, arg)
        (ELSE(ldecls, cp, result, resultInfo, cmt, info), arg)
      end
    end
  end
  return (outMatchCase, outArg)
end

function traverseClassPartBidir(
  cp::ClassPart,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{ClassPart, Argument}
  local outArg::Argument
  local outCp::ClassPart

  @assign (outCp, outArg) = begin
    local algs::List{AlgorithmItem}
    local eqs::List{EquationItem}
    local arg::Argument
    @match (cp, enterFunc, exitFunc, inArg) begin
      (ALGORITHMS(algs), _, _, arg) => begin
        @assign (algs, arg) = ListUtil.map2FoldCheckReferenceEq(
          algs,
          traverseAlgorithmItemBidir,
          enterFunc,
          exitFunc,
          arg,
        )
        (ALGORITHMS(algs), arg)
      end

      (EQUATIONS(eqs), _, _, arg) => begin
        @assign (eqs, arg) = ListUtil.map2FoldCheckReferenceEq(
          eqs,
          traverseEquationItemBidir,
          enterFunc,
          exitFunc,
          arg,
        )
        (EQUATIONS(eqs), arg)
      end
    end
  end
  return (outCp, outArg)
end

function traverseEquationItemListBidir(
  inEquationItems::List{<:EquationItem},
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{List{EquationItem}, Argument}
  local outArg::Argument
  local outEquationItems::List{EquationItem}

  @assign (outEquationItems, outArg) = ListUtil.map2FoldCheckReferenceEq(
    inEquationItems,
    traverseEquationItemBidir,
    enterFunc,
    exitFunc,
    inArg,
  )
  return (outEquationItems, outArg)
end

function traverseAlgorithmItemListBidir(
  inAlgs::List{<:AlgorithmItem},
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{List{AlgorithmItem}, Argument}
  local outArg::Argument
  local outAlgs::List{AlgorithmItem}

  @assign (outAlgs, outArg) = ListUtil.map2FoldCheckReferenceEq(
    inAlgs,
    traverseAlgorithmItemBidir,
    enterFunc,
    exitFunc,
    inArg,
  )
  return (outAlgs, outArg)
end

function traverseAlgorithmItemBidir(
  inAlgorithmItem::AlgorithmItem,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{AlgorithmItem, Argument}
  local outArg::Argument
  local outAlgorithmItem::AlgorithmItem

  @assign (outAlgorithmItem, outArg) = begin
    local arg::Argument
    local alg::Algorithm
    local cmt::Option{Comment}
    local info::Info
    @match (inAlgorithmItem, enterFunc, exitFunc, inArg) begin
      (ALGORITHMITEM(algorithm_ = alg, comment = cmt, info = info), _, _, arg) => begin
        @assign (alg, arg) = traverseAlgorithmBidir(alg, enterFunc, exitFunc, arg)
        (ALGORITHMITEM(alg, cmt, info), arg)
      end

      (ALGORITHMITEMCOMMENT(__), _, _, _) => begin
        (inAlgorithmItem, inArg)
      end
    end
  end
  return (outAlgorithmItem, outArg)
end

function traverseEquationItemBidir(
  inEquationItem::EquationItem,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{EquationItem, Argument}
  local outArg::Argument
  local outEquationItem::EquationItem

  @assign (outEquationItem, outArg) = begin
    local arg::Argument
    local eq::Equation
    local cmt::Option{Comment}
    local info::Info
    @match (inEquationItem, enterFunc, exitFunc, inArg) begin
      (EQUATIONITEM(equation_ = eq, comment = cmt, info = info), _, _, arg) => begin
        @assign (eq, arg) = traverseEquationBidir(eq, enterFunc, exitFunc, arg)
        (EQUATIONITEM(eq, cmt, info), arg)
      end
    end
  end
  return (outEquationItem, outArg)
end

function traverseEquationBidir(
  inEquation::Equation,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{Equation, Argument}
  local outArg::Argument
  local outEquation::Equation

  @assign (outEquation, outArg) = begin
    local arg::Argument
    local e1::Exp
    local e2::Exp
    local eqil1::List{EquationItem}
    local eqil2::List{EquationItem}
    local else_branch::List{Tuple{Exp, List{EquationItem}}}
    local cref1::ComponentRef
    local cref2::ComponentRef
    local iters::ForIterators
    local func_args::FunctionArgs
    local eq::EquationItem
    @match (inEquation, enterFunc, exitFunc, inArg) begin
      (
        EQ_IF(
          ifExp = e1,
          equationTrueItems = eqil1,
          elseIfBranches = else_branch,
          equationElseItems = eqil2,
        ),
        _,
        _,
        arg,
      ) => begin
        @assign (e1, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (eqil1, arg) =
          traverseEquationItemListBidir(eqil1, enterFunc, exitFunc, arg)
        @assign (else_branch, arg) = ListUtil.map2FoldCheckReferenceEq(
          else_branch,
          traverseEquationBidirElse,
          enterFunc,
          exitFunc,
          arg,
        )
        @assign (eqil2, arg) =
          traverseEquationItemListBidir(eqil2, enterFunc, exitFunc, arg)
        (EQ_IF(e1, eqil1, else_branch, eqil2), arg)
      end

      (EQ_EQUALS(leftSide = e1, rightSide = e2), _, _, arg) => begin
        @assign (e1, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (e2, arg) = traverseExpBidir(e2, enterFunc, exitFunc, arg)
        (EQ_EQUALS(e1, e2), arg)
      end

      (EQ_PDE(leftSide = e1, rightSide = e2, domain = cref1), _, _, arg) => begin
        @assign (e1, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (e2, arg) = traverseExpBidir(e2, enterFunc, exitFunc, arg)
        @assign cref1 = traverseExpBidirCref(cref1, enterFunc, exitFunc, arg)
        (EQ_PDE(e1, e2, cref1), arg)
      end

      (EQ_CONNECT(connector1 = cref1, connector2 = cref2), _, _, arg) => begin
        @assign (cref1, arg) = traverseExpBidirCref(cref1, enterFunc, exitFunc, arg)
        @assign (cref2, arg) = traverseExpBidirCref(cref2, enterFunc, exitFunc, arg)
        (EQ_CONNECT(cref1, cref2), arg)
      end

      (EQ_FOR(iterators = iters, forEquations = eqil1), _, _, arg) => begin
        @assign (iters, arg) = ListUtil.map2FoldCheckReferenceEq(
          iters,
          traverseExpBidirIterator,
          enterFunc,
          exitFunc,
          arg,
        )
        @assign (eqil1, arg) =
          traverseEquationItemListBidir(eqil1, enterFunc, exitFunc, arg)
        (EQ_FOR(iters, eqil1), arg)
      end

      (
        EQ_WHEN_E(whenExp = e1, whenEquations = eqil1, elseWhenEquations = else_branch),
        _,
        _,
        arg,
      ) => begin
        @assign (e1, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (eqil1, arg) =
          traverseEquationItemListBidir(eqil1, enterFunc, exitFunc, arg)
        @assign (else_branch, arg) = ListUtil.map2FoldCheckReferenceEq(
          else_branch,
          traverseEquationBidirElse,
          enterFunc,
          exitFunc,
          arg,
        )
        (EQ_WHEN_E(e1, eqil1, else_branch), arg)
      end

      (EQ_NORETCALL(functionName = cref1, functionArgs = func_args), _, _, arg) => begin
        @assign (cref1, arg) = traverseExpBidirCref(cref1, enterFunc, exitFunc, arg)
        @assign (func_args, arg) =
          traverseExpBidirFunctionArgs(func_args, enterFunc, exitFunc, arg)
        (EQ_NORETCALL(cref1, func_args), arg)
      end

      (EQ_FAILURE(equ = eq), _, _, arg) => begin
        @assign (eq, arg) = traverseEquationItemBidir(eq, enterFunc, exitFunc, arg)
        (EQ_FAILURE(eq), arg)
      end
    end
  end
  return (outEquation, outArg)
end

function traverseEquationBidirElse(
  inElse::Tuple{<:Exp, List{<:EquationItem}},
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{Tuple{Exp, List{EquationItem}}, Argument}
  local arg::Argument
  local outElse::Tuple{Exp, List{EquationItem}}

  local e::Exp
  local eqil::List{EquationItem}

  @assign (e, eqil) = inElse
  @assign (e, arg) = traverseExpBidir(e, enterFunc, exitFunc, inArg)
  @assign (eqil, arg) = traverseEquationItemListBidir(eqil, enterFunc, exitFunc, arg)
  @assign outElse = (e, eqil)
  return (outElse, arg)
end

function traverseAlgorithmBidirElse(
  inElse::Tuple{<:Exp, List{<:AlgorithmItem}},
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{Tuple{Exp, List{AlgorithmItem}}, Argument}
  local arg::Argument
  local outElse::Tuple{Exp, List{AlgorithmItem}}

  local e::Exp
  local algs::List{AlgorithmItem}

  @assign (e, algs) = inElse
  @assign (e, arg) = traverseExpBidir(e, enterFunc, exitFunc, inArg)
  @assign (algs, arg) = traverseAlgorithmItemListBidir(algs, enterFunc, exitFunc, arg)
  @assign outElse = (e, algs)
  return (outElse, arg)
end

function traverseAlgorithmBidir(
  inAlg::Algorithm,
  enterFunc::FuncType,
  exitFunc::FuncType,
  inArg::Argument,
)::Tuple{Algorithm, Argument}
  local outArg::Argument
  local outAlg::Algorithm

  @assign (outAlg, outArg) = begin
    local arg::Argument
    local e1::Exp
    local e2::Exp
    local algs1::List{AlgorithmItem}
    local algs2::List{AlgorithmItem}
    local else_branch::List{Tuple{Exp, List{AlgorithmItem}}}
    local cref1::ComponentRef
    local cref2::ComponentRef
    local iters::ForIterators
    local func_args::FunctionArgs
    local alg::AlgorithmItem
    @match (inAlg, enterFunc, exitFunc, inArg) begin
      (ALG_ASSIGN(e1, e2), _, _, arg) => begin
        @assign (e1, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (e2, arg) = traverseExpBidir(e2, enterFunc, exitFunc, arg)
        (ALG_ASSIGN(e1, e2), arg)
      end

      (ALG_IF(e1, algs1, else_branch, algs2), _, _, arg) => begin
        @assign (e1, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (algs1, arg) =
          traverseAlgorithmItemListBidir(algs1, enterFunc, exitFunc, arg)
        @assign (else_branch, arg) = ListUtil.map2FoldCheckReferenceEq(
          else_branch,
          traverseAlgorithmBidirElse,
          enterFunc,
          exitFunc,
          arg,
        )
        @assign (algs2, arg) =
          traverseAlgorithmItemListBidir(algs2, enterFunc, exitFunc, arg)
        (ALG_IF(e1, algs1, else_branch, algs2), arg)
      end

      (ALG_FOR(iters, algs1), _, _, arg) => begin
        @assign (iters, arg) = ListUtil.map2FoldCheckReferenceEq(
          iters,
          traverseExpBidirIterator,
          enterFunc,
          exitFunc,
          arg,
        )
        @assign (algs1, arg) =
          traverseAlgorithmItemListBidir(algs1, enterFunc, exitFunc, arg)
        (ALG_FOR(iters, algs1), arg)
      end

      (ALG_PARFOR(iters, algs1), _, _, arg) => begin
        @assign (iters, arg) = ListUtil.map2FoldCheckReferenceEq(
          iters,
          traverseExpBidirIterator,
          enterFunc,
          exitFunc,
          arg,
        )
        @assign (algs1, arg) =
          traverseAlgorithmItemListBidir(algs1, enterFunc, exitFunc, arg)
        (ALG_PARFOR(iters, algs1), arg)
      end

      (ALG_WHILE(e1, algs1), _, _, arg) => begin
        @assign (e1, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (algs1, arg) =
          traverseAlgorithmItemListBidir(algs1, enterFunc, exitFunc, arg)
        (ALG_WHILE(e1, algs1), arg)
      end

      (ALG_WHEN_A(e1, algs1, else_branch), _, _, arg) => begin
        @assign (e1, arg) = traverseExpBidir(e1, enterFunc, exitFunc, arg)
        @assign (algs1, arg) =
          traverseAlgorithmItemListBidir(algs1, enterFunc, exitFunc, arg)
        @assign (else_branch, arg) = ListUtil.map2FoldCheckReferenceEq(
          else_branch,
          traverseAlgorithmBidirElse,
          enterFunc,
          exitFunc,
          arg,
        )
        (ALG_WHEN_A(e1, algs1, else_branch), arg)
      end

      (ALG_NORETCALL(cref1, func_args), _, _, arg) => begin
        @assign (cref1, arg) = traverseExpBidirCref(cref1, enterFunc, exitFunc, arg)
        @assign (func_args, arg) =
          traverseExpBidirFunctionArgs(func_args, enterFunc, exitFunc, arg)
        (ALG_NORETCALL(cref1, func_args), arg)
      end

      (ALG_RETURN(__), _, _, arg) => begin
        (inAlg, arg)
      end

      (ALG_BREAK(__), _, _, arg) => begin
        (inAlg, arg)
      end

      (ALG_CONTINUE(__), _, _, arg) => begin
        (inAlg, arg)
      end

      (ALG_FAILURE(algs1), _, _, arg) => begin
        @assign (algs1, arg) =
          traverseAlgorithmItemListBidir(algs1, enterFunc, exitFunc, arg)
        (ALG_FAILURE(algs1), arg)
      end

      (ALG_TRY(algs1, algs2), _, _, arg) => begin
        @assign (algs1, arg) =
          traverseAlgorithmItemListBidir(algs1, enterFunc, exitFunc, arg)
        @assign (algs2, arg) =
          traverseAlgorithmItemListBidir(algs2, enterFunc, exitFunc, arg)
        (ALG_TRY(algs1, algs2), arg)
      end
    end
  end
  return (outAlg, outArg)
end

function makeIdentPathFromString(s::String)::Path
  local p::Path

  @assign p = IDENT(s)
  return p
end

"""returns the class name of a Class as a Path"""
function className(cl::Class)::Path
  local name::Path

  local id::String

  @match CLASS(name = id) = cl
  @assign name = IDENT(id)
  return name
end

"""
  The ElementSpec type contains the name of the element, and this function
  extracts this name.
"""
function elementSpecName(inElementSpec::ElementSpec)::Ident
  local outIdent::Ident

  @assign outIdent = begin
    local n::Ident
    @match inElementSpec begin
      CLASSDEF(class_ = CLASS(name = n)) => begin
        n
      end

      COMPONENTS(components = COMPONENTITEM(component = COMPONENT(name = n)) <| nil()) =>
        begin
          n
        end
    end
  end
  return outIdent
end

"""returns the string of an expression if it is a string constant."""
function expString(exp::Exp)::String
  local str::String

  @match STRING(str) = exp
  return str
end

"""returns the componentRef of an expression if matches."""
function expCref(exp::Exp)::ComponentRef
  local cr::ComponentRef

  @match CREF(cr) = exp
  return cr
end

"""returns the componentRef of an expression if matches."""
function crefExp(cr::ComponentRef)::Exp
  local exp::Exp

  @assign exp = CREF(cr)
  return exp
end

function printComponentRefStr(cr::ComponentRef)::String
  local ostring::String

  @assign ostring = begin
    local s1::String
    local s2::String
    local child::ComponentRef
    @match cr begin
      CREF_IDENT(s1, _) => begin
        s1
      end

      CREF_QUAL(s1, _, child) => begin
        @assign s2 = printComponentRefStr(child)
        @assign s1 = s1 + "." + s2
        s1
      end

      CREF_FULLYQUALIFIED(child) => begin
        @assign s2 = printComponentRefStr(child)
        @assign s1 = "." + s2
        s1
      end

      ALLWILD(__) => begin
        "__"
      end

      WILD(__) => begin
        "_"
      end
    end
  end
  return ostring
end

"""Returns true if two paths are equal."""
function pathEqual(inPath1::Path, inPath2::Path)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    local id1::String
    local id2::String
    local res::Bool
    local path1::Path
    local path2::Path
    #=  fully qual vs. path
    =#
    @match (inPath1, inPath2) begin
      (FULLYQUALIFIED(path1), path2) => begin
        pathEqual(path1, path2)
      end

      (path1, FULLYQUALIFIED(path2)) => begin
        pathEqual(path1, path2)
      end

      (IDENT(id1), IDENT(id2)) => begin
        stringEq(id1, id2)
      end

      (QUALIFIED(id1, path1), QUALIFIED(id2, path2)) => begin
        @assign res = if stringEq(id1, id2)
          pathEqual(path1, path2)
        else
          false
        end
        res
      end

      _ => begin
        false
      end
    end
  end
  #=  path vs. fully qual
  =#
  #=  ident vs. ident
  =#
  #=  qual ident vs. qual ident
  =#
  #=  other return false
  =#
  return outBoolean
end

"""
  Author BZ 2009-01
  Check whether two type specs are equal or not.
"""
function typeSpecEqual(a::TypeSpec, b::TypeSpec)::Bool
  local ob::Bool

  @assign ob = begin
    local p1::Path
    local p2::Path
    local oad1::Option{ArrayDim}
    local oad2::Option{ArrayDim}
    local lst1::List{TypeSpec}
    local lst2::List{TypeSpec}
    local i1::Ident
    local i2::Ident
    local pos1::Int
    local pos2::Int
    #=  first try full equality
    =#
    @matchcontinue (a, b) begin
      (TPATH(p1, oad1), TPATH(p2, oad2)) => begin
        @match true = pathEqual(p1, p2)
        @match true = optArrayDimEqual(oad1, oad2)
        true
      end

      (TCOMPLEX(p1, lst1, oad1), TCOMPLEX(p2, lst2, oad2)) => begin
        @match true = pathEqual(p1, p2)
        @match true = ListUtil.isEqualOnTrue(lst1, lst2, typeSpecEqual)
        @match true = optArrayDimEqual(oad1, oad2)
        true
      end

      _ => begin
        false
      end
    end
  end
  return ob
end

"""
  Author BZ
  helper function for typeSpecEqual
"""
function optArrayDimEqual(oad1::Option{<:ArrayDim}, oad2::Option{<:ArrayDim})::Bool
  local b::Bool

  @assign b = begin
    local ad1::List{Subscript}
    local ad2::List{Subscript}
    @matchcontinue (oad1, oad2) begin
      (SOME(ad1), SOME(ad2)) => begin
        @match true = ListUtil.isEqualOnTrue(ad1, ad2, subscriptEqual)
        true
      end

      (NONE(), NONE()) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return b
end

"""This function simply converts a Path to a string."""
function typeSpecPathString(tp::TypeSpec)::String
  local s::String

  @assign s = begin
    local p::Path
    @match tp begin
      TCOMPLEX(path = p) => begin
        pathString(p)
      end

      TPATH(path = p) => begin
        pathString(p)
      end
    end
  end
  return s
end

"""Converts a TypeSpec to Path"""
function typeSpecPath(tp::TypeSpec)::Path
  local op::Path

  @assign op = begin
    local p::Path
    @match tp begin
      TCOMPLEX(path = p) => begin
        p
      end

      TPATH(path = p) => begin
        p
      end
    end
  end
  return op
end

"""Returns the dimensions of a TypeSpec."""
function typeSpecDimensions(inTypeSpec::TypeSpec)::ArrayDim
  local outDimensions::ArrayDim

  @assign outDimensions = begin
    local dim::ArrayDim
    @match inTypeSpec begin
      TPATH(arrayDim = SOME(dim)) => begin
        dim
      end

      TCOMPLEX(arrayDim = SOME(dim)) => begin
        dim
      end

      _ => begin
        nil
      end
    end
  end
  return outDimensions
end

"""This function simply converts a Path to a string."""
function pathString(
  path::Path,
  delimiter::String = ".",
  usefq::Bool = true,
  reverse::Bool = false,
)::String
  local s::String
  local p1::Path
  local p2::Path
  local count::Int = 0
  local len::Int = 0
  local dlen::Int = stringLength(delimiter)
  local b::Bool

  #=  First, calculate the length of the string to be generated
  =#
  @assign p1 = if usefq
    path
  else
    makeNotFullyQualified(path)
  end
  _ = begin
    @match p1 begin
      IDENT(__) => begin
        #=  Do not allocate memory if we're just going to copy the only identifier
        =#
        @assign s = p1.name
        return s
        ()
      end
      _ => begin
        ()
      end
    end
  end
  @assign p2 = p1
  @assign b = true
  while b
    @assign (p2, len, count, b) = begin
      @match p2 begin
        IDENT(__) => begin
          (p2, len + 1, count + stringLength(p2.name), false)
        end

        QUALIFIED(__) => begin
          (p2.path, len + 1, count + stringLength(p2.name), true)
        end

        FULLYQUALIFIED(__) => begin
          (p2.path, len + 1, count, true)
        end
      end
    end
  end
  @assign s = pathStringWork(p1, (len - 1) * dlen + count, delimiter, dlen, reverse)
  return s
end

"""
I rewrote this to not use the string allocator - John
"""
function pathStringWork(
  inPath::Path,
  len::Int,
  delimiter::String,
  dlen::Int,
  reverse::Bool,
)::String
  local s::String = ""
  local p::Path = inPath
  local b::Bool = true
  local count::Int = 0
  #=  Allocate a string of the exact required length
  =#
  local sb = IOBuffer() #System.StringAllocator = System.StringAllocator(len)

  #=  Fill the string
  =#
  while b
    (p, count, b) = begin
      @match p begin
        IDENT(__) => begin
          print(sb, p.name)
          (p, count + stringLength(p.name), false)
        end

        QUALIFIED(__) => begin
          # System.stringAllocatorStringCopy(
          #   sb,
          #   p.name,
          #   if reverse
          #     len - count - dlen - stringLength(p.name)
          #   else
          #     count
          #   end,
          # )
          # System.stringAllocatorStringCopy(sb, delimiter, if reverse
          #     len - count - dlen
          #   else
          #     count + stringLength(p.name)
          #   end)
          print(sb, p.name)
          print(sb, delimiter)
          (p.path, count + stringLength(p.name) + dlen, true)
        end

        FULLYQUALIFIED(__) => begin
          # System.stringAllocatorStringCopy(sb, delimiter, if reverse
          #   len - count - dlen
          # else
          #   count
          # end)
          print(sb, delimiter)
          (p.path, count + dlen, true)
        end
      end
    end
  end
  #=  Return the string
  =#
  s = String(take!(sb))
  #  @info s
  return s
end

function pathStringNoQual(path::Path, delimiter::String = ".",
                          usefq::Bool = false, reverse::Bool = false)
  return pathString(path, delimiter, usefq, reverse)
end

function pathStringDefault(path::Path)::String
  local s::String = pathString(path)
  return s
end

function pathCompare(ip1::Path, ip2::Path)::Int
  local o::Int

  @assign o = begin
    local p1::Path
    local p2::Path
    local i1::String
    local i2::String
    @match (ip1, ip2) begin
      (FULLYQUALIFIED(p1), FULLYQUALIFIED(p2)) => begin
        pathCompare(p1, p2)
      end

      (FULLYQUALIFIED(__), _) => begin
        1
      end

      (_, FULLYQUALIFIED(__)) => begin
        -1
      end

      (QUALIFIED(i1, p1), QUALIFIED(i2, p2)) => begin
        @assign o = stringCompare(i1, i2)
        @assign o = if o == 0
          pathCompare(p1, p2)
        else
          o
        end
        o
      end

      (QUALIFIED(__), _) => begin
        1
      end

      (_, QUALIFIED(__)) => begin
        -1
      end

      (IDENT(i1), IDENT(i2)) => begin
        stringCompare(i1, i2)
      end
    end
  end
  return o
end

function pathCompareNoQual(ip1::Path, ip2::Path)::Int
  local o::Int

  @assign o = begin
    local p1::Path
    local p2::Path
    local i1::String
    local i2::String
    @match (ip1, ip2) begin
      (FULLYQUALIFIED(p1), p2) => begin
        pathCompareNoQual(p1, p2)
      end

      (p1, FULLYQUALIFIED(p2)) => begin
        pathCompareNoQual(p1, p2)
      end

      (QUALIFIED(i1, p1), QUALIFIED(i2, p2)) => begin
        @assign o = stringCompare(i1, i2)
        @assign o = if o == 0
          pathCompare(p1, p2)
        else
          o
        end
        o
      end

      (QUALIFIED(__), _) => begin
        1
      end

      (_, QUALIFIED(__)) => begin
        -1
      end

      (IDENT(i1), IDENT(i2)) => begin
        stringCompare(i1, i2)
      end
    end
  end
  return o
end

function pathHashWork(path::Path, acc::UInt64)::UInt64
  return @match path begin
    FULLYQUALIFIED(p) => pathHashWork(p, acc)
    QUALIFIED(s, p) => pathHashWork(p, hash(s, acc))
    IDENT(s) => hash(s, acc)
  end
end

"""Hashes a path."""
function pathHashModWork(path::Path, acc::Int)::Int
  local hash::Int

  @assign hash = begin
    local p::Path
    local s::String
    local i::Int
    local i2::Int
    @match (path, acc) begin
      (FULLYQUALIFIED(p), _) => begin
        pathHashModWork(p, acc * 31 + 46)
      end

      (QUALIFIED(s, p), _) => begin
        @assign i = stringHashDjb2(s)
        @assign i2 = acc * 31 + 46
        pathHashModWork(p, i2 * 31 + i)
      end

      (IDENT(s), _) => begin
        @assign i = stringHashDjb2(s)
        @assign i2 = acc * 31 + 46
        i2 * 31 + i
      end
    end
  end
  #= /* '.' */ =#
  return hash
end

"""Converts a string into a qualified path."""
function stringPath(str::String)::Path
  local qualifiedPath::Path
  local paths::List{String}
  paths = arrayList(split(str, ".")) #Util.stringSplitAtChar(str, ".")
  qualifiedPath = stringListPath(paths)
  return qualifiedPath
end

"""Converts a list of strings into a qualified path."""
function stringListPath(paths::List{<:String})::Path
  local qualifiedPath::Path

  @assign qualifiedPath = begin
    local str::String
    local rest_str::List{String}
    local p::Path
    @matchcontinue paths begin
      nil() => begin
        fail()
      end

      str <| nil() => begin
        IDENT(str)
      end

      str <| rest_str => begin
        @assign p = stringListPath(rest_str)
        QUALIFIED(str, p)
      end
    end
  end
  return qualifiedPath
end

function stringListPathReversed2(inStrings::List{<:String}, inAccumPath::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local id::String
    local rest_str::List{String}
    local path::Path
    @match (inStrings, inAccumPath) begin
      (nil(), _) => begin
        inAccumPath
      end

      (id <| rest_str, _) => begin
        @assign path = QUALIFIED(id, inAccumPath)
        stringListPathReversed2(rest_str, path)
      end
    end
  end
  return outPath
end

"""Returns the two last idents of a path"""
function pathTwoLastIdents(inPath::Path)::Path
  local outTwoLast::Path

  @assign outTwoLast = begin
    local p::Path
    @match inPath begin
      QUALIFIED(path = IDENT(__)) => begin
        inPath
      end

      QUALIFIED(path = p) => begin
        pathTwoLastIdents(p)
      end

      FULLYQUALIFIED(path = p) => begin
        pathTwoLastIdents(p)
      end
    end
  end
  return outTwoLast
end

"""Returns the last ident (after last dot) in a path"""
function pathLastIdent(inPath::Path)::String
  local outIdent::String

  @assign outIdent = begin
    local id::Ident
    local p::Path
    @match inPath begin
      QUALIFIED(path = p) => begin
        pathLastIdent(p)
      end

      IDENT(name = id) => begin
        id
      end

      FULLYQUALIFIED(path = p) => begin
        pathLastIdent(p)
      end
    end
  end
  return outIdent
end

"""Returns the last ident (after last dot) in a path"""
function pathLast(path::Path)::Path

  @assign path = begin
    local p::Path
    @match path begin
      QUALIFIED(path = p) => begin
        pathLast(p)
      end

      IDENT(__) => begin
        path
      end

      FULLYQUALIFIED(path = p) => begin
        pathLast(p)
      end
    end
  end
  return path
end

"""Returns the first ident (before first dot) in a path"""
function pathFirstIdent(inPath::Path)::Ident
  local outIdent::Ident

  @assign outIdent = begin
    local n::Ident
    local p::Path
    @match inPath begin
      FULLYQUALIFIED(path = p) => begin
        pathFirstIdent(p)
      end

      QUALIFIED(name = n) => begin
        n
      end

      IDENT(name = n) => begin
        n
      end
    end
  end
  return outIdent
end

function pathFirstPath(inPath::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local n::Ident
    @match inPath begin
      IDENT(__) => begin
        inPath
      end

      QUALIFIED(name = n) => begin
        IDENT(n)
      end

      FULLYQUALIFIED(path = outPath) => begin
        pathFirstPath(outPath)
      end
    end
  end
  return outPath
end

function pathSecondIdent(inPath::Path)::Ident
  local outIdent::Ident

  @assign outIdent = begin
    local n::Ident
    local p::Path
    @match inPath begin
      QUALIFIED(path = QUALIFIED(name = n)) => begin
        n
      end

      QUALIFIED(path = IDENT(name = n)) => begin
        n
      end

      FULLYQUALIFIED(path = p) => begin
        pathSecondIdent(p)
      end
    end
  end
  return outIdent
end

function pathRest(inPath::Path)::Path
  local outPath::Path

  @assign outPath = begin
    @match inPath begin
      QUALIFIED(path = outPath) => begin
        outPath
      end

      FULLYQUALIFIED(path = outPath) => begin
        pathRest(outPath)
      end
    end
  end
  return outPath
end

"""strips the same prefix paths and returns the stripped path. e.g pathStripSamePrefix(P.M.A, P.M.B) => A"""
function pathStripSamePrefix(inPath1::Absyn.Path, inPath2::Absyn.Path)::Absyn.Path
  local outPath::Absyn.Path

  @assign outPath = begin
    local ident1::Ident
    local ident2::Ident
    local path1::Absyn.Path
    local path2::Absyn.Path
    @matchcontinue (inPath1, inPath2) begin
      (_, _) => begin
        @assign ident1 = pathFirstIdent(inPath1)
        @assign ident2 = pathFirstIdent(inPath2)
        @match true = stringEq(ident1, ident2)
        @assign path1 = stripFirst(inPath1)
        @assign path2 = stripFirst(inPath2)
        pathStripSamePrefix(path1, path2)
      end

      _ => begin
        inPath1
      end
    end
  end
  return outPath
end

"""Returns the prefix of a path, i.e. this.is.a.path => this.is.a"""
function pathPrefix(path::Path)::Path
  local prefix::Path

  @assign prefix = begin
    local p::Path
    local n::Ident
    @matchcontinue path begin
      FULLYQUALIFIED(path = p) => begin
        pathPrefix(p)
      end

      QUALIFIED(name = n, path = IDENT(__)) => begin
        IDENT(n)
      end

      QUALIFIED(name = n, path = p) => begin
        @assign p = pathPrefix(p)
        QUALIFIED(n, p)
      end
    end
  end
  return prefix
end

"""Prefixes a path with an identifier."""
function prefixPath(prefix::Ident, path::Path)::Path
  local outPath::Path

  @assign outPath = QUALIFIED(prefix, path)
  return outPath
end

"""
  Adds a suffix to a path. Ex:
  suffixPath(a.b.c, 'd') => a.b.c.d
"""
function suffixPath(inPath::Path, inSuffix::Ident)::Path
  local outPath::Path

  @assign outPath = begin
    local name::Ident
    local path::Path
    @match (inPath, inSuffix) begin
      (IDENT(name), _) => begin
        QUALIFIED(name, IDENT(inSuffix))
      end

      (QUALIFIED(name, path), _) => begin
        @assign path = suffixPath(path, inSuffix)
        QUALIFIED(name, path)
      end

      (FULLYQUALIFIED(path), _) => begin
        @assign path = suffixPath(path, inSuffix)
        FULLYQUALIFIED(path)
      end
    end
  end
  return outPath
end

"""returns true if suffix_path is a suffix of path"""
function pathSuffixOf(suffix_path::Path, path::Path)::Bool
  local res::Bool

  @assign res = begin
    local p::Path
    @matchcontinue (suffix_path, path) begin
      (_, _) => begin
        @match true = pathEqual(suffix_path, path)
        true
      end

      (_, FULLYQUALIFIED(path = p)) => begin
        pathSuffixOf(suffix_path, p)
      end

      (_, QUALIFIED(path = p)) => begin
        pathSuffixOf(suffix_path, p)
      end

      _ => begin
        false
      end
    end
  end
  return res
end

function pathToStringList(path::Path)::List{String}
  local outPaths::List{String}

  @assign outPaths = listReverse(pathToStringListWork(path, nil))
  return outPaths
end

function pathToStringListWork(path::Path, acc::List{<:String})::List{String}
  local outPaths::List{String}

  @assign outPaths = begin
    local n::String
    local p::Path
    local strings::List{String}
    @match (path, acc) begin
      (IDENT(name = n), _) => begin
        _cons(n, acc)
      end

      (FULLYQUALIFIED(path = p), _) => begin
        pathToStringListWork(p, acc)
      end

      (QUALIFIED(name = n, path = p), _) => begin
        pathToStringListWork(p, _cons(n, acc))
      end
    end
  end
  return outPaths
end

"""Function for appending subscripts at end of last ident"""
function addSubscriptsLast(icr::ComponentRef, i::List{<:Subscript})::ComponentRef
  local ocr::ComponentRef

  @assign ocr = begin
    local subs::List{Subscript}
    local id::String
    local cr::ComponentRef
    @match (icr, i) begin
      (CREF_IDENT(id, subs), _) => begin
        CREF_IDENT(id, listAppend(subs, i))
      end

      (CREF_QUAL(id, subs, cr), _) => begin
        @assign cr = addSubscriptsLast(cr, i)
        CREF_QUAL(id, subs, cr)
      end

      (CREF_FULLYQUALIFIED(cr), _) => begin
        @assign cr = addSubscriptsLast(cr, i)
        crefMakeFullyQualified(cr)
      end
    end
  end
  return ocr
end

"""
  Replaces the first part of a cref with a replacement path:
  (a[4].b.c[3], d.e) => d.e[4].b.c[3]
  (a[3], b.c.d) => b.c.d[3]
"""
function crefReplaceFirstIdent(icref::ComponentRef, replPath::Path)::ComponentRef
  local outCref::ComponentRef

  @assign outCref = begin
    local subs::List{Subscript}
    local cr::ComponentRef
    local cref::ComponentRef
    @match (icref, replPath) begin
      (CREF_FULLYQUALIFIED(componentRef = cr), _) => begin
        @assign cr = crefReplaceFirstIdent(cr, replPath)
        crefMakeFullyQualified(cr)
      end

      (CREF_QUAL(componentRef = cr, subscripts = subs), _) => begin
        @assign cref = pathToCref(replPath)
        @assign cref = addSubscriptsLast(cref, subs)
        joinCrefs(cref, cr)
      end

      (CREF_IDENT(subscripts = subs), _) => begin
        @assign cref = pathToCref(replPath)
        @assign cref = addSubscriptsLast(cref, subs)
        cref
      end
    end
  end
  return outCref
end

"""Returns true if prefixPath is a prefix of path, false otherwise."""
function pathPrefixOf(prefixPath::Path, path::Path)::Bool
  local isPrefix::Bool

  @assign isPrefix = begin
    local p::Path
    local p2::Path
    local id::String
    local id2::String
    @matchcontinue (prefixPath, path) begin
      (FULLYQUALIFIED(p), p2) => begin
        pathPrefixOf(p, p2)
      end

      (p, FULLYQUALIFIED(p2)) => begin
        pathPrefixOf(p, p2)
      end

      (IDENT(id), IDENT(id2)) => begin
        stringEq(id, id2)
      end

      (IDENT(id), QUALIFIED(name = id2)) => begin
        stringEq(id, id2)
      end

      (QUALIFIED(id, p), QUALIFIED(id2, p2)) => begin
        @match true = stringEq(id, id2)
        @match true = pathPrefixOf(p, p2)
        true
      end

      _ => begin
        false
      end
    end
  end
  return isPrefix
end

"""
  Alternative names: crefIsPrefixOf, isPrefixOf, prefixOf
  Author: DH 2010-03

  Returns true if prefixCr is a prefix of cr, i.e., false otherwise.
  Subscripts are NOT checked.
"""
function crefPrefixOf(prefixCr::ComponentRef, cr::ComponentRef)::Bool
  local out::Bool

  @assign out = begin
    @matchcontinue (prefixCr, cr) begin
      (_, _) => begin
        @match true = crefEqualNoSubs(prefixCr, cr)
        true
      end

      (_, _) => begin
        crefPrefixOf(prefixCr, crefStripLast(cr))
      end

      _ => begin
        false
      end
    end
  end
  return out
end

"""removes the prefix_path from path, and returns the rest of path"""
function removePrefix(prefix_path::Path, path::Path)::Path
  local newPath::Path

  @assign newPath = begin
    local p::Path
    local p2::Path
    local id1::Ident
    local id2::Ident
    #=  fullyqual path
    =#
    @match (prefix_path, path) begin
      (p, FULLYQUALIFIED(p2)) => begin
        removePrefix(p, p2)
      end

      (QUALIFIED(name = id1, path = p), QUALIFIED(name = id2, path = p2)) => begin
        @match true = stringEq(id1, id2)
        removePrefix(p, p2)
      end

      (IDENT(id1), QUALIFIED(name = id2, path = p2)) => begin
        @match true = stringEq(id1, id2)
        p2
      end
    end
  end
  #=  qual
  =#
  #=  ids
  =#
  return newPath
end

"""
  Tries to remove a given prefix from a path with removePrefix. If it fails it
  removes the first identifier in the prefix and tries again, until it either
  succeeds or reaches the end of the prefix. Ex:
  removePartialPrefix(A.B.C, B.C.D.E) => D.E
"""
function removePartialPrefix(inPrefix::Path, inPath::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local p::Path
    @matchcontinue (inPrefix, inPath) begin
      (_, _) => begin
        @assign p = removePrefix(inPrefix, inPath)
        p
      end

      (QUALIFIED(path = p), _) => begin
        @assign p = removePrefix(p, inPath)
        p
      end

      (FULLYQUALIFIED(path = p), _) => begin
        @assign p = removePartialPrefix(p, inPath)
        p
      end

      _ => begin
        inPath
      end
    end
  end
  return outPath
end

"""
  function: crefRemovePrefix
  Alternative names: removePrefix
  Author: DH 2010-03

  If prefixCr is a prefix of cr, removes prefixCr from cr and returns the remaining reference,
  otherwise fails. Subscripts are NOT checked.
"""
function crefRemovePrefix(prefixCr::ComponentRef, cr::ComponentRef)::ComponentRef
  local out::ComponentRef

  @assign out = begin
    local prefixIdent::Ident
    local ident::Ident
    local prefixRestCr::ComponentRef
    local restCr::ComponentRef
    #=  fqual
    =#
    @match (prefixCr, cr) begin
      (
        CREF_FULLYQUALIFIED(componentRef = prefixRestCr),
        CREF_FULLYQUALIFIED(componentRef = restCr),
      ) => begin
        crefRemovePrefix(prefixRestCr, restCr)
      end

      (
        CREF_QUAL(name = prefixIdent, componentRef = prefixRestCr),
        CREF_QUAL(name = ident, componentRef = restCr),
      ) => begin
        @match true = stringEq(prefixIdent, ident)
        crefRemovePrefix(prefixRestCr, restCr)
      end

      (CREF_IDENT(name = prefixIdent), CREF_QUAL(name = ident, componentRef = restCr)) =>
        begin
          @match true = stringEq(prefixIdent, ident)
          restCr
        end

      (CREF_IDENT(name = prefixIdent), CREF_IDENT(name = ident)) => begin
        @match true = stringEq(prefixIdent, ident)
        CREF_IDENT("", nil)
      end
    end
  end
  #=  qual
  =#
  #=  id vs. qual
  =#
  #=  id vs. id
  =#
  return out
end

"""
  Author BZ,
  checks if one IDENT(..) is contained in path.
"""
function pathContains(fullPath::Path, pathId::Path)::Bool
  local b::Bool

  @assign b = begin
    local str1::String
    local str2::String
    local qp::Path
    local b1::Bool
    local b2::Bool
    @match (fullPath, pathId) begin
      (IDENT(str1), IDENT(str2)) => begin
        stringEq(str1, str2)
      end

      (QUALIFIED(str1, qp), IDENT(str2)) => begin
        @assign b1 = stringEq(str1, str2)
        @assign b2 = pathContains(qp, pathId)
        @assign b1 = boolOr(b1, b2)
        b1
      end

      (FULLYQUALIFIED(qp), _) => begin
        pathContains(qp, pathId)
      end
    end
  end
  return b
end

"""
  Author OT,
  checks if Path contains the given string.
"""
function pathContainsString(p1::Path, str::String)::Bool
  local b::Bool

  @assign b = begin
    local str1::String
    local searchStr::String
    local qp::Path
    local b1::Bool
    local b2::Bool
    local b3::Bool
    @match (p1, str) begin
      (IDENT(str1), searchStr) => begin
        @assign b1 = System.stringFind(str1, searchStr) != (-1)
        b1
      end

      (QUALIFIED(str1, qp), searchStr) => begin
        @assign b1 = System.stringFind(str1, searchStr) != (-1)
        @assign b2 = pathContainsString(qp, searchStr)
        @assign b3 = boolOr(b1, b2)
        b3
      end

      (FULLYQUALIFIED(qp), searchStr) => begin
        pathContainsString(qp, searchStr)
      end
    end
  end
  return b
end

"""
  This function checks if subPath is contained in path.
  If it is the complete path is returned. Otherwise the function fails.
  For example,
  pathContainedIn( C.D, A.B.C) => A.B.C.D
  pathContainedIn(C.D, A.B.C.D) => A.B.C.D
  pathContainedIn(A.B.C.D, A.B.C.D) => A.B.C.D
  pathContainedIn(B.C,A.B) => A.B.C
"""
function pathContainedIn(subPath::Path, path::Path)::Path
  local completePath::Path

  @assign completePath = begin
    local ident::Ident
    local newPath::Path
    local newSubPath::Path
    #=  A suffix, e.g. C.D in A.B.C.D
    =#
    @matchcontinue (subPath, path) begin
      (_, _) => begin
        @match true = pathSuffixOf(subPath, path)
        path
      end

      (_, _) => begin
        @assign ident = pathLastIdent(path)
        @assign newPath = stripLast(path)
        @assign newPath = pathContainedIn(subPath, newPath)
        joinPaths(newPath, IDENT(ident))
      end

      _ => begin
        @assign ident = pathLastIdent(subPath)
        @assign newSubPath = stripLast(subPath)
        @assign newSubPath = pathContainedIn(newSubPath, path)
        joinPaths(newSubPath, IDENT(ident))
      end
    end
  end
  #=  strip last ident of path and recursively check if suffix.
  =#
  #=  strip last ident of subpath and recursively check if suffix.
  =#
  return completePath
end

"""
  Author BZ 2009-08
  Function for getting ComponentRefs out from Subscripts
"""
function getCrefsFromSubs(
  isubs::List{<:Subscript},
  includeSubs::Bool,
  includeFunctions::Bool,
)::List{ComponentRef} #= note that if you say includeSubs = false then you won't get the functions from array subscripts =#
  local crefs::List{ComponentRef}

  @assign crefs = begin
    local crefs1::List{ComponentRef}
    local exp::Exp
    local subs::List{Subscript}
    @match (isubs, includeSubs, includeFunctions) begin
      (nil(), _, _) => begin
        nil
      end

      (NOSUB(__) <| subs, _, _) => begin
        getCrefsFromSubs(subs, includeSubs, includeFunctions)
      end

      (SUBSCRIPT(exp) <| subs, _, _) => begin
        @assign crefs1 = getCrefsFromSubs(subs, includeSubs, includeFunctions)
        @assign crefs = getCrefFromExp(exp, includeSubs, includeFunctions)
        listAppend(crefs, crefs1)
      end
    end
  end
  return crefs
end

"""
  Returns a flattened list of the
  component references in an expression
"""
function getCrefFromExp(
  inExp::Exp,
  includeSubs::Bool,
  includeFunctions::Bool,
)::List{ComponentRef} #= note that if you say includeSubs = false then you won't get the functions from array subscripts =#
  local outComponentRefLst::List{ComponentRef}

  @assign outComponentRefLst = begin
    local cr::ComponentRef
    local l1::List{ComponentRef}
    local l2::List{ComponentRef}
    local res::List{ComponentRef}
    local e1::ComponentCondition
    local e2::ComponentCondition
    local e3::ComponentCondition
    local op::Operator
    local e4::List{Tuple{ComponentCondition, ComponentCondition}}
    local farg::FunctionArgs
    local expl::List{ComponentCondition}
    local expll::List{List{ComponentCondition}}
    local subs::List{Subscript}
    local lstres1::List{List{ComponentRef}}
    local crefll::List{List{ComponentRef}}
    @match (inExp, includeSubs, includeFunctions) begin
      (INTEGER(__), _, _) => begin
        nil
      end

      (REAL(__), _, _) => begin
        nil
      end

      (STRING(__), _, _) => begin
        nil
      end

      (BOOL(__), _, _) => begin
        nil
      end

      (CREF(componentRef = ALLWILD(__)), _, _) => begin
        nil
      end

      (CREF(componentRef = WILD(__)), _, _) => begin
        nil
      end

      (CREF(componentRef = cr), false, _) => begin
        list(cr)
      end

      (CREF(componentRef = cr), true, _) => begin
        @assign subs = getSubsFromCref(cr, includeSubs, includeFunctions)
        @assign l1 = getCrefsFromSubs(subs, includeSubs, includeFunctions)
        _cons(cr, l1)
      end

      (BINARY(exp1 = e1, exp2 = e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (UNARY(exp = e1), _, _) => begin
        @assign res = getCrefFromExp(e1, includeSubs, includeFunctions)
        res
      end

      (LBINARY(exp1 = e1, exp2 = e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (LUNARY(exp = e1), _, _) => begin
        @assign res = getCrefFromExp(e1, includeSubs, includeFunctions)
        res
      end

      (RELATION(exp1 = e1, exp2 = e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (IFEXP(ifExp = e1, trueBranch = e2, elseBranch = e3), _, _) => begin
        ListUtil.flatten(list(
          getCrefFromExp(e1, includeSubs, includeFunctions),
          getCrefFromExp(e2, includeSubs, includeFunctions),
          getCrefFromExp(e3, includeSubs, includeFunctions),
        ))
      end

      (CALL(function_ = cr, functionArgs = farg), _, _) => begin
        @assign res = getCrefFromFarg(farg, includeSubs, includeFunctions)
        @assign res = if includeFunctions
          _cons(cr, res)
        else
          res
        end
        res
      end

      (PARTEVALFUNCTION(function_ = cr, functionArgs = farg), _, _) => begin
        @assign res = getCrefFromFarg(farg, includeSubs, includeFunctions)
        @assign res = if includeFunctions
          _cons(cr, res)
        else
          res
        end
        res
      end

      (ARRAY(arrayExp = expl), _, _) => begin
        @assign lstres1 = ListUtil.map2(expl, getCrefFromExp, includeSubs, includeFunctions)
        @assign res = ListUtil.flatten(lstres1)
        res
      end

      (MATRIX(matrix = expll), _, _) => begin
        @assign res = ListUtil.flatten(ListUtil.flatten(ListUtil.map2List(
          expll,
          getCrefFromExp,
          includeSubs,
          includeFunctions,
        )))
        res
      end

      (RANGE(start = e1, step = SOME(e3), stop = e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign l2 = listAppend(l1, l2)
        @assign l1 = getCrefFromExp(e3, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (RANGE(start = e1, step = NONE(), stop = e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (END(__), _, _) => begin
        nil
      end

      (TUPLE(expressions = expl), _, _) => begin
        @assign crefll = ListUtil.map2(expl, getCrefFromExp, includeSubs, includeFunctions)
        @assign res = ListUtil.flatten(crefll)
        res
      end

      (CODE(__), _, _) => begin
        nil
      end

      (AS(exp = e1), _, _) => begin
        getCrefFromExp(e1, includeSubs, includeFunctions)
      end

      (CONS(e1, e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (LIST(expl), _, _) => begin
        @assign crefll = ListUtil.map2(expl, getCrefFromExp, includeSubs, includeFunctions)
        @assign res = ListUtil.flatten(crefll)
        res
      end

      (MATCHEXP(__), _, _) => begin
        fail()
      end

      (DOT(__), _, _) => begin
        getCrefFromExp(inExp.exp, includeSubs, includeFunctions)
      end

      _ => begin
        Error.addInternalError(
          getInstanceName() + " failed " + printExp(inExp),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  #=  TODO: Handle else if-branches.
  =#
  #=  inExp.index is only allowed to contain names to index the function call; not crefs that are evaluated in any way
  =#
  return outComponentRefLst
end

"""
  Returns the flattened list of all component references
  present in a list of function arguments.
"""
function getCrefFromFarg(
  inFunctionArgs::FunctionArgs,
  includeSubs::Bool,
  includeFunctions::Bool,
)::List{ComponentRef} #= note that if you say includeSubs = false then you won't get the functions from array subscripts =#
  local outComponentRefLst::List{ComponentRef}

  @assign outComponentRefLst = begin
    local l1::List{List{ComponentRef}}
    local l2::List{List{ComponentRef}}
    local fl1::List{ComponentRef}
    local fl2::List{ComponentRef}
    local fl3::List{ComponentRef}
    local res::List{ComponentRef}
    local expl::List{ComponentCondition}
    local nargl::List{NamedArg}
    local iterators::ForIterators
    local exp::Exp
    @match (inFunctionArgs, includeSubs, includeFunctions) begin
      (FUNCTIONARGS(args = expl, argNames = nargl), _, _) => begin
        @assign l1 = ListUtil.map2(expl, getCrefFromExp, includeSubs, includeFunctions)
        @assign fl1 = ListUtil.flatten(l1)
        @assign l2 = ListUtil.map2(nargl, getCrefFromNarg, includeSubs, includeFunctions)
        @assign fl2 = ListUtil.flatten(l2)
        @assign res = listAppend(fl1, fl2)
        res
      end

      (FOR_ITER_FARG(exp, _, iterators), _, _) => begin
        @assign l1 = ListUtil.map2Option(
          ListUtil.map(iterators, iteratorRange),
          getCrefFromExp,
          includeSubs,
          includeFunctions,
        )
        @assign l2 = ListUtil.map2Option(
          ListUtil.map(iterators, iteratorGuard),
          getCrefFromExp,
          includeSubs,
          includeFunctions,
        )
        @assign fl1 = ListUtil.flatten(l1)
        @assign fl2 = ListUtil.flatten(l2)
        @assign fl3 = getCrefFromExp(exp, includeSubs, includeFunctions)
        @assign res = listAppend(fl1, listAppend(fl2, fl3))
        res
      end
    end
  end
  return outComponentRefLst
end

function iteratorName(iterator::ForIterator)::String
  local name::String

  @match ITERATOR(name = name) = iterator
  return name
end

function iteratorRange(iterator::ForIterator)::Option{Exp}
  local range::Option{Exp}

  @match ITERATOR(range = range) = iterator
  return range
end

function iteratorGuard(iterator::ForIterator)::Option{Exp}
  local guardExp::Option{Exp}

  @match ITERATOR(guardExp = guardExp) = iterator
  return guardExp
end

#=  stefan
=#

"""returns the names from a list of NamedArgs as a string list"""
function getNamedFuncArgNamesAndValues(
  inNamedArgList::List{<:NamedArg},
)::Tuple{List{String}, List{Exp}}
  local outExpList::List{Exp}
  local outStringList::List{String}

  @assign (outStringList, outExpList) = begin
    local cdr::List{NamedArg}
    local s::String
    local e::Exp
    local slst::List{String}
    local elst::List{Exp}
    @match inNamedArgList begin
      nil() => begin
        (nil, nil)
      end

      NAMEDARG(argName = s, argValue = e) <| cdr => begin
        @assign (slst, elst) = getNamedFuncArgNamesAndValues(cdr)
        (_cons(s, slst), _cons(e, elst))
      end
    end
  end
  return (outStringList, outExpList)
end

"""
  Returns the flattened list of all component references
  present in a list of named function arguments.
"""
function getCrefFromNarg(
  inNamedArg::NamedArg,
  includeSubs::Bool,
  includeFunctions::Bool,
)::List{ComponentRef} #= note that if you say includeSubs = false then you won't get the functions from array subscripts =#
  local outComponentRefLst::List{ComponentRef}

  @assign outComponentRefLst = begin
    local res::List{ComponentRef}
    local exp::ComponentCondition
    @match (inNamedArg, includeSubs, includeFunctions) begin
      (NAMEDARG(argValue = exp), _, _) => begin
        @assign res = getCrefFromExp(exp, includeSubs, includeFunctions)
        res
      end
    end
  end
  return outComponentRefLst
end

"""This function joins two paths"""
function joinPaths(inPath1::Path, inPath2::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local str::Ident
    local p2::Path
    local p_1::Path
    local p::Path
    @match (inPath1, inPath2) begin
      (IDENT(name = str), p2) => begin
        QUALIFIED(str, p2)
      end

      (QUALIFIED(name = str, path = p), p2) => begin
        @assign p_1 = joinPaths(p, p2)
        QUALIFIED(str, p_1)
      end

      (FULLYQUALIFIED(p), p2) => begin
        joinPaths(p, p2)
      end

      (p, FULLYQUALIFIED(p2)) => begin
        joinPaths(p, p2)
      end
    end
  end
  return outPath
end

"""
  author Lucian
  This function joins a path list
"""
function pathAppendList(inPathLst::List{<:Path})::Path
  local outPath::Path

  @assign outPath = begin
    local path::Path
    local res_path::Path
    local first::Path
    local rest::List{Path}
    @match inPathLst begin
      nil() => begin
        IDENT("")
      end

      path <| nil() => begin
        path
      end

      first <| rest => begin
        @assign path = pathAppendList(rest)
        @assign res_path = joinPaths(first, path)
        res_path
      end
    end
  end
  return outPath
end

"""
  Returns the path given as argument to
  the function minus the last ident.
"""
function stripLast(inPath::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local str::Ident
    local p::Path
    @match inPath begin
      QUALIFIED(name = str, path = IDENT(__)) => begin
        IDENT(str)
      end

      QUALIFIED(name = str, path = p) => begin
        @assign p = stripLast(p)
        QUALIFIED(str, p)
      end

      FULLYQUALIFIED(p) => begin
        @assign p = stripLast(p)
        FULLYQUALIFIED(p)
      end
    end
  end
  return outPath
end

"""
  Returns the path given as argument to
  the function minus the last ident.
"""
function crefStripLast(inCref::ComponentRef)::ComponentRef
  local outCref::ComponentRef

  @assign outCref = begin
    local str::Ident
    local c_1::ComponentRef
    local c::ComponentRef
    local subs::List{Subscript}
    @match inCref begin
      CREF_IDENT(__) => begin
        fail()
      end

      CREF_QUAL(name = str, subscripts = subs, componentRef = CREF_IDENT(__)) => begin
        CREF_IDENT(str, subs)
      end

      CREF_QUAL(name = str, subscripts = subs, componentRef = c) => begin
        @assign c_1 = crefStripLast(c)
        CREF_QUAL(str, subs, c_1)
      end

      CREF_FULLYQUALIFIED(componentRef = c) => begin
        @assign c_1 = crefStripLast(c)
        crefMakeFullyQualified(c_1)
      end
    end
  end
  return outCref
end

"""
  Author BZ 2008-04
  Function for splitting Absynpath into two parts,
  qualified part, and ident part (all_but_last, last);
"""
function splitQualAndIdentPath(inPath::Path)::Tuple{Path, Path}
  local outPath2::Path
  local outPath1::Path

  @assign (outPath1, outPath2) = begin
    local qPath::Path
    local curPath::Path
    local identPath::Path
    local s1::String
    local s2::String
    @match inPath begin
      QUALIFIED(name = s1, path = IDENT(name = s2)) => begin
        (IDENT(s1), IDENT(s2))
      end

      QUALIFIED(name = s1, path = qPath) => begin
        @assign (curPath, identPath) = splitQualAndIdentPath(qPath)
        (QUALIFIED(s1, curPath), identPath)
      end

      FULLYQUALIFIED(qPath) => begin
        @assign (curPath, identPath) = splitQualAndIdentPath(qPath)
        (curPath, identPath)
      end
    end
  end
  return (outPath1, outPath2)
end

"""
  Returns the path given as argument
  to the function minus the first ident.
"""
function stripFirst(inPath::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local p::Path
    @match inPath begin
      QUALIFIED(path = p) => begin
        p
      end

      FULLYQUALIFIED(p) => begin
        stripFirst(p)
      end
    end
  end
  return outPath
end

"""
  This function converts a ComponentRef to a Path, if possible.
  If the component reference contains subscripts, it will silently fail.
"""
function crefToPath(inComponentRef::ComponentRef)::Path
  local outPath::Path

  @assign outPath = begin
    local i::Ident
    local p::Path
    local c::ComponentRef
    @match inComponentRef begin
      CREF_IDENT(name = i, subscripts = nil()) => begin
        IDENT(i)
      end

      CREF_QUAL(name = i, subscripts = nil(), componentRef = c) => begin
        @assign p = crefToPath(c)
        QUALIFIED(i, p)
      end

      CREF_FULLYQUALIFIED(componentRef = c) => begin
        @assign p = crefToPath(c)
        FULLYQUALIFIED(p)
      end
    end
  end
  return outPath
end

"""Converts a ComponentRef to a Path, ignoring any subscripts."""
function crefToPathIgnoreSubs(inComponentRef::ComponentRef)::Path
  local outPath::Path

  @assign outPath = begin
    local i::Ident
    local p::Path
    local c::ComponentRef
    @match inComponentRef begin
      CREF_IDENT(name = i) => begin
        IDENT(i)
      end

      CREF_QUAL(name = i, componentRef = c) => begin
        @assign p = crefToPathIgnoreSubs(c)
        QUALIFIED(i, p)
      end

      CREF_FULLYQUALIFIED(componentRef = c) => begin
        @assign p = crefToPathIgnoreSubs(c)
        FULLYQUALIFIED(p)
      end
    end
  end
  return outPath
end

"""This function converts a Path to a ComponentRef."""
function pathToCref(inPath::Path)::ComponentRef
  local outComponentRef::ComponentRef

  @assign outComponentRef = begin
    local i::Ident
    local c::ComponentRef
    local p::Path
    @match inPath begin
      IDENT(name = i) => begin
        CREF_IDENT(i, nil)
      end

      QUALIFIED(name = i, path = p) => begin
        @assign c = pathToCref(p)
        CREF_QUAL(i, nil, c)
      end

      FULLYQUALIFIED(p) => begin
        @assign c = pathToCref(p)
        crefMakeFullyQualified(c)
      end
    end
  end
  return outComponentRef
end

"""
  This function converts a Path to a ComponentRef, and applies the given
  subscripts to the last identifier.
"""
function pathToCrefWithSubs(inPath::Path, inSubs::List{<:Subscript})::ComponentRef
  local outComponentRef::ComponentRef

  @assign outComponentRef = begin
    local i::Ident
    local c::ComponentRef
    local p::Path
    @match (inPath, inSubs) begin
      (IDENT(name = i), _) => begin
        CREF_IDENT(i, inSubs)
      end

      (QUALIFIED(name = i, path = p), _) => begin
        @assign c = pathToCrefWithSubs(p, inSubs)
        CREF_QUAL(i, nil, c)
      end

      (FULLYQUALIFIED(p), _) => begin
        @assign c = pathToCrefWithSubs(p, inSubs)
        crefMakeFullyQualified(c)
      end
    end
  end
  return outComponentRef
end

"""Returns the last identifier in a component reference."""
function crefLastIdent(inComponentRef::ComponentRef)::Ident
  local outIdent::Ident

  @assign outIdent = begin
    local cref::ComponentRef
    local id::Ident
    @match inComponentRef begin
      CREF_IDENT(name = id) => begin
        id
      end

      CREF_QUAL(componentRef = cref) => begin
        crefLastIdent(cref)
      end

      CREF_FULLYQUALIFIED(componentRef = cref) => begin
        crefLastIdent(cref)
      end
    end
  end
  return outIdent
end

"""
  Returns the basename of the component reference, but fails if it encounters
  any subscripts.
"""
function crefFirstIdentNoSubs(inCref::ComponentRef)::Ident
  local outIdent::Ident

  @assign outIdent = begin
    local id::Ident
    local cr::ComponentRef
    @match inCref begin
      CREF_IDENT(name = id, subscripts = nil()) => begin
        id
      end

      CREF_QUAL(name = id, subscripts = nil()) => begin
        id
      end

      CREF_FULLYQUALIFIED(componentRef = cr) => begin
        crefFirstIdentNoSubs(cr)
      end
    end
  end
  return outIdent
end

"""Return the last subscripts of an ComponentRef"""
function crefLastSubs(inComponentRef::ComponentRef)::List{Subscript}
  local outSubscriptLst::List{Subscript}

  @assign outSubscriptLst = begin
    local id::Ident
    local subs::List{Subscript}
    local res::List{Subscript}
    local cr::ComponentRef
    @match inComponentRef begin
      CREF_IDENT(subscripts = subs) => begin
        subs
      end

      CREF_QUAL(componentRef = cr) => begin
        @assign res = crefLastSubs(cr)
        res
      end

      CREF_FULLYQUALIFIED(componentRef = cr) => begin
        @assign res = crefLastSubs(cr)
        res
      end
    end
  end
  return outSubscriptLst
end

function crefSetLastSubs(
  inCref::ComponentRef,
  inSubscripts::List{<:Subscript},
)::ComponentRef
  local outCref::ComponentRef = inCref

  @assign outCref = begin
    @match outCref begin
      CREF_IDENT(__) => begin
        @assign outCref.subscripts = inSubscripts
        outCref
      end

      CREF_QUAL(__) => begin
        @assign outCref.componentRef = crefSetLastSubs(outCref.componentRef, inSubscripts)
        outCref
      end

      CREF_FULLYQUALIFIED(__) => begin
        @assign outCref.componentRef = crefSetLastSubs(outCref.componentRef, inSubscripts)
        outCref
      end
    end
  end
  return outCref
end

"""This function finds if a cref has subscripts"""
function crefHasSubscripts(cref::ComponentRef)::Bool
  local hasSubscripts::Bool

  @assign hasSubscripts = begin
    @match cref begin
      CREF_IDENT(__) => begin
        !listEmpty(cref.subscripts)
      end

      CREF_QUAL(subscripts = nil()) => begin
        crefHasSubscripts(cref.componentRef)
      end

      CREF_FULLYQUALIFIED(__) => begin
        crefHasSubscripts(cref.componentRef)
      end

      WILD(__) => begin
        false
      end

      ALLWILD(__) => begin
        false
      end

      _ => begin
        true
      end
    end
  end
  return hasSubscripts
end

"""
  Author: BZ, 2009-09
  Extract subscripts of crefs.
"""
function getSubsFromCref(
  cr::ComponentRef,
  includeSubs::Bool,
  includeFunctions::Bool,
)::List{Subscript} #= note that if you say includeSubs = false then you won't get the functions from array subscripts =#
  local subscripts::List{Subscript}

  @assign subscripts = begin
    local subs2::List{Subscript}
    local child::ComponentRef
    @match (cr, includeSubs, includeFunctions) begin
      (CREF_IDENT(_, subs2), _, _) => begin
        subs2
      end

      (CREF_QUAL(_, subs2, child), _, _) => begin
        @assign subscripts = getSubsFromCref(child, includeSubs, includeFunctions)
        @assign subscripts = ListUtil.unionOnTrue(subscripts, subs2, subscriptEqual)
        subscripts
      end

      (CREF_FULLYQUALIFIED(child), _, _) => begin
        @assign subscripts = getSubsFromCref(child, includeSubs, includeFunctions)
        subscripts
      end
    end
  end
  return subscripts
end

#=  stefan
=#

"""Gets the last ident in a ComponentRef"""
function crefGetLastIdent(inComponentRef::ComponentRef)::ComponentRef
  local outComponentRef::ComponentRef

  @assign outComponentRef = begin
    local cref::ComponentRef
    local cref_1::ComponentRef
    local id::Ident
    local subs::List{Subscript}
    @match inComponentRef begin
      CREF_IDENT(id, subs) => begin
        CREF_IDENT(id, subs)
      end

      CREF_QUAL(_, _, cref) => begin
        @assign cref_1 = crefGetLastIdent(cref)
        cref_1
      end

      CREF_FULLYQUALIFIED(cref) => begin
        @assign cref_1 = crefGetLastIdent(cref)
        cref_1
      end
    end
  end
  return outComponentRef
end

"""Strips the last subscripts of a ComponentRef"""
function crefStripLastSubs(inComponentRef::ComponentRef)::ComponentRef
  local outComponentRef::ComponentRef

  @assign outComponentRef = begin
    local id::Ident
    local subs::List{Subscript}
    local s::List{Subscript}
    local cr_1::ComponentRef
    local cr::ComponentRef
    @match inComponentRef begin
      CREF_IDENT(name = id) => begin
        CREF_IDENT(id, nil)
      end

      CREF_QUAL(name = id, subscripts = s, componentRef = cr) => begin
        @assign cr_1 = crefStripLastSubs(cr)
        CREF_QUAL(id, s, cr_1)
      end

      CREF_FULLYQUALIFIED(componentRef = cr) => begin
        @assign cr_1 = crefStripLastSubs(cr)
        crefMakeFullyQualified(cr_1)
      end
    end
  end
  return outComponentRef
end

"""This function joins two ComponentRefs."""
function joinCrefs(
  inComponentRef1::ComponentRef,
  inComponentRef2::ComponentRef,
)::ComponentRef
  local outComponentRef::ComponentRef

  @assign outComponentRef = begin
    local id::Ident
    local sub::List{Subscript}
    local cr2::ComponentRef
    local cr_1::ComponentRef
    local cr::ComponentRef
    @match (inComponentRef1, inComponentRef2) begin
      (CREF_IDENT(name = id, subscripts = sub), cr2) => begin
        @shouldFail @match CREF_FULLYQUALIFIED() = cr2
        CREF_QUAL(id, sub, cr2)
      end

      (CREF_QUAL(name = id, subscripts = sub, componentRef = cr), cr2) => begin
        @assign cr_1 = joinCrefs(cr, cr2)
        CREF_QUAL(id, sub, cr_1)
      end

      (CREF_FULLYQUALIFIED(componentRef = cr), cr2) => begin
        @assign cr_1 = joinCrefs(cr, cr2)
        crefMakeFullyQualified(cr_1)
      end
    end
  end
  return outComponentRef
end

"""Returns first ident from a ComponentRef"""
function crefFirstIdent(inCref::ComponentRef)::Ident
  local outIdent::Ident

  @assign outIdent = begin
    @match inCref begin
      CREF_IDENT(__) => begin
        inCref.name
      end

      CREF_QUAL(__) => begin
        inCref.name
      end

      CREF_FULLYQUALIFIED(__) => begin
        crefFirstIdent(inCref.componentRef)
      end
    end
  end
  return outIdent
end

function crefSecondIdent(cref::ComponentRef)::Ident
  local ident::Ident

  @assign ident = begin
    @match cref begin
      CREF_QUAL(__) => begin
        crefFirstIdent(cref.componentRef)
      end

      CREF_FULLYQUALIFIED(__) => begin
        crefSecondIdent(cref.componentRef)
      end
    end
  end
  return ident
end

"""Returns the first part of a cref."""
function crefFirstCref(inCref::ComponentRef)::ComponentRef
  local outCref::ComponentRef

  @assign outCref = begin
    @match inCref begin
      CREF_QUAL(__) => begin
        CREF_IDENT(inCref.name, inCref.subscripts)
      end

      CREF_FULLYQUALIFIED(__) => begin
        crefFirstCref(inCref.componentRef)
      end

      _ => begin
        inCref
      end
    end
  end
  return outCref
end

"""Strip the first ident from a ComponentRef"""
function crefStripFirst(inComponentRef::ComponentRef)::ComponentRef
  local outComponentRef::ComponentRef

  @assign outComponentRef = begin
    local cr::ComponentRef
    @match inComponentRef begin
      CREF_QUAL(componentRef = cr) => begin
        cr
      end

      CREF_FULLYQUALIFIED(componentRef = cr) => begin
        crefStripFirst(cr)
      end
    end
  end
  return outComponentRef
end

"""Makes a component reference fully qualified unless it already is."""
function crefMakeFullyQualified(inComponentRef::ComponentRef)::ComponentRef
  local outComponentRef::ComponentRef

  @assign outComponentRef = begin
    @match inComponentRef begin
      CREF_FULLYQUALIFIED(__) => begin
        inComponentRef
      end

      _ => begin
        CREF_FULLYQUALIFIED(inComponentRef)
      end
    end
  end
  return outComponentRef
end

"""Maps a class restriction to the corresponding string for printing"""
function restrString(inRestriction::Restriction)::String
  local outString::String

  @assign outString = begin
    @match inRestriction begin
      R_CLASS(__) => begin
        "CLASS"
      end

      R_OPTIMIZATION(__) => begin
        "OPTIMIZATION"
      end

      R_MODEL(__) => begin
        "MODEL"
      end

      R_RECORD(__) => begin
        "RECORD"
      end

      R_BLOCK(__) => begin
        "BLOCK"
      end

      R_CONNECTOR(__) => begin
        "CONNECTOR"
      end

      R_EXP_CONNECTOR(__) => begin
        "EXPANDABLE CONNECTOR"
      end

      R_TYPE(__) => begin
        "TYPE"
      end

      R_PACKAGE(__) => begin
        "PACKAGE"
      end

      R_FUNCTION(FR_NORMAL_FUNCTION(PURE(__))) => begin
        "PURE FUNCTION"
      end

      R_FUNCTION(FR_NORMAL_FUNCTION(IMPURE(__))) => begin
        "IMPURE FUNCTION"
      end

      R_FUNCTION(FR_NORMAL_FUNCTION(NO_PURITY(__))) => begin
        "FUNCTION"
      end

      R_FUNCTION(FR_OPERATOR_FUNCTION(__)) => begin
        "OPERATOR FUNCTION"
      end

      R_PREDEFINED_INTEGER(__) => begin
        "PREDEFINED_INT"
      end

      R_PREDEFINED_REAL(__) => begin
        "PREDEFINED_REAL"
      end

      R_PREDEFINED_STRING(__) => begin
        "PREDEFINED_STRING"
      end

      R_PREDEFINED_BOOLEAN(__) => begin
        "PREDEFINED_BOOL"
      end

      R_PREDEFINED_CLOCK(__) => begin
        "PREDEFINED_CLOCK"
      end

      R_UNIONTYPE(__) => begin
        "UNIONTYPE"
      end

      _ => begin
        "* Unknown restriction *"
      end
    end
  end
  #=  BTH
  =#
  #= /* MetaModelica restriction */ =#
  return outString
end

"""
  Checks if the name of a ComponentRef is
  equal to the name of another ComponentRef, including subscripts.
  See also crefEqualNoSubs.
"""
function crefEqual(iCr1::ComponentRef, iCr2::ComponentRef)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    local id::Ident
    local id2::Ident
    local ss1::List{Subscript}
    local ss2::List{Subscript}
    local cr1::ComponentRef
    local cr2::ComponentRef
    @matchcontinue (iCr1, iCr2) begin
      (CREF_IDENT(name = id, subscripts = ss1), CREF_IDENT(name = id2, subscripts = ss2)) => begin
        @match true = stringEq(id, id2)
        @match true = subscriptsEqual(ss1, ss2)
        true
      end

      (
        CREF_QUAL(name = id, subscripts = ss1, componentRef = cr1),
        CREF_QUAL(name = id2, subscripts = ss2, componentRef = cr2),
      ) => begin
        @match true = stringEq(id, id2)
        @match true = subscriptsEqual(ss1, ss2)
        @match true = crefEqual(cr1, cr2)
        true
      end

      (CREF_FULLYQUALIFIED(componentRef = cr1), CREF_FULLYQUALIFIED(componentRef = cr2)) => begin
        crefEqual(cr1, cr2)
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

function subscriptEqual(inSubscript1::Subscript, inSubscript2::Subscript)::Bool
  local outIsEqual::Bool

  @assign outIsEqual = begin
    local e1::Exp
    local e2::Exp
    @match (inSubscript1, inSubscript2) begin
      (NOSUB(__), NOSUB(__)) => begin
        true
      end

      (SUBSCRIPT(e1), SUBSCRIPT(e2)) => begin
        expEqual(e1, e2)
      end

      _ => begin
        false
      end
    end
  end
  return outIsEqual
end

"""Checks if two subscript lists are equal."""
function subscriptsEqual(inSubList1::List{<:Subscript}, inSubList2::List{<:Subscript})::Bool
  local outIsEqual::Bool

  @assign outIsEqual = ListUtil.isEqualOnTrue(inSubList1, inSubList2, subscriptEqual)
  return outIsEqual
end

"""
  Checks if the name of a ComponentRef is equal to the name
  of another ComponentRef without checking subscripts.
  See also crefEqual.
"""
function crefEqualNoSubs(cr1::ComponentRef, cr2::ComponentRef)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    local rest1::ComponentRef
    local rest2::ComponentRef
    local id::Ident
    local id2::Ident
    @matchcontinue (cr1, cr2) begin
      (CREF_IDENT(name = id), CREF_IDENT(name = id2)) => begin
        @match true = stringEq(id, id2)
        true
      end

      (
        CREF_QUAL(name = id, componentRef = rest1),
        CREF_QUAL(name = id2, componentRef = rest2),
      ) => begin
        @match true = stringEq(id, id2)
        @match true = crefEqualNoSubs(rest1, rest2)
        true
      end

      (
        CREF_FULLYQUALIFIED(componentRef = rest1),
        CREF_FULLYQUALIFIED(componentRef = rest2),
      ) => begin
        crefEqualNoSubs(rest1, rest2)
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Returns true if two expressions are equal"""
function expEqual(exp1::Exp, exp2::Exp)::Bool
  local equal::Bool

  @assign equal = begin
    local b::Bool
    local x::Exp
    local y::Exp
    local i::Int
    local r::String
    #=  real vs. integer
    =#
    @matchcontinue (exp1, exp2) begin
      (INTEGER(i), REAL(r)) => begin
        @assign b = realEq(intReal(i), System.stringReal(r))
        b
      end

      (REAL(r), INTEGER(i)) => begin
        @assign b = realEq(intReal(i), System.stringReal(r))
        b
      end

      (x, y) => begin
        valueEq(x, y)
      end
    end
  end
  #=  anything else, exact match!
  =#
  return equal
end

"""Returns true if two each attributes are equal"""
function eachEqual(each1::Each, each2::Each)::Bool
  local equal::Bool

  @assign equal = begin
    @match (each1, each2) begin
      (NON_EACH(__), NON_EACH(__)) => begin
        true
      end

      (EACH(__), EACH(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return equal
end

IteratorIndexedCref = Tuple

"""
  Checks if the given component reference is subscripted by the given iterator.
  Only cases where a subscript consists of only the iterator is considered.
  If so it adds a cref-index pair to the list, where the cref is the subscripted
  cref without subscripts, and the index is the subscripted dimension. E.g. for
  iterator i:
  a[i] => (a, 1), b[1, i] => (b, 2), c[i+1] => (), d[2].e[i] => (d[2].e, 1)
"""
function getIteratorIndexedCrefs(
  inCref::ComponentRef,
  inIterator::String,
  inCrefs::List{<:IteratorIndexedCref},
)::List{IteratorIndexedCref}
  local outCrefs::List{IteratorIndexedCref} = inCrefs

  local crefs::List{Tuple{ComponentRef, Integer}}

  @assign outCrefs = begin
    local subs::List{Subscript}
    local idx::Int
    local name::String
    local id::String
    local cref::ComponentRef
    @match inCref begin
      CREF_IDENT(name = id, subscripts = subs) => begin
        #=  For each subscript, check if the subscript consists of only the
        =#
        #=  iterator we're looking for.
        =#
        @assign idx = 1
        for sub in subs
          @assign _ = begin
            @match sub begin
              SUBSCRIPT(
                subscript = CREF(
                  componentRef = CREF_IDENT(name = name, subscripts = nil()),
                ),
              ) => begin
                if name == inIterator
                  @assign outCrefs = _cons((CREF_IDENT(id, nil), idx), outCrefs)
                end
                ()
              end

              _ => begin
                ()
              end
            end
          end
          @assign idx = idx + 1
        end
        outCrefs
      end

      CREF_QUAL(name = id, subscripts = subs, componentRef = cref) => begin
        @assign crefs = getIteratorIndexedCrefs(cref, inIterator, nil)
        #=  Append the prefix from the qualified cref to any matches, and add
        =#
        #=  them to the result list.
        =#
        for cr in crefs
          @assign (cref, idx) = cr
          @assign outCrefs = _cons((CREF_QUAL(id, subs, cref), idx), outCrefs)
        end
        getIteratorIndexedCrefs(CREF_IDENT(id, subs), inIterator, outCrefs)
      end

      CREF_FULLYQUALIFIED(componentRef = cref) => begin
        @assign crefs = getIteratorIndexedCrefs(cref, inIterator, nil)
        #=  Make any matches fully qualified, and add them to the result list.
        =#
        for cr in crefs
          @assign (cref, idx) = cr
          @assign outCrefs = _cons((CREF_FULLYQUALIFIED(cref), idx), outCrefs)
        end
        outCrefs
      end

      _ => begin
        inCrefs
      end
    end
  end
  return outCrefs
end

function pathReplaceIdent(path::Path, last::String)::Path
  local out::Path

  @assign out = begin
    local p::Path
    local n::String
    local s::String
    @match (path, last) begin
      (FULLYQUALIFIED(p), s) => begin
        @assign p = pathReplaceIdent(p, s)
        FULLYQUALIFIED(p)
      end

      (QUALIFIED(n, p), s) => begin
        @assign p = pathReplaceIdent(p, s)
        QUALIFIED(n, p)
      end

      (IDENT(__), s) => begin
        IDENT(s)
      end
    end
  end
  return out
end

"""
  @author: adrpo
  this function returns true if the given InnerOuter
  is one of INNER_OUTER() or OUTER()
"""
function isOuter(io::InnerOuter)::Bool
  local isItAnOuter::Bool

  @assign isItAnOuter = begin
    @match io begin
      INNER_OUTER(__) => begin
        true
      end

      OUTER(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isItAnOuter
end

"""
  @author: adrpo
  this function returns true if the given InnerOuter
  is one of INNER_OUTER() or INNER()
"""
function isInner(io::InnerOuter)::Bool
  local isItAnInner::Bool

  @assign isItAnInner = begin
    @match io begin
      INNER_OUTER(__) => begin
        true
      end

      INNER(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isItAnInner
end

"""Returns true if the InnerOuter is OUTER, false otherwise."""
function isOnlyOuter(inIO::InnerOuter)::Bool
  local outOnlyOuter::Bool

  @assign outOnlyOuter = begin
    @match inIO begin
      OUTER(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outOnlyOuter
end

"""Returns true if two InnerOuter's are equal"""
function innerOuterEqual(io1::InnerOuter, io2::InnerOuter)::Bool
  local res::Bool

  @assign res = begin
    @match (io1, io2) begin
      (INNER(__), INNER(__)) => begin
        true
      end

      (OUTER(__), OUTER(__)) => begin
        true
      end

      (INNER_OUTER(__), INNER_OUTER(__)) => begin
        true
      end

      (NOT_INNER_OUTER(__), NOT_INNER_OUTER(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""Makes a path not fully qualified unless it already is."""
function makeNotFullyQualified(inPath::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local path::Path
    @match inPath begin
      FULLYQUALIFIED(path) => begin
        path
      end

      _ => begin
        inPath
      end
    end
  end
  return outPath
end

"""Compares two import elements."""
function importEqual(im1::Import, im2::Import)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    local id::Ident
    local id2::Ident
    local p1::Path
    local p2::Path
    @matchcontinue (im1, im2) begin
      (NAMED_IMPORT(name = id, path = p1), NAMED_IMPORT(name = id2, path = p2)) => begin
        @match true = stringEq(id, id2)
        @match true = pathEqual(p1, p2)
        true
      end

      (QUAL_IMPORT(path = p1), QUAL_IMPORT(path = p2)) => begin
        @match true = pathEqual(p1, p2)
        true
      end

      (UNQUAL_IMPORT(path = p1), UNQUAL_IMPORT(path = p2)) => begin
        @match true = pathEqual(p1, p2)
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Transforms an if-expression to canonical form (without else-if branches)"""
function canonIfExp(inExp::Exp)::Exp
  local outExp::Exp

  @assign outExp = begin
    local cond::Exp
    local tb::Exp
    local eb::Exp
    local ei_cond::Exp
    local ei_tb::Exp
    local e::Exp
    local eib::List{Tuple{Exp, Exp}}
    @match inExp begin
      IFEXP(elseIfBranch = nil()) => begin
        inExp
      end

      IFEXP(
        ifExp = cond,
        trueBranch = tb,
        elseBranch = eb,
        elseIfBranch = (ei_cond, ei_tb) <| eib,
      ) => begin
        @assign e = canonIfExp(IFEXP(ei_cond, ei_tb, eb, eib))
        IFEXP(cond, tb, e, nil)
      end
    end
  end
  return outExp
end

"""
  @author: adrpo
  This function checks if a modification only contains literal expressions
"""
function onlyLiteralsInAnnotationMod(inMod::List{<:ElementArg})::Bool
  local onlyLiterals::Bool

  @assign onlyLiterals = begin
    local dive::List{ElementArg}
    local rest::List{ElementArg}
    local eqMod::EqMod
    local b1::Bool
    local b2::Bool
    local b3::Bool
    local b::Bool
    @matchcontinue inMod begin
      nil() => begin
        true
      end

      MODIFICATION(path = IDENT(name = "interaction")) <| rest => begin
        @assign b = onlyLiteralsInAnnotationMod(rest)
        b
      end

      MODIFICATION(modification = SOME(CLASSMOD(dive, eqMod))) <| rest => begin
        @assign b1 = onlyLiteralsInEqMod(eqMod)
        @assign b2 = onlyLiteralsInAnnotationMod(dive)
        @assign b3 = onlyLiteralsInAnnotationMod(rest)
        @assign b = boolAnd(b1, boolAnd(b2, b3))
        b
      end

      _ <| rest => begin
        @assign b = onlyLiteralsInAnnotationMod(rest)
        b
      end

      _ => begin
        false
      end
    end
  end
  #=  skip \"interaction\" annotation!
  =#
  #=  search inside, some(exp)
  =#
  #=  failed above, return false
  =#
  return onlyLiterals
end

"""
  @author: adrpo
  This function checks if an optional expression only contains literal expressions
"""
function onlyLiteralsInEqMod(eqMod::EqMod)::Bool
  local onlyLiterals::Bool

  @assign onlyLiterals = begin
    local exp::Exp
    local lst::List{Exp}
    local b::Bool
    @match eqMod begin
      NOMOD(__) => begin
        true
      end

      EQMOD(exp = exp) => begin
        @match (_, _cons(lst, nil)) = traverseExpBidir(
          exp,
          onlyLiteralsInExpEnter,
          onlyLiteralsInExpExit,
          _cons(nil, nil),
        )
        @assign b = listEmpty(lst)
        b
      end
    end
  end
  #=  search inside, some(exp)
  =#
  return onlyLiterals
end

"""
  @author: adrpo
  Visitor function for checking if Exp contains only literals, NO CREFS!
  It returns an empty list if it doesn't contain any crefs!
"""
function onlyLiteralsInExpEnter(
  inExp::Exp,
  inLst::List{<:List{<:Exp}},
)::Tuple{Exp, List{List{Exp}}}
  local outLst::List{List{Exp}}
  local outExp::Exp

  @assign (outExp, outLst) = begin
    local b::Bool
    local e::Exp
    local cr::ComponentRef
    local lst::List{Exp}
    local rest::List{List{Exp}}
    local name::String
    local fargs::FunctionArgs
    #=  first handle all graphic enumerations!
    =#
    #=  FillPattern.*, Smooth.*, TextAlignment.*, etc!
    =#
    @match (inExp, inLst) begin
      (e && CREF(CREF_QUAL(name = name)), lst <| rest) => begin
        @assign b = listMember(
          name,
          list(
            "LinePattern",
            "Arrow",
            "FillPattern",
            "BorderPattern",
            "TextStyle",
            "Smooth",
            "TextAlignment",
          ),
        )
        @assign lst = ListUtil.consOnTrue(!b, e, lst)
        (inExp, _cons(lst, rest))
      end

      (CREF(__), lst <| rest) => begin
        (inExp, _cons(_cons(inExp, lst), rest))
      end

      _ => begin
        (inExp, inLst)
      end
    end
  end
  #=  crefs, add to list
  =#
  #=  anything else, return the same!
  =#
  return (outExp, outLst)
end

"""
  @author: adrpo
  Visitor function for checking if Exp contains only literals, NO CREFS!
  It returns an empty list if it doesn't contain any crefs!
"""
function onlyLiteralsInExpExit(
  inExp::Exp,
  inLst::List{<:List{<:Exp}},
)::Tuple{Exp, List{List{Exp}}}
  local outLst::List{List{Exp}}
  local outExp::Exp

  @assign (outExp, outLst) = begin
    local lst::List{List{Exp}}
    #=  first handle DynamicSelect; pop the stack (ignore any crefs inside DynamicSelect)
    =#
    @match (inExp, inLst) begin
      (CALL(function_ = CREF_IDENT(name = "DynamicSelect")), lst) => begin
        (inExp, lst)
      end

      _ => begin
        (inExp, inLst)
      end
    end
  end
  #=  anything else, return the same!
  =#
  return (outExp, outLst)
end

function crefIdent(cr::ComponentRef)::String
  local str::String

  @match CREF_IDENT(str, nil) = cr
  return str
end

function pathIsIdent(inPath::Path)::Bool
  local outIsIdent::Bool

  @assign outIsIdent = begin
    @match inPath begin
      IDENT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsIdent
end

"""Helper function to crefInsertSubscriptLstLst"""
function crefInsertSubscriptLstLst2(
  inCref::ComponentRef,
  inSubs::List{<:List{<:Subscript}},
)::ComponentRef
  local outCref::ComponentRef

  @assign outCref = begin
    local cref::ComponentRef
    local cref2::ComponentRef
    local n::Ident
    local subs::List{List{Subscript}}
    local s::List{Subscript}
    @matchcontinue (inCref, inSubs) begin
      (cref, nil()) => begin
        cref
      end

      (CREF_IDENT(name = n), s <| nil()) => begin
        CREF_IDENT(n, s)
      end

      (CREF_QUAL(name = n, componentRef = cref), s <| subs) => begin
        @assign cref2 = crefInsertSubscriptLstLst2(cref, subs)
        CREF_QUAL(n, s, cref2)
      end

      (CREF_FULLYQUALIFIED(componentRef = cref), subs) => begin
        @assign cref2 = crefInsertSubscriptLstLst2(cref, subs)
        crefMakeFullyQualified(cref2)
      end
    end
  end
  return outCref
end

function isCref(exp::Exp)::Bool
  local b::Bool

  @assign b = begin
    @match exp begin
      CREF(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return b
end

function isTuple(exp::Exp)::Bool
  local b::Bool

  @assign b = begin
    @match exp begin
      TUPLE(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return b
end

"""
  @author: johti
  Returns true if all fields are crefs
"""
function allFieldsAreCrefs(expLst::List{<:Exp})::Bool
  local b::Bool

  @assign b = ListUtil.mapAllValueBool(expLst, complexIsCref, true)
  return b
end

"""
  @author: johti
  Returns true if everything contained
  in the tuple or a cons cell is a constant reference.
"""
function complexIsCref(inExp::Exp)::Bool
  local b::Bool

  @assign b = begin
    @match inExp begin
      TUPLE(__) => begin
        allFieldsAreCrefs(inExp.expressions)
      end

      CONS(__) => begin
        complexIsCref(inExp.head) && complexIsCref(inExp.rest)
      end

      _ => begin
        isCref(inExp)
      end
    end
  end
  return b
end

function isDerCref(exp::Exp)::Bool
  local b::Bool

  @assign b = begin
    @match exp begin
      CALL(CREF_IDENT("der", nil()), FUNCTIONARGS(CREF(__) <| nil(), nil())) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return b
end

"""
  author: adrpo
  returns all the expressions from array dimension as a list
  also returns if we have unknown dimensions in the array dimension
"""
function getExpsFromArrayDim_tail(
  inAd::ArrayDim,
  inAccumulator::List{<:Exp},
)::Tuple{Bool, List{Exp}}
  local outExps::List{Exp}
  local hasUnknownDimensions::Bool

  @assign (hasUnknownDimensions, outExps) = begin
    local rest::List{Subscript}
    local e::Exp
    local exps::List{Exp}
    local acc::List{Exp}
    local b::Bool
    #=  handle empty list
    =#
    @match (inAd, inAccumulator) begin
      (nil(), acc) => begin
        (false, listReverse(acc))
      end

      (SUBSCRIPT(e) <| rest, acc) => begin
        @assign (b, exps) = getExpsFromArrayDim_tail(rest, _cons(e, acc))
        (b, exps)
      end

      (NOSUB(__) <| rest, acc) => begin
        @assign (_, exps) = getExpsFromArrayDim_tail(rest, acc)
        (true, exps)
      end
    end
  end
  #=  handle SUBSCRIPT
  =#
  #=  handle NOSUB
  =#
  return (hasUnknownDimensions, outExps)
end

function isInput(inDirection::Direction)::Bool
  local outIsInput::Bool

  @assign outIsInput = begin
    @match inDirection begin
      INPUT(__) => begin
        true
      end

      INPUT_OUTPUT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsInput
end

function isOutput(inDirection::Direction)::Bool
  local outIsOutput::Bool

  @assign outIsOutput = begin
    @match inDirection begin
      OUTPUT(__) => begin
        true
      end

      INPUT_OUTPUT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsOutput
end

function directionEqual(inDirection1::Direction, inDirection2::Direction)::Bool
  local outEqual::Bool

  @assign outEqual = begin
    @match (inDirection1, inDirection2) begin
      (BIDIR(__), BIDIR(__)) => begin
        true
      end

      (INPUT(__), INPUT(__)) => begin
        true
      end

      (OUTPUT(__), OUTPUT(__)) => begin
        true
      end

      (INPUT_OUTPUT(__), INPUT_OUTPUT(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outEqual
end

function isFieldEqual(isField1::IsField, isField2::IsField)::Bool
  local outEqual::Bool

  @assign outEqual = begin
    @match (isField1, isField2) begin
      (NONFIELD(__), NONFIELD(__)) => begin
        true
      end

      (FIELD(__), FIELD(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outEqual
end

function componentName(c::ComponentItem)::String
  local name::String

  @match COMPONENTITEM(component = COMPONENT(name = name)) = c
  return name
end

# Current OMC signature: replace the last identifier by name.
function pathSetLastIdent(inPath::Path, ident::String)::Path
  return pathSetLastIdent(inPath, IDENT(ident))
end

function pathSetLastIdent(inPath::Path, inLastIdent::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local p::Path
    local n::String
    @match (inPath, inLastIdent) begin
      (IDENT(__), _) => begin
        inLastIdent
      end

      (QUALIFIED(n, p), _) => begin
        @assign p = pathSetLastIdent(p, inLastIdent)
        QUALIFIED(n, p)
      end

      (FULLYQUALIFIED(p), _) => begin
        @assign p = pathSetLastIdent(p, inLastIdent)
        FULLYQUALIFIED(p)
      end
    end
  end
  return outPath
end

"""
  @author:
  returns true if expression is initial()
"""
function isInitial(inExp::Exp)::Bool
  local hasReinit::Bool

  @assign hasReinit = begin
    @match inExp begin
      CALL(function_ = CREF_IDENT("initial", _)) => begin
        true
      end

      CALL(function_ = CREF_FULLYQUALIFIED(CREF_IDENT("initial", _))) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return hasReinit
end

"""Returns the import name of a named or qualified import."""
function importName(inImport::Import)::Ident
  local outName::Ident

  @assign outName = begin
    local name::Ident
    local path::Path
    #=  Named import has a given name, 'import D = A.B.C' => D.
    =#
    @match inImport begin
      NAMED_IMPORT(name = name) => begin
        name
      end

      QUAL_IMPORT(path = path) => begin
        pathLastIdent(path)
      end
    end
  end
  #=  Qualified import uses the last identifier, 'import A.B.C' => C.
  =#
  return outName
end

"""
  This function takes an old annotation as first argument and a new
  annotation as  second argument and merges the two.
  Annotation \\\"parts\\\" that exist in both the old and the new annotation
  will be changed according to the new definition. For instance,
  merge_annotations(annotation(x=1,y=2),annotation(x=3))
  => annotation(x=3,y=2)
"""
function mergeAnnotations(inAnnotation1::Annotation, inAnnotation2::Annotation)::Annotation
  local outAnnotation::Annotation

  @assign outAnnotation = begin
    local oldmods::List{ElementArg}
    local newmods::List{ElementArg}
    local a::Annotation
    @match (inAnnotation1, inAnnotation2) begin
      (ANNOTATION(elementArgs = nil()), a) => begin
        a
      end

      (ANNOTATION(elementArgs = oldmods), ANNOTATION(elementArgs = newmods)) => begin
        ANNOTATION(mergeAnnotations2(oldmods, newmods))
      end
    end
  end
  return outAnnotation
end

function mergeAnnotations2(
  oldmods::List{<:ElementArg},
  newmods::List{<:ElementArg},
)::List{ElementArg}
  local res::List{ElementArg} = listReverse(oldmods)

  local mods::List{ElementArg}
  local b::Bool
  local p::Path
  local mod1::ElementArg
  local mod2::ElementArg

  for mod in newmods
    @match MODIFICATION(path = p) = mod
    try
      @assign mod2 = ListUtil.find(res, (p) -> isModificationOfPath(path = p))
      @assign mod1 = subModsInSameOrder(mod2, mod)
      @match (res, true) =
        ListUtil.replaceOnTrue(mod1, res, (p) -> isModificationOfPath(path = p))
    catch
      @assign res = _cons(mod, res)
    end
  end
  @assign res = listReverse(res)
  return res
end

"""returns true or false if the given path is in the list of modifications"""
function isModificationOfPath(mod::ElementArg, path::Path)::Bool
  local yes::Bool

  @assign yes = begin
    local id1::String
    local id2::String
    @match (mod, path) begin
      (MODIFICATION(path = IDENT(name = id1)), IDENT(name = id2)) => begin
        id1 == id2
      end

      _ => begin
        false
      end
    end
  end
  return yes
end

function subModsInSameOrder(oldmod::ElementArg, newmod::ElementArg)::ElementArg
  local mod::ElementArg

  @assign mod = begin
    local args1::List{ElementArg}
    local args2::List{ElementArg}
    local res::List{ElementArg}
    local arg2::ElementArg
    local eq1::EqMod
    local eq2::EqMod
    local p::Path
    #=  mod1 or mod2 has no submods
    =#
    @match (oldmod, newmod) begin
      (_, MODIFICATION(modification = NONE())) => begin
        newmod
      end

      (MODIFICATION(modification = NONE()), _) => begin
        newmod
      end

      (
        MODIFICATION(modification = SOME(CLASSMOD(args1, _))),
        arg2 && MODIFICATION(modification = SOME(CLASSMOD(args2, eq2))),
      ) => begin
        #=  mod1
        =#
        #=  Delete all items from args2 that are not in args1
        =#
        @assign res = nil
        for arg1 in args1
          @match MODIFICATION(path = p) = arg1
          if ListUtil.exist(args2, (p) -> isModificationOfPath(path = p))
            @assign res = _cons(arg1, res)
          end
        end
        @assign res = listReverse(res)
        #=  Merge the annotations
        =#
        @assign res = mergeAnnotations2(res, args2)
        @assign arg2.modification = SOME(CLASSMOD(res, eq2))
        arg2
      end
    end
  end
  return mod
end

function typeSpecString(inTs::TypeSpec)::String
  local outStr::String

  @assign outStr = Absyn.dumpTypeSpec(inTs)
  return outStr
end

function crefString(inCr::ComponentRef)::String
  local outStr::String

  @assign outStr = Absyn.dumpCref(inCr)
  return outStr
end

function typeSpecStringNoQualNoDims(inTs::TypeSpec)::String
  local outStr::String

  @assign outStr = begin
    local str::Ident
    local s::Ident
    local str1::Ident
    local str2::Ident
    local str3::Ident
    local path::Path
    local adim::Option{List{Subscript}}
    local typeSpecLst::List{TypeSpec}
    @match inTs begin
      TPATH(path = path) => begin
        @assign str = pathString(makeNotFullyQualified(path))
        str
      end

      TCOMPLEX(path = path, typeSpecs = typeSpecLst) => begin
        @assign str1 = pathString(makeNotFullyQualified(path))
        @assign str2 = typeSpecStringNoQualNoDimsLst(typeSpecLst)
        @assign str = stringAppendList(list(str1, "<", str2, ">"))
        str
      end
    end
  end
  return outStr
end

function typeSpecStringNoQualNoDimsLst(inTypeSpecLst::List{<:TypeSpec})::String
  local outString::String
  outString = ListUtil.toString(inTypeSpecLst, typeSpecStringNoQualNoDims, "", "", ", ", "", false)
  return outString
end

"""An import clause as Modelica, without `import` and the semicolon: `SI = Modelica.Units.SI`, `A.B`, `A.B.*`,
`A.{b, c = d}`."""
function importString(inImp::Import)::String
  return @match inImp begin
    NAMED_IMPORT(__) => inImp.name + " = " + Absyn.dumpPath(inImp.path)
    QUAL_IMPORT(__) => Absyn.dumpPath(inImp.path)
    UNQUAL_IMPORT(__) => Absyn.dumpPath(inImp.path) + ".*"
    GROUP_IMPORT(__) => Absyn.dumpPath(inImp.prefix) + ".{" +
      join(String[g isa GROUP_IMPORT_NAME ? g.name : (g::GROUP_IMPORT_RENAME).rename * " = " * g.name for g in inImp.groups],
           ", ") + "}"
  end
end

"""Removes a variable from a variable list"""
function removeCrefFromCrefs(
  inAbsynComponentRefLst::List{<:ComponentRef},
  inComponentRef::ComponentRef,
)::List{ComponentRef}
  local outAbsynComponentRefLst::List{ComponentRef}

  @assign outAbsynComponentRefLst = begin
    local n1::String
    local n2::String
    local rest_1::List{ComponentRef}
    local rest::List{ComponentRef}
    local cr1::ComponentRef
    local cr2::ComponentRef
    @matchcontinue (inAbsynComponentRefLst, inComponentRef) begin
      (nil(), _) => begin
        nil
      end

      (cr1 <| rest, cr2) => begin
        @match CREF_IDENT(name = n1, subscripts = nil) = cr1
        @match CREF_IDENT(name = n2, subscripts = nil) = cr2
        @match true = stringEq(n1, n2)
        @assign rest_1 = removeCrefFromCrefs(rest, cr2)
        rest_1
      end

      (cr1 <| rest, cr2) => begin
        @match CREF_QUAL(name = n1) = cr1
        @match CREF_IDENT(name = n2) = cr2
        @match true = stringEq(n1, n2)
        @assign rest_1 = removeCrefFromCrefs(rest, cr2)
        rest_1
      end

      (cr1 <| rest, cr2) => begin
        @assign rest_1 = removeCrefFromCrefs(rest, cr2)
        _cons(cr1, rest_1)
      end
    end
  end
  #=  If modifier like on comp like: T t(x=t.y) => t.y must be removed
  =#
  return outAbsynComponentRefLst
end

"""Helper function to getNamedAnnotationInElementitemlist."""
function getNamedAnnotationStr(
  inAbsynElementArgLst::List{<:ElementArg},
  id::Path,
  f::ModFunc,
)::Option{TypeA}
  local outString::Option{TypeA}

  @assign outString = begin
    local str::TypeA
    local ann::ElementArg
    local mod::Option{Modification}
    local xs::List{ElementArg}
    local id1::Ident
    local id2::Ident
    local rest::Path
    @matchcontinue (inAbsynElementArgLst, id, f) begin
      (MODIFICATION(path = IDENT(name = id1), modification = mod) <| _, IDENT(id2), _) =>
        begin
          @match true = stringEq(id1, id2)
          @assign str = f(mod)
          SOME(str)
        end

      (
        MODIFICATION(
          path = IDENT(name = id1),
          modification = SOME(CLASSMOD(elementArgLst = xs)),
        ) <| _,
        QUALIFIED(name = id2, path = rest),
        _,
      ) => begin
        @match true = stringEq(id1, id2)
        getNamedAnnotationStr(xs, rest, f)
      end

      (_ <| xs, _, _) => begin
        getNamedAnnotationStr(xs, id, f)
      end
    end
  end
  return outString
end

"""
  This function splits each part of a cref into CREF_IDENTs and applies the
  given function to each part. If the given cref is a qualified cref then the
  map function is expected to also return CREF_IDENT, so that the split cref
  can be reconstructed. Otherwise the map function is free to return whatever
  it wants.
"""
function mapCrefParts(inCref::ComponentRef, inMapFunc::MapFunc)::ComponentRef
  local outCref::ComponentRef

  @assign outCref = begin
    local name::Ident
    local subs::List{Subscript}
    local rest_cref::ComponentRef
    local cref::ComponentRef
    @match (inCref, inMapFunc) begin
      (CREF_QUAL(name, subs, rest_cref), _) => begin
        @assign cref = CREF_IDENT(name, subs)
        @match CREF_IDENT(name, subs) = inMapFunc(cref)
        @assign rest_cref = mapCrefParts(rest_cref, inMapFunc)
        CREF_QUAL(name, subs, rest_cref)
      end

      (CREF_FULLYQUALIFIED(cref), _) => begin
        @assign cref = mapCrefParts(cref, inMapFunc)
        CREF_FULLYQUALIFIED(cref)
      end

      _ => begin
        @assign cref = inMapFunc(inCref)
        cref
      end
    end
  end
  return outCref
end

function dummyTraverseExp(inExp::Exp, inArg::Arg)::Tuple{Exp, Arg}
  local outArg::Arg
  local outExp::Exp

  @assign outExp = inExp
  @assign outArg = inArg
  return (outExp, outArg)
end

"""retrives defineunit definitions in elements"""
function getDefineUnitsInElements(elts::List{<:ElementItem})::List{Element}
  local outElts::List{Element}

  @assign outElts = begin
    local e::Element
    local rest::List{ElementItem}
    @matchcontinue elts begin
      nil() => begin
        nil
      end

      ELEMENTITEM(e && DEFINEUNIT(__)) <| rest => begin
        @assign outElts = getDefineUnitsInElements(rest)
        _cons(e, outElts)
      end

      _ <| rest => begin
        getDefineUnitsInElements(rest)
      end
    end
  end
  return outElts
end

function isEmptyMod(inMod::Modification)::Bool
  local outIsEmpty::Bool

  @assign outIsEmpty = begin
    @match inMod begin
      CLASSMOD(nil(), NOMOD(__)) => begin
        true
      end

      CLASSMOD(nil(), EQMOD(exp = TUPLE(expressions = nil()))) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsEmpty
end

"""Splits a cref into parts."""
function crefExplode(
  inCref::ComponentRef,
  inAccum::List{<:ComponentRef} = nil,
)::List{ComponentRef}
  local outCrefParts::List{ComponentRef}

  @assign outCrefParts = begin
    @match inCref begin
      CREF_QUAL(__) => begin
        crefExplode(inCref.componentRef, _cons(crefFirstCref(inCref), inAccum))
      end

      CREF_FULLYQUALIFIED(__) => begin
        crefExplode(inCref.componentRef, inAccum)
      end

      _ => begin
        listReverse(_cons(inCref, inAccum))
      end
    end
  end
  return outCrefParts
end

function isAlgorithmItem(inAlg::AlgorithmItem)::Bool
  local outIsClass::Bool

  @assign outIsClass = begin
    @match inAlg begin
      ALGORITHMITEM(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsClass
end

"""Returns the number of parts a path consists of, e.g. A.B.C gives 3."""
function pathPartCount(path::Path, partsAccum::Int = 0)::Int
  local parts::Int

  @assign parts = begin
    @match path begin
      Path.IDENT(__) => begin
        partsAccum + 1
      end

      Path.QUALIFIED(__) => begin
        pathPartCount(path.path, partsAccum + 1)
      end

      Path.FULLYQUALIFIED(__) => begin
        pathPartCount(path.path, partsAccum)
      end
    end
  end
  return parts
end

"""
  This function strips out the `graphics\\' modification from an ElementArg
  list and return two lists, one with the other modifications and the
  second with the `graphics\\' modification
"""
function stripGraphicsAndInteractionModification(
  inAbsynElementArgLst::List{<:Absyn.ElementArg},
)::Tuple{List{Absyn.ElementArg}, List{Absyn.ElementArg}}
  local outAbsynElementArgLst2::List{Absyn.ElementArg}
  local outAbsynElementArgLst1::List{Absyn.ElementArg}

  @assign (outAbsynElementArgLst1, outAbsynElementArgLst2) = begin
    local mod::Absyn.ElementArg
    local rest::List{Absyn.ElementArg}
    local l1::List{Absyn.ElementArg}
    local l2::List{Absyn.ElementArg}
    #=  handle empty
    =#
    @matchcontinue inAbsynElementArgLst begin
      nil() => begin
        (nil, nil)
      end

      Absyn.MODIFICATION(path = Absyn.IDENT(name = "interaction")) <| rest => begin
        @assign (l1, l2) = stripGraphicsAndInteractionModification(rest)
        (l1, l2)
      end

      Absyn.MODIFICATION(modification = NONE(), path = Absyn.IDENT(name = "graphics")) <|
      rest => begin
        @assign (l1, l2) = stripGraphicsAndInteractionModification(rest)
        (l1, l2)
      end

      mod &&
        Absyn.MODIFICATION(modification = SOME(_), path = Absyn.IDENT(name = "graphics")) <| rest => begin
        @assign (l1, l2) = stripGraphicsAndInteractionModification(rest)
        (l1, _cons(mod, l2))
      end

      mod && Absyn.MODIFICATION(__) <| rest => begin
        @assign (l1, l2) = stripGraphicsAndInteractionModification(rest)
        (_cons(mod, l1), l2)
      end
    end
  end
  #=  adrpo: remove interaction annotations as we don't handle them currently
  =#
  #=  adrpo: remove empty annotations, to handle bad Dymola annotations, for example: Diagram(graphics)
  =#
  #=  add graphics to the second tuple
  =#
  #=  collect in the first tuple
  =#
  return (outAbsynElementArgLst1, outAbsynElementArgLst2)
end

"""Helperfunction to traverseClasses."""
function traverseClasses2(
  inClasses::List{<:Absyn.Class},
  inPath::Option{<:Absyn.Path},
  inFunc::FuncType,
  inArg::Type_a,
  inVisitProtected::Bool,
)::Tuple{List{Absyn.Class}, Option{Absyn.Path}, Type_a} #= visit protected elements =#
  local outTpl::Tuple{List{Absyn.Class}, Option{Absyn.Path}, Type_a}

  @assign outTpl = begin
    local pa::Option{Absyn.Path}
    local pa_1::Option{Absyn.Path}
    local pa_2::Option{Absyn.Path}
    local pa_3::Option{Absyn.Path}
    local visitor::FuncType
    local args::Type_a
    local args_1::Type_a
    local args_2::Type_a
    local args_3::Type_a
    local class_1::Absyn.Class
    local class_2::Absyn.Class
    local class_::Absyn.Class
    local classes_1::List{Absyn.Class}
    local classes::List{Absyn.Class}
    local traverse_prot::Bool
    @matchcontinue (inClasses, inPath, inFunc, inArg, inVisitProtected) begin
      (nil(), pa, _, args, _) => begin
        (nil, pa, args)
      end

      (class_ <| classes, pa, visitor, args, traverse_prot) => begin
        @assign (class_1, _, args_1) = visitor((class_, pa, args))
        @assign (class_2, _, args_2) =
          traverseInnerClass(class_1, pa, visitor, args_1, traverse_prot)
        @assign (classes_1, pa_3, args_3) =
          traverseClasses2(classes, pa, visitor, args_2, traverse_prot)
        (_cons(class_2, classes_1), pa_3, args_3)
      end

      (class_ <| classes, pa, visitor, args, traverse_prot) => begin
        @assign (class_2, _, args_2) =
          traverseInnerClass(class_, pa, visitor, args, traverse_prot)
        @match true = classHasLocalClasses(class_2)
        @assign (classes_1, pa_3, args_3) =
          traverseClasses2(classes, pa, visitor, args_2, traverse_prot)
        (_cons(class_2, classes_1), pa_3, args_3)
      end

      (_ <| classes, pa, visitor, args, traverse_prot) => begin
        @assign (classes_1, pa_3, args_3) =
          traverseClasses2(classes, pa, visitor, args, traverse_prot)
        (classes_1, pa_3, args_3)
      end

      (class_ <| _, _, _, _, _) => begin
        print("-traverse_classes2 failed on class:")
        print(AbsynUtil.pathString(AbsynUtil.className(class_)))
        print("\\n")
        fail()
      end
    end
  end
  #= /* Visitor failed, but class contains inner classes after traversal, i.e. those inner classes didn't fail, and thus
     the class must be included also */ =#
  #= /* Visitor failed, remove class */ =#
  return outTpl
end

"""Returns true if class contains a local class"""
function classHasLocalClasses(cl::Absyn.Class)::Bool
  local res::Bool

  @assign res = begin
    local parts::List{Absyn.ClassPart}
    #=  A class with parts.
    =#
    @match cl begin
      Absyn.CLASS(body = Absyn.PARTS(classParts = parts)) => begin
        @assign res = partsHasLocalClass(parts)
        res
      end

      Absyn.CLASS(body = Absyn.CLASS_EXTENDS(parts = parts)) => begin
        @assign res = partsHasLocalClass(parts)
        res
      end
    end
  end
  #=  An extended class with parts: model extends M end M;
  =#
  return res
end

"""Help function to classHasLocalClass"""
function partsHasLocalClass(inParts::List{<:Absyn.ClassPart})::Bool
  local res::Bool

  @assign res = begin
    local elts::List{Absyn.ElementItem}
    local parts::List{Absyn.ClassPart}
    @match inParts begin
      Absyn.PUBLIC(elts) <| _ => begin
        eltsHasLocalClass(elts)
      end

      Absyn.PROTECTED(elts) <| _ => begin
        eltsHasLocalClass(elts)
      end

      _ <| parts => begin
        partsHasLocalClass(parts)
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""help function to partsHasLocalClass"""
function eltsHasLocalClass(inElts::List{<:Absyn.ElementItem})::Bool
  local res::Bool

  @assign res = begin
    local elts::List{Absyn.ElementItem}
    @match inElts begin
      Absyn.ELEMENTITEM(Absyn.ELEMENT(specification = Absyn.CLASSDEF(__))) <| _ => begin
        true
      end

      _ <| elts => begin
        eltsHasLocalClass(elts)
      end

      nil() => begin
        false
      end
    end
  end
  return res
end

"""Help function to classHasLocalClassOfType"""
function partsHasLocalClassOfType(
  inParts::List{<:Absyn.ClassPart},
  inRestriction::Absyn.Restriction,
)::Bool
  local res::Bool

  @assign res = begin
    local elts::List{Absyn.ElementItem}
    local parts::List{Absyn.ClassPart}
    @matchcontinue inParts begin
      Absyn.PUBLIC(contents = elts) <| _ => begin
        eltsHasLocalClassOfType(elts, inRestriction)
      end

      Absyn.PROTECTED(contents = elts) <| _ => begin
        eltsHasLocalClassOfType(elts, inRestriction)
      end

      _ <| parts => begin
        partsHasLocalClassOfType(parts, inRestriction)
      end

      nil() => begin
        fail()
      end
    end
  end
  return res
end

"""
  Returns true if there exists a local class which is restricted to the supplied restriction.
  Otherwise fails
"""
function eltsHasLocalClassOfType(
  inElts::List{<:Absyn.ElementItem},
  inRestriction::Absyn.Restriction,
)::Bool
  local res::Bool

  @assign res = begin
    local elts::List{Absyn.ElementItem}
    local restriction::Restriction
    @matchcontinue inElts begin
      Absyn.ELEMENTITEM(Absyn.ELEMENT(
        specification = Absyn.CLASSDEF(class_ = CLASS(restriction = restriction)),
      )) <| _ => begin
        @assign res = valueEq(restriction, inRestriction)
        if res == false
          fail()
        end
        #= Go to next
        =#
        res
      end

      _ <| elts => begin
        eltsHasLocalClassOfType(elts, inRestriction)
      end

      nil() => begin
        fail()
      end
    end
  end
  return res
end

"""Helperfunction to traverseClasses2. This function traverses all inner classes of a class."""
function traverseInnerClass(
  inClass::Absyn.Class,
  inPath::Option{<:Absyn.Path},
  inFunc::FuncType,
  inArg::Type_a,
  inVisitProtected::Bool,
)::Tuple{Absyn.Class, Option{Absyn.Path}, Type_a} #= if true, traverse protected elts =#
  local outTpl::Tuple{Absyn.Class, Option{Absyn.Path}, Type_a}

  @assign outTpl = begin
    local tmp_pa::Absyn.Path
    local pa::Absyn.Path
    local parts_1::List{Absyn.ClassPart}
    local parts::List{Absyn.ClassPart}
    local pa_1::Option{Absyn.Path}
    local args_1::Type_a
    local args::Type_a
    local name::String
    local bcname::String
    local p::Bool
    local f::Bool
    local e::Bool
    local visit_prot::Bool
    local r::Absyn.Restriction
    local str_opt::Option{String}
    local file_info::SourceInfo
    local visitor::FuncType
    local cl::Absyn.Class
    local modif::List{Absyn.ElementArg}
    local typeVars::List{String}
    local classAttrs::List{Absyn.NamedArg}
    local cmt::Absyn.Comment
    local ann::List{Absyn.Annotation}
    #= /* a class with parts */ =#
    @matchcontinue (inClass, inPath, inFunc, inArg, inVisitProtected) begin
      (
        Absyn.CLASS(
          name,
          p,
          f,
          e,
          r,
          Absyn.PARTS(typeVars, classAttrs, parts, ann, str_opt),
          file_info,
        ),
        SOME(pa),
        visitor,
        args,
        visit_prot,
      ) => begin
        @assign tmp_pa = AbsynUtil.joinPaths(pa, Absyn.IDENT(name))
        @assign (parts_1, pa_1, args_1) =
          traverseInnerClassParts(parts, SOME(tmp_pa), visitor, args, visit_prot)
        (
          Absyn.CLASS(
            name,
            p,
            f,
            e,
            r,
            Absyn.PARTS(typeVars, classAttrs, parts_1, ann, str_opt),
            file_info,
          ),
          pa_1,
          args_1,
        )
      end

      (
        Absyn.CLASS(
          name = name,
          partialPrefix = p,
          finalPrefix = f,
          encapsulatedPrefix = e,
          restriction = r,
          body = Absyn.PARTS(
            typeVars = typeVars,
            classAttrs = classAttrs,
            classParts = parts,
            ann = ann,
            comment = str_opt,
          ),
          info = file_info,
        ),
        NONE(),
        visitor,
        args,
        visit_prot,
      ) => begin
        @assign (parts_1, pa_1, args_1) = traverseInnerClassParts(
          parts,
          SOME(Absyn.IDENT(name)),
          visitor,
          args,
          visit_prot,
        )
        (
          Absyn.CLASS(
            name,
            p,
            f,
            e,
            r,
            Absyn.PARTS(typeVars, classAttrs, parts_1, ann, str_opt),
            file_info,
          ),
          pa_1,
          args_1,
        )
      end

      (
        Absyn.CLASS(
          name = name,
          partialPrefix = p,
          finalPrefix = f,
          encapsulatedPrefix = e,
          restriction = r,
          body = Absyn.PARTS(
            typeVars = typeVars,
            classAttrs = classAttrs,
            classParts = parts,
            ann = ann,
            comment = str_opt,
          ),
          info = file_info,
        ),
        pa_1,
        visitor,
        args,
        visit_prot,
      ) => begin
        @assign (parts_1, pa_1, args_1) =
          traverseInnerClassParts(parts, pa_1, visitor, args, visit_prot)
        (
          Absyn.CLASS(
            name,
            p,
            f,
            e,
            r,
            Absyn.PARTS(typeVars, classAttrs, parts_1, ann, str_opt),
            file_info,
          ),
          pa_1,
          args_1,
        )
      end

      (
        Absyn.CLASS(
          name = name,
          partialPrefix = p,
          finalPrefix = f,
          encapsulatedPrefix = e,
          restriction = r,
          body = Absyn.CLASS_EXTENDS(
            baseClassName = bcname,
            comment = str_opt,
            modifications = modif,
            parts = parts,
            ann = ann,
          ),
          info = file_info,
        ),
        SOME(pa),
        visitor,
        args,
        visit_prot,
      ) => begin
        @assign tmp_pa = AbsynUtil.joinPaths(pa, Absyn.IDENT(name))
        @assign (parts_1, pa_1, args_1) =
          traverseInnerClassParts(parts, SOME(tmp_pa), visitor, args, visit_prot)
        (
          Absyn.CLASS(
            name,
            p,
            f,
            e,
            r,
            Absyn.CLASS_EXTENDS(bcname, modif, str_opt, parts_1, ann),
            file_info,
          ),
          pa_1,
          args_1,
        )
      end

      (
        Absyn.CLASS(
          name = name,
          partialPrefix = p,
          finalPrefix = f,
          encapsulatedPrefix = e,
          restriction = r,
          body = Absyn.CLASS_EXTENDS(
            baseClassName = bcname,
            comment = str_opt,
            modifications = modif,
            parts = parts,
            ann = ann,
          ),
          info = file_info,
        ),
        NONE(),
        visitor,
        args,
        visit_prot,
      ) => begin
        @assign (parts_1, pa_1, args_1) = traverseInnerClassParts(
          parts,
          SOME(Absyn.IDENT(name)),
          visitor,
          args,
          visit_prot,
        )
        (
          Absyn.CLASS(
            name,
            p,
            f,
            e,
            r,
            Absyn.CLASS_EXTENDS(bcname, modif, str_opt, parts_1, ann),
            file_info,
          ),
          pa_1,
          args_1,
        )
      end

      (
        Absyn.CLASS(
          name = name,
          partialPrefix = p,
          finalPrefix = f,
          encapsulatedPrefix = e,
          restriction = r,
          body = Absyn.CLASS_EXTENDS(
            baseClassName = bcname,
            comment = str_opt,
            modifications = modif,
            parts = parts,
            ann = ann,
          ),
          info = file_info,
        ),
        pa_1,
        visitor,
        args,
        visit_prot,
      ) => begin
        @assign (parts_1, pa_1, args_1) =
          traverseInnerClassParts(parts, pa_1, visitor, args, visit_prot)
        (
          Absyn.CLASS(
            name,
            p,
            f,
            e,
            r,
            Absyn.CLASS_EXTENDS(bcname, modif, str_opt, parts_1, ann),
            file_info,
          ),
          pa_1,
          args_1,
        )
      end

      (cl, pa_1, _, args, _) => begin
        (cl, pa_1, args)
      end
    end
  end
  #= /* adrpo: handle also an extended class with parts: model extends M end M; */ =#
  #= /* otherwise */ =#
  return outTpl
end

"""Helper function to traverseInnerClass"""
function traverseInnerClassParts(
  inClassParts::List{<:Absyn.ClassPart},
  inPath::Option{<:Absyn.Path},
  inFunc::FuncType,
  inArg::Type_a,
  inVisitProtected::Bool,
)::Tuple{List{Absyn.ClassPart}, Option{Absyn.Path}, Type_a} #= visist protected elts =#
  local outTpl::Tuple{List{Absyn.ClassPart}, Option{Absyn.Path}, Type_a}

  @assign outTpl = begin
    local pa::Option{Absyn.Path}
    local pa_1::Option{Absyn.Path}
    local pa_2::Option{Absyn.Path}
    local args::Type_a
    local args_1::Type_a
    local args_2::Type_a
    local elts_1::List{Absyn.ElementItem}
    local elts::List{Absyn.ElementItem}
    local parts_1::List{Absyn.ClassPart}
    local parts::List{Absyn.ClassPart}
    local visitor::FuncType
    local visit_prot::Bool
    local part::Absyn.ClassPart
    @matchcontinue (inClassParts, inPath, inFunc, inArg, inVisitProtected) begin
      (nil(), pa, _, args, _) => begin
        (nil, pa, args)
      end

      (Absyn.PUBLIC(contents = elts) <| parts, pa, visitor, args, visit_prot) => begin
        @assign (elts_1, _, args_1) =
          traverseInnerClassElements(elts, pa, visitor, args, visit_prot)
        @assign (parts_1, pa_2, args_2) =
          traverseInnerClassParts(parts, pa, visitor, args_1, visit_prot)
        (_cons(Absyn.PUBLIC(elts_1), parts_1), pa_2, args_2)
      end

      (Absyn.PROTECTED(contents = elts) <| parts, pa, visitor, args, true) => begin
        @assign (elts_1, _, args_1) =
          traverseInnerClassElements(elts, pa, visitor, args, true)
        @assign (parts_1, pa_2, args_2) =
          traverseInnerClassParts(parts, pa, visitor, args_1, true)
        (_cons(Absyn.PROTECTED(elts_1), parts_1), pa_2, args_2)
      end

      (part <| parts, pa, visitor, args, true) => begin
        @assign (parts_1, pa_1, args_1) =
          traverseInnerClassParts(parts, pa, visitor, args, true)
        (_cons(part, parts_1), pa_1, args_1)
      end
    end
  end
  return outTpl
end

"""Helper function to traverseInnerClassParts"""
function traverseInnerClassElements(
  inElements::List{<:Absyn.ElementItem},
  inPath::Option{<:Absyn.Path},
  inFuncType::FuncType,
  inArg::Type_a,
  inVisitProtected::Bool,
)::Tuple{List{Absyn.ElementItem}, Option{Absyn.Path}, Type_a} #= visit protected elts =#
  local outTpl::Tuple{List{Absyn.ElementItem}, Option{Absyn.Path}, Type_a}

  @assign outTpl = begin
    local pa::Option{Absyn.Path}
    local pa_1::Option{Absyn.Path}
    local pa_2::Option{Absyn.Path}
    local args::Type_a
    local args_1::Type_a
    local args_2::Type_a
    local elt_spec_1::Absyn.ElementSpec
    local elt_spec::Absyn.ElementSpec
    local elts_1::List{Absyn.ElementItem}
    local elts::List{Absyn.ElementItem}
    local f::Bool
    local visit_prot::Bool
    local r::Option{Absyn.RedeclareKeywords}
    local io::Absyn.InnerOuter
    local info::SourceInfo
    local constr::Option{Absyn.ConstrainClass}
    local visitor::FuncType
    local elt::Absyn.ElementItem
    local repl::Bool
    local cl::Absyn.Class
    @matchcontinue (inElements, inPath, inFuncType, inArg, inVisitProtected) begin
      (nil(), pa, _, args, _) => begin
        (nil, pa, args)
      end

      (
        Absyn.ELEMENTITEM(
          element = Absyn.ELEMENT(
            finalPrefix = f,
            redeclareKeywords = r,
            innerOuter = io,
            specification = elt_spec,
            info = info,
            constrainClass = constr,
          ),
        ) <| elts,
        pa,
        visitor,
        args,
        visit_prot,
      ) => begin
        @assign (elt_spec_1, _, args_1) =
          traverseInnerClassElementspec(elt_spec, pa, visitor, args, visit_prot)
        @assign (elts_1, pa_2, args_2) =
          traverseInnerClassElements(elts, pa, visitor, args_1, visit_prot)
        (
          _cons(
            Absyn.ELEMENTITEM(Absyn.ELEMENT(f, r, io, elt_spec_1, info, constr)),
            elts_1,
          ),
          pa_2,
          args_2,
        )
      end

      (
        Absyn.ELEMENTITEM(
          element = Absyn.ELEMENT(
            finalPrefix = f,
            redeclareKeywords = r,
            innerOuter = io,
            specification = Absyn.CLASSDEF(repl, cl),
            info = info,
            constrainClass = constr,
          ),
        ) <| elts,
        pa,
        visitor,
        args,
        visit_prot,
      ) => begin
        @assign (cl, _, args_1) = traverseInnerClass(cl, pa, visitor, args, visit_prot)
        @match true = classHasLocalClasses(cl)
        @assign (elts_1, pa_2, args_2) =
          traverseInnerClassElements(elts, pa, visitor, args_1, visit_prot)
        (
          _cons(
            Absyn.ELEMENTITEM(Absyn.ELEMENT(
              f,
              r,
              io,
              Absyn.CLASSDEF(repl, cl),
              info,
              constr,
            )),
            elts_1,
          ),
          pa_2,
          args_2,
        )
      end

      (
        Absyn.ELEMENTITEM(element = Absyn.ELEMENT(__)) <| elts,
        pa,
        visitor,
        args,
        visit_prot,
      ) => begin
        @assign (elts_1, pa_2, args_2) =
          traverseInnerClassElements(elts, pa, visitor, args, visit_prot)
        (elts_1, pa_2, args_2)
      end

      (elt <| elts, pa, visitor, args, visit_prot) => begin
        @assign (elts_1, pa_1, args_1) =
          traverseInnerClassElements(elts, pa, visitor, args, visit_prot)
        (_cons(elt, elts_1), pa_1, args_1)
      end
    end
  end
  #= /* Visitor failed in elementspec, but inner classes succeeded, include class */ =#
  #= /* Visitor failed in elementspec, remove class */ =#
  return outTpl
end

"""Helperfunction to traverseInnerClassElements"""
function traverseInnerClassElementspec(
  inElementSpec::Absyn.ElementSpec,
  inPath::Option{<:Absyn.Path},
  inFuncType::FuncType,
  inArg::Type_a,
  inVisitProtected::Bool,
)::Tuple{Absyn.ElementSpec, Option{Absyn.Path}, Type_a} #= visit protected elts =#
  local outTpl::Tuple{Absyn.ElementSpec, Option{Absyn.Path}, Type_a}

  @assign outTpl = begin
    local class_1::Absyn.Class
    local class_2::Absyn.Class
    local class_::Absyn.Class
    local pa_1::Option{Absyn.Path}
    local pa_2::Option{Absyn.Path}
    local pa::Option{Absyn.Path}
    local args_1::Type_a
    local args_2::Type_a
    local args::Type_a
    local repl::Bool
    local visit_prot::Bool
    local visitor::FuncType
    local elt_spec::Absyn.ElementSpec
    @match (inElementSpec, inPath, inFuncType, inArg, inVisitProtected) begin
      (Absyn.CLASSDEF(replaceable_ = repl, class_ = class_), pa, visitor, args, visit_prot) => begin
        @assign (class_1, _, args_1) = visitor((class_, pa, args))
        @assign (class_2, pa_2, args_2) =
          traverseInnerClass(class_1, pa, visitor, args_1, visit_prot)
        (Absyn.CLASSDEF(repl, class_2), pa_2, args_2)
      end

      (elt_spec && Absyn.EXTENDS(__), pa, _, args, _) => begin
        (elt_spec, pa, args)
      end

      (elt_spec && Absyn.IMPORT(__), pa, _, args, _) => begin
        (elt_spec, pa, args)
      end

      (elt_spec && Absyn.COMPONENTS(__), pa, _, args, _) => begin
        (elt_spec, pa, args)
      end
    end
  end
  return outTpl
end

"""
  @author johti
  Get the direction if one exists otherwise returns BIDIR()
"""
function getDirection(elementItem::Absyn.ElementItem)::Direction
  local oDirection::Direction

  @assign oDirection = begin
    local element::Element
    @matchcontinue elementItem begin
      ELEMENTITEM(element = element) => begin
        begin
          local specification::ElementSpec
          @match element begin
            ELEMENT(specification = specification) => begin
              begin
                local attributes::ElementAttributes
                @match specification begin
                  COMPONENTS(attributes = attributes) => begin
                    begin
                      local direction::Direction
                      @match attributes begin
                        ATTR(direction = direction) => begin
                          direction
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      _ => begin
        BIDIR()
      end
    end
  end
  return oDirection
end

function isNamedPathIdent(path::Absyn.Path, name::String)::Bool
  local res::Bool

  @assign res = begin
    @match path begin
      IDENT(__) => begin
        path.name == name
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""An expression as Modelica (Absyn.jl's printer)."""
printExp(exp::Exp)::String = Absyn.dumpExp(exp)

@exportAll()
end

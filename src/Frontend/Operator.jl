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
  Structure describing different operators
"""
struct OpStruct
  ADD::Int
  SUB::Int
  MUL::Int
  DIV::Int
  POW::Int
  ADD_EW::Int
  SUB_EW::Int
  MUL_EW::Int
  DIV_EW::Int
  POW_EW::Int
  ADD_SCALAR_ARRAY::Int
  ADD_ARRAY_SCALAR::Int
  SUB_SCALAR_ARRAY::Int
  SUB_ARRAY_SCALAR::Int
  MUL_SCALAR_ARRAY::Int
  MUL_ARRAY_SCALAR::Int
  MUL_VECTOR_MATRIX::Int
  MUL_MATRIX_VECTOR::Int
  SCALAR_PRODUCT::Int
  MATRIX_PRODUCT::Int
  DIV_SCALAR_ARRAY::Int
  DIV_ARRAY_SCALAR::Int
  POW_SCALAR_ARRAY::Int
  POW_ARRAY_SCALAR::Int
  POW_MATRIX::Int
  UMINUS::Int
  AND::Int
  OR::Int
  NOT::Int
  LESS::Int
  LESSEQ::Int
  GREATER::Int
  GREATEREQ::Int
  EQUAL::Int
  NEQUAL::Int
  USERDEFINED::Int
end

const Op = OpStruct(
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
)

const OpType = Int

#= OPERATOR is defined in FrontendInterfaces/Interfaces.jl, before the expressions that hold one. =#

function negate(op::OPERATOR)::OPERATOR
  local outOp::OPERATOR
  local neg_op::OpType
  neg_op = begin
    @match op.op begin
      Op.ADD => begin
        Op.SUB
      end

      Op.SUB => begin
        Op.ADD
      end

      Op.ADD_EW => begin
        Op.SUB_EW
      end

      Op.SUB_EW => begin
        Op.ADD_EW
      end

      Op.ADD_SCALAR_ARRAY => begin
        Op.SUB_SCALAR_ARRAY
      end

      Op.SUB_SCALAR_ARRAY => begin
        Op.ADD_SCALAR_ARRAY
      end

      Op.ADD_ARRAY_SCALAR => begin
        Op.SUB_ARRAY_SCALAR
      end
    end
  end
  outOp = OPERATOR(op.ty, neg_op)
  return outOp
end

function isElementWise(op::OPERATOR)::Bool
  @match op.op begin
    Op.ADD_EW => begin
      true
    end

    Op.SUB_EW => begin
      true
    end

    Op.MUL_EW => begin
      true
    end

    Op.DIV_EW => begin
      true
    end

    Op.POW_EW => begin
      true
    end

    _ => begin
      false
    end
  end
end

"""
The element-wise kind of an arithmetic operator (`Op.MUL` → `Op.MUL_EW`; omc's `Operator.makeEW`). An operation on
two arrays keeps it (`p .* p`, not the matrix product `p * p`). Other operators are returned as they are.
"""
function makeEW(op::OPERATOR)::OPERATOR
  local o::Int = op.op
  o == Op.ADD && return OPERATOR(op.ty, Op.ADD_EW)
  o == Op.SUB && return OPERATOR(op.ty, Op.SUB_EW)
  o == Op.MUL && return OPERATOR(op.ty, Op.MUL_EW)
  o == Op.DIV && return OPERATOR(op.ty, Op.DIV_EW)
  o == Op.POW && return OPERATOR(op.ty, Op.POW_EW)
  return op
end

function stripEW(op::OPERATOR)::OPERATOR
  opOP = @match op.op begin
    Op.ADD_EW => begin
      Op.ADD
    end

    Op.SUB_EW => begin
      Op.SUB
    end

    Op.MUL_EW => begin
      Op.MUL
    end

    Op.DIV_EW => begin
      Op.DIV
    end

    Op.POW_EW => begin
      Op.POW
    end
    _ => begin
      return op
    end
  end
  return OPERATOR(op.ty, opOP)
end

function makeArrayScalar(ty::ModelicaType, op::OpType)::OPERATOR
  local outOp::OPERATOR
  local o::OpType
  o = begin
    @match op begin
      Op.ADD => begin
        Op.ADD_ARRAY_SCALAR
      end

      Op.SUB => begin
        Op.SUB_ARRAY_SCALAR
      end

      Op.MUL => begin
        Op.MUL_ARRAY_SCALAR
      end

      Op.DIV => begin
        Op.DIV_ARRAY_SCALAR
      end

      Op.POW => begin
        Op.POW_ARRAY_SCALAR
      end
    end
  end
  outOp = OPERATOR(ty, o)
  return outOp
end

function makeScalarArray(ty::ModelicaType, op::OpType)::OPERATOR
  local outOp::OPERATOR
  local o::OpType
  o = begin
    @match op begin
      Op.ADD => begin
        Op.ADD_SCALAR_ARRAY
      end

      Op.SUB => begin
        Op.SUB_SCALAR_ARRAY
      end

      Op.MUL => begin
        Op.MUL_SCALAR_ARRAY
      end

      Op.DIV => begin
        Op.DIV_SCALAR_ARRAY
      end

      Op.POW => begin
        Op.POW_SCALAR_ARRAY
      end
    end
  end
  outOp = OPERATOR(ty, o)
  return outOp
end

function makeEqual(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.EQUAL)
  return op
end

function makeGreater(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.GREATER)
  return op
end

function makeLessEq(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.LESSEQ)
  return op
end

function makeLess(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.LESS)
  return op
end

function makeNot(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.NOT)
  return op
end

function makeOr(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.OR)
  return op
end

function makeAnd(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.AND)
  return op
end

function makeUMinus(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.UMINUS)
  return op
end

function makePow(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.POW)
  return op
end

function makeDiv(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.DIV)
  return op
end

function makeMul(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.MUL)
  return op
end

function makeSub(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.SUB)
  return op
end

function makeAdd(ty::ModelicaType)::OPERATOR
  local op::OPERATOR = OPERATOR(ty, Op.ADD)
  return op
end

function isNonAssociative(op::OPERATOR)::Bool

  @match op.op begin
    Op.POW => begin
      true
    end

    Op.POW_EW => begin
      true
    end

    Op.POW_SCALAR_ARRAY => begin
      true
    end

    Op.POW_ARRAY_SCALAR => begin
      true
    end

    Op.POW_MATRIX => begin
      true
    end

    _ => begin
      false
    end
  end
end

function isAssociative(op::OPERATOR)::Bool
  local isAssoc::Bool

  isAssoc = begin
    @match op.op begin
      Op.ADD => begin
        true
      end

      Op.ADD_EW => begin
        true
      end

      Op.MUL_EW => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  #= case ADD_ARRAY_SCALAR() then true;
     case MUL_ARRAY_SCALAR() then true; =#
  return isAssoc
end

function priority(op::OPERATOR, lhs::Bool)::Int

  @match op.op begin
    Op.ADD => begin
      if lhs
        5
      else
        6
      end
    end

    Op.SUB => begin
      5
    end

    Op.MUL => begin
      2
    end

    Op.DIV => begin
      2
    end

    Op.POW => begin
      1
    end

    Op.ADD_EW => begin
      if lhs
        5
      else
        6
      end
    end

    Op.SUB_EW => begin
      5
    end

    Op.MUL_EW => begin
      if lhs
        2
      else
        3
      end
    end

    Op.DIV_EW => begin
      2
    end

    Op.POW_EW => begin
      1
    end

    #= The array kinds as their scalar operator (omc's Operator.priority): with 0 the right operand of each got
       parentheses (`{1.0, 2.0} .* (time)`). =#
    Op.ADD_SCALAR_ARRAY || Op.ADD_ARRAY_SCALAR => begin
      if lhs
        5
      else
        6
      end
    end

    Op.SUB_SCALAR_ARRAY || Op.SUB_ARRAY_SCALAR => begin
      5
    end

    Op.MUL_SCALAR_ARRAY || Op.MUL_ARRAY_SCALAR || Op.MUL_VECTOR_MATRIX || Op.MUL_MATRIX_VECTOR ||
    Op.SCALAR_PRODUCT || Op.MATRIX_PRODUCT => begin
      if lhs
        2
      else
        3
      end
    end

    Op.DIV_SCALAR_ARRAY || Op.DIV_ARRAY_SCALAR => begin
      2
    end

    Op.POW_SCALAR_ARRAY || Op.POW_ARRAY_SCALAR || Op.POW_MATRIX => begin
      1
    end

    Op.AND => begin
      8
    end

    Op.OR => begin
      9
    end

    _ => begin
      0
    end
  end
end

function symbol(op::OPERATOR, spacing::String = " ")::String
  local symbol::String

  @assign symbol = begin
    @match op.op begin
      Op.ADD => begin
        "+"
      end

      Op.SUB => begin
        "-"
      end

      Op.MUL => begin
        "*"
      end

      Op.DIV => begin
        "/"
      end

      Op.POW => begin
        "^"
      end

      Op.ADD_EW => begin
        ".+"
      end

      Op.SUB_EW => begin
        ".-"
      end

      Op.MUL_EW => begin
        ".*"
      end

      Op.DIV_EW => begin
        "./"
      end

      Op.POW_EW => begin
        ".^"
      end

      Op.ADD_SCALAR_ARRAY => begin
        ".+"
      end

      Op.ADD_ARRAY_SCALAR => begin
        ".+"
      end

      Op.SUB_SCALAR_ARRAY => begin
        ".-"
      end

      Op.SUB_ARRAY_SCALAR => begin
        ".-"
      end

      Op.MUL_SCALAR_ARRAY => begin
        "*"
      end

      Op.MUL_ARRAY_SCALAR => begin
        ".*"
      end

      Op.MUL_VECTOR_MATRIX => begin
        "*"
      end

      Op.MUL_MATRIX_VECTOR => begin
        "*"
      end

      Op.SCALAR_PRODUCT => begin
        "*"
      end

      Op.MATRIX_PRODUCT => begin
        "*"
      end

      Op.DIV_SCALAR_ARRAY => begin
        "./"
      end

      Op.DIV_ARRAY_SCALAR => begin
        "/"
      end

      Op.POW_SCALAR_ARRAY => begin
        ".^"
      end

      Op.POW_ARRAY_SCALAR => begin
        ".^"
      end

      Op.POW_MATRIX => begin
        "^"
      end

      Op.UMINUS => begin
        "-"
      end

      Op.AND => begin
        "and"
      end

      Op.OR => begin
        "or"
      end

      Op.NOT => begin
        "not"
      end

      Op.LESS => begin
        "<"
      end

      Op.LESSEQ => begin
        "<="
      end

      Op.GREATER => begin
        ">"
      end

      Op.GREATEREQ => begin
        ">="
      end

      Op.EQUAL => begin
        "=="
      end

      Op.NEQUAL => begin
        "<>"
      end

      _ => begin
        #= case Op.USERDEFINED      then \"Userdefined:\" + AbsynUtil.pathString(op.fqName); =#
        Error.assertion(false, getInstanceName() + " got unknown type.", sourceInfo())
        fail()
      end
    end
  end
  @assign symbol = spacing + symbol + spacing
  return symbol
end

function unlift(op::OPERATOR)
  local ty = unliftArray(op.ty)
  return OPERATOR(ty, op.op)
end

function scalarize(op::OPERATOR)
  local ty = arrayElementType(op.ty)
  return OPERATOR(ty, op.op)
end

function setType(ty::ModelicaType, op::OPERATOR)
  return OPERATOR(ty, op.op)
end

function typeOf(op::OPERATOR)::ModelicaType
  local ty::ModelicaType = op.ty
  return ty
end

function fromAbsyn(inOperator::Absyn.Operator)::OPERATOR
  local outOperator::OPERATOR
  local op::OpType
  op = begin
    @match inOperator begin
      Absyn.ADD(__) => begin
        Op.ADD
      end

      Absyn.SUB(__) => begin
        Op.SUB
      end

      Absyn.MUL(__) => begin
        Op.MUL
      end

      Absyn.DIV(__) => begin
        Op.DIV
      end

      Absyn.POW(__) => begin
        Op.POW
      end

      Absyn.ADD_EW(__) => begin
        Op.ADD_EW
      end

      Absyn.SUB_EW(__) => begin
        Op.SUB_EW
      end

      Absyn.MUL_EW(__) => begin
        Op.MUL_EW
      end

      Absyn.DIV_EW(__) => begin
        Op.DIV_EW
      end

      Absyn.POW_EW(__) => begin
        Op.POW_EW
      end

      Absyn.UPLUS(__) => begin
        Op.ADD
      end

      Absyn.UPLUS_EW(__) => begin
        Op.ADD
      end

      Absyn.UMINUS(__) => begin
        Op.UMINUS
      end

      Absyn.UMINUS_EW(__) => begin
        Op.UMINUS
      end

      Absyn.AND(__) => begin
        Op.AND
      end

      Absyn.OR(__) => begin
        Op.OR
      end

      Absyn.NOT(__) => begin
        Op.NOT
      end

      Absyn.LESS(__) => begin
        Op.LESS
      end

      Absyn.LESSEQ(__) => begin
        Op.LESSEQ
      end

      Absyn.GREATER(__) => begin
        Op.GREATER
      end

      Absyn.GREATEREQ(__) => begin
        Op.GREATEREQ
      end

      Absyn.EQUAL(__) => begin
        Op.EQUAL
      end

      Absyn.NEQUAL(__) => begin
        Op.NEQUAL
      end
    end
  end
  outOperator = OPERATOR(TYPE_UNKNOWN(), op)
  return outOperator
end

function compare(op1::OPERATOR, op2::OPERATOR)::Int
  local comp::Int
  local o1::OpType = op1.op
  local o2::OpType = op2.op
  comp = Util.intCompare(Int(o1), Int(o2))
  return comp
end

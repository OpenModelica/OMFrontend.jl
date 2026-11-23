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
      Op.ADD => Op.SUB

      Op.SUB => Op.ADD

      Op.ADD_EW => Op.SUB_EW

      Op.SUB_EW => Op.ADD_EW

      Op.ADD_SCALAR_ARRAY => Op.SUB_SCALAR_ARRAY

      Op.SUB_SCALAR_ARRAY => Op.ADD_SCALAR_ARRAY

      Op.ADD_ARRAY_SCALAR => Op.SUB_ARRAY_SCALAR
    end
  end
  outOp = OPERATOR(op.ty, neg_op)
  return outOp
end

function isElementWise(op::OPERATOR)::Bool
  @match op.op begin
    Op.ADD_EW => true

    Op.SUB_EW => true

    Op.MUL_EW => true

    Op.DIV_EW => true

    Op.POW_EW => true

    _ => false
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
    Op.ADD_EW => Op.ADD

    Op.SUB_EW => Op.SUB

    Op.MUL_EW => Op.MUL

    Op.DIV_EW => Op.DIV

    Op.POW_EW => Op.POW
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
      Op.ADD => Op.ADD_ARRAY_SCALAR

      Op.SUB => Op.SUB_ARRAY_SCALAR

      Op.MUL => Op.MUL_ARRAY_SCALAR

      Op.DIV => Op.DIV_ARRAY_SCALAR

      Op.POW => Op.POW_ARRAY_SCALAR
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
      Op.ADD => Op.ADD_SCALAR_ARRAY

      Op.SUB => Op.SUB_SCALAR_ARRAY

      Op.MUL => Op.MUL_SCALAR_ARRAY

      Op.DIV => Op.DIV_SCALAR_ARRAY

      Op.POW => Op.POW_SCALAR_ARRAY
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
    Op.POW => true

    Op.POW_EW => true

    Op.POW_SCALAR_ARRAY => true

    Op.POW_ARRAY_SCALAR => true

    Op.POW_MATRIX => true

    _ => false
  end
end

function isAssociative(op::OPERATOR)::Bool
  local isAssoc::Bool

  isAssoc = begin
    @match op.op begin
      Op.ADD => true

      Op.ADD_EW => true

      Op.MUL_EW => true

      _ => false
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

    Op.SUB => 5

    Op.MUL => 2

    Op.DIV => 2

    Op.POW => 1

    Op.ADD_EW => begin
      if lhs
        5
      else
        6
      end
    end

    Op.SUB_EW => 5

    Op.MUL_EW => begin
      if lhs
        2
      else
        3
      end
    end

    Op.DIV_EW => 2

    Op.POW_EW => 1

    #= The array kinds as their scalar operator (omc's Operator.priority): with 0 the right operand of each got
       parentheses (`{1.0, 2.0} .* (time)`). =#
    Op.ADD_SCALAR_ARRAY || Op.ADD_ARRAY_SCALAR => begin
      if lhs
        5
      else
        6
      end
    end

    Op.SUB_SCALAR_ARRAY || Op.SUB_ARRAY_SCALAR => 5

    Op.MUL_SCALAR_ARRAY || Op.MUL_ARRAY_SCALAR || Op.MUL_VECTOR_MATRIX || Op.MUL_MATRIX_VECTOR ||
    Op.SCALAR_PRODUCT || Op.MATRIX_PRODUCT => begin
      if lhs
        2
      else
        3
      end
    end

    Op.DIV_SCALAR_ARRAY || Op.DIV_ARRAY_SCALAR => 2

    Op.POW_SCALAR_ARRAY || Op.POW_ARRAY_SCALAR || Op.POW_MATRIX => 1

    Op.AND => 8

    Op.OR => 9

    _ => 0
  end
end

function symbol(op::OPERATOR, spacing::String = " ")::String
  local symbol::String

  symbol = begin
    @match op.op begin
      Op.ADD => "+"

      Op.SUB => "-"

      Op.MUL => "*"

      Op.DIV => "/"

      Op.POW => "^"

      Op.ADD_EW => ".+"

      Op.SUB_EW => ".-"

      Op.MUL_EW => ".*"

      Op.DIV_EW => "./"

      Op.POW_EW => ".^"

      Op.ADD_SCALAR_ARRAY => ".+"

      Op.ADD_ARRAY_SCALAR => ".+"

      Op.SUB_SCALAR_ARRAY => ".-"

      Op.SUB_ARRAY_SCALAR => ".-"

      Op.MUL_SCALAR_ARRAY => "*"

      Op.MUL_ARRAY_SCALAR => ".*"

      Op.MUL_VECTOR_MATRIX => "*"

      Op.MUL_MATRIX_VECTOR => "*"

      Op.SCALAR_PRODUCT => "*"

      Op.MATRIX_PRODUCT => "*"

      Op.DIV_SCALAR_ARRAY => "./"

      Op.DIV_ARRAY_SCALAR => "/"

      Op.POW_SCALAR_ARRAY => ".^"

      Op.POW_ARRAY_SCALAR => ".^"

      Op.POW_MATRIX => "^"

      Op.UMINUS => "-"

      Op.AND => "and"

      Op.OR => "or"

      Op.NOT => "not"

      Op.LESS => "<"

      Op.LESSEQ => "<="

      Op.GREATER => ">"

      Op.GREATEREQ => ">="

      Op.EQUAL => "=="

      Op.NEQUAL => "<>"

      _ => begin
        #= case Op.USERDEFINED      then \"Userdefined:\" + AbsynUtil.pathString(op.fqName); =#
        Error.assertion(false, getInstanceName() + " got unknown type.", sourceInfo())
        fail()
      end
    end
  end
  symbol = spacing + symbol + spacing
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
      Absyn.ADD(__) => Op.ADD

      Absyn.SUB(__) => Op.SUB

      Absyn.MUL(__) => Op.MUL

      Absyn.DIV(__) => Op.DIV

      Absyn.POW(__) => Op.POW

      Absyn.ADD_EW(__) => Op.ADD_EW

      Absyn.SUB_EW(__) => Op.SUB_EW

      Absyn.MUL_EW(__) => Op.MUL_EW

      Absyn.DIV_EW(__) => Op.DIV_EW

      Absyn.POW_EW(__) => Op.POW_EW

      Absyn.UPLUS(__) => Op.ADD

      Absyn.UPLUS_EW(__) => Op.ADD

      Absyn.UMINUS(__) => Op.UMINUS

      Absyn.UMINUS_EW(__) => Op.UMINUS

      Absyn.AND(__) => Op.AND

      Absyn.OR(__) => Op.OR

      Absyn.NOT(__) => Op.NOT

      Absyn.LESS(__) => Op.LESS

      Absyn.LESSEQ(__) => Op.LESSEQ

      Absyn.GREATER(__) => Op.GREATER

      Absyn.GREATEREQ(__) => Op.GREATEREQ

      Absyn.EQUAL(__) => Op.EQUAL

      Absyn.NEQUAL(__) => Op.NEQUAL
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

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

@UniontypeDecl NFOperator

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

abstract type NFOperator end

struct OPERATOR{T <: Integer} <: NFOperator
  ty::M_Type
  op::T
end

function negate(op::Operator)::Operator
  local outOp::Operator
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

function isElementWise(op::Operator)::Bool
  local ew::Bool
  ew = begin
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
  return ew
end

function stripEW(op::Operator)
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

function makeArrayScalar(ty::M_Type, op::OpType)::Operator
  local outOp::Operator
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

function makeScalarArray(ty::M_Type, op::OpType)::Operator
  local outOp::Operator
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

function makeNotEqual(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.NEQUAL)
  return op
end

function makeEqual(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.EQUAL)
  return op
end

function makeGreaterEq(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.GREATEREQ)
  return op
end

function makeGreater(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.GREATER)
  return op
end

function makeLessEq(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.LESSEQ)
  return op
end

function makeLess(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.LESS)
  return op
end

function makeNot(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.NOT)
  return op
end

function makeOr(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.OR)
  return op
end

function makeAnd(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.AND)
  return op
end

function makeUMinus(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.UMINUS)
  return op
end

function makeDivEW(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.DIV_EW)
  return op
end

function makeMulEW(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.MUL_EW)
  return op
end

function makeSubEW(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.SUB_EW)
  return op
end

function makeAddEW(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.ADD_EW)
  return op
end

function makePow(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.POW)
  return op
end

function makeDiv(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.DIV)
  return op
end

function makeMul(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.MUL)
  return op
end

function makeSub(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.SUB)
  return op
end

function makeAdd(ty::M_Type)::Operator
  local op::Operator = OPERATOR(ty, Op.ADD)
  return op
end

function isNonAssociative(op::Operator)::Bool
  local isNonAssociative::Bool

  @assign isNonAssociative = begin
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
  return isNonAssociative
end

function isAssociative(op::Operator)::Bool
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
  #= case ADD_ARRAY_SCALAR() then true; =#
  #= case MUL_ARRAY_SCALAR() then true;
  =#
  return isAssoc
end

function priority(op::Operator, lhs::Bool)::Int
  local priority::Int

  @assign priority = begin
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
  return priority
end

function symbol(op::Operator, spacing::String = " ")::String
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
        #= case Op.USERDEFINED      then \"Userdefined:\" + AbsynUtil.pathString(op.fqName);
        =#
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
  return OPERATOR{Int}(ty, op.op)
end

function scalarize(op::OPERATOR)
  local ty = arrayElementType(op.ty)
  return OPERATOR{Int}(ty, op.op)
end

function setType(ty::M_Type, op::OPERATOR)
  return OPERATOR{Int}(ty, op.op)
end

function typeOf(op::Operator)::M_Type
  local ty::M_Type = op.ty
  return ty
end

function toDAE(op::Operator)::DAE.Operator #Tuple{DAE.Operator, Bool}
  local swapArguments::Bool = false #= The DAE structure only has array*scalar, not scalar*array, etc =#
  local daeOp::DAE.Operator
  local ty::DAE.Type
  @assign ty = toDAE(op.ty)
  @assign daeOp = begin
    @match op.op begin
      Op.ADD => begin
        if isArray(op.ty)
          DAE.ADD_ARR(ty)
        else
          DAE.ADD(ty)
        end
      end

      Op.SUB => begin
        if isArray(op.ty)
          DAE.SUB_ARR(ty)
        else
          DAE.SUB(ty)
        end
      end

      Op.MUL => begin
        if isArray(op.ty)
          DAE.MUL_ARR(ty)
        else
          DAE.MUL(ty)
        end
      end

      Op.DIV => begin
        if isArray(op.ty)
          DAE.DIV_ARR(ty)
        else
          DAE.DIV(ty)
        end
      end

      Op.POW => begin
        if isArray(op.ty)
          DAE.POW_ARR2(ty)
        else
          DAE.POW(ty)
        end
      end

      Op.ADD_SCALAR_ARRAY => begin
        @assign swapArguments = true
        DAE.ADD_ARRAY_SCALAR(ty)
      end

      Op.ADD_ARRAY_SCALAR => begin
        DAE.ADD_ARRAY_SCALAR(ty)
      end

      Op.SUB_SCALAR_ARRAY => begin
        DAE.SUB_SCALAR_ARRAY(ty)
      end

      Op.SUB_ARRAY_SCALAR => begin
        Error.addInternalError(
          getInstanceName() + ": Don't know how to handle " + String(op.op),
          sourceInfo(),
        )
        DAE.SUB(ty)
      end

      Op.MUL_SCALAR_ARRAY => begin
        @assign swapArguments = true
        DAE.MUL_ARRAY_SCALAR(ty)
      end

      Op.MUL_ARRAY_SCALAR => begin
        DAE.MUL_ARRAY_SCALAR(ty)
      end

      Op.MUL_VECTOR_MATRIX => begin
        DAE.MUL_MATRIX_PRODUCT(ty)
      end

      Op.MUL_MATRIX_VECTOR => begin
        DAE.MUL_MATRIX_PRODUCT(ty)
      end

      Op.SCALAR_PRODUCT => begin
        DAE.MUL_SCALAR_PRODUCT(ty)
      end

      Op.MATRIX_PRODUCT => begin
        DAE.MUL_MATRIX_PRODUCT(ty)
      end

      Op.DIV_SCALAR_ARRAY => begin
        DAE.DIV_SCALAR_ARRAY(ty)
      end

      Op.DIV_ARRAY_SCALAR => begin
        DAE.DIV_ARRAY_SCALAR(ty)
      end

      Op.POW_SCALAR_ARRAY => begin
        DAE.POW_SCALAR_ARRAY(ty)
      end

      Op.POW_ARRAY_SCALAR => begin
        DAE.POW_ARRAY_SCALAR(ty)
      end

      Op.POW_MATRIX => begin
        DAE.POW_ARR(ty)
      end

      Op.UMINUS => begin
        if isArray(op.ty)
          DAE.UMINUS_ARR(ty)
        else
          DAE.UMINUS(ty)
        end
      end

      Op.AND => begin
        DAE.AND(ty)
      end

      Op.OR => begin
        DAE.OR(ty)
      end

      Op.NOT => begin
        DAE.NOT(ty)
      end

      Op.LESS => begin
        DAE.LESS(ty)
      end

      Op.LESSEQ => begin
        DAE.LESSEQ(ty)
      end

      Op.GREATER => begin
        DAE.GREATER(ty)
      end

      Op.GREATEREQ => begin
        DAE.GREATEREQ(ty)
      end

      Op.EQUAL => begin
        DAE.EQUAL(ty)
      end

      Op.NEQUAL => begin
        DAE.NEQUAL(ty)
      end

      _ => begin
        Error.assertion(false, getInstanceName() + " got unknown type.", sourceInfo())
        fail()
      end
    end
  end
  return daeOp #, swapArguments) #= The DAE structure only has array*scalar, not scalar*array, etc =#
end

function fromAbsyn(inOperator::Absyn.Operator)::Operator
  local outOperator::Operator
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

function compare(op1::Operator, op2::Operator)::Int
  local comp::Int
  local o1::OpType = op1.op
  local o2::OpType = op2.op
  comp = Util.intCompare(Int(o1), Int(o2))
  return comp
end

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
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll

function expandGeneric2(
  subs::List{<:List{<:Subscript}},
  exp::Expression,
  ty::ModelicaType,
  accum::List{<:Subscript} = nil,
)::Expression
  local outExp::Expression
  local t::ModelicaType
  local sub::List{Subscript}
  local expl::Vector{Expression}
  local rest_subs::List{List{Subscript}}
  outExp = begin
    @match subs begin
      sub <| rest_subs => begin
        t = unliftArray(ty)
        expl =
          Expression[expandGeneric2(rest_subs, exp, t, _cons(s, accum)) for s in sub]
        makeArray(ty, expl)
      end
      nil() => begin
        outExp = exp
        for s in listReverse(accum)
          outExp = applySubscript(s, outExp)
        end
        outExp
      end
    end
  end
  return outExp
end

function expandGeneric(@nospecialize(exp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression
  local ty::ModelicaType
  local dims::List{Dimension}
  local subs::List{List{Subscript}}
  ty = typeOf(exp)
  if isArray(ty)
    expanded = hasKnownSize(ty)
    if expanded
      dims = arrayDims(ty)
      subs = list(
        list(
          SUBSCRIPT_INDEX(e)
          for
          e in
            toList(fromDim(d))
        ) for d in dims
      )
      outExp = expandGeneric2(subs, exp, ty)
    else
      outExp = exp
    end
  else
    outExp = exp
    expanded = true
  end
  return (outExp, expanded)
end

#= Not expanded: the whole cast (as omc's expandCast); it was the operand alone. =#
function expandCast(exp::CAST_EXPRESSION)::Tuple{Expression, Bool}
  local (operand, expanded) = expand(exp.exp)
  if expanded && !referenceEq(exp.exp, operand)
    return (typeCast(operand, exp.ty), true)
  end
  return (exp, expanded)
end

function makeLogicalUnaryOp(@nospecialize(exp1::Expression), op::OPERATOR)::Expression
  local exp::Expression = LUNARY_EXPRESSION(op, exp1)
  return exp
end

#= Not expanded (an operand of unknown size, in a function): the whole
   expression, operator included (as omc's expandLogicalUnary). =#
function expandLogicalUnary(exp::LUNARY_EXPRESSION)::Tuple{Expression, Bool}
  local (operand::Expression, expanded::Bool) = expand(exp.exp)
  if expanded
    local scalar_op::OPERATOR = scalarize(exp.operator)
    return (mapArrayElements(operand, (@nospecialize(e::Expression),) -> makeLogicalUnaryOp(e, scalar_op)), true)
  end
  return (exp, false)
end

function makeLBinaryOp(@nospecialize(exp1::Expression), op::OPERATOR, @nospecialize(exp2::Expression))::Expression
  local exp::Expression

  if isScalarLiteral(exp1) &&
     isScalarLiteral(exp2)
    @assign exp = evalLogicBinaryOp(exp1, op, exp2)
  else
    @assign exp = LBINARY_EXPRESSION(exp1, op, exp2)
  end
  return exp
end

function expandLogicalBinary(@nospecialize(exp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression

  local exp1::Expression
  local exp2::Expression
  local op::OPERATOR

  @match LBINARY_EXPRESSION(exp1 = exp1, operator = op, exp2 = exp2) = exp
  if isArray(typeOf(op))
     (exp1, expanded) = expand(exp1)
    if expanded
       (exp2, expanded) = expand(exp2)
    end
    if expanded
      @assign outExp = expandBinaryElementWise2(exp1, op, exp2, makeLBinaryOp)
    else
      @assign outExp = exp
    end
  else
    @assign outExp = exp
    @assign expanded = true
  end
  return (outExp, expanded)
end

#= Not expanded (an operand of unknown size, in a function): the whole
   expression, operator included (as omc's expandUnary). It was the operand
   alone, so -x of such an array lost its sign: Buildings' finiteLineSource
   integrand, exp(-dis.*dis*u^2), grew instead of decaying. =#
function expandUnary(exp::UNARY_EXPRESSION)::Tuple{Expression, Bool}
  local (operand::Expression, expanded::Bool) = expand(exp.exp)
  if expanded
    local scalar_op::OPERATOR = scalarize(exp.operator)
    return (mapArrayElements(operand, (@nospecialize(expArg::Expression),) -> simplifyUnaryOp(expArg, scalar_op)), true)
  end
  return (exp, false)
end

function expandBinaryPowMatrix2(@nospecialize(matrix::Expression), n::Int)::Expression
  local exp::Expression
  @assign exp = begin
    @match n begin
      1 => begin
        matrix
      end
      2 => begin
        makeBinaryMatrixProduct(matrix, matrix)
      end
      _ where {(intMod(n, 2) == 0)} => begin
        #= A^1 = A
           A^2 = A * A
           A^n = A^m * A^m where n = 2*m =#
        @assign exp = expandBinaryPowMatrix2(matrix, intDiv(n, 2))
        makeBinaryMatrixProduct(exp, exp)
      end

      _ => begin
        #= A^n = A * A^(n-1) =#
        @assign exp = expandBinaryPowMatrix2(matrix, n - 1)
        makeBinaryMatrixProduct(matrix, exp)
      end
    end
  end
  return exp
end

function expandBinaryPowMatrix(@nospecialize(exp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression

  local exp1::Expression
  local exp2::Expression
  local op::OPERATOR
  local n::Int

  @match BINARY_EXPRESSION(exp1 = exp1, operator = op, exp2 = exp2) = exp
   (outExp, expanded) = begin
    @match exp2 begin
      INTEGER_EXPRESSION(0) => begin
        #= a ^ 0 = identity(size(a, 1)) =#
        @assign n =
          size(listHead(arrayDims(typeOf(
            op,
          ))))
        (makeIdentityMatrix(n, TYPE_REAL()), true)
      end

      INTEGER_EXPRESSION(n) => begin
        #= a ^ n where n is a literal value. =#
         (exp1, expanded) = expand(exp1)
        if expanded
          @assign outExp = expandBinaryPowMatrix2(exp1, n)
        end
        (outExp, expanded)
      end

      _ => begin
        expandGeneric(exp)
      end
    end
  end
  #= a ^ n where n is unknown, subscript the whole expression. =#
  return (outExp, expanded)
end

function makeBinaryMatrixProduct2(
  row::Expression,
  matrix::Vector{Expression},
)::Vector{Expression}
  local outRow::Vector{Expression}
  outRow = Expression[makeScalarProduct(row, e) for e in matrix]
  return outRow
end

function makeBinaryMatrixProduct(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  local exp::Expression

  local expl1::Vector{Expression}
  local expl2::Vector{Expression}
  local ty::ModelicaType
  local row_ty::ModelicaType
  local mat_ty::ModelicaType
  local n::Dimension
  local p::Dimension

  @match ARRAY_EXPRESSION(TYPE_ARRAY(ty, n <| _), expl1) = exp1
  #= Transpose the second matrix. This makes it easier to do the multiplication,
     since we can do row-row multiplications instead of row-column. =#
  @match ARRAY_EXPRESSION(TYPE_ARRAY(dimensions = p <| _), expl2) =
    transposeArray(exp2)
  @assign mat_ty = TYPE_ARRAY(ty, list(n, p))
  if isempty(expl2)
    exp = makeZero(mat_ty)
  else
    row_ty = TYPE_ARRAY(ty, list(p))
    expl1 = Expression[
      makeArray(row_ty, makeBinaryMatrixProduct2(e, expl2))
      for e in expl1
    ]
    exp = makeArray(mat_ty, expl1)
  end
  #= If any of the matrices' dimensions are zero, the result will be a matrix
     of zeroes (the default value of sum). Only expl2 needs to be checked here,
     the normal case can handle expl1 being empty.
     c[i, j] = a[i, :] * b[:, j] for i in 1:n, j in 1:p. =#
  return exp
end

"""  Expands a matrix*matrix expression, c[n, p] = a[n, m] * b[m, p]. """
function expandBinaryMatrixProduct(@nospecialize(exp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression

  local exp1::Expression
  local exp2::Expression

  @match BINARY_EXPRESSION(exp1 = exp1, exp2 = exp2) = exp
   (exp1, expanded) = expand(exp1)
  if expanded
     (exp2, expanded) = expand(exp2)
  end
  if expanded
    @assign outExp = makeBinaryMatrixProduct(exp1, exp2)
  else
    @assign outExp = exp
  end
  return (outExp, expanded)
end

function makeScalarProduct(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression))::Expression
  local ty::ModelicaType
  local expV1::Vector{Expression}
  local expV2::Vector{Expression}
  @match ARRAY_EXPRESSION(ty, expV1) = exp1
  @match ARRAY_EXPRESSION(_, expV2) = exp2
  local elem_ty::ModelicaType = unliftArray(ty)
  # The scalar product of two empty arrays is defined by sum, whose default is 0.
  isempty(expV1) && return makeZero(elem_ty)
  local mul_op::OPERATOR = makeMul(elem_ty)
  local add_op::OPERATOR = makeAdd(elem_ty)
  # A typed loop: a generator over the abstract elements compiled per element type (the sum folds from the left).
  local exp::Expression = simplifyBinaryOp(expV1[1], mul_op, expV2[1])
  for i in 2:length(expV1)
    exp = simplifyBinaryOp(exp, add_op, simplifyBinaryOp(expV1[i], mul_op, expV2[i]))
  end
  return exp
end

"""Expands a vector*vector expression, c = a[n] * b[n]."""
function expandBinaryDotProduct(@nospecialize(exp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression

  local exp1::Expression
  local exp2::Expression

  @match BINARY_EXPRESSION(exp1 = exp1, exp2 = exp2) = exp
   (exp1, expanded) = expand(exp1)
  if expanded
     (exp2, expanded) = expand(exp2)
  end
  if expanded
    @assign outExp = makeScalarProduct(exp1, exp2)
  else
    @assign outExp = exp
  end
  return (outExp, expanded)
end

""" Expands a matrix*vector expression, c[n] = a[n, m] * b[m]. """
function expandBinaryMatrixVector(@nospecialize(exp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression

  local exp1::Expression
  local exp2::Expression

  local expL::List{Expression}
  local expV::Vector{Expression}

  local ty::ModelicaType
  local n::Dimension

  @match BINARY_EXPRESSION(exp1 = exp1, exp2 = exp2) = exp
  (exp1, expanded) = expand(exp1)
  if expanded
    @match ARRAY_EXPRESSION(TYPE_ARRAY(ty, _cons(n, T)), expV) = exp1
    ty = TYPE_ARRAY(ty, list(n))
    expL = arrayList(expV)
    if listEmpty(expL)
      outExp = makeZero(ty)
    else
      (exp2, expanded) = expand(exp2)
      if expanded
        #=  c[i] = a[i, :] * b for i in 1:n =#
        expV = Expression[makeScalarProduct(e1, exp2) for e1 in expL]
        outExp = makeArray(ty, expV)
      else
        outExp = exp
      end
    end
  else
    outExp = exp
  end
  return (outExp, expanded)
end

"""Expands a vector*matrix expression, c[m] = a[n] * b[n, m]."""
function expandBinaryVectorMatrix(@nospecialize(exp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression

  local exp1::Expression
  local exp2::Expression
  local expl::Vector{Expression}
  local ty::ModelicaType
  local m::Dimension

  @match BINARY_EXPRESSION(exp1 = exp1, exp2 = exp2) = exp
   (exp2, expanded) = expand(exp2)
  if expanded
    @match ARRAY_EXPRESSION(TYPE_ARRAY(ty, _cons(m, _)), expl) =
      transposeArray(exp2)
    @assign ty = TYPE_ARRAY(ty, list(m))
    if isempty(expl)
      @assign outExp = makeZero(ty)
    else
       (exp1, expanded) = expand(exp1)
      if expanded
        expl = Expression[makeScalarProduct(exp1, e2) for e2 in expl]
        outExp = makeArray(ty, expl)
      else
        @assign outExp = exp
      end
    end
  else
    @assign outExp = exp
  end
  #= c[i] = a * b[:, i] for i in 1:m =#
  return (outExp, expanded)
end

function expandBinaryArrayScalar(
  @nospecialize(exp::Expression),
  scalarOp::OpType,
)::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression
  local exp1::Expression
  local exp2::Expression
  local op::OPERATOR
  @match BINARY_EXPRESSION(exp1 = exp1, operator = op, exp2 = exp2) = exp
  (exp1, expanded) = expand(exp1)
  if expanded
    local eop::OPERATOR = OPERATOR(arrayElementType(typeOf(op)), scalarOp)
    local rhs::Base.RefValue{Expression} = captureRef(exp2)
    outExp = mapArrayElements(exp1, (@nospecialize(expArg::Expression),) -> simplifyBinaryOp(expArg, eop, rhs[]))
  else
    outExp = exp
  end
  return (outExp, expanded)
end

function expandBinaryScalarArray(
  @nospecialize(exp::Expression),
  scalarOp::OpType,
)::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression
  local exp1::Expression
  local exp2::Expression
  local op::OPERATOR
  @match BINARY_EXPRESSION(exp1 = exp1, operator = op, exp2 = exp2) = exp
  (exp2, expanded) = expand(exp2)
  if expanded
    local eop::OPERATOR = OPERATOR(arrayElementType(typeOf(op)), scalarOp)
    local lhs::Base.RefValue{Expression} = captureRef(exp1)
    outExp = mapArrayElements(exp2, (@nospecialize(arg::Expression),) -> simplifyBinaryOp(lhs[], eop, arg))
  else
    outExp = exp
  end
  return (outExp, expanded)
end

function expandBinaryElementWise2(
  @nospecialize(exp1::Expression),
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  func::FT,
)::Expression where {FT<:Function}
  local elems1::Vector{Expression} = (exp1::ARRAY_EXPRESSION).elements
  local elems2::Vector{Expression} = (exp2::ARRAY_EXPRESSION).elements
  local ty::ModelicaType = typeOf(op)
  local eop::OPERATOR = setType(unliftArray(ty), op)
  local nested::Bool = dimensionCount(ty) > 1
  # A typed loop: a generator over the abstract elements compiled per element type.
  local elems::Vector{Expression} = Vector{Expression}(undef, min(length(elems1), length(elems2)))
  for i in eachindex(elems)
    elems[i] = nested ? expandBinaryElementWise2(elems1[i], eop, elems2[i], func) : func(elems1[i], eop, elems2[i])
  end
  return makeArray(ty, elems)
end

function expandBinaryElementWise(@nospecialize(exp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression
  local exp1::Expression
  local exp2::Expression
  local op::OPERATOR
  @match BINARY_EXPRESSION(exp1 = exp1, operator = op, exp2 = exp2) = exp
  if isArray(typeOf(op))
     (exp1, expanded) = expand(exp1)
    if expanded
       (exp2, expanded) = expand(exp2)
    end
    if expanded
      # The elements get the scalar operator (`.*` of two arrays is `*` of their elements).
      outExp = expandBinaryElementWise2(exp1, stripEW(op), exp2, simplifyBinaryOp)
    else
      outExp = exp
    end
  else
    outExp = exp
    expanded = true
  end
  return (outExp, expanded)
end

function expandBinary(@nospecialize(exp::Expression), op::OPERATOR)::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression

   (outExp, expanded) = begin
    @match op.op begin
      Op.ADD_SCALAR_ARRAY => begin
        expandBinaryScalarArray(exp, Op.ADD)
      end

      Op.ADD_ARRAY_SCALAR => begin
        expandBinaryArrayScalar(exp, Op.ADD)
      end

      Op.SUB_SCALAR_ARRAY => begin
        expandBinaryScalarArray(exp, Op.SUB)
      end

      Op.SUB_ARRAY_SCALAR => begin
        expandBinaryArrayScalar(exp, Op.SUB)
      end

      Op.MUL_SCALAR_ARRAY => begin
        expandBinaryScalarArray(exp, Op.MUL)
      end

      Op.MUL_ARRAY_SCALAR => begin
        expandBinaryArrayScalar(exp, Op.MUL)
      end

      Op.MUL_VECTOR_MATRIX => begin
        expandBinaryVectorMatrix(exp)
      end

      Op.MUL_MATRIX_VECTOR => begin
        expandBinaryMatrixVector(exp)
      end

      Op.SCALAR_PRODUCT => begin
        expandBinaryDotProduct(exp)
      end

      Op.MATRIX_PRODUCT => begin
        expandBinaryMatrixProduct(exp)
      end

      Op.DIV_SCALAR_ARRAY => begin
        expandBinaryScalarArray(exp, Op.DIV)
      end

      Op.DIV_ARRAY_SCALAR => begin
        expandBinaryArrayScalar(exp, Op.DIV)
      end

      Op.POW_SCALAR_ARRAY => begin
        expandBinaryScalarArray(exp, Op.POW)
      end

      Op.POW_ARRAY_SCALAR => begin
        expandBinaryArrayScalar(exp, Op.POW)
      end

      Op.POW_MATRIX => begin
        expandBinaryPowMatrix(exp)
      end

      _ => begin
        expandBinaryElementWise(exp)
      end
    end
  end
  if !expanded
    @assign outExp = exp
  end
  return (outExp, expanded)
end

function expandSize(@nospecialize(exp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool = true
  local outExp::Expression

  @assign outExp = begin
    local dims::Int
    local e::Expression
    local ty::ModelicaType
    @match exp begin
      SIZE_EXPRESSION(exp = e, dimIndex = NONE()) => begin
        @assign ty = typeOf(e)
        @assign dims = dimensionCount(ty)
        local expl_vec = Expression[
          SIZE_EXPRESSION(e, SOME(INTEGER_EXPRESSION(i)))
          for i = 1:dims
        ]
        makeArray(
          TYPE_ARRAY(ty, list(fromInteger(dims))),
          expl_vec,
        )
      end

      _ => begin
        exp
      end
    end
  end
  #= Size with an index is scalar, and thus already maximally expanded. =#
  return (outExp, expanded)
end

function expandArrayConstructor2(
  exp::Expression,
  ty::ModelicaType,
  ranges::List{<:Expression},
  iterators::List{<:Pointer{<:Expression}},
)::Expression
  # One instance: the recursion passes Cons or Nil{Any}, and each element type of `exp` compiled 2-10 ms.
  @nospecialize exp ty ranges iterators
  local result::Expression
  local range::Expression
  local ranges_rest::List{Expression}
  local expl::Vector{Expression} = Expression[]
  local iter::Pointer{Expression}
  local iters_rest::List{Pointer{Expression}}
  local range_iter::ExpressionIterator
  local value::Expression
  local el_ty::ModelicaType
  if listEmpty(ranges)
    (result,_) = expand(simplify(exp))
  else
    @match Cons{Expression}(range, ranges_rest) = ranges
    @match Cons{Pointer{Expression}}(iter, iters_rest) = iterators
    range_iter = fromExpToExpressionIterator(range)
    el_ty = unliftArray(ty)
    while hasNext(range_iter)
      (range_iter, value) = next(range_iter)
      P_Pointer.update(iter, value)
      push!(expl, expandArrayConstructor2(exp, el_ty, ranges_rest, iters_rest))
    end
    result = makeArray(ty, expl)
  end
  #= Normally it wouldn't be the expansion's task to simplify expressions,
     but we make an exception here since the generated expressions contain
     MUTABLE expressions that we need to get rid of. Also, expansion of
     array constructors is often done during the scalarization phase, after
     the simplification phase, so they wouldn't otherwise be simplified. =#
  return result
end

"""
An array constructor expanded into its elements: `(array, true)`; `(exp, false)` when a range does
not expand (the caller expands the call generically).
"""
function expandArrayConstructor(
  exp::Expression,
  ty::ModelicaType,
  iterators::List{<:Tuple{<:InstNode, Expression}},
)::Tuple{Expression, Bool}
  @nospecialize exp ty
  local e::Expression = exp
  local ranges::List{Expression} = nil
  local iters::List{Pointer{Expression}} = nil
  for (node::InstNode, range::Expression) in iterators
    local iter::Pointer{Expression} = P_Pointer.create(INTEGER_EXPRESSION(0))
    e = replaceIterator(e, node, MUTABLE_EXPRESSION(iter))
    iters = Cons{Pointer{Expression}}(iter, iters)
    local (range_exp::Expression, range_expanded::Bool) = expand(range)
    range_expanded || return (exp, false)
    ranges = Cons{Expression}(range_exp, ranges)
  end
  return (expandArrayConstructor2(e, ty, ranges, iters), true)
end

function expandBuiltinGeneric2(
  exp::Expression,
  fn::MODELICA_FUNCTION,
  ty::ModelicaType,
  var::VariabilityType,
  attr::CALL_ATTR
)::Expression

  @assign exp = begin
    local expl::Vector{Expression}
    @match exp begin
      ARRAY_EXPRESSION(literal = true) => begin
        exp
      end

      ARRAY_EXPRESSION(__) => begin
        expl = Expression[expandBuiltinGeneric2(e, fn, ty, var, attr) for e in exp.elements]
        makeArray(setArrayElementType(exp.ty, ty), expl)
      end

      _ => begin
        CALL_EXPRESSION(TYPED_CALL(fn, ty, var, list(exp), attr))
      end
    end
  end
  return exp
end

function expandBuiltinGeneric(call::Call)::Tuple{Expression, Bool}
  local expanded::Bool = true
  local outExp::Expression
  local fn::MODELICA_FUNCTION
  local ty::ModelicaType
  local var::VariabilityType
  local attr::CALL_ATTR
  local arg::Expression
  #= The arguments are a Vector (the Cons pattern never matched: der(x), pre(x) of an array
     fell back to a subscripted call). =#
  @match TYPED_CALL(fn, ty, var, _, attr) = call
  arg = call.arguments[1]
  ty = arrayElementType(ty)
  @match (arg, true) = expand(arg)
  outExp = expandBuiltinGeneric2(arg, fn, ty, var, attr)
  return (outExp, expanded)
end

function expandBuiltinTranspose(@nospecialize(arg::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression

   (outExp, expanded) = expand(arg)
  if expanded
    @assign outExp = transposeArray(outExp)
  end
  return (outExp, expanded)
end

@nospecializeinfer function expandBuiltinDiagonal(@nospecialize(arg::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression
   (outExp, expanded) = expand(arg)
  if expanded
    outExp = evalBuiltinDiagonal(outExp)
  end
  return (outExp, expanded)
end

function expandBuiltinPromote(args::Vector{Expression})::Tuple{Expression, Bool}
  #= args[2] is an Integer literal (the caller checks). =#
  local (eexp::Expression, expanded::Bool) = expand(args[1])
  return (Base.first(promote(eexp, typeOf(eexp), (args[2]::INTEGER_EXPRESSION).value)), expanded)
end

function expandBuiltinCat(args::Vector{Expression}, call::Call)::Tuple{Expression, Bool}
  #= This relies on the fact that Ceval.evalBuiltinCat doesn't actually do any
     actual constant evaluation, and works on non-constant arrays too as long
     as they're expanded. =#
  local expanded::Bool
  local exp::Expression
  local expV
  (expV, expanded) = expandVector(args[2:end]) #TODO: See if view can be used here
  if expanded
    exp = evalBuiltinCat(Base.first(args), expV, EVALTARGET_IGNORE_ERRORS())
  else
    (exp, _) = expandGeneric(CALL_EXPRESSION(call))
  end
  return (exp, expanded)
end

"""
A builtin call expanded (`callExp` is the call `call` as an expression): the array builtins by
their own rules, any other builtin by `expandGeneric`.
"""
function expand(
  fn::MODELICA_FUNCTION,
  args::Vector{Expression},
  call::Call,
  @nospecialize(callExp::Expression),
  )::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression
  local fn_path::Absyn.Path = nameConsiderBuiltin(fn)
  (outExp, expanded) = begin
    @match AbsynUtil.pathFirstIdent(fn_path) begin
      "cat" => begin
        expandBuiltinCat(args, call)
      end

      "der" => begin
        expandBuiltinGeneric(call)
      end

      "diagonal" => begin
        expandBuiltinDiagonal(args[1])
      end

      "pre" => begin
        expandBuiltinGeneric(call)
      end

      #= fill/identity/zeros/ones with sizes that are not literals (a function's local:
         MSL Polynomials.roots' [identity(n - 1), zeros(n - 1)]) stay calls, as omc's expandGeneric =#
      "fill" => begin
        all(isLiteral, args[2:end]) ? expandBuiltinFill(args) : (CALL_EXPRESSION(call), false)
      end

      "previous" => begin
        expandBuiltinGeneric(call)
      end

      "promote" => begin
        args[2] isa INTEGER_EXPRESSION ? expandBuiltinPromote(args) : expandGeneric(callExp)
      end

      "transpose" => begin
        expandBuiltinTranspose(args[1])
      end

      "identity" => begin
        all(isLiteral, args) ? expandBuiltinIdentity(args) : (CALL_EXPRESSION(call), false)
      end

      "zeros" => begin
        all(isLiteral, args) ? expandBuiltinZeros(args) : (CALL_EXPRESSION(call), false)
      end

      "ones" => begin
        all(isLiteral, args) ? expandBuiltinOnes(args) : (CALL_EXPRESSION(call), false)
      end

      _ => expandGeneric(callExp)
    end
  end
  #= A Ceval builtin (cat, diagonal, fill, ...) that cannot evaluate its arguments: the call stays. =#
  isEvalFailure(outExp) && return (CALL_EXPRESSION(call), false)
  return (outExp, expanded)
end

@nospecializeinfer function expandCall(call::Call, @nospecialize(exp::Expression))::Tuple{Expression, Bool}
  isvariant(call, TYPED_CALL) && isBuiltin(call.fn) && isNotImpure(call.fn) &&
    return expand(call.fn, call.arguments, call, exp)
  if isvariant(call, TYPED_ARRAY_CONSTRUCTOR)
    local (arr::Expression, arr_expanded::Bool) = expandArrayConstructor(call.exp, call.ty, call.iters)
    arr_expanded && return (arr, true)
  end
  return expandGeneric(exp)
end

@nospecializeinfer function expandRange(@nospecialize(exp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local outExp::Expression
  local ty::ModelicaType
  @match RANGE_EXPRESSION(ty = ty) = exp
  expanded = hasKnownSize(ty)
  if expanded
    outExp = evalExp(exp)
  else
    outExp = exp
  end
  return (outExp, expanded)
end

function expandTypename(ty::ModelicaType)::Expression

  local lits::List{Expression}
  @match ty begin
    TYPE_ARRAY(elementType = TYPE_BOOLEAN(__)) => begin
      makeArray(
        ty,
        Expression[
          BOOLEAN_EXPRESSION(false),
          BOOLEAN_EXPRESSION(true),
        ],
        true,
      )
    end

    TYPE_ARRAY(elementType = TYPE_ENUMERATION(__)) => begin
      @assign lits = makeEnumLiterals(ty.elementType)
      makeArray(ty, lits; literal=true)
    end

    _ => begin
      Error.addInternalError(getInstanceName() + " got invalid typename", sourceInfo())
      fail()
    end
  end
end

function expandCref4(
  subs,#::List{Subscript},
  comb,#::List{Subscript}, #== nil,=#
  accum,#::List{List{Subscript}}, #= = nil, =#
  restSubs,#::List{List{Subscript}},
  cref::ComponentRef,
  crefType::ModelicaType,
)::Expression
  local arrayExp::Expression

  local expl::Vector{Expression}
  local arr_ty::ModelicaType
  local slice::List{Subscript}
  local rest::List{Subscript}
  arrayExp = begin
    @match subs begin
      nil() => begin
        expandCref3(restSubs, cref, crefType,
                    Cons{List{Subscript}}(listReverseInPlace(comb), accum))
      end

      SUBSCRIPT_EXPANDED_SLICE(indices = slice) <| rest => begin
        expl = Expression[
          expandCref4(rest, Cons{Subscript}(idx, comb), accum, restSubs, cref, crefType)
          for idx in slice
        ]
        if isempty(expl)
          makeEmptyArray(liftArrayLeft(crefType, DIMENSION_INTEGER(0, Variability.CONSTANT)))
        else
          arr_ty = liftArrayLeft(
            typeOf(Base.first(expl)),
            fromExpList(expl),
          )
          makeArray(arr_ty, expl)
        end
      end
      _ => begin
        expandCref4(
          listRest(subs),
          Cons{Subscript}(listHead(subs), comb),
          accum,
          restSubs,
          cref,
          crefType,
        )
      end
    end
  end
  return arrayExp
end

function expandCref3(
  subs::List{List{Subscript}},
  cref::ComponentRef,
  crefType::ModelicaType,
  accum = nil,
)::Expression
  @match subs begin
    nil() => begin
      if isempty(accum)
        CREF_EXPRESSION(crefType, cref)
      else
        local arrSubs = Vector{Subscript}[listArray(e) for e in accum]
        local crefR = setSubscriptsListV(arrSubs, cref)
        #@info "Done..."
        CREF_EXPRESSION(
          crefType,
          crefR,
        )
      end
    end
    _ => begin
      expandCref4(listHead(subs),
                  nil,
                  accum,
                  listRest(subs),
                  cref,
                  crefType)
    end
  end
end

function expandCref2(
  cref::ComponentRef,
  subs::List = nil, #
  )::List{List{Subscript}}
  local cr_subs::List{Subscript}
  local dims::List{Dimension}
  subs = begin
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF) => begin
        dims = arrayDims(cref.ty)
        cr_subs = expandList(cref.subscripts, dims)
        if listEmpty(cr_subs) && !listEmpty(dims)
          nil
        else
          expandCref2(cref.restCref, Cons{List{Subscript}}(cr_subs, subs))
        end
      end
      _ => begin
        subs
      end
    end
  end
  return subs
end

"""
Expands a component reference
"""
@nospecializeinfer function expandCref(@nospecialize(crefExp::Expression))::Tuple{Expression, Bool}
  local expanded::Bool
  local arrayExp::Expression
  (arrayExp, expanded) = begin
    @match crefExp begin
      CREF_EXPRESSION(cref = COMPONENT_REF_CREF(__)) => begin
        if hasZeroDimension(crefExp.ty)
          arrayExp = makeEmptyArray(crefExp.ty)
          expanded = true
        elseif hasKnownSize(crefExp.ty)
          return(expandCref3(expandCref2(crefExp.cref),
                             crefExp.cref,
                             arrayElementType(crefExp.ty)),
                 true)
        elseif isArray(crefExp.cref.ty) && hasKnownSize(crefExp.cref.ty)
          #= The outer CREF_EXPRESSION type may have unresolved DIMENSION_EXP
             (e.g. "pipe2.n - 1") while the inner cref type has the resolved
             DIMENSION_INTEGER. Try expansion using the cref's own type. =#
          return(expandCref3(expandCref2(crefExp.cref),
                             crefExp.cref,
                             arrayElementType(crefExp.cref.ty)),
                 true)
        else

          return (crefExp, false)
        end
        (arrayExp, expanded)
      end
      _ => begin
        return (crefExp, false)
      end
    end
  end
  return (arrayExp, expanded)
end

"""
Expands a list of Expressions. If abortOnFailure is true the function will
stop if it fails to expand an element and the original list will be
returned unchanged. If abortOnFailure is false it will instead continue and
try to expand the whole list. In both cases the output 'expanded' indicates
whether the whole list could be expanded or not.
"""
function expandList(
  expl::List{Expression},
  abortOnFailure::Bool = true,
  )::Tuple{List{Expression}, Bool}
  local expanded::Bool = true
  local outExpl::List{Expression} = nil
  local res::Bool
  for exp in expl
    (exp, res) = expand(exp)
    expanded = res && expanded
    if !res && abortOnFailure
      outExpl = expl
      return (outExpl, expanded)
    end
    outExpl = Cons{Expression}(exp, outExpl)
  end
  outExpl = listReverseInPlace(outExpl)
  return (outExpl, expanded)
end

function expandVector(
  expl::Vector{Expression},
  abortOnFailure::Bool = true,
  )::Tuple{Vector{Expression}, Bool}
  local expanded::Bool = true
  local outExpl::Vector{Expression} = Expression[]
  local res::Bool
  for exp in expl
    (exp, res) = expand(exp)
    expanded = res && expanded
    if !res && abortOnFailure
      outExpl = expl
      return (outExpl, expanded)
    end
    push!(outExpl,exp)
  end
  return (outExpl, expanded)
end

@nospecializeinfer function expand(@nospecialize(exp::Expression))
  local expanded::Bool
   (exp, expanded) = begin
    @match exp begin
      CREF_EXPRESSION(ty = TYPE_ARRAY(__)) => begin
        expandCref(exp)
      end
      #=  One-dimensional arrays are already expanded. =#
      ARRAY_EXPRESSION(ty = TYPE_ARRAY(dimensions = nil())) => begin
        (exp, true)
      end

      ARRAY_EXPRESSION(__) => begin
        (expElements, expanded) = expandVector(exp.elements)
        exp = ARRAY_EXPRESSION(exp.ty, expElements, exp.literal)
        (exp, expanded)
      end

      TYPENAME_EXPRESSION(__) => begin
        (expandTypename(exp.ty), true)
      end

      RANGE_EXPRESSION(__) => begin
        expandRange(exp)
      end

      CALL_EXPRESSION(__) => begin
        expandCall(exp.call, exp)
      end

      SIZE_EXPRESSION(__) => begin
        expandSize(exp)
      end

      BINARY_EXPRESSION(__) => begin
        expandBinary(exp, exp.operator)
      end

      UNARY_EXPRESSION(__) => begin
        expandUnary(exp)
      end

      LBINARY_EXPRESSION(__) => begin
        expandLogicalBinary(exp)
      end

      LUNARY_EXPRESSION(__) => begin
        expandLogicalUnary(exp)
      end

      RELATION_EXPRESSION(__) => begin
        (exp, true)
      end

      CAST_EXPRESSION(__) => begin
        expandCast(exp)
      end

      _ => begin
        expandGeneric(exp)
      end
    end
  end
  return (exp, expanded)
end

function expandBuiltinFill(args::Vector)
  local expanded = true
  local outExp
  outExp = fillArgsDimVec(Base.first(args), args[2:end]) #Can probably use view here.
  return (outExp, expanded)
end

function expandBuiltinIdentity(args::Vector)::Tuple{Expression, Bool}
  local outExp = evalBuiltinIdentity(args[1])
  return (outExp, true)
end

function expandBuiltinZeros(args::Vector)::Tuple{Expression, Bool}
  local outExp = evalBuiltinZeros(args)
  return (outExp, true)
end

function expandBuiltinOnes(args::Vector)::Tuple{Expression, Bool}
  local outExp = evalBuiltinOnes(args)
  return (outExp, true)
end

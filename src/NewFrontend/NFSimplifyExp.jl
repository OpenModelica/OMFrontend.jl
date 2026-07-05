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

@nospecializeinfer function simplify(@nospecialize(exp::Expression))
  local tmp::Expression = begin
    @match exp begin
      CREF_EXPRESSION(__) => begin
        local expCref = simplifySubscripts(exp.cref)
        #= Reuse the node when the cref did not simplify; the subscripted type
           is then unchanged too, so no rebuild is needed. =#
        if referenceEq(expCref, exp.cref)
          exp
        else
          CREF_EXPRESSION(getSubscriptedType(expCref), expCref)
        end
      end

      ARRAY_EXPRESSION(__) => begin
        expElements = mapPreservingEq(exp.elements, simplify)
        if referenceEq(expElements, exp.elements)
          exp
        else
          ARRAY_EXPRESSION(exp.ty, expElements, exp.literal)
        end
      end

      RANGE_EXPRESSION(__) => begin
        simplifyRange(exp)
      end

      RECORD_EXPRESSION(__) => begin
        #println("Record expression")
        #println(toString(exp))
        #exp.elements = Expression[simplify(e) for e in exp.elements]
        simplifyRecord(exp)
        exp
      end

      CALL_EXPRESSION(__) => begin
        simplifyCall(exp)
      end

      SIZE_EXPRESSION(__) => begin
        simplifySize(exp)
      end

      BINARY_EXPRESSION(__) => begin
        seb = simplifyBinary(exp)
        seb
      end

      UNARY_EXPRESSION(__) => begin
        simplifyUnary(exp)
      end

      LBINARY_EXPRESSION(__) => begin
        simplifyLogicBinary(exp)
      end

      LUNARY_EXPRESSION(__) => begin
        simplifyLogicUnary(exp)
      end

      RELATION_EXPRESSION(__) => begin
        simplifyRelation(exp)
      end

      IF_EXPRESSION(__) => begin
        simplifyIf(exp)
      end

      CAST_EXPRESSION(__) => begin
        local se = simplify(exp.exp)
        local c = simplifyCast(se, exp.ty)
        (referenceEq(se, exp.exp) && c isa CAST_EXPRESSION) ? exp : c
      end

      UNBOX_EXPRESSION(__) => begin
        local se = simplify(exp.exp)
        referenceEq(se, exp.exp) ? exp : UNBOX_EXPRESSION(se, exp.ty)
      end

      SUBSCRIPTED_EXP_EXPRESSION(__) => begin
        simplifySubscriptedExp(exp)
      end

      TUPLE_ELEMENT_EXPRESSION(__) => begin
        simplifyTupleElement(exp)
      end

      BOX_EXPRESSION(__) => begin
        local se = simplify(exp.exp)
        referenceEq(se, exp.exp) ? exp : BOX_EXPRESSION(se)
      end

      MUTABLE_EXPRESSION(__) => begin
        simplify(P_Pointer.access(exp.exp))
      end
      _ => begin
        exp
      end
    end
  end
  return tmp
end

function simplifyOpt(exp::Option{<:Expression})
  local e::Expression
   exp = begin
    @match exp begin
      SOME(e) => begin
        SOME(simplify(e))
      end

      _ => begin
        exp
      end
    end
  end
  return exp
end

@nospecializeinfer function simplifyRange(@nospecialize(range::Expression))
  local exp::Expression

  local start_exp1::Expression
  local stop_exp1::Expression
  local start_exp2::Expression
  local stop_exp2::Expression
  local step_exp1::Option{Expression}
  local step_exp2::Option{Expression}
  local ty::M_Type

  @match RANGE_EXPRESSION(
    ty = ty,
    start = start_exp1,
    step = step_exp1,
    stop = stop_exp1,
  ) = range
   start_exp2 = simplify(start_exp1)
   step_exp2 = simplifyOpt(step_exp1)
   stop_exp2 = simplify(stop_exp1)
  if referenceEq(start_exp1, start_exp2) &&
     referenceEq(step_exp1, step_exp2) &&
     referenceEq(stop_exp1, stop_exp2)
     exp = range
  else
     ty = getRangeType(
      start_exp2,
      step_exp2,
      stop_exp2,
      arrayElementType(ty),
      AbsynUtil.dummyInfo,
    )
     exp = RANGE_EXPRESSION(ty, start_exp2, step_exp2, stop_exp2)
  end
  return exp
end

@nospecializeinfer function simplifyCall(@nospecialize(callExp::Expression))
  local call::Call
  local args::Vector{Expression}
  local builtin::Bool
  local is_pure::Bool
  @match CALL_EXPRESSION(call = call) = callExp
  callExp = begin
    @match call begin
      TYPED_CALL(arguments = args) where {(!isExternal(call))} => begin
        local origArgs = args
        if Flags.isSet(Flags.NF_EXPAND_FUNC_ARGS)
          args = mapPreservingEq(args, arg -> hasArrayCall(arg) ? arg : Base.first(expand(arg)))
        end
        #=  HACK, TODO, FIXME! handle DynamicSelect properly in OMEdit, then disable this stuff! =#
        if Flags.isSet(Flags.NF_API) && !Flags.isSet(Flags.NF_API_DYNAMIC_SELECT)
          if stringEq(
            "DynamicSelect",
            AbsynUtil.pathString(nameConsiderBuiltin(call.fn)),
          )
             callExp = simplify(listHead(args))
            return
          end
        end
        args = mapPreservingEq(args, simplify)
        local changed = !referenceEq(args, origArgs)
        if changed
          call = TYPED_CALL(call.fn, call.ty, call.var, args, call.attributes)
        end
        builtin = isBuiltin(call.fn)
        is_pure = !isImpure(call.fn)
        #=  Use Ceval for builtin pure functions with literal arguments.
        =#
        if builtin
          local scalarize = Flags.isSet(Flags.NF_SCALARIZE)
          if (is_pure && ArrayUtil.all(args, isLiteral)) && (scalarize && isScalar(call.ty))
            try
              callExp = evalCall(call, EVALTARGET_IGNORE_ERRORS())
              callExp = stripBindingInfo(callExp)
            catch e
              #@info "DBG print to remove $e"
              callExp = CALL_EXPRESSION(call)
            end
          else
            if Flags.isSet(Flags.NF_SCALARIZE)
              callExp = simplify(nameConsiderBuiltin(call.fn), args, call)
            end
          end
        elseif Flags.isSet(Flags.NF_EVAL_CONST_ARG_FUNCS) &&
               is_pure &&
               ArrayUtil.all(args, isLiteral)
          callExp = simplifyCall2(call)
        else
          callExp = changed ? CALL_EXPRESSION(call) : callExp
        end
        #=  do not expand builtin calls if we should not scalarize
        =#
        #=  nothing
        =#
        callExp
      end

      TYPED_ARRAY_CONSTRUCTOR(__) => begin
        simplifyArrayConstructor(call)
      end

      TYPED_REDUCTION(__) => begin
        @assign call.exp = simplify(call.exp)
        @assign call.iters =
          list((Util.tuple21(i), simplify(Util.tuple22(i))) for i in call.iters)
        CALL_EXPRESSION(call)
      end

      _ => begin
        callExp
      end
    end
  end
  return callExp
end

const CONST_FOLD_CACHE = Dict{String,Expression}()

function simplifyCall2(call::Call)
  local outExp::Expression
  local key = toString(CALL_EXPRESSION(call))
  local hit = get(CONST_FOLD_CACHE, key, nothing)
  if hit !== nothing
    return hit
  end
  ErrorExt.setCheckpoint(getInstanceName())
  try
     outExp = evalCall(call, EVALTARGET_IGNORE_ERRORS())
     outExp = stripBindingInfo(outExp)
    ErrorExt.delCheckpoint(getInstanceName())
    CONST_FOLD_CACHE[key] = outExp
  catch
    if Flags.isSet(Flags.FAILTRACE)
      ErrorExt.delCheckpoint(getInstanceName())
      Debug.traceln(
        "- " + getInstanceName() + " failed to evaluate " + toString(call) + "\\n",
      )
    else
      ErrorExt.rollBack(getInstanceName())
    end
     outExp = CALL_EXPRESSION(call)
  end
  return outExp
end

function simplify(
  name::Absyn.Path,
  args::Vector{Expression},
  call::Call,
)
  local exp::Expression
  exp = begin
    @match AbsynUtil.pathFirstIdent(name) begin
      "cat" => begin
        (exp, _) = expandBuiltinCat(args, call)
        exp
      end
      "sum" => begin
        simplifySumProduct(Base.first(args), call, #=isSum=# true)
      end
      "product" => begin
        simplifySumProduct(Base.first(args), call, #=isSum=# false)
      end
      "transpose" => begin
        simplifyTranspose(Base.first(args), call)
      end
      _ => begin
        CALL_EXPRESSION(call)
      end
    end
  end
  return exp
end

function simplifySumProduct(arg::Expression, call::Call, isSum::Bool)
  local exp::Expression

  local expanded::Bool
  local args::Vector{Expression}
  local ty::M_Type
  local op::Operator

  (exp, expanded) = expand(arg)
  if expanded
    args = listArray(arrayScalarElements(exp))
    ty = arrayElementType(typeOf(arg))
    if isempty(args)
      exp = if isSum
        makeZero(ty)
      else
        makeOne(ty)
      end
    else
      @match [exp, args...] = args
       op = if isSum
        makeAdd(ty)
      else
        makeMul(ty)
      end
      for e in args
        exp = BINARY_EXPRESSION(exp, op, e)
      end
    end
  else
     exp = CALL_EXPRESSION(call)
  end
  return exp
end

function simplifyTranspose(arg::Expression, call::Call)
  local exp::Expression
  local e::Expression
  if hasArrayCall(arg)
    e = arg
  else
    (e, _) = expand(arg)
  end
  exp = begin
    @match e begin
      ARRAY_EXPRESSION(
        __,
      ) where {(ArrayUtil.all(e.elements, isArray))} => begin
        transposeArray(e)
      end
      _ => begin
        CALL_EXPRESSION(call)
      end
    end
  end
  return exp
end

function simplifyArrayConstructor(call::Call)
  local outExp::Expression
  local ty::M_Type
  local var::VariabilityType
  local exp::Expression
  local e::Expression
  local iters::List{Tuple{InstNode, Expression}}
  local iter::InstNode
  local dim::Dimension
  local dim_size::Int
  local expanded::Bool
  @match TYPED_ARRAY_CONSTRUCTOR(ty, var, exp, iters) = call
  iters = list((Util.tuple21(i), simplify(Util.tuple22(i))) for i in iters)
  outExp = begin
    @matchcontinue iters begin
      (iter, e) <| T where{T isa Nil} => begin
        @match TYPE_ARRAY(dimensions = dim <| T) where {T isa Nil} = typeOf(e)
        dim_size = size(dim)
        if dim_size == 0
          outExp = makeEmptyArray(ty)
        elseif dim_size == 1
          @match (ARRAY_EXPRESSION(elements = [e]), _) = expand(e)
          exp = replaceIterator(exp, iter, e)
          exp = makeArray(ty, Expression[exp])
          outExp = simplify(exp)
        else
          fail()
        end
        #=  Result is Array[0], return empty array expression.
        =#
        #=  Result is Array[1], return array with the single element.
        =#
        outExp
      end
      _ => begin
        exp = simplify(exp)
        CALL_EXPRESSION(TYPED_ARRAY_CONSTRUCTOR(ty, var, exp, iters))
      end
    end
  end
  return outExp
end

function simplifySize(sizeExp::Expression)
   sizeExp = begin
    local exp::Expression
    local index::Expression
    local dim::Dimension
    local dims::List{Dimension}
    @match sizeExp begin
      SIZE_EXPRESSION(exp, SOME(index)) => begin
        index = simplify(index)
        if isLiteral(index)
          dim = listGet(
            arrayDims(typeOf(exp)),
            toInteger(index),
          )
          if isKnown(dim)
            exp = INTEGER_EXPRESSION(size(dim))
          else
            exp = SIZE_EXPRESSION(exp, SOME(index))
          end
        else
          exp = SIZE_EXPRESSION(exp, SOME(index))
        end
        exp
      end
      SIZE_EXPRESSION(__) => begin
         dims = arrayDims(typeOf(sizeExp.exp))
        if listUtil.all(dims, (x, y=true) -> isKnown(x, y))
           exp = makeArray(
            TYPE_ARRAY(
              TYPE_INTEGER(),
              list(fromInteger(listLength(dims))),
            ),
            Expression[sizeExp(d) for d in dims],
          )
        else
           exp = sizeExp
        end
        exp
      end
    end
  end
  return sizeExp
end

#= Reuse `orig` when the fallback would rebuild the identical binary (same
   operands by identity, same operator); otherwise allocate a fresh node. =#
@inline function reuseBinary(@nospecialize(orig), @nospecialize(e1), op::Operator, @nospecialize(e2))
  if orig isa BINARY_EXPRESSION && orig.operator === op &&
     referenceEq(orig.exp1, e1) && referenceEq(orig.exp2, e2)
    return orig
  end
  return BINARY_EXPRESSION(e1, op, e2)
end

@nospecializeinfer function simplifyBinary(@nospecialize(binaryExp::Expression))
  local e1::Expression
  local e2::Expression
  local se1::Expression
  local se2::Expression
  local op::Operator
  @match BINARY_EXPRESSION(e1, op, e2) = binaryExp
  se1 = simplify(e1)
  se2 = simplify(e2)
  binaryExp = simplifyBinaryOp(se1, op, se2, binaryExp)
  if Flags.isSet(Flags.NF_EXPAND_OPERATIONS) && !hasArrayCall(binaryExp)
    (binaryExp, _) = expand(binaryExp)
  end
  return binaryExp
end

@nospecializeinfer function simplifyBinaryOp(@nospecialize(exp1::Expression), op::Operator, @nospecialize(exp2::Expression), @nospecialize(orig = nothing))
  local outExp::Expression

  if isLiteral(exp1) && isLiteral(exp2)
    outExp = evalBinaryOp(
      expand(exp1)[1],
      op,
      expand(exp2)[1],
    )
    outExp = stripBindingInfo(outExp)
  else
    outExp = begin
      @match op.op begin
        Op.ADD => begin
          simplifyBinaryAdd(exp1, op, exp2, orig)
        end

        Op.SUB => begin
          simplifyBinarySub(exp1, op, exp2, orig)
        end

        Op.MUL => begin
          simplifyBinaryMul(exp1, op, exp2, false, orig)
        end

        Op.DIV => begin
          simplifyBinaryDiv(exp1, op, exp2, orig)
        end

        Op.POW => begin
          simplifyBinaryPow(exp1, op, exp2, orig)
        end

        _ => begin
          reuseBinary(orig, exp1, op, exp2)
        end
      end
    end
  end
  return outExp
end

@nospecializeinfer function simplifyBinaryAdd(@nospecialize(exp1::Expression), op::Operator, @nospecialize(exp2::Expression), @nospecialize(orig = nothing))
  local outExp::Expression

  if isZero(exp1)
    outExp = exp2
  elseif isZero(exp2)
    outExp = exp1
  elseif isNegated(exp2)
    outExp = BINARY_EXPRESSION(
      exp1,
      negate(op),
      negate(exp2),
    )
  else
    outExp = reuseBinary(orig, exp1, op, exp2)
  end
  #=  0 + e = e
  =#
  #=  e + 0 = e
  =#
  #=  e1 + -(e2) = e1 - e2
  =#
  return outExp
end

@nospecializeinfer function simplifyBinarySub(@nospecialize(exp1::Expression), op::Operator, @nospecialize(exp2::Expression), @nospecialize(orig = nothing))
  local outExp::Expression

  if isZero(exp1)
     outExp = UNARY_EXPRESSION(
      makeUMinus(typeOf(op)),
      exp2,
    )
  elseif isZero(exp2)
     outExp = exp1
  elseif isNegated(exp2)
     outExp = BINARY_EXPRESSION(
      exp1,
      negate(op),
      negate(exp2),
    )
  else
     outExp = reuseBinary(orig, exp1, op, exp2)
  end
  #=  0 - e = -e
  =#
  #=  e - 0 = e
  =#
  #=  e1 - -(e2) = e1 + e2
  =#
  return outExp
end

@nospecializeinfer function simplifyBinaryMul(
  @nospecialize(exp1::Expression),
  op::Operator,
  @nospecialize(exp2::Expression),
  switched::Bool = false,
  @nospecialize(orig = nothing),
)
  local outExp::Expression

   outExp = begin
    @match exp1 begin
      INTEGER_EXPRESSION(value = 0) => begin
        exp1
      end

      REAL_EXPRESSION(value = 0.0) => begin
        exp1
      end

      INTEGER_EXPRESSION(value = 1) => begin
        exp2
      end

      REAL_EXPRESSION(value = 1.0) => begin
        exp2
      end

      _ => begin
        if switched
          #= operands are swapped back to original order here =#
          reuseBinary(orig, exp2, op, exp1)
        else
          simplifyBinaryMul(exp2, op, exp1, true, orig)
        end
      end
    end
  end
  #=  0 * e = 0
  =#
  #=  1 * e = e
  =#
  return outExp
end

@nospecializeinfer function simplifyBinaryDiv(@nospecialize(exp1::Expression), op::Operator, @nospecialize(exp2::Expression), @nospecialize(orig = nothing))
  local outExp::Expression

  #=  e / 1 = e
  =#
  if isOne(exp2)
     outExp = exp1
  else
     outExp = reuseBinary(orig, exp1, op, exp2)
  end
  return outExp
end

@nospecializeinfer function simplifyBinaryPow(@nospecialize(exp1::Expression), op::Operator, @nospecialize(exp2::Expression), @nospecialize(orig = nothing))
  local outExp::Expression

  if isZero(exp2)
     outExp = makeOne(typeOf(op))
  elseif isOne(exp2)
     outExp = exp1
  else
     outExp = reuseBinary(orig, exp1, op, exp2)
  end
  return outExp
end

@nospecializeinfer function simplifyUnary(@nospecialize(unaryExp::Expression))
  local e::Expression
  local se::Expression
  local op::Operator
  @match UNARY_EXPRESSION(op, e) = unaryExp
   se = simplify(e)
   unaryExp = simplifyUnaryOp(se, op, unaryExp)
  if Flags.isSet(Flags.NF_EXPAND_OPERATIONS) && !hasArrayCall(unaryExp)
    (unaryExp, _) = expand(unaryExp)
 end
  return unaryExp
end

@nospecializeinfer function simplifyUnaryOp(@nospecialize(exp::Expression), op::Operator, @nospecialize(orig = nothing))
  local outExp::Expression
  if isLiteral(exp)
    outExp = evalUnaryOp(exp, op)
    outExp = stripBindingInfo(outExp)
  elseif orig isa UNARY_EXPRESSION && orig.operator === op && referenceEq(orig.exp, exp)
    outExp = orig
  else
    outExp = UNARY_EXPRESSION(op, exp)
  end
  return outExp
end

@nospecializeinfer function simplifyLogicBinary(@nospecialize(binaryExp::Expression))

  local e1::Expression
  local e2::Expression
  local se1::Expression
  local se2::Expression
  local op::Operator

  @match LBINARY_EXPRESSION(e1, op, e2) = binaryExp
   se1 = simplify(e1)
   se2 = simplify(e2)
   binaryExp = begin
    @match op.op begin
      Op.AND => begin
        simplifyLogicBinaryAnd(se1, op, se2, binaryExp)
      end

      Op.OR => begin
        simplifyLogicBinaryOr(se1, op, se2, binaryExp)
      end
    end
  end
  return binaryExp
end

#= Reuse `orig` when the LBINARY fallback would rebuild the identical node. =#
@inline function reuseLBinary(@nospecialize(orig), @nospecialize(e1), op::Operator, @nospecialize(e2))
  if orig isa LBINARY_EXPRESSION && orig.operator === op &&
     referenceEq(orig.exp1, e1) && referenceEq(orig.exp2, e2)
    return orig
  end
  return LBINARY_EXPRESSION(e1, op, e2)
end

@nospecializeinfer function simplifyLogicBinaryAnd(
  @nospecialize(exp1::Expression),
  op::Operator,
  @nospecialize(exp2::Expression),
  @nospecialize(orig = nothing),
)
  local exp::Expression

   exp = begin
    local expl::List{Expression}
    local o::Operator
    #=  false and e => false
    =#
    @match (exp1, exp2) begin
      (BOOLEAN_EXPRESSION(false), _) => begin
        exp1
      end

      (_, BOOLEAN_EXPRESSION(false)) => begin
        exp2
      end

      (BOOLEAN_EXPRESSION(true), _) => begin
        exp2
      end

      (_, BOOLEAN_EXPRESSION(true)) => begin
        exp1
      end

      (ARRAY_EXPRESSION(__), ARRAY_EXPRESSION(__)) => begin
        #=  e and false => false
        =#
        #=  true and e => e
        =#
        #=  e and true => e
        =#
         o = unlift(op)
         expl =
          list(@do_threaded_for simplifyLogicBinaryAnd(e1, o, e2) (e1, e2) (
            exp1.elements,
            exp2.elements,
          ))
        makeArray(typeOf(op), listArray(expl))
      end

      _ => begin
        reuseLBinary(orig, exp1, op, exp2)
      end
    end
  end
  return exp
end

@nospecializeinfer function simplifyLogicBinaryOr(@nospecialize(exp1::Expression), op::Operator, @nospecialize(exp2::Expression), @nospecialize(orig = nothing))
  local exp::Expression

   exp = begin
    local expl::List{Expression}
    local o::Operator
    #=  true or e => true
    =#
    @match (exp1, exp2) begin
      (BOOLEAN_EXPRESSION(true), _) => begin
        exp1
      end

      (_, BOOLEAN_EXPRESSION(true)) => begin
        exp2
      end

      (BOOLEAN_EXPRESSION(false), _) => begin
        exp2
      end

      (_, BOOLEAN_EXPRESSION(false)) => begin
        exp1
      end

      (ARRAY_EXPRESSION(__), ARRAY_EXPRESSION(__)) => begin
        #=  e or true => true
        =#
        #=  false or e => e
        =#
        #=  e or false => e
        =#
         o = unlift(op)
         expl =
          list(@do_threaded_for simplifyLogicBinaryAnd(e1, o, e2) (e1, e2) (
            exp1.elements,
            exp2.elements,
          ))
        makeArray(typeOf(op), listArray(expl))
      end

      _ => begin
        reuseLBinary(orig, exp1, op, exp2)
      end
    end
  end
  return exp
end

@nospecializeinfer function simplifyLogicUnary(@nospecialize(unaryExp::Expression))
  local e::Expression
  local se::Expression
  local op::Operator
  @match LUNARY_EXPRESSION(op, e) = unaryExp
  se = simplify(e)
  if isLiteral(se)
    unaryExp = evalLogicUnaryOp(se, op)
    unaryExp = stripBindingInfo(unaryExp)
  elseif !referenceEq(e, se)
    unaryExp = LUNARY_EXPRESSION(op, se)
  end
  return unaryExp
end

@nospecializeinfer function simplifyRelation(@nospecialize(relationExp::Expression))
  local e1::Expression
  local e2::Expression
  local se1::Expression
  local se2::Expression
  local op::Operator

  @match RELATION_EXPRESSION(e1, op, e2) = relationExp
   se1 = simplify(e1)
   se2 = simplify(e2)
  if isLiteral(se1) && isLiteral(se2)
     relationExp = evalRelationOp(se1, op, se2)
     relationExp = stripBindingInfo(relationExp)
  elseif !(referenceEq(e1, se1) && referenceEq(e2, se2))
     relationExp = RELATION_EXPRESSION(se1, op, se2)
  end
  return relationExp
end

@nospecializeinfer function simplifyIf(@nospecialize(ifExp::Expression))

  local cond::Expression
  local tb::Expression
  local fb::Expression

  local ocond::Expression
  local otb::Expression
  local ofb::Expression
  @match IF_EXPRESSION(ocond, otb, ofb) = ifExp
   cond = simplify(ocond)
   ifExp = begin
    @match cond begin
      BOOLEAN_EXPRESSION(__) => begin
        simplify(if cond.value
          otb
        else
          ofb
        end)
      end
      _ => begin
         tb = simplify(otb)
         fb = simplify(ofb)
        if isEqual(tb, fb)
          tb
        elseif referenceEq(cond, ocond) && referenceEq(tb, otb) && referenceEq(fb, ofb)
          ifExp
        else
          IF_EXPRESSION(cond, tb, fb)
        end
      end
    end
  end
  return ifExp
end

@nospecializeinfer function simplifyCast(@nospecialize(exp::Expression), @nospecialize(ty::NFType))
  local castExp::Expression
  castExp = begin
    local ety::NFType
    @match (ty, exp) begin
      (TYPE_REAL(__), INTEGER_EXPRESSION(__)) => begin
        REAL_EXPRESSION(intReal(exp.value))
      end
      (TYPE_ARRAY(elementType = TYPE_REAL(__)), ARRAY_EXPRESSION(__)) =>
        begin
          ety = unliftArray(ty)
          expElements = Expression[simplifyCast(e, ety) for e in exp.elements]
          expTy = setArrayElementType(exp.ty, arrayElementType(ty))
          ARRAY_EXPRESSION(expTy, expElements, exp.literal)
        end
      _ => begin
        CAST_EXPRESSION(ty, exp)
      end
    end
  end
  return castExp
end

@nospecializeinfer function simplifySubscriptedExp(@nospecialize(subscriptedExp::Expression); split = false)
  local e::Expression
  local subs::List{Subscript}
  local ty::NFType
  @match SUBSCRIPTED_EXP_EXPRESSION(e, subs, ty) = subscriptedExp
  subscriptedExp = simplify(e)
  subs = simplifyList(subs, arrayDims(typeOf(e)))
  cond = ! listEmpty(subs) && isArray(subscriptedExp) && ! isEmptyArray(subscriptedExp) &&
    ArrayUtil.allEqual(arrayElements(subscriptedExp), isEqual)
  if !split && !(ListUtil.all(subs, isLiteral))
    while cond
      @match h <| subs = subs
      subscriptedExp = arrayGet(arrayElements(subscriptedExp), 1)
      cond = ! listEmpty(subs) && isArray(subscriptedExp) && ! isEmptyArray(subscriptedExp) &&
        ArrayUtil.allEqual(arrayElements(subscriptedExp), isEqual)
    end
    if listEmpty(subs)
      return subscriptedExp
    end
  end
  subscriptedExp = applySubscripts(subs, subscriptedExp)
  return subscriptedExp
end

@nospecializeinfer function simplifyTupleElement(@nospecialize(tupleExp::Expression))
  local e::Expression
  local index::Int
  local ty::M_Type
  @match TUPLE_ELEMENT_EXPRESSION(e, index, ty) = tupleExp
  e = simplify(e)
  tupleExp = tupleElement(e, ty, index)
  return tupleExp
end


function simplifyRecord(recordExpr::RECORD_EXPRESSION)
  # local args = if Flags.isSet(Flags.NF_EXPAND_FUNC_ARGS)
  #   Expression[if hasArrayCall(arg)
  #                arg
  #              else
  #                Base.first(expand(arg))
  #              end for arg in recordExpr.elements]

  # else
  #   recordExpr.elements
  # end
  # #= TODO, possible use apply here. =#
  # recordExpr.elements = Expression[simplify(e) for e in args]
  return recordExpr
end

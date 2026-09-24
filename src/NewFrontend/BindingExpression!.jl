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
```
mapFoldShallow!(@nospecialize(exp::Expression), @nospecialize(func::Function), arg::ArgT)  where {ArgT}
```

Same as ```mapFoldShallow(@nospecialize(exp::Expression), @nospecialize(func::Function), arg::ArgT)```,
however this function mutates the argument if possible.
TODO:
Not fully implemented yet.
"""
function mapFoldShallow!(@nospecialize(exp::Expression), @nospecialize(func::Function), arg::ArgT)  where {ArgT}
  local outExp::Expression
  outExp = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local e4::Expression
    local oe::Option{Expression}
    local cr::ComponentRef
    local expl::List{Expression}
    local call::Call
    local subs::List{Subscript}
    local unchanged::Bool
    #@debug "Calling mapFoldShallow"
    @match exp begin
      CLKCONST_EXPRESSION(__)  => begin
        (outExp, arg) = mapFoldClockShallow(exp, func, arg)
        outExp
      end
      CREF_EXPRESSION(__)  => begin
         (cr, arg) = mapFoldCrefShallow(exp.cref, func, arg)
        if referenceEq(exp.cref, cr)
          exp
        else
          CREF_EXPRESSION(exp.ty, cr)
        end
      end
      ARRAY_EXPRESSION(__)  => begin
        (expV, arg) = ArrayUtil.mapFold(exp.elements, func, arg)
        ARRAY_EXPRESSION(exp.ty, expV, exp.literal)
      end

      RANGE_EXPRESSION(step = oe)  => begin
         (e1, arg) = func(exp.start, arg)
         (oe, arg) = mapFoldOptShallow(exp.step, func, arg)
         (e3, arg) = func(exp.stop, arg)
        if referenceEq(e1, exp.start) && referenceEq(oe, exp.step) && referenceEq(e3, exp.stop)
          exp
        else
          RANGE_EXPRESSION(exp.ty, e1, oe, e3)
        end
      end

      TUPLE_EXPRESSION(__)  => begin
         (expl, arg) = ListUtil.mapFold(exp.elements, func, arg)
        TUPLE_EXPRESSION(exp.ty, expl)
      end

      RECORD_EXPRESSION(__)  => begin
        (expV, arg) = ArrayUtil.mapFold(exp.elements, func, arg)
        RECORD_EXPRESSION(exp.path, exp.ty, expV)
      end

      CALL_EXPRESSION(__)  => begin
         (call, arg) = mapFoldCallShallow(exp.call, func, arg)
        if referenceEq(exp.call, call)
          exp
        else
          CALL_EXPRESSION(call)
        end
      end

      SIZE_EXPRESSION(__)  => begin
         (e1, arg) = func(exp.exp, arg)
         (oe, arg) = mapFoldOptShallow(exp.dimIndex, func, arg)
        if referenceEq(exp.exp, e1) && referenceEq(exp.dimIndex, oe)
          exp
        else
          SIZE_EXPRESSION(e1, oe)
        end
      end

      BINARY_EXPRESSION(__)  => begin
         (e1, arg) = func(exp.exp1, arg)
         (e2, arg) = func(exp.exp2, arg)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          BINARY_EXPRESSION(e1, exp.operator, e2)
        end
      end

      UNARY_EXPRESSION(__)  => begin
         (e1, arg) = func(exp.exp, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          UNARY_EXPRESSION(exp.operator, e1)
        end
      end

      LBINARY_EXPRESSION(__)  => begin
         (e1, arg) = func(exp.exp1, arg)
         (e2, arg) = func(exp.exp2, arg)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          LBINARY_EXPRESSION(e1, exp.operator, e2)
        end
      end

      LUNARY_EXPRESSION(__)  => begin
         (e1, arg) = func(exp.exp, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          LUNARY_EXPRESSION(exp.operator, e1)
        end
      end

      RELATION_EXPRESSION(__)  => begin
         (e1, arg) = func(exp.exp1, arg)
         (e2, arg) = func(exp.exp2, arg)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          RELATION_EXPRESSION(e1, exp.operator, e2)
        end
      end

      IF_EXPRESSION(__)  => begin
         (e1, arg) = func(exp.condition, arg)
         (e2, arg) = func(exp.trueBranch, arg)
         (e3, arg) = func(exp.falseBranch, arg)
        if referenceEq(exp.condition, e1) && referenceEq(exp.trueBranch, e2) && referenceEq(exp.falseBranch, e3)
          exp
        else
          IF_EXPRESSION(e1, e2, e3)
        end
      end

      CAST_EXPRESSION(__)  => begin
         (e1, arg) = func(exp.exp, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          CAST_EXPRESSION(exp.ty, e1)
        end
      end

      UNBOX_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          UNBOX_EXPRESSION(e1, exp.ty)
        end
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp, arg)
        (subs, arg) = ListUtil.mapFold(exp.subscripts, (ss, foldArg) -> mapFoldExpShallow(ss, func, foldArg), arg)
        SUBSCRIPTED_EXP_EXPRESSION(e1, subs, exp.ty)
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.tupleExp, arg)
        if referenceEq(exp.tupleExp, e1)
          exp
        else
          TUPLE_ELEMENT_EXPRESSION(e1, exp.index, exp.ty)
        end
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
         (e1, arg) = func(exp.recordExp, arg)
        if referenceEq(exp.recordExp, e1)
          exp
        else
          RECORD_ELEMENT_EXPRESSION(e1, exp.index, exp.fieldName, exp.ty)
        end
      end

      MUTABLE_EXPRESSION(__)  => begin
        (e1, arg) = func(P_Pointer.access(exp.exp), arg)
        P_Pointer.update(exp.exp, e1)
        exp
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        (expl, arg) = ListUtil.mapFold(exp.args, func, arg)
        local expArgs = expl
        PARTIAL_FUNCTION_APPLICATION_EXPRESSION(exp.fn, expArgs, exp.argNames, exp.ty)
      end

      BINDING_EXP(__)  => begin
        (e1, arg) = func(exp.exp, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          BINDING_EXP(e1, exp.expType, exp.bindingType, exp.parents, exp.isEach)
        end
      end

      _  => begin
        exp
      end
    end
  end
  (outExp, arg)
end


"""
```
mapFoldShallowRef!(@nospecialize(exp::Expression), @nospecialize(func::Function), arg::ArgT, )  where {ArgT}
```

Same as ```mapFoldShallow(@nospecialize(exp::Expression), @nospecialize(func::Function), arg::ArgT)```,
however this function mutates the argument if possible.
TODO:
Not fully implemented yet.
"""
function mapFoldShallowRef(@nospecialize(exp::Expression), @nospecialize(func::Function), arg::ArgT, outRefArg::Ref{ArgT})  where {ArgT}
  local outExp::Expression
  outExp = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local e4::Expression
    local oe::Option{Expression}
    local cr::ComponentRef
    local expl::List{Expression}
    local call::Call
    local subs::List{Subscript}
    local unchanged::Bool
    @match exp begin
      CLKCONST_EXPRESSION(__)  => begin
        (outExp, arg) = mapFoldClockShallow(exp, func, arg)
        outExp
      end
      CREF_EXPRESSION(__)  => begin
        (cr, arg) = mapFoldCrefShallow(exp.cref, func, arg)
        if referenceEq(exp.cref, cr)
          exp
        else
          CREF_EXPRESSION(exp.ty, cr)
        end
      end
      ARRAY_EXPRESSION(__)  => begin
        expV = ArrayUtil.mapFoldSO(exp.elements, (e, a) -> func(e, a)[1], arg)
        ARRAY_EXPRESSION(exp.ty, expV, exp.literal)
      end

      RANGE_EXPRESSION(step = oe)  => begin
        (e1, arg) = func(exp.start, arg)
        (oe, arg) = mapFoldOptShallow(exp.step, func, arg)
        (e3, arg) = func(exp.stop, arg)
        outRefArg.x = arg
        if referenceEq(e1, exp.start) && referenceEq(oe, exp.step) && referenceEq(e3, exp.stop)
          exp
        else
          RANGE_EXPRESSION(exp.ty, e1, oe, e3)
        end
      end

      TUPLE_EXPRESSION(__)  => begin
        (expl, arg) = ListUtil.mapFold(exp.elements, func, arg)
        TUPLE_EXPRESSION(exp.ty, expl)
      end

      RECORD_EXPRESSION(__)  => begin
        (expV, arg) = ArrayUtil.mapFold(exp.elements, func, arg)
        RECORD_EXPRESSION(exp.path, exp.ty, expV)
      end

      CALL_EXPRESSION(__)  => begin
        call = mapFoldCallShallowRef(exp.call, func, arg, outRefArg)
        if referenceEq(exp.call, call)
          exp
        else
          CALL_EXPRESSION(call)
        end
      end

      SIZE_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp, arg)
        (oe, arg) = mapFoldOptShallow(exp.dimIndex, func, arg)
        if referenceEq(exp.exp, e1) && referenceEq(exp.dimIndex, oe)
          exp
        else
          SIZE_EXPRESSION(e1, oe)
        end
      end

      BINARY_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp1, arg)
        (e2, arg) = func(exp.exp2, arg)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          BINARY_EXPRESSION(e1, exp.operator, e2)
        end
      end

      UNARY_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          UNARY_EXPRESSION(exp.operator, e1)
        end
      end

      LBINARY_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp1, arg)
        (e2, arg) = func(exp.exp2, arg)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          LBINARY_EXPRESSION(e1, exp.operator, e2)
        end
      end

      LUNARY_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          LUNARY_EXPRESSION(exp.operator, e1)
        end
      end

      RELATION_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp1, arg)
        (e2, arg) = func(exp.exp2, arg)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          RELATION_EXPRESSION(e1, exp.operator, e2)
        end
      end

      IF_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.condition, arg)
        outRefArg.x = arg
        (e2, arg) = func(exp.trueBranch, arg)
        outRefArg.x = arg
        (e3, arg) = func(exp.falseBranch, arg)
        outRefArg.x = arg
        if referenceEq(exp.condition, e1) && referenceEq(exp.trueBranch, e2) && referenceEq(exp.falseBranch, e3)
          exp
        else
          IF_EXPRESSION(e1, e2, e3)
        end
      end

      CAST_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp, arg)
        outRefArg.x = arg
        if referenceEq(exp.exp, e1)
          exp
        else
          CAST_EXPRESSION(exp.ty, e1)
        end
      end

      UNBOX_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          UNBOX_EXPRESSION(e1, exp.ty)
        end
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.exp, arg)
        subs = ListUtil.mapFoldSO(exp.subscripts, (ss, foldArg) -> mapFoldExpShallowO1(ss, func, foldArg), arg)
        SUBSCRIPTED_EXP_EXPRESSION(e1, subs, exp.ty)
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.tupleExp, arg)
        if referenceEq(exp.tupleExp, e1)
          exp
        else
          TUPLE_ELEMENT_EXPRESSION(e1, exp.index, exp.ty)
        end
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        (e1, arg) = func(exp.recordExp, arg)
        if referenceEq(exp.recordExp, e1)
          exp
        else
          RECORD_ELEMENT_EXPRESSION(e1, exp.index, exp.fieldName, exp.ty)
        end
      end

      MUTABLE_EXPRESSION(__)  => begin
        (e1, arg) = func(P_Pointer.access(exp.exp), arg)
        P_Pointer.update(exp.exp, e1)
        exp
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        (expl, arg) = ListUtil.mapFold(exp.args, func, arg)
        local expArgs = expl
        PARTIAL_FUNCTION_APPLICATION_EXPRESSION(exp.fn, expArgs, exp.argNames, exp.ty)
      end

      BINDING_EXP(__)  => begin
        (e1, arg) = func(exp.exp, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          BINDING_EXP(e1, exp.expType, exp.bindingType, exp.parents, exp.isEach)
        end
      end

      _  => begin
        exp
      end
    end
  end
  #=  Merge the value-based fold (arg) with the Ref-based tracking.
      Some match arms (CALL_EXPRESSION, SUBSCRIPTED_EXP_EXPRESSION) use
      mapFoldSO which discards the fold result, so arg can stay stale.
      Callbacks update outRefArg.x directly via side effects.
      Use && to preserve false from either source. =#
  outRefArg.x = arg && outRefArg.x
  outExp
end


function mapFoldCallShallowRef(call::Call, @nospecialize(func::Function), foldArg::ArgT, outRefArg::Ref{ArgT})  where {ArgT}
  local outCall::Call
  outCall = begin
    local args::Vector{Expression}
    local nargs::Vector{NamedArg}
    local targs::Vector{TypedArg}
    local tnargs::Vector{TypedNamedArg}
    local s::String
    local e::Expression
    local t::M_Type
    local v::VariabilityType
    local iters::List{Tuple{InstNode, Expression}}
    local default_exp::Option{Expression}
    local fold_exp::Tuple{Option{Expression}, String, String}
    local oe::Option{Expression}
    @match call begin
      UNTYPED_CALL(__)  => begin
        (args, foldArg) = ArrayUtil.mapFold(call.arguments, func, foldArg)
        nargs = Vector{NamedArg}(undef, length(call.named_args))
        for (i,arg) in enumerate(call.named_args)
          (s, e) = arg
          (e, foldArg) = func(e, foldArg)
          nargs[i] = (s, e)
        end
        UNTYPED_CALL(call.ref, args, nargs, call.call_scope)
      end

      ARG_TYPED_CALL(__)  => begin
        targs = Vector{TypedArg}(undef, length(call.arguments))
        tnargs = Vector{TypedNamedArg}(undef, length(call.named_args))
        for (i, arg) in enumerate(call.arguments)
           (e, t, v) = arg
           (e, foldArg) = func(e, foldArg)
           targs[i] = (e, t, v)
        end
        for (i,arg) in enumerate(call.named_args)
          (s, e, t, v) = arg
          (e, foldArg) = func(e, foldArg)
          tnargs[i] = (s, e, t, v)
        end
        ARG_TYPED_CALL(call.ref, targs, tnargs, call.call_scope)
      end

      TYPED_CALL(__)  => begin
        args = ArrayUtil.mapFoldSO(call.arguments, (e, a) -> func(e, a)[1], foldArg)
        TYPED_CALL(call.fn, call.ty, call.var, args, call.attributes)
      end

      UNTYPED_ARRAY_CONSTRUCTOR(__)  => begin
        (e, foldArg) = func(call.exp, foldArg)
        iters = mapFoldCallIteratorsShallow(call.iters, func, foldArg)
        UNTYPED_ARRAY_CONSTRUCTOR(e, iters)
      end

      TYPED_ARRAY_CONSTRUCTOR(__)  => begin
        (e, foldArg) = func(call.exp, foldArg)
        (iters,_) = mapFoldCallIteratorsShallow(call.iters, func, foldArg)
        TYPED_ARRAY_CONSTRUCTOR(call.ty, call.var, e, iters)
      end

      UNTYPED_REDUCTION(__)  => begin
         (e, foldArg) = func(call.exp, foldArg)
        iters = mapFoldCallIteratorsShallow(call.iters, func, foldArg)
        UNTYPED_REDUCTION(call.ref, e, iters)
      end

      TYPED_REDUCTION(__)  => begin
        (e, foldArg) = func(call.exp, foldArg)
        iters = mapFoldCallIteratorsShallow(call.iters, func, foldArg)
        (default_exp, foldArg) = mapFoldOptShallow(call.defaultExp, func, foldArg)
        oe = Util.tuple31(call.foldExp)
        if isSome(oe)
          (oe, foldArg) = mapFoldOptShallow(oe, func, foldArg)
          fold_exp = Util.applyTuple31(call.foldExp, (_) -> oe)
        else
          fold_exp = call.foldExp
        end
        TYPED_REDUCTION(call.fn, call.ty, call.var, e, iters, default_exp, fold_exp)
      end
    end
  end
  #=  Merge foldArg (value-based fold) with outRefArg (Ref-based tracking).
      Some match arms (e.g. TYPED_CALL) use mapFoldSO which discards the fold
      result, leaving foldArg stale at its initial value. The callbacks in
      those arms update outRefArg directly via side effects. Use && to
      preserve false from either source. =#
  outRefArg.x = foldArg && outRefArg.x
  outCall
end

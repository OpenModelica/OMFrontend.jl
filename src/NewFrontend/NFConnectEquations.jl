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

const EQ_ASSERT_STR = STRING_EXPRESSION("Connected constants/parameters must be equal")

"""
  The equations of the connection sets: potential sets equate their members, flow sets sum to zero, stream sets
  give the stream equations. The last set's equations come first (as before; the order is kept for stable output).
"""
function generateEquations(sets::Vector{<:List{<:CONNECTOR}})
  local perSet::Vector{List{Equation}} = Vector{List{Equation}}(undef, length(sets))
  local flowThreshold::Expression = REAL_EXPRESSION(1e-7)
  local cty::ConnectorType.TYPE
  local count::Int = 0
  setGlobalRoot(Global.isInStream, NONE())
  for (k, set) in enumerate(sets)
    cty = getSetType(set)
    perSet[k] = if isPotential(cty)
      generatePotentialEquations(set)
    elseif isFlow(cty)
      generateFlowEquations(set)
    elseif isStream(cty)
      generateStreamEquations(set, flowThreshold)
    else
      Error.addInternalError(
        getInstanceName() +
        " got connection set with invalid type '" +
        toDebugString(cty) +
        "': " +
        ListUtil.toString(set, toString, "", "{", ", ", "}", true),
        sourceInfo()
      )
      fail()
    end
    count += listLength(perSet[k])
  end
  #= The last set's equations first, each set's in order. =#
  local equations::Vector{Equation} = Vector{Equation}(undef, count)
  local i::Int = 0
  for k in length(sets):-1:1
    for eq in perSet[k]
      i += 1
      equations[i] = eq
    end
  end
  return equations
end

const CardinalityTable = NFCardinalityTable

function evaluateOperators(
  @nospecialize(exp::Expression),
  @nospecialize(sets::ConnectionSets.Sets),
  setsArray::Vector{<:List{<:CONNECTOR}},
  ctable::CardinalityTable.Table,
)::Expression
  local evalExp::Expression
  evalExp = begin
    local call::Call
    @match exp begin
      CALL_EXPRESSION(call = call) => begin
        begin
          @match call begin
            TYPED_CALL(__) => begin
              begin
                @match name(call.fn) begin
                  Absyn.IDENT("inStream") => begin
                    evaluateInStream(
                      toCref(Base.first(call.arguments)),
                      sets,
                      setsArray,
                      ctable,
                    )
                  end

                  Absyn.IDENT("actualStream") => begin
                    evaluateActualStream(
                      toCref(Base.first(call.arguments)),
                      sets,
                      setsArray,
                      ctable,
                    )
                  end

                  Absyn.IDENT("cardinality") => begin
                    CardinalityTable.evaluateCardinality(Base.first(call.arguments), ctable)
                  end

                  _ => begin
                    mapShallow(
                      exp,
                      (expArg) -> evaluateOperators(
                        expArg,
                        sets,
                        setsArray,
                        ctable,
                      ),
                    )
                  end
                end
              end
            end

            TYPED_REDUCTION(
              __,
            ) where {(contains(call.exp, isStreamCall))} =>
              begin
                evaluateOperatorReductionExp(exp, sets, setsArray, ctable)
              end

            TYPED_ARRAY_CONSTRUCTOR(
              __,
            ) where {(contains(call.exp, isStreamCall))} =>
              begin
                evaluateOperatorArrayConstructorExp(exp, sets, setsArray, ctable)
              end

            _ => begin
              mapShallow(
                exp,
                (@nospecialize(expArg::Expression),) -> evaluateOperators(
                  expArg,
                  sets,
                  setsArray,
                  ctable,
                ),
              )
            end
          end
        end
      end

      BINARY_EXPRESSION(
        exp1 = CREF_EXPRESSION(__),
        operator = OPERATOR(op = Op.MUL),
        exp2 = CALL_EXPRESSION(call = call && TYPED_CALL(__)),
      ) where {(AbsynUtil.isNamedPathIdent(name(call.fn), "actualStream"))} =>
        begin
          evaluateActualStreamMul(
            exp.exp1,
            Base.first(call.arguments),
            exp.operator,
            sets,
            setsArray,
            ctable,
          )
        end

      BINARY_EXPRESSION(
        exp1 = CALL_EXPRESSION(call = call && TYPED_CALL(__)),
        operator = OPERATOR(op = Op.MUL),
        exp2 = CREF_EXPRESSION(__),
      ) where {(AbsynUtil.isNamedPathIdent(name(call.fn), "actualStream"))} =>
        begin
          evaluateActualStreamMul(
            exp.exp2,
            Base.first(call.arguments),
            exp.operator,
            sets,
            setsArray,
            ctable,
          )
        end
      _ => begin
        mapShallow(
          exp,
          (@nospecialize(expArg::Expression),) ->
            evaluateOperators(expArg, sets, setsArray, ctable),
        )
      end
    end
  end
  #= inStream/actualStream can't handle non-literal subscripts, so reductions and array
     constructors containing such calls needs to be expanded to get rid of the iterators. =#
  return evalExp
end

function getSetType(set::List{<:CONNECTOR})::ConnectorType.TYPE
  local cty::ConnectorType.TYPE
  #=  All connectors in a set should have the same type, so pick the first.=#
  @match _cons(CONNECTOR(cty = cty), _) = set
  return cty
end

"""
  Generating the equations for a set of potential variables means equating all
  the components. For n components, this will give n-1 equations. For example,
  if the set contains the components X, Y.A and Z.B, the equations generated
  will be X = Y.A and X = Z.B.
"""
function generatePotentialEquations(elements::List{<:CONNECTOR})::List{Equation}
  local equations::List{Equation}
  local c1::CONNECTOR
  c1 = listHead(elements)
  if variability(c1) > Variability.PARAMETER
    equations = list(
      makeEqualityEquation(c1.name, c1.source, c2.name, c2.source)
      for c2 in listRest(elements)
    )
  else
    equations = list(
      makeEqualityAssert(c1.name, c1.source, c2.name, c2.source)
      for c2 in listRest(elements)
    )
  end
  return equations
end

function makeEqualityEquation(
  lhsCref::ComponentRef,
  lhsSource::SourceInfo,
  rhsCref::ComponentRef,
  rhsSource::SourceInfo,
)::Equation
  local equalityEq::Equation

  local source::SourceInfo
  source = lhsSource
  equalityEq = makeCrefEquality(lhsCref, rhsCref, EMPTY_NODE(), source)
  return equalityEq
end

function makeEqualityAssert(
  lhsCref::ComponentRef,
  lhsSource::SourceInfo,
  rhsCref::ComponentRef,
  rhsSource::SourceInfo,
)::Equation
  local equalityAssert::Equation

  local source::SourceInfo
  local lhs_exp::Expression
  local rhs_exp::Expression
  local exp::Expression
  local ty::ModelicaType

  @assign source = lhsSource
  @assign ty = getComponentType(lhsCref)
  @assign lhs_exp = fromCref(lhsCref)
  @assign rhs_exp = fromCref(rhsCref)
  if isReal(ty)
    @assign exp =
      BINARY_EXPRESSION(lhs_exp, makeSub(ty), rhs_exp)
    @assign exp = CALL_EXPRESSION(makeTypedCall(
      NFBuiltinFuncs.ABS_REAL,
      Expression[exp],
      variability(exp),
    ))
    @assign exp = RELATION_EXPRESSION(
      exp,
      makeLessEq(ty),
      REAL_EXPRESSION(0.0),
    )
  else
    @assign exp =
      RELATION_EXPRESSION(lhs_exp, makeEqual(ty), rhs_exp)
  end
  #= Modelica doesn't allow == for Reals, so to keep the flat Modelica
     somewhat valid we use 'abs(lhs - rhs) <= 0' instead.
     For any other type, generate assertion for 'lhs == rhs'. =#
  @assign equalityAssert =
    EQUATION_ASSERT(exp, EQ_ASSERT_STR, NFBuiltin.ASSERTIONLEVEL_ERROR, source)
  return equalityAssert
end

function generateFlowEquations(elements::List{<:CONNECTOR})::List{Equation}
  local equations::List{Equation}
  local c::CONNECTOR
  local c_rest::List{CONNECTOR}
  local src::SourceInfo
  local sum::Expression
  local iterators::List{InstNode} = nil
  @match _cons(c, c_rest) = elements
  src = c.source
  #= Handle arrays =#
  if isArray(c)
    (iterators, ranges, subs) = makeIterators(c.name, arrayDims(c.ty))
    subs = listReverseInPlace(subs)
    @match c <| c_rest = list(addSubscripts(subs, e) for e in elements)
  end

  if listEmpty(c_rest)
    sum = fromCref(c.name)
  else
    sum = makeFlowExp(c)
    for e in c_rest
      sum = BINARY_EXPRESSION(
        sum,
        makeAdd(TYPE_REAL()),
        makeFlowExp(e),
      )
    end
  end
  equations = list(EQUATION_EQUALITY(sum, REAL_EXPRESSION(0.0), arrayElementType(c.ty), src))
  while ! listEmpty(iterators)
    local forEq = EQUATION_FOR(listHead(iterators),
                               SOME(listHead(ranges)),
                               listArray(equations),
                               #= TODO: Investigate EMPTY_NODE(), John 2024 march=#
                               src)
    #= Unroll the for loop using flattenEquation if we are scalarizing the model =#
    equations = if Flags.isSet(Flags.FRONTEND_SCALARIZE)
      arrayList(unrollFlowForLoop(forEq, COMPONENT_REF_EMPTY(), Equation[]))
    else
      list(forEq)
    end
    iterators = listRest(iterators)
    ranges = listRest(ranges)
  end

  return equations
end

"""
   Unrolls an equational for-loop for flow equations.
   This is special since it forces the iterator replacements.
   It differs from the normal unroll procedure in that it replaces all \$1 call with the correct value.
"""
function unrollFlowForLoop(forLoop::Equation,
                           prefix::ComponentRef,
                           equations::Vector{Equation})
  local body::Vector{Equation}
  local unrolled_body::Vector{Equation}
  local range::Expression
  local range_iter::RangeIterator
  local val::Expression
  local bodies::Vector{Vector{Equation}} = Vector{Equation}[]
  @match EQUATION_FOR(iterator = iter, range = SOME(range), body = body) = forLoop
  range = flattenExp(range, prefix)
  range = evalExp(range, EVALTARGET_RANGE(Equation_info(forLoop)))
  range_iter = RangeIterator_fromExp(range)
  while hasNext(range_iter)
    (range_iter, val) = next(range_iter)
    unrolled_body = Equation[]
    for eq in body
      teq = mapExp(eq, (exp) -> replaceFlowIterator(exp, forLoop.iterator, val))
      push!(unrolled_body, teq)
    end
    push!(bodies, unrolled_body)
  end
  #= The last iteration's equations first, then `equations`. =#
  local out::Vector{Equation} = Equation[]
  for k in length(bodies):-1:1
    append!(out, bodies[k])
  end
  append!(out, equations)
  return out
end

"""
Replaces flow iterators.
Note, this assumes that the encompassing for loop is constructed in a certain way.
@author johti17
"""
function replaceFlowIterator(@nospecialize(exp::Expression),
                             iterator::InstNode,
                             @nospecialize(iteratorValue::Expression))
  local res = if exp isa CREF_EXPRESSION
    exp = CREF_EXPRESSION(exp.ty, _replaceIteratorInCref(exp.cref, iterator, iteratorValue))
    exp
  elseif exp isa BINARY_EXPRESSION
    expExp1 = replaceFlowIterator(exp.exp1,
                                  iterator,
                                  iteratorValue)
    expExp2 = replaceFlowIterator(exp.exp2,
                                  iterator,
                                  iteratorValue)
    BINARY_EXPRESSION(expExp1, exp.operator, expExp2)
  elseif exp isa UNARY_EXPRESSION
    expExp= replaceFlowIterator(exp.exp,
                                iterator,
                                iteratorValue)
    UNARY_EXPRESSION(exp.operator, expExp)
  else
    exp
  end
  return res
end

"""
Walk a COMPONENT_REF_CREF chain and replace any subscript that references
the given iterator node with a concrete SUBSCRIPT_INDEX(iteratorValue).
"""
function _replaceIteratorInCref(cref::ComponentRef, iterator::InstNode,
                                @nospecialize(iteratorValue::Expression))::ComponentRef
  if !(isvariant(cref, COMPONENT_REF_CREF))
    return cref
  end
  local newSubs = Subscript[]
  local changed = false
  for sub in cref.subscripts
    if sub isa SUBSCRIPT_INDEX && sub.index isa CREF_EXPRESSION
      subNode = sub.index.cref
      if isvariant(subNode, COMPONENT_REF_CREF) && subNode.node === iterator
        push!(newSubs, SUBSCRIPT_INDEX(iteratorValue))
        changed = true
        continue
      end
    end
    push!(newSubs, sub)
  end
  local newRestCref = _replaceIteratorInCref(cref.restCref, iterator, iteratorValue)
  if changed || newRestCref !== cref.restCref
    return COMPONENT_REF_CREF(cref.node, list(newSubs...), cref.ty, cref.origin, newRestCref)
  end
  return cref
end

"""
  Creates an expression from a connector element, which is the element itself
  if it's an inside connector, or the element negated if it's outside.
"""
function makeFlowExp(element::CONNECTOR)::Expression
  local exp::Expression
  local face::Face

  @assign exp = fromCref(element.name)
  #= TODO: Remove unnecessary variable 'face' once #4502 is fixed. =#
  @assign face = element.face
  if face == FACE_OUTSIDE
    @assign exp =
      UNARY_EXPRESSION(makeUMinus(TYPE_REAL()), exp)
  end
  return exp
end

"""Generates the equations for a stream connection set."""
function generateStreamEquations(
  elements::List{<:CONNECTOR},
  flowThreshold::Expression,
)::List{Equation}

  local cr1::ComponentRef
  local cr2::ComponentRef
  local src::SourceInfo
  local src1::SourceInfo
  local cref1::Expression
  local cref2::Expression
  local e1::Expression
  local e2::Expression
  local inside::List{CONNECTOR}
  local outside::List{CONNECTOR}
  local f1::Face
  local f2::Face
  #= Unconnected stream connector, do nothing. =#
  @match elements begin
    CONNECTOR(face = f1) <| nil() where {(f1 == FACE_INSIDE)} => begin
      nil
    end

    CONNECTOR(face = f1) <|
    CONNECTOR(face = f2) <| nil() where {(f1 == FACE_INSIDE && f2 == FACE_INSIDE)} => begin
      nil
    end

    CONNECTOR(name = cr1, face = f1, source = src1) <|
    CONNECTOR(name = cr2, face = f2, source = src2) <|
    nil() where {(f1 == FACE_OUTSIDE && f2 == FACE_OUTSIDE)} => begin
      #= Both inside, do nothing.
         Both outside:
         cr1 = inStream(cr2);
         cr2 = inStream(cr1); =#
      @assign cref1 = fromCref(cr1)
      @assign cref2 = fromCref(cr2)
      @assign e1 = makeInStreamCall(cref2)
      @assign e2 = makeInStreamCall(cref1)
      @assign src = src1
      list(
        EQUATION_EQUALITY(cref1, e1, TYPE_REAL(), src),
        EQUATION_EQUALITY(cref2, e2, TYPE_REAL(), src),
      )
    end

    CONNECTOR(name = cr1, source = src1) <|
    CONNECTOR(name = cr2, source = src2) <| nil() => begin
      #= One inside, one outside:
         cr1 = cr2; =#
      @assign src = src1
      list(EQUATION_CREF_EQUALITY(cr1, cr2, src))
    end

    _ => begin
      #= The general case with N inside connectors and M outside: =#
       (outside, inside) =
        ListUtil.splitOnTrue(elements, isOutside, CONNECTOR)
      streamEquationGeneral(outside, inside, flowThreshold)
    end
  end
end

"""Generates an equation for an outside stream connector element."""
function streamEquationGeneral(
  outsideElements::List{<:CONNECTOR},
  insideElements::List{<:CONNECTOR},
  flowThreshold::Expression,
)::List{Equation}
  local equations::List{Equation} = nil

  local outside::List{CONNECTOR}
  local cref_exp::Expression
  local res::Expression
  local src::SourceInfo

  for e in outsideElements
    @assign cref_exp = fromCref(e.name)
    @assign outside = removeStreamSetElement(e.name, outsideElements)
    @assign res = streamSumEquationExp(outside, insideElements, flowThreshold)
    src = e.source
    @assign equations =
      _cons(EQUATION_EQUALITY(cref_exp, res, TYPE_REAL(), src), equations)
  end
  return equations
end

"""
  Generates the sum expression used by stream connector equations, given M
  outside connectors and N inside connectors:

  (sum(max(-flow_exp[i], eps) * stream_exp[i] for i in N) +
  sum(max( flow_exp[i], eps) * inStream(stream_exp[i]) for i in M)) /
  (sum(max(-flow_exp[i], eps) for i in N) +
  sum(max( flow_exp[i], eps) for i in M))

  where eps = inFlowThreshold.
"""
function streamSumEquationExp(
  outsideElements::List{<:CONNECTOR},
  insideElements::List{<:CONNECTOR},
  flowThreshold::Expression,
)::Expression
  local sumExp::Expression

  local outside_sum1::Expression
  local outside_sum2::Expression
  local inside_sum1::Expression
  local inside_sum2::Expression

  if listEmpty(outsideElements)
    @assign inside_sum1 = sumMap(insideElements, sumInside1, flowThreshold)
    @assign inside_sum2 = sumMap(insideElements, sumInside2, flowThreshold)
    @assign sumExp = BINARY_EXPRESSION(
      inside_sum1,
      makeDiv(TYPE_REAL()),
      inside_sum2,
    )
  elseif listEmpty(insideElements)
    @assign outside_sum1 = sumMap(outsideElements, sumOutside1, flowThreshold)
    @assign outside_sum2 = sumMap(outsideElements, sumOutside2, flowThreshold)
    @assign sumExp = BINARY_EXPRESSION(
      outside_sum1,
      makeDiv(TYPE_REAL()),
      outside_sum2,
    )
  else
    @assign outside_sum1 = sumMap(outsideElements, sumOutside1, flowThreshold)
    @assign outside_sum2 = sumMap(outsideElements, sumOutside2, flowThreshold)
    @assign inside_sum1 = sumMap(insideElements, sumInside1, flowThreshold)
    @assign inside_sum2 = sumMap(insideElements, sumInside2, flowThreshold)
    @assign sumExp = BINARY_EXPRESSION(
      BINARY_EXPRESSION(
        outside_sum1,
        makeAdd(TYPE_REAL()),
        inside_sum1,
      ),
      makeDiv(TYPE_REAL()),
      BINARY_EXPRESSION(
        outside_sum2,
        makeAdd(TYPE_REAL()),
        inside_sum2,
      ),
    )
  end
  #= No outside components.
     No inside components.
     Both outside and inside components. =#
  return sumExp
end

"""
  Creates a sum expression by applying the given function on the list of
  elements and summing up the resulting expressions.
"""
function sumMap(
  elements::List{<:CONNECTOR},
  func::FuncType,
  flowThreshold::Expression,
)::Expression
  local exp::Expression

  @assign exp = func(listHead(elements), flowThreshold)
  for e in listRest(elements)
    @assign exp = BINARY_EXPRESSION(
      func(e, flowThreshold),
      makeAdd(TYPE_REAL()),
      exp,
    )
  end
  return exp
end

"""Returns the stream and flow component in a stream set element as expressions."""
function streamFlowExp(element::CONNECTOR)::Tuple{Expression, Expression}
  local flowExp::Expression
  local streamExp::Expression

  local stream_cr::ComponentRef

  @assign stream_cr = name(element)
  @assign streamExp = fromCref(stream_cr)
  @assign flowExp = fromCref(associatedFlowCref(stream_cr))
  return (streamExp, flowExp)
end

"""Returns the flow component in a stream set element as an expression."""
function flowExp(element::CONNECTOR)::Expression
  local flowExp::Expression

  local flow_cr::ComponentRef

  @assign flow_cr = associatedFlowCref(name(element))
  @assign flowExp = fromCref(flow_cr)
  return flowExp
end

"""
  Helper function to streamSumEquationExp. Returns the expression
  max(flow_exp, eps) * inStream(stream_exp)
  given a stream set element.
"""
function sumOutside1(element::CONNECTOR, @nospecialize(flowThreshold::Expression))::Expression
  local exp::Expression

  local stream_exp::Expression
  local flow_exp::Expression

   (stream_exp, flow_exp) = streamFlowExp(element)
  @assign exp = BINARY_EXPRESSION(
    makePositiveMaxCall(flow_exp, element, flowThreshold),
    makeMul(TYPE_REAL()),
    makeInStreamCall(stream_exp),
  )
  return exp
end

"""
  Helper function to streamSumEquationExp. Returns the expression
  max(-flow_exp, eps) * stream_exp
  given a stream set element.
"""
function sumInside1(element::CONNECTOR, @nospecialize(flowThreshold::Expression))::Expression
  local exp::Expression

  local stream_exp::Expression
  local flow_exp::Expression

   (stream_exp, flow_exp) = streamFlowExp(element)
  @assign flow_exp =
    UNARY_EXPRESSION(makeUMinus(TYPE_REAL()), flow_exp)
  @assign exp = BINARY_EXPRESSION(
    makePositiveMaxCall(flow_exp, element, flowThreshold),
    makeMul(TYPE_REAL()),
    stream_exp,
  )
  return exp
end

"""
  Helper function to streamSumEquationExp. Returns the expression
  max(flow_exp, eps)
  given a stream set element.
"""
function sumOutside2(element::CONNECTOR, @nospecialize(flowThreshold::Expression))::Expression
  local exp::Expression

  local flow_exp::Expression

  @assign flow_exp = flowExp(element)
  @assign exp = makePositiveMaxCall(flow_exp, element, flowThreshold)
  return exp
end

"""
  Helper function to streamSumEquationExp. Returns the expression
  max(-flow_exp, eps)
  given a stream set element.
"""
function sumInside2(element::CONNECTOR, @nospecialize(flowThreshold::Expression))::Expression
  local exp::Expression

  local flow_exp::Expression

  @assign flow_exp = flowExp(element)
  @assign flow_exp =
    UNARY_EXPRESSION(makeUMinus(TYPE_REAL()), flow_exp)
  @assign exp = makePositiveMaxCall(flow_exp, element, flowThreshold)
  return exp
end

"""Creates an inStream call expression."""
function makeInStreamCall(@nospecialize(streamExp::Expression))::Expression
  local inStreamCall::Expression

  @assign inStreamCall = CALL_EXPRESSION(makeTypedCall(
    NFBuiltinFuncs.IN_STREAM,
    Expression[streamExp],
    variability(streamExp),
  ))
  return inStreamCall
end

"""Generates a max(flow_exp, eps) call."""
function makePositiveMaxCall(
  flowExp::Expression,
  element::CONNECTOR,
  flowThreshold::Expression,
)::Expression
  local positiveMaxCall::Expression

  local flow_node::InstNode
  local nominal_oexp::Option{Expression}
  local nominal_exp::Expression
  local flow_threshold::Expression

  @assign flow_node =
    node(associatedFlowCref(name(
      element,
    )))
  @assign nominal_oexp =
    lookupAttributeValue("nominal", getClass(flow_node))
  if isSome(nominal_oexp)
    @match SOME(nominal_exp) = nominal_oexp
    @assign nominal_exp = getBindingExp(nominal_exp)
    @assign flow_threshold = BINARY_EXPRESSION(
      flowThreshold,
      makeMul(TYPE_REAL()),
      nominal_exp,
    )
  else
    @assign flow_threshold = flowThreshold
  end
  @assign positiveMaxCall = CALL_EXPRESSION(makeTypedCall(
    NFBuiltinFuncs.POSITIVE_MAX_REAL,
    Expression[flowExp, flow_threshold],
    variability(element),
  ))
  setGlobalRoot(Global.isInStream, SOME(true))
  return positiveMaxCall
end

function isStreamCall(@nospecialize(exp::Expression))::Bool
  @match exp begin
    CALL_EXPRESSION(__) => begin
      begin
        @match name(typedFunction(exp.call)) begin
          Absyn.IDENT("inStream") => begin
            true
          end
          Absyn.IDENT("actualStream") => begin
            true
          end
          _ => begin
            false
          end
        end
      end
    end
    _ => begin
      false
    end
  end
end

function evaluateOperatorReductionExp(
  exp::Expression,
  sets::ConnectionSets.Sets,
  setsArray::Vector{<:List{<:CONNECTOR}},
  ctable::CardinalityTable.Table,
)::Expression
  local outExp::Expression

  local call::Call
  local ty::ModelicaType
  local arg::Expression
  local iter_exp::Expression
  local iters::List{Tuple{InstNode, Expression}} = nil
  local iter_node::InstNode

  @assign outExp = begin
    @match exp begin
      CALL_EXPRESSION(call = call && TYPED_REDUCTION(__)) => begin
        @assign ty = typeOf(call.exp)
        for iter in call.iters
           (iter_node, iter_exp) = iter
          if variability(component(iter_node)) >
             Variability.PARAMETER
            print("Iteration range in reduction containing connector operator calls must be a parameter expression.")
            fail()
          end
          @assign iter_exp = evalExp(iter_exp)
          @assign ty = liftArrayLeftList(
            ty,
            arrayDims(typeOf(iter_exp)),
          )
          @assign iters = _cons((iter_node, iter_exp), iters)
        end
        @assign iters = listReverseInPlace(iters)
        #= expandArrayConstructor returns (exp, expanded). =#
        (arg, _) = expandArrayConstructor(call.exp, ty, iters)
        CALL_EXPRESSION(makeTypedCall(
          call.fn,
          Expression[arg],
          call.var,
          call.ty,
        ))
      end
    end
  end
  @assign outExp = evaluateOperators(outExp, sets, setsArray, ctable)
  return outExp
end

function evaluateOperatorArrayConstructorExp(
  exp::Expression,
  sets::ConnectionSets.Sets,
  setsArray::Vector{<:List{<:CONNECTOR}},
  ctable::CardinalityTable.Table,
)::Expression
  local evalExp::Expression

  local expanded::Bool

   (evalExp, expanded) = expand(exp)
  if !expanded
    Error.addInternalError(
      getInstanceName() +
      " failed to expand call containing stream operator: " +
      toString(exp),
      sourceInfo(),
    )
  end
  @assign evalExp = evaluateOperators(evalExp, sets, setsArray, ctable)
  return evalExp
end

"""Evaluates the inStream operator with the given cref as argument."""
function evaluateInStream(
  cref::ComponentRef,
  sets::ConnectionSets.Sets,
  setsArray::Vector{<:List{<:CONNECTOR}},
  ctable::CardinalityTable.Table,
)::Expression
  local exp::Expression

  local c::CONNECTOR
  local sl::List{CONNECTOR}
  local set::Int

  @assign c = CONNECTOR(
    cref,
    TYPE_UNKNOWN(),
    FACE_INSIDE,
    ConnectorType.STREAM,
    AbsynUtil.dummyInfo,
  )
  #= A connector in no set (unconnected): itself. A bare catch here hid that
     findSetArrayIndex was not ported: every inStream was its own connector
     (pipe.b.h_outflow = pipe.a.h_outflow, not the source's). =#
  @assign set = ConnectionSets.findSetArrayIndex(c, sets)
  @assign sl = set > 0 ? arrayGet(setsArray, set) : list(c)
  @assign exp = generateInStreamExp(
    cref,
    sl,
    sets,
    setsArray,
    ctable,
    Flags.getConfigReal(Flags.FLOW_THRESHOLD),
  )
  return exp
end

"""
  Helper function to evaluateInStream. Generates an expression for inStream
  given a connection set.
"""
function generateInStreamExp(
  streamCref::ComponentRef,
  streams::List{<:CONNECTOR},
  sets::ConnectionSets.Sets,
  setsArray::Vector{<:List{<:CONNECTOR}},
  ctable::CardinalityTable.Table,
  flowThreshold::AbstractFloat,
)::Expression
  local exp::Expression

  local reducedStreams::List{CONNECTOR}
  local inside::List{CONNECTOR}
  local outside::List{CONNECTOR}
  local cr::ComponentRef
  local f1::Face
  local f2::Face

  @assign reducedStreams = list(s for s in streams if !isZeroFlowMinMax(s, streamCref))
  @assign exp = begin
    @match reducedStreams begin
      CONNECTOR(face = f1) <| nil() where {(f1 == FACE_INSIDE)} => begin
        fromCref(streamCref)
      end

      CONNECTOR(face = f1) <|
      CONNECTOR(face = f2) <| nil() where {(f1 == FACE_INSIDE && f2 == FACE_INSIDE)} => begin
        #= Unconnected stream connector:
           inStream(c) = c;
           Two inside connected stream connectors:
           inStream(c1) = c2;
           inStream(c2) = c1; =#
        @match CONNECTOR(name = cr) <| nil() =
          removeStreamSetElement(streamCref, reducedStreams)
        fromCref(cr)
      end

      CONNECTOR(face = f1) <|
      CONNECTOR(face = f2) <| nil() where {(f1 != f2)} => begin
        #= One inside, one outside connected stream connector:
           inStream(c1) = inStream(c2); =#
        @match CONNECTOR(name = cr) <| nil() =
          removeStreamSetElement(streamCref, reducedStreams)
        evaluateInStream(cr, sets, setsArray, ctable)
      end

      _ => begin
        #= The general case: =#
         (outside, inside) =
          ListUtil.splitOnTrue(reducedStreams, isOutside, CONNECTOR)
        @assign inside = removeStreamSetElement(streamCref, inside)
        @assign exp = streamSumEquationExp(
          outside,
          inside,
          REAL_EXPRESSION(flowThreshold),
        )
        #= Evaluate any inStream calls that were generated. =#
        @assign exp = evaluateOperators(exp, sets, setsArray, ctable)
        exp
      end
    end
  end
  return exp
end

"""Returns true if the given flow attribute of a connector is zero."""
function isZeroFlowMinMax(conn::CONNECTOR, streamCref::ComponentRef)::Bool
  local isZero::Bool

  if isEqual(streamCref, conn.name)
    @assign isZero = false
  elseif isOutside(conn)
    @assign isZero = isZeroFlow(conn, "max")
  else
    @assign isZero = isZeroFlow(conn, "min")
  end
  return isZero
end

"""Returns true if the given flow attribute of a connector is zero."""
function isZeroFlow(element::CONNECTOR, attr::String)::Bool
  #= `zeroFlow`: a local `isZero` shadowed the function it called (UndefVarError). =#
  local zeroFlow::Bool

  local attr_oexp::Option{Expression}
  local flow_exp::Expression
  local attr_exp::Expression
  local flow_node::InstNode

  @assign flow_exp = flowExp(element)
  @assign flow_node =
    node(toCref(flow_exp))
  @assign attr_oexp = lookupAttributeValue(attr, getClass(flow_node))
  if isSome(attr_oexp)
    @match SOME(attr_exp) = attr_oexp
    #= Evaluated, as OMC's Ceval.evalExp: `min = if allowFlowReversal then -inf else 0`. =#
    local e = getBindingExp(attr_exp)
    @assign zeroFlow = isZero(isLiteral(e) ? e : evalExp(e))
  else
    @assign zeroFlow = false
  end
  return zeroFlow
end

"""
  This function evaluates the actualStream operator for a component reference,
  given the connection sets.
"""
function evaluateActualStream(
  streamCref::ComponentRef,
  sets::ConnectionSets.Sets,
  setsArray::Vector{<:List{<:CONNECTOR}},
  ctable::CardinalityTable.Table,
  mulCref::Option{<:ComponentRef} = NONE(),
)::Expression
  local exp::Expression

  local flow_dir::Int
  local flow_cr::ComponentRef
  local flow_exp::Expression
  local stream_exp::Expression
  local instream_exp::Expression
  local op::OPERATOR

  @assign flow_cr = associatedFlowCref(streamCref)
  @assign flow_dir = evaluateFlowDirection(flow_cr)
  #= Select a branch if we know the flow direction, otherwise generate the whole
     if-equation. =#
  if flow_dir == 1
    @assign exp = evaluateInStream(streamCref, sets, setsArray, ctable)
  elseif flow_dir == (-1)
    @assign exp = fromCref(streamCref)
  else
    @assign flow_exp = fromCref(flow_cr)
    @assign stream_exp = fromCref(streamCref)
    @assign instream_exp = evaluateInStream(streamCref, sets, setsArray, ctable)
    @assign op =
      makeGreater(nodeType(flow_cr))
    @assign exp = IF_EXPRESSION(
      RELATION_EXPRESSION(flow_exp, op, REAL_EXPRESSION(0.0)),
      instream_exp,
      stream_exp,
    )
    if isNone(mulCref) ||
       !isEqual(flow_cr, Util.getOption(mulCref))
      @assign exp = makeSmoothCall(exp, 0)
    end
  end
  #= actualStream(stream_var) = smooth(0, if flow_var > 0 then inStream(stream_var)
     else stream_var); =#
  return exp
end

"""
  Handles expressions on the form flowCref * actualStream(streamCref) where
  flowCref is associated with streamCref.
"""
function evaluateActualStreamMul(
  crefExp::Expression,
  actualStreamArg::Expression,
  op::OPERATOR,
  sets::ConnectionSets.Sets,
  setsArray::Vector{<:List{<:CONNECTOR}},
  ctable::CardinalityTable.Table,
)::Expression
  local outExp::Expression

  local e1::Expression
  local e2::Expression
  local cr::ComponentRef

  e1 = evaluateOperators(crefExp, sets, setsArray, ctable)
  @match CREF_EXPRESSION(cref = cr) = e1
  @assign e2 = evaluateActualStream(
    toCref(actualStreamArg),
    sets,
    setsArray,
    ctable,
    SOME(cr),
  )
  @assign outExp = BINARY_EXPRESSION(e1, op, e2)
  #= Wrap the expression in smooth if the result would be flow_cr * (if flow_cr > 0 then ...) =#
  @assign outExp = begin
    @match e2 begin
      IF_EXPRESSION(__) => begin
        makeSmoothCall(outExp, 0)
      end

      _ => begin
        outExp
      end
    end
  end
  return outExp
end

function evaluateFlowDirection(flowCref::ComponentRef)::Int
  local direction::Int

  local flow_cls::Class
  local omin::Option{Expression}
  local omax::Option{Expression}
  local min_val::AbstractFloat
  local max_val::AbstractFloat

  @assign flow_cls = getClass(node(flowCref))
  @assign omin = lookupAttributeValue("min", flow_cls)
  @assign omin =
    simplifyOpt(Util.applyOption(omin, getBindingExp))
  @assign omax = lookupAttributeValue("max", flow_cls)
  @assign omax =
    simplifyOpt(Util.applyOption(omax, getBindingExp))
  @assign direction = begin
    @match (omin, omax) begin
      (NONE(), NONE()) => begin
        0
      end

      (SOME(REAL_EXPRESSION(min_val)), NONE()) => begin
        if min_val >= 0
          1
        else
          0
        end
      end

      (NONE(), SOME(REAL_EXPRESSION(max_val))) => begin
        if max_val <= 0
          -1
        else
          0
        end
      end

      (
        SOME(REAL_EXPRESSION(min_val)),
        SOME(REAL_EXPRESSION(max_val)),
      ) => begin
        if min_val >= 0 && max_val >= min_val
          1
        elseif (max_val <= 0 && min_val <= max_val)
          -1
        else
          0
        end
      end

      _ => begin
        0
      end
    end
  end
  #= No attributes, flow direction can't be decided.
     Flow is positive if min is positive.
     Flow is negative if max is negative.
     Flow is positive if both min and max are positive, negative if they are
     both negative, otherwise undecideable.
     Flow is undecideable if either attribute is not a constant Real value. =#
  return direction
end

""" Creates a smooth(order, arg) call. """
function makeSmoothCall(@nospecialize(arg::Expression), order::Int)::Expression
  local callExp::Expression

  @assign callExp = CALL_EXPRESSION(makeTypedCall(
    NFBuiltinFuncs.SMOOTH,
    Expression[INTEGER_EXPRESSION(order), arg],
    variability(arg),
  ))
  return callExp
end

""" This function removes the given cref from a connection set. """
function removeStreamSetElement(
  cref::ComponentRef,
  elements::List{<:CONNECTOR},
)::List{CONNECTOR}

  (elements, _) = ListUtil.deleteMemberOnTrue(cref, elements, compareCrefStreamSet, CONNECTOR)
  return elements
end

"""
  Helper function to removeStreamSetElement. Checks if the cref in a stream set
  element matches the given cref.
"""
function compareCrefStreamSet(cref::ComponentRef, element::CONNECTOR)::Bool
  local matches::Bool

  @assign matches = isEqual(cref, element.name)
  return matches
end

"""
  Returns the flow cref that's declared in the same connector as the given
  stream cref.
"""
function associatedFlowCref(streamCref::ComponentRef)::ComponentRef
  local flowCref::ComponentRef

  local ty::ModelicaType
  local rest_cr::ComponentRef
  local flow_node::InstNode

  @match COMPONENT_REF_CREF(ty = ty, restCref = rest_cr) = streamCref
  @assign flowCref = begin
    @match arrayElementType(ty) begin
      TYPE_COMPLEX(complexTy = COMPLEX_CONNECTOR(flows = flow_node <| nil())) => begin
        prefixCref(
          flow_node,
          getType(flow_node),
          nil,
          streamCref,
        )
      end

      _ => begin
        associatedFlowCref(rest_cr)
      end
    end
  end
  #= A connector with a single flow, append the flow node to the cref and return it.
     Otherwise, remove the first part of the cref and try again. =#
  return flowCref
end

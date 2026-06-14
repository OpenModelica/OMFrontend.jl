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

function addBindingExpParent(@nospecialize(parent::InstNode),
                             @nospecialize(exp::Expression))
  local modifiedExp = if exp isa BINDING_EXP
    #= Check this. =#
    BINDING_EXP(exp.exp, exp.expType, exp.bindingType, _cons(parent, exp.parents), exp.isEach)
  else
    exp
  end
  return modifiedExp
end

mutable struct MaxProp
  count::Int
  exp::Expression
end

function mostPropagatedSubExp_traverser(@nospecialize(exp::Expression), mp::MaxProp)
  if isBindingExp(exp)
    local exp_prop = propagatedDimCount(exp)
    if exp_prop > mp.count
      mp.count = exp_prop
      mp.exp = exp
    end
  end
  mp
end

"""
Returns the most propagated subexpression in either of the two given
expressions, as well as the number of dimensions it's been propagated
through. Returns the first expression and -1 as the number of dimensions
if neither expression contains any binding expressions.
"""
function mostPropagatedSubExpBinary(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression)) ::Tuple{Expression, Int}
  #=  TODO: Optimize this, there's no need to check for bindings in e.g. literal arrays. =#
  local mp = MaxProp(-1, exp1)
  fold(exp1, mostPropagatedSubExp_traverser, mp)
  fold(exp2, mostPropagatedSubExp_traverser, mp)
  (mp.exp, mp.count)
end

"""
Returns the most propagated subexpression of the given expression, as well
as the number of dimensions it's been propagated through. Returns the
expression itself and -1 as the number of dimensions if it doesn't contain
any binding expressions.
"""
function mostPropagatedSubExp(@nospecialize(exp::Expression))
  #=  TODO: Optimize this, there's no need to check for bindings in e.g. literal arrays. =#
  local mp = MaxProp(-1, exp)
  fold(exp, mostPropagatedSubExp_traverser, mp)
  (mp.exp, mp.count)
end

function bindingExpMap4(@nospecialize(exp::Expression), subs::List{<:Subscript}) ::Expression
  local outExp::Expression
  outExp = begin
    local prop_count::Int
    local prop_subs::List{Subscript}
    @match exp begin
      BINDING_EXP(__)  => begin
        prop_count = propagatedDimCount(exp)
        prop_subs = ListUtil.lastN(subs, prop_count)
        applySubscripts(prop_subs, exp.exp)
      end
      _  => begin
        exp
      end
    end
  end
  outExp
end

function bindingExpMap3(@nospecialize(exp::Expression), evalFunc::EvalFunc, subs::List{<:Subscript})
  local result::Expression
  local e1::Expression
  local e2::Expression
  local op::Operator
   result = map(exp, @closure (x) -> bindingExpMap4(x, subs)) #TODO?
   result = evalFunc(result)
  result
end

function bindingExpMap2(@nospecialize(exp::Expression), evalFunc::EvalFunc, mostPropagatedCount::Int, @nospecialize(mostPropagatedExp::Expression))
  local result::Expression
  local exp_ty::M_Type
  local bind_ty::M_Type
  local dims::List{Dimension}
  local e::Expression
  local parents::List{InstNode}
  local is_each::Bool
  @match BINDING_EXP(exp = e, expType = exp_ty, parents = parents, isEach = is_each) = mostPropagatedExp
  dims = ListUtil.firstN(arrayDims(exp_ty), mostPropagatedCount)
  func = @closure (x, y) -> bindingExpMap3(x, evalFunc, y)
  result = vectorize(exp, dims, func)
  (exp_ty, bind_ty) = bindingExpType(result, mostPropagatedCount)
  result = BINDING_EXP(result, exp_ty, bind_ty, parents, is_each)
  result
end

"""Calls the given function on each element of a binding expression."""
function bindingExpMap(@nospecialize(exp::Expression), evalFunc::EvalFunc)
  local result::Expression
  local max_prop_exp::Expression
  local max_prop_count::Int
  (max_prop_exp, max_prop_count) = mostPropagatedSubExp(exp)
  if max_prop_count >= 0
    result = bindingExpMap2(exp, evalFunc, max_prop_count, max_prop_exp)
  else
    result = evalFunc(exp)
  end
  result
end

"""
 Constructs an array with the given dimensions by calling the given
 function on the given expression for each combination of subscripts defined
 by the dimensions.
"""
function vectorize(@nospecialize(exp::Expression), dims::List{<:Dimension}, func::FuncT, accumSubs::List{<:Subscript} = nil)
  local outExp::Expression
  local iter::RangeIterator
  local dim::Dimension
  local rest_dims::List{Dimension}
  local expl::Vector{Expression}
  local e::Expression
  if listEmpty(dims)
    local tmp = accumSubs
    accumSubs = nil
    while tmp !== nil
      @match Cons{Subscript}(t, tmp) = tmp
      accumSumbs = Cons{Subscript}{t, accumSubs}
    end
     outExp = func(exp, accumSubs)
  else
    expl = Expression[]
    @match Cons{Dimensions}(dim, rest_dims) = dims
    iter = fromDim(dim)
    while hasNext(iter)
      (iter, e) = next(iter)
      e = vectorize(exp, rest_dims, func, Cons{Subscript}(SUBSCRIPT_INDEX(e), accumSubs))
      push!(expl, e)
    end
    outExp = makeExpArray(expl)
  end
  outExp
end

"""
  Calculates the expression type and binding type of an expression given the
  number of dimensions it's been propagated through.
"""
function bindingExpType(@nospecialize(exp::Expression), propagatedDimCount::Int)
  local bindingType::M_Type
  local expType::M_Type
  expType = typeOf(exp)
  bindingType = if propagatedDimCount > 0
    unliftArrayN(propagatedDimCount, expType)
  else
    expType
  end
  (expType, bindingType)
end

"""
  Returns the number of dimensions a binding expression has been propagated
  through.
"""
function propagatedDimCount(@nospecialize(exp::Expression)) ::Int
  local dimCount::Int
  dimCount = begin
    @match exp begin
      BINDING_EXP(isEach = false)  => begin
        if isKnown(exp.expType)
          dimCount = dimensionCount(exp.expType) - dimensionCount(exp.bindingType)
        else
          dimCount = 0
          for parent in listRest(exp.parents)
            dimCount = dimCount + dimensionCount(getType(parent))
          end
        end
        dimCount
      end
      _  => begin
        0
      end
    end
  end
  dimCount
end

"""
  Replaces all binding expressions in the given expression with the
  expressions they contain.
"""
function stripBindingInfo(@nospecialize(exp::Expression)) ::Expression
  local outExp::Expression
  outExp = map(exp, getBindingExp)
  outExp
end

"""
    Returns the expression contained in a binding expression, if the given
    expression is a binding expression.
"""
function getBindingExp(@nospecialize(bindingExp::Expression))
  getBindingExp2(bindingExp)
end

function getBindingExp2(@nospecialize(bindingExp::Expression))
  local outExp::Expression
   outExp = begin
    @match bindingExp begin
      BINDING_EXP(__)  => begin
        getBindingExp(bindingExp.exp)
      end
      _  => begin
        bindingExp
      end
    end
  end
  outExp
end

function isBindingExp(@nospecialize(exp::Expression)) ::Bool
  local isBindingExp::Bool

   isBindingExp = begin
    @match exp begin
      BINDING_EXP(__)  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  isBindingExp
end

function nthEnumLiteral(@nospecialize(ty::M_Type), n::Int) ::Expression
  local exp::Expression
  exp = ENUM_LITERAL_EXPRESSION(ty, nthEnumLiteral(ty, n), n)
  exp
end

"""
Replaces split indices in a subscripted expression with : subscripts,
except for indices that reference nodes in the given list.
"""
@nospecializeinfer function expandNonListedSplitIndices(@nospecialize(exp::Expression), @nospecialize(indicesToKeep::Union{List{<:InstNode}, Cons{<:InstNode}}))
  #= Adapted from OpenModelica: the original SUBSCRIPTED_EXP had a split::Bool
     field not ported to Julia. Instead we detect split subscripts by checking
     for SUBSCRIPT_SPLIT_INDEX in the subscript list and replace those whose
     nodes are NOT in indicesToKeep with SUBSCRIPT_WHOLE. =#
  outExp = @match exp begin
    SUBSCRIPTED_EXP_EXPRESSION(__) => begin
      local newSubs = Subscript[]
      local changed = false
      for sub in exp.subscripts
        if sub isa SUBSCRIPT_SPLIT_INDEX
          if !_nodeInList(sub.node, indicesToKeep)
            push!(newSubs, SUBSCRIPT_WHOLE())
            changed = true
          else
            push!(newSubs, sub)
          end
        else
          push!(newSubs, sub)
        end
      end
      if changed
        applySubscripts(newSubs, exp.exp)
      else
        exp
      end
    end
    _ => exp
  end
  return outExp
end

function _nodeInList(@nospecialize(node::InstNode), @nospecialize(lst))
  for n in lst
    if n === node
      return true
    end
  end
  return false
end

function retype(@nospecialize(exp::Expression))
  exp = @match exp begin
    RANGE_EXPRESSION(__)  => begin
      local expTy = getRangeType(exp.start, exp.step, exp.stop, typeOf(exp.start), AbsynUtil.dummyInfo)
      RANGE_EXPRESSION(expTy, exp.start, exp.step, exp.stop)
    end
    CALL_EXPRESSION(call = TYPED_ARRAY_CONSTRUCTOR(__))  => begin
      local expCall = retype(exp.call)
      exp = CALL_EXPRESSION(expCall)
      exp
    end
    _  => begin
      exp
    end
  end
  exp
end

function splitRecordCref(@nospecialize(exp::Expression)) ::Expression
  local outExp::Expression
  (outExp, _) = expand(exp)
  outExp = begin
    local cls::InstNode
    local cr::ComponentRef
    local field_cr::ComponentRef
    local ty::M_Type
    @match outExp begin
      CREF_EXPRESSION(ty = TYPE_COMPLEX(cls = cls), cref = cr)  => begin
        local comps::Vector{InstNode} = getComponents(classTree(getClass(cls)))
        #@info "Components...." toString(comps)
        local compsLen::Int = arrayLength(comps)
        local fields::Vector{Expression} = Vector{Expression}(undef, compsLen)
        local j::Int = 1
        for i in 1:compsLen#:(-1):1
          ty = getType(comps[i])
          field_cr = prefixCref(comps[i], ty, nil, cr)
          fields[j] = CREF_EXPRESSION(ty, field_cr) #_cons(CREF_EXPRESSION(ty, field_cr), fields)
          j += 1
        end
        makeRecord(scopePath(cls), outExp.ty, fields)
      end
      ARRAY_EXPRESSION(__)  => begin
        local outExpElements = list(splitRecordCref(e) for e in outExp.elements)
        ARRAY_EXPRESSION(outExp.ty, outExpElements, outExp.literal)
      end
      _  => begin
        exp
      end
    end
  end
  #@info "Out Components" toString(outExp)
  outExp
end

"""
  Returns the nth field of a record expression. If the expression is an array
  it will return an array with the nth field in each array element.
"""
function nthRecordElement(index::Int, @nospecialize(recordExp::Expression)) ::Expression
  local outExp::Expression

   outExp = begin
    local node::InstNode
    local expl::List{Expression}
    @match recordExp begin
      RECORD_EXPRESSION(__)  => begin
        recordExp.elements[index]
      end

      ARRAY_EXPRESSION(elements =  nil(), ty = TYPE_ARRAY(elementType = TYPE_COMPLEX(cls = node)))  => begin
        makeEmptyArray(getType(nthComponent(index, getClass(node))))
      end

      ARRAY_EXPRESSION(__)  => begin
        expV = Expression[nthRecordElement(index, e) for e in recordExp.elements]
        makeArray(setArrayElementType(recordExp.ty, typeOf(first(expV))), expV)
      end

      RECORD_ELEMENT_EXPRESSION(ty = TYPE_ARRAY(elementType = TYPE_COMPLEX(cls = node)))  => begin
         node = nthComponent(index, getClass(node))
        RECORD_ELEMENT_EXPRESSION(recordExp, index, name(node), liftArrayLeftList(getType(node), arrayDims(recordExp.ty)))
      end

      BINDING_EXP(__)  => begin
        local f = @closure (e) -> nthRecordElement(index, e)
        bindingExpMap(recordExp, f)
      end

      _  => begin
        @match TYPE_COMPLEX(cls = node) = typeOf(recordExp)
         node = nthComponent(index, getClass(node))
        RECORD_ELEMENT_EXPRESSION(recordExp, index, name(node), getType(node))
      end
    end
  end
  outExp
end

"""  Returns the field with the given name in a record expression. If the
     expression is an array it will return the equivalent of calling the
     function on each element of the array.
"""
function recordElement(elementName::String, @nospecialize(recordExp::Expression)) ::Expression
  local outExp::Expression
  outExp = begin
    local node::InstNode
    local cls::Class
    local cls_tree::ClassTree
    local ty::M_Type
    local index::Int
    local expl::List{Expression}
    local cref::ComponentRef
    @match recordExp begin
      RECORD_EXPRESSION(ty = TYPE_COMPLEX(cls = node))  => begin
        cls = getClass(node)
        index = lookupComponentIndex(elementName, cls)
        recordExp.elements[index]
      end

      CREF_EXPRESSION(ty = TYPE_COMPLEX(cls = node))  => begin
        cls_tree = classTree(getClass(node))
        local entryInfo  = lookupElement(elementName, cls_tree)
        node = entryInfo.node
        @assert entryInfo.isImport == false "Entry info was not an import."
        ty = getType(node)
        cref = prefixCref(node, ty, nil, recordExp.cref)
        ty = liftArrayLeftList(ty, arrayDims(recordExp.ty))
        CREF_EXPRESSION(ty, cref)
      end

      ARRAY_EXPRESSION(elements =  nil(), ty = TYPE_ARRAY(elementType = TYPE_COMPLEX(cls = node)))  => begin
        cls = getClass(node)
        index = lookupComponentIndex(elementName, cls)
        ty = getType(nthComponent(index, cls))
        makeArray(ty, Expression[])
      end

      ARRAY_EXPRESSION(ty = TYPE_ARRAY(elementType = TYPE_COMPLEX(cls = node)))  => begin
        index = lookupComponentIndex(elementName, getClass(node))
        expV = Expression[nthRecordElement(index, e) for e in recordExp.elements]
        ty = liftArrayLeft(typeOf(expV[1]), fromInteger(length(expV)))
        makeArray(ty, expV; literal=recordExp.literal)
      end

      BINDING_EXP(__)  => begin
        local f = @closure (x) -> recordElement(elementName, x)
        bindingExpMap(recordExp, f)
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
         outExp = recordElement(elementName, recordExp.exp)
        SUBSCRIPTED_EXP_EXPRESSION(outExp, recordExp.subscripts, lookupRecordFieldType(elementName, recordExp.ty))
      end

      EMPTY_EXPRESSION(__)  => begin
        fail()
      end

      _  => begin
         ty = typeOf(recordExp)
        @match TYPE_COMPLEX(cls = node) = arrayElementType(ty)
         cls = getClass(node)
         index = lookupComponentIndex(elementName, cls)
         ty = liftArrayRightList(getType(nthComponent(index, cls)), arrayDims(ty))
        RECORD_ELEMENT_EXPRESSION(recordExp, index, elementName, ty)
      end
    end
  end
  outExp
end

function tupleElement(@nospecialize(exp::Expression), @nospecialize(ty::M_Type), index::Int) ::Expression
  local tupleElem::Expression
  tupleElem = begin
    local ety::M_Type
    @match exp begin
      TUPLE_EXPRESSION(__)  => begin
        listGet(exp.elements, index)
      end

      ARRAY_EXPRESSION(__)  => begin
        ety = unliftArray(ty)
        expElements = list(tupleElement(e, ety, index) for e in exp.elements)
        ARRAY_EXPRESSION(exp.ty, expElements, exp.literal)
      end

      BINDING_EXP(__)  => begin
        local f = @closure (ty, index) -> tupleElement(ty = ty, index = index)
        bindingExpMap(exp, f)
      end

      _  => begin
        TUPLE_ELEMENT_EXPRESSION(exp, index, ty)
      end
    end
  end
  tupleElem
end

function toScalar(@nospecialize(exp::Expression)) ::Expression
  local outExp::Expression

   outExp = begin
    @match exp begin
      ARRAY_EXPRESSION(elements = outExp <|  nil())  => begin
        toScalar(outExp)
      end

      _  => begin
        exp
      end
    end
  end
  outExp
end

function enumIndexExp(@nospecialize(enumExp::Expression)) ::Expression
  local indexExp::Expression

   indexExp = begin
    @match enumExp begin
      ENUM_LITERAL_EXPRESSION(__)  => begin
        INTEGER_EXPRESSION(enumExp.index)
      end

      _  => begin
        CALL_EXPRESSION(makeTypedCall(NFBuiltinFuncs.INTEGER_ENUM, Expression[enumExp], variability(enumExp)))
      end
    end
  end
  indexExp
end

function isEmpty(@nospecialize(exp::Expression)) ::Bool
  local empty::Bool

   empty = begin
    @match exp begin
      EMPTY_EXPRESSION(__)  => begin
        true
      end
      _  => begin
        false
      end
    end
  end
  empty
end

function isMutable(@nospecialize(exp::Expression)) ::Bool
  local isMutable::Bool

   isMutable = begin
    @match exp begin
      MUTABLE_EXPRESSION(__)  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  isMutable
end

function makeImmutable(@nospecialize(exp::Expression))
  local outExp::Expression
   outExp = begin
    @match exp begin
      MUTABLE_EXPRESSION(__)  => begin
        P_Pointer.access(exp.exp)
      end

      _  => begin
        exp
      end
    end
  end
  outExp
end

function makeMutable(@nospecialize(exp::Expression))
  local outExp::Expression
   outExp = MUTABLE_EXPRESSION(P_Pointer.create(exp, Expression))
  outExp
end

function variabilityList(expl::List{<:Expression}, var::VariabilityType = Variability.CONSTANT)
  for e in expl
     var = variabilityMax(var, variability(e))
  end
  var
end

function variabilityVector(expl::Vector{Expression}, var::VariabilityType = Variability.CONSTANT)
  for e in expl
    var = variabilityMax(var, variability(e))
  end
  var
end

@nospecializeinfer function variability(@nospecialize(exp::Expression))
  local var::VariabilityType
   var = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        Variability.CONSTANT
      end

      REAL_EXPRESSION(__)  => begin
        Variability.CONSTANT
      end

      STRING_EXPRESSION(__)  => begin
        Variability.CONSTANT
      end

      BOOLEAN_EXPRESSION(__)  => begin
        Variability.CONSTANT
      end

      ENUM_LITERAL_EXPRESSION(__)  => begin
        Variability.CONSTANT
      end

      CLKCONST_EXPRESSION(_)  => begin
        Variability.DISCRETE
      end

      CREF_EXPRESSION(__)  => begin
        variability(exp.cref)
      end

      TYPENAME_EXPRESSION(__)  => begin
        Variability.CONSTANT
      end

      ARRAY_EXPRESSION(__)  => begin
        variabilityVector(exp.elements)
      end

      MATRIX_EXPRESSION(__)  => begin
        local matVar = Variability.CONSTANT
        for row in exp.elements
          matVar = variabilityVector(row, matVar)
        end
        matVar
      end

      RANGE_EXPRESSION(__)  => begin
         var = variability(exp.start)
         var = variabilityMax(var, variability(exp.stop))
        if isSome(exp.step)
           var = variabilityMax(var, variability(Util.getOption(exp.step)))
        end
        var
      end

      TUPLE_EXPRESSION(__)  => begin
        variabilityList(exp.elements)
      end

      RECORD_EXPRESSION(__)  => begin
        variabilityVector(exp.elements)
      end

      CALL_EXPRESSION(__)  => begin
        variability(exp.call)
      end

      SIZE_EXPRESSION(__)  => begin
        if isSome(exp.dimIndex)
           var = variabilityMax(Variability.PARAMETER, variability(Util.getOption(exp.dimIndex)))
        else
           var = Variability.PARAMETER
        end
        var
      end

      END_EXPRESSION(__)  => begin
        Variability.PARAMETER
      end

      BINARY_EXPRESSION(__)  => begin
        variabilityMax(variability(exp.exp1), variability(exp.exp2))
      end

      UNARY_EXPRESSION(__)  => begin
        variability(exp.exp)
      end

      LBINARY_EXPRESSION(__)  => begin
        variabilityMax(variability(exp.exp1), variability(exp.exp2))
      end

      LUNARY_EXPRESSION(__)  => begin
        variability(exp.exp)
      end

      RELATION_EXPRESSION(__)  => begin
        variabilityMin(variabilityMax(variability(exp.exp1), variability(exp.exp2)), Variability.DISCRETE)
      end

      IF_EXPRESSION(__)  => begin
        variabilityMax(variability(exp.condition), variabilityMax(variability(exp.trueBranch), variability(exp.falseBranch)))
      end

      CAST_EXPRESSION(__)  => begin
        variability(exp.exp)
      end

      UNBOX_EXPRESSION(__)  => begin
        variability(exp.exp)
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        variabilityMax(variability(exp.exp), variabilityList(exp.subscripts))
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        variability(exp.tupleExp)
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        variability(exp.recordExp)
      end

      BOX_EXPRESSION(__)  => begin
        variability(exp.exp)
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        Variability.CONTINUOUS
      end

      BINDING_EXP(__)  => begin
        variability(exp.exp)
      end

      _  => begin
        Error.assertion(false, getInstanceName() + " got unknown expression.", sourceInfo())
        fail()
      end
    end
  end
  var
end

function promote2(@nospecialize(exp::Expression), isArray::Bool, dims::Int, types::List{<:M_Type}) ::Expression
  local outExp::Expression
   outExp = begin
    local ty::M_Type
    local rest_ty::List{M_Type}
    local arr_exp::Expression
    local expanded::Bool
    #=  No types left, we're done!
    =#
    @match (exp, types) begin
      (_,  nil())  => begin
        exp
      end
      (ARRAY_EXPRESSION(__), ty <| rest_ty)  => begin
        makeArray(ty, Expression[promote2(e, false, dims, rest_ty) for e in exp.elements])
      end
      (_, _) where (isArray)  => begin
        #=  An array, promote each element in the array.
        =#
        #=  An expression with array type, but which is not an array expression.
        =#
        #=  Such an expression can't be promoted here, so we create a promote call instead.
        =#
        (outExp, expanded) = expand(exp)
        if expanded
           outExp = promote2(outExp, true, dims, types)
        else
          outExp = CALL_EXPRESSION(makeTypedCall(NFBuiltinFuncs.PROMOTE,
                                                 Expression[exp, INTEGER_EXPRESSION(dims)],
                                                 variability(exp), listHead(types)))
        end
        outExp
      end
      _  => begin
        #=  A scalar expression, promote it as many times as the number of types given. =#
         outExp = exp
        for ty in listReverse(types)
          outExp = makeArray(ty, Expression[outExp])
        end
        outExp
      end
    end
  end
  outExp
end

function promote(@nospecialize(e::Expression), @nospecialize(ty::M_Type), n::Int) ::Tuple{Expression, M_Type}
  local dims::List{Dimension}
  local ety::M_Type
  local tys::List{M_Type} = nil
  local is_array::Bool
  #=  Construct the dimensions that needs to be added. =#
   dims = list(fromInteger(1) for i in dimensionCount(ty):n - 1)
  if ! listEmpty(dims)
     dims = listAppend(arrayDims(ty), dims)
     is_array = isArray(ty)
     ety = arrayElementType(ty)
     ty = liftArrayLeftList(ety, dims)
    while ! listEmpty(dims)
       tys = Cons{NFType}(liftArrayLeftList(ety, dims), tys)
       dims = listRest(dims)
    end
     e = promote2(e, is_array, n, listReverse(tys))
  end
  #=  Concatenate the existing dimensions and the added ones. =#
  #=  Construct the result type. =#
  #=  Construct the expression types, to avoid having to create a new type
      for each subexpression that will be created.
  =#
  (e, ty)
end

function promoteRef(@nospecialize(e::Expression), @nospecialize(ty::M_Type), n::Int, tyRef::Ref{NFType})::Expression
  local dims::List{Dimension}
  local ety::M_Type
  local tys::List{M_Type} = nil
  local is_array::Bool
  #=  Construct the dimensions that needs to be added. =#
   dims = list(fromInteger(1) for i in dimensionCount(ty):n - 1)
  if ! listEmpty(dims)
     dims = listAppend(arrayDims(ty), dims)
     is_array = isArray(ty)
     ety = arrayElementType(ty)
     ty = liftArrayLeftList(ety, dims)
    while ! listEmpty(dims)
       tys = Cons{NFType}(liftArrayLeftList(ety, dims), tys)
       dims = listRest(dims)
    end
     e = promote2(e, is_array, n, listReverse(tys))
  end
  #=  Concatenate the existing dimensions and the added ones. =#
  #=  Construct the result type. =#
  #=  Construct the expression types, to avoid having to create a new type
      for each subexpression that will be created.
  =#
  tyRef.x = ty
  e
end

function makeIdentityMatrix(n::Int, @nospecialize(elementType::M_Type)) ::Expression
  local matrix::Expression

  local zero::Expression
  local one::Expression
  local row::List{Expression}
  local rows::List{Expression} = nil
  local row_ty::M_Type

  zero = makeZero(elementType)
  one = makeOne(elementType)
  row_ty = TYPE_ARRAY(elementType, list(fromInteger(n)))
  for i in 1:n
     row = nil
    for j in 2:i
       row = Cons{Expression}(zero, row)
    end
     row = Cons{Expression}(one, row)
    for j in i:n - 1
       row = Cons{Expression}(zero, row)
    end
     rows = Cons{Expression}(makeArray(row_ty, row, literal = true), rows)
  end
   matrix = makeArray(liftArrayLeft(row_ty, fromInteger(n)), rows, literal = true)
  matrix
end

function transposeArray(@nospecialize(arrayExp::Expression)) ::Expression
  local outExp::Expression

  local dim1::Dimension
  local dim2::Dimension
  local rest_dims::List{Dimension}
  local ty::M_Type
  local row_ty::M_Type
  local expl::Vector{Expression}
  local matrix::Vector{Vector{Expression}}
  local literal::Bool

  @match ARRAY_EXPRESSION(TYPE_ARRAY(ty, Cons{Dimension}(dim1, Cons{Dimension}(dim2, rest_dims))), expl, literal) = arrayExp
  if ! isempty(expl)
    row_ty = TYPE_ARRAY(ty, Cons{Dimension}(dim1, rest_dims))
    matrix = Vector{Expression}[e.elements  for e in expl]
    matrix = ArrayUtil.transposeArray(matrix)
    expl = Expression[makeArray(row_ty, row, literal = literal) for row in matrix]
  end
  outExp = makeArray(TYPE_ARRAY(ty, Cons{Dimension}(dim2, Cons{Dimension}(dim1, rest_dims))), expl, literal = literal)
  outExp
end

function hasArrayCall2(@nospecialize(exp::Expression)) ::Bool
  local hasArrayCall::Bool
  local call::Call
  local ty::M_Type
  hasArrayCall = begin
    @match exp begin
      CALL_EXPRESSION(call = call)  => begin
         ty = typeOf(call)
        isArray(ty) && isVectorizeable(call)
      end

      TUPLE_ELEMENT_EXPRESSION(tupleExp = CALL_EXPRESSION(call = call))  => begin
        ty = nthTupleType(typeOf(call), exp.index)
        isArray(ty) && isVectorizeable(call)
      end

      _  => begin
        false
      end
    end
  end
  hasArrayCall
end

"""
  Returns true if the given expression contains a function call that returns
  an array, otherwise false.
"""
function hasArrayCall(@nospecialize(exp::Expression)) ::Bool
  local hasArrayCall::Bool
  hasArrayCall = contains(exp, hasArrayCall2)
  hasArrayCall
end

function arrayScalarElement(@nospecialize(arrayExp::Expression)) ::Expression
  local scalarExp::Expression
  @match ARRAY_EXPRESSION(elements = list(scalarExp)) = arrayExp
  scalarExp
end

@nospecializeinfer function arrayScalarElements_impl(@nospecialize(exp::Expression), elements::List{<:Expression}) ::List{Expression}
   elements = begin
    @match exp begin
      ARRAY_EXPRESSION(__)  => begin
        for e in exp.elements
           elements = arrayScalarElements_impl(e, elements)
        end
        elements
      end
      _  => begin
        Cons{Expression}(exp, elements)
      end
    end
  end
  elements
end

"""
TODO: Rewrite so it uses vectors...
"""
function arrayScalarElements(@nospecialize(exp::Expression)) ::List{Expression}
  local elements::List{Expression}
   elements = listReverseInPlace(arrayScalarElements_impl(exp, nil))
  elements
end

function arrayElementList(array::ARRAY_EXPRESSION)
  return arrayList(array.elements)
end

function arrayElements(array::ARRAY_EXPRESSION)
  return array.elements
end

function negate(@nospecialize(exp::Expression)) ::Expression
  exp = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        INTEGER_EXPRESSION(-exp.value)
      end

      REAL_EXPRESSION(__)  => begin
        REAL_EXPRESSION(-exp.value)
      end

      CAST_EXPRESSION(__)  => begin
        CAST_EXPRESSION(exp.ty, negate(exp.exp))
      end

      UNARY_EXPRESSION(__)  => begin
        exp.exp
      end

      _  => begin
        UNARY_EXPRESSION(OPERATOR(typeOf(exp), Op.UMINUS), exp)
      end
    end
  end
  exp
end

function isNegated(@nospecialize(exp::Expression)) ::Bool
  local negated::Bool

   negated = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        exp.value < 0
      end

      REAL_EXPRESSION(__)  => begin
        exp.value < 0
      end

      CAST_EXPRESSION(__)  => begin
        isNegated(exp.exp)
      end

      UNARY_EXPRESSION(__)  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  negated
end

function unbox(@nospecialize(boxedExp::Expression)) ::Expression
  local exp::Expression

   exp = begin
    local ty::M_Type
    @match boxedExp begin
      BOX_EXPRESSION(__)  => begin
        boxedExp.exp
      end

      _  => begin
         ty = typeOf(boxedExp)
        if isBoxed(ty)
          UNBOX_EXPRESSION(boxedExp, unbox(ty))
        else
          boxedExp
        end
      end
    end
  end
  exp
end

function box(@nospecialize(exp::Expression)) ::Expression
  local boxedExp::Expression

   boxedExp = begin
    @match exp begin
      BOX_EXPRESSION(__)  => begin
        exp
      end

      _  => begin
        BOX_EXPRESSION(exp)
      end
    end
  end
  boxedExp
end

function makeMinValue(@nospecialize(ty::M_Type)) ::Expression
  local exp::Expression

   exp = begin
    @match ty begin
      TYPE_REAL(__)  => begin
        REAL_EXPRESSION(-System.realMaxLit())
      end

      TYPE_INTEGER(__)  => begin
        INTEGER_EXPRESSION(-System.intMaxLit())
      end

      TYPE_BOOLEAN(__)  => begin
        BOOLEAN_EXPRESSION(false)
      end

      TYPE_ENUMERATION(__)  => begin
        ENUM_LITERAL_EXPRESSION(ty, listHead(ty.literals), 1)
      end

      TYPE_ARRAY(__)  => begin
        makeArray(ty, ArrayUtil.fill(makeMaxValue(unliftArray(ty)), size(listHead(ty.dimensions))), literal = true)
      end
    end
  end
  exp
end

function makeMaxValue(@nospecialize(ty::M_Type)) ::Expression
  local exp::Expression

   exp = begin
    @match ty begin
      TYPE_REAL(__)  => begin
        REAL_EXPRESSION(System.realMaxLit())
      end

      TYPE_INTEGER(__)  => begin
        INTEGER_EXPRESSION(System.intMaxLit())
      end

      TYPE_BOOLEAN(__)  => begin
        BOOLEAN_EXPRESSION(true)
      end

      TYPE_ENUMERATION(__)  => begin
        ENUM_LITERAL_EXPRESSION(ty, ListUtil.last(ty.literals), listLength(ty.literals))
      end

      TYPE_ARRAY(__)  => begin
        ARRAY_EXPRESSION(ty, ListUtil.fill(makeMaxValue(unliftArray(ty)), size(listHead(ty.dimensions))), literal = true)
      end
    end
  end
  exp
end

function makeOne(@nospecialize(ty::M_Type)) ::Expression
  local zeroExp::Expression

   zeroExp = begin
    @match ty begin
      TYPE_REAL(__)  => begin
        REAL_EXPRESSION(1.0)
      end

      TYPE_INTEGER(__)  => begin
        INTEGER_EXPRESSION(1)
      end

      TYPE_ARRAY(__)  => begin
        ARRAY_EXPRESSION(ty, ListUtil.fill(makeZero(unliftArray(ty)), size(listHead(ty.dimensions))), literal = true)
      end
    end
  end
  zeroExp
end

function makeOperatorRecordZero(recordNode::InstNode) ::Expression
  local zeroExp::Expression
  local op_node::InstNode
  local fn::M_FUNCTION
  @match ENTRY_INFO(op_node, _) = lookupElement("'0'", getClass(recordNode))
  instFunctionNode(op_node)
  fns = typeNodeCache(op_node)
  fn = fns[1]
  zeroExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[], Variability.CONSTANT))
  zeroExp = evalExp(zeroExp)
  zeroExp
end

function makeZero(@nospecialize(ty::M_Type)) ::Expression
  local zeroExp::Expression

   zeroExp = begin
    @match ty begin
      TYPE_REAL(__)  => begin
        REAL_EXPRESSION(0.0)
      end

      TYPE_INTEGER(__)  => begin
        INTEGER_EXPRESSION(0)
      end

      TYPE_ARRAY(__)  => begin
        ARRAY_EXPRESSION(ty, ListUtil.fill(makeZero(unliftArray(ty)), size(listHead(ty.dimensions))), literal = true)
      end

      TYPE_COMPLEX(__)  => begin
        makeOperatorRecordZero(ty.cls)
      end
    end
  end
  zeroExp
end

"""
  Creates an array from the given list of dimensions, where each element is
  the given expression. Example:
  liftArrayList([2, 3], 1) => {{1, 1, 1}, {1, 1, 1}}
"""
function liftArrayList(dims::List{<:Dimension}, @nospecialize(exp::Expression)) ::Tuple{Expression, M_Type}
  local arrayType::M_Type = typeOf(exp)
  local expl::List{Expression}
  local is_literal::Bool = isLiteral(exp)
  tmp = dims
  dims = nil
  while tmp !== nil
    @match Cons{Dimension}(d, tmp) =tmp
    dims = Cons{Dimension}{d, dims}
  end
  while dims !== nil
    @match Cons{Dimension}(d, dims) = dims
    expl = nil
    for i in 1:size(dim)
      expl = Cons{Expression}(exp, expl)
    end
    arrayType = liftArrayLeft(arrayType, dim)
    exp = makeArray(arrayType, expl, literal = is_literal)
  end
  (exp, arrayType)
end

"""
  Creates an array with the given dimension, where each element is the given
  expression. Example: liftArray([3], 1) => {1, 1, 1}
"""
function liftArray(dim::Dimension, @nospecialize(exp::Expression)) ::Tuple{Expression, M_Type}
  local arrayType::M_Type = typeOf(exp)
  local expl::Vector{Expression} = Vector[]
  for i in 1:size(dim)
    #expl = _cons(exp, expl)
    push!(expl, exp)
  end
  arrayType = liftArrayLeft(arrayType, dim)
  exp = makeArray(arrayType, expl, literal = isLiteral(exp))
  (exp, arrayType)
end

"""
  Creates an array with the given type, filling it with the given scalar
  expression.
"""
function fillType(@nospecialize(ty::M_Type), @nospecialize(fillExp::Expression)) ::Expression
  local exp::Expression = fillExp
  local dims::List{Dimension} = arrayDims(ty)
  local expl::Vector{Expression}
  local arr_ty::M_Type = arrayElementType(ty)
  for dim in dims #listReverse(dims)
    expl  = Expression[]
    for i in 1:size(dim)
      #expl = _cons(exp, expl)
      push!(expl, exp)
    end
    arr_ty = liftArrayLeft(arr_ty, dim)
    exp = makeArray(arr_ty, expl, literal = isLiteral(exp))
  end
  exp
end

function fillArgs(@nospecialize(fillExp::Expression), dims::List{Expression})
  local dimSize
  local arr::Vector{Expression} = Expression[]
  local result = fillExp
  local arrTy = typeOf(result)
  local literal::Bool = isLiteral(fillExp)
  for d in dims#listReverse(dims)
    dimSize = toInteger(d)
    arr = Expression[result for e in 1:dimSize]
    arrTy = liftArrayLeft(arrTy, fromInteger(dimSize))
    result = makeArray(arrTy, arr, literal = literal)
  end
  return result
end

function fillArgsDimVec(@nospecialize(fillExp::Expression), dims::Vector{Expression})
  local dimSize
  local arr::Vector{Expression} = Expression[]
  local result = fillExp
  local arrTy = typeOf(result)
  local literal::Bool = isLiteral(fillExp)
  for d in dims#listReverse(dims)
    dimSize = toInteger(d)
    arr = Expression[result for e in 1:dimSize]
    arrTy = liftArrayLeft(arrTy, fromInteger(dimSize))
    result = makeArray(arrTy, arr, literal = literal)
  end
  return result
end

function isRecordOrRecordArray(@nospecialize(exp::Expression)) ::Bool
  local isRecord::Bool
  isRecord = begin
    @match exp begin
      RECORD_EXPRESSION(__)  => begin
        true
      end
      ARRAY_EXPRESSION(__)  => begin
        #ListUtil.all(exp.elements, isRecordOrRecordArray)
        ArrayUtil.all(exp.elements, isRecordOrRecordArray)
      end
      _  => begin
        false
      end
    end
  end
  isRecord
end

isRecord(exp::Expression) = false
isRecord(exp::RECORD_EXPRESSION) = isRecordOrRecordArray(exp::Expression)

function isBoolean(@nospecialize(exp::Expression)) ::Bool
  local isBool::Bool

   isBool = begin
    @match exp begin
      BOOLEAN_EXPRESSION(__)  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  isBool
end

function isInteger(@nospecialize(exp::Expression)) ::Bool
  local isInteger::Bool

   isInteger = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  isInteger
end

function isLiteral(@nospecialize(exp::Expression)) ::Bool
  local literal::Bool

   literal = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        true
      end

      REAL_EXPRESSION(__)  => begin
        true
      end

      STRING_EXPRESSION(__)  => begin
        true
      end

      BOOLEAN_EXPRESSION(__)  => begin
        true
      end

      ENUM_LITERAL_EXPRESSION(__)  => begin
        true
      end

      ARRAY_EXPRESSION(__)  => begin
        ArrayUtil.all(exp.elements, isLiteral)
      end

      RECORD_EXPRESSION(__)  => begin
        ArrayUtil.all(exp.elements, isLiteral)
      end

      RANGE_EXPRESSION(__)  => begin
        isLiteral(exp.start) && isLiteral(exp.stop) && Util.applyOptionOrDefault(exp.step, isLiteral, true)
      end
      _  => begin
        false
      end
    end
  end
  literal
end

function isScalarLiteral(@nospecialize(exp::Expression)) ::Bool
  local literal::Bool

   literal = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        true
      end

      REAL_EXPRESSION(__)  => begin
        true
      end

      STRING_EXPRESSION(__)  => begin
        true
      end

      BOOLEAN_EXPRESSION(__)  => begin
        true
      end

      ENUM_LITERAL_EXPRESSION(__)  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  literal
end

function isNegative(@nospecialize(exp::Expression)) ::Bool
  local negative::Bool

   negative = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        exp.value < 0
      end

      REAL_EXPRESSION(__)  => begin
        exp.value < 0
      end

      BOOLEAN_EXPRESSION(__)  => begin
        false
      end

      ENUM_LITERAL_EXPRESSION(__)  => begin
        false
      end

      CAST_EXPRESSION(__)  => begin
        isNegative(exp.exp)
      end

      UNARY_EXPRESSION(__)  => begin
        ! isNegative(exp.exp)
      end

      _  => begin
        false
      end
    end
  end
  negative
end

function isOne(@nospecialize(exp::Expression)) ::Bool
  local isOneVar::Bool
  isOneVar = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        exp.value == 1
      end
      REAL_EXPRESSION(__)  => begin
        exp.value == 1.0
      end
      CAST_EXPRESSION(__)  => begin
        isOne(exp.exp)
      end
      _  => begin
        false
      end
    end
  end
  isOneVar
end

function isZero(@nospecialize(exp::Expression)) ::Bool
  local isZ::Bool

   isZ = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        exp.value == 0
      end

      REAL_EXPRESSION(__)  => begin
        exp.value == 0.0
      end

      CAST_EXPRESSION(__)  => begin
        isZero(exp.exp)
      end

      UNARY_EXPRESSION(__)  => begin
        isZero(exp.exp)
      end

      _  => begin
        false
      end
    end
  end
  isZ
end

function containsIterator(@nospecialize(exp::Expression), origin::ORIGIN_Type) ::Bool
  local iter::Bool
  if flagSet(origin, ORIGIN_FOR)
    iter = contains(exp, isIterator)
  else
    iter = false
  end
  iter
end

function isIterator(@nospecialize(exp::Expression)) ::Bool
  local _result::Bool
   _result = begin
    @match exp begin
      CREF_EXPRESSION(__)  => begin
        isIterator(exp.cref)
      end

      _  => begin
        false
      end
    end
  end
  _result
end

function toCref(@nospecialize(exp::Expression)) ::ComponentRef
  local cref::ComponentRef

  @match CREF_EXPRESSION(cref = cref) = exp
  cref
end

function fromCref(cref::ComponentRef) ::Expression
  local exp::Expression

   exp = CREF_EXPRESSION(getSubscriptedType(cref), cref)
  exp
end

function arrayAllEqual2(@nospecialize(arrayExp::Expression), @nospecialize(element::Expression)) ::Bool
  local allEqual::Bool

   allEqual = begin
    @match arrayExp begin
      ARRAY_EXPRESSION(elements = ARRAY_EXPRESSION(__) <| _)  => begin
        ListUtil.map1BoolAnd(arrayExp.elements, arrayAllEqual2, element)
      end

      ARRAY_EXPRESSION(__)  => begin
        ListUtil.map1BoolAnd(arrayExp.elements, isEqual, element)
      end

      _  => begin
        true
      end
    end
  end
  allEqual
end

"""Checks if all scalar elements in an array are equal to each other."""
function arrayAllEqual(@nospecialize(arrayExp::Expression)) ::Bool
  local allEqual::Bool

   allEqual = begin
    @matchcontinue arrayExp begin
      ARRAY_EXPRESSION(__)  => begin
        arrayAllEqual2(arrayExp, arrayFirstScalar(arrayExp))
      end

      _  => begin
        true
      end
    end
  end
  allEqual
end

""" #= Returns the first scalar element of an array. Fails if the array is empty. =#"""
@nospecializeinfer function arrayFirstScalar(@nospecialize(arrayExp::Expression)) ::Expression
  local exp::Expression

   exp = begin
    @match arrayExp begin
      ARRAY_EXPRESSION(__)  => begin
        arrayFirstScalar(listHead(arrayExp.elements))
      end

      _  => begin
        arrayExp
      end
    end
  end
  exp
end

@nospecializeinfer function callContainsShallow(@nospecialize(call::Call), func::ContainsPred) ::Bool
  local res::Bool
  res = begin
    local e::Expression
    @match call begin
      UNTYPED_CALL(__)  => begin
         res = listContainsShallow(call.arguments, func)
        if ! res
          for arg in call.named_args
             (_, e) = arg
            if func(e)
               res = true
              break
            end
          end
        end
        res
      end

      ARG_TYPED_CALL(__)  => begin
        for arg in call.arguments
           (e, _, _) = arg
          if func(e)
             res = true
            return
          end
        end
        for arg in call.named_args
           (_, e, _, _) = arg
          if func(e)
             res = true
            return
          end
        end
        false
      end

      TYPED_CALL(__)  => begin
        listContainsShallow(call.arguments, func)
      end

      UNTYPED_ARRAY_CONSTRUCTOR(__)  => begin
        func(call.exp)
      end

      TYPED_ARRAY_CONSTRUCTOR(__)  => begin
        func(call.exp)
      end

      UNTYPED_REDUCTION(__)  => begin
        func(call.exp)
      end

      TYPED_REDUCTION(__)  => begin
        func(call.exp)
      end
    end
  end
  res
end

function listContainsShallow(expl::Union{List{<:Expression}, Vector{Expression}}, func::ContainsPred)::Bool
  local res::Bool
  for e in expl
    if func(e)
      res = true
      return res
    end
  end
  res = false
  return res
end

function crefContainsShallow(cref::ComponentRef, func::ContainsPred) ::Bool
  local res::Bool

   res = begin
    @match cref begin
      COMPONENT_REF_CREF(__)  => begin
        listContainsExpShallow(cref.subscripts, func) || crefContainsShallow(cref.restCref, func)
      end

      _  => begin
        false
      end
    end
  end
  res
end

function containsShallow(@nospecialize(exp::Expression), func::ContainsPred) ::Bool
  local res::Bool

   res = begin
    @match exp begin
      CREF_EXPRESSION(__)  => begin
        crefContainsShallow(exp.cref, func)
      end

      ARRAY_EXPRESSION(__)  => begin
        listContainsShallow(exp.elements, func)
      end

      MATRIX_EXPRESSION(__)  => begin
         res = false
        for row in exp.elements
          if listContainsShallow(row, func)
             res = true
            break
          end
        end
        res
      end

      RANGE_EXPRESSION(__)  => begin
        func(exp.start) || Util.applyOptionOrDefault(exp.step, func, false) || func(exp.stop)
      end

      TUPLE_EXPRESSION(__)  => begin
        listContainsShallow(exp.elements, func)
      end

      RECORD_EXPRESSION(__)  => begin
        listContainsShallow(exp.elements, func)
      end

      CALL_EXPRESSION(__)  => begin
        callContainsShallow(exp.call, func)
      end

      SIZE_EXPRESSION(__)  => begin
        Util.applyOptionOrDefault(exp.dimIndex, func, false) || func(exp.exp)
      end

      BINARY_EXPRESSION(__)  => begin
        func(exp.exp1) || func(exp.exp2)
      end

      UNARY_EXPRESSION(__)  => begin
        func(exp.exp)
      end

      LBINARY_EXPRESSION(__)  => begin
        func(exp.exp1) || func(exp.exp2)
      end

      LUNARY_EXPRESSION(__)  => begin
        func(exp.exp)
      end

      RELATION_EXPRESSION(__)  => begin
        func(exp.exp1) || func(exp.exp2)
      end

      IF_EXPRESSION(__)  => begin
        func(exp.condition) || func(exp.trueBranch) || func(exp.falseBranch)
      end

      CAST_EXPRESSION(__)  => begin
        func(exp.exp)
      end

      UNBOX_EXPRESSION(__)  => begin
        func(exp.exp)
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        func(exp.exp) || listContainsExpShallow(exp.subscripts, func)
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        func(exp.tupleExp)
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        func(exp.recordExp)
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        listContains(exp.args, func)
      end

      BOX_EXPRESSION(__)  => begin
        func(exp.exp)
      end
      _  => begin
        false
      end
    end
  end
  res
end

@nospecializeinfer function callContains(@nospecialize(call::Call), func::ContainsPred) ::Bool
  local res::Bool

   res = begin
    local e::Expression
    @match call begin
      UNTYPED_CALL(__)  => begin
         res = vectorContains(call.arguments, func)
        if ! res
          for arg in call.named_args
             (_, e) = arg
            if contains(e, func)
               res = true
              break
            end
          end
        end
        res
      end

      ARG_TYPED_CALL(__)  => begin
        for arg in call.arguments
           (e, _, _) = arg
          if contains(e, func)
             res = true
            return
          end
        end
        for arg in call.named_args
           (_, e, _, _) = arg
          if contains(e, func)
             res = true
            return
          end
        end
        false
      end

      TYPED_CALL(__)  => begin
        vectorContains(call.arguments, func)
      end

      UNTYPED_ARRAY_CONSTRUCTOR(__)  => begin
        contains(call.exp, func)
      end

      TYPED_ARRAY_CONSTRUCTOR(__)  => begin
        contains(call.exp, func)
      end

      UNTYPED_REDUCTION(__)  => begin
        contains(call.exp, func)
      end

      TYPED_REDUCTION(__)  => begin
        contains(call.exp, func)
      end
    end
  end
  res
end

function listContains(expl::List{<:Expression}, func::ContainsPred) ::Bool
  local res::Bool

  for e in expl
    if contains(e, func)
       res = true
      return res
    end
  end
   res = false
  res
end

function vectorContains(expl::Vector{Expression}, func::ContainsPred)
  local res::Bool
  for e in expl
    if contains(e, func)
       res = true
      return res
    end
  end
   res = false
  res
end

function crefContains(cref::ComponentRef, func::ContainsPred) ::Bool
  local res::Bool

   res = begin
    @match cref begin
      COMPONENT_REF_CREF(__)  => begin
        listContainsExp(cref.subscripts, func) || crefContains(cref.restCref, func)
      end

      _  => begin
        false
      end
    end
  end
  res
end

@nospecializeinfer function contains(@nospecialize(exp::Expression), func::ContainsPred) ::Bool
  local res::Bool
  if func(exp)
     res = true
    return res
  end
   res = begin
    local e::Expression
    @match exp begin
      CREF_EXPRESSION(__)  => begin
        crefContains(exp.cref, func)
      end
      ARRAY_EXPRESSION(__)  => begin
        vectorContains(exp.elements, func)
      end
      MATRIX_EXPRESSION(__)  => begin
         res = false
        for row in exp.elements
          if listContains(row, func)
             res = true
            break
          end
        end
        res
      end
      RANGE_EXPRESSION(__)  => begin
        contains(exp.start, func) || containsOpt(exp.step, func) || contains(exp.stop, func)
      end
      TUPLE_EXPRESSION(__)  => begin
        listContains(exp.elements, func)
      end
      RECORD_EXPRESSION(__)  => begin
        vectorContains(exp.elements, func)
      end
      CALL_EXPRESSION(__)  => begin
        callContains(exp.call, func)
      end
      SIZE_EXPRESSION(__)  => begin
        containsOpt(exp.dimIndex, func) || contains(exp.exp, func)
      end
      BINARY_EXPRESSION(__)  => begin
        contains(exp.exp1, func) || contains(exp.exp2, func)
      end
      UNARY_EXPRESSION(__)  => begin
        contains(exp.exp, func)
      end
      LBINARY_EXPRESSION(__)  => begin
        contains(exp.exp1, func) || contains(exp.exp2, func)
      end
      LUNARY_EXPRESSION(__)  => begin
        contains(exp.exp, func)
      end
      RELATION_EXPRESSION(__)  => begin
        contains(exp.exp1, func) || contains(exp.exp2, func)
      end
      IF_EXPRESSION(__)  => begin
        contains(exp.condition, func) || contains(exp.trueBranch, func) || contains(exp.falseBranch, func)
      end
      CAST_EXPRESSION(__)  => begin
        contains(exp.exp, func)
      end
      UNBOX_EXPRESSION(__)  => begin
        contains(exp.exp, func)
      end
      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        contains(exp.exp, func) || listContainsExp(exp.subscripts, func)
      end
      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        contains(exp.tupleExp, func)
      end
      RECORD_ELEMENT_EXPRESSION(__)  => begin
        contains(exp.recordExp, func)
      end
      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        listContains(exp.args, func)
      end
      BOX_EXPRESSION(__)  => begin
        contains(exp.exp, func)
      end
      _  => begin
        false
      end
    end
  end
  res
end

function containsOpt(exp::Option{<:Expression}, func::ContainsPred) ::Bool
  local res::Bool
  local e::Expression
  res = begin
    @match exp begin
      SOME(e)  => begin
        contains(e, func)
      end
      _  => begin
        false
      end
    end
  end
  res
end

function mapFoldCrefShallow(cref::ComponentRef, @nospecialize(func::Function), arg::ArgT)  where {ArgT}
  local outCref::ComponentRef
  outCref = begin
    local subs::List{Subscript}
    local rest::ComponentRef
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF)  => begin
        (subs, arg) = ListUtil.map1Fold(cref.subscripts, mapFoldExpShallow, func, arg, Subscript)
        (rest, arg) = mapFoldCrefShallow(cref.restCref, func, arg)
        COMPONENT_REF_CREF(cref.node, subs, cref.ty, cref.origin, rest)
      end
      _  => begin
        cref
      end
    end
  end
  (outCref, arg)
end

@nospecializeinfer function mapFoldCallIteratorsShallow(iters::List{Tuple{InstNode, Expression}}, @nospecialize(func::Function), arg::ArgT)  where {ArgT}
  if listEmpty(iters)
    return (iters, arg)
  end

  local outIters::List{Tuple{InstNode, Expression}} = nil

  local node::InstNode
  local exp::Expression
  local new_exp::Expression

  for i in iters
     (node, exp) = i
     (new_exp, arg) = func(exp, arg)
     outIters = Cons{Tuple{InstNode, Expression}}(if referenceEq(new_exp, exp)
                               i
                             else
                               (node, new_exp)
                             end, outIters)
  end
   outIters = listReverseInPlace(outIters)
  (outIters, arg)
end

@nospecializeinfer function mapFoldCallShallow(@nospecialize(call::Call), @nospecialize(func::Function), foldArg::ArgT)  where {ArgT}
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
        (args, foldArg) = ArrayUtil.mapFold(call.arguments, func, foldArg)
        TYPED_CALL(call.fn, call.ty, call.var, args, call.attributes)
      end

      UNTYPED_ARRAY_CONSTRUCTOR(__)  => begin
        (e, foldArg) = func(call.exp, foldArg)
        (iters, foldArg) = mapFoldCallIteratorsShallow(call.iters, func, foldArg)
        UNTYPED_ARRAY_CONSTRUCTOR(e, iters)
      end

      TYPED_ARRAY_CONSTRUCTOR(__)  => begin
        (e, foldArg) = func(call.exp, foldArg)
        (iters, foldArg) = mapFoldCallIteratorsShallow(call.iters, func, foldArg)
        TYPED_ARRAY_CONSTRUCTOR(call.ty, call.var, e, iters)
      end

      UNTYPED_REDUCTION(__)  => begin
         (e, foldArg) = func(call.exp, foldArg)
        (iters, foldArg) = mapFoldCallIteratorsShallow(call.iters, func, foldArg)
        UNTYPED_REDUCTION(call.ref, e, iters)
      end

      TYPED_REDUCTION(__)  => begin
        (e, foldArg) = func(call.exp, foldArg)
        (iters, foldArg) = mapFoldCallIteratorsShallow(call.iters, func, foldArg)
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
  (outCall, foldArg)
end

function mapFoldOptShallow(exp::Option{Expression}, @nospecialize(func::Function), arg::ArgT)  where {ArgT}

  local outExp::Option{Expression}

  local e1::Expression
  local e2::Expression

   outExp = begin
    @match exp begin
      SOME(e1)  => begin
         (e2, arg) = func(e1, arg)
        if referenceEq(e1, e2)
          exp
        else
          SOME(e2)
        end
      end

      _  => begin
        exp
      end
    end
  end
  (outExp, arg)
end

function mapFoldClockShallow(@nospecialize(clockExp::Expression), @nospecialize(func::Function), arg::ArgT)  where {ArgT}

  local outExp::Expression

  local clk::ClockKind
  local e1::Expression
  local e2::Expression
  local e3::Expression
  local e4::Expression

  @match CLKCONST_EXPRESSION(clk = clk) = clockExp
   outExp = begin
    @match clk begin
      INTEGER_CLOCK(e1, e2)  => begin
         (e3, arg) = func(e1, arg)
         (e4, arg) = func(e2, arg)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          clockExp
        else
          CLKCONST_EXPRESSION(INTEGER_CLOCK(e3, e4))
        end
      end

      REAL_CLOCK(e1)  => begin
         (e2, arg) = func(e1, arg)
        if referenceEq(e1, e2)
          clockExp
        else
          CLKCONST_EXPRESSION(REAL_CLOCK(e2))
        end
      end

      BOOLEAN_CLOCK(e1, e2)  => begin
         (e3, arg) = func(e1, arg)
         (e4, arg) = func(e2, arg)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          clockExp
        else
          CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e3, e4))
        end
      end

      SOLVER_CLOCK(e1, e2)  => begin
         (e3, arg) = func(e1, arg)
         (e4, arg) = func(e2, arg)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          clockExp
        else
          CLKCONST_EXPRESSION(SOLVER_CLOCK(e3, e4))
        end
      end

      _  => begin
        clockExp
      end
    end
  end
  (outExp, arg)
end

@nospecializeinfer function mapFoldShallow(@nospecialize(exp::Expression), @nospecialize(func::Function), arg::ArgT)  where {ArgT}
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
        reuseIfRefEqual(exp, exp.cref, cr, c -> CREF_EXPRESSION(exp.ty, c))
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
         (expl, arg) = ListUtil.mapFold(exp.elements, func, arg, Expression)
        TUPLE_EXPRESSION(exp.ty, expl)
      end

      RECORD_EXPRESSION(__)  => begin
        (expV, arg) = ArrayUtil.mapFold(exp.elements, func, arg)
        RECORD_EXPRESSION(exp.path, exp.ty, expV)
      end

      CALL_EXPRESSION(__)  => begin
         (call, arg) = mapFoldCallShallow(exp.call, func, arg)
        reuseIfRefEqual(exp, exp.call, call, c -> CALL_EXPRESSION(c))
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
        reuseIfRefEqual(exp, exp.exp, e1, e -> UNARY_EXPRESSION(exp.operator, e))
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
        reuseIfRefEqual(exp, exp.exp, e1, e -> LUNARY_EXPRESSION(exp.operator, e))
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

function mapFoldCref(cref::ComponentRef, @nospecialize(func::Function), arg::ArgT)  where {ArgT}

  local outCref::ComponentRef

   outCref = begin
    local subs::List{Subscript}
    local rest::ComponentRef
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF)  => begin
         (subs, arg) = ListUtil.map1Fold(cref.subscripts, mapFoldExp, func, arg, Subscript)
         (rest, arg) = mapFoldCref(cref.restCref, func, arg)
        COMPONENT_REF_CREF(cref.node, subs, cref.ty, cref.origin, rest)
      end

      _  => begin
        cref
      end
    end
  end
  (outCref, arg)
end

@nospecializeinfer function mapFoldCallIterators(iters::List{Tuple{InstNode, Expression}}, @nospecialize(func::Function), arg::ArgT)  where {ArgT}
  if listEmpty(iters)
    return (iters, arg)
  end

  local outIters::List{Tuple{InstNode, Expression}} = nil

  local node::InstNode
  local exp::Expression
  local new_exp::Expression

  for i in iters
     (node, exp) = i
     (new_exp, arg) = mapFold(exp, func, arg)
     outIters = Cons{Tuple{InstNode, Expression}}(if referenceEq(new_exp, exp)
                             i
                             else
                             (node, new_exp)
                             end, outIters)
  end
   outIters = listReverseInPlace(outIters)
  (outIters, arg)
end

@nospecializeinfer function mapFoldCall(@nospecialize(call::Call), @nospecialize(func::Function), foldArg::ArgT)  where {ArgT}
  local outCall::Call
   outCall = begin
    local args::List{Expression}
    local nargs::List{NamedArg}
    local targs::List{TypedArg}
    local tnargs::List{TypedNamedArg}
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
        (args, foldArg) = ListUtil.map1Fold(call.arguments, mapFold, func, foldArg, Expression)
         nargs = nil
        for arg in call.named_args
           (s, e) = arg
           (e, foldArg) = mapFold(e, func, foldArg)
           nargs = Cons{NamedArg}((s, e), nargs)
        end
        UNTYPED_CALL(call.ref, args, listReverse(nargs), call.call_scope)
      end

      ARG_TYPED_CALL(__)  => begin
         targs = nil
         tnargs = nil
        for arg in call.arguments
           (e, t, v) = arg
           (e, foldArg) = mapFold(e, func, foldArg)
           targs = Cons{TypedArg}((e, t, v), targs)
        end
        for arg in call.named_args
           (s, e, t, v) = arg
           (e, foldArg) = mapFold(e, func, foldArg)
           tnargs = Cons{TypedNamedArg}((s, e, t, v), tnargs)
        end
        ARG_TYPED_CALL(call.ref, listReverse(targs), listReverse(tnargs), call.call_scope)
      end

      TYPED_CALL(__)  => begin
        (args, foldArg) = ListUtil.map1Fold(call.arguments, mapFold, func, foldArg, Expression)
        TYPED_CALL(call.fn, call.ty, call.var, args, call.attributes)
      end

      UNTYPED_ARRAY_CONSTRUCTOR(__)  => begin
        (e, foldArg) = mapFold(call.exp, func, foldArg)
        UNTYPED_ARRAY_CONSTRUCTOR(e, call.iters)
      end

      TYPED_ARRAY_CONSTRUCTOR(__)  => begin
         (e, foldArg) = mapFold(call.exp, func, foldArg)
        TYPED_ARRAY_CONSTRUCTOR(call.ty, call.var, e, call.iters)
      end

      UNTYPED_REDUCTION(__)  => begin
         (e, foldArg) = mapFold(call.exp, func, foldArg)
        UNTYPED_REDUCTION(call.ref, e, call.iters)
      end

      TYPED_REDUCTION(__)  => begin
         (e, foldArg) = mapFold(call.exp, func, foldArg)
         (iters, foldArg) = mapFoldCallIterators(call.iters, func, foldArg)
         (default_exp, foldArg) = mapFoldOpt(call.defaultExp, func, foldArg)
        oe = Util.tuple31(call.foldExp)
        if isSome(oe)
           (oe, foldArg) = mapFoldOpt(oe, func, foldArg)
          fold_exp = Util.applyTuple31(call.foldExp, (_) -> oe)
        else
          fold_exp = call.foldExp
        end
        TYPED_REDUCTION(call.fn, call.ty, call.var, e, iters, default_exp, fold_exp)
      end
    end
  end
  (outCall, foldArg)
end

function mapFoldOpt(exp::Option{Expression}, @nospecialize(func::Function), arg::ArgT)  where {ArgT}

  local outExp::Option{Expression}

  local e::Expression

   outExp = begin
    @match exp begin
      SOME(e)  => begin
         (e, arg) = mapFold(e, func, arg)
        SOME(e)
      end

      _  => begin
        exp
      end
    end
  end
  (outExp, arg)
end

@nospecializeinfer function mapFold(@nospecialize(exp::Expression), @nospecialize(func::Function), @nospecialize(arg::ArgT))  where {ArgT}
  local outExp::Expression
  outExp = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local e4::Expression
    local cr::ComponentRef
    local expl::List{Expression}
    local call::Call
    local subs::List{Subscript}
    @match exp begin
      CLKCONST_EXPRESSION(INTEGER_CLOCK(e1, e2))  => begin
        (e3, arg) = mapFold(e1, func, arg)
        (e4, arg) = mapFold(e2, func, arg)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          exp
        else
          CLKCONST_EXPRESSION(INTEGER_CLOCK(e3, e4))
        end
      end

      CLKCONST_EXPRESSION(REAL_CLOCK(e1))  => begin
        (e2, arg) = mapFold(e1, func, arg)
        if referenceEq(e1, e2)
          exp
        else
          CLKCONST_EXPRESSION(REAL_CLOCK(e2))
        end
      end

      CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e1, e2))  => begin
        (e3, arg) = mapFold(e1, func, arg)
        (e4, arg) = mapFold(e2, func, arg)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          exp
        else
          CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e3, e4))
        end
      end

      CLKCONST_EXPRESSION(SOLVER_CLOCK(e1, e2))  => begin
        (e3, arg) = mapFold(e1, func, arg)
        (e4, arg) = mapFold(e2, func, arg)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          exp
        else
          CLKCONST_EXPRESSION(SOLVER_CLOCK(e3, e4))
        end
      end

      CREF_EXPRESSION(__)  => begin
        (cr, arg) = mapFoldCref(exp.cref, func, arg)
        reuseIfRefEqual(exp, exp.cref, cr, c -> CREF_EXPRESSION(exp.ty, c))
      end

      ARRAY_EXPRESSION(__)  => begin
        (expl, arg) = ArrayUtil.map1Fold(exp.elements, mapFold, func, arg, Expression)
        ARRAY_EXPRESSION(exp.ty, expl, exp.literal)
      end

      RANGE(step = SOME(e2))  => begin
        (e1, arg) = mapFold(exp.start, func, arg)
        (e4, arg) = mapFold(e2, func, arg)
        (e3, arg) = mapFold(exp.stop, func, arg)
        if referenceEq(exp.start, e1) && referenceEq(e2, e4) && referenceEq(exp.stop, e3)
          exp
        else
          RANGE_EXPRESSION(exp.ty, e1, SOME(e4), e3)
        end
      end

      RANGE_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.start, func, arg)
        (e3, arg) = mapFold(exp.stop, func, arg)
        if referenceEq(exp.start, e1) && referenceEq(exp.stop, e3)
          exp
        else
          RANGE_EXPRESSION(exp.ty, e1, NONE(), e3)
        end
      end

      TUPLE_EXPRESSION(__)  => begin
        (expl, arg) = ListUtil.map1Fold(exp.elements, mapFold, func, arg)
        TUPLE_EXPRESSION(exp.ty, expl)
      end

      RECORD_EXPRESSION(__)  => begin
        (expl, arg) = ArrayUtil.map1Fold(exp.elements, mapFold, func, arg)
        RECORD_EXPRESSION(exp.path, exp.ty, expl)
      end

      CALL_EXPRESSION(__)  => begin
        (call, arg) = mapFoldCall(exp.call, func, arg)
        reuseIfRefEqual(exp, exp.call, call, c -> CALL_EXPRESSION(c))
      end

      SIZE_EXPRESSION(dimIndex = SOME(e2))  => begin
        (e1, arg) = mapFold(exp.exp, func, arg)
        (e3, arg) = mapFold(e2, func, arg)
        if referenceEq(exp.exp, e1) && referenceEq(e2, e3)
          exp
        else
          SIZE_EXPRESSION(e1, SOME(e3))
        end
      end

      SIZE_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.exp, func, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          SIZE_EXPRESSION(e1, NONE())
        end
      end

      BINARY_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.exp1, func, arg)
        (e2, arg) = mapFold(exp.exp2, func, arg)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          BINARY_EXPRESSION(e1, exp.operator, e2)
        end
      end

      UNARY_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.exp, func, arg)
        reuseIfRefEqual(exp, exp.exp, e1, e -> UNARY_EXPRESSION(exp.operator, e))
      end

      LBINARY_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.exp1, func, arg)
        (e2, arg) = mapFold(exp.exp2, func, arg)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          LBINARY_EXPRESSION(e1, exp.operator, e2)
        end
      end

      LUNARY(__)  => begin
        (e1, arg) = mapFold(exp.exp, func, arg)
        reuseIfRefEqual(exp, exp.exp, e1, e -> LUNARY(exp.operator, e))
      end

      RELATION_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.exp1, func, arg)
        (e2, arg) = mapFold(exp.exp2, func, arg)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          RELATION_EXPRESSION(e1, exp.operator, e2)
        end
      end

      IF_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.condition, func, arg)
        (e2, arg) = mapFold(exp.trueBranch, func, arg)
        (e3, arg) = mapFold(exp.falseBranch, func, arg)
        if referenceEq(exp.condition, e1) && referenceEq(exp.trueBranch, e2) && referenceEq(exp.falseBranch, e3)
          exp
        else
          IF_EXPRESSION(e1, e2, e3)
        end
      end

      CAST_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.exp, func, arg)
        reuseIfRefEqual(exp, exp.exp, e1, e -> CAST_EXPRESSION(exp.ty, e))
      end

      UNBOX_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.exp, func, arg)
        if referenceEq(exp.exp, e1)
          exp
        else
          UNBOX_EXPRESSION(e1, exp.ty)
        end
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.exp, func, arg)
        (subs, arg) = ListUtil.mapFold(exp.subscripts, (sub, a) -> mapFoldExp(sub, func, a), arg)
        SUBSCRIPTED_EXP_EXPRESSION(e1, subs, exp.ty)
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.tupleExp, func, arg)
        if referenceEq(exp.tupleExp, e1)
          exp
        else
          TUPLE_ELEMENT_EXPRESSION(e1, exp.index, exp.ty)
        end
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(exp.recordExp, func, arg)
        if referenceEq(exp.recordExp, e1)
          exp
        else
          RECORD_ELEMENT_EXPRESSION(e1, exp.index, exp.fieldName, exp.ty)
        end
      end

      MUTABLE_EXPRESSION(__)  => begin
        (e1, arg) = mapFold(P_Pointer.access(exp.exp), func, arg)
        P_Pointer.update(exp.exp, e1)
        exp
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        (expl, arg) = ListUtil.map1Fold(exp.args, mapFold, func, arg)
        local expArgs = expl
        PARTIAL_FUNCTION_APPLICATION_EXPRESSION(exp.fn, expArgs, exp.argNames, exp.ty)
      end

      BINDING_EXP(__)  => begin
        (e1, arg) = mapFold(exp.exp, func, arg)
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
  (outExp, arg) = func(outExp, arg)
  return (outExp, arg)
end

function applyCrefSubscript(subscript::Subscript, func::ApplyFunc)
    @match subscript begin
      SUBSCRIPT_UNTYPED(__)  => begin
        apply(subscript.exp, func)
        nothing
      end

      SUBSCRIPT_INDEX(__)  => begin
        apply(subscript.index, func)
        nothing
      end

      SUBSCRIPT_SLICE(__)  => begin
        apply(subscript.slice, func)
        nothing
      end

      SUBSCRIPT_WHOLE(__)  => begin
        nothing
      end
    end
end

function applyCref(cref::ComponentRef, func::ApplyFunc)
  @match cref begin
    COMPONENT_REF_CREF(origin = Origin.CREF)  => begin
      for s in cref.subscripts
        applyCrefSubscript(s, func)
      end
      applyCref(cref.restCref, func)
      nothing
    end
    _  => begin
      nothing
    end
  end
end

@nospecializeinfer function applyCall(@nospecialize(call::Call), func::ApplyFunc)::Nothing
    local e::Expression
    @match call begin
      UNTYPED_CALL(__)  => begin
        applyList(call.arguments, func)
        for arg in call.named_args
          e = arg[2]
          apply(e, func)
        end
        nothing
      end

      ARG_TYPED_CALL(__)  => begin
        for arg in call.arguments
          e = first(arg)
          apply(e, func)
        end
        for arg in call.named_args
          e = arg[2]
          apply(e, func)
        end
        nothing
      end

      TYPED_CALL(__)  => begin
        applyList(call.arguments, func)
        nothing
      end

      UNTYPED_ARRAY_CONSTRUCTOR(__)  => begin
        apply(call.exp, func)
        for i in call.iters
          apply(last(i), func)
        end
        nothing
      end

      TYPED_ARRAY_CONSTRUCTOR(__)  => begin
        apply(call.exp, func)
        for i in call.iters
          apply(last(i), func)
        end
        nothing
      end

      UNTYPED_REDUCTION(__)  => begin
        apply(call.exp, func)
        for i in call.iters
          apply(last(i), func)
        end
        nothing
      end

      TYPED_REDUCTION(__)  => begin
        apply(call.exp, func)
        for i in call.iters
          apply(last(i), func)
        end
        Util.applyOption(call.defaultExp, func)
        Util.applyOption(Util.tuple31(call.foldExp), func)
        nothing
      end
    end
end

@nospecializeinfer function apply(@nospecialize(exp::Expression), func::ApplyFunc)::Nothing
  local e::Expression
  local e1::Expression
  local e2::Expression
  @match exp begin
    CLKCONST_EXPRESSION(INTEGER_CLOCK(e1, e2))  => begin
      apply(e1, func)
      apply(e2, func)
    end
    CLKCONST_EXPRESSION(REAL_CLOCK(e1))  => begin
      apply(e1, func)
    end
    CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e1, e2))  => begin
      apply(e1, func)
      apply(e2, func)
    end
    CLKCONST_EXPRESSION(SOLVER_CLOCK(e1, e2))  => begin
      apply(e1, func)
      apply(e2, func)
    end
    CREF_EXPRESSION(__)  => begin
      applyCref(exp.cref, func)
    end
    ARRAY_EXPRESSION(__)  => begin
      applyList(exp.elements, func)
    end
    MATRIX_EXPRESSION(__)  => begin
      for row in exp.elements
        applyList(row, func)
      end
    end
    RANGE_EXPRESSION(step = SOME(e))  => begin
      apply(exp.start, func)
      apply(e, func)
      apply(exp.stop, func)
    end
    RANGE_EXPRESSION(__)  => begin
      apply(exp.start, func)
      apply(exp.stop, func)
    end
    TUPLE_EXPRESSION(__)  => begin
      applyList(exp.elements, func)
    end
    RECORD_EXPRESSION(__)  => begin
      applyList(exp.elements, func)
    end
    CALL_EXPRESSION(__)  => begin
      applyCall(exp.call, func)
    end
    SIZE_EXPRESSION(dimIndex = SOME(e))  => begin
      apply(exp.exp, func)
      apply(e, func)
    end
    SIZE_EXPRESSION(__)  => begin
      apply(exp.exp, func)
    end
    BINARY_EXPRESSION(__)  => begin
      apply(exp.exp1, func)
      apply(exp.exp2, func)
    end
    UNARY_EXPRESSION(__)  => begin
      apply(exp.exp, func)
    end
    LBINARY_EXPRESSION(__)  => begin
      apply(exp.exp1, func)
      apply(exp.exp2, func)
    end
    LUNARY_EXPRESSION(__)  => begin
      apply(exp.exp, func)
    end
    RELATION_EXPRESSION(__)  => begin
      apply(exp.exp1, func)
      apply(exp.exp2, func)
    end
    IF_EXPRESSION(__)  => begin
      apply(exp.condition, func)
      apply(exp.trueBranch, func)
      apply(exp.falseBranch, func)
    end
    CAST_EXPRESSION(__)  => begin
      apply(exp.exp, func)
    end
    UNBOX_EXPRESSION(__)  => begin
      apply(exp.exp, func)
    end
    SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
      apply(exp.exp, func)
      for s in exp.subscripts
        applyExp(s, func)
      end
    end
    TUPLE_ELEMENT_EXPRESSION(__)  => begin
      apply(exp.tupleExp, func)
    end
    RECORD_ELEMENT_EXPRESSION(__)  => begin
      apply(exp.recordExp, func)
    end
    BOX_EXPRESSION(__)  => begin
      apply(exp.exp, func)
    end
    MUTABLE_EXPRESSION(__)  => begin
      apply(P_Pointer.access(exp.exp), func)
    end
    PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
      applyList(exp.args, func)
    end
    BINDING_EXP(__)  => begin
      apply(exp.exp, func)
    end
    _  => begin
    end
  end
  func(exp)
  return nothing
end

function applyList(expl::Union{List{<:Expression},Vector{Expression}}, func::ApplyFunc)
  for e in expl
    apply(e, func)
  end
end

function foldCref(cref::ComponentRef, func::FoldFunc, arg::ArgT)  where {ArgT}
  () = begin
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF)  => begin
        arg = ListUtil.fold(cref.subscripts, (x, y) -> foldExp(x, func, y), arg) #=TODO: Look at the x, y change here=#
        arg = foldCref(cref.restCref, func, arg)
        ()
      end
      _  => begin
        ()
      end
    end
  end
  arg
end

@nospecializeinfer function foldCall(@nospecialize(call::Call), func::FoldFunc, foldArg::ArgT) where {ArgT}
  () = begin
    local e::Expression
    @match call begin
      UNTYPED_CALL(__)  => begin
        foldArg = foldList(call.arguments, func, foldArg)
        for arg in call.named_args
          (_, e) = arg
          foldArg = fold(e, func, foldArg)
        end
        ()
      end

      ARG_TYPED_CALL(__)  => begin
        for arg in call.arguments
           (e, _, _) = arg
           foldArg = fold(e, func, foldArg)
        end
        for arg in call.named_args
           (_, e, _, _) = arg
           foldArg = fold(e, func, foldArg)
        end
        ()
      end

      TYPED_CALL(__)  => begin
         foldArg = foldList(call.arguments, func, foldArg)
        ()
      end

      UNTYPED_ARRAY_CONSTRUCTOR(__)  => begin
         foldArg = fold(call.exp, func, foldArg)
        for i in call.iters
           foldArg = fold(last(i), func, foldArg)
        end
        ()
      end

      TYPED_ARRAY_CONSTRUCTOR(__)  => begin
         foldArg = fold(call.exp, func, foldArg)
        for i in call.iters
           foldArg = fold(last(i), func, foldArg)
        end
        ()
      end

      UNTYPED_REDUCTION(__)  => begin
         foldArg = fold(call.exp, func, foldArg)
        for i in call.iters
           foldArg = fold(last(i), func, foldArg)
        end
        ()
      end

      TYPED_REDUCTION(__)  => begin
         foldArg = fold(call.exp, func, foldArg)
        for i in call.iters
           foldArg = fold(last(i), func, foldArg)
        end
         foldArg = foldOpt(call.defaultExp, func, foldArg)
         foldArg = foldOpt(Util.tuple31(call.foldExp), func, foldArg)
        ()
      end
    end
  end
  foldArg
end

@nospecializeinfer function fold(@nospecialize(exp::Expression), func::FoldFunc, arg)
  local result
  result = begin
    local e::Expression
    local e1::Expression
    local e2::Expression
    @match exp begin
      CLKCONST_EXPRESSION(INTEGER_CLOCK(e1, e2))  => begin
         result = fold(e1, func, arg)
         result = fold(e2, func, result)
        result
      end

      CLKCONST_EXPRESSION(REAL_CLOCK(e1))  => begin
         result = fold(e1, func, arg)
        result
      end

      CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e1, e2))  => begin
         result = fold(e1, func, arg)
         result = fold(e2, func, result)
        result
      end

      CLKCONST_EXPRESSION(SOLVER_CLOCK(e1, e2))  => begin
         result = fold(e1, func, arg)
         result = fold(e2, func, result)
        result
      end

      CREF_EXPRESSION(__)  => begin
        foldCref(exp.cref, func, arg)
      end

      ARRAY_EXPRESSION(__)  => begin
        foldList(exp.elements, func, arg)
      end

      MATRIX_EXPRESSION(__)  => begin
         result = arg
        for row in exp.elements
           result = foldList(row, func, result)
        end
        result
      end

      RANGE_EXPRESSION(__)  => begin
         result = fold(exp.start, func, arg)
         result = foldOpt(exp.step, func, result)
        fold(exp.stop, func, result)
      end

      TUPLE_EXPRESSION(__)  => begin
        foldList(exp.elements, func, arg)
      end

      RECORD_EXPRESSION(__)  => begin
        foldList(exp.elements, func, arg)
      end

      CALL_EXPRESSION(__)  => begin
        foldCall(exp.call, func, arg)
      end

      SIZE_EXPRESSION(dimIndex = SOME(e))  => begin
         result = fold(exp.exp, func, arg)
        fold(e, func, result)
      end

      SIZE_EXPRESSION(__)  => begin
        fold(exp.exp, func, arg)
      end

      BINARY_EXPRESSION(__)  => begin
         result = fold(exp.exp1, func, arg)
        fold(exp.exp2, func, result)
      end

      UNARY_EXPRESSION(__)  => begin
        fold(exp.exp, func, arg)
      end

      LBINARY_EXPRESSION(__)  => begin
         result = fold(exp.exp1, func, arg)
        fold(exp.exp2, func, result)
      end

      LUNARY_EXPRESSION(__)  => begin
        fold(exp.exp, func, arg)
      end

      RELATION_EXPRESSION(__)  => begin
         result = fold(exp.exp1, func, arg)
        fold(exp.exp2, func, result)
      end

      IF_EXPRESSION(__)  => begin
         result = fold(exp.condition, func, arg)
         result = fold(exp.trueBranch, func, result)
        fold(exp.falseBranch, func, result)
      end

      CAST_EXPRESSION(__)  => begin
        fold(exp.exp, func, arg)
      end

      UNBOX_EXPRESSION(__)  => begin
        fold(exp.exp, func, arg)
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        result = fold(exp.exp, func, arg)
        local f = @closure (x, y) -> foldExp(x, func, y)
        ListUtil.fold(exp.subscripts, f, result)
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        fold(exp.tupleExp, func, arg)
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        fold(exp.recordExp, func, arg)
      end

      BOX_EXPRESSION(__)  => begin
        fold(exp.exp, func, arg)
      end

      MUTABLE_EXPRESSION(__)  => begin
        fold(P_Pointer.access(exp.exp), func, arg)
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        foldList(exp.args, func, arg)
      end

      BINDING_EXP(__)  => begin
        fold(exp.exp, func, arg)
      end

      _  => begin
        arg
      end
    end
  end
  result = func(exp, result)
  return result
end

function foldOpt(exp::Option{Expression}, func::FoldFunc, arg::ArgT)  where {ArgT}
  local result::ArgT

   result = begin
    local e::Expression
    @match exp begin
      SOME(e)  => begin
        func(e, arg)
      end

      _  => begin
        arg
      end
    end
  end
  result
end

function foldList(expl::Union{List{T}, Vector{T}}, func::FoldFunc, arg) where T
  local result = arg
  for e in expl
    result = fold(e, func, result)
  end
  result
end

function mapArrayElements(exp::ARRAY_EXPRESSION, @nospecialize(func::Function))
  local expElements = Expression[mapArrayElements(e, func) for e in exp.elements]
  ARRAY_EXPRESSION(exp.ty, expElements, exp.literal)
end

"""  Applies the given function to each scalar elements of an array. """
function mapArrayElements(@nospecialize(exp::Expression), @nospecialize(func::Function))
  local outExp = func(exp)
  return outExp
end

@nospecializeinfer function mapCallShallowIterators(iters::List{<:Tuple{<:InstNode, Expression}}, @nospecialize(func::Function)) ::List{Tuple{InstNode, Expression}}
  if listEmpty(iters)
    return iters
  end
  local anyChanged = false
  for i in iters
    (_, exp) = i
    new_exp = func(exp)
    if !referenceEq(new_exp, exp)
      anyChanged = true
      break
    end
  end
  if !anyChanged
    return iters
  end
  local outIters::List{Tuple{InstNode, Expression}} = nil
  local node::InstNode
  local exp::Expression
  local new_exp::Expression
  for i in iters
     (node, exp) = i
    new_exp = func(exp)
    outIters = Cons{Tuple{InstNode, Expression}}(if referenceEq(new_exp, exp)
                             i
                             else
                             (node, new_exp)
                             end, outIters)
  end
  outIters = listReverseInPlace(outIters)
  outIters
end

@nospecializeinfer function mapCallShallow(@nospecialize(call::Call), @nospecialize(func::Function))
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
    @match call begin
      UNTYPED_CALL(__)  => begin
        local newArgs = mapPreservingEq(call.arguments, func)
        local origNargs = call.named_args
        local newNargs = origNargs
        for i in eachindex(origNargs)
          local (s, e) = origNargs[i]
          local new_e = func(e)
          if !referenceEq(e, new_e)
            if newNargs === origNargs
              newNargs = copy(origNargs)
            end
            newNargs[i] = (s, new_e)
          end
        end
        if newArgs === call.arguments && newNargs === origNargs
          call
        else
          UNTYPED_CALL(call.ref, newArgs, newNargs, call.call_scope)
        end
      end

      ARG_TYPED_CALL(__)  => begin
        targs = TypedArg[(func(e), t, v) for (e, t, v) in call.arguments]
        tnargs = TypedNamedArg[(s, func(e), t, v) for (s, e, t, v) in call.named_args]
        ARG_TYPED_CALL(call.ref, targs, tnargs, call.call_scope)
      end

      TYPED_CALL(__)  => begin
        local newArgs = mapPreservingEq(call.arguments, func)
        if newArgs === call.arguments
          call
        else
          TYPED_CALL(call.fn, call.ty, call.var, newArgs, call.attributes)
        end
      end

      UNTYPED_ARRAY_CONSTRUCTOR(__)  => begin
        reuseIfRefEqual(call, call.exp, func(call.exp), e -> UNTYPED_ARRAY_CONSTRUCTOR(e, call.iters))
      end

      TYPED_ARRAY_CONSTRUCTOR(__)  => begin
        reuseIfRefEqual(call, call.exp, func(call.exp), e -> TYPED_ARRAY_CONSTRUCTOR(call.ty, call.var, e, call.iters))
      end

      UNTYPED_REDUCTION(__)  => begin
        reuseIfRefEqual(call, call.exp, func(call.exp), e -> UNTYPED_REDUCTION(call.ref, e, call.iters))
      end

      TYPED_REDUCTION(__)  => begin
        e = func(call.exp)
        iters = mapCallShallowIterators(call.iters, func)
        default_exp = mapShallowOpt(call.defaultExp, func)
        fold_exp = Util.applyTuple31(call.foldExp, (oe) -> mapShallowOpt(oe, func))
        TYPED_REDUCTION(call.fn, call.ty, call.var, e, iters, default_exp, fold_exp)
      end
    end
  end
  outCall
end

function mapCrefShallow(cref::ComponentRef, @nospecialize(func::Function)) ::ComponentRef
  local outCref::ComponentRef

   outCref = begin
    local subs::List{Subscript}
    local rest::ComponentRef
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF)  => begin
        #subs = list(mapShallowExp(s, func) for s in cref.subscripts)
        #= New body... =#
        subs = cref.subscripts #list(mapExp(s, func) for s in cref.subscripts)
        tmp = listReverse(subs)
        nSubs::List{Subscript} = nil
        while tmp !== nil
          @match Cons{Subscript}(s, tmp) = tmp
          nSubs = Cons{Subscript}(mapShallowExp(s, func), nSubs)
        end

        rest = mapCref(cref.restCref, func)
        COMPONENT_REF_CREF(cref.node, subs, cref.ty, cref.origin, rest)
      end

      _  => begin
        cref
      end
    end
  end
  outCref
end

function mapCrefShallow!(cref::ComponentRef, @nospecialize(func::Function)) ::ComponentRef
  local outCref::ComponentRef
   outCref = begin
    local subs::List{Subscript}
    local rest::ComponentRef
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF)  => begin
        local subsV = Subscript[mapShallowExp(s, func) for s in cref.subscripts]
        subs = arrayList(subsV)
        rest = mapCref!(cref.restCref, func)
        #cref.subscripts = subs
        #cref.restCref = rest
        COMPONENT_REF_CREF(cref.node, subs, cref.ty, cref.origin, rest)
        #cref
      end
      _  => begin
        cref
      end
    end
  end
  outCref
end


function mapShallowOpt(exp::Option{<:Expression}, @nospecialize(func::Function)) ::Option{Expression}
  local outExp::Option{Expression}

  local e::Expression

   outExp = begin
    @match exp begin
      SOME(e)  => begin
        SOME(func(e))
      end

      _  => begin
        exp
      end
    end
  end
  outExp
end

@nospecializeinfer function mapShallow(@nospecialize(exp::Expression), func::Function)
  local outExp::Expression
  outExp = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local e4::Expression
    @match exp begin
      CLKCONST_EXPRESSION(INTEGER_CLOCK(e1, e2))  => begin
        e3 = func(e1)
        e4 = func(e2)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          exp
        else
          CLKCONST_EXPRESSION(INTEGER_CLOCK(e3, e4))
        end
      end

      CLKCONST_EXPRESSION(REAL_CLOCK(e1))  => begin
        e2 = func(e1)
        if referenceEq(e1, e2)
          exp
        else
          CLKCONST_EXPRESSION(REAL_CLOCK(e2))
        end
      end

      CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e1, e2))  => begin
        e3 = func(e1)
        e4 = func(e2)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          exp
        else
          CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e3, e4))
        end
      end

      CLKCONST_EXPRESSION(SOLVER_CLOCK(e1, e2))  => begin
        e3 = func(e1)
        e4 = func(e2)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          exp
        else
          CLKCONST_EXPRESSION(SOLVER_CLOCK(e3, e4))
        end
      end

      CREF_EXPRESSION(__)  => begin
        mapCrefShallow(exp.cref, func)
        #CREF_EXPRESSION(exp.ty, )
        exp
      end

      ARRAY_EXPRESSION(__)  => begin
        local elems = exp.elements::Vector{Expression}
        for (i, e) in enumerate(elems)
          elems[i] = func(e)::Expression
        end
        #ARRAY_EXPRESSION(exp.ty, Expression[func(e) for e in exp.elements], exp.literal)
        exp
      end

      MATRIX_EXPRESSION(__)  => begin
        MATRIX_EXPRESSION(list(list(func(e) for e in row) for row in exp.elements))
      end

      RANGE_EXPRESSION(step = SOME(e2))  => begin
        e1 = func(exp.start)
        e4 = func(e2)
        e3 = func(exp.stop)
        if referenceEq(exp.start, e1) && referenceEq(e2, e4) && referenceEq(exp.stop, e3)
          exp
        else
          RANGE_EXPRESSION(exp.ty, e1, SOME(e4), e3)
        end
      end

      RANGE_EXPRESSION(__)  => begin
        e1 = func(exp.start)
        e3 = func(exp.stop)
        if referenceEq(exp.start, e1) && referenceEq(exp.stop, e3)
          exp
        else
          RANGE_EXPRESSION(exp.ty, e1, NONE(), e3)
        end
      end

      TUPLE_EXPRESSION(__)  => begin
        TUPLE_EXPRESSION(exp.ty, list(func(e) for e in exp.elements))
      end

      RECORD_EXPRESSION(__)  => begin
        local newElements = mapPreservingEq(exp.elements, func)
        if newElements === exp.elements
          exp
        else
          RECORD_EXPRESSION(exp.path, exp.ty, newElements)
        end
      end

      CALL_EXPRESSION(__)  => begin
        reuseIfRefEqual(exp, exp.call, mapCallShallow(exp.call, func), c -> CALL_EXPRESSION(c))
      end

      SIZE_EXPRESSION(dimIndex = SOME(e2))  => begin
        e1 = func(exp.exp)
        e3 = func(e2)
        if referenceEq(exp.exp, e1) && referenceEq(e2, e3)
          exp
        else
          SIZE_EXPRESSION(e1, SOME(e3))
        end
      end

      SIZE_EXPRESSION(__)  => begin
        e1 = func(exp.exp)
        if referenceEq(exp.exp, e1)
          exp
        else
          SIZE_EXPRESSION(e1, NONE())
        end
      end

      BINARY_EXPRESSION(__)  => begin
        e1 = func(exp.exp1)
        e2 = func(exp.exp2)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          BINARY_EXPRESSION(e1, exp.operator, e2)
        end
      end

      UNARY_EXPRESSION(__)  => begin
        e1 = func(exp.exp)
        if referenceEq(exp.exp, e1)
          exp
        else
          UNARY_EXPRESSION(exp.operator, e1)
        end
      end

      LBINARY_EXPRESSION(__)  => begin
        e1 = func(exp.exp1)
        e2 = func(exp.exp2)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          LBINARY_EXPRESSION(e1, exp.operator, e2)
        end
      end

      LUNARY_EXPRESSION(__)  => begin
        e1 = func(exp.exp)
        if referenceEq(exp.exp, e1)
          exp
        else
          LUNARY_EXPRESSION(exp.operator, e1)
        end
      end

      RELATION_EXPRESSION(__)  => begin
        e1 = func(exp.exp1)
        e2 = func(exp.exp2)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          RELATION_EXPRESSION(e1, exp.operator, e2)
        end
      end

      IF_EXPRESSION(__)  => begin
        e1 = func(exp.condition)
        e2 = func(exp.trueBranch)
        e3 = func(exp.falseBranch)
        if referenceEq(exp.condition, e1) && referenceEq(exp.trueBranch, e2) && referenceEq(exp.falseBranch, e3)
          exp
        else
          IF_EXPRESSION(e1, e2, e3)
        end
      end

      CAST_EXPRESSION(__)  => begin
        e1 = func(exp.exp)
        if referenceEq(exp.exp, e1)
          exp
        else
          CAST_EXPRESSION(exp.ty, e1)
        end
      end

      UNBOX_EXPRESSION(__)  => begin
        e1 = func(exp.exp)
        if referenceEq(exp.exp, e1)
          exp
        else
          UNBOX_EXPRESSION(e1, exp.ty)
        end
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        SUBSCRIPTED_EXP_EXPRESSION(func(exp.exp), list(mapShallowExp(e, func) for e in exp.subscripts), exp.ty)
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        e1 = func(exp.tupleExp)
        if referenceEq(exp.tupleExp, e1)
          exp
        else
          TUPLE_ELEMENT_EXPRESSION(e1, exp.index, exp.ty)
        end
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        e1 = func(exp.recordExp)
        if referenceEq(exp.recordExp, e1)
          exp
        else
          RECORD_ELEMENT_EXPRESSION(e1, exp.index, exp.fieldName, exp.ty)
        end
      end

      BOX_EXPRESSION(__)  => begin
        e1 = func(exp.exp)
        if referenceEq(exp.exp, e1)
          exp
        else
          BOX_EXPRESSION(e1)
        end
      end

      MUTABLE_EXPRESSION(__)  => begin
        P_Pointer.update(exp.exp, func(P_Pointer.access(exp.exp)))
        exp
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        newArgs = list(func(e) for e in exp.args)
        PARTIAL_FUNCTION_APPLICATION_EXPRESSION(exp.fn, newArgs, exp.argNames, exp.ty)
      end

      BINDING_EXP(__)  => begin
        e1 = func(exp.exp)
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
  outExp
end

function mapCref(cref::ComponentRef, @nospecialize(func::Function)) ::ComponentRef
  local outCref::ComponentRef
  outCref = begin
    local subs::List{Subscript}
    local rest::ComponentRef
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF)  => begin
        rest = mapCref(cref.restCref, func)
        subs = cref.subscripts
        if listEmpty(subs)
          if referenceEq(rest, cref.restCref)
            cref
          else
            COMPONENT_REF_CREF(cref.node, subs, cref.ty, cref.origin, rest)
          end
        else
          tmp = listReverse(subs)
          nSubs::List{Subscript} = nil
          anySubChanged = false
          while tmp !== nil
            @match Cons{Subscript}(s, tmp) = tmp
            ms = mapExp(s, func)
            if !referenceEq(s, ms)
              anySubChanged = true
            end
            nSubs = Cons{Subscript}(ms, nSubs)
          end
          if !anySubChanged && referenceEq(rest, cref.restCref)
            cref
          else
            COMPONENT_REF_CREF(cref.node, anySubChanged ? nSubs : subs, cref.ty, cref.origin, rest)
          end
        end
      end
      _  => begin
        cref
      end
    end
  end
  outCref
end

function mapCref!(cref::ComponentRef, @nospecialize(func::Function)) ::ComponentRef
  return cref
end

"""
@author johti17
"""
function mapCref!(cref::COMPONENT_REF_CREF, @nospecialize(func::Function)) ::ComponentRef
  local outCref::ComponentRef = cref
  local subs::List{Subscript}
  local rest::ComponentRef
  if cref.origin == Origin.CREF
    return cref
  end
  while !(cref isa COMPONENT_REF_CREF) && cref.restCref.origin != Origin.CREF
    tmp = Subscript[mapExp(s, func) for s in cref.subscripts]
    subs = arrayList(tmp)
    rest = cref.restCref
    @assign cref.restCref = rest
    @assign cref.subscripts = subs
    cref = rest
  end
  return outCref
end

function mapCallIterators(iters::List{<:Tuple{<:InstNode, Expression}}, @nospecialize(func::Function)) ::List{Tuple{InstNode, Expression}}
  if listEmpty(iters)
    return iters
  end
  local anyChanged = false
  for i in iters
    (_, exp) = i
    new_exp = map(exp, func)
    if !referenceEq(new_exp, exp)
      anyChanged = true
      break
    end
  end
  if !anyChanged
    return iters
  end
  local outIters::List{Tuple{InstNode, Expression}} = nil
  local node::InstNode
  local exp::Expression
  local new_exp::Expression
  for i in iters
     (node, exp) = i
     new_exp = map(exp, func)
     outIters = Cons{Tuple{InstNode, Expression}}(if referenceEq(new_exp, exp)
                             i
                             else
                             (node, new_exp)
                             end, outIters)
  end
   outIters = listReverseInPlace(outIters)
  outIters
end

@nospecializeinfer function mapCall(@nospecialize(call::Call), @nospecialize(func::Function)) ::Call
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
    @match call begin
      UNTYPED_CALL(__)  => begin
        local origArgs = call.arguments
        local newArgs = origArgs
        for i in eachindex(origArgs)
          local orig = origArgs[i]
          local mapped = map(orig, func)
          if !referenceEq(orig, mapped)
            if newArgs === origArgs
              newArgs = copy(origArgs)
            end
            newArgs[i] = mapped
          end
        end
        local origNargs = call.named_args
        local newNargs = origNargs
        for i in eachindex(origNargs)
          local (s, e) = origNargs[i]
          local new_e = map(e, func)
          if !referenceEq(e, new_e)
            if newNargs === origNargs
              newNargs = copy(origNargs)
            end
            newNargs[i] = (s, new_e)
          end
        end
        if newArgs === origArgs && newNargs === origNargs
          call
        else
          UNTYPED_CALL(call.ref, newArgs, newNargs, call.call_scope)
        end
      end

      ARG_TYPED_CALL(__)  => begin
        targs = nil
        tnargs = nil
        for arg in call.arguments
           (e, t, v) = arg
          e = map(e, func)
          targs = Cons{TypedArg}((e, t, v), targs)
        end
        for arg in call.named_args
           (s, e, t, v) = arg
          e = map(e, func)
          tnargs = Cons{TypedNamedArg}((s, e, t, v), tnargs)
        end
        ARG_TYPED_CALL(call.ref, listReverseInPlace(targs), listReverseInPlace(tnargs), call.call_scope)
      end

      TYPED_CALL(__)  => begin
        local newArgs = mapPreservingEq(call.arguments, e -> map(e, func))
        if newArgs === call.arguments
          call
        else
          TYPED_CALL(call.fn, call.ty, call.var, newArgs, call.attributes)
        end
      end

      UNTYPED_ARRAY_CONSTRUCTOR(__)  => begin
        e = map(call.exp, func)
        iters = mapCallIterators(call.iters, func)
        if referenceEq(e, call.exp) && referenceEq(iters, call.iters)
          call
        else
          UNTYPED_ARRAY_CONSTRUCTOR(e, iters)
        end
      end

      TYPED_ARRAY_CONSTRUCTOR(__)  => begin
        e = map(call.exp, func)
        iters = mapCallIterators(call.iters, func)
        if referenceEq(e, call.exp) && referenceEq(iters, call.iters)
          call
        else
          TYPED_ARRAY_CONSTRUCTOR(call.ty, call.var, e, iters)
        end
      end

      UNTYPED_REDUCTION(__)  => begin
        e = map(call.exp, func)
        iters = mapCallIterators(call.iters, func)
        if referenceEq(e, call.exp) && referenceEq(iters, call.iters)
          call
        else
          UNTYPED_REDUCTION(call.ref, e, iters)
        end
      end

      TYPED_REDUCTION(__)  => begin
        e = map(call.exp, func)
        iters = mapCallIterators(call.iters, func)
        default_exp = mapOpt(call.defaultExp, func)
        fold_exp = Util.applyTuple31(call.foldExp, (oe) -> mapOpt(oe, func))
        TYPED_REDUCTION(call.fn, call.ty, call.var, e, iters, default_exp, fold_exp)
      end
    end
  end
  outCall
end

function mapOpt(exp::Option{<:Expression}, @nospecialize(func::Function)) ::Option{Expression}
  local outExp::Option{Expression}

  local e::Expression

   outExp = begin
    @match exp begin
      SOME(e)  => begin
        SOME(map(e, func))
      end

      _  => begin
        exp
      end
    end
  end
  outExp
end

"""
```
map(@nospecialize(exp::Expression), @nospecialize(func::Function))
```
Applies the function `func`, to the expression `exp`.
This function traverse the expression and creates new nodes when needed.

The function passed to this function is expected to take an expression as the argument and return
one expression.
"""
@nospecializeinfer function map(@nospecialize(exp::Expression), @nospecialize(func::MapFunc))
  local outExp::Expression
   outExp = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local e4::Expression
    @match exp begin
      CLKCONST_EXPRESSION(INTEGER_CLOCK(e1, e2))  => begin
         e3 = map(e1, func)
         e4 = map(e2, func)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          exp
        else
          CLKCONST_EXPRESSION(INTEGER_CLOCK(e3, e4))
        end
      end

      CLKCONST_EXPRESSION(REAL_CLOCK(e1))  => begin
         e2 = map(e1, func)
        if referenceEq(e1, e2)
          exp
        else
          CLKCONST_EXPRESSION(REAL_CLOCK(e2))
        end
      end
      CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e1, e2))  => begin
         e3 = map(e1, func)
         e4 = map(e2, func)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          exp
        else
          CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e3, e4))
        end
      end
      CLKCONST_EXPRESSION(SOLVER_CLOCK(e1, e2))  => begin
         e3 = map(e1, func)
         e4 = map(e2, func)
        if referenceEq(e1, e3) && referenceEq(e2, e4)
          exp
        else
          CLKCONST_EXPRESSION(SOLVER_CLOCK(e3, e4))
        end
      end
      CREF_EXPRESSION(__)  => begin
        reuseIfRefEqual(exp, exp.cref, mapCref(exp.cref, func), c -> CREF_EXPRESSION(exp.ty, c))
      end

      ARRAY_EXPRESSION(__)  => begin
        local newElements = mapPreservingEq(exp.elements, e -> map(e, func))
        if newElements === exp.elements
          exp
        else
          ARRAY_EXPRESSION(exp.ty, newElements, exp.literal)
        end
      end

      MATRIX_EXPRESSION(__)  => begin
        MATRIX_EXPRESSION(list(list(map(e, func) for e in row) for row in exp.elements))
      end

      RANGE_EXPRESSION(step = SOME(e2))  => begin
         e1 = map(exp.start, func)
         e4 = map(e2, func)
         e3 = map(exp.stop, func)
        if referenceEq(exp.start, e1) && referenceEq(e2, e4) && referenceEq(exp.stop, e3)
          exp
        else
          RANGE_EXPRESSION(exp.ty, e1, SOME(e4), e3)
        end
      end

      RANGE_EXPRESSION(__)  => begin
         e1 = map(exp.start, func)
         e3 = map(exp.stop, func)
        if referenceEq(exp.start, e1) && referenceEq(exp.stop, e3)
          exp
        else
          RANGE_EXPRESSION(exp.ty, e1, NONE(), e3)
        end
      end

      TUPLE_EXPRESSION(__)  => begin
        TUPLE_EXPRESSION(exp.ty, list(map(e, func) for e in exp.elements))
      end

      RECORD_EXPRESSION(__)  => begin
        local newElements = mapPreservingEq(exp.elements, e -> map(e, func))
        if newElements === exp.elements
          exp
        else
          RECORD_EXPRESSION(exp.path, exp.ty, newElements)
        end
      end

      CALL_EXPRESSION(__)  => begin
        reuseIfRefEqual(exp, exp.call, mapCall(exp.call, func), c -> CALL_EXPRESSION(c))
      end

      SIZE_EXPRESSION(dimIndex = SOME(e2))  => begin
         e1 = map(exp.exp, func)
         e3 = map(e2, func)
        if referenceEq(exp.exp, e1) && referenceEq(e2, e3)
          exp
        else
          SIZE_EXPRESSION(e1, SOME(e3))
        end
      end

      SIZE_EXPRESSION(__)  => begin
         e1 = map(exp.exp, func)
        if referenceEq(exp.exp, e1)
          exp
        else
          SIZE_EXPRESSION(e1, NONE())
        end
      end

      BINARY_EXPRESSION(__)  => begin
         e1 = map(exp.exp1, func)
         e2 = map(exp.exp2, func)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          BINARY_EXPRESSION(e1, exp.operator, e2)
        end
      end

      UNARY_EXPRESSION(__)  => begin
         e1 = map(exp.exp, func)
        if referenceEq(exp.exp, e1)
          exp
        else
          UNARY_EXPRESSION(exp.operator, e1)
        end
      end

      LBINARY_EXPRESSION(__)  => begin
         e1 = map(exp.exp1, func)
         e2 = map(exp.exp2, func)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          LBINARY_EXPRESSION(e1, exp.operator, e2)
        end
      end

      LUNARY_EXPRESSION(__)  => begin
         e1 = map(exp.exp, func)
        if referenceEq(exp.exp, e1)
          exp
        else
          LUNARY_EXPRESSION(exp.operator, e1)
        end
      end

      RELATION_EXPRESSION(__)  => begin
         e1 = map(exp.exp1, func)
         e2 = map(exp.exp2, func)
        if referenceEq(exp.exp1, e1) && referenceEq(exp.exp2, e2)
          exp
        else
          RELATION_EXPRESSION(e1, exp.operator, e2)
        end
      end

      IF_EXPRESSION(__)  => begin
         e1 = map(exp.condition, func)
         e2 = map(exp.trueBranch, func)
         e3 = map(exp.falseBranch, func)
        if referenceEq(exp.condition, e1) && referenceEq(exp.trueBranch, e2) && referenceEq(exp.falseBranch, e3)
          exp
        else
          IF_EXPRESSION(e1, e2, e3)
        end
      end

      CAST_EXPRESSION(__)  => begin
         e1 = map(exp.exp, func)
        if referenceEq(exp.exp, e1)
          exp
        else
          CAST_EXPRESSION(exp.ty, e1)
        end
      end

      UNBOX_EXPRESSION(__)  => begin
         e1 = map(exp.exp, func)
        if referenceEq(exp.exp, e1)
          exp
        else
          UNBOX_EXPRESSION(e1, exp.ty)
        end
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        SUBSCRIPTED_EXP_EXPRESSION(map(exp.exp, func), list(mapExp(s, func) for s in exp.subscripts), exp.ty)
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
         e1 = map(exp.tupleExp, func)
        if referenceEq(exp.tupleExp, e1)
          exp
        else
          TUPLE_ELEMENT_EXPRESSION(e1, exp.index, exp.ty)
        end
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
         e1 = map(exp.recordExp, func)
        if referenceEq(exp.recordExp, e1)
          exp
        else
          RECORD_ELEMENT_EXPRESSION(e1, exp.index, exp.fieldName, exp.ty)
        end
      end

      BOX_EXPRESSION(__)  => begin
         e1 = map(exp.exp, func)
        if referenceEq(exp.exp, e1)
          exp
        else
          BOX_EXPRESSION(e1)
        end
      end

      MUTABLE_EXPRESSION(__)  => begin
        P_Pointer.update(exp.exp, map(P_Pointer.access(exp.exp), func))
        exp
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        expArgs = list(map(e, func) for e in exp.args)
        PARTIAL_FUNCTION_APPLICATION_EXPRESSION(exp.fn, expArgs, exp.argNames, exp.ty)
      end

      BINDING_EXP(__)  => begin
         e1 = map(exp.exp, func)
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
  outExp = func(outExp)
  outExp
end

"""Adding an alias for map. For some reason Julia struggles to find it in certain situations."""
function mapExpAlias(@nospecialize(exp::Expression), func::Function)
  return map(exp, func)
end

@nospecializeinfer function dimensionCount(@nospecialize(exp::Expression))
  local dimCount::Int
   dimCount = begin
    @match exp begin
      ARRAY_EXPRESSION(ty = TYPE_UNKNOWN(__))  => begin
        1 + dimensionCount(listHead(exp.elements))
      end

      ARRAY_EXPRESSION(__)  => begin
        dimensionCount(exp.ty)
      end

      RANGE_EXPRESSION(__)  => begin
        dimensionCount(exp.ty)
      end

      SIZE_EXPRESSION(dimIndex = NONE())  => begin
        dimensionCount(exp.exp)
      end

      CAST_EXPRESSION(__)  => begin
        dimensionCount(exp.exp)
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        dimensionCount(exp.ty)
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        dimensionCount(exp.ty)
      end

      _  => begin
        0
      end
    end
  end
  #=  TODO: Add more expressions.
  =#
  dimCount
end

function toDAEValueRecord(@nospecialize(ty::M_Type), path::Absyn.Path, args::List{<:Expression}) ::Values.Value
  local value::Values.Value

  local field_names::List{String} = nil
  local arg::Expression
  local rest_args::List{Expression} = args
  local values::List{Values.Value} = nil

  for field in recordFields(ty)
    @match _cons(arg, rest_args) = rest_args
     () = begin
      @match field begin
        FIELD_INPUT(__)  => begin
           field_names = _cons(field.name, field_names)
           values = _cons(toDAEValue(arg), values)
          ()
        end

        _  => begin
          ()
        end
      end
    end
  end
   field_names = listReverseInPlace(field_names)
   values = listReverseInPlace(values)
   value = Values.RECORD(path, values, field_names, -1)
  value
end

@nospecializeinfer function toDAEValue(@nospecialize(exp::Expression)) ::Values.Value
  local value::Values.Value

   value = begin
    local ty::M_Type
    local vals::List{Values.Value}
    local fields::List{Field}
    local field_names::List{String}
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        Values.INTEGER_EXPRESSION(exp.value)
      end

      REAL_EXPRESSION(__)  => begin
        Values.REAL_EXPRESSION(exp.value)
      end

      STRING_EXPRESSION(__)  => begin
        Values.STRING_EXPRESSION(exp.value)
      end

      BOOLEAN_EXPRESSION(__)  => begin
        Values.BOOL(exp.value)
      end

      ENUM_LITERAL_EXPRESSION(ty = ty && TYPE_ENUMERATION(__))  => begin
        Values.ENUM_LITERAL(AbsynUtil.suffixPath(ty.typePath, exp.name), exp.index)
      end

      ARRAY_EXPRESSION(__)  => begin
        vals = list(toDAEValue(e) for e in exp.elements)
        ValuesUtil.makeArray(vals)
      end

      RECORD_EXPRESSION(__)  => begin
        toDAEValueRecord(exp.ty, exp.path, exp.elements)
      end

      _  => begin
        Error.assertion(false, getInstanceName() + " got unhandled expression " + toString(exp), sourceInfo())
        fail()
      end
    end
  end
  value
end

function toDAEValueOpt(exp::Option{<:Expression}) ::Option{Values.Value}
  local value::Option{Values.Value} = Util.applyOption(exp, toDAEValue)
  value
end

function toDAERecord(@nospecialize(ty::M_Type), path::Absyn.Path, args::Vector{<:Expression}) ::DAE.Exp
  toDAERecord(ty, path, list(args...))
end

function toDAERecord(@nospecialize(ty::M_Type), path::Absyn.Path, args::List{<:Expression}) ::DAE.Exp
  local exp::DAE.Exp

  local field_names::List{String} = nil
  local arg::Expression
  local rest_args::List{Expression} = args
  local dargs::List{DAE.Exp} = nil

  for field in recordFields(ty)
    @match _cons(arg, rest_args) = rest_args
     () = begin
      @match field begin
        FIELD_INPUT(__)  => begin
           field_names = _cons(field.name, field_names)
           dargs = _cons(toDAE(arg), dargs)
          ()
        end

        FIELD_LOCAL(__)  => begin
          #=  TODO: Constants/parameters shouldn't be added to record expressions
          =#
          #=        since that causes issues with the backend, but removing them
          =#
          #=        currently causes even worse issues.
          =#
           field_names = _cons(field.name, field_names)
           dargs = _cons(toDAE(arg), dargs)
          ()
        end

        _  => begin
          ()
        end
      end
    end
  end
   field_names = listReverseInPlace(field_names)
   dargs = listReverseInPlace(dargs)
   exp = DAE.RECORD(path, dargs, field_names, toDAE(ty))
  exp
end

@nospecializeinfer function toDAE(@nospecialize(exp::Expression))
  local dexp::DAE.Exp
  local changed::Bool = true
   dexp = begin
    local ty::M_Type
    local daeOp::DAE.Operator
    local swap::Bool
    local dae1::DAE.Exp
    local dae2::DAE.Exp
    local names::List{String}
    local fn::M_Function
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        DAE.ICONST(exp.value)
      end

      REAL_EXPRESSION(__)  => begin
        DAE.RCONST(exp.value)
      end

      STRING_EXPRESSION(__)  => begin
        DAE.SCONST(exp.value)
      end

      BOOLEAN_EXPRESSION(__)  => begin
        DAE.BCONST(exp.value)
      end

      ENUM_LITERAL_EXPRESSION(ty = ty && TYPE_ENUMERATION(__))  => begin
        DAE.ENUM_LITERAL(AbsynUtil.suffixPath(ty.typePath, exp.name), exp.index)
      end

      CLKCONST_EXPRESSION(__)  => begin
        DAE.CLKCONST_EXPRESSION(toDAE(exp.clk))
      end

      CREF_EXPRESSION(__)  => begin
        DAE.CREF(toDAE(exp.cref), toDAE(exp.ty))
      end

      TYPENAME_EXPRESSION(__)  => begin
        toDAE(expandTypename(exp.ty))
      end

      ARRAY_EXPRESSION(__)  => begin
        DAE.ARRAY(toDAE(exp.ty), isScalarArray(exp.ty), list(toDAE(e) for e in exp.elements))
      end

      RECORD_EXPRESSION(__)  => begin
        toDAERecord(exp.ty, exp.path, exp.elements)
      end

      RANGE_EXPRESSION(__)  => begin
        DAE.RANGE(toDAE(exp.ty), toDAE(exp.start), if isSome(exp.step)
                  SOME(toDAE(Util.getOption(exp.step)))
                  else
                  NONE()
                  end, toDAE(exp.stop))
      end

      TUPLE_EXPRESSION(__)  => begin
        DAE.TUPLE(list(toDAE(e) for e in exp.elements))
      end

      CALL_EXPRESSION(__)  => begin
        toDAE(exp.call)
      end

      SIZE_EXPRESSION(__)  => begin
        DAE.SIZE(toDAE(exp.exp), if isSome(exp.dimIndex)
                 SOME(toDAE(Util.getOption(exp.dimIndex)))
                 else
                 NONE()
                 end)
      end

      BINARY_EXPRESSION(__)  => begin
        #=  END() doesn't have a DAE representation.
        =#
         daeOp = toDAE(exp.operator)
        swap = false #=TODO. Handle arrays better Implicit stupid metamodelica=#
         dae1 = toDAE(exp.exp1)
         dae2 = toDAE(exp.exp2)
        DAE.BINARY(if swap
                   dae2
                   else
                   dae1
                   end, daeOp, if swap
                   dae1
                   else
                   dae2
                   end)
      end

      UNARY_EXPRESSION(__)  => begin
        DAE.UNARY(toDAE(exp.operator), toDAE(exp.exp))
      end

      LBINARY_EXPRESSION(__)  => begin
        DAE.LBINARY(toDAE(exp.exp1), toDAE(exp.operator), toDAE(exp.exp2))
      end

      LUNARY_EXPRESSION(__)  => begin
        DAE.LUNARY(toDAE(exp.operator), toDAE(exp.exp))
      end

      RELATION_EXPRESSION(__)  => begin
        DAE.RELATION(toDAE(exp.exp1), toDAE(exp.operator), toDAE(exp.exp2), -1, NONE())
      end

      IF_EXPRESSION(__)  => begin
        DAE.IFEXP(toDAE(exp.condition), toDAE(exp.trueBranch), toDAE(exp.falseBranch))
      end

      CAST_EXPRESSION(__)  => begin
        DAE.CAST(toDAE(exp.ty), toDAE(exp.exp))
      end

      BOX_EXPRESSION(__)  => begin
        DAE.BOX(toDAE(exp.exp))
      end

      UNBOX_EXPRESSION(__)  => begin
        DAE.UNBOX(toDAE(exp.exp), toDAE(exp.ty))
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        DAE.ASUB(toDAE(exp.exp), list(toDAEExp(s) for s in exp.subscripts))
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        DAE.TSUB(toDAE(exp.tupleExp), exp.index, toDAE(exp.ty))
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        DAE.RSUB(toDAE(exp.recordExp), exp.index, exp.fieldName, toDAE(exp.ty))
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        fns = typeRefCache(exp.fn)
        fn = fns[1]
        DAE.PARTEVALFUNCTION(nameConsiderBuiltin(fn), list(toDAE(arg) for arg in exp.args), toDAE(exp.ty), toDAE(TYPE_FUNCTION(fn, FunctionType.FUNCTIONAL_VARIABLE)))
      end

      BINDING_EXP(__)  => begin
        toDAE(exp.exp)
      end

      MUTABLE_EXPRESSION(__)  => begin
        toDAE(P_Pointer.access(exp.exp))
      end

      _  => begin
        Error.assertion(false, getInstanceName() + " got unknown expression '" + toString(exp) + "'", sourceInfo())
        fail()
      end
    end
  end
  dexp
end

function toDAEOpt(exp::Option{<:Expression}) ::Option{DAE.Exp}
  local dexp::Option{DAE.Exp}

   dexp = begin
    local e::Expression
    @match exp begin
      SOME(e)  => begin
        SOME(toDAE(e))
      end

      _  => begin
        NONE()
      end
    end
  end
  dexp
end

function isNonAssociativeExp(@nospecialize(exp::Expression)) ::Bool
  local isAssociative::Bool

   isAssociative = begin
    @match exp begin
      BINARY_EXPRESSION(__)  => begin
        isNonAssociative(exp.operator)
      end

      LBINARY_EXPRESSION(__)  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  isAssociative
end

function isAssociativeExp(@nospecialize(exp::Expression)) ::Bool
  local isAssoc::Bool
  isAssoc = begin
    @match exp begin
      BINARY_EXPRESSION(__)  => begin
        isAssociative(exp.operator)
      end
      LBINARY_EXPRESSION(__)  => begin
        true
      end
      _  => begin
        false
      end
    end
  end
  isAssoc
end

function priority(@nospecialize(exp::Expression), lhs::Bool) ::Int
  local priorityVar::Int

  priorityVar = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        if exp.value < 0
          4
        else
          0
        end
      end

      REAL_EXPRESSION(__)  => begin
        if exp.value < 0.0
          4
        else
          0
        end
      end

      BINARY_EXPRESSION(__)  => begin
        priority(exp.operator, lhs)
      end

      UNARY_EXPRESSION(__)  => begin
        4
      end

      LBINARY_EXPRESSION(__)  => begin
        priority(exp.operator, lhs)
      end

      LUNARY_EXPRESSION(__)  => begin
        7
      end

      RELATION_EXPRESSION(__)  => begin
        6
      end

      RANGE_EXPRESSION(__)  => begin
        10
      end

      IF_EXPRESSION(__)  => begin
        11
      end

      _  => begin
        0
      end
    end
  end
  priorityVar
end

"""  Helper function to toString, prints an operator and adds parentheses as needed. """
function operandFlatString(@nospecialize(operand::Expression), @nospecialize(operator::Expression), lhs::Bool; inFunction = false)
  local str::String
  local operand_prio::Int
  local operator_prio::Int
  local parenthesize::Bool = false
  str = toFlatString(operand; inFunction = inFunction)
  operand_prio = priority(operand, lhs)
  if operand_prio == 4
    parenthesize = true
  else
    operator_prio = priority(operator, lhs)
    if operand_prio > operator_prio
      parenthesize = true
    elseif operand_prio == operator_prio
      parenthesize = if lhs
        isNonAssociativeExp(operand)
      else
        ! isAssociativeExp(operand)
      end
    end
  end
  if parenthesize
    str = "(" + str + ")"
  end
  str
end

"""Helper function to toString, prints an operator and adds parentheses as needed."""
function operandString(@nospecialize(operand::Expression), @nospecialize(operator::Expression), lhs::Bool) ::String
  local str::String

  local operand_prio::Int
  local operator_prio::Int
  local parenthesize::Bool = false

   str = toString(operand)
   operand_prio = priority(operand, lhs)
  if operand_prio == 4
     parenthesize = true
  else
     operator_prio = priority(operator, lhs)
    if operand_prio > operator_prio
       parenthesize = true
    elseif operand_prio == operator_prio
       parenthesize = if lhs
        isNonAssociativeExp(operand)
      else
        ! isAssociativeExp(operand)
      end
    end
  end
  if parenthesize
     str = "(" + str + ")"
  end
  str
end

function toFlatSubscriptedString(@nospecialize(exp::Expression), subs::List{<:Subscript}; inFunction = false)
  local str::String
  local exp_ty::M_Type
  local sub_tyl::List{M_Type}
  local dims::List{Dimension}
  local strl::List{String}
  local name::String
  exp_ty = typeOf(exp)
  dims = ListUtil.firstN(arrayDims(exp_ty), listLength(subs))
  sub_tyl = list(subscriptType(d) for d in dims)
  name = subscriptedTypeName(exp_ty, sub_tyl)
  strl = list(")")
  for s in subs
    strl = _cons(toFlatString(s; inFunction = inFunction), strl)
    strl = _cons(",", strl)
  end
  strl = _cons(toFlatString(exp; inFunction = inFunction), strl)
  strl = _cons("'(", strl)
  strl = _cons(name, strl)
  strl = _cons("'", strl)
  str = stringAppendList(strl)
  str
end


function toFlatString(exp::BINDING_EXP; inFunction = false)
  toFlatString(exp.exp; inFunction = inFunction)
end

@nospecializeinfer function toFlatString(exp::Expression; inFunction = false)
  local str::String
  local t::M_Type
  local clk::ClockKind
  str = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        intString(exp.value)
      end

      REAL_EXPRESSION(__)  => begin
        realString(exp.value)
      end

      STRING_EXPRESSION(__)  => begin
        "\"" + exp.value + "\""
      end

      BOOLEAN_EXPRESSION(__)  => begin
        boolString(exp.value)
      end

      ENUM_LITERAL_EXPRESSION(ty = t && TYPE_ENUMERATION(__))  => begin
        "'" + AbsynUtil.pathString(t.typePath) + "'." + exp.name
      end

      CLKCONST_EXPRESSION(clk)  => begin
        toFlatString(clk)
      end

      CREF_EXPRESSION(__)  => begin
        # #@info "cref expr to string..."
        res = toFlatString(exp.cref; inFunction = inFunction)
        #=
        There is a current bug that if we have scalarized the model,
        the subscript for parameters are not always set correctly for cref expressions.
        Here we check if it is scalarized
        =#
        if Base.contains(res, "load.V_nom")
          @info "It contained it..."  toString(exp.cref)
          #global TMP = getOriginCref(exp.cref)
          dims = TMP.ty.dimensions
          println(dims)
        end
        toFlatString(exp.cref; inFunction = inFunction)
      end

      TYPENAME_EXPRESSION(__)  => begin
        typenameString(arrayElementType(exp.ty))
      end

      ARRAY_EXPRESSION(__)  => begin
        if !isempty(exp.elements)
          "{" +  stringDelimitList(list(toFlatString(e; inFunction = inFunction)
                                        for e in exp.elements), ", ") + "}"
        else
          "{/* Empty array expression*/}"
        end
      end

      MATRIX_EXPRESSION(__)  => begin
        if !isempty(exp.elements)
          local inner = stringDelimitList(list(toFlatString(e; inFunction = inFunction) for e in el), ", ")
          local delimList =  stringDelimitList(list(inner for el in exp.elements), "; ")
          string("[",
                 delimList
                 ,  "]")
         else
           "/*[Empty matrix expression*/]"
         end
      end

      RANGE_EXPRESSION(__)  => begin
        res = string(operandFlatString(exp.start, exp, false; inFunction = inFunction),
                     (if isSome(exp.step)
                        ":" + operandFlatString(Util.getOption(exp.step), exp, false; inFunction = inFunction)
                      else
                        ""
                      end) + ":" + operandFlatString(exp.stop, exp, false; inFunction = inFunction))
        res
      end

      TUPLE_EXPRESSION(__)  => begin
        "(" + stringDelimitList(list(toFlatString(e; inFunction = inFunction) for e in exp.elements), ", ") + ")"
      end

      RECORD_EXPRESSION(__)  => begin
        #= Use scopePath from the type's class node to get a consistent short path,
           avoiding the root model prefix that may appear in exp.path due to
           instFunctionRef caching order (toPath includes root, scopePath does not). =#
        local recordPath = if exp.ty isa TYPE_COMPLEX && exp.ty.cls isa CLASS_NODE
          scopePath(exp.ty.cls)
        else
          exp.path
        end
        local flatStringCall = x -> toFlatString(x, inFunction = inFunction)
        res = ListUtil.toString(arrayList(exp.elements), flatStringCall,
                          "'" + AbsynUtil.pathString(recordPath), "'(", ", ", ")", true)
      end

      CALL_EXPRESSION(__)  => begin
        toFlatString(exp.call; inFunction = inFunction)
      end

      SIZE_EXPRESSION(__)  => begin
        string("size(", toFlatString(exp.exp; inFunction = inFunction)
               ,(if isSome(exp.dimIndex)
                   ", " + toFlatString(Util.getOption(exp.dimIndex); inFunction = inFunction)
                 else
                   ""
                 end), ")")
      end

      END_EXPRESSION(__)  => begin
        "end"
      end

      BINARY_EXPRESSION(__)  => begin
        string(operandFlatString(exp.exp1, exp, true; inFunction = inFunction),
               symbol(exp.operator),
               operandFlatString(exp.exp2, exp, false; inFunction = inFunction))
      end

      UNARY_EXPRESSION(__)  => begin
        "(" + symbol(exp.operator, "") + operandFlatString(exp.exp, exp, false; inFunction = inFunction) + ")"
      end

      LBINARY_EXPRESSION(__)  => begin
        string(operandFlatString(exp.exp1, exp, true; inFunction = inFunction),
               symbol(exp.operator)
               ,operandFlatString(exp.exp2, exp, false; inFunction = inFunction))
      end

      LUNARY_EXPRESSION(__)  => begin
        symbol(exp.operator, "") + " " + operandFlatString(exp.exp, exp, false; inFunction = inFunction)
      end

      RELATION_EXPRESSION(__)  => begin
        operandFlatString(exp.exp1, exp, true; inFunction = inFunction) + symbol(exp.operator) + operandFlatString(exp.exp2, exp, false; inFunction = inFunction)
      end

      IF_EXPRESSION(__)  => begin
        "if " + toFlatString(exp.condition; inFunction = inFunction) + " then " + toFlatString(exp.trueBranch; inFunction = inFunction) + " else " + toFlatString(exp.falseBranch; inFunction = inFunction)
      end

      UNBOX_EXPRESSION(__)  => begin
        "UNBOX_EXPRESSION(" + toFlatString(exp.exp; inFunction = inFunction) + ")"
      end

      BOX_EXPRESSION(__)  => begin
        "BOX_EXPRESSION(" + toFlatString(exp.exp; inFunction = inFunction) + ")"
      end

      CAST_EXPRESSION(__)  => begin
        toFlatString(exp.exp; inFunction = inFunction)
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        toFlatSubscriptedString(exp.exp, exp.subscripts; inFunction = inFunction)
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        #= In flat Modelica, assigning a scalar from a multi-output function call
           uses simple assignment (first output), not [1] indexing. =#
        if exp.index == 1
          toFlatString(exp.tupleExp; inFunction = inFunction)
        else
          toFlatString(exp.tupleExp; inFunction = inFunction) + "[" + intString(exp.index) + "]"
        end
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        toFlatString(exp.recordExp; inFunction = inFunction) + "[field: " + exp.fieldName + "]"
      end

      MUTABLE_EXPRESSION(__)  => begin
        toFlatString(P_Pointer.access(exp.exp); inFunction = inFunction)
      end

      EMPTY_EXPRESSION(__)  => begin
        "#EMPTY#"
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        "function " + toFlatString(exp.fn; inFunction = inFunction) + "(" + stringDelimitList(list(@do_threaded_for n + " = " + toFlatString(a; inFunction = inFunction) (a, n) (exp.args, exp.argNames)), ", ") + ")"
      end
      _  => begin
        anyString(exp)
      end
    end
  end
  str
end

@nospecializeinfer function toString(@nospecialize(exp::Expression))
  local str::String
  local t::M_Type
  local clk::ClockKind
  str = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        intString(exp.value)
      end

      REAL_EXPRESSION(__)  => begin
        realString(exp.value)
      end

      STRING_EXPRESSION(__)  => begin
        "\"" + exp.value + "\""
      end

      BOOLEAN_EXPRESSION(__)  => begin
        boolString(exp.value)
      end

      ENUM_LITERAL_EXPRESSION(ty = t && TYPE_ENUMERATION(__))  => begin
        AbsynUtil.pathString(t.typePath) + "." + exp.name
      end

      CLKCONST_EXPRESSION(clk)  => begin
        toString(clk)
      end

      CREF_EXPRESSION(__)  => begin
        toString(exp.cref)
      end

      TYPENAME_EXPRESSION(__)  => begin
        typenameString(arrayElementType(exp.ty))
      end

      ARRAY_EXPRESSION(__)  => begin
        if !isempty(exp.elements)
          "{" +  stringDelimitList(list(toString(e) for e in exp.elements), ", ") + "}"
        else
          "{/*Empty Array Expression*/}"
        end
      end

      MATRIX_EXPRESSION(__)  => begin
        if !isempty(exp.elements)
          "[" + stringDelimitList(list(stringDelimitList(list(toString(e) for e in el), ", ") for el in exp.elements), "; ") + "]"
        else
          "*/ Empty Matrix Expression */"
        end
      end

      RANGE_EXPRESSION(__)  => begin
        operandString(exp.start, exp, false) + (if isSome(exp.step)
                                                        ":" + operandString(Util.getOption(exp.step), exp, false)
                                                      else
                                                        ""
                                                      end) + ":" + operandString(exp.stop, exp, false)
      end

      TUPLE_EXPRESSION(__)  => begin
        "(" + stringDelimitList(list(toString(e) for e in exp.elements), ", ") + ")"
      end

      RECORD_EXPRESSION(__)  => begin
        ArrayUtil.toString(exp.elements, toString, AbsynUtil.pathString(exp.path), "(", ", ", ")", true)
      end

      CALL_EXPRESSION(__)  => begin
        toString(exp.call)
      end

      SIZE_EXPRESSION(__)  => begin
        "size(" + toString(exp.exp) + (if isSome(exp.dimIndex)
                                       ", " + toString(Util.getOption(exp.dimIndex))
                                       else
                                       ""
                                       end) + ")"
      end

      END_EXPRESSION(__)  => begin
        "end"
      end

      BINARY_EXPRESSION(__)  => begin
        operandString(exp.exp1, exp, true) + symbol(exp.operator) + operandString(exp.exp2, exp, false)
      end

      UNARY_EXPRESSION(__)  => begin
        symbol(exp.operator, "") + operandString(exp.exp, exp, false)
      end

      LBINARY_EXPRESSION(__)  => begin
        operandString(exp.exp1, exp, true) + symbol(exp.operator) + operandString(exp.exp2, exp, false)
      end

      LUNARY_EXPRESSION(__)  => begin
        symbol(exp.operator, "") + " " + operandString(exp.exp, exp, false)
      end

      RELATION_EXPRESSION(__)  => begin
        operandString(exp.exp1, exp, true) + symbol(exp.operator) + operandString(exp.exp2, exp, false)
      end

      IF_EXPRESSION(__)  => begin
        "if " + toString(exp.condition) + " then " + toString(exp.trueBranch) + " else " + toString(exp.falseBranch)
      end

      UNBOX_EXPRESSION(__)  => begin
        "UNBOX_EXPRESSION(" + toString(exp.exp) + ")"
      end

      BOX_EXPRESSION(__)  => begin
        "BOX_EXPRESSION(" + toString(exp.exp) + ")"
      end

      CAST_EXPRESSION(__)  => begin
        #if Flags.isSet(Flags.NF_API) Changes by me, John
        toString(exp.exp)
#        else
#          "CAST_EXPRESSION(" + toString(exp.ty) + ", " + toString(exp.exp) + ")"
 #       end
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        toString(exp.exp) + toStringList(exp.subscripts)
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        toString(exp.tupleExp) + "[" + intString(exp.index) + "]"
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        toString(exp.recordExp) + "[field: " + exp.fieldName + "]"
      end

      MUTABLE_EXPRESSION(__)  => begin
        toString(P_Pointer.access(exp.exp))
      end

      EMPTY_EXPRESSION(__)  => begin
        "#EMPTY#"
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        local argStrs = nil
        local restArgs = exp.args
        local restNames = exp.argNames
        while !listEmpty(restArgs)
          @match _cons(a, restArgs) = restArgs
          @match _cons(n, restNames) = restNames
          argStrs = _cons(n + " = " + toString(a), argStrs)
        end
        "function " + toString(exp.fn) + "(" + stringDelimitList(listReverseInPlace(argStrs), ", ") + ")"
      end

      BINDING_EXP(__)  => begin
        toString(exp.exp)
      end

      _  => begin
        anyString(exp)
      end
    end
  end
  str
end

function toStringTyped(@nospecialize(exp::Expression)) ::String
  local str::String

   str = "/*" + toString(typeOf(exp)) + "*/ " + toString(exp)
  str
end

function toInteger(@nospecialize(exp::Expression)) ::Int
  local i::Int

   i = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        exp.value
      end

      BOOLEAN_EXPRESSION(__)  => begin
        if exp.value
          1
        else
          0
        end
      end

      ENUM_LITERAL_EXPRESSION(__)  => begin
        exp.index
      end
    end
  end
  i
end

function makeEnumLiterals(@nospecialize(enumType::M_Type)) ::List{Expression}
  local literals::List{Expression}

  local lits::List{String}

  @match TYPE_ENUMERATION(literals = lits) = enumType
   literals = list(@do_threaded_for ENUM_LITERAL_EXPRESSION(enumType, l, i) (l, i) (lits, 1:listLength(lits)))
  literals
end

function makeEnumLiteral(@nospecialize(enumType::M_Type), index::Int) ::Expression
  local literal::Expression

  local literals::List{String}

  @match TYPE_ENUMERATION(literals = literals) = enumType
   literal = ENUM_LITERAL_EXPRESSION(enumType, listGet(literals, index), index)
  literal
end

function arrayFromList(inExps::List{<:Expression}, @nospecialize(elemTy::M_Type), inDims::List{<:Dimension}) ::Expression
  local outExp::Expression
  outExp = arrayFromList_impl(inExps, elemTy, listReverse(inDims))
  outExp
end

function arrayFromList_impl(inExps::List{<:Expression}, @nospecialize(elemTy::M_Type), inDims::List{<:Dimension}) ::Expression
  local outExp::Expression
  local ldim::Dimension
  local restdims::List{Dimension}
  local ty::M_Type
  local newlst::List{Expression}
  local partexps::List{List{Expression}}
  local dimsize::Int

  Error.assertion(! listEmpty(inDims), "Empty dimension list given in arrayFromList.", sourceInfo())
  @match _cons(ldim, restdims) = inDims
  dimsize = size(ldim)
  ty = liftArrayLeft(elemTy, ldim)
  if ListUtil.hasOneElement(inDims)
    Error.assertion(dimsize == listLength(inExps), "Length mismatch in arrayFromList.", sourceInfo())
    outExp = makeArray(ty, inExps)
    return outExp
  end
  partexps = ListUtil.partition(inExps, dimsize)
  newlst = nil
  for arrexp in partexps
    newlst = Cons{Expression}(makeArray(ty, arrexp), newlst)
  end
  newlst = listReverse(newlst)
  outExp = arrayFromList_impl(newlst, ty, restdims)
  outExp
end

"""
Same as arrayFromList but for ```Vector{Expression}```
"""
function arrayFromVector(inExps::Vector{Expression}, @nospecialize(elemTy::M_Type), inDims::List{Dimension})::Expression
  local outExp::Expression
  outExp = arrayFromVectorImpl(inExps, elemTy, listReverse(inDims))
end

function arrayFromVectorImpl(inExps::Vector{Expression},
                             elemTy::M_Type,
                             inDims::List{Dimension})::Expression
  local outExp::Expression
  local ldim::Dimension
  local restdims::List{Dimension}
  local ty::M_Type
  local newVec::Vector{Expression}
  local partexps::Vector{Vector{Expression}} #=A Vector of Vectors...=#
  local dimsize::Int
  Error.assertion(! listEmpty(inDims), "Empty dimension list given in arrayFromList.", sourceInfo())
  @match Cons{Dimension}(ldim, restdims) = inDims
  dimsize = size(ldim)
  ty = liftArrayLeft(elemTy, ldim)
  if ListUtil.hasOneElement(inDims)
    Error.assertion(dimsize == length(inExps), "Length mismatch in arrayFromList.", sourceInfo())
    outExp = makeArray(ty, inExps)
    return outExp
  end
  partexps = ArrayUtil.partition(inExps, dimsize)
  newVec = Vector{Expression}(undef, length(partexps))
  for (i,arrexp) in enumerate(partexps)
    newVec[i] = makeArray(ty, arrexp)
  end
  outExp = arrayFromVectorImpl(newVec, ty, restdims)
  return outExp
end

@nospecializeinfer function replaceIterator2(@nospecialize(exp::Expression), iterator::InstNode, @nospecialize(iteratorValue::Expression)) ::Expression
  newExp = begin
    local node::InstNode
    @match exp begin
      CREF_EXPRESSION(cref = COMPONENT_REF_CREF(node = node))  where {exp.cref isa COMPONENT_REF_CREF && isSimple(exp.cref)} => begin
        if nameEqual(iterator, node)
          iteratorValue
        else
          exp
        end
      end
      CREF_EXPRESSION(__) => begin
        exp
      end
      _  => begin
        exp
      end
    end
  end
  newExp
end

function replaceIterator(@nospecialize(exp::Expression),
                         iterator::InstNode,
                         iteratorValue::Expression)
  res = map(exp, @closure (x) -> replaceIterator2(x,  iterator, iteratorValue))
  return res
end

function makeSubscriptedExp(subscripts::List{<:Subscript}, @nospecialize(exp::Expression)) ::Expression
  local outExp::Expression

  local e::Expression
  local subs::List{Subscript}
  local extra_subs::List{Subscript}
  local ty::M_Type
  local dim_count::Int

  #=  If the expression is already a SUBSCRIPTED_EXP_EXPRESSION we need to concatenate the
  =#
  #=  old subscripts with the new. Otherwise we just create a new SUBSCRIPTED_EXP_EXPRESSION.
  =#
   (e, subs, ty) = begin
    @match exp begin
      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        (exp.exp, exp.subscripts, typeOf(exp.exp))
      end

      _  => begin
        (exp, nil, typeOf(exp))
      end
    end
  end
  dim_count = dimensionCount(ty)
  (subs, extra_subs) = mergeList(subscripts, subs, dim_count)
  #=  Check that the expression has enough dimensions to be subscripted. =#
  if ! listEmpty(extra_subs)
    Error.assertion(false, getInstanceName() + ": too few dimensions in " + toString(exp) + " to apply subscripts " + toStringList(subscripts), sourceInfo())
  end
  ty = subscript(ty, subs)
  outExp = SUBSCRIPTED_EXP_EXPRESSION(e, subs, ty)
  return outExp
end

function applySubscriptIf(subscript::Subscript, @nospecialize(exp::Expression), restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression
  local cond::Expression
  local tb::Expression
  local fb::Expression
  @match IF_EXPRESSION(cond, tb, fb) = exp
   tb = applySubscript(subscript, tb, restSubscripts)
   fb = applySubscript(subscript, fb, restSubscripts)
   outExp = IF_EXPRESSION(cond, tb, fb)
  outExp
end

function applyIndexSubscriptArrayConstructor(@nospecialize(call::Call), index::Subscript) ::Expression
  local subscriptedExp::Expression

  local ty::M_Type
  local var::VariabilityType
  local exp::Expression
  local iter_exp::Expression
  local iters::List{Tuple{InstNode, Expression}}
  local iter::InstNode

  @match TYPED_ARRAY_CONSTRUCTOR(ty, var, exp, iters) = call
   ((iter, iter_exp), iters) = ListUtil.splitLast(iters)
   iter_exp = applySubscript(index, iter_exp)
   subscriptedExp = replaceIterator(exp, iter, iter_exp)
  if ! listEmpty(iters)
     subscriptedExp = CALL_EXPRESSION(TYPED_ARRAY_CONSTRUCTOR(unliftArray(ty), var, subscriptedExp, iters))
  end
  subscriptedExp
end

function applySubscriptArrayConstructor(subscript::Subscript, @nospecialize(call::Call), restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression

  if isIndex(subscript) && listEmpty(restSubscripts)
     outExp = applyIndexSubscriptArrayConstructor(call, subscript)
  else
     outExp = makeSubscriptedExp(Cons{Subscript}(subscript, restSubscripts), CALL_EXPRESSION(call))
  end
  #=  TODO: Handle slicing and multiple subscripts better.
  =#
  outExp
end

function applySubscriptCall(subscript::Subscript, @nospecialize(exp::Expression), restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression
  local call::Call
  @match CALL_EXPRESSION(call = call) = exp
  outExp = begin
    local arg::Expression
    local ty::M_Type
    @match call begin
      TYPED_CALL(arguments = arg <| nil()) where (isSubscriptableBuiltin(call.fn))  => begin
        arg = applySubscript(subscript, arg, restSubscripts)
        ty = copyDims(typeOf(arg), call.ty)
        CALL_EXPRESSION(TYPED_CALL(call.fn, ty, call.var, list(arg), call.attributes))
      end

      TYPED_ARRAY_CONSTRUCTOR(__)  => begin
        applySubscriptArrayConstructor(subscript, call, restSubscripts)
      end

      _  => begin
        makeSubscriptedExp(Cons{Subscript}(subscript, restSubscripts), exp)
      end
    end
  end
  outExp
end

function applyIndexSubscriptRange2(@nospecialize(startExp::Expression), stepExp::Option{<:Expression}, @nospecialize(stopExp::Expression), index::Int) ::Expression
  local subscriptedExp::Expression

  local iidx::Int
  local ridx::AbstractFloat

   subscriptedExp = begin
    @match (startExp, stepExp) begin
      (INTEGER_EXPRESSION(__), SOME(INTEGER_EXPRESSION(iidx)))  => begin
        INTEGER_EXPRESSION(startExp.value + (index - 1) * iidx)
      end

      (INTEGER_EXPRESSION(__), _)  => begin
        INTEGER_EXPRESSION(startExp.value + index - 1)
      end

      (REAL_EXPRESSION(__), SOME(REAL_EXPRESSION(ridx)))  => begin
        REAL_EXPRESSION(startExp.value + (index - 1) * ridx)
      end

      (REAL_EXPRESSION(__), _)  => begin
        REAL_EXPRESSION(startExp.value + index - 1.0)
      end

      (BOOLEAN_EXPRESSION(__), _)  => begin
        if index == 1
          startExp
        else
          stopExp
        end
      end

      (ENUM_LITERAL_EXPRESSION(index = iidx), _)  => begin
         iidx = iidx + index - 1
        nthEnumLiteral(startExp.ty, iidx)
      end
    end
  end
  subscriptedExp
end

function applyIndexSubscriptRange(@nospecialize(rangeExp::Expression), index::Subscript) ::Expression
  local outExp::Expression

  local index_exp::Expression
  local start_exp::Expression
  local stop_exp::Expression
  local step_exp::Option{Expression}
  local ty::M_Type

  @match SUBSCRIPT_INDEX(index = index_exp) = index
  if isScalarLiteral(index_exp)
    @match RANGE_EXPRESSION(start = start_exp, step = step_exp, stop = stop_exp) = rangeExp
     outExp = applyIndexSubscriptRange2(start_exp, step_exp, stop_exp, toInteger(index_exp))
  else
    @match RANGE_EXPRESSION(ty = ty) = rangeExp
    local subs = list(index)
    local ty = subscript(ty, list(index))
    outExp = SUBSCRIPTED_EXP_EXPRESSION(rangeExp, subs, ty)
  end
  outExp
end

function applySubscriptRange(subscript::Subscript, @nospecialize(exp::Expression)) ::Expression
  local outExp::Expression
  local sub::Subscript
  local start_exp::Expression
  local stop_exp::Expression
  local step_exp::Option{Expression}
  local ty::M_Type
  local expl::List{Expression}
  (sub, _) = expandSlice(subscript)
  outExp = begin
    @match sub begin
      SUBSCRIPT_INDEX(__)  => begin
        applyIndexSubscriptRange(exp, sub)
      end
      SUBSCRIPT_SLICE(__)  => begin
        @match RANGE_EXPRESSION(ty = ty) = exp
        ty = TYPE_ARRAY(unliftArray(ty), list(toDimension(sub)))
        SUBSCRIPTED_EXP_EXPRESSION(exp, list(subscript), ty)
      end
      SUBSCRIPT_WHOLE(__)  => begin
        exp
      end
      SUBSCRIPT_EXPANDED_SLICE(__)  => begin
        expl = Expression[applyIndexSubscriptRange(exp, i) for i in sub.indices]
        @match RANGE_EXPRESSION(ty = ty) = exp
        makeArray(liftArrayLeft(ty, fromInteger(listLength(expl))), expl)
      end
      SUBSCRIPT_SPLIT_INDEX(__) => begin
        @match RANGE_EXPRESSION(ty) = exp
        ty = unliftArray(ty)
        SUBSCRIPTED_EXP_EXPRESSION(exp, list(sub), ty, true #=TODO=#)
      end
    end
  end
  outExp
end

function applyIndexExpArray(@nospecialize(exp::Expression), @nospecialize(index::Expression), restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression
  local expl::Vector{Expression}
  if isScalarLiteral(index)
    @match ARRAY_EXPRESSION(elements = expl) = exp
     outExp = applySubscripts(restSubscripts, arrayGet(expl, toInteger(index)))
  elseif isBindingExp(index)
     outExp = bindingExpMap(index, ind -> applyIndexExpArray(exp, ind, restSubscripts))
  else
     outExp = makeSubscriptedExp(Cons{Subscript}(SUBSCRIPT_INDEX(index), restSubscripts), exp)
  end
  outExp
end

function applyIndexSubscriptArray(@nospecialize(exp::Expression), index::Subscript, restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression

   outExp = applyIndexExpArray(exp, toExp(index), restSubscripts)
  outExp
end

function applySubscriptArray(inSubscript::Subscript, @nospecialize(exp::Expression), restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression

  local sub::Subscript
  local s::Subscript
  local rest_subs::List{Subscript}
  local expl::Vector{Expression}
  local ty::M_Type
  local el_count::Int
  local literal::Bool

  (sub, _) = expandSlice(inSubscript)
   outExp = begin
    @match sub begin
      SUBSCRIPT_INDEX(__)  => begin
        applyIndexSubscriptArray(exp, sub, restSubscripts)
      end

      SUBSCRIPT_SLICE(__)  => begin
        makeSubscriptedExp(Cons{Subscript}(inSubscript, restSubscripts), exp)
      end

      SUBSCRIPT_WHOLE(__)  => begin
        if listEmpty(restSubscripts)
           outExp = exp
        else
          @match ARRAY_EXPRESSION(ty = ty, elements = expl, literal = literal) = exp
          @match Cons{Subscript}(s, rest_subs) = restSubscripts
          expl = Expression[applySubscript(s, e, rest_subs) for e in expl]
          el_count = length(expl)
          ty = if el_count > 0
            typeOf(expl[1])
          else
            subscript(unliftArray(ty), restSubscripts)
          end
          ty = liftArrayLeft(ty, fromInteger(el_count))
          outExp = makeArray(ty, expl; literal=literal)
        end
        outExp
      end

      SUBSCRIPT_EXPANDED_SLICE(__)  => begin
        @match ARRAY_EXPRESSION(ty = ty, literal = literal) = exp
        expl = Expression[applyIndexSubscriptArray(exp, i, restSubscripts) for i in sub.indices]
        el_count = length(expl)
        ty = if el_count > 0
          typeOf(expl[1])
        else
          subscript(unliftArray(ty), restSubscripts)
        end
        ty = liftArrayLeft(ty, fromInteger(el_count))
        makeArray(ty, expl; literal=literal)
      end
    end
  end
  outExp
end

function applyIndexSubscriptTypename(@nospecialize(ty::M_Type), index::Subscript) ::Expression
  local subscriptedExp::Expression

  local idx_exp::Expression
  local idx::Int

   idx_exp = toExp(index)
  if isScalarLiteral(idx_exp)
     idx = toInteger(idx_exp)
     subscriptedExp = begin
      @match ty begin
        TYPE_BOOLEAN(__) where (idx <= 2)  => begin
          if idx == 1
            BOOLEAN_EXPRESSION(false)
          else
            BOOLEAN_EXPRESSION(true)
          end
        end

        TYPE_ENUMERATION(__)  => begin
          nthEnumLiteral(ty, idx)
        end
      end
    end
  else
    subscriptedExp = SUBSCRIPTED_EXP_EXPRESSION(TYPENAME_EXPRESSION(ty), list(index), ty)
  end
  subscriptedExp
end

function applySubscriptTypename(subscript::Subscript, @nospecialize(ty::M_Type)) ::Expression
  local outExp::Expression
  local sub::Subscript
  local index::Int
  local expl::List{Expression}
  sub = expandSlice(subscript)
  outExp = begin
    @match sub begin
      SUBSCRIPT_INDEX(__)  => begin
        applyIndexSubscriptTypename(ty, sub)
      end

      SUBSCRIPT_SLICE(__)  => begin
        SUBSCRIPTED_EXP_EXPRESSION(TYPENAME_EXPRESSION(ty), list(subscript), TYPE_ARRAY(ty, list(toDimension(sub))))
      end

      SUBSCRIPT_WHOLE(__)  => begin
        TYPENAME_EXPRESSION(ty)
      end

      SUBSCRIPT_EXPANDED_SLICE(__)  => begin
        expl = Expression[applyIndexSubscriptTypename(ty, i) for i in sub.indices]
        makeArray(liftArrayLeft(ty, fromInteger(listLength(expl))), expl, literal = true)
      end
    end
  end
  outExp
end

function applySubscriptCref(subscript::Subscript, cref::ComponentRef, restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression
  local cr::ComponentRef
  local ty::M_Type
  cr = applySubscripts(Cons{Subscript}(subscript, restSubscripts), cref)
  ty = getSubscriptedType(cr)
  outExp = CREF_EXPRESSION(ty, cr)
  outExp
end

"""
 Subscripts an expression with the given subscript, and then applies the
 optional list of subscripts to each element of the subscripted expression.
"""
function applySubscript(subscript::Subscript, @nospecialize(exp::Expression), restSubscripts::List{<:Subscript} = nil) ::Expression
  local outExp::Expression
  # @info "Apply subscript:"
  # println("exp:")
  # println(toString(exp))
  # println("subscript:")
  # println(toString(subscript))
  # println("*******************")
  outExp = begin
    @match exp begin
      CREF_EXPRESSION(__)  => begin
        applySubscriptCref(subscript, exp.cref, restSubscripts)
      end
      TYPENAME_EXPRESSION(__) where (listEmpty(restSubscripts))  => begin
        applySubscriptTypename(subscript, exp.ty)
      end
      ARRAY_EXPRESSION(__)  => begin
        applySubscriptArray(subscript, exp, restSubscripts)
      end
      RANGE_EXPRESSION(__) where (listEmpty(restSubscripts))  => begin
        applySubscriptRange(subscript, exp)
      end
      CALL_EXPRESSION(call = TYPED_ARRAY_CONSTRUCTOR(__))  => begin
        applySubscriptArrayConstructor(subscript, exp.call, restSubscripts)
      end
      CALL_EXPRESSION(__)  => begin
        applySubscriptCall(subscript, exp, restSubscripts)
      end
      IF_EXPRESSION(__)  => begin
        applySubscriptIf(subscript, exp, restSubscripts)
      end
      BINDING_EXP(__)  => begin
        bindingExpMap(exp, (expArg) -> applySubscript(subscript, expArg, restSubscripts))
      end
      _  => begin
        makeSubscriptedExp(Cons{Subscript}(subscript, restSubscripts), exp)
      end
    end
  end
  outExp
end

""" Subscripts an expression with the given list of subscripts. """
function applySubscripts(subscripts::List{<:Subscript}, @nospecialize(exp::Expression)) ::Expression
  local outExp::Expression
  if listEmpty(subscripts)
    outExp = exp
  else
    outExp = applySubscript(listHead(subscripts), exp, listRest(subscripts))
  end
  outExp
end

"""
```
makeRecord(recordName::Absyn.Path, @nospecialize(recordType::M_Type), fields::List{Expression})
```
  Creates a record expression.
"""
function makeRecord(recordName::Absyn.Path, @nospecialize(recordType::M_Type), fields::Vector{Expression})
  local exp::Expression
  exp = RECORD_EXPRESSION(recordName, recordType, fields)
  exp
end

function makeRange(@nospecialize(start::Expression), step::Option{T}, @nospecialize(stop::Expression)) where {T}
  local rangeTy = getRangeType(start, step, stop, typeOf(start), AbsynUtil.dummyInfo)
  return RANGE_EXPRESSION(rangeTy, start, step, stop)
end

"""
```
makeExpArray(elements::List{<:Expression}, isLiteral::Bool = false) ::Expression
```
  Creates an array expression
"""
function makeExpArray(elements::List{<:Expression}, isLiteral::Bool = false) ::Expression
  local exp::Expression
  local ty::M_Type
  ty = typeOf(listHead(elements))
  ty = liftArrayLeft(ty, fromInteger(listLength(elements)))
  exp = makeArray(ty, elements, literal = isLiteral)
  exp
end

function makeRealMatrix(values::List{<:List{<:AbstractFloat}}) ::Expression
  local exp::Expression
  local ty::M_Type
  local expl::Vector{Expression}
  if listEmpty(values)
     ty = TYPE_ARRAY(TYPE_REAL(), list(fromInteger(0), DIMENSION_UNKNOWN()))
     exp = makeEmptyArray(ty)
  else
     ty = TYPE_ARRAY(TYPE_REAL(), list(fromInteger(listLength(listHead(values)))))
     expl = Expression[makeArray(ty, list(REAL_EXPRESSION(v) for v in row), literal = true) for row in values]
     ty = liftArrayLeft(ty, fromInteger(listLength(expl)))
     exp = makeArray(ty, expl, literal = true)
  end
  exp
end

function makeRealArray(values::List{AbstractFloat})
  local exp::Expression
   exp = makeArray(TYPE_ARRAY(TYPE_REAL(), list(fromInteger(listLength(values)))), Expression[REAL_EXPRESSION(v) for v in values]; literal = true)
  exp
end

function makeIntegerArray(values::List{Int})
  local exp::Expression
  exp = makeArray(TYPE_ARRAY(TYPE_INTEGER(),
                             list(fromInteger(listLength(values)))), Expression[INTEGER_EXPRESSION(v) for v in values]
                   ; literal = true)
  exp
end

function makeEmptyArray(@nospecialize(ty::M_Type))
  local outExp::Expression
   outExp = ARRAY_EXPRESSION(ty, nil, true)
  outExp
end

function makeExpArray(ty::NFType, expl::List{Expression}; literal::Bool = false)
  local outExp::Expression
   outExp = ARRAY_EXPRESSION(ty, expl, literal)
  outExp
end

"""
Generic make array function
"""
function makeArray(ty::NFType, expl::List; literal::Bool = false)
  # @warn "Called make array with old interface"
  # st = stacktrace()
  # println(st[3])  # 2 because 1 is the current function itself
  ARRAY_EXPRESSION(ty, listArray(expl), literal)
end

"""
Generic make array function for vectors
"""
function makeArray(ty::NFType, expV::Vector{T}; literal::Bool = false) where {T}
  ARRAY_EXPRESSION(ty, expV, literal)
end

function updateArray!(arrayExpr::ARRAY_EXPRESSION;
                      ty::NFType = arrayExpr.ty,
                      elements::Vector{T}  = arrayExpr.elements,
                      literal::Bool = false) where {T}
  arrayExpr.elements = elements
  arrayExpr.ty = ty
  arrayExpr.literal = literal
  arrayExpr
end


function makeInteger(value::Int)
  local exp::Expression = INTEGER_EXPRESSION(value)
  exp
end

function integerValue(@nospecialize(exp::Expression))
  local value::Int
  @match INTEGER_EXPRESSION(value = value) = exp
  value
end

function makeReal(value::AbstractFloat)
  local exp::Expression = REAL_EXPRESSION(value)
  exp
end

function realValue(@nospecialize(exp::Expression))
  local value::AbstractFloat
   value = begin
    @match exp begin
      REAL_EXPRESSION(__)  => begin
        exp.value
      end

      INTEGER_EXPRESSION(__)  => begin
        intReal(exp.value)
      end
    end
  end
  value
end

 """
   Converts an expression to the given type. Dimensions of array types can be
   omitted, and are ignored by this function, since arrays can't be cast to a
   different size. Only the element type of the type is used, so for example:
   typeCast({1, 2, 3}, TYPE_REAL()) => {1.0, 2.0, 3.0}

   The function does not check that the cast is valid, and expressions that
   can't be converted outright will be wrapped as a CAST expression.
 """
 function typeCast(@nospecialize(exp::Expression), @nospecialize(ty::NFType)) ::Expression
   local t::NFType
   local t2::NFType
   local ety::NFType
   local el::Vector{Expression}
    ety = arrayElementType(ty)
    exp = begin
     @match (exp, ety) begin
       (INTEGER_EXPRESSION(__), TYPE_REAL(__))  => begin
         REAL_EXPRESSION(intReal(exp.value))
       end
       (BOOLEAN_EXPRESSION(__), TYPE_REAL(__)) where (Flags.isSet(Flags.NF_API))  => begin
         REAL_EXPRESSION(if exp.value
              1.0
              else
              0.0
              end)
       end
       (REAL_EXPRESSION(__), TYPE_REAL(__))  => begin
         exp
       end
       (ARRAY_EXPRESSION(ty = t, elements = el), _)  => begin
         #=  Integer can be cast to Real.
         =#
         #=  Boolean can be cast to Real (only if -d=nfAPI is on)
         =#
         #=  as there are annotations having expressions such as Boolean x > 0.5
         =#
         #=  Real doesn't need to be cast to Real, since we convert e.g. array with
         =#
         #=  a mix of Integers and Reals to only Reals.
         =#
         #=  For arrays we typecast each element and update the type of the array.
         =#
         el = Expression[typeCast(e, ety) for e in el]
         t = setArrayElementType(t, ety)
         ARRAY_EXPRESSION(t, el, exp.literal)
       end
       (RANGE_EXPRESSION(ty = t), _)  => begin
         t = setArrayElementType(t, ety)
         RANGE_EXPRESSION(t, typeCast(exp.start, ety), typeCastOpt(exp.step, ety), typeCast(exp.stop, ety))
       end
       (UNARY_EXPRESSION(__), _)  => begin
         #=  Unary operators (i.e. -) are handled by casting the operand.
         =#
         t = setArrayElementType(typeOf(exp.operator), ety)
         UNARY_EXPRESSION(setType(t, exp.operator), typeCast(exp.exp, ety))
       end
       (IF_EXPRESSION(__), _)  => begin
         IF_EXPRESSION(exp.condition, typeCast(exp.trueBranch, ety), typeCast(exp.falseBranch, ety))
       end
       (CALL_EXPRESSION(__), _)  => begin
         typeCast(exp, ety)
       end
       (CAST_EXPRESSION(__), _)  => begin
         typeCast(exp.exp, ty)
       end
       (BINDING_EXP(__), _)  => begin
         #=  If-expressions are handled by casting each of the branches.
         =#
         #=  Calls are handled by Call.typeCast, which has special rules for some functions.
         =#
         #=  Casting a cast expression overrides its current cast type.
         =#
          t = setArrayElementType(exp.expType, ety)
          t2 = setArrayElementType(exp.bindingType, ety)
         BINDING_EXP(typeCast(exp.exp, ety), t, t2, exp.parents, exp.isEach)
       end
       _  => begin
         #=  Other expressions are handled by making a CAST expression.
         =#
          t = typeOf(exp)
          t = setArrayElementType(t, ety)
         CAST_EXPRESSION(t, exp)
       end
     end
   end
   exp
 end

function typeCastOpt(exp::Option{<:Expression}, @nospecialize(ty::M_Type)) ::Option{Expression}
  local outExp::Option{Expression} = Util.applyOption(exp, (e) -> typeCast(e, ty))
  outExp
end

function setType(@nospecialize(ty::NFType), @nospecialize(exp::Expression))
  retExp = @match exp begin
    ENUM_LITERAL_EXPRESSION(__)  => begin
      ENUM_LITERAL_EXPRESSION(ty, exp.name, exp.index)
    end

    CREF_EXPRESSION(__)  => begin
      CREF_EXPRESSION(ty, exp.cref)
    end

    TYPENAME_EXPRESSION(__)  => begin
      TYPENAME_EXPRESSION(ty)
    end

    ARRAY_EXPRESSION(__)  => begin
      ARRAY_EXPRESSION(ty, exp.elements, exp.literal)
    end

    RANGE_EXPRESSION(__)  => begin
      RANGE_EXPRESSION(ty, exp.start, exp.step, exp.stop)
    end

    TUPLE_EXPRESSION(__)  => begin
      TUPLE_EXPRESSION(exp.ty, exp.elements)
    end

    RECORD_EXPRESSION(__)  => begin
      exp.ty = ty
    end

    CALL_EXPRESSION(__)  => begin
      CALL_EXPRESSION(setType(exp.call, ty))
    end

    BINARY_EXPRESSION(__) || UNARY_EXPRESSION(__) || LBINARY_EXPRESSION(__) ||
      RELATION_EXPRESSION(__) ||  LUNARY_EXPRESSION(__) => begin
        exp.operator = setType(ty, exp.operator)
        exp
      end

    CAST_EXPRESSION(__)  => begin
      CAST_EXPRESSION(ty, exp.exp)
    end

    UNBOX_EXPRESSION(__)  => begin
      UNBOX_EXPRESSION(exp.exp, ty)
    end

    SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
      SUBSCRIPTED_EXP_EXPRESSION(exp.exp, exp.subscripts, ty)
    end

    TUPLE_ELEMENT_EXPRESSION(__)  => begin
      TUPLE_ELEMENT_EXPRESSION(exp.tupleExp, exp.index, ty)
    end

    RECORD_ELEMENT_EXPRESSION(__)  => begin
      RECORD_ELEMENT_EXPRESSION(exp.recordExp, exp.index, exp.fieldName, ty)
    end

    PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(exp.fn,
                                              exp.args,
                                              exp.argNames,
                                              ty)
    end
    _  => begin
      exp
    end
  end
  retExp
end


@nospecializeinfer function typeOf(@nospecialize(exp::Expression))
  local ty::M_Type
  ty = begin
    @match exp begin
      INTEGER_EXPRESSION(__)  => begin
        TYPE_INTEGER()
      end

      REAL_EXPRESSION(__)  => begin
        TYPE_REAL()
      end

      STRING_EXPRESSION(__)  => begin
        TYPE_STRING()
      end

      BOOLEAN_EXPRESSION(__)  => begin
        TYPE_BOOLEAN()
      end

      ENUM_LITERAL_EXPRESSION(__)  => begin
        exp.ty
      end

      CLKCONST_EXPRESSION(__)  => begin
        TYPE_CLOCK()
      end

      CREF_EXPRESSION(__)  => begin
        exp.ty
      end

      TYPENAME_EXPRESSION(__)  => begin
        exp.ty
      end

      ARRAY_EXPRESSION(__)  => begin
        exp.ty
      end

      RANGE_EXPRESSION(__)  => begin
        exp.ty
      end

      TUPLE_EXPRESSION(__)  => begin
        exp.ty
      end

      RECORD_EXPRESSION(__)  => begin
        exp.ty
      end

      CALL_EXPRESSION(__)  => begin
        typeOf(exp.call)
      end

      SIZE_EXPRESSION(__)  => begin
        if isSome(exp.dimIndex)
          TYPE_INTEGER()
        else
          sizeType(typeOf(exp.exp))
        end
      end

      END_EXPRESSION(__)  => begin
        TYPE_INTEGER()
      end

      BINARY_EXPRESSION(__)  => begin
        typeOf(exp.operator)
      end

      UNARY_EXPRESSION(__)  => begin
        typeOf(exp.operator)
      end

      LBINARY_EXPRESSION(__)  => begin
        typeOf(exp.operator)
      end

      LUNARY_EXPRESSION(__)  => begin
        typeOf(exp.operator)
      end

      RELATION_EXPRESSION(__)  => begin
        typeOf(exp.operator)
      end

      IF_EXPRESSION(__)  => begin
        typeOf(exp.trueBranch)
      end

      CAST_EXPRESSION(__)  => begin
        exp.ty
      end

      UNBOX_EXPRESSION(__)  => begin
        exp.ty
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        exp.ty
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        exp.ty
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        exp.ty
      end

      BOX_EXPRESSION(__)  => begin
        TYPE_METABOXED(typeOf(exp.exp))
      end

      MUTABLE_EXPRESSION(__)  => begin
        typeOf(P_Pointer.access(exp.exp))
      end

      EMPTY_EXPRESSION(__)  => begin
        exp.ty
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        exp.ty
      end

      BINDING_EXP(__)  => begin
        exp.bindingType
      end

      _  => begin
        TYPE_UNKNOWN()
      end
    end
  end
  ty
end

function compareList(expl1::List{<:Expression}, expl2::List{<:Expression}) ::Int
  local comp::Int

  local e2::Expression
  local rest_expl2::List{Expression} = expl2

  #=  Check that the lists have the same length, otherwise they can't be equal.
  =#
   comp = Util.intCompare(listLength(expl1), listLength(expl2))
  if comp != 0
    return comp
  end
  for e1 in expl1
    @match Cons{Expression}(e2, rest_expl2) = rest_expl2
    comp = compare(e1, e2)
    if comp != 0
      return comp
    end
  end
  #=  Return if the expressions are not equal.
  =#
   comp = 0
  comp
end


function compareVector(expl1::Vector{Expression}, expl2::Vector{Expression})::Int
  local comp::Int
  local e2::Expression
  #=  Check that the lists have the same length, otherwise they can't be equal. =#
   comp = Util.intCompare(length(expl1), length(expl2))
  if comp != 0
    return comp
  end
  for (i, e1) in enumerate(expl1)
    e2 = expl2[i]
    comp = compare(e1, e2)
    if comp != 0
      return comp
    end
  end
  #=  Return if the expressions are not equal. =#
  comp = 0
  return comp
end

function compareOpt(expl1::Option{<:Expression}, expl2::Option{<:Expression}) ::Int
  local comp::Int

  local e1::Expression
  local e2::Expression

   comp = begin
    @match (expl1, expl2) begin
      (NONE(), NONE())  => begin
        0
      end

      (NONE(), _)  => begin
        -1
      end

      (_, NONE())  => begin
        1
      end

      (SOME(e1), SOME(e2))  => begin
        compare(e1, e2)
      end
    end
  end
  comp
end

""" #= Checks whether two expressions are equal, and returns 0 if they are.
               If the first expression is 'less' than the second it returns an integer
               less than 0, otherwise an integer greater than 0. =#"""
@nospecializeinfer function compare(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression)) ::Int
  local comp::Int

  #=  Check if the expressions are the same object.
  =#
  if referenceEq(exp1, exp2)
    return 0
  end
  #=  Return false if the expressions are of different kinds.
  =#
  comp = Util.intCompare(valueConstructor(exp1), valueConstructor(exp2))
  if comp != 0
    return comp
  end
   comp = begin
    local i::Int
    local r::AbstractFloat
    local s::String
    local b::Bool
    local cr::ComponentRef
    local ty::M_Type
    local expl
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local oe::Option{Expression}
    local p::Path
    local op::Operator
    local c::Call
    local subs::List{Subscript}
    local clk1::ClockKind
    local clk2::ClockKind
    local me::Pointer{Expression}
    @match exp1 begin
      INTEGER_EXPRESSION(__)  => begin
        @match INTEGER_EXPRESSION(value = i) = exp2
        Util.intCompare(exp1.value, i)
      end

      REAL_EXPRESSION(__)  => begin
        @match REAL_EXPRESSION(value = r) = exp2
        Util.realCompare(exp1.value, r)
      end

      STRING_EXPRESSION(__)  => begin
        @match STRING_EXPRESSION(value = s) = exp2
        Util.stringCompare(exp1.value, s)
      end

      BOOLEAN_EXPRESSION(__)  => begin
        @match BOOLEAN_EXPRESSION(value = b) = exp2
        Util.boolCompare(exp1.value, b)
      end

      ENUM_LITERAL_EXPRESSION(__)  => begin
        @match ENUM_LITERAL_EXPRESSION(ty = ty, index = i) = exp2
         comp = AbsynUtil.pathCompare(enumName(exp1.ty), enumName(ty))
        if comp == 0
           comp = Util.intCompare(exp1.index, i)
        end
        comp
      end

      CREF_EXPRESSION(__)  => begin
        @match CREF_EXPRESSION(cref = cr) = exp2
        compare(exp1.cref, cr)
      end

      TYPENAME_EXPRESSION(__)  => begin
        @match TYPENAME_EXPRESSION(ty = ty) = exp2
        valueCompare(exp1.ty, ty)
      end

      ARRAY_EXPRESSION(__)  => begin
        @match ARRAY_EXPRESSION(ty = ty, elements = expV) = exp2
         comp = valueCompare(ty, exp1.ty)
        if comp == 0
          compareVector(exp1.elements, expV)
        else
          comp
        end
      end

      RANGE_EXPRESSION(__)  => begin
        @match RANGE_EXPRESSION(start = e1, step = oe, stop = e2) = exp2
         comp = compare(exp1.start, e1)
        if comp == 0
           comp = compare(exp1.stop, e2)
          if comp == 0
             comp = compareOpt(exp1.step, oe)
          end
        end
        comp
      end

      TUPLE_EXPRESSION(__)  => begin
        @match TUPLE_EXPRESSION(elements = expl) = exp2
        compareList(exp1.elements, expl)
      end

      RECORD_EXPRESSION(__)  => begin
        @match RECORD_EXPRESSION(path = p, elements = expl) = exp2
                          comp = AbsynUtil.pathCompare(exp1.path, p)
        if comp == 0
          compareVector(exp1.elements, expl)
        else
          comp
        end
      end

      CALL_EXPRESSION(__)  => begin
        @match CALL_EXPRESSION(call = c) = exp2
        compare(exp1.call, c)
      end

      SIZE_EXPRESSION(__)  => begin
        @match SIZE_EXPRESSION(exp = e1, dimIndex = oe) = exp2
         comp = compareOpt(exp1.dimIndex, oe)
        if comp == 0
          compare(exp1.exp, e1)
        else
          comp
        end
      end

      END_EXPRESSION(__)  => begin
        0
      end

      BINARY_EXPRESSION(__)  => begin
        @match BINARY_EXPRESSION(exp1 = e1, operator = op, exp2 = e2) = exp2
         comp = compare(exp1.operator, op)
        if comp == 0
           comp = compare(exp1.exp1, e1)
          if comp == 0
             comp = compare(exp1.exp2, e2)
          end
        end
        comp
      end

      UNARY_EXPRESSION(__)  => begin
        @match UNARY_EXPRESSION(operator = op, exp = e1) = exp2
         comp = compare(exp1.operator, op)
        if comp == 0
          compare(exp1.exp, e1)
        else
          comp
        end
      end

      LBINARY_EXPRESSION(__)  => begin
        @match LBINARY_EXPRESSION(exp1 = e1, operator = op, exp2 = e2) = exp2
         comp = compare(exp1.operator, op)
        if comp == 0
           comp = compare(exp1.exp1, e1)
          if comp == 0
             comp = compare(exp1.exp2, e2)
          end
        end
        comp
      end

      LUNARY_EXPRESSION(__)  => begin
        @match LUNARY_EXPRESSION(operator = op, exp = e1) = exp2
         comp = compare(exp1.operator, op)
        if comp == 0
          compare(exp1.exp, e1)
        else
          comp
        end
      end

      RELATION_EXPRESSION(__)  => begin
        @match RELATION_EXPRESSION(exp1 = e1, operator = op, exp2 = e2) = exp2
         comp = compare(exp1.operator, op)
        if comp == 0
           comp = compare(exp1.exp1, e1)
          if comp == 0
             comp = compare(exp1.exp2, e2)
          end
        end
        comp
      end

      IF_EXPRESSION(__)  => begin
        @match IF_EXPRESSION(condition = e1, trueBranch = e2, falseBranch = e3) = exp2
         comp = compare(exp1.condition, e1)
        if comp == 0
           comp = compare(exp1.trueBranch, e2)
          if comp == 0
             comp = compare(exp1.falseBranch, e3)
          end
        end
        comp
      end

      UNBOX_EXPRESSION(__)  => begin
        @match UNBOX_EXPRESSION(exp = e1) = exp2
        compare(exp1.exp, e1)
      end

      CAST_EXPRESSION(__)  => begin
         e1 = begin
          @match exp2 begin
            CAST_EXPRESSION(exp = e1)  => begin
              e1
            end

            e1  => begin
              e1
            end
          end
        end
        compare(exp1.exp, e1)
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        @match SUBSCRIPTED_EXP_EXPRESSION(exp = e1, subscripts = subs) = exp2
         comp = compare(exp1.exp, e1)
        if comp == 0
           comp = compareList(exp1.subscripts, subs)
        end
        comp
      end

      TUPLE_ELEMENT_EXPRESSION(__)  => begin
        @match TUPLE_ELEMENT_EXPRESSION(tupleExp = e1, index = i) = exp2
         comp = Util.intCompare(exp1.index, i)
        if comp == 0
           comp = compare(exp1.tupleExp, e1)
        end
        comp
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        @match RECORD_ELEMENT_EXPRESSION(recordExp = e1, index = i) = exp2
         comp = Util.intCompare(exp1.index, i)
        if comp == 0
           comp = compare(exp1.recordExp, e1)
        end
        comp
      end

      BOX_EXPRESSION(__)  => begin
        @match BOX_EXPRESSION(exp = e2) = exp2
        compare(exp1.exp, e2)
      end

      MUTABLE_EXPRESSION(__)  => begin
        @match MUTABLE_EXPRESSION(exp = me) = exp2
        compare(P_Pointer.access(exp1.exp), P_Pointer.access(me))
      end

      EMPTY_EXPRESSION(__)  => begin
        @match EMPTY_EXPRESSION(ty = ty) = exp2
        valueCompare(exp1.ty, ty)
      end

      CLKCONST_EXPRESSION(clk1)  => begin
        @match CLKCONST_EXPRESSION(clk2) = exp2
        compare(clk1, clk2)
      end

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        @match PARTIAL_FUNCTION_APPLICATION_EXPRESSION(fn = cr, args = expl) = exp2
         comp = compare(exp1.fn, cr)
        if comp == 0
           comp = compareList(exp1.args, expl)
        end
        comp
      end

      BINDING_EXP(__)  => begin
        @match BINDING_EXP(exp = e2) = exp2
        compare(exp1.exp, e2)
      end

      _  => begin
        Error.assertion(false, getInstanceName() + " got unknown expression.", sourceInfo())
        fail()
      end
    end
  end
  comp
end

"""Returns true if the two expressions are equal, otherwise false."""
function isEqual(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression)) ::Bool
  local isEqual::Bool
  isEqual = 0 == compare(exp1, exp2)
  isEqual
end

function isFalse(@nospecialize(exp::Expression)) ::Bool
  local isTrue::Bool

   isTrue = begin
    @match exp begin
      BOOLEAN_EXPRESSION(false)  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  isTrue
end

function isAllTrue(@nospecialize(exp::Expression)) ::Bool
  local isTrue::Bool

   isTrue = begin
    @match exp begin
      BOOLEAN_EXPRESSION(true)  => begin
        true
      end

      ARRAY_EXPRESSION(__)  => begin
        for e in exp.elements
          if ! isAllTrue(e)
             isTrue = false
            return
          end
        end
        true
      end

      _  => begin
        false
      end
    end
  end
  isTrue
end

function isTrue(@nospecialize(exp::Expression))
    @match exp begin
      BOOLEAN_EXPRESSION(true)  => begin
        true
      end
      _  => begin
        false
      end
    end
end

function isCall(@nospecialize(exp::Expression))
  @match exp begin
    CALL_EXPRESSION(__)  => begin
      true
    end
    _  => begin
      false
    end
  end
end

function isWildCref(@nospecialize(exp::Expression))
  local wild::Bool

   wild = begin
    @match exp begin
      CREF_EXPRESSION(cref = COMPONENT_REF_WILD(__))  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  wild
end

function isCref(@nospecialize(exp::Expression)) ::Bool
  local isCref::Bool

   isCref = begin
    @match exp begin
      CREF_EXPRESSION(__)  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  isCref
end

function isEmptyArray(@nospecialize(exp::Expression)) ::Bool
  local emptyArray::Bool
   emptyArray = begin
    @match exp begin
      ARRAY_EXPRESSION(__)  => begin
        isempty(exp.elements)
      end
      _  => begin
        false
      end
    end
  end
  emptyArray
end

function isArray(@nospecialize(exp::Expression)) ::Bool
  local isArray::Bool

   isArray = begin
    @match exp begin
      ARRAY_EXPRESSION(__)  => begin
        true
      end

      _  => begin
        false
      end
    end
  end
  isArray
end

@UniontypeDecl ClockKind

function toString(ck::ClockKind) ::String
  local str::String

   str = begin
    local e1::Expression
    local e2::Expression
    @match ck begin
      INFERRED_CLOCK(__)  => begin
        ""
      end

      INTEGER_CLOCK(e1, e2)  => begin
        toString(e1) + ", " + toString(e2)
      end

      REAL_CLOCK(e1)  => begin
        toString(e1)
      end

      BOOLEAN_CLOCK(e1, e2)  => begin
        toString(e1) + ", " + toString(e2)
      end

      SOLVER_CLOCK(e1, e2)  => begin
        toString(e1) + ", " + toString(e2)
      end
    end
  end
   str = "Clock(" + str + ")"
  str
end

function toDebugString(ick::ClockKind) ::String
  local ock::String

   ock = begin
    local i::Expression
    local ic::Expression
    local r::Expression
    local c::Expression
    local si::Expression
    local sm::Expression
    @match ick begin
      INFERRED_CLOCK(__)  => begin
        "INFERRED_CLOCK()"
      end

      INTEGER_CLOCK(i, r)  => begin
        "INTEGER_CLOCK(" + toString(i) + ", " + toString(r) + ")"
      end

      REAL_CLOCK(i)  => begin
        "REAL_CLOCK(" + toString(i) + ")"
      end

      BOOLEAN_CLOCK(c, si)  => begin
        "BOOLEAN_CLOCK(" + toString(c) + ", " + toString(si) + ")"
      end

      SOLVER_CLOCK(c, sm)  => begin
        "SOLVER_CLOCK(" + toString(c) + ", " + toString(sm) + ")"
      end
    end
  end
  ock
end

function toDAE(ick::ClockKind) ::DAE.P_ClockKind
  local ock::DAE.P_ClockKind

   ock = begin
    local i::Expression
    local ic::Expression
    local r::Expression
    local c::Expression
    local si::Expression
    local sm::Expression
    @match ick begin
      INFERRED_CLOCK(__)  => begin
        DAE.INFERRED_CLOCK()
      end

      INTEGER_CLOCK(i, r)  => begin
        DAE.INTEGER_CLOCK(toDAE(i), toDAE(r))
      end

      REAL_CLOCK(i)  => begin
        DAE.REAL_CLOCK(toDAE(i))
      end

      BOOLEAN_CLOCK(c, si)  => begin
        DAE.BOOLEAN_CLOCK(toDAE(c), toDAE(si))
      end

      SOLVER_CLOCK(c, sm)  => begin
        DAE.SOLVER_CLOCK(toDAE(c), toDAE(sm))
      end
    end
  end
  ock
end

function compare(ck1::ClockKind, ck2::ClockKind) ::Int
  local comp::Int

   comp = begin
    local i1::Expression
    local ic1::Expression
    local r1::Expression
    local c1::Expression
    local si1::Expression
    local sm1::Expression
    local i2::Expression
    local ic2::Expression
    local r2::Expression
    local c2::Expression
    local si2::Expression
    local sm2::Expression
    @match (ck1, ck2) begin
      (INFERRED_CLOCK(__), INFERRED_CLOCK(__))  => begin
        0
      end

      (INTEGER_CLOCK(i1, r1), INTEGER_CLOCK(i2, r2))  => begin
         comp = compare(i1, i2)
        if comp == 0
           comp = compare(r1, r2)
        end
        comp
      end

      (REAL_CLOCK(i1), REAL_CLOCK(i2))  => begin
        compare(i1, i2)
      end

      (BOOLEAN_CLOCK(c1, si1), BOOLEAN_CLOCK(c2, si2))  => begin
         comp = compare(c1, c2)
        if comp == 0
           comp = compare(si1, si2)
        end
        comp
      end

      (SOLVER_CLOCK(c1, sm2), SOLVER_CLOCK(c2, sm1))  => begin
         comp = compare(c1, c2)
        if comp == 0
           comp = compare(sm1, sm2)
        end
        comp
      end
    end
  end
  comp
end

#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#
@UniontypeDecl Binding

@nospecializeinfer function containsExp(@nospecialize(binding::Binding), predFn::Function)
  local res::Bool

   res = begin
    @match binding begin
      UNTYPED_BINDING(__) => begin
        contains(binding.bindingExp, predFn)
      end

      TYPED_BINDING(__) => begin
        contains(binding.bindingExp, predFn)
      end

      FLAT_BINDING(__) => begin
        contains(binding.bindingExp, predFn)
      end

      CEVAL_BINDING(__) => begin
        contains(binding.bindingExp, predFn)
      end

      _ => begin
        false
      end
    end
  end
  return res
end

@nospecializeinfer function foldExp(@nospecialize(binding::Binding), foldFn::Function, arg::ArgT) where {ArgT}
  arg = begin
    @match binding begin
      UNTYPED_BINDING(__) => begin
        fold(binding.bindingExp, foldFn, arg)
      end

      TYPED_BINDING(__) => begin
        fold(binding.bindingExp, foldFn, arg)
      end

      FLAT_BINDING(__) => begin
        fold(binding.bindingExp, foldFn, arg)
      end

      CEVAL_BINDING(__) => begin
        fold(binding.bindingExp, foldFn, arg)
      end

      _ => begin
        arg
      end
    end
  end
  return arg
end

@nospecializeinfer function mapExpShallow(@nospecialize(binding::Binding), mapFn::Function)
  local e1::Expression
  local e2::Expression
  () = begin
    @match binding begin
      UNTYPED_BINDING(bindingExp = e1) => begin
        e2 = mapFn(e1)
        if !referenceEq(e1, e2)
          binding.bindingExp = e2
        end
        ()
      end

      TYPED_BINDING(bindingExp = e1) => begin
        e2 = mapFn(e1)
        if !referenceEq(e1, e2)
          binding.bindingExp = e2
        end
        ()
      end

      FLAT_BINDING(bindingExp = e1) => begin
        e2 = mapFn(e1)
        if !referenceEq(e1, e2)
          binding.bindingExp = e2
        end
        ()
      end

      CEVAL_BINDING(bindingExp = e1) => begin
        e2 = mapFn(e1)
        if !referenceEq(e1, e2)
          binding.bindingExp = e2
        end
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return binding
end

@nospecializeinfer function mapExp(@nospecialize(binding::Binding), mapFn::Function)
  local e1::Expression
  local e2::Expression
  local res = @match binding begin
    UNTYPED_BINDING(bindingExp = e1) => begin
      e2 = map(e1, mapFn)
      binding = if !referenceEq(e1, e2)
        bindingExp = e2
        UNTYPED_BINDING(bindinExp, binding.isProcessing, binding.isEach, binding.info)
      else
        binding
      end
    end
    TYPED_BINDING(bindingExp = e1) => begin
      e2 = map(e1, mapFn)
      if !referenceEq(e1, e2)
        bindingExp = e2
        TYPED_BINDING(bindingExp,
                      binding.bindingType,
                      binding.variability,
                      binding.eachType,
                      binding.evaluated,
                      binding.isFlattened,
                      binding.info)
      else
        binding
      end
    end
    FLAT_BINDING(bindingExp = e1) => begin
      e2 = map(e1, mapFn)
      if !referenceEq(e1, e2)
        bindingBindingExp = e2
        FLAT_BINDING(bindingBindingExp, binding.variability)
      end
      binding
    end
    CEVAL_BINDING(bindingExp = e1) => begin
      e2 = map(e1, mapFn)
      binding = if !referenceEq(e1, e2)
        bindingBindingExp = e2
        CEVAL_BINDING(bindingBindingExp)
      else
        binding
      end
    end
    _ => begin
      binding
    end
  end
  return res
end

@nospecializeinfer function toDAEExp(@nospecialize(binding::Binding))
  local bindingExp::Option{DAE.Exp}

   bindingExp = begin
    @match binding begin
      UNBOUND(__) => begin
        NONE()
      end

      TYPED_BINDING(__) => begin
        SOME(toDAE(binding.bindingExp))
      end

      FLAT_BINDING(__) => begin
        SOME(toDAE(binding.bindingExp))
      end

      CEVAL_BINDING(__) => begin
        NONE()
      end

      _ => begin
        Error.assertion(false, getInstanceName() + " got untyped binding", sourceInfo())
        fail()
      end
    end
  end
  return bindingExp
end

function makeDAEBinding(@nospecialize(exp::Expression), var::VariabilityType)
  local binding::DAE.Binding
   binding = DAE.EQBOUND(
    toDAE(exp),
    NONE(),
    variabilityToDAEConst(var),
    DAE.BINDING_FROM_DEFAULT_VALUE(),
  )
  #=  TODO: revise this. =#
  return binding
end

@nospecializeinfer function toDAE(@nospecialize(binding::Binding))
  local outBinding::DAE.Binding

   outBinding = begin
    @match binding begin
      UNBOUND(__) => begin
        DAE.UNBOUND()
      end

      TYPED_BINDING(__) => begin
        makeDAEBinding(binding.bindingExp, binding.variability)
      end

      FLAT_BINDING(__) => begin
        makeDAEBinding(binding.bindingExp, binding.variability)
      end

      CEVAL_BINDING(__) => begin
        DAE.UNBOUND()
      end

      INVALID_BINDING(__) => begin
        Error.addTotalMessages(binding.errors)
        fail()
      end

      _ => begin
        Error.assertion(false, getInstanceName() + " got untyped binding", sourceInfo())
        fail()
      end
    end
  end
  return outBinding
end

@nospecializeinfer function isEqual(@nospecialize(binding1::Binding), @nospecialize(binding2::Binding))
  local equal::Bool
   equal = begin
    @match (binding1, binding2) begin
      (UNBOUND(__), UNBOUND(__)) => begin
        true
      end
      (RAW_BINDING(__), RAW_BINDING(__)) => begin
        AbsynUtil.expEqual(binding1.bindingExp, binding2.bindingExp)
      end
      (UNTYPED_BINDING(__), UNTYPED_BINDING(__)) => begin
        isEqual(binding1.bindingExp, binding2.bindingExp)
      end
      (TYPED_BINDING(__), TYPED_BINDING(__)) => begin
        isEqual(binding1.bindingExp, binding2.bindingExp)
      end
      _ => begin
        false
      end
    end
  end
  #=  TODO: Handle propagated dims.
  =#
  return equal
end

@nospecializeinfer function toFlatString(@nospecialize(binding::Binding), prefix::String = ""; inFunction = false)
  local string::String
   string = begin
    @match binding begin
      UNBOUND(__) => begin
        ""
      end
      RAW_BINDING(__) => begin
        prefix + Dump.printExpStr(binding.bindingExp)
      end

      UNTYPED_BINDING(__) => begin
        prefix + toFlatString(binding.bindingExp; inFunction = inFunction)
      end

      TYPED_BINDING(__) => begin
        prefix + toFlatString(binding.bindingExp; inFunction = inFunction)
      end

      FLAT_BINDING(__) => begin
        prefix + toFlatString(binding.bindingExp; inFunction = inFunction)
      end

      CEVAL_BINDING(__) => begin
        prefix + toFlatString(binding.bindingExp; inFunction = inFunction)
      end

      INVALID_BINDING(__) => begin
        toFlatString(binding.binding, prefix; inFunction = inFunction)
      end
    end
  end
  return string
end

@nospecializeinfer function toString(@nospecialize(binding::Binding), prefix::String = "")
  local string::String

   string = begin
    @match binding begin
      UNBOUND(__) => begin
        ""
      end

      RAW_BINDING(__) => begin
        str = binding.bindingExp
        prefix + "$str" # Dump.printExpStr(binding.bindingExp)
      end

      UNTYPED_BINDING(__) => begin
        prefix + toString(binding.bindingExp)
      end

      TYPED_BINDING(__) => begin
        prefix + toString(binding.bindingExp)
      end

      FLAT_BINDING(__) => begin
        prefix + toString(binding.bindingExp)
      end

      CEVAL_BINDING(__) => begin
        prefix + toString(binding.bindingExp)
      end

      INVALID_BINDING(__) => begin
        toString(binding.binding, prefix)
      end
    end
  end
  return string
end

""" #= Returns the number of dimensions that the binding was propagated through to
     get to the element it belongs to. =#"""
@nospecializeinfer function propagatedDimCount(@nospecialize(binding::Binding))
  local count::Int

   count = begin
    @match binding begin
      UNTYPED_BINDING(__) => begin
        propagatedDimCount(binding.bindingExp)
      end

      TYPED_BINDING(__) => begin
        propagatedDimCount(binding.bindingExp)
      end

      _ => begin
        0
      end
    end
  end
  return count
end

@nospecializeinfer function isClassBinding(@nospecialize(binding::Binding))
  local pars::List{InstNode} = parents(binding)
  while pars !== nil
    @match Cons{InstNode}(parent, pars) = pars
    if isClass(parent)
      return true
    end
  end
  return false
end

function addParent(parent::InstNode,
                   binding::Binding)
  if ! (binding isa UNBOUND || binding isa RAW_BINDING)
    return binding
  end

  local parentLst = Cons{InstNode}(parent, binding.parents)
  local newBinding = if binding isa UNBOUND
    UNBOUND(parentLst,
            binding.isEach,
            binding.info)
  elseif binding isa RAW_BINDING
    #binding.parents = parentLst
    RAW_BINDING(binding.bindingExp,
                binding.scope,
                parentLst,
                binding.isEach,
                binding.info)
  else
    binding
  end
  return newBinding
end


@nospecializeinfer function parentCount(@nospecialize(binding::Binding))
  local count::Int = length(parents(binding))
  return count
end

function parents(@nospecialize(binding::Binding))
  local parents::Union{Vector{InstNode}, List{InstNode}}
  parents = begin
    @match binding begin
      UNBOUND(__) => begin
        binding.parents
      end
      RAW_BINDING(__) => begin
        binding.parents
      end
      UNTYPED_BINDING(
        bindingExp = BINDING_EXP(__),
      ) => begin
        binding.bindingExp.parents
      end
      TYPED_BINDING(bindingExp = BINDING_EXP(__)) => begin
        binding.bindingExp.parents
      end
      CEVAL_BINDING(bindingExp = BINDING_EXP(__)) => begin
        binding.bindingExp.parents
      end
      _ => begin
        InstNode[]
      end
    end
  end
  return parents
end

@nospecializeinfer function isTyped(@nospecialize(binding::Binding))
  local isTyped::Bool

   isTyped = begin
    @match binding begin
      TYPED_BINDING(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isTyped
end

@nospecializeinfer function isEach(@nospecialize(binding::Binding))
  local isEach::Bool

   isEach = begin
    @match binding begin
      UNBOUND(__) => begin
        binding.isEach
      end

      RAW_BINDING(__) => begin
        binding.isEach
      end

      UNTYPED_BINDING(__) => begin
        binding.isEach
      end

      TYPED_BINDING(__) => begin
        binding.eachType == EachType.EACH
      end

      _ => begin
        false
      end
    end
  end
  return isEach
end

function getType(@nospecialize(binding::Binding))
  local ty::NFType
   ty = begin
    @match binding begin
      UNBOUND(__) => begin
        TYPE_UNKNOWN()
      end
      RAW_BINDING(__) => begin
        TYPE_UNKNOWN()
      end

      UNTYPED_BINDING(__) => begin
        TYPE_UNKNOWN()
      end

      TYPED_BINDING(__) => begin
        binding.bindingType
      end

      FLAT_BINDING(__) => begin
        typeOf(binding.bindingExp)
      end

      CEVAL_BINDING(__) => begin
        typeOf(binding.bindingExp)
      end

      INVALID_BINDING(__) => begin
        getType(binding.binding)
      end
    end
  end
  return ty
end

@nospecializeinfer function Binding_getInfo(@nospecialize(binding::Binding))
  local info::SourceInfo

   info = begin
    @match binding begin
      UNBOUND(__) => begin
        binding.info
      end

      RAW_BINDING(__) => begin
        binding.info
      end

      UNTYPED_BINDING(__) => begin
        binding.info
      end

      TYPED_BINDING(__) => begin
        binding.info
      end

      _ => begin
        AbsynUtil.dummyInfo
      end
    end
  end
  return info
end

@nospecializeinfer function variability(@nospecialize(binding::Binding))
  local var::VariabilityType

   var = begin
    @match binding begin
      TYPED_BINDING(__) => begin
        binding.variability
      end

      FLAT_BINDING(__) => begin
        binding.variability
      end

      _ => begin
        Error.assertion(false, getInstanceName() + " got unknown binding", sourceInfo())
        fail()
      end
    end
  end
  return var
end

@nospecializeinfer function recordFieldBinding(fieldNode::InstNode, @nospecialize(recordBinding::Binding))
  local fieldBinding::Binding = recordBinding
  local exp::Expression
  local ty::M_Type
  local var::VariabilityType
  local field_name::String = name(fieldNode)

   fieldBinding = begin
    @match fieldBinding begin
      UNTYPED_BINDING(__) => begin
        fieldBinding.bindingExp = recordElement(field_name, fieldBinding.bindingExp)
        @info "exp in recordFieldBinding" toString(fieldBinding)
        fieldBinding
      end

      TYPED_BINDING(__) => begin
        exp = recordElement(field_name, fieldBinding.bindingExp)
        exp = addBindingExpParent(fieldNode, exp)
        ty = typeOf(exp)
        var = variability(exp)
        TYPED_BINDING(
          exp,
          ty,
          var,
          fieldBinding.eachType,
          fieldBinding.evaluated,
          fieldBinding.isFlattened,
          fieldBinding.info,
        )
      end

      FLAT_BINDING(__) => begin
        exp = recordElement(field_name, fieldBinding.bindingExp)
        var = variability(exp)
        FLAT_BINDING(exp, var)
      end

      CEVAL_BINDING(__) => begin
        fieldBinding.bindingExp = recordElement(field_name, fieldBinding.bindingExp)
        fieldBinding
      end
    end
  end
  return fieldBinding
end

function isCrefExp(binding::Binding)
  local isCrefVar::Bool
  isCrefVar = begin
    @match binding begin
      TYPED_BINDING(__) => begin
        isCref(getBindingExp(binding.bindingExp))
      end
      _ => begin
        false
      end
    end
  end
  return isCrefVar
end

function isRecordExp(binding::Binding)
  local isRecordExp::Bool

   isRecordExp = begin
    @match binding begin
      TYPED_BINDING(__) => begin
        isRecord(getBindingExp(binding.bindingExp))
      end

      _ => begin
        false
      end
    end
  end
  return isRecordExp
end

function setExp(@nospecialize(exp::Expression), binding::Binding)
  () = begin
    @match binding begin
      UNTYPED_BINDING(__) => begin
        binding.bindingExp = exp
        ()
      end

      TYPED_BINDING(__) => begin
        binding.bindingExp = exp
        ()
      end

      FLAT_BINDING(__) => begin
        binding.bindingExp = exp
        ()
      end
    end
  end
  return binding
end

function getExp(binding::Binding)
  local exp::Expression

   exp = begin
    @match binding begin
      UNTYPED_BINDING(__) => begin
        binding.bindingExp
      end

      TYPED_BINDING(__) => begin
        binding.bindingExp
      end

      FLAT_BINDING(__) => begin
        binding.bindingExp
      end
    end
  end
  return exp
end

@nospecialized function hasExp(binding::Binding)
  local hExp::Bool
   hExp = begin
    @match binding begin
      UNTYPED_BINDING(__) => true
      TYPED_BINDING(__) => true
      FLAT_BINDING(__) => true
      _ => false
    end
  end
  return hExp
end

function setTypedExp(@nospecialize(exp::Expression), binding::Binding)
  () = begin
    @match binding begin
      TYPED_BINDING(__) => begin
        @assign binding.bindingExp = exp
        ()
      end
      FLAT_BINDING(__) => begin
        @assign binding.bindingExp = exp
        ()
      end
    end
  end
  return binding
end

function getTypedExp(binding::Binding)
  local exp::Expression
   exp = begin
    @match binding begin
      TYPED_BINDING(__) => begin
        binding.bindingExp
      end

      FLAT_BINDING(__) => begin
        binding.bindingExp
      end
    end
  end
  return exp
end

function getUntypedExp(binding::Binding)
  local exp::Expression

  @match UNTYPED_BINDING(bindingExp = exp) = binding
  return exp
end

function typedExp(binding::Binding)
  local exp::Option{Expression}

   exp = begin
    @match binding begin
      TYPED_BINDING(__) => begin
        SOME(binding.bindingExp)
      end

      FLAT_BINDING(__) => begin
        SOME(binding.bindingExp)
      end

      _ => begin
        NONE()
      end
    end
  end
  return exp
end

function untypedExp(binding::Binding)
  local exp::Option{Expression}

   exp = begin
    @match binding begin
      UNTYPED_BINDING(__) => begin
        SOME(binding.bindingExp)
      end

      _ => begin
        NONE()
      end
    end
  end
  return exp
end

function isUnbound(binding::Binding)
  local isUnbound::Bool

   isUnbound = begin
    @match binding begin
      UNBOUND(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isUnbound
end

function isExplicitlyBound(binding::Binding)
  local isBound::Bool
  isBound = begin
    @match binding begin
      UNBOUND(__) => begin
        false
      end
      CEVAL_BINDING(__) => begin
        false
      end
      _ => begin
        true
      end
    end
  end
  return isBound
end

function isBound(binding::Binding)
  local isBound::Bool
  isBound = begin
    @match binding begin
      UNBOUND(__) => begin
        false
      end
      _ => begin
        true
      end
    end
  end
  return isBound
end

function fromAbsyn(
  bindingExp::Option{<:Absyn.Exp},
  eachPrefix::Bool,
  parents::List{<:InstNode},
  scope::InstNode,
  info::SourceInfo,
)
  local binding::Binding
  binding = begin
    local exp::Absyn.Exp
    @match bindingExp begin
      SOME(exp) => begin
        RAW_BINDING(exp, scope, parents, eachPrefix, info)
      end
      _ => begin
        if eachPrefix
          UNBOUND(parents, true, info)
        else
          EMPTY_BINDING
        end
      end
    end
  end
  return binding
end


"""
@author johti17
"""
function modelicaListOfListToJuliaMatrix(modelicaLstLst::List{Cons{T}}) where {T}
  local matrix = Vector{T}[]
  for lst in modelicaLstLst
    push!(matrix, listArray(lst))
  end
  #= Convert to matrix =#
  return hcat(matrix...)
end


"""
@author johti17
"""
function modelicaMatrixToJuliaMatrix(modelicaMatrix::MATRIX_EXPRESSION)
  local jlMatrix = modelicaListOfListToJuliaMatrix(modelicaMatrix.elements)
  return jlMatrix
end

"""
@author johti17.
Same as modelicaMatrixToJuliaMatrix, but for matrices represented as a List of Array Expressions.
"""
function modelicaMatrixToJuliaMatrix(lst::Union{Cons{Expression},Vector{Expression}})
  local matrix = Vector{Expression}[]
  #= Convert the list of array expressions into a list of list. =#
  for exp in lst
    @assert exp isa ARRAY_EXPRESSION "The expressions in the list must be of type array expressions. The expression was: $(T)"
    push!(matrix, exp.elements)
  end
  local jlMatrix::Matrix{ARRAY_EXPRESSION} = hcat(matrix...)
  return Base.permutedims(jlMatrix)
end

"""
  Converts a Matrix of expressions to a list of array expressions.
  @johti17
"""
function jlMatrixToModelicaArrayExpLists(jlMatrix::Matrix{ARRAY_EXPRESSION})
  (ncols, nrows) = Base.size(jlMatrix)
  arrayExps::Vector{Expression} = Expression[]
  local lstLst::List{Expression} = nil
  for col in eachcol(jlMatrix)
    for (i,e) in enumerate(col)
      push!(arrayExps, e)
    end
    (combinedElements) = Base.reduce(vcat,
                            Base.map(x -> x.elements, arrayExps))
    lstLst = ARRAY_EXPRESSION(arrayExps[1].ty, combinedElements, arrayExps[1].literal) <| lstLst
    arrayExps = Expression[]
  end
  lstLst = listReverse(lstLst)
  #println("List list:\n" * toString(lstLst))
  return lstLst
end

"""
  Converts a Matrix of expressions to a vector of array expressions.
  @johti17
"""
function jlMatrixToModelicaArrayExpVector(jlMatrix::Matrix{ARRAY_EXPRESSION})
  (ncols, nrows) = Base.size(jlMatrix)
  arrayExps::Vector{Expression} = Expression[]
  local arrArr = ARRAY_EXPRESSION[]
  for col in eachcol(jlMatrix)
    for (i,e) in enumerate(col)
      push!(arrayExps, e)
    end
    local arrayExpressionType = arrayExps[1].ty
    local arrayExpressionLiteral = arrayExps[1].literal
    (combinedElements) = Base.reduce(vcat,
                                     Base.map(x -> x.elements, arrayExps))
    push!(arrArr, ARRAY_EXPRESSION(arrayExpressionType,
                                      combinedElements,
                                      arrayExpressionLiteral))
    arrayExps = Expression[]
  end
  return arrArr
end

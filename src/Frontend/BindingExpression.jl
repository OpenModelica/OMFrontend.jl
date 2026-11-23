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
  fold(exp1, mostPropagatedSubExp_traverser, mp, MaxProp)
  fold(exp2, mostPropagatedSubExp_traverser, mp, MaxProp)
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
  fold(exp, mostPropagatedSubExp_traverser, mp, MaxProp)
  (mp.exp, mp.count)
end

function bindingExpMap4(@nospecialize(exp::Expression), subs::List{<:Subscript}) ::Expression
  local prop_count::Int
  local prop_subs::List{Subscript}
  @match exp begin
    BINDING_EXP(__)  => begin
      prop_count = propagatedDimCount(exp)
      prop_subs = ListUtil.lastN(subs, prop_count)
      applySubscripts(prop_subs, exp.exp)
    end
    _ => exp
  end
end

function bindingExpMap3(@nospecialize(exp::Expression), evalFunc::EvalFunc, subs::List{<:Subscript})
  local result::Expression
   result = map(exp, (@nospecialize(x::Expression),) -> bindingExpMap4(x, subs)) #TODO?
   result = evalFunc(result)
  result
end

function bindingExpMap2(@nospecialize(exp::Expression), evalFunc::EvalFunc, mostPropagatedCount::Int, @nospecialize(mostPropagatedExp::Expression))
  local result::Expression
  local exp_ty::ModelicaType
  local bind_ty::ModelicaType
  local dims::List{Dimension}
  local parents::List{InstNode}
  local is_each::Bool
  @match BINDING_EXP(exp = e, expType = exp_ty, parents = parents, isEach = is_each) = mostPropagatedExp
  dims = ListUtil.firstN(arrayDims(exp_ty), mostPropagatedCount, Dimension)
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
  local e::Expression
  if listEmpty(dims)
    #= The subscripts were accumulated innermost first (omc's vectorize). =#
    outExp = func(exp, listReverse(accumSubs))
  else
    local expl = Expression[]
    local dim = listHead(dims)
    local rest_dims = listRest(dims)
    iter = fromDim(dim)
    while hasNext(iter)
      (iter, e) = next(iter)
      e = vectorize(exp, rest_dims, func, Cons{Subscript}(SUBSCRIPT_INDEX(e), accumSubs))
      push!(expl, e)
    end
    outExp = makeArray(liftArrayLeft(typeOf(expl[1]), fromInteger(length(expl))), expl)
  end
  outExp
end

"""
  Calculates the expression type and binding type of an expression given the
  number of dimensions it's been propagated through.
"""
function bindingExpType(@nospecialize(exp::Expression), propagatedDimCount::Int)
  local bindingType::ModelicaType
  local expType::ModelicaType
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
      _ => 0
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
      BINDING_EXP(__) => getBindingExp(bindingExp.exp)
      _ => bindingExp
    end
  end
  outExp
end

isBindingExp(@nospecialize(exp::Expression)) ::Bool = isvariant(exp, BINDING_EXP)

function nthEnumLiteral(ty::ModelicaType, n::Int) ::Expression
  local exp::Expression
  exp = ENUM_LITERAL_EXPRESSION(ty, nthEnumLiteral(ty, n), n)
  exp
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
    _ => exp
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
    local ty::ModelicaType
    @match outExp begin
      CREF_EXPRESSION(ty = TYPE_COMPLEX(cls = cls), cref = cr)  => begin
        local comps::Vector{InstNode} = getComponents(classTree(getClass(cls)))
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
        local outExpElements = Expression[splitRecordCref(e) for e in outExp.elements]
        ARRAY_EXPRESSION(outExp.ty, outExpElements, outExp.literal)
      end
      _ => exp
    end
  end
  outExp
end

"""
  Returns the nth field of a record expression. If the expression is an array
  it will return an array with the nth field in each array element.
"""
function nthRecordElement(index::Int, @nospecialize(recordExp::Expression)) ::Expression

   local node::InstNode
   @match recordExp begin
     RECORD_EXPRESSION(__) => recordExp.elements[index]

     ARRAY_EXPRESSION(ty = TYPE_ARRAY(elementType = TYPE_COMPLEX(cls = node))) where (isempty(recordExp.elements))  => begin
       makeEmptyArray(getType(nthComponent(index, getClass(node))))
     end

     ARRAY_EXPRESSION(__)  => begin
       expV = Expression[nthRecordElement(index, e) for e in recordExp.elements]
       makeArray(liftArrayLeft(typeOf(expV[1]), fromInteger(length(expV))), expV)
     end

     RECORD_ELEMENT_EXPRESSION(ty = TYPE_ARRAY(elementType = TYPE_COMPLEX(cls = node)))  => begin
        node = nthComponent(index, getClass(node))
       _typeRecordExpField!(node, recordExp)
       RECORD_ELEMENT_EXPRESSION(recordExp, index, name(node), liftArrayLeftList(getType(node), arrayDims(recordExp.ty)))
     end

     BINDING_EXP(__)  => begin
       local f = @closure (e) -> nthRecordElement(index, e)
       bindingExpMap(recordExp, f)
     end

     _  => begin
       @match TYPE_COMPLEX(cls = node) = typeOf(recordExp)
        node = nthComponent(index, getClass(node))
       _typeRecordExpField!(node, recordExp)
       RECORD_ELEMENT_EXPRESSION(recordExp, index, name(node), getType(node))
     end
   end
end

#= A field of a record component not typed yet is typed here, as a reference to it would be: its
   type before had no dimensions (the element type). Under parallel typing a record component is
   typed before its fields, which other tasks type; its field's binding then had type Real for
   Real[3] (Buildings' fan records, `per = perFan`: an unknown dimension in typeDimension). =#
function _typeRecordField!(field::InstNode, recordCref::ComponentRef)::Nothing
  isComponent(field) && isvariant(component(resolveOuter(field)), UNTYPED_COMPONENT) || return nothing
  local origin = isvariant(recordCref, COMPONENT_REF_CREF) && isFunction(explicitParent(node(recordCref))) ?
    ORIGIN_FUNCTION : ORIGIN_CLASS
  typeComponent(field, origin)
  return nothing
end

#= The same for a field read through a record element or a subscripted record, found through
   the reference the expression reads (Buildings DX coils: datCoi.sta.perCur.EIRFunFF, sta an
   array of records, had type Real[1]: sta's dimension without its own). =#
function _typeRecordExpField!(field::InstNode, @nospecialize(recordExp::Expression))::Nothing
  local exp = recordExp
  while !(exp isa CREF_EXPRESSION)
    if exp isa RECORD_ELEMENT_EXPRESSION
      exp = exp.recordExp
    elseif exp isa SUBSCRIPTED_EXP_EXPRESSION
      exp = exp.exp
    else
      #= Another expression of records (MSL Batteries' `cellData = {{if ... then cellDataDegraded else
         cellDataOriginal for kp in 1:Np} for ks in 1:Ns}`): typed by the first record reference in it. Untyped,
         the field's type lacked its own dimensions, which serial typing had by its order and parallel typing
         not always (CCCV_StackRC, 1 in 3 runs: OCV_SOC_internal deduced from a Real[3, 2]). =#
      local first::Union{Nothing, CREF_EXPRESSION} =
        fold(exp, (e::Expression, acc::Union{Nothing, CREF_EXPRESSION}) ->
               (acc === nothing && e isa CREF_EXPRESSION && isComplex(arrayElementType(e.ty))) ? e : acc,
             nothing, Union{Nothing, CREF_EXPRESSION})
      first === nothing && return nothing
      return _typeRecordField!(field, first.cref)
    end
  end
  return _typeRecordField!(field, exp.cref)
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
    local ty::ModelicaType
    local index::Int
    local cref::ComponentRef
    @match recordExp begin
      RECORD_EXPRESSION(ty = TYPE_COMPLEX(cls = node))  => begin
        cls = getClass(node)
        index = lookupComponentIndex(elementName, cls)
        recordExp.elements[index]
      end

      CREF_EXPRESSION(__) where {isComplex(arrayElementType(recordExp.ty))}  => begin
        #= An array of records too: the field's cref sliced over it (r3.r2.r, omc SlicedCref2). =#
        @match TYPE_COMPLEX(cls = node) = arrayElementType(recordExp.ty)
        cls_tree = classTree(getClass(node))
        local entryInfo  = lookupElement(elementName, cls_tree)
        node = entryInfo.node
        @assert entryInfo.isImport == false "Entry info was not an import."
        _typeRecordField!(node, recordExp.cref)
        ty = getType(node)
        cref = prefixCref(node, ty, nil, recordExp.cref)
        ty = liftArrayLeftList(ty, arrayDims(recordExp.ty))
        CREF_EXPRESSION(ty, cref)
      end

      ARRAY_EXPRESSION(ty = TYPE_ARRAY(elementType = TYPE_COMPLEX(cls = node))) where {isempty(recordExp.elements)}  => begin
        cls = getClass(node)
        index = lookupComponentIndex(elementName, cls)
        ty = liftArrayLeftList(getType(nthComponent(index, cls)), arrayDims(recordExp.ty))
        makeEmptyArray(ty)
      end

      ARRAY_EXPRESSION(ty = TYPE_ARRAY(elementType = TYPE_COMPLEX(cls = node)))  => begin
        index = lookupComponentIndex(elementName, getClass(node))
        expV = Expression[nthRecordElement(index, e) for e in recordExp.elements]
        ty = liftArrayLeft(typeOf(expV[1]), fromInteger(length(expV)))
        #= Literal only if the fields are: an evaluated record keeps its fields unevaluated (read
           later), the array of records is literal. Buildings ElectricChillerParallel:
           fill(perCHWPum, numChi)'s pressure.V_flow stayed mCHW_flow_nominal/1000*{...} in sum(). =#
        makeArray(ty, expV; literal = recordExp.literal && all(isLiteral, expV))
      end

      BINDING_EXP(__)  => begin
        local f = @closure (x) -> recordElement(elementName, x)
        bindingExpMap(recordExp, f)
      end

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
         outExp = recordElement(elementName, recordExp.exp)
        SUBSCRIPTED_EXP_EXPRESSION(outExp, recordExp.subscripts, lookupRecordFieldType(elementName, recordExp.ty))
      end

      EMPTY_EXPRESSION(__) => fail()

      _  => begin
         ty = typeOf(recordExp)
        @match TYPE_COMPLEX(cls = node) = arrayElementType(ty)
         cls = getClass(node)
         index = lookupComponentIndex(elementName, cls)
         node = nthComponent(index, cls)
         _typeRecordExpField!(node, recordExp)
         #= The record array's dimensions first (omc: liftArrayLeftList): f[6] of sta[1] is
            Real[1, 6], not Real[6, 1] (a field's size deduced from it was sta's). =#
         ty = liftArrayLeftList(getType(node), arrayDims(ty))
        RECORD_ELEMENT_EXPRESSION(recordExp, index, elementName, ty)
      end
    end
  end
  outExp
end

function tupleElement(@nospecialize(exp::Expression), ty::ModelicaType, index::Int) ::Expression
  local ety::ModelicaType
  @match exp begin
    TUPLE_EXPRESSION(__) => listGet(exp.elements, index)

    ARRAY_EXPRESSION(__)  => begin
      ety = unliftArray(ty)
      ARRAY_EXPRESSION(exp.ty, Expression[tupleElement(e, ety, index) for e in exp.elements], exp.literal)
    end

    BINDING_EXP(__) => bindingExpMap(exp, e -> tupleElement(e, ty, index))

    _ => TUPLE_ELEMENT_EXPRESSION(exp, index, ty)
  end
end

function toScalar(@nospecialize(exp::Expression)) ::Expression

   @match exp begin
     ARRAY_EXPRESSION(__) where {length(exp.elements) == 1} => toScalar(exp.elements[1])

     _ => exp
   end
end

function enumIndexExp(@nospecialize(enumExp::Expression)) ::Expression

   @match enumExp begin
     ENUM_LITERAL_EXPRESSION(__) => INTEGER_EXPRESSION(enumExp.index)

     _ => CALL_EXPRESSION(makeTypedCall(BuiltinFuncs.INTEGER_ENUM, Expression[enumExp], variability(enumExp)))
   end
end

isEmpty(@nospecialize(exp::Expression)) ::Bool = isvariant(exp, EMPTY_EXPRESSION)

function makeImmutable(@nospecialize(exp::Expression))
  local outExp::Expression
   outExp = begin
    @match exp begin
      MUTABLE_EXPRESSION(__) => P_Pointer.access(exp.exp)

      _ => exp
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
      INTEGER_EXPRESSION(__) => Variability.CONSTANT

      REAL_EXPRESSION(__) => Variability.CONSTANT

      STRING_EXPRESSION(__) => Variability.CONSTANT

      BOOLEAN_EXPRESSION(__) => Variability.CONSTANT

      ENUM_LITERAL_EXPRESSION(__) => Variability.CONSTANT

      CLKCONST_EXPRESSION(_) => Variability.DISCRETE

      CREF_EXPRESSION(__) => variability(exp.cref)

      TYPENAME_EXPRESSION(__) => Variability.CONSTANT

      ARRAY_EXPRESSION(__) => variabilityVector(exp.elements)

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

      TUPLE_EXPRESSION(__) => variabilityList(exp.elements)

      RECORD_EXPRESSION(__) => variabilityVector(exp.elements)

      CALL_EXPRESSION(__) => variability(exp.call)

      SIZE_EXPRESSION(__)  => begin
        if isSome(exp.dimIndex)
           var = variabilityMax(Variability.PARAMETER, variability(Util.getOption(exp.dimIndex)))
        else
           var = Variability.PARAMETER
        end
        var
      end

      END_EXPRESSION(__) => Variability.PARAMETER

      BINARY_EXPRESSION(__) => variabilityMax(variability(exp.exp1), variability(exp.exp2))

      UNARY_EXPRESSION(__) => variability(exp.exp)

      LBINARY_EXPRESSION(__) => variabilityMax(variability(exp.exp1), variability(exp.exp2))

      LUNARY_EXPRESSION(__) => variability(exp.exp)

      RELATION_EXPRESSION(__)  => begin
        variabilityMin(variabilityMax(variability(exp.exp1), variability(exp.exp2)), Variability.DISCRETE)
      end

      IF_EXPRESSION(__)  => begin
        variabilityMax(variability(exp.condition), variabilityMax(variability(exp.trueBranch), variability(exp.falseBranch)))
      end

      CAST_EXPRESSION(__) => variability(exp.exp)

      UNBOX_EXPRESSION(__) => variability(exp.exp)

      SUBSCRIPTED_EXP_EXPRESSION(__) => variabilityMax(variability(exp.exp), variabilityList(exp.subscripts))

      TUPLE_ELEMENT_EXPRESSION(__) => variability(exp.tupleExp)

      RECORD_ELEMENT_EXPRESSION(__) => variability(exp.recordExp)

      BOX_EXPRESSION(__) => variability(exp.exp)

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__) => Variability.CONTINUOUS

      BINDING_EXP(__) => variability(exp.exp)

      _  => begin
        Error.assertion(false, getInstanceName() + " got unknown expression.", sourceInfo())
        fail()
      end
    end
  end
  var
end

function promote2(@nospecialize(exp::Expression), isArray::Bool, dims::Int, types::List{<:ModelicaType}) ::Expression
  local outExp::Expression
   outExp = begin
    local ty::ModelicaType
    local rest_ty::List{ModelicaType}
    local expanded::Bool
    #= No types left, we're done! =#
    @match (exp, types) begin
      (_,  nil()) => exp
      (ARRAY_EXPRESSION(__), ty <| rest_ty)  => begin
        makeArray(ty, Expression[promote2(e, false, dims, rest_ty) for e in exp.elements])
      end
      (_, _) where (isArray)  => begin
        #= An array, promote each element in the array.
           An expression with array type, but which is not an array expression.
           Such an expression can't be promoted here, so we create a promote call instead. =#
        (outExp, expanded) = expand(exp)
        if expanded
           outExp = promote2(outExp, true, dims, types)
        else
          outExp = CALL_EXPRESSION(makeTypedCall(BuiltinFuncs.PROMOTE,
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

function promote(@nospecialize(e::Expression), ty::ModelicaType, n::Int) ::Tuple{Expression, ModelicaType}
  local dims::List{Dimension}
  local ety::ModelicaType
  local tys::List{ModelicaType} = nil
  local is_array::Bool
  #=  Construct the dimensions that needs to be added. =#
   dims = list(fromInteger(1) for _ in dimensionCount(ty):n - 1)
  if ! listEmpty(dims)
     dims = listAppend(arrayDims(ty), dims)
     is_array = isArray(ty)
     ety = arrayElementType(ty)
     ty = liftArrayLeftList(ety, dims)
    while ! listEmpty(dims)
       tys = Cons{ModelicaType}(liftArrayLeftList(ety, dims), tys)
       dims = listRest(dims)
    end
     e = promote2(e, is_array, n, listReverse(tys))
  end
  #= Concatenate the existing dimensions and the added ones.
     Construct the result type.
     Construct the expression types, to avoid having to create a new type
     for each subexpression that will be created. =#
  (e, ty)
end

function promoteRef(@nospecialize(e::Expression), ty::ModelicaType, n::Int, tyRef::Ref{ModelicaType})::Expression
  local dims::List{Dimension}
  local ety::ModelicaType
  local tys::List{ModelicaType} = nil
  local is_array::Bool
  #=  Construct the dimensions that needs to be added. =#
   dims = list(fromInteger(1) for _ in dimensionCount(ty):n - 1)
  if ! listEmpty(dims)
     dims = listAppend(arrayDims(ty), dims)
     is_array = isArray(ty)
     ety = arrayElementType(ty)
     ty = liftArrayLeftList(ety, dims)
    while ! listEmpty(dims)
       tys = Cons{ModelicaType}(liftArrayLeftList(ety, dims), tys)
       dims = listRest(dims)
    end
     e = promote2(e, is_array, n, listReverse(tys))
  end
  #= Concatenate the existing dimensions and the added ones.
     Construct the result type.
     Construct the expression types, to avoid having to create a new type
     for each subexpression that will be created. =#
  tyRef.x = ty
  e
end

function makeIdentityMatrix(n::Int, elementType::ModelicaType) ::Expression
  local matrix::Expression

  local zero::Expression
  local one::Expression
  local row::List{Expression}
  local rows::List{Expression} = nil
  local row_ty::ModelicaType

  zero = makeZero(elementType)
  one = makeOne(elementType)
  row_ty = TYPE_ARRAY(elementType, list(fromInteger(n)))
  for i in 1:n
     row = nil
    for _ in 2:i
       row = Cons{Expression}(zero, row)
    end
     row = Cons{Expression}(one, row)
    for _ in i:n - 1
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
  local ty::ModelicaType
  local row_ty::ModelicaType
  local expl::Vector{Expression}
  local matrix::Vector{Vector{Expression}}
  local literal::Bool

  @match ARRAY_EXPRESSION(TYPE_ARRAY(ty, Cons{Dimension}(dim1, Cons{Dimension}(dim2, rest_dims))), expl, literal) = arrayExp
  if ! isempty(expl)
    row_ty = TYPE_ARRAY(ty, Cons{Dimension}(dim1, rest_dims))
    matrix = Vector{Expression}[(e::ARRAY_EXPRESSION).elements for e in expl]
    matrix = ArrayUtil.transposeArray(matrix)
    expl = Expression[makeArray(row_ty, row, literal = literal) for row in matrix]
  end
  outExp = makeArray(TYPE_ARRAY(ty, Cons{Dimension}(dim2, Cons{Dimension}(dim1, rest_dims))), expl, literal = literal)
  outExp
end

function hasArrayCall2(@nospecialize(exp::Expression)) ::Bool
  local call::Call
  local ty::ModelicaType
  @match exp begin
    CALL_EXPRESSION(call = call)  => begin
       ty = typeOf(call)
      isArray(ty) && isVectorizeable(call)
    end

    TUPLE_ELEMENT_EXPRESSION(tupleExp = CALL_EXPRESSION(call = call))  => begin
      ty = nthTupleType(typeOf(call), exp.index)
      isArray(ty) && isVectorizeable(call)
    end

    _ => false
  end
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

#= The only element of an array of one element. =#
function arrayScalarElement(@nospecialize(arrayExp::Expression)) ::Expression
  (arrayExp isa ARRAY_EXPRESSION && length(arrayExp.elements) == 1) || fail()
  return arrayExp.elements[1]
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
      _ => Cons{Expression}(exp, elements)
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

function arrayElements(array::ARRAY_EXPRESSION)
  return array.elements
end

function negate(@nospecialize(exp::Expression)) ::Expression
  exp = begin
    @match exp begin
      INTEGER_EXPRESSION(__) => INTEGER_EXPRESSION(-exp.value)

      REAL_EXPRESSION(__) => REAL_EXPRESSION(-exp.value)

      CAST_EXPRESSION(__) => CAST_EXPRESSION(exp.ty, negate(exp.exp))

      UNARY_EXPRESSION(__) => exp.exp

      _ => UNARY_EXPRESSION(OPERATOR(typeOf(exp), Op.UMINUS), exp)
    end
  end
  exp
end

function isNegated(@nospecialize(exp::Expression)) ::Bool

   @match exp begin
     INTEGER_EXPRESSION(__) => exp.value < 0

     REAL_EXPRESSION(__) => exp.value < 0

     CAST_EXPRESSION(__) => isNegated(exp.exp)

     UNARY_EXPRESSION(__) => true

     _ => false
   end
end

function unbox(@nospecialize(boxedExp::Expression)) ::Expression

   local ty::ModelicaType
   @match boxedExp begin
     BOX_EXPRESSION(__) => boxedExp.exp

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

function box(@nospecialize(exp::Expression)) ::Expression

   @match exp begin
     BOX_EXPRESSION(__) => exp

     _ => BOX_EXPRESSION(exp)
   end
end

function makeMinValue(ty::ModelicaType) ::Expression

   @match ty begin
     TYPE_REAL(__) => REAL_EXPRESSION(-System.realMaxLit())

     TYPE_INTEGER(__) => INTEGER_EXPRESSION(-System.intMaxLit())

     TYPE_BOOLEAN(__) => BOOLEAN_EXPRESSION(false)

     TYPE_ENUMERATION(__) => ENUM_LITERAL_EXPRESSION(ty, listHead(ty.literals), 1)

     TYPE_ARRAY(__) => fillType(ty, makeMinValue(arrayElementType(ty)))
   end
end

function makeMaxValue(ty::ModelicaType) ::Expression

   @match ty begin
     TYPE_REAL(__) => REAL_EXPRESSION(System.realMaxLit())

     TYPE_INTEGER(__) => INTEGER_EXPRESSION(System.intMaxLit())

     TYPE_BOOLEAN(__) => BOOLEAN_EXPRESSION(true)

     TYPE_ENUMERATION(__) => ENUM_LITERAL_EXPRESSION(ty, ListUtil.last(ty.literals), listLength(ty.literals))

     TYPE_ARRAY(__) => fillType(ty, makeMaxValue(arrayElementType(ty)))
   end
end

function makeOne(ty::ModelicaType) ::Expression

   @match ty begin
     TYPE_REAL(__) => REAL_EXPRESSION(1.0)

     TYPE_INTEGER(__) => INTEGER_EXPRESSION(1)

     TYPE_ARRAY(__) => fillType(ty, makeOne(arrayElementType(ty)))
   end
end

function makeOperatorRecordZero(recordNode::InstNode) ::Expression
  local zeroExp::Expression
  local op_node::InstNode
  local fn::MODELICA_FUNCTION
  op_node = lookupElementNode("'0'", getClass(recordNode))
  instFunctionNode(op_node)
  fns = typeNodeCache(op_node)
  fn = fns[1]
  zeroExp = CALL_EXPRESSION(makeTypedCall(fn, Expression[], Variability.CONSTANT))
  zeroExp = evalExp(zeroExp)
  zeroExp
end

function makeZero(ty::ModelicaType) ::Expression

   @match ty begin
     TYPE_REAL(__) => REAL_EXPRESSION(0.0)

     TYPE_INTEGER(__) => INTEGER_EXPRESSION(0)

     TYPE_ARRAY(__) => fillType(ty, makeZero(arrayElementType(ty)))

     TYPE_COMPLEX(__) => makeOperatorRecordZero(ty.cls)
   end
end

"""
  Creates an array with the given dimension, where each element is the given
  expression. Example: liftArray([3], 1) => {1, 1, 1}
"""
function liftArray(dim::Dimension, @nospecialize(exp::Expression)) ::Tuple{Expression, ModelicaType}
  local arrayType::ModelicaType = typeOf(exp)
  local expl::Vector{Expression} = Expression[]
  for _ in 1:size(dim)
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
function fillType(ty::ModelicaType, @nospecialize(fillExp::Expression)) ::Expression
  local exp::Expression = fillExp
  local dims::List{Dimension} = arrayDims(ty)
  local expl::Vector{Expression}
  local arr_ty::ModelicaType = arrayElementType(ty)
  #= Innermost dimension first: each pass lifts the array by one dimension on the left. =#
  for dim in listReverse(dims)
    expl  = Expression[]
    for _ in 1:size(dim)
      push!(expl, exp)
    end
    arr_ty = liftArrayLeft(arr_ty, dim)
    exp = makeArray(arr_ty, expl, literal = isLiteral(exp))
  end
  exp
end

function fillArgsDimVec(@nospecialize(fillExp::Expression), dims::Vector{Expression})
  local dimSize
  local arr::Vector{Expression}
  local result = fillExp
  local arrTy = typeOf(result)
  local literal::Bool = isLiteral(fillExp)
  for d in Iterators.reverse(dims)
    dimSize = toInteger(d)
    arr = Expression[result for _ in 1:dimSize]
    arrTy = liftArrayLeft(arrTy, fromInteger(dimSize))
    result = makeArray(arrTy, arr, literal = literal)
  end
  return result
end

function isRecordOrRecordArray(@nospecialize(exp::Expression)) ::Bool
  @match exp begin
    RECORD_EXPRESSION(__) => true
    ARRAY_EXPRESSION(__) => ArrayUtil.all(exp.elements, isRecordOrRecordArray)
    _ => false
  end
end

isRecord(::Expression) = false
isRecord(exp::RECORD_EXPRESSION) = isRecordOrRecordArray(exp::Expression)

isBoolean(@nospecialize(exp::Expression)) ::Bool = isvariant(exp, BOOLEAN_EXPRESSION)

isInteger(@nospecialize(exp::Expression)) ::Bool = isvariant(exp, INTEGER_EXPRESSION)

function isLiteral(@nospecialize(exp::Expression)) ::Bool

   @match exp begin
     INTEGER_EXPRESSION(__) => true

     REAL_EXPRESSION(__) => true

     STRING_EXPRESSION(__) => true

     BOOLEAN_EXPRESSION(__) => true

     ENUM_LITERAL_EXPRESSION(__) => true

     ARRAY_EXPRESSION(__) => ArrayUtil.all(exp.elements, isLiteral)

     RECORD_EXPRESSION(__) => ArrayUtil.all(exp.elements, isLiteral)

     RANGE_EXPRESSION(__)  => begin
       isLiteral(exp.start) && isLiteral(exp.stop) && Util.applyOptionOrDefault(exp.step, isLiteral, true)
     end
     _ => false
   end
end

isScalarLiteral(@nospecialize(exp::Expression)) ::Bool = isvariant(exp, INTEGER_EXPRESSION) || isvariant(exp, REAL_EXPRESSION) || isvariant(exp, STRING_EXPRESSION) || isvariant(exp, BOOLEAN_EXPRESSION) || isvariant(exp, ENUM_LITERAL_EXPRESSION)

"""
omc Expression.isNonNegative: true if exp is known to be >= 0 (a cref's min attribute is not
looked up here).
"""
function isNonNegative(@nospecialize(exp::Expression))::Bool
  @match exp begin
    INTEGER_EXPRESSION(__) => exp.value >= 0
    REAL_EXPRESSION(__) => exp.value >= 0.0
    CAST_EXPRESSION(__) => isNonNegative(exp.exp)
    UNARY_EXPRESSION(__) => isNonPositive(exp.exp)
    _ => false
  end
end

"""
omc Expression.isNonPositive: true if exp is known to be <= 0 (a cref's max attribute is not
looked up here).
"""
function isNonPositive(@nospecialize(exp::Expression))::Bool
  @match exp begin
    INTEGER_EXPRESSION(__) => exp.value <= 0
    REAL_EXPRESSION(__) => exp.value <= 0.0
    CAST_EXPRESSION(__) => isNonPositive(exp.exp)
    UNARY_EXPRESSION(__) => isNonNegative(exp.exp)
    _ => false
  end
end

"""
omc Expression.makeDefaultValue: a value of type ty for a variable without a start value:
0 (min if min >= 0, max if max <= 0), "", false, the first enumeration literal (min if given).
"""
function makeDefaultValue(ty::ModelicaType, min::Union{Expression, Nothing} = nothing,
                          max::Union{Expression, Nothing} = nothing)::Expression
  if isInteger(ty) || isReal(ty)
    min !== nothing && isNonNegative(min) && return min
    max !== nothing && isNonPositive(max) && return max
    return isInteger(ty) ? INTEGER_EXPRESSION(0) : REAL_EXPRESSION(0.0)
  elseif isString(ty)
    return STRING_EXPRESSION("")
  elseif isBoolean(ty)
    return BOOLEAN_EXPRESSION(false)
  elseif isEnumeration(ty)
    min !== nothing && return min
    return ENUM_LITERAL_EXPRESSION(ty, listHead(ty.literals), 1)
  elseif isArray(ty)
    return fillType(ty, makeDefaultValue(arrayElementType(ty)))
  elseif isTuple(ty)
    return TUPLE_EXPRESSION(ty, arrayList(Expression[makeDefaultValue(t) for t in ty.types]))
  end
  error("makeDefaultValue: no default value of type " * toString(ty))
end

function isOne(@nospecialize(exp::Expression)) ::Bool
  @match exp begin
    INTEGER_EXPRESSION(__) => exp.value == 1
    REAL_EXPRESSION(__) => exp.value == 1.0
    CAST_EXPRESSION(__) => isOne(exp.exp)
    _ => false
  end
end

function isZero(@nospecialize(exp::Expression)) ::Bool

   @match exp begin
     INTEGER_EXPRESSION(__) => exp.value == 0

     REAL_EXPRESSION(__) => exp.value == 0.0

     CAST_EXPRESSION(__) => isZero(exp.exp)

     UNARY_EXPRESSION(__) => isZero(exp.exp)

     _ => false
   end
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
   @match exp begin
     CREF_EXPRESSION(__) => isIterator(exp.cref)

     _ => false
   end
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

   @match arrayExp begin
     ARRAY_EXPRESSION(__) where (!isempty(arrayExp.elements) && arrayExp.elements[1] isa ARRAY_EXPRESSION)  => begin
       all(e -> arrayAllEqual2(e, element), arrayExp.elements)
     end

     ARRAY_EXPRESSION(__) => all(e -> isEqual(e, element), arrayExp.elements)

     _ => true
   end
end

"""Checks if all scalar elements in an array are equal to each other."""
function arrayAllEqual(@nospecialize(arrayExp::Expression)) ::Bool

   @matchcontinue arrayExp begin
     ARRAY_EXPRESSION(__) => arrayAllEqual2(arrayExp, arrayFirstScalar(arrayExp))

     _ => true
   end
end

""" #= Returns the first scalar element of an array. Fails if the array is empty. =#"""
@nospecializeinfer function arrayFirstScalar(@nospecialize(arrayExp::Expression)) ::Expression

   @match arrayExp begin
     ARRAY_EXPRESSION(__) => arrayFirstScalar(arrayExp.elements[1])

     _ => arrayExp
   end
end

@nospecializeinfer function callContainsShallow(call::Call, func::FT) ::Bool where {FT<:Function}
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

      TYPED_CALL(__) => listContainsShallow(call.arguments, func)

      UNTYPED_ARRAY_CONSTRUCTOR(__) => func(call.exp)

      TYPED_ARRAY_CONSTRUCTOR(__) => func(call.exp)

      UNTYPED_REDUCTION(__) => func(call.exp)

      TYPED_REDUCTION(__) => func(call.exp)
    end
  end
  res
end

function listContainsShallow(expl::Union{List{<:Expression}, Vector{Expression}}, func::FT)::Bool where {FT<:Function}
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

function crefContainsShallow(cref::ComponentRef, func::FT) ::Bool where {FT<:Function}

   @match cref begin
     COMPONENT_REF_CREF(__) => listContainsExpShallow(cref.subscripts, func) || crefContainsShallow(cref.restCref, func)

     _ => false
   end
end

function containsShallow(@nospecialize(exp::Expression), func::FT) ::Bool where {FT<:Function}
  local res::Bool

   res = begin
    @match exp begin
      CREF_EXPRESSION(__) => crefContainsShallow(exp.cref, func)

      ARRAY_EXPRESSION(__) => listContainsShallow(exp.elements, func)

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

      RANGE_EXPRESSION(__) => func(exp.start) || Util.applyOptionOrDefault(exp.step, func, false) || func(exp.stop)

      TUPLE_EXPRESSION(__) => listContainsShallow(exp.elements, func)

      RECORD_EXPRESSION(__) => listContainsShallow(exp.elements, func)

      CALL_EXPRESSION(__) => callContainsShallow(exp.call, func)

      SIZE_EXPRESSION(__) => Util.applyOptionOrDefault(exp.dimIndex, func, false) || func(exp.exp)

      BINARY_EXPRESSION(__) => func(exp.exp1) || func(exp.exp2)

      UNARY_EXPRESSION(__) => func(exp.exp)

      LBINARY_EXPRESSION(__) => func(exp.exp1) || func(exp.exp2)

      LUNARY_EXPRESSION(__) => func(exp.exp)

      RELATION_EXPRESSION(__) => func(exp.exp1) || func(exp.exp2)

      IF_EXPRESSION(__) => func(exp.condition) || func(exp.trueBranch) || func(exp.falseBranch)

      CAST_EXPRESSION(__) => func(exp.exp)

      UNBOX_EXPRESSION(__) => func(exp.exp)

      SUBSCRIPTED_EXP_EXPRESSION(__) => func(exp.exp) || listContainsExpShallow(exp.subscripts, func)

      TUPLE_ELEMENT_EXPRESSION(__) => func(exp.tupleExp)

      RECORD_ELEMENT_EXPRESSION(__) => func(exp.recordExp)

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__) => listContains(exp.args, func)

      BOX_EXPRESSION(__) => func(exp.exp)
      _ => false
    end
  end
  res
end

function callContains(call::Call, func::FT)::Bool where {FT<:Function}
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
            return true
          end
        end
        for arg in call.named_args
           (_, e, _, _) = arg
          if contains(e, func)
            return true
          end
        end
        false
      end

      TYPED_CALL(__) => vectorContains(call.arguments, func)

      UNTYPED_ARRAY_CONSTRUCTOR(__) => contains(call.exp, func)

      TYPED_ARRAY_CONSTRUCTOR(__) => contains(call.exp, func)

      UNTYPED_REDUCTION(__) => contains(call.exp, func)

      TYPED_REDUCTION(__) => contains(call.exp, func)
    end
  end
  res
end

function listContains(expl::List{<:Expression}, func::FT)::Bool where {FT<:Function}
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

function vectorContains(expl::Vector{Expression}, func::FT)::Bool where {FT<:Function}
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

function crefContains(cref::ComponentRef, func::FT)::Bool where {FT<:Function}

   @match cref begin
     COMPONENT_REF_CREF(__) => listContainsExp(cref.subscripts, func) || crefContains(cref.restCref, func)

     _ => false
   end
end

"""Whether `func` holds for `exp` or one of its subexpressions (specialized on `func`)."""
@nospecializeinfer function contains(@nospecialize(exp::Expression), func::FT)::Bool where {FT<:Function}
  local res::Bool
  if func(exp)::Bool
     res = true
    return res
  end
   res = begin
    @match exp begin
      CREF_EXPRESSION(__) => crefContains(exp.cref, func)
      ARRAY_EXPRESSION(__) => vectorContains(exp.elements, func)
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
      RANGE_EXPRESSION(__) => contains(exp.start, func) || containsOpt(exp.step, func) || contains(exp.stop, func)
      TUPLE_EXPRESSION(__) => listContains(exp.elements, func)
      RECORD_EXPRESSION(__) => vectorContains(exp.elements, func)
      CALL_EXPRESSION(__) => callContains(exp.call, func)
      SIZE_EXPRESSION(__) => containsOpt(exp.dimIndex, func) || contains(exp.exp, func)
      BINARY_EXPRESSION(__) => contains(exp.exp1, func) || contains(exp.exp2, func)
      UNARY_EXPRESSION(__) => contains(exp.exp, func)
      LBINARY_EXPRESSION(__) => contains(exp.exp1, func) || contains(exp.exp2, func)
      LUNARY_EXPRESSION(__) => contains(exp.exp, func)
      RELATION_EXPRESSION(__) => contains(exp.exp1, func) || contains(exp.exp2, func)
      IF_EXPRESSION(__)  => begin
        contains(exp.condition, func) || contains(exp.trueBranch, func) || contains(exp.falseBranch, func)
      end
      CAST_EXPRESSION(__) => contains(exp.exp, func)
      UNBOX_EXPRESSION(__) => contains(exp.exp, func)
      SUBSCRIPTED_EXP_EXPRESSION(__) => contains(exp.exp, func) || listContainsExp(exp.subscripts, func)
      TUPLE_ELEMENT_EXPRESSION(__) => contains(exp.tupleExp, func)
      RECORD_ELEMENT_EXPRESSION(__) => contains(exp.recordExp, func)
      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__) => listContains(exp.args, func)
      BOX_EXPRESSION(__) => contains(exp.exp, func)
      _ => false
    end
  end
  res
end

function containsOpt(exp::Option{<:Expression}, func::FT)::Bool where {FT<:Function}
  local e::Expression
  @match exp begin
    SOME(e) => contains(e, func)
    _ => false
  end
end

function mapFoldCrefShallow(cref::ComponentRef, func::FT, arg::ArgT)::Tuple{ComponentRef, ArgT} where {FT<:Function, ArgT}
  local outCref::ComponentRef
  outCref = begin
    local subs::List{Subscript}
    local rest::ComponentRef
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF)  => begin
        (subs, arg) = ListUtil.map1Fold(cref.subscripts, mapFoldExpShallow, func, arg, Subscript, ArgT)
        (rest, arg) = mapFoldCrefShallow(cref.restCref, func, arg)
        COMPONENT_REF_CREF(cref.node, subs, cref.ty, cref.origin, rest)
      end
      _ => cref
    end
  end
  (outCref, arg)
end

function mapFoldCallIteratorsShallow(iters::List{Tuple{InstNode, Expression}}, func::FT,
                                     arg::ArgT)::Tuple{List{Tuple{InstNode, Expression}}, ArgT} where {FT<:Function, ArgT}
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

function mapFoldCallShallow(call::Call, func::FT, foldArg::ArgT)::Tuple{Call, ArgT} where {FT<:Function, ArgT}
  local outCall::Call
  outCall = begin
    local args::Vector{Expression}
    local nargs::Vector{NamedArg}
    local targs::Vector{TypedArg}
    local tnargs::Vector{TypedNamedArg}
    local s::String
    local e::Expression
    local t::ModelicaType
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

function mapFoldOptShallow(exp::Option{Expression}, func::FT, arg::ArgT)::Tuple{Option{Expression}, ArgT} where {FT<:Function, ArgT}

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

      _ => exp
    end
  end
  (outExp, arg)
end

function mapFoldClockShallow(@nospecialize(clockExp::Expression), func::FT, arg::ArgT)::Tuple{Expression, ArgT} where {FT<:Function, ArgT}

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

      _ => clockExp
    end
  end
  (outExp, arg)
end

"""
The children of `exp` mapped by `(child, arg) = func(child, arg)`, the fold argument threaded through; `exp` itself
when no child changed. Specialized on `func` (3 callers, all with a Bool argument: NFEvalConstants).
"""
@nospecializeinfer function mapFoldShallow(@nospecialize(exp::Expression), func::FT, arg::ArgT)::Tuple{Expression, ArgT} where {FT<:Function, ArgT}
  local outExp::Expression
  outExp = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local oe::Option{Expression}
    local cr::ComponentRef
    local expl::List{Expression}
    local call::Call
    local subs::List{Subscript}
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
         (expl, arg) = ListUtil.mapFold(exp.elements, func, arg, Expression, ArgT)
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
        reuseIfRefEqual(exp, exp.exp, e1, (@nospecialize(e::Expression),) -> UNARY_EXPRESSION(exp.operator, e))
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
        reuseIfRefEqual(exp, exp.exp, e1, (@nospecialize(e::Expression),) -> LUNARY_EXPRESSION(exp.operator, e))
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
        (subs, arg) = ListUtil.mapFold(exp.subscripts, (ss, foldArg) -> mapFoldExpShallow(ss, func, foldArg), arg, Subscript, ArgT)
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
        (expl, arg) = ListUtil.mapFold(exp.args, func, arg, Expression, ArgT)
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

      _ => exp
    end
  end
  (outExp, arg)
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

      SUBSCRIPT_WHOLE(__) => nothing
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
    _ => nothing
  end
end

@nospecializeinfer function applyCall(call::Call, func::ApplyFunc)::Nothing
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
    CLKCONST_EXPRESSION(REAL_CLOCK(e1)) => apply(e1, func)
    CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e1, e2))  => begin
      apply(e1, func)
      apply(e2, func)
    end
    CLKCONST_EXPRESSION(SOLVER_CLOCK(e1, e2))  => begin
      apply(e1, func)
      apply(e2, func)
    end
    CREF_EXPRESSION(__) => applyCref(exp.cref, func)
    ARRAY_EXPRESSION(__) => applyList(exp.elements, func)
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
    TUPLE_EXPRESSION(__) => applyList(exp.elements, func)
    RECORD_EXPRESSION(__) => applyList(exp.elements, func)
    CALL_EXPRESSION(__) => applyCall(exp.call, func)
    SIZE_EXPRESSION(dimIndex = SOME(e))  => begin
      apply(exp.exp, func)
      apply(e, func)
    end
    SIZE_EXPRESSION(__) => apply(exp.exp, func)
    BINARY_EXPRESSION(__)  => begin
      apply(exp.exp1, func)
      apply(exp.exp2, func)
    end
    UNARY_EXPRESSION(__) => apply(exp.exp, func)
    LBINARY_EXPRESSION(__)  => begin
      apply(exp.exp1, func)
      apply(exp.exp2, func)
    end
    LUNARY_EXPRESSION(__) => apply(exp.exp, func)
    RELATION_EXPRESSION(__)  => begin
      apply(exp.exp1, func)
      apply(exp.exp2, func)
    end
    IF_EXPRESSION(__)  => begin
      apply(exp.condition, func)
      apply(exp.trueBranch, func)
      apply(exp.falseBranch, func)
    end
    CAST_EXPRESSION(__) => apply(exp.exp, func)
    UNBOX_EXPRESSION(__) => apply(exp.exp, func)
    SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
      apply(exp.exp, func)
      for s in exp.subscripts
        applyExp(s, func)
      end
    end
    TUPLE_ELEMENT_EXPRESSION(__) => apply(exp.tupleExp, func)
    RECORD_ELEMENT_EXPRESSION(__) => apply(exp.recordExp, func)
    BOX_EXPRESSION(__) => apply(exp.exp, func)
    MUTABLE_EXPRESSION(__) => apply(P_Pointer.access(exp.exp), func)
    PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__) => applyList(exp.args, func)
    BINDING_EXP(__) => apply(exp.exp, func)
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

"""
Folds `func` over the subscript expressions of `cref`, from the last part to the first, while the parts are crefs
(origin CREF); an iterator or scope part ends the fold.
"""
function foldCref(cref::ComponentRef, func::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}
  local acc::ArgT = arg
  local cr::ComponentRef = cref
  local subs::List{Subscript}
  while isvariant(cr, COMPONENT_REF_CREF) && cr.origin == Origin.CREF
    subs = cr.subscripts
    while subs isa Cons
      acc = foldExp(subs.head, func, acc, ArgT)
      subs = subs.tail
    end
    cr = cr.restCref
  end
  return acc
end

function foldCall(call::Call, func::FT, foldArg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}
  local e::Expression
  @match call begin
    UNTYPED_CALL(__)  => begin
      foldArg = foldList(call.arguments, func, foldArg, ArgT)
      for arg in call.named_args
        (_, e) = arg
        foldArg = fold(e, func, foldArg, ArgT)
      end
      ()
    end

    ARG_TYPED_CALL(__)  => begin
      for arg in call.arguments
         (e, _, _) = arg
         foldArg = fold(e, func, foldArg, ArgT)
      end
      for arg in call.named_args
         (_, e, _, _) = arg
         foldArg = fold(e, func, foldArg, ArgT)
      end
      ()
    end

    TYPED_CALL(__)  => begin
       foldArg = foldList(call.arguments, func, foldArg, ArgT)
      ()
    end

    UNTYPED_ARRAY_CONSTRUCTOR(__)  => begin
       foldArg = fold(call.exp, func, foldArg, ArgT)
      for i in call.iters
         foldArg = fold(last(i), func, foldArg, ArgT)
      end
      ()
    end

    TYPED_ARRAY_CONSTRUCTOR(__)  => begin
       foldArg = fold(call.exp, func, foldArg, ArgT)
      for i in call.iters
         foldArg = fold(last(i), func, foldArg, ArgT)
      end
      ()
    end

    UNTYPED_REDUCTION(__)  => begin
       foldArg = fold(call.exp, func, foldArg, ArgT)
      for i in call.iters
         foldArg = fold(last(i), func, foldArg, ArgT)
      end
      ()
    end

    TYPED_REDUCTION(__)  => begin
       foldArg = fold(call.exp, func, foldArg, ArgT)
      for i in call.iters
         foldArg = fold(last(i), func, foldArg, ArgT)
      end
       foldArg = foldOpt(call.defaultExp, func, foldArg, ArgT)
       foldArg = foldOpt(Util.tuple31(call.foldExp), func, foldArg, ArgT)
      ()
    end
  end
  foldArg
end

@nospecializeinfer function fold(@nospecialize(exp::Expression), func::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}
  local result::ArgT
  result = begin
    local e::Expression
    local e1::Expression
    local e2::Expression
    @match exp begin
      CREF_EXPRESSION(__) => foldCref(exp.cref, func, arg, ArgT)

      ARRAY_EXPRESSION(__) => foldList(exp.elements, func, arg, ArgT)

      MATRIX_EXPRESSION(__)  => begin
         result = arg
        for row in exp.elements
           result = foldList(row, func, result, ArgT)
        end
        result
      end

      RANGE_EXPRESSION(__)  => begin
         result = fold(exp.start, func, arg, ArgT)
         result = foldOpt(exp.step, func, result, ArgT)
        fold(exp.stop, func, result, ArgT)
      end

      TUPLE_EXPRESSION(__) => foldList(exp.elements, func, arg, ArgT)

      RECORD_EXPRESSION(__) => foldList(exp.elements, func, arg, ArgT)

      CALL_EXPRESSION(__) => foldCall(exp.call, func, arg, ArgT)

      SIZE_EXPRESSION(dimIndex = SOME(e))  => begin
         result = fold(exp.exp, func, arg, ArgT)
        fold(e, func, result, ArgT)
      end

      SIZE_EXPRESSION(__) => fold(exp.exp, func, arg, ArgT)

      BINARY_EXPRESSION(__)  => begin
         result = fold(exp.exp1, func, arg, ArgT)
        fold(exp.exp2, func, result, ArgT)
      end

      UNARY_EXPRESSION(__) => fold(exp.exp, func, arg, ArgT)

      LBINARY_EXPRESSION(__)  => begin
         result = fold(exp.exp1, func, arg, ArgT)
        fold(exp.exp2, func, result, ArgT)
      end

      LUNARY_EXPRESSION(__) => fold(exp.exp, func, arg, ArgT)

      RELATION_EXPRESSION(__)  => begin
         result = fold(exp.exp1, func, arg, ArgT)
        fold(exp.exp2, func, result, ArgT)
      end

      IF_EXPRESSION(__)  => begin
         result = fold(exp.condition, func, arg, ArgT)
         result = fold(exp.trueBranch, func, result, ArgT)
        fold(exp.falseBranch, func, result, ArgT)
      end

      CAST_EXPRESSION(__) => fold(exp.exp, func, arg, ArgT)

      UNBOX_EXPRESSION(__) => fold(exp.exp, func, arg, ArgT)

      SUBSCRIPTED_EXP_EXPRESSION(__)  => begin
        result = fold(exp.exp, func, arg, ArgT)
        for s in exp.subscripts
          result = foldExp(s, func, result, ArgT)
        end
        result
      end

      TUPLE_ELEMENT_EXPRESSION(__) => fold(exp.tupleExp, func, arg, ArgT)

      RECORD_ELEMENT_EXPRESSION(__) => fold(exp.recordExp, func, arg, ArgT)

      BOX_EXPRESSION(__) => fold(exp.exp, func, arg, ArgT)

      MUTABLE_EXPRESSION(__) => fold(P_Pointer.access(exp.exp), func, arg, ArgT)

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__) => foldList(exp.args, func, arg, ArgT)

      BINDING_EXP(__) => fold(exp.exp, func, arg, ArgT)

      #= Clocks last: rare, and their nested patterns cost a test for every expression before them. =#
      CLKCONST_EXPRESSION(INTEGER_CLOCK(e1, e2))  => begin
         result = fold(e1, func, arg, ArgT)
         result = fold(e2, func, result, ArgT)
        result
      end

      CLKCONST_EXPRESSION(REAL_CLOCK(e1))  => begin
         result = fold(e1, func, arg, ArgT)
        result
      end

      CLKCONST_EXPRESSION(BOOLEAN_CLOCK(e1, e2))  => begin
         result = fold(e1, func, arg, ArgT)
         result = fold(e2, func, result, ArgT)
        result
      end

      CLKCONST_EXPRESSION(SOLVER_CLOCK(e1, e2))  => begin
         result = fold(e1, func, arg, ArgT)
         result = fold(e2, func, result, ArgT)
        result
      end

      _ => arg
    end
  end
  result = func(exp, result)::ArgT
  return result
end

"""Folds `func` over the expression in `exp`, if any, and its subexpressions (as `fold`)."""
function foldOpt(exp::Option{Expression}, func::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}
  return exp === nothing ? arg : fold(something(exp), func, arg, ArgT)
end

"""Folds `func` over the expressions of `expl` in order (as `fold`)."""
function foldList(expl::Union{List{T}, Vector{T}}, func::FT, arg::ArgT, ::Type{ArgT})::ArgT where {T, FT<:Function, ArgT}
  local result::ArgT = arg
  for e in expl
    result = fold(e, func, result, ArgT)
  end
  return result
end

function mapArrayElements(exp::ARRAY_EXPRESSION, func::FT) where {FT<:Function}
  local expElements = Expression[mapArrayElements(e, func) for e in exp.elements]
  ARRAY_EXPRESSION(exp.ty, expElements, exp.literal)
end

"""  Applies the given function to each scalar elements of an array. """
function mapArrayElements(@nospecialize(exp::Expression), func::FT) where {FT<:Function}
  local outExp = func(exp)
  return outExp
end

@nospecializeinfer function mapCallShallowIterators(iters::List{<:Tuple{<:InstNode, Expression}}, func::FT) ::List{Tuple{InstNode, Expression}} where {FT<:Function}
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

@nospecializeinfer function mapCallShallow(call::Call, func::FT) where {FT<:Function}
  local outCall::Call
  outCall = begin
    local targs::Vector{TypedArg}
    local tnargs::Vector{TypedNamedArg}
    local e::Expression
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

function mapCrefShallow(cref::ComponentRef, func::FT) ::ComponentRef where {FT<:Function}

   local subs::List{Subscript}
   local rest::ComponentRef
   @match cref begin
     COMPONENT_REF_CREF(origin = Origin.CREF)  => begin
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

     _ => cref
   end
end

function mapShallowOpt(exp::Option{<:Expression}, func::FT) ::Option{Expression} where {FT<:Function}

  local e::Expression

   @match exp begin
     SOME(e) => SOME(func(e))

     _ => exp
   end
end

@nospecializeinfer function mapShallow(@nospecialize(exp::Expression), func::FT) where {FT<:Function}
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
        exp
      end

      ARRAY_EXPRESSION(__)  => begin
        local elems = exp.elements::Vector{Expression}
        for (i, e) in enumerate(elems)
          elems[i] = func(e)::Expression
        end
        exp
      end

      MATRIX_EXPRESSION(__) => MATRIX_EXPRESSION(mapMatrix(exp.elements, func))

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

      TUPLE_EXPRESSION(__) => TUPLE_EXPRESSION(exp.ty, ListUtil.map(exp.elements, func, Expression))

      RECORD_EXPRESSION(__)  => begin
        local newElements = mapPreservingEq(exp.elements, func)
        if newElements === exp.elements
          exp
        else
          RECORD_EXPRESSION(exp.path, exp.ty, newElements)
        end
      end

      CALL_EXPRESSION(__) => reuseIfRefEqual(exp, exp.call, mapCallShallow(exp.call, func), c -> CALL_EXPRESSION(c))

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
        SUBSCRIPTED_EXP_EXPRESSION(func(exp.exp), List{Subscript}(mapShallowExp(e, func) for e in exp.subscripts), exp.ty)
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
        newArgs = ListUtil.map(exp.args, func, Expression)
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
      _ => exp
    end
  end
  outExp
end

function mapCref(cref::ComponentRef, func::FT) ::ComponentRef where {FT<:Function}
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
    _ => cref
  end
end

function mapCallIterators(iters::List{<:Tuple{<:InstNode, Expression}}, func::FT) ::List{Tuple{InstNode, Expression}} where {FT<:Function}
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

@nospecializeinfer function mapCall(call::Call, func::FT) ::Call where {FT<:Function}
  local targs::Vector{TypedArg}
  local tnargs::Vector{TypedNamedArg}
  local s::String
  local e::Expression
  local t::ModelicaType
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
      targs = TypedArg[]
      tnargs = TypedNamedArg[]
      for arg in call.arguments
         (e, t, v) = arg
        e = map(e, func)
        push!(targs, (e, t, v))
      end
      for arg in call.named_args
         (s, e, t, v) = arg
        e = map(e, func)
        push!(tnargs, (s, e, t, v))
      end
      ARG_TYPED_CALL(call.ref, targs, tnargs, call.call_scope)
    end

    TYPED_CALL(__)  => begin
      local newArgs = mapPreservingEq(call.arguments, (@nospecialize(e::Expression),) -> map(e, func))
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

function mapOpt(exp::Option{<:Expression}, func::FT) ::Option{Expression} where {FT<:Function}

  local e::Expression

   @match exp begin
     SOME(e) => SOME(map(e, func))

     _ => exp
   end
end

"""
```
map(exp::Expression, func::FT) where {FT<:Function}
```
Applies the function `func`, to the expression `exp`.
This function traverse the expression and creates new nodes when needed.

The function passed to this function is expected to take an expression as the argument and return
one expression.
"""
@nospecializeinfer function map(@nospecialize(exp::Expression), func::FT) where {FT<:Function}
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
      CREF_EXPRESSION(__) => reuseIfRefEqual(exp, exp.cref, mapCref(exp.cref, func), c -> CREF_EXPRESSION(exp.ty, c))

      ARRAY_EXPRESSION(__)  => begin
        local newElements = mapPreservingEq(exp.elements, (@nospecialize(e::Expression),) -> map(e, func))
        if newElements === exp.elements
          exp
        else
          ARRAY_EXPRESSION(exp.ty, newElements, exp.literal)
        end
      end

      MATRIX_EXPRESSION(__)  => begin
        MATRIX_EXPRESSION(mapMatrix(exp.elements, (@nospecialize(e::Expression),) -> map(e, func)))
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
        TUPLE_EXPRESSION(exp.ty, ListUtil.map(exp.elements, (@nospecialize(e::Expression),) -> map(e, func), Expression))
      end

      RECORD_EXPRESSION(__)  => begin
        local newElements = mapPreservingEq(exp.elements, (@nospecialize(e::Expression),) -> map(e, func))
        if newElements === exp.elements
          exp
        else
          RECORD_EXPRESSION(exp.path, exp.ty, newElements)
        end
      end

      CALL_EXPRESSION(__) => reuseIfRefEqual(exp, exp.call, mapCall(exp.call, func), c -> CALL_EXPRESSION(c))

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
        SUBSCRIPTED_EXP_EXPRESSION(map(exp.exp, func), List{Subscript}(mapExp(s, func) for s in exp.subscripts), exp.ty)
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
        expArgs = ListUtil.map(exp.args, (@nospecialize(e::Expression),) -> map(e, func), Expression)
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
      _ => exp
    end
   end
  outExp = func(outExp)
  outExp
end

@nospecializeinfer function dimensionCount(@nospecialize(exp::Expression))
  local dimCount::Int
   dimCount = begin
    @match exp begin
      ARRAY_EXPRESSION(ty = TYPE_UNKNOWN(__)) => 1 + dimensionCount(exp.elements[1])

      ARRAY_EXPRESSION(__) => dimensionCount(exp.ty)

      RANGE_EXPRESSION(__) => dimensionCount(exp.ty)

      SIZE_EXPRESSION(dimIndex = NONE()) => dimensionCount(exp.exp)

      CAST_EXPRESSION(__) => dimensionCount(exp.exp)

      SUBSCRIPTED_EXP_EXPRESSION(__) => dimensionCount(exp.ty)

      TUPLE_ELEMENT_EXPRESSION(__) => dimensionCount(exp.ty)

      _ => 0
    end
  end
  #= TODO: Add more expressions. =#
  dimCount
end

function isNonAssociativeExp(@nospecialize(exp::Expression)) ::Bool

   @match exp begin
     BINARY_EXPRESSION(__) => isNonAssociative(exp.operator)

     LBINARY_EXPRESSION(__) => true

     _ => false
   end
end

function isAssociativeExp(@nospecialize(exp::Expression)) ::Bool
  @match exp begin
    BINARY_EXPRESSION(__) => isAssociative(exp.operator)
    LBINARY_EXPRESSION(__) => true
    _ => false
  end
end

function priority(@nospecialize(exp::Expression), lhs::Bool) ::Int

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

    BINARY_EXPRESSION(__) => priority(exp.operator, lhs)

    UNARY_EXPRESSION(__) => 4

    LBINARY_EXPRESSION(__) => priority(exp.operator, lhs)

    LUNARY_EXPRESSION(__) => 7

    RELATION_EXPRESSION(__) => 6

    RANGE_EXPRESSION(__) => 10

    IF_EXPRESSION(__) => 11

    _ => 0
  end
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
  local exp_ty::ModelicaType
  local sub_tyl::List{ModelicaType}
  local dims::List{Dimension}
  local strl::List{String}
  local name::String
  exp_ty = typeOf(exp)
  dims = ListUtil.firstN(arrayDims(exp_ty), listLength(subs), Dimension)
  sub_tyl = list(subscriptType(d) for d in dims)
  name = subscriptedTypeName(exp_ty, sub_tyl)
  strl = list(")")
  #= Consed from the last subscript, so that they read in order: exp, s1, s2, ... =#
  for s in listReverse(subs)
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
  local t::ModelicaType
  local clk::ClockKind
  str = begin
    @match exp begin
      INTEGER_EXPRESSION(__) => intString(exp.value)

      REAL_EXPRESSION(__) => realString(exp.value)

      STRING_EXPRESSION(__) => "\"" + _stringOf(exp) + "\""

      BOOLEAN_EXPRESSION(__) => boolString(exp.value)

      ENUM_LITERAL_EXPRESSION(ty = t && TYPE_ENUMERATION(__))  => begin
        "'" + AbsynUtil.pathString(t.typePath) + "'." + (exp::ENUM_LITERAL_EXPRESSION).name
      end

      CLKCONST_EXPRESSION(clk) => toFlatString(clk)

      CREF_EXPRESSION(__)  => toFlatString(exp.cref; inFunction = inFunction)

      TYPENAME_EXPRESSION(__) => typenameString(arrayElementType(exp.ty))

      ARRAY_EXPRESSION(__)  => begin
        if !isempty(exp.elements)
          ArrayUtil.toString(exp.elements, (@nospecialize(e::Expression),) -> toFlatString(e; inFunction = inFunction), "", "{", ", ", "}", true)
        else
          "{/* Empty array expression*/}"
        end
      end

      MATRIX_EXPRESSION(__)  => begin
        if !isempty(exp.elements)
          string("[", _matrixString(exp.elements, (@nospecialize(e::Expression),) -> toFlatString(e; inFunction = inFunction)), "]")
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
        "(" + stringDelimitList(ListUtil.map(exp.elements, (@nospecialize(e::Expression),) -> toFlatString(e; inFunction = inFunction), String), ", ") + ")"
      end

      RECORD_EXPRESSION(__)  => begin
        #= Use scopePath from the type's class node to get a consistent short path,
           avoiding the root model prefix that may appear in exp.path due to
           instFunctionRef caching order (toPath includes root, scopePath does not). =#
        local recordPath = if isvariant(exp.ty, TYPE_COMPLEX) && isvariant(exp.ty.cls, CLASS_NODE)
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
                   ", " + toFlatString(Util.getOption(exp.dimIndex); inFunction = inFunction)::String
                 else
                   ""
                 end), ")")
      end

      END_EXPRESSION(__) => "end"

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
        "if " + toFlatString(exp.condition; inFunction = inFunction)::String + " then " + toFlatString(exp.trueBranch; inFunction = inFunction)::String + " else " + toFlatString(exp.falseBranch; inFunction = inFunction)::String
      end

      UNBOX_EXPRESSION(__)  => begin
        "UNBOX_EXPRESSION(" + toFlatString(exp.exp; inFunction = inFunction)::String + ")"
      end

      BOX_EXPRESSION(__)  => begin
        "BOX_EXPRESSION(" + toFlatString(exp.exp; inFunction = inFunction)::String + ")"
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
          toFlatString(exp.tupleExp; inFunction = inFunction)::String + "[" + intString(exp.index)::String + "]"
        end
      end

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        toFlatString(exp.recordExp; inFunction = inFunction)::String + "[field: " + (exp::RECORD_ELEMENT_EXPRESSION).fieldName + "]"
      end

      MUTABLE_EXPRESSION(__)  => begin
        toFlatString(P_Pointer.access(exp.exp); inFunction = inFunction)
      end

      EMPTY_EXPRESSION(__) => "#EMPTY#"

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        "function " + toFlatString(exp.fn; inFunction = inFunction)::String + "(" + stringDelimitList(list(@do_threaded_for (n::String) + " = " + toFlatString(a; inFunction = inFunction)::String (a, n) (exp.args, exp.argNames)), ", ") + ")"
      end
      _ => anyString(exp)
    end
  end
  str
end

"""The rows of a matrix expression as a string: `str` of each element, elements joined by ", ", rows by "; "."""
function _matrixString(rows::Vector{Vector{Expression}}, str::F)::String where {F<:Function}
  local io::IOBuffer = IOBuffer()
  for i in eachindex(rows)
    i > 1 && print(io, "; ")
    local row::Vector{Expression} = rows[i]
    for j in eachindex(row)
      j > 1 && print(io, ", ")
      print(io, str(row[j])::String)
    end
  end
  return String(take!(io))
end

@nospecializeinfer function toString(@nospecialize(exp::Expression))
  local str::String
  local t::ModelicaType
  local clk::ClockKind
  str = begin
    @match exp begin
      INTEGER_EXPRESSION(__) => intString(exp.value)

      REAL_EXPRESSION(__) => realString(exp.value)

      STRING_EXPRESSION(__) => "\"" + _stringOf(exp) + "\""

      BOOLEAN_EXPRESSION(__) => boolString(exp.value)

      ENUM_LITERAL_EXPRESSION(ty = t && TYPE_ENUMERATION(__))  => begin
        AbsynUtil.pathString(t.typePath) + "." + (exp::ENUM_LITERAL_EXPRESSION).name
      end

      CLKCONST_EXPRESSION(clk) => toString(clk)

      CREF_EXPRESSION(__) => toString(exp.cref)

      TYPENAME_EXPRESSION(__) => typenameString(arrayElementType(exp.ty))

      ARRAY_EXPRESSION(__)  => begin
        if !isempty(exp.elements)
          ArrayUtil.toString(exp.elements, toString, "", "{", ", ", "}", true)
        else
          "{/*Empty Array Expression*/}"
        end
      end

      MATRIX_EXPRESSION(__)  => begin
        if !isempty(exp.elements)
          "[" + _matrixString(exp.elements, toString) + "]"
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

      TUPLE_EXPRESSION(__) => "(" + stringDelimitList(ListUtil.map(exp.elements, toString, String), ", ") + ")"

      RECORD_EXPRESSION(__)  => begin
        ArrayUtil.toString(exp.elements, toString, AbsynUtil.pathString(exp.path), "(", ", ", ")", true)
      end

      CALL_EXPRESSION(__) => toString(exp.call)

      SIZE_EXPRESSION(__)  => begin
        "size(" + toString(exp.exp)::String + (if isSome(exp.dimIndex)
                                       ", " + toString(Util.getOption(exp.dimIndex))::String
                                       else
                                       ""
                                       end) + ")"
      end

      END_EXPRESSION(__) => "end"

      BINARY_EXPRESSION(__)  => begin
        operandString(exp.exp1, exp, true) + symbol(exp.operator) + operandString(exp.exp2, exp, false)
      end

      UNARY_EXPRESSION(__) => symbol(exp.operator, "") + operandString(exp.exp, exp, false)

      LBINARY_EXPRESSION(__)  => begin
        operandString(exp.exp1, exp, true) + symbol(exp.operator) + operandString(exp.exp2, exp, false)
      end

      LUNARY_EXPRESSION(__) => symbol(exp.operator, "") + " " + operandString(exp.exp, exp, false)

      RELATION_EXPRESSION(__)  => begin
        operandString(exp.exp1, exp, true) + symbol(exp.operator) + operandString(exp.exp2, exp, false)
      end

      IF_EXPRESSION(__)  => begin
        "if " + toString(exp.condition)::String + " then " + toString(exp.trueBranch)::String + " else " + toString(exp.falseBranch)::String
      end

      UNBOX_EXPRESSION(__) => "UNBOX_EXPRESSION(" + toString(exp.exp)::String + ")"

      BOX_EXPRESSION(__) => "BOX_EXPRESSION(" + toString(exp.exp)::String + ")"

      #if Flags.isSet(Flags.NF_API) Changes by me, John
      #        else
      #          "CAST_EXPRESSION(" + toString(exp.ty) + ", " + toString(exp.exp) + ")"
      #       end
      CAST_EXPRESSION(__) => toString(exp.exp)

      SUBSCRIPTED_EXP_EXPRESSION(__) => toString(exp.exp)::String + toStringList(exp.subscripts)::String

      TUPLE_ELEMENT_EXPRESSION(__) => toString(exp.tupleExp)::String + "[" + intString(exp.index)::String + "]"

      RECORD_ELEMENT_EXPRESSION(__)  => begin
        toString(exp.recordExp)::String + "[field: " + (exp::RECORD_ELEMENT_EXPRESSION).fieldName + "]"
      end

      MUTABLE_EXPRESSION(__) => toString(P_Pointer.access(exp.exp))

      EMPTY_EXPRESSION(__) => "#EMPTY#"

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
        local argStrs = nil
        local restArgs = exp.args
        local restNames = exp.argNames
        while !listEmpty(restArgs)
          @match _cons(a, restArgs) = restArgs
          @match _cons(n, restNames) = restNames
          argStrs = _cons((n::String) + " = " + toString(a)::String, argStrs)
        end
        "function " + toString(exp.fn)::String + "(" + stringDelimitList(listReverseInPlace(argStrs), ", ") + ")"
      end

      BINDING_EXP(__) => toString(exp.exp)

      _ => anyString(exp)
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

   @match exp begin
     INTEGER_EXPRESSION(__) => exp.value

     #= An index, as omc: false is 1 and true is 2 (Boolean dimensions). =#
     BOOLEAN_EXPRESSION(__)  => begin
       if exp.value
         2
       else
         1
       end
     end

     ENUM_LITERAL_EXPRESSION(__) => exp.index
   end
end

function makeEnumLiterals(enumType::ModelicaType) ::List{Expression}
  local lits::List{String}
  @match TYPE_ENUMERATION(literals = lits) = enumType
  # A List{Expression}: a list of ENUM_LITERAL_EXPRESSION was converted (rebuilt) to it.
  local literals::Vector{Expression} = Expression[]
  local i::Int = 0
  for l in lits
    i += 1
    push!(literals, ENUM_LITERAL_EXPRESSION(enumType, l, i))
  end
  return arrayList(literals)
end

function makeEnumLiteral(enumType::ModelicaType, index::Int) ::Expression
  local literal::Expression

  local literals::List{String}

  @match TYPE_ENUMERATION(literals = literals) = enumType
   literal = ENUM_LITERAL_EXPRESSION(enumType, listGet(literals, index), index)
  literal
end

"""
The array expression with the dimensions `inDims` whose elements, in row-major order, are `inExps`.
"""
function arrayFromVector(inExps::Vector{Expression}, elemTy::ModelicaType, inDims::List{Dimension})::Expression
  return arrayFromVectorImpl(inExps, elemTy, listReverse(inDims))
end

function arrayFromVectorImpl(inExps::Vector{Expression},
                             elemTy::ModelicaType,
                             inDims::List{Dimension})::Expression
  local outExp::Expression
  local ldim::Dimension
  local restdims::List{Dimension}
  local ty::ModelicaType
  local newVec::Vector{Expression}
  local partexps::Vector{Vector{Expression}} #=A Vector of Vectors...=#
  local dimsize::Int
  Error.assertion(! listEmpty(inDims), "Empty dimension list given in arrayFromVector.", sourceInfo())
  @match Cons{Dimension}(ldim, restdims) = inDims
  dimsize = size(ldim)
  ty = liftArrayLeft(elemTy, ldim)
  if ListUtil.hasOneElement(inDims)
    Error.assertion(dimsize == length(inExps), "Length mismatch in arrayFromVector.", sourceInfo())
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
  local node::InstNode
  @match exp begin
    CREF_EXPRESSION(cref = COMPONENT_REF_CREF(node = node))  where {isvariant(exp.cref, COMPONENT_REF_CREF) && isSimple(exp.cref)} => begin
      if nameEqual(iterator, node)
        iteratorValue
      else
        exp
      end
    end
    CREF_EXPRESSION(__) => exp
    _ => exp
  end
end

function replaceIterator(@nospecialize(exp::Expression),
                         iterator::InstNode,
                         @nospecialize(iteratorValue::Expression))::Expression
  local value::Base.RefValue{Expression} = captureRef(iteratorValue)
  return map(exp, (@nospecialize(x::Expression),) -> replaceIterator2(x, iterator, value[]))
end

function makeSubscriptedExp(subscripts::List{<:Subscript}, @nospecialize(exp::Expression)) ::Expression
  local outExp::Expression

  local e::Expression
  local subs::List{Subscript}
  local extra_subs::List{Subscript}
  local ty::ModelicaType
  local dim_count::Int

  #= If the expression is already a SUBSCRIPTED_EXP_EXPRESSION we need to concatenate the
     old subscripts with the new. Otherwise we just create a new SUBSCRIPTED_EXP_EXPRESSION. =#
   (e, subs, ty) = begin
    @match exp begin
      SUBSCRIPTED_EXP_EXPRESSION(__) => (exp.exp, exp.subscripts, typeOf(exp.exp))

      _ => (exp, nil, typeOf(exp))
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

function applyIndexSubscriptArrayConstructor(call::Call, index::Subscript) ::Expression
  local subscriptedExp::Expression

  local ty::ModelicaType
  local var::VariabilityType
  local exp::Expression
  local iter_exp::Expression
  local iters::List{Tuple{InstNode, Expression}}
  local iter::InstNode

  @match TYPED_ARRAY_CONSTRUCTOR(ty, var, exp, iters) = call
   ((iter, iter_exp), iters) = ListUtil.splitLast(iters, Tuple{InstNode, Expression})
   iter_exp = applySubscript(index, iter_exp)
   subscriptedExp = replaceIterator(exp, iter, iter_exp)
  if ! listEmpty(iters)
     subscriptedExp = CALL_EXPRESSION(TYPED_ARRAY_CONSTRUCTOR(unliftArray(ty), var, subscriptedExp, iters))
  end
  subscriptedExp
end

function applySubscriptArrayConstructor(subscript::Subscript, call::Call, restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression

  if isIndex(subscript) && listEmpty(restSubscripts)
     outExp = applyIndexSubscriptArrayConstructor(call, subscript)
  else
     outExp = makeSubscriptedExp(Cons{Subscript}(subscript, restSubscripts), CALL_EXPRESSION(call))
  end
  #= TODO: Handle slicing and multiple subscripts better. =#
  outExp
end

function applySubscriptCall(subscript::Subscript, @nospecialize(exp::Expression), restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression
  local call::Call
  @match CALL_EXPRESSION(call = call) = exp
  outExp = begin
    local arg::Expression
    local ty::ModelicaType
    @match call begin
      TYPED_CALL(__) where (length(call.arguments) == 1 && isSubscriptableBuiltin(call.fn))  => begin
        arg = applySubscript(subscript, call.arguments[1], restSubscripts)
        ty = copyDims(typeOf(arg), call.ty)
        CALL_EXPRESSION(TYPED_CALL(call.fn, ty, call.var, Expression[arg], call.attributes))
      end

      TYPED_ARRAY_CONSTRUCTOR(__) => applySubscriptArrayConstructor(subscript, call, restSubscripts)

      _ => makeSubscriptedExp(Cons{Subscript}(subscript, restSubscripts), exp)
    end
  end
  outExp
end

function applyIndexSubscriptRange2(@nospecialize(startExp::Expression), stepExp::Option{<:Expression}, @nospecialize(stopExp::Expression), index::Int) ::Expression

  local iidx::Int
  local ridx::AbstractFloat

   @match (startExp, stepExp) begin
     (INTEGER_EXPRESSION(__), SOME(INTEGER_EXPRESSION(iidx))) => INTEGER_EXPRESSION(startExp.value + (index - 1) * iidx)

     (INTEGER_EXPRESSION(__), _) => INTEGER_EXPRESSION(startExp.value + index - 1)

     (REAL_EXPRESSION(__), SOME(REAL_EXPRESSION(ridx))) => REAL_EXPRESSION(startExp.value + (index - 1) * ridx)

     (REAL_EXPRESSION(__), _) => REAL_EXPRESSION(startExp.value + index - 1.0)

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

function applyIndexSubscriptRange(@nospecialize(rangeExp::Expression), index::Subscript) ::Expression
  local outExp::Expression

  local index_exp::Expression
  local start_exp::Expression
  local stop_exp::Expression
  local step_exp::Option{Expression}
  local ty::ModelicaType

  @match SUBSCRIPT_INDEX(index = index_exp) = index
  if isScalarLiteral(index_exp)
    @match RANGE_EXPRESSION(start = start_exp, step = step_exp, stop = stop_exp) = rangeExp
     outExp = applyIndexSubscriptRange2(start_exp, step_exp, stop_exp, toInteger(index_exp))
  elseif isNone(rangeExp.step) && rangeExp.start isa INTEGER_EXPRESSION && rangeExp.start.value == 1
    #= (1:n)[i] is i (an iterator of a vectorized component array as the index) =#
    outExp = index_exp
  else
    @match RANGE_EXPRESSION(ty = ty) = rangeExp
    local subs::List{Subscript} = Cons{Subscript}(index, nil)
    ty = subscript(ty, subs)
    outExp = SUBSCRIPTED_EXP_EXPRESSION(rangeExp, subs, ty)
  end
  outExp
end

function applySubscriptRange(subscript::Subscript, @nospecialize(exp::Expression)) ::Expression
  local outExp::Expression
  local sub::Subscript
  local ty::ModelicaType
  local expl::Vector{Expression}
  (sub, _) = expandSlice(subscript)
  outExp = begin
    @match sub begin
      SUBSCRIPT_INDEX(__) => applyIndexSubscriptRange(exp, sub)
      SUBSCRIPT_SLICE(__)  => begin
        @match RANGE_EXPRESSION(ty = ty) = exp
        ty = TYPE_ARRAY(unliftArray(ty), list(toDimension(sub)))
        SUBSCRIPTED_EXP_EXPRESSION(exp, Cons{Subscript}(subscript, nil), ty)
      end
      SUBSCRIPT_WHOLE(__) => exp
      SUBSCRIPT_EXPANDED_SLICE(__)  => begin
        expl = Expression[applyIndexSubscriptRange(exp, i) for i in sub.indices]
        @match RANGE_EXPRESSION(ty = ty) = exp
        makeArray(liftArrayLeft(ty, fromInteger(length(expl))), expl)
      end
      SUBSCRIPT_SPLIT_INDEX(__) => begin
        @match RANGE_EXPRESSION(ty) = exp
        ty = unliftArray(ty)
        SUBSCRIPTED_EXP_EXPRESSION(exp, Cons{Subscript}(sub, nil), ty)
      end
    end
  end
  outExp
end

function applyIndexExpArray(@nospecialize(exp::Expression), @nospecialize(index::Expression), restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression
  local expl::Vector{Expression}
  #= An index out of bounds is left as a subscripted expression: someone else's problem, and
     maybe fine (a branch not taken; omc applyIndexExpArray). =#
  if isScalarLiteral(index) && !(exp isa ARRAY_EXPRESSION && !(1 <= toInteger(index) <= length(exp.elements)))
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
  local ty::ModelicaType
  local el_count::Int
  local literal::Bool

  (sub, _) = expandSlice(inSubscript)
   outExp = begin
    @match sub begin
      SUBSCRIPT_INDEX(__) => applyIndexSubscriptArray(exp, sub, restSubscripts)

      SUBSCRIPT_SLICE(__) => makeSubscriptedExp(Cons{Subscript}(inSubscript, restSubscripts), exp)

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

function applyIndexSubscriptTypename(ty::ModelicaType, index::Subscript) ::Expression
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

        TYPE_ENUMERATION(__) => nthEnumLiteral(ty, idx)
      end
    end
  else
    subscriptedExp = SUBSCRIPTED_EXP_EXPRESSION(TYPENAME_EXPRESSION(ty), Cons{Subscript}(index, nil), ty)
  end
  subscriptedExp
end

function applySubscriptTypename(subscript::Subscript, ty::ModelicaType) ::Expression
  local outExp::Expression
  local sub::Subscript
  local expl::Vector{Expression}
  (sub, _) = expandSlice(subscript)
  outExp = begin
    @match sub begin
      SUBSCRIPT_INDEX(__) => applyIndexSubscriptTypename(ty, sub)

      SUBSCRIPT_SLICE(__)  => begin
        SUBSCRIPTED_EXP_EXPRESSION(TYPENAME_EXPRESSION(ty), Cons{Subscript}(subscript, nil), TYPE_ARRAY(ty, list(toDimension(sub))))
      end

      SUBSCRIPT_WHOLE(__) => TYPENAME_EXPRESSION(ty)

      SUBSCRIPT_EXPANDED_SLICE(__)  => begin
        expl = Expression[applyIndexSubscriptTypename(ty, i) for i in sub.indices]
        makeArray(liftArrayLeft(ty, fromInteger(length(expl))), expl, literal = true)
      end
    end
  end
  outExp
end

function applySubscriptCref(subscript::Subscript, cref::ComponentRef, restSubscripts::List{<:Subscript}) ::Expression
  local outExp::Expression
  local cr::ComponentRef
  local ty::ModelicaType
  cr = applySubscripts(Cons{Subscript}(subscript, restSubscripts), cref)
  ty = getSubscriptedType(cr)
  outExp = CREF_EXPRESSION(ty, cr)
  outExp
end

"""
 Subscripts an expression with the given subscript, and then applies the
 optional list of subscripts to each element of the subscripted expression.
"""
function applySubscript(@nospecialize(subscript::Subscript), @nospecialize(exp::Expression), @nospecialize(restSubscripts::List{<:Subscript} = nil)) ::Expression
  @match exp begin
    CREF_EXPRESSION(__) => applySubscriptCref(subscript, exp.cref, restSubscripts)
    TYPENAME_EXPRESSION(__) where (listEmpty(restSubscripts)) => applySubscriptTypename(subscript, exp.ty)
    ARRAY_EXPRESSION(__) => applySubscriptArray(subscript, exp, restSubscripts)
    RANGE_EXPRESSION(__) where (listEmpty(restSubscripts)) => applySubscriptRange(subscript, exp)
    CALL_EXPRESSION(call = TYPED_ARRAY_CONSTRUCTOR(__))  => begin
      applySubscriptArrayConstructor(subscript, exp.call, restSubscripts)
    end
    CALL_EXPRESSION(__) => applySubscriptCall(subscript, exp, restSubscripts)
    IF_EXPRESSION(__) => applySubscriptIf(subscript, exp, restSubscripts)
    BINDING_EXP(__) => bindingExpMap(exp, (expArg) -> applySubscript(subscript, expArg, restSubscripts))
    _ => makeSubscriptedExp(Cons{Subscript}(subscript, restSubscripts), exp)
  end
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
makeRecord(recordName::Absyn.Path, recordType::ModelicaType, fields::Vector{Expression})
```
  Creates a record expression.
"""
function makeRecord(recordName::Absyn.Path, recordType::ModelicaType, fields::Vector{Expression})
  local exp::Expression
  exp = RECORD_EXPRESSION(recordName, recordType, fields)
  exp
end

function makeRange(@nospecialize(start::Expression), step::Option{T}, @nospecialize(stop::Expression)) where {T}
  local rangeTy = getRangeType(start, step, stop, typeOf(start), AbsynUtil.dummyInfo)
  return RANGE_EXPRESSION(rangeTy, start, step, stop)
end




function makeEmptyArray(ty::ModelicaType)
  local outExp::Expression
   outExp = ARRAY_EXPRESSION(ty, Expression[], true)
  outExp
end

"""
Generic make array function
"""
function makeArray(ty::ModelicaType, expl::List; literal::Bool = false)
  ARRAY_EXPRESSION(ty, listArray(expl), literal)
end

"""
Generic make array function for vectors
"""
function makeArray(ty::ModelicaType, expV::Vector{T}; literal::Bool = false) where {T}
  ARRAY_EXPRESSION(ty, expV, literal)
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

 """
   Converts an expression to the given type. Dimensions of array types can be
   omitted, and are ignored by this function, since arrays can't be cast to a
   different size. Only the element type of the type is used, so for example:
   typeCast({1, 2, 3}, TYPE_REAL()) => {1.0, 2.0, 3.0}

   The function does not check that the cast is valid, and expressions that
   can't be converted outright will be wrapped as a CAST expression.
 """
 function typeCast(@nospecialize(exp::Expression), ty::ModelicaType) ::Expression
   local t::ModelicaType
   local t2::ModelicaType
   local ety::ModelicaType
   local el::Vector{Expression}
    ety = arrayElementType(ty)
    exp = begin
     @match (exp, ety) begin
       (INTEGER_EXPRESSION(__), TYPE_REAL(__)) => REAL_EXPRESSION(intReal(exp.value))
       (BOOLEAN_EXPRESSION(__), TYPE_REAL(__)) where (Flags.isSet(Flags.NF_API))  => begin
         REAL_EXPRESSION(if exp.value
              1.0
              else
              0.0
              end)
       end
       (REAL_EXPRESSION(__), TYPE_REAL(__)) => exp
       #= --allowNonStandardModelica=nonStdEnumerationAsIntegers (omc). =#
       (ENUM_LITERAL_EXPRESSION(__), TYPE_INTEGER(__)) where {Flags.isConfigFlagSet(Flags.ALLOW_NON_STANDARD_MODELICA, "nonStdEnumerationAsIntegers")}  => begin
         INTEGER_EXPRESSION(exp.index)
       end
       (ARRAY_EXPRESSION(ty = t, elements = el), _)  => begin
         #= Integer can be cast to Real.
            Boolean can be cast to Real (only if -d=nfAPI is on)
            as there are annotations having expressions such as Boolean x > 0.5
            Real doesn't need to be cast to Real, since we convert e.g. array with
            a mix of Integers and Reals to only Reals.
            For arrays we typecast each element and update the type of the array. =#
         el = Expression[typeCast(e, ety) for e in el]
         t = setArrayElementType(t, ety)
         ARRAY_EXPRESSION(t, el, exp.literal)
       end
       (RANGE_EXPRESSION(ty = t), _)  => begin
         t = setArrayElementType(t, ety)
         RANGE_EXPRESSION(t, typeCast(exp.start, ety), typeCastOpt(exp.step, ety), typeCast(exp.stop, ety))
       end
       (UNARY_EXPRESSION(__), _)  => begin
         #= Unary operators (i.e. -) are handled by casting the operand. =#
         t = setArrayElementType(typeOf(exp.operator), ety)
         UNARY_EXPRESSION(setType(t, exp.operator), typeCast(exp.exp, ety))
       end
       (IF_EXPRESSION(__), _)  => begin
         IF_EXPRESSION(exp.condition, typeCast(exp.trueBranch, ety), typeCast(exp.falseBranch, ety))
       end
       (CALL_EXPRESSION(__), _) => typeCast(exp, ety)
       (CAST_EXPRESSION(__), _) => typeCast(exp.exp, ty)
       (BINDING_EXP(__), _)  => begin
         #= If-expressions are handled by casting each of the branches.
            Calls are handled by Call.typeCast, which has special rules for some functions.
            Casting a cast expression overrides its current cast type. =#
          t = setArrayElementType(exp.expType, ety)
          t2 = setArrayElementType(exp.bindingType, ety)
         BINDING_EXP(typeCast(exp.exp, ety), t, t2, exp.parents, exp.isEach)
       end
       _  => begin
         #= Other expressions are handled by making a CAST expression. =#
          t = typeOf(exp)
          t = setArrayElementType(t, ety)
         CAST_EXPRESSION(t, exp)
       end
     end
   end
   exp
 end

function typeCastOpt(exp::Option{<:Expression}, ty::ModelicaType) ::Option{Expression}
  local outExp::Option{Expression} = Util.applyOption(exp, (e) -> typeCast(e, ty))
  outExp
end

function setType(ty::ModelicaType, @nospecialize(exp::Expression))
  retExp = @match exp begin
    ENUM_LITERAL_EXPRESSION(__) => ENUM_LITERAL_EXPRESSION(ty, exp.name, exp.index)

    CREF_EXPRESSION(__) => CREF_EXPRESSION(ty, exp.cref)

    TYPENAME_EXPRESSION(__) => TYPENAME_EXPRESSION(ty)

    ARRAY_EXPRESSION(__) => ARRAY_EXPRESSION(ty, exp.elements, exp.literal)

    RANGE_EXPRESSION(__) => RANGE_EXPRESSION(ty, exp.start, exp.step, exp.stop)

    TUPLE_EXPRESSION(__) => TUPLE_EXPRESSION(exp.ty, exp.elements)

    RECORD_EXPRESSION(__)  => begin
      exp.ty = ty
    end

    CALL_EXPRESSION(__) => CALL_EXPRESSION(setType(exp.call, ty))

    BINARY_EXPRESSION(__) || UNARY_EXPRESSION(__) || LBINARY_EXPRESSION(__) ||
      RELATION_EXPRESSION(__) ||  LUNARY_EXPRESSION(__) => begin
        exp.operator = setType(ty, exp.operator)
        exp
      end

    CAST_EXPRESSION(__) => CAST_EXPRESSION(ty, exp.exp)

    UNBOX_EXPRESSION(__) => UNBOX_EXPRESSION(exp.exp, ty)

    SUBSCRIPTED_EXP_EXPRESSION(__) => SUBSCRIPTED_EXP_EXPRESSION(exp.exp, exp.subscripts, ty)

    TUPLE_ELEMENT_EXPRESSION(__) => TUPLE_ELEMENT_EXPRESSION(exp.tupleExp, exp.index, ty)

    RECORD_ELEMENT_EXPRESSION(__) => RECORD_ELEMENT_EXPRESSION(exp.recordExp, exp.index, exp.fieldName, ty)

    PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__)  => begin
      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(exp.fn,
                                              exp.args,
                                              exp.argNames,
                                              ty)
    end
    _ => exp
  end
  retExp
end

@nospecializeinfer function typeOf(@nospecialize(exp::Expression))
  local ty::ModelicaType
  ty = begin
    @match exp begin
      INTEGER_EXPRESSION(__) => TYPE_INTEGER()

      REAL_EXPRESSION(__) => TYPE_REAL()

      STRING_EXPRESSION(__) => TYPE_STRING()

      BOOLEAN_EXPRESSION(__) => TYPE_BOOLEAN()

      ENUM_LITERAL_EXPRESSION(__) => exp.ty

      CLKCONST_EXPRESSION(__) => TYPE_CLOCK()

      CREF_EXPRESSION(__) => exp.ty

      TYPENAME_EXPRESSION(__) => exp.ty

      ARRAY_EXPRESSION(__) => exp.ty

      RANGE_EXPRESSION(__) => exp.ty

      TUPLE_EXPRESSION(__) => exp.ty

      RECORD_EXPRESSION(__) => exp.ty

      CALL_EXPRESSION(__) => typeOf(exp.call)

      SIZE_EXPRESSION(__)  => begin
        if isSome(exp.dimIndex)
          TYPE_INTEGER()
        else
          sizeType(typeOf(exp.exp))
        end
      end

      END_EXPRESSION(__) => TYPE_INTEGER()

      BINARY_EXPRESSION(__) => typeOf(exp.operator)

      UNARY_EXPRESSION(__) => typeOf(exp.operator)

      LBINARY_EXPRESSION(__) => typeOf(exp.operator)

      LUNARY_EXPRESSION(__) => typeOf(exp.operator)

      #= Boolean, over the operands' dimensions (the operator's type is the operands'; omc). =#
      RELATION_EXPRESSION(__) => copyDims(typeOf(exp.operator), TYPE_BOOLEAN())

      IF_EXPRESSION(__) => typeOf(exp.trueBranch)

      CAST_EXPRESSION(__) => exp.ty

      UNBOX_EXPRESSION(__) => exp.ty

      SUBSCRIPTED_EXP_EXPRESSION(__) => exp.ty

      TUPLE_ELEMENT_EXPRESSION(__) => exp.ty

      RECORD_ELEMENT_EXPRESSION(__) => exp.ty

      BOX_EXPRESSION(__) => TYPE_METABOXED(typeOf(exp.exp))

      MUTABLE_EXPRESSION(__) => typeOf(P_Pointer.access(exp.exp))

      EMPTY_EXPRESSION(__) => exp.ty

      PARTIAL_FUNCTION_APPLICATION_EXPRESSION(__) => exp.ty

      BINDING_EXP(__) => exp.bindingType

      _ => TYPE_UNKNOWN()
    end
  end
  ty
end

function compareList(expl1::List{<:Expression}, expl2::List{<:Expression}) ::Int
  local comp::Int

  local e2::Expression
  local rest_expl2::List{Expression} = expl2

  #= Check that the lists have the same length, otherwise they can't be equal. =#
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
  #= Return if the expressions are not equal. =#
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

  local e1::Expression
  local e2::Expression

   @match (expl1, expl2) begin
     (NONE(), NONE()) => 0

     (NONE(), _) => -1

     (_, NONE()) => 1

     (SOME(e1), SOME(e2)) => compare(e1, e2)
   end
end

""" #= Checks whether two expressions are equal, and returns 0 if they are.
               If the first expression is 'less' than the second it returns an integer
               less than 0, otherwise an integer greater than 0. =#"""
@nospecializeinfer function compare(@nospecialize(exp1::Expression), @nospecialize(exp2::Expression)) ::Int
  local comp::Int

  #= Check if the expressions are the same object. =#
  if referenceEq(exp1, exp2)
    return 0
  end
  #= Return false if the expressions are of different kinds. =#
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
    local ty::ModelicaType
    local expl
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local oe::Option{Expression}
    local p::Path
    local op::OPERATOR
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

      END_EXPRESSION(__) => 0

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
            CAST_EXPRESSION(exp = e1) => e1

            e1 => e1
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

   @match exp begin
     BOOLEAN_EXPRESSION(false) => true

     _ => false
   end
end

function isTrue(@nospecialize(exp::Expression))
    @match exp begin
      BOOLEAN_EXPRESSION(true) => true
      _ => false
    end
end

function isCall(@nospecialize(exp::Expression))
  @match exp begin
    CALL_EXPRESSION(__) => true
    _ => false
  end
end

function isWildCref(@nospecialize(exp::Expression))
  local wild::Bool

   wild = begin
    @match exp begin
      CREF_EXPRESSION(cref = COMPONENT_REF_WILD(__)) => true

      _ => false
    end
  end
  wild
end

isCref(@nospecialize(exp::Expression)) ::Bool = isvariant(exp, CREF_EXPRESSION)

function isEmptyArray(@nospecialize(exp::Expression)) ::Bool
   @match exp begin
     ARRAY_EXPRESSION(__) => isempty(exp.elements)
     _ => false
   end
end

isArray(@nospecialize(exp::Expression)) ::Bool = isvariant(exp, ARRAY_EXPRESSION)

@UniontypeDecl ClockKind

function toString(ck::ClockKind) ::String
  local str::String

   str = begin
    local e1::Expression
    local e2::Expression
    @match ck begin
      INFERRED_CLOCK(__) => ""

      INTEGER_CLOCK(e1, e2) => toString(e1) + ", " + toString(e2)

      REAL_CLOCK(e1) => toString(e1)

      BOOLEAN_CLOCK(e1, e2) => toString(e1) + ", " + toString(e2)

      SOLVER_CLOCK(e1, e2) => toString(e1) + ", " + toString(e2)
    end
  end
   str = "Clock(" + str + ")"
  str
end

"""
    toFlatString(ck::ClockKind) -> String

A clock as flat Modelica, `Clock(...)` with its expressions as flat Modelica (omc
ClockKind.toFlatString): the flat model of a model with a Clock had no method for it.
"""
function toFlatString(ck::ClockKind)::String
  local args = @match ck begin
    INFERRED_CLOCK(__) => ""
    INTEGER_CLOCK(e1, e2) => toFlatString(e1) + ", " + toFlatString(e2)
    REAL_CLOCK(e1) => toFlatString(e1)
    BOOLEAN_CLOCK(e1, e2) => toFlatString(e1) + ", " + toFlatString(e2)
    SOLVER_CLOCK(e1, e2) => toFlatString(e1) + ", " + toFlatString(e2)
  end
  return "Clock(" + args + ")"
end

function toDebugString(ick::ClockKind) ::String

   local i::Expression
   local r::Expression
   local c::Expression
   local si::Expression
   local sm::Expression
   @match ick begin
     INFERRED_CLOCK(__) => "INFERRED_CLOCK()"

     INTEGER_CLOCK(i, r) => "INTEGER_CLOCK(" + toString(i) + ", " + toString(r) + ")"

     REAL_CLOCK(i) => "REAL_CLOCK(" + toString(i) + ")"

     BOOLEAN_CLOCK(c, si) => "BOOLEAN_CLOCK(" + toString(c) + ", " + toString(si) + ")"

     SOLVER_CLOCK(c, sm) => "SOLVER_CLOCK(" + toString(c) + ", " + toString(sm) + ")"
   end
end

function compare(ck1::ClockKind, ck2::ClockKind) ::Int
  local comp::Int

   comp = begin
    local i1::Expression
    local r1::Expression
    local c1::Expression
    local si1::Expression
    local sm1::Expression
    local i2::Expression
    local r2::Expression
    local c2::Expression
    local si2::Expression
    local sm2::Expression
    @match (ck1, ck2) begin
      (INFERRED_CLOCK(__), INFERRED_CLOCK(__)) => 0

      (INTEGER_CLOCK(i1, r1), INTEGER_CLOCK(i2, r2))  => begin
         comp = compare(i1, i2)
        if comp == 0
           comp = compare(r1, r2)
        end
        comp
      end

      (REAL_CLOCK(i1), REAL_CLOCK(i2)) => compare(i1, i2)

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

@nospecializeinfer function containsExp(binding::Binding, predFn::Function)
  local res::Bool

   res = begin
    @match binding begin
      UNTYPED_BINDING(__) => contains(binding.bindingExp, predFn)

      TYPED_BINDING(__) => contains(binding.bindingExp, predFn)

      FLAT_BINDING(__) => contains(binding.bindingExp, predFn)

      CEVAL_BINDING(__) => contains(binding.bindingExp, predFn)

      _ => false
    end
  end
  return res
end

function foldExp(binding::Binding, foldFn::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}
  arg = begin
    @match binding begin
      UNTYPED_BINDING(__) => fold(binding.bindingExp, foldFn, arg, ArgT)

      TYPED_BINDING(__) => fold(binding.bindingExp, foldFn, arg, ArgT)

      FLAT_BINDING(__) => fold(binding.bindingExp, foldFn, arg, ArgT)

      CEVAL_BINDING(__) => fold(binding.bindingExp, foldFn, arg, ArgT)

      _ => arg
    end
  end
  return arg
end

@nospecializeinfer function mapExp(binding::Binding, mapFn::Function)
  local e1::Expression
  local e2::Expression
  local res = @match binding begin
    UNTYPED_BINDING(bindingExp = e1) => begin
      e2 = map(e1, mapFn)
      binding = if !referenceEq(e1, e2)
        UNTYPED_BINDING(e2, binding.isProcessing, binding.scope, binding.isEach, binding.info)
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
        FLAT_BINDING(e2, binding.variability)
      else
        binding
      end
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
    _ => binding
  end
  return res
end

@nospecializeinfer function isEqual(binding1::Binding, binding2::Binding)
  local equal::Bool
   equal = begin
    @match (binding1, binding2) begin
      (UNBOUND(__), UNBOUND(__)) => true
      (RAW_BINDING(__), RAW_BINDING(__)) => AbsynUtil.expEqual(binding1.bindingExp, binding2.bindingExp)
      (UNTYPED_BINDING(__), UNTYPED_BINDING(__)) => isEqual(binding1.bindingExp, binding2.bindingExp)
      (TYPED_BINDING(__), TYPED_BINDING(__)) => isEqual(binding1.bindingExp, binding2.bindingExp)
      _ => false
    end
  end
  #= TODO: Handle propagated dims. =#
  return equal
end

@nospecializeinfer function toFlatString(binding::Binding, prefix::String = ""; inFunction = false)
  local string::String
   string = begin
    @match binding begin
      UNBOUND(__) => ""
      RAW_BINDING(__) => prefix + Dump.printExpStr(binding.bindingExp)::String

      UNTYPED_BINDING(__) => begin
        prefix + toFlatString(binding.bindingExp; inFunction = inFunction)::String
      end

      TYPED_BINDING(__) => begin
        prefix + toFlatString(binding.bindingExp; inFunction = inFunction)::String
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

@nospecializeinfer function toString(binding::Binding, prefix::String = "")
  local string::String

   string = begin
    @match binding begin
      UNBOUND(__) => ""

      RAW_BINDING(__) => begin
        str = binding.bindingExp
        prefix + "$str" # Dump.printExpStr(binding.bindingExp)
      end

      UNTYPED_BINDING(__) => prefix + toString(binding.bindingExp)

      TYPED_BINDING(__) => prefix + toString(binding.bindingExp)

      FLAT_BINDING(__) => prefix + toString(binding.bindingExp)

      CEVAL_BINDING(__) => prefix + toString(binding.bindingExp)

      INVALID_BINDING(__) => toString(binding.binding, prefix)
    end
  end
  return string
end

""" #= Returns the number of dimensions that the binding was propagated through to
     get to the element it belongs to. =#"""
@nospecializeinfer function propagatedDimCount(binding::Binding)
  local count::Int

   count = begin
    @match binding begin
      UNTYPED_BINDING(__) => propagatedDimCount(binding.bindingExp)

      TYPED_BINDING(__) => propagatedDimCount(binding.bindingExp)

      _ => 0
    end
  end
  return count
end

@nospecializeinfer function isClassBinding(binding::Binding)
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
  if ! (isvariant(binding, UNBOUND) || isvariant(binding, RAW_BINDING))
    return binding
  end

  local parentLst = Cons{InstNode}(parent, binding.parents)
  local newBinding = if isvariant(binding, UNBOUND)
    UNBOUND(parentLst,
            binding.isEach,
            binding.info)
  elseif isvariant(binding, RAW_BINDING)
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

function parents(binding::Binding)
  local parents::Union{Vector{InstNode}, List{InstNode}}
  parents = begin
    @match binding begin
      UNBOUND(__) => binding.parents
      RAW_BINDING(__) => binding.parents
      UNTYPED_BINDING(
        bindingExp = BINDING_EXP(__),
      ) => binding.bindingExp.parents
      TYPED_BINDING(bindingExp = BINDING_EXP(__)) => binding.bindingExp.parents
      CEVAL_BINDING(bindingExp = BINDING_EXP(__)) => binding.bindingExp.parents
      _ => InstNode[]
    end
  end
  return parents
end

@nospecializeinfer function isTyped(binding::Binding)
  local isTyped::Bool

   isTyped = begin
    @match binding begin
      TYPED_BINDING(__) => true

      _ => false
    end
  end
  return isTyped
end

@nospecializeinfer function isEach(binding::Binding)
  local isEach::Bool

   isEach = begin
    @match binding begin
      UNBOUND(__) => binding.isEach

      RAW_BINDING(__) => binding.isEach

      UNTYPED_BINDING(__) => binding.isEach

      TYPED_BINDING(__) => binding.eachType == EachType.EACH

      _ => false
    end
  end
  return isEach
end

function getType(binding::Binding)
  local ty::ModelicaType
   ty = begin
    @match binding begin
      UNBOUND(__) => TYPE_UNKNOWN()
      RAW_BINDING(__) => TYPE_UNKNOWN()

      UNTYPED_BINDING(__) => TYPE_UNKNOWN()

      TYPED_BINDING(__) => binding.bindingType

      FLAT_BINDING(__) => typeOf(binding.bindingExp)

      CEVAL_BINDING(__) => typeOf(binding.bindingExp)

      INVALID_BINDING(__) => getType(binding.binding)
    end
  end
  return ty
end

@nospecializeinfer function Binding_getInfo(binding::Binding)
  local info::SourceInfo

   info = begin
    @match binding begin
      UNBOUND(__) => binding.info

      RAW_BINDING(__) => binding.info

      UNTYPED_BINDING(__) => binding.info

      TYPED_BINDING(__) => binding.info

      _ => AbsynUtil.dummyInfo
    end
  end
  return info
end

@nospecializeinfer function variability(binding::Binding)
  local var::VariabilityType

   var = begin
    @match binding begin
      TYPED_BINDING(__) => binding.variability

      FLAT_BINDING(__) => binding.variability

      _ => begin
        Error.assertion(false, getInstanceName() + " got unknown binding", sourceInfo())
        fail()
      end
    end
  end
  return var
end

@nospecializeinfer function recordFieldBinding(fieldNode::InstNode, recordBinding::Binding)
  local fieldBinding::Binding = recordBinding
  local exp::Expression
  local ty::ModelicaType
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
      TYPED_BINDING(__) => isCref(getBindingExp(binding.bindingExp))
      _ => false
    end
  end
  return isCrefVar
end

function getExp(binding::Binding)
  local exp::Expression

   exp = begin
    @match binding begin
      UNTYPED_BINDING(__) => binding.bindingExp

      TYPED_BINDING(__) => binding.bindingExp

      FLAT_BINDING(__) => binding.bindingExp
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
  return binding
end

function getTypedExp(binding::Binding)
  local exp::Expression
   exp = begin
    @match binding begin
      TYPED_BINDING(__) => binding.bindingExp

      FLAT_BINDING(__) => binding.bindingExp
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
      TYPED_BINDING(__) => SOME(binding.bindingExp)

      FLAT_BINDING(__) => SOME(binding.bindingExp)

      _ => NONE()
    end
  end
  return exp
end

function untypedExp(binding::Binding)
  local exp::Option{Expression}

   exp = begin
    @match binding begin
      UNTYPED_BINDING(__) => SOME(binding.bindingExp)

      _ => NONE()
    end
  end
  return exp
end

function isUnbound(binding::Binding)
  local isUnbound::Bool

   isUnbound = begin
    @match binding begin
      UNBOUND(__) => true

      _ => false
    end
  end
  return isUnbound
end

function isExplicitlyBound(binding::Binding)
  local isBound::Bool
  isBound = begin
    @match binding begin
      UNBOUND(__) => false
      CEVAL_BINDING(__) => false
      _ => true
    end
  end
  return isBound
end

function isBound(binding::Binding)
  local isBound::Bool
  isBound = begin
    @match binding begin
      UNBOUND(__) => false
      _ => true
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
      SOME(exp) => RAW_BINDING(exp, scope, parents, eachPrefix, info)
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

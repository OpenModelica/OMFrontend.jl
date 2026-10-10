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

function scalarize(flatModel::FlatModel, name::String)::FlatModel
  local vars::Vector{Variable} = Variable[]
  for v in flatModel.variables
    scalarizeVariable(v, vars)
  end
  local equations = scalarizeEquations(mapExpList(flatModel.equations, expandComplexCref))
  local initialEquations = scalarizeEquations(mapExpList(flatModel.initialEquations, expandComplexCref))
  local algorithms = Algorithm[scalarizeAlgorithm(a) for a in flatModel.algorithms]
  local initialAlgorithms = Algorithm[scalarizeAlgorithm(a) for a in flatModel.initialAlgorithms]
  @assign begin
    flatModel.variables = vars
    flatModel.equations = equations
    flatModel.initialEquations = initialEquations
    flatModel.algorithms = algorithms
    flatModel.initialAlgorithms = initialAlgorithms
  end
  #execStat(getInstanceName() + "(" + name + ")")
  return flatModel
end

"""
    scalarizeKeptArrays(flatModel::FlatModel)::FlatModel

A flat model flattened without scalarization (`scalarize = false`: array variables, array
equations, for-equations) in the scalarized form the backend takes: for-equations unrolled
(nested ones too, then simplified), array variables split into their elements, also those
whose dimensions are on a prefix part (`r.p.i` of a component array `r`: `r[1].p.i`, as the
equations refer to them), then the array equations expanded by `scalarize`. Algorithms keep
their for-statements, as when scalarizing.
"""
function scalarizeKeptArrays(flatModel::FlatModel)::FlatModel
  #= The settings of a scalarizing flattening (setSettingForInst): expansion of operations and
     function arguments on, so der(x) expands to der(x[1]), ... They stay on: from here on
     the model is scalar, as after a scalarizing flatten. =#
  FlagsUtil.set(Flags.NF_SCALARIZE, true)
  FlagsUtil.set(Flags.NF_EXPAND_OPERATIONS, true)
  FlagsUtil.set(Flags.NF_EXPAND_FUNC_ARGS, true)
  #= The array variables by name: their element crefs, dimensions and element type. A cref
     of an array variable without (literal) subscripts on its array parts becomes the array of
     its elements (the variable table knows the dimensions; the parts of a cref in a
     vectorized equation do not always carry them). =#
  local table = Dict{String, Tuple{Vector{ComponentRef}, Vector{Int}, NFType}}()
  for v in flatModel.variables
    if isArray(v.ty) && hasKnownSize(v.ty) && !isEmptyArray(v.ty)
      table[_unsubscriptedName(v.name)] = (_expandArrayParts(v.name), [size(d) for d in arrayDims(v.ty)], arrayElementType(v.ty))
    end
  end
  local expandArr = (e) -> map(e, (x) -> _expandKeptArrayCref(x, table))
  local vars::Vector{Variable} = Variable[]
  for v in flatModel.variables
    _splitKeptArrayVariable(v, vars, table)
  end
  @assign begin
    flatModel.variables = vars
    flatModel.equations = _arrayEqualityAsEquality(mapExpList(_unrollForEquations(flatModel.equations), expandArr))
    flatModel.initialEquations = _arrayEqualityAsEquality(mapExpList(_unrollForEquations(flatModel.initialEquations), expandArr))
    flatModel.algorithms = mapExpList(_unrollVectorizedAlgorithms(flatModel.algorithms), expandArr)
    flatModel.initialAlgorithms = mapExpList(_unrollVectorizedAlgorithms(flatModel.initialAlgorithms), expandArr)
  end
  #= As a scalarizing flatten: simplify with the expansion settings on (function arguments and
     operations on arrays expanded, in bindings and algorithms too), then scalarize. =#
  flatModel = simplifyFlatModel(flatModel)
  return scalarize(flatModel, flatModel.name)
end

#= An algorithm of a component array kept as an array is vectorized into one for-loop over the
   array (vectorizeAlgorithm, iterators named $i...): one algorithm per element instead, with
   the iterator replaced in every cref part, as a scalarizing flatten gives (the backend lowers
   when-statements per element). Loops written in the model stay. =#
function _unrollVectorizedAlgorithms(algs::Vector{Algorithm})::Vector{Algorithm}
  local out = Algorithm[]
  for alg in algs
    _unrollVectorizedAlgorithm!(out, alg.statements, alg.source)
  end
  return out
end

function _unrollVectorizedAlgorithm!(out::Vector{Algorithm}, stmts::Vector{Statement}, source)
  if length(stmts) == 1 && isvariant(stmts[1], ALG_FOR) && startswith(name(stmts[1].iterator), "\$") &&
     isSome(stmts[1].range)
    local loop = stmts[1]
    local range::Expression = evalExp(Util.getOption(loop.range), EVALTARGET_RANGE(AbsynUtil.dummyInfo))
    local range_iter = RangeIterator_fromExp(range)
    local val::Expression
    while hasNext(range_iter)
      (range_iter, val) = next(range_iter)
      local f = (e) -> map(e, (x) -> _replaceIteratorInExp(x, loop.iterator, val))
      _unrollVectorizedAlgorithm!(out, mapExpList(loop.body, f), source)
    end
  else
    push!(out, ALGORITHM(stmts, source))
  end
  return out
end

#= A variable of a flat model with arrays kept, split into its elements (also over the
   dimensions of its prefix parts: r.p.i of a component array r -> r[1].p.i, ...), with the
   binding and type attributes of each element. A scalar variable keeps its binding, array
   crefs in it expanded (an array context). =#
function _splitKeptArrayVariable(v::Variable, vars::Vector{Variable}, table)
  local expandArr = (x) -> _expandKeptArrayCref(x, table)
  if !(isArray(v.ty) && hasKnownSize(v.ty))
    push!(vars, VARIABLE(v.name, v.ty, mapExp(v.binding, expandArr), v.visibility, v.attributes,
                         Tuple{String, Binding}[(n, mapExp(b, expandArr)) for (n, b) in v.typeAttributes],
                         v.comment, v.info))
    return vars
  end
  isEmptyArray(v.ty) && return vars
  local ndims = length(arrayDims(v.ty))
  local (elems, _, elty) = table[_unsubscriptedName(v.name)]
  local bindings = _elementBindings(v.binding, elems, ndims, v, table)
  local attrs = [(n, _elementBindings(b, elems, ndims, v, table)) for (n, b) in v.typeAttributes]
  for (k, e) in enumerate(elems)
    push!(vars, VARIABLE(e, elty, bindings[k], v.visibility, v.attributes,
                         Tuple{String, Binding}[(n, bs[k]) for (n, bs) in attrs], v.comment, v.info))
  end
  return vars
end

#= The binding of each element. Per instance (fewer dimensions than the variable: written for
   one component of a component array kept as an array, or each): the element's prefix
   subscripts transferred into its crefs (r[2].p.i's binding reads r[2]'s parameters), as
   flattening a scalarized component array does. An array binding: expanded, element k. =#
function _elementBindings(b::Binding, elems::Vector{ComponentRef}, ndims::Int, v::Variable, table)::Vector{Binding}
  isBound(b) || return Binding[b for _ in elems]
  local e = getTypedExp(b)
  local var = variability(b)
  local expandArr = (x) -> _expandKeptArrayCref(x, table)
  if isEach(b) || dimensionCount(typeOf(e)) < ndims
    #= Per element: the prefix subscripts transferred, then the arrays left (a field that is
       itself an array, vol[2].X_start) expanded. =#
    return Binding[FLAT_BINDING(map(map(e, (x) -> _transferPrefixSubs(x, el)), expandArr), var) for el in elems]
  end
  local (ee, expanded) = expand(map(e, expandArr))
  local scal = expanded ? Base.collect(arrayScalarElements(ee)) : Expression[]
  if length(scal) != length(elems)
    Error.assertion(false, getInstanceName() + " could not split the binding " + toString(e) +
                    " over the " + String(length(elems)) + " elements of " + toString(v.name), v.info)
    fail()
  end
  return Binding[FLAT_BINDING(x, var) for x in scal]
end

function _transferPrefixSubs(@nospecialize(x::Expression), el::ComponentRef)::Expression
  (x isa CREF_EXPRESSION && isvariant(x.cref, COMPONENT_REF_CREF)) || return x
  return CREF_EXPRESSION(x.ty, transferSubscripts(el, x.cref))
end

#= A cref of an array variable whose array parts are not all subscripted: the (nested) array of
   the matching elements over the free dimensions (x -> {x[1], x[2]}, vol[2].X_start ->
   {vol[2].X_start[1], ...}, whole arrays in function arguments too, as a scalarizing flatten
   expands them). Crefs with non-literal subscripts (loop iterators) are left. Array crefs in a
   tuple target are expanded likewise. Other crefs: _expandPrefixArrayCref. =#
function _expandKeptArrayCref(@nospecialize(x::Expression), table)::Expression
  if x isa TUPLE_EXPRESSION
    local changed = false
    local elems = Expression[]
    for e in x.elements
      local e2 = e isa CREF_EXPRESSION ? _expandKeptArrayCref(e, table) : e
      changed |= !referenceEq(e, e2)
      push!(elems, e2)
    end
    return changed ? TUPLE_EXPRESSION(x.ty, list(elems...)) : x
  end
  (x isa CREF_EXPRESSION && isvariant(x.cref, COMPONENT_REF_CREF)) || return x
  local entry = get(table, _unsubscriptedName(x.cref), nothing)
  entry === nothing && return _expandPrefixArrayCref(x)
  local (elems, dims, elty) = entry
  local xparts = _crefPartsRootFirst(x.cref)
  local eparts0 = _crefPartsRootFirst(elems[1])
  length(xparts) == length(eparts0) || return x
  #= The variable's dimensions per part (the elements' subscript counts), the free ones where x
     has no subscripts. =#
  local freeDims = Int[]
  local pos = 1
  for (xp, ep) in zip(xparts, eparts0)
    local n = listLength(ep.subscripts)
    listEmpty(xp.subscripts) && append!(freeDims, dims[pos:(pos + n - 1)])
    pos += n
  end
  isempty(freeDims) && return x
  local matching = ComponentRef[]
  for el in elems
    local ok = true
    for (xp, ep) in zip(xparts, _crefPartsRootFirst(el))
      listEmpty(xp.subscripts) && continue
      local eq = _literalSubsEqual(xp.subscripts, ep.subscripts)
      eq === nothing && return x
      if !eq
        ok = false
        break
      end
    end
    ok && push!(matching, el)
  end
  length(matching) == prod(freeDims) || return x
  return _nestedCrefArray(matching, freeDims, elty, 0)
end

#= An array equality whose sides are both expanded arrays (a vectorized x = k after
   _expandKeptArrayCref) as a plain equality: scalarizeEquation splits that per element, while
   its array-equality case evaluates parameters (x[1] = -0.01 instead of x[1] = k[1]). =#
function _arrayEqualityAsEquality(eql::Vector{Equation})::Vector{Equation}
  return Equation[(isvariant(eq, EQUATION_ARRAY_EQUALITY) && eq.lhs isa ARRAY_EXPRESSION && eq.rhs isa ARRAY_EXPRESSION) ?
                  EQUATION_EQUALITY(eq.lhs, eq.rhs, eq.ty, eq.source) : eq for eq in eql]
end

function _unsubscriptedName(cr::ComponentRef)::String
  return Base.join([name(p.node) for p in _crefPartsRootFirst(cr)], ".")
end

function _crefPartsRootFirst(cr::ComponentRef)::Vector{ComponentRef}
  local parts = ComponentRef[]
  while isvariant(cr, COMPONENT_REF_CREF)
    pushfirst!(parts, cr)
    cr = cr.restCref
  end
  return parts
end

#= Whether two subscript lists are equal literal indices; nothing when the first is not literal. =#
function _literalSubsEqual(xs::List{<:Subscript}, es::List{<:Subscript})
  listLength(xs) == listLength(es) || return false
  for (a, b) in zip(xs, es)
    (a isa SUBSCRIPT_INDEX && isLiteral(a.index)) || return nothing
    (b isa SUBSCRIPT_INDEX && isEqual(a.index, b.index)) || return false
  end
  return true
end

#= A cref with array dimensions on a prefix part without subscripts, as names of a component
   array kept as an array (c.T0 of c[4]): the nested array of its element crefs (c[1].T0, ...).
   ExpandExp.expandCref expands the parts written in an expression only, not the prefix of a
   flattened name. =#
function _expandPrefixArrayCref(@nospecialize(exp::Expression))::Expression
  exp isa CREF_EXPRESSION || return exp
  local cr = exp.cref
  isvariant(cr, COMPONENT_REF_CREF) || return exp
  local dims = Int[]
  local hasPrefixDims = false
  local part = cr
  local isLeaf = true
  while isvariant(part, COMPONENT_REF_CREF)
    if listEmpty(part.subscripts)
      local pdims = [size(d) for d in arrayDims(part.ty)]
      if !isempty(pdims)
        prepend!(dims, pdims)
        isLeaf || (hasPrefixDims = true)
      end
    end
    isLeaf = false
    part = part.restCref
  end
  hasPrefixDims || return exp
  return _nestedCrefArray(_expandArrayParts(cr), dims, arrayElementType(exp.ty), 0)
end

function _nestedCrefArray(crefs::Vector{ComponentRef}, dims::Vector{Int}, elty::NFType, offset::Int)::Expression
  if length(dims) == 1
    local elems = Expression[CREF_EXPRESSION(elty, crefs[offset + i]) for i in 1:dims[1]]
    return makeArray(liftArrayLeft(elty, fromInteger(dims[1])), elems)
  end
  local rest = dims[2:end]
  local stride = prod(rest)
  local subs = Expression[_nestedCrefArray(crefs, rest, elty, offset + (i - 1) * stride) for i in 1:dims[1]]
  return makeArray(liftArrayLeft(typeOf(subs[1]), fromInteger(dims[1])), subs)
end

#= For-equations unrolled: the iterator replaced by each value of its range (nested loops and
   loops in if-branches too), then simplified so subscripts like x[i - 1] fold and
   if-equations whose conditions used the iterator are resolved. =#
function _unrollForEquations(eql::Vector{Equation})::Vector{Equation}
  local out = Equation[]
  for eq in eql
    _unrollForEquation!(out, eq)
  end
  return simplifyEquations(out)
end

#= replaceIteratorList that also replaces the iterator in the subscripts of a cref's prefix
   parts: vectorizing a component array puts its iterators there (c[$i1].C), and the
   expression map (mapCref) only visits the parts of CREF origin. =#
function _replaceIteratorAllParts(eql::Vector{Equation}, iterator::InstNode, @nospecialize(value::Expression))::Vector{Equation}
  local f = (e) -> map(e, (x) -> _replaceIteratorInExp(x, iterator, value))
  return mapExpList(eql, f)
end

function _replaceIteratorInExp(@nospecialize(x::Expression), iterator::InstNode, @nospecialize(value::Expression))::Expression
  if x isa CREF_EXPRESSION && isvariant(x.cref, COMPONENT_REF_CREF) && !isSimple(x.cref)
    return CREF_EXPRESSION(x.ty, _replaceIteratorInCrefParts(x.cref, iterator, value))
  end
  return replaceIterator2(x, iterator, value)
end

function _replaceIteratorInCrefParts(cr::ComponentRef, iterator::InstNode, @nospecialize(value::Expression))::ComponentRef
  isvariant(cr, COMPONENT_REF_CREF) || return cr
  local rest = _replaceIteratorInCrefParts(cr.restCref, iterator, value)
  local subs = list(mapExp(sub, (e) -> replaceIterator(e, iterator, value)) for sub in cr.subscripts)
  return COMPONENT_REF_CREF(cr.node, subs, cr.ty, cr.origin, rest)
end

function _unrollForEquation!(out::Vector{Equation}, @nospecialize(eq::Equation))
  if isvariant(eq, EQUATION_FOR)
    local range::Expression = evalExp(Util.getOption(eq.range), EVALTARGET_RANGE(Equation_info(eq)))
    local range_iter = RangeIterator_fromExp(range)
    local val::Expression
    while hasNext(range_iter)
      (range_iter, val) = next(range_iter)
      for b in _replaceIteratorAllParts(eq.body, eq.iterator, val)
        _unrollForEquation!(out, b)
      end
    end
  elseif isvariant(eq, EQUATION_IF) && contains(eq, isConnectEq)
    #= An if-equation with connects: its branch picked now that the iterators have values
       (an arrayed component's if ground then connect(...) end if). =#
    for b in eq.branches
      isvariant(b, EQUATION_BRANCH) || (push!(out, eq); return out)
      local c = evalExp(b.condition)
      isBoolean(c) || (push!(out, eq); return out)
      if isTrue(c)
        for e in b.body
          _unrollForEquation!(out, e)
        end
        return out
      end
    end
  elseif isvariant(eq, EQUATION_IF)
    local bl = EquationBranch[]
    for b in eq.branches
      if isvariant(b, EQUATION_BRANCH)
        local body = Equation[]
        for e in b.body
          _unrollForEquation!(body, e)
        end
        push!(bl, makeBranch(b.condition, body, b.conditionVar))
      else
        push!(bl, b)
      end
    end
    push!(out, EQUATION_IF(bl, eq.source))
  else
    push!(out, eq)
  end
  return out
end

function scalarizeVariable(var::Variable, vars::Vector{Variable})
  local name::ComponentRef
  local binding::Binding
  local ty::M_Type
  local vis::VisibilityType
  local attr::Attributes
  local ty_attr::Vector{Tuple{String, Binding}}
  local cmt::Option{SCode.Comment}
  local info::SourceInfo
  local binding_iter::ExpressionIterator
  local crefs::List{ComponentRef}
  local exp::Expression
  local v::Variable
  local ty_attr_names::Vector{String}
  local ty_attr_iters::Vector{ExpressionIterator}
  local bind_var::VariabilityType
  if isArray(var.ty) && hasKnownSize(var.ty)
    #= Skip zero-size array variables entirely =#
    if isEmptyArray(var.ty)
      return vars
    end
    try
      @match VARIABLE(
        name,
        ty,
        binding,
        vis,
        attr,
        ty_attr,
        cmt,
        info,
      ) = var
      crefs = scalarize(name)
      if listEmpty(crefs)
        return vars
      end
      ty = arrayElementType(ty)
      (ty_attr_names, ty_attr_iters) = scalarizeTypeAttributes(ty_attr)
      #= Addition by me //John =#
      if isBound(binding)
        #        @info "bound" toString(binding)
        binding_iter = fromExpToExpressionIterator(expandComplexCref(getTypedExp(binding)))
        bind_var = variability(binding)
        #= Some other checks in omc currently... =#
        for cr in crefs
          #@info "Looping..."
          if hasNext(binding_iter)
            #@info "Had next"
            (binding_iter, exp) = next(binding_iter)
            binding = FLAT_BINDING(exp, bind_var)
            ty_attr = nextTypeAttributes(ty_attr_names, ty_attr_iters)
            push!(
              vars,
              VARIABLE(cr, ty, binding, vis, attr, ty_attr, cmt, info)
            )
          else #= Did not have a next =#
            # push!(
            #   vars,
            #   VARIABLE(cr, ty, binding, vis, attr, ty_attr, cmt, info)
            # )
          end
        end
      else
        for cr in crefs
          ty_attr = nextTypeAttributes(ty_attr_names, ty_attr_iters)
          push!(vars,
                VARIABLE(cr, ty, binding, vis, attr, ty_attr, cmt, info))
        end
      end
    catch e
      Error.assertion(
        false,
        getInstanceName() +
          " failed on " +
          toString(var, "", true),
        var.info,
      )
    end
  else
    local res
    res = mapExp(var.binding, expandComplexCref_traverser)
    @assign var.binding = res
    push!(vars, var)
  end
  #@info "Scalarize var res:" toString(vars)
  return vars
end

function scalarizeTypeAttributes(attrs::Vector{Tuple{String, Binding}},
  )
  local iters::Vector{ExpressionIterator}
  local names::Vector{String} = String[]
  local len::Int
  local i::Int
  local name::String
  local binding::Binding
  len = length(attrs)
  iters = arrayCreateNoInit(len, EXPRESSION_NONE_ITERATOR())
  i = len
  for attr in attrs
    (name, binding) = attr
    pushfirst!(names, name)
    iters[i] = fromBinding(binding)
    i = i - 1
  end
  return (names, iters)
end

function nextTypeAttributes(
  names::Vector{String},
  iters::Vector{ExpressionIterator},
)::Vector{Tuple{String, Binding}}
  local attrs = Tuple{String, Binding}[]
  local i::Int = 1
  local iter::ExpressionIterator
  local exp::Expression
  for name in names
    (iter, exp) = next(iters[i])
    iters[i] = iter
    i = i + 1
    attrs = push!(attrs, (name, FLAT_BINDING(exp, Variability.PARAMETER)))
  end
  return attrs
end

function expandComplexCref(exp::Expression)
  exp = map(exp, expandComplexCref_traverser)
  return exp
end


function expandComplexCref_traverser(exp::Expression)
  @match exp begin
    CREF_EXPRESSION(ty = TYPE_ARRAY(__)) => begin
      #=  Expand crefs where any of the prefix nodes are arrays. For example if
      =#
      #=  b in a.b.c is SomeType[2] we expand it into {a.b[1].c, a.b[2].c}.
      =#
      #=  TODO: This is only done due to backend issues and shouldn't be
      =#
      #=        necessary.
      =#
      if isComplexArray(exp.cref)
        (exp, _) = expand(exp)
      end

    end
    _ => begin
    end
  end
  return exp
end

function scalarizeEquations(eql::Vector{Equation})
  local equations::Vector{Equation} = Equation[]
  for eq in eql
    equations = scalarizeEquation(eq, equations)
  end
  return equations
end

function scalarizeEquation(@nospecialize(eq::Equation), equations::Vector{Equation})
  #= Expand record-typed equations to field-level equations.
     For CREF = CREF: expand both sides to their record fields.
     For CREF = CALL (function returning record): keep as record-level. =#
  if isvariant(eq, EQUATION_EQUALITY) && isComplex(eq.ty)
    local rec_lhs = eq.lhs
    local rec_rhs = eq.rhs
    local lhs_expandable = rec_lhs isa CREF_EXPRESSION || rec_lhs isa RECORD_EXPRESSION
    local rhs_expandable = rec_rhs isa CREF_EXPRESSION || rec_rhs isa RECORD_EXPRESSION
    if lhs_expandable && rhs_expandable
      @match TYPE_COMPLEX(cls = rec_cls) = eq.ty
      local rec_comps::Vector{InstNode} = getComponents(classTree(getClass(rec_cls)))
      for (i, comp) in enumerate(rec_comps)
        local fty = getType(comp)
        local flhs = if rec_lhs isa CREF_EXPRESSION
          CREF_EXPRESSION(fty, prefixCref(comp, fty, nil, rec_lhs.cref))
        else
          rec_lhs.elements[i]
        end
        local frhs = if rec_rhs isa CREF_EXPRESSION
          CREF_EXPRESSION(fty, prefixCref(comp, fty, nil, rec_rhs.cref))
        else
          rec_rhs.elements[i]
        end
        local feq = EQUATION_EQUALITY(flhs, frhs, fty, eq.source)
        equations = scalarizeEquation(feq, equations)
      end
      return equations
    else
      push!(equations, eq)
      return equations
    end
  end
  #= Pre-process: try to expand EQUATION_ARRAY_EQUALITY with TYPED_ARRAY_CONSTRUCTOR
     before the @match block, since Revise cannot update @match cases. =#
  if isvariant(eq, EQUATION_ARRAY_EQUALITY)
    local _expanded = tryExpandArrayEqualityToScalar(eq)
    if _expanded !== nothing
      for _eq in _expanded
        equations = scalarizeEquation(_eq, equations)
      end
      return equations
    end
  end
  equations = begin
    local lhs_iter::ExpressionIterator
    local rhs_iter::ExpressionIterator
    local lhs::Expression
    local rhs::Expression
    local ty::M_Type
    local src::DAE.ElementSource
    local info::SourceInfo
    @match eq begin

      EQUATION_EQUALITY(
        lhs,
        rhs,
        ty,
        src,
      ) where{isArray(ty)} => begin

        local lhs = eq.lhs
      if hasArrayCall(lhs) || hasArrayCall(rhs)
        #= Try to expand array comprehensions/calls before giving up.
           expand() handles TYPED_ARRAY_CONSTRUCTOR and broadcasts. =#
        local _exp_ok = true
        local _exp_lhs = lhs
        local _exp_rhs = eq.rhs
        try
          (_exp_lhs, _) = expand(lhs)
          (_exp_rhs, _) = expand(eq.rhs)
        catch
          _exp_ok = false
        end
        if !_exp_ok
          equations = push!(equations, EQUATION_ARRAY_EQUALITY(lhs, eq.rhs, ty, src))
          return equations
        end
        lhs_iter = fromExpToExpressionIterator(_exp_lhs)
        rhs_iter = fromExpToExpressionIterator(_exp_rhs)
        #= A side that stays a call (an operator record's array function, `ca1 = -ca2` as
           Complex.'-'.negateArr(ca2)) has no elements: an array equation, as omc keeps any
           equation with an array call. =#
        if hasNext(lhs_iter) != hasNext(rhs_iter) && isArray(typeOf(eq.rhs)) && isArray(typeOf(lhs))
          equations = push!(equations, EQUATION_ARRAY_EQUALITY(lhs, eq.rhs, eq.ty, src))
          return equations
        end
      else
        lhs_iter = fromExpToExpressionIterator(lhs)
        rhs_iter = fromExpToExpressionIterator(rhs)
        #= If the RHS cannot be expanded into elements (e.g. arithmetic over
           array slices like 0.5*(rhos[1:1]+rhos[2:2])), keep the equation
           as an array equality for the backend to handle. =#
        if !hasNext(rhs_iter) && hasNext(lhs_iter)
          equations = push!(equations, EQUATION_ARRAY_EQUALITY(eq.lhs, eq.rhs, eq.ty, src))
          return equations
        end
      end
      local rhs_is_scalar = !isArray(typeOf(eq.rhs))
      local scalar_rhs::Expression = eq.rhs
      ty = arrayElementType(ty)
      while hasNext(lhs_iter)
        if !hasNext(rhs_iter)
          if rhs_is_scalar
            #= Scalar RHS broadcast to all LHS elements =#
            (lhs_iter, lhs) = next(lhs_iter)
            equations = scalarizeEquation(EQUATION_EQUALITY(lhs, scalar_rhs, ty, src), equations)
            continue
          end
          local msg = string(" could not expand rhs " + toString(eq.rhs) * " to match " * toString(eq.lhs),
                             " rhs type was: $(toString(eq.ty)) & lhs type was: $(toString(eq.ty))")
          @info "scalarizeEquation: RHS exhausted before LHS" toString(eq.lhs) toString(eq.rhs) toString(eq.ty)
          Error.addInternalError(
            getInstanceName() +
              msg,
            src.info,
          )
          fail()
        end
        (lhs_iter, lhs) = next(lhs_iter)
        (rhs_iter, rhs) = next(rhs_iter)
        equations = scalarizeEquation(EQUATION_EQUALITY(lhs, rhs, ty, src), equations)
      end
      equations
      end
      EQUATION_ARRAY_EQUALITY(
        CREF_EXPRESSION(__),
        rhs,
        ty,
        src) where{isArray(ty) && (isArray(eq.rhs) || isArray(eq.lhs))} => begin
          local lhs = eq.lhs
          if hasArrayCall(lhs) || hasArrayCall(rhs)
            equations = push!(equations, EQUATION_ARRAY_EQUALITY(lhs, rhs, ty, src))
          else
            lhs_iter = fromExpToExpressionIterator(lhs)
            rhs_iter = fromExpToExpressionIterator(rhs)
            ty = arrayElementType(ty)
            while hasNext(lhs_iter)
              if !hasNext(rhs_iter)
                local msg =   string(" could not expand rhs " + toString(eq.rhs) * " to match " * toString(eq.lhs),
                                     " rhs type was: $(toString(rhs.ty)) & lhs type was: $(toString(lhs.ty)). Full Equation: $(toString(eq))")
                Error.addInternalError(
                  getInstanceName() +
                    msg,
                  src.info,
                )
                fail()
              end
              (lhs_iter, lhs) = next(lhs_iter)
              (rhs_iter, rhs) = next(rhs_iter)
              local arrEq = EQUATION_EQUALITY(lhs, rhs, ty, src)
              equations = push!(equations, arrEq)
            end
          end
          equations

        end

      EQUATION_ARRAY_EQUALITY(CREF_EXPRESSION(__), CALL_EXPRESSION(call), TYPE_ARRAY(__))  where {isvariant(call, TYPED_ARRAY_CONSTRUCTOR)}=> begin
        local newExp = _tryEvalParameterExp(eq.rhs)
        local aeq = EQUATION_ARRAY_EQUALITY(eq.lhs, newExp, eq.ty, eq.source)
        push!(equations, aeq)
      end

      EQUATION_ARRAY_EQUALITY(__) => begin
        #= Try to expand/eval and scalarize before falling through. =#
        try
          local _aexp_lhs = _tryEvalParameterExp(eq.lhs)
          local _aexp_rhs = _tryEvalParameterExp(eq.rhs)
          (_aexp_lhs, _) = expand(_aexp_lhs)
          (_aexp_rhs, _) = expand(_aexp_rhs)
          local _a_lhs_iter = fromExpToExpressionIterator(_aexp_lhs)
          local _a_rhs_iter = fromExpToExpressionIterator(_aexp_rhs)
          if hasNext(_a_lhs_iter) && hasNext(_a_rhs_iter)
            local _a_ty = arrayElementType(eq.ty)
            while hasNext(_a_lhs_iter) && hasNext(_a_rhs_iter)
              (_a_lhs_iter, lhs) = next(_a_lhs_iter)
              (_a_rhs_iter, rhs) = next(_a_rhs_iter)
              equations = scalarizeEquation(EQUATION_EQUALITY(lhs, rhs, _a_ty, eq.source), equations)
            end
            return equations
          end
        catch _aexp_err
          #= Expansion failed; keep as array equality for toFlatStream. =#
        end
        push!(equations, EQUATION_ARRAY_EQUALITY(eq.lhs, eq.rhs, eq.ty, eq.source))
      end

      EQUATION_CONNECT(__) => begin
        equations
      end

      EQUATION_IF(__) => begin
        scalarizeIfEquation(eq.branches, eq.source, equations)
      end

      EQUATION_WHEN(__) => begin
        scalarizeWhenEquation(eq.branches, eq.source, equations)
      end

      _ => begin
        push!(equations, eq)
      end
    end
  end
  return equations
end

#= tryEvalExp for a constant or parameter expression; any other is returned as it is. A discrete or
   continuous expression cannot evaluate to a constant: evalExp finds that out by throwing, after
   evaluating the function bodies it calls (0.3-7 ms per equation on MultiBody's frame functions,
   three quarters of Engine1a's scalarize). =#
function _tryEvalParameterExp(exp::Expression)::Expression
  return variability(exp) <= Variability.NON_STRUCTURAL_PARAMETER ? tryEvalExp(exp) : exp
end

"""
Remove the trailing branches with no equations after scalarization (an empty
branch before others stays: where its condition holds, none of the later
ones runs). Add the scalarized if equation to the list of equations unless we
don't have any branches left.
"""
function scalarizeIfEquation(
  branches::Vector{<:Equation_Branch},
  source::DAE.ElementSource,
  equations::Vector{Equation},
)
  local bl::Vector{EquationBranch} = EquationBranch[]
  local cond::Expression
  local body::Vector{Equation}
  local var::VariabilityType
  for b in branches
    @match EQUATION_BRANCH(cond, var, body) = b
    body = scalarizeEquations(body)
    push!(bl, makeBranch(cond, body, var))
  end
  while !isempty(bl) && isempty(last(bl).body)
    pop!(bl)
  end
  if !isempty(bl)
    push!(equations, EQUATION_IF(bl, source))
  end
  return equations
end

function scalarizeWhenEquation(
  branches::Vector{<:Equation_Branch},
  source::DAE.ElementSource,
  equations::Vector{Equation},
  )
  local bl::Vector{EquationBranch} = EquationBranch[]
  local cond::Expression
  local body::Vector{Equation}
  local var::VariabilityType
  for b in branches
    @match EQUATION_BRANCH(cond, var, body) = b
    body = scalarizeEquations(body)
    if isArray(typeOf(cond))
      (cond, _) = expand(cond)
    end
    push!(bl, makeBranch(cond, body, var))
  end
  push!(equations, EQUATION_WHEN(bl, source))
  return equations
end

function scalarizeAlgorithm(alg::Algorithm)::Algorithm
  @assign alg.statements = scalarizeStatements(alg.statements)
  return alg
end

function scalarizeStatements(stmts::Vector{Statement})
  local statements::Vector{Statement} = Statement[]
  for s in stmts
    statements = scalarizeStatement(s, statements)
  end
  statements = statements
  return statements
end

function scalarizeStatement(stmt::Statement, statements::Vector{Statement})
  statements = begin
    @match stmt begin
      ALG_FOR(__) => begin
        push!(
          statements,
          ALG_FOR(
            stmt.iterator,
            stmt.range,
            scalarizeStatements(stmt.body),
            stmt.source,
          ),
        )
      end
      ALG_IF(__) => begin
        scalarizeIfStatement(stmt.branches, stmt.source, statements)
      end
      ALG_WHEN(__) => begin
        scalarizeWhenStatement(stmt.branches, stmt.source, statements)
      end
      ALG_WHILE(__) => begin
        push!(
          statements,
          ALG_WHILE(
            stmt.condition,
            scalarizeStatements(stmt.body),
            stmt.source,
          ),
        )
      end
      _ => begin
        push!(statements, stmt)#_cons(stmt, statements)
      end
    end
  end
  return statements
end

function scalarizeIfStatement(
  branches::Vector{Tuple{Expression, Vector{Statement}}},
  source::DAE.ElementSource,
  statements::Vector{Statement},
)
  local bl::Vector{Tuple{Expression, Vector{Statement}}} = Tuple{Expression, Vector{Statement}}[]
  local cond::Expression
  local body::Vector{Statement}
  for b in branches
    (cond, body) = b
    push!(bl, (cond, scalarizeStatements(body)))
  end
  #= Remove the trailing branches with no statements after scalarization (an
     empty branch before others stays: where its condition holds, none of the
     later ones runs; `if mode == 1 then else y := 5; end if` with mode = 1
     set y). Add the scalarized if statement unless no branch is left. =#
  while !isempty(bl) && isempty(last(bl)[2])
    pop!(bl)
  end
  if !isempty(bl)
    push!(statements, ALG_IF(bl, source))
  end
  return statements
end

"""
  Scalarizes a when statement.
"""
function scalarizeWhenStatement(
  branches::Vector{Tuple{Expression, Vector{Statement}}},
  source::DAE.ElementSource,
  statements::Vector{Statement},
)
  local bl::Vector{Tuple{Expression, Vector{Statement}}} = Tuple{Expression, Vector{Statement}}[]
  local cond::Expression
  local body::Vector{Statement}
  for b in branches
    (cond, body) = b
    body = scalarizeStatements(body)
    if isArray(typeOf(cond))
      (cond, _) = expand(cond)
    end
    push!(bl, (cond, body))
  end
  statements = push!(statements, ALG_WHEN(bl, source))
  return statements
end

"""
Check whether both sides of a record equation can be expanded to field-level.
Returns true if both LHS and RHS are component references or record expressions.
Returns false if either side is a function call (which returns a record and
cannot be trivially split into per-field calls).
"""
function canExpandRecordEquationSides(@nospecialize(lhs::Expression), @nospecialize(rhs::Expression))::Bool
  lhs_ok = lhs isa CREF_EXPRESSION || lhs isa RECORD_EXPRESSION
  rhs_ok = rhs isa CREF_EXPRESSION || rhs isa RECORD_EXPRESSION
  return lhs_ok && rhs_ok
end

"""
Expand a record equation into per-field scalar equations.
For each field of the record type, creates a new EQUATION_EQUALITY
with the field appended to both LHS and RHS crefs.
The generated field equations are recursively scalarized to handle
array-typed fields (e.g. X :: Real[2]).
"""
function expandRecordEquation(
  @nospecialize(lhs::Expression),
  @nospecialize(rhs::Expression),
  ty::M_Type,
  src::DAE.ElementSource,
  equations::Vector{Equation},
)::Vector{Equation}
  @match TYPE_COMPLEX(cls = cls) = ty
  local comps::Vector{InstNode} = getComponents(classTree(getClass(cls)))
  for (i, comp) in enumerate(comps)
    local field_ty = getType(comp)
    local field_lhs = expandRecordFieldExp(lhs, comp, field_ty, i)
    local field_rhs = expandRecordFieldExp(rhs, comp, field_ty, i)
    local field_eq = EQUATION_EQUALITY(field_lhs, field_rhs, field_ty, src)
    equations = scalarizeEquation(field_eq, equations)
  end
  return equations
end

"""
Create a field-level expression from a record-level expression.
For CREF_EXPRESSION: appends the field component to get cref.field
For RECORD_EXPRESSION: extracts the i-th element
"""
function expandRecordFieldExp(
  @nospecialize(exp::Expression),
  fieldNode::InstNode,
  field_ty::M_Type,
  fieldIndex::Int,
)::Expression
  @match exp begin
    CREF_EXPRESSION(__) => begin
      local field_cr = prefixCref(fieldNode, field_ty, nil, exp.cref)
      CREF_EXPRESSION(field_ty, field_cr)
    end
    RECORD_EXPRESSION(__) => begin
      exp.elements[fieldIndex]
    end
    _ => begin
      exp
    end
  end
end

"""
Try to expand an EQUATION_ARRAY_EQUALITY into scalar equations.
Handles cases where the RHS is a TYPED_ARRAY_CONSTRUCTOR (possibly wrapped
in binary operations) and the LHS is an iterable array.
Returns a vector of scalar equations, or nothing if expansion is not possible.
"""
function tryExpandArrayEqualityToScalar(eq::Equation)
  local lhs_exp = eq.lhs
  local rhs_exp = eq.rhs
  #= Extract the TYPED_ARRAY_CONSTRUCTOR from the RHS, handling binary wrappers. =#
  local constructor = nothing
  local wrapper_op = nothing
  local wrapper_scalar = nothing
  local wrapper_is_lhs = false
  if rhs_exp isa CALL_EXPRESSION && isvariant(rhs_exp.call, TYPED_ARRAY_CONSTRUCTOR)
    constructor = rhs_exp.call
  elseif rhs_exp isa BINARY_EXPRESSION
    local e1 = rhs_exp.exp1
    local e2 = rhs_exp.exp2
    if e1 isa CALL_EXPRESSION && isvariant(e1.call, TYPED_ARRAY_CONSTRUCTOR)
      constructor = e1.call
      wrapper_op = rhs_exp.operator
      wrapper_scalar = e2
      wrapper_is_lhs = false
    elseif e2 isa CALL_EXPRESSION && isvariant(e2.call, TYPED_ARRAY_CONSTRUCTOR)
      constructor = e2.call
      wrapper_op = rhs_exp.operator
      wrapper_scalar = e1
      wrapper_is_lhs = true
    end
  end
  if constructor === nothing
    return nothing
  end
  #= Get LHS elements =#
  local lhs_elements::Vector{Expression}
  if lhs_exp isa ARRAY_EXPRESSION
    lhs_elements = lhs_exp.elements
  else
    try
      local (exp_lhs, _) = expand(lhs_exp)
      if exp_lhs isa ARRAY_EXPRESSION
        lhs_elements = exp_lhs.elements
      else
        return nothing
      end
    catch
      return nothing
    end
  end
  #= Iterate over the constructor's range and substitute =#
  local body = constructor.exp
  local iters = constructor.iters
  if listLength(iters) != 1
    return nothing
  end
  local (iter_node, range_exp) = listHead(iters)
  local range_iter = fromExpToExpressionIterator(range_exp)
  local result_eqs = Equation[]
  local idx = 1
  local elem_ty = arrayElementType(eq.ty)
  while hasNext(range_iter)
    if idx > length(lhs_elements)
      return nothing
    end
    local value::Expression
    (range_iter, value) = next(range_iter)
    local substituted = simplify(replaceIterator(body, iter_node, value))
    #= Re-apply the binary wrapper if present =#
    local rhs_elem = if wrapper_op !== nothing
      if wrapper_is_lhs
        BINARY_EXPRESSION(wrapper_scalar, wrapper_op, substituted)
      else
        BINARY_EXPRESSION(substituted, wrapper_op, wrapper_scalar)
      end
    else
      substituted
    end
    push!(result_eqs, EQUATION_EQUALITY(lhs_elements[idx], rhs_elem, elem_ty, eq.source))
    idx += 1
  end
  if idx - 1 != length(lhs_elements)
    return nothing
  end
  return result_eqs
end

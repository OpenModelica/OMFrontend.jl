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

#= CONNECTION equations as for-equations when not scalarizing.

   The connection sets hold scalar connectors (Connector.split), so the equations generated from them are scalar:
   `r[1].n.v = r[2].p.v`, `r[2].n.v = r[3].p.v`, ... . Equations of one shape, the same but for their literal integer
   subscripts, whose subscripts are affine in one index over a run of members, become one for-equation:
   `for $i1 in 1:3 loop r[$i1].n.v = r[$i1 + 1].p.v; end for;`. The sets, and so the equations' meaning, are the
   scalar ones; only their form changes. =#

"""
Whether `exp` is made of crefs, literals, unary and binary operations only, and its crefs' subscripts are literal
integers, iterators or parameters: an expression of a connection equation that can be rerolled.
"""
function _rerollable(@nospecialize(exp::Expression))::Bool
  if exp isa CREF_EXPRESSION
    return _rerollable(exp.cref)
  elseif exp isa BINARY_EXPRESSION
    return _rerollable(exp.exp1) && _rerollable(exp.exp2)
  elseif exp isa UNARY_EXPRESSION
    return _rerollable(exp.exp)
  end
  return exp isa REAL_EXPRESSION || exp isa INTEGER_EXPRESSION || exp isa BOOLEAN_EXPRESSION
end

function _rerollable(cref::ComponentRef)::Bool
  isvariant(cref, COMPONENT_REF_CREF) || return true
  for s in cref.subscripts
    (s isa SUBSCRIPT_INDEX && (s.index isa INTEGER_EXPRESSION || s.index isa CREF_EXPRESSION)) || return false
  end
  return _rerollable(cref.restCref)
end

"""
The literal integer subscripts of `exp`'s crefs (`_rerollable`), in traversal order, pushed to `vals`. With `subs`
empty, the result is `exp` with each of them replaced by the subscript 0 (the shape of the equation, a key); otherwise
the i-th one is replaced by `subs[i]`.
"""
function _rerollMapExp(@nospecialize(exp::Expression), vals::Vector{Int}, subs::Vector{Subscript})::Expression
  if exp isa CREF_EXPRESSION
    return CREF_EXPRESSION(exp.ty, _rerollMapCref(exp.cref, vals, subs))
  elseif exp isa BINARY_EXPRESSION
    local e1::Expression = _rerollMapExp(exp.exp1, vals, subs)
    return BINARY_EXPRESSION(e1, exp.operator, _rerollMapExp(exp.exp2, vals, subs))
  elseif exp isa UNARY_EXPRESSION
    return UNARY_EXPRESSION(exp.operator, _rerollMapExp(exp.exp, vals, subs))
  end
  return exp
end

"""
`_rerollMapExp` for a cref: its literal integer subscripts, on every part (`r[1].n.v`: the 1 of `r`), collected and
replaced. Iterator and parameter subscripts are kept as part of the shape.
"""
function _rerollMapCref(cref::ComponentRef, vals::Vector{Int}, subs::Vector{Subscript})::ComponentRef
  isvariant(cref, COMPONENT_REF_CREF) || return cref
  local rest::ComponentRef = _rerollMapCref(cref.restCref, vals, subs)
  local newSubs::Vector{Subscript} = Subscript[]
  for s in cref.subscripts
    #= a SUBSCRIPT_INDEX (`_rerollable`); its index field is a type parameter =#
    local idx::Expression = (s::SUBSCRIPT_INDEX).index
    if idx isa INTEGER_EXPRESSION
      push!(vals, Int(idx.value))
      push!(newSubs, isempty(subs) ? SUBSCRIPT_INDEX(INTEGER_EXPRESSION(0)) : subs[length(vals)])
    else
      #= an iterator or a parameter: part of the shape =#
      push!(newSubs, s)
    end
  end
  return COMPONENT_REF_CREF(cref.node, arrayList(newSubs), cref.ty, cref.origin, rest)
end

"""
Whether `exp` is a binary addition.
"""
function _isSum(@nospecialize(exp::Expression))::Bool
  return exp isa BINARY_EXPRESSION && _isAdd(exp.operator)
end

"""Whether `op` is `+`."""
_isAdd(op::OPERATOR)::Bool = op.op == Op.ADD

"""
The terms of a sum (`a + b + c`, nested binary additions).
"""
function _rerollTerms!(terms::Vector{Expression}, @nospecialize(exp::Expression))::Vector{Expression}
  if _isSum(exp)
    _rerollTerms!(terms, exp.exp1)
    _rerollTerms!(terms, exp.exp2)
  else
    push!(terms, exp)
  end
  return terms
end

"""
The key of an expression's shape (its literal subscripts as 0) and its literal subscripts.
"""
function _rerollShape(@nospecialize(exp::Expression))::Tuple{String, Vector{Int}}
  local vals::Vector{Int} = Int[]
  local shape::Expression = _rerollMapExp(exp, vals, Subscript[])
  return (toString(shape), vals)
end

"""
`exp` in a canonical form for rerolling: the terms of a sum ordered by shape, then by subscripts, so that
`r[2].p.i + r[1].n.i` and `r[2].n.i + r[3].p.i` are one shape.
"""
function _rerollCanonical(@nospecialize(exp::Expression))::Expression
  _isSum(exp) || return exp
  local op::OPERATOR = (exp::BINARY_EXPRESSION).operator
  local keyed::Vector{Tuple{String, Vector{Int}, Expression}} = Tuple{String, Vector{Int}, Expression}[]
  for t in _rerollTerms!(Expression[], exp)
    local (key::String, vals::Vector{Int}) = _rerollShape(t)
    push!(keyed, (key, vals, t))
  end
  sort!(keyed; by = k -> (k[1], k[2]))
  local sum::Expression = keyed[1][3]
  for k in 2:length(keyed)
    sum = BINARY_EXPRESSION(sum, op, keyed[k][3])
  end
  return sum
end

"""
Whether `eq` is a scalar equality whose sides are `_rerollable`. (`Equation` is a compacted uniontype: its fields hold
the union of all variants' field types, so an EQUATION_EQUALITY's are asserted.)
"""
function _rerollable(eq::Equation)::Bool
  isvariant(eq, EQUATION_EQUALITY) || return false
  return !isArray(eq.ty::ModelicaType) && _rerollable(eq.lhs::Expression) && _rerollable(eq.rhs::Expression)
end

"""
A scalar equality (`_rerollable`) in canonical form (`_rerollCanonical` sides; for crefs on both sides, the side of
the smaller shape first), its shape key, its literal subscripts and whether its sides were swapped.
"""
function _rerollMember(eq::Equation)::Tuple{Equation, String, Vector{Int}, Bool}
  local lhs::Expression = _rerollCanonical(eq.lhs::Expression)
  local rhs::Expression = _rerollCanonical(eq.rhs::Expression)
  local l::Tuple{String, Vector{Int}} = _rerollShape(lhs)
  local r::Tuple{String, Vector{Int}} = _rerollShape(rhs)
  local swapped::Bool = lhs isa CREF_EXPRESSION && rhs isa CREF_EXPRESSION && (r[1], r[2]) < (l[1], l[2])
  if swapped
    (lhs, rhs, l, r) = (rhs, lhs, r, l)
  end
  local vals::Vector{Int} = vcat(l[2], r[2])
  return (EQUATION_EQUALITY(lhs, rhs, eq.ty::ModelicaType, eq.source), l[1] * " = " * r[1], vals, swapped)
end

"""
The subscript `base + step * (i - 1)` of the iterator `i`.
"""
function _rerollSubscript(iter::Expression, base::Int, step::Int)::Subscript
  step == 0 && return SUBSCRIPT_INDEX(INTEGER_EXPRESSION(base))
  local c::Int = base - step
  local term::Expression = step == 1 ? iter :
    step == -1 ? UNARY_EXPRESSION(makeUMinus(TYPE_INTEGER()), iter) :
    BINARY_EXPRESSION(INTEGER_EXPRESSION(step), makeMul(TYPE_INTEGER()), iter)
  local e::Expression = if c == 0
    term
  elseif step == -1
    BINARY_EXPRESSION(INTEGER_EXPRESSION(c), makeSub(TYPE_INTEGER()), iter)
  elseif c > 0
    BINARY_EXPRESSION(term, makeAdd(TYPE_INTEGER()), INTEGER_EXPRESSION(c))
  else
    BINARY_EXPRESSION(term, makeSub(TYPE_INTEGER()), INTEGER_EXPRESSION(-c))
  end
  return SUBSCRIPT_INDEX(e)
end

"""
The for-equation over `n` members of one shape: `eq` (the first member, canonical) with its i-th literal subscript
`base[i] + step[i] * (\$i1 - 1)`; its sides swapped back when `swapped` (the first member's orientation).
"""
function _rerollLoop(eq::Equation, base::Vector{Int}, step::Vector{Int}, n::Int, swapped::Bool)::Equation
  local iterNode::InstNode = newIndexedIterator(1, TYPE_INTEGER(), eq.source)
  local iter::Expression = CREF_EXPRESSION(TYPE_INTEGER(), makeIterator(iterNode, TYPE_INTEGER()))
  local subs::Vector{Subscript} = Subscript[_rerollSubscript(iter, base[k], step[k]) for k in eachindex(base)]
  local vals::Vector{Int} = Int[]
  local lhs::Expression = _rerollMapExp(eq.lhs::Expression, vals, subs)
  local rhs::Expression = _rerollMapExp(eq.rhs::Expression, vals, subs)
  local ty::ModelicaType = eq.ty::ModelicaType
  local body::Equation = swapped ? EQUATION_EQUALITY(rhs, lhs, ty, eq.source) : EQUATION_EQUALITY(lhs, rhs, ty, eq.source)
  local range::Expression = makeRange(INTEGER_EXPRESSION(1), NONE(), INTEGER_EXPRESSION(n))
  return EQUATION_FOR(iterNode, SOME(range), Equation[body], eq.source)
end

"A member of a group of one shape: the original equation, its canonical form, its literal subscripts, whether its sides were swapped."
const RerollMember = Tuple{Equation, Equation, Vector{Int}, Bool}

"""
    rerollConnectEquations(eqs)

The scalar connection equations `eqs` with each run of members of one shape whose literal subscripts are affine in
the member's position (at least 2 members) as one for-equation. Members are ordered by their subscripts within a
shape; equations not rerolled keep their place and their form. Used when not scalarizing (`FRONTEND_SCALARIZE` off).
"""
function rerollConnectEquations(eqs::Vector{Equation})::Vector{Equation}
  #= the group of each shape key =#
  local groups::Dict{String, Int} = Dict{String, Int}()
  #= the groups in the order of their first member; an equation kept as it is is a group of its own (one member, no
     literal subscripts), so it keeps its place =#
  local members::Vector{Vector{RerollMember}} = Vector{RerollMember}[]
  for eq in eqs
    if !_rerollable(eq)
      push!(members, RerollMember[(eq, eq, Int[], false)])
      continue
    end
    local m::Tuple{Equation, String, Vector{Int}, Bool} = _rerollMember(eq)
    if isempty(m[3])
      push!(members, RerollMember[(eq, eq, Int[], false)])
      continue
    end
    local gi::Int = get(groups, m[2], 0)
    if gi == 0
      push!(members, RerollMember[(eq, m[1], m[3], m[4])])
      groups[m[2]] = length(members)
    else
      push!(members[gi], (eq, m[1], m[3], m[4]))
    end
  end
  local out::Vector{Equation} = Equation[]
  sizehint!(out, length(eqs))
  for group in members
    local ms::Vector{RerollMember} = length(group) == 1 ? group : sort!(group; by = m -> m[3])
    local i::Int = 1
    while i <= length(ms)
      local j::Int = i
      if i < length(ms)
        local d::Vector{Int} = ms[i + 1][3] - ms[i][3]
        if any(!=(0), d)
          j = i + 1
          while j < length(ms) && ms[j + 1][3] - ms[j][3] == d
            j += 1
          end
          push!(out, _rerollLoop(ms[i][2], ms[i][3], d, j - i + 1, ms[i][4]))
        end
      end
      if j == i
        push!(out, ms[i][1])
      end
      i = j + 1
    end
  end
  return out
end

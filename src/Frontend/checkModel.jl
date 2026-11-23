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

#= The equation and variable counts of omc's checkModel (OMCompiler NFFrontEnd/NFCheckModel.mo) for a flat model whose
   dimensions are known (a scalarized model).
   Author: John Tinnerholm =#

"""
    checkModelCounts(flat::FLAT_MODEL) -> (equations, variables)

omc's checkModel counts. Variables: the scalar unknowns (variability discrete or continuous, external objects not
counted). Equations: the scalar equations, the bindings of the unknowns, one per public top-level input, and the
variables each algorithm assigns. (omc's third count, the trivial equations, depends on which array equations stay
unscalarized and is left out.)
"""
function checkModelCounts(flat::FLAT_MODEL)::NTuple{2, Int}
  local sizes::Dict{String, Int} = Dict{String, Int}()
  for v::VARIABLE in flat.variables
    local key::String = checkModelCrefKey(v.name)
    sizes[key] = get(sizes, key, 0) + checkModelTypeSize(v.ty)
  end
  local variables::Int = 0
  local equations::Int = 0
  for v::VARIABLE in flat.variables
    (v.attributes.variability < Variability.DISCRETE || isExternalObject(v.ty)) && continue
    local sz::Int = checkModelTypeSize(v.ty)
    variables += sz
    if checkModelKnownInput(v)
      equations += sz
    else
      equations += checkModelTypeSize(getType(v.binding))
    end
  end
  for eq::Equation in flat.equations
    equations += checkModelEquationSize(eq)
  end
  for alg::ALGORITHM in flat.algorithms
    local assigned::Set{String} = Set{String}()
    for s::Statement in alg.statements
      checkModelAssigned!(assigned, s)
    end
    equations += sum(k -> get(sizes, k, 0), assigned; init = 0)
  end
  return (equations, variables)
end

"""A public top-level input: omc counts it as a variable with an equation (its value comes from outside)."""
function checkModelKnownInput(v::VARIABLE)::Bool
  return v.attributes.direction == Direction.INPUT && v.visibility == Visibility.PUBLIC &&
         !isvariant(v.name.restCref, COMPONENT_REF_CREF)
end

"""
The name of `cref` without the subscripts of its non-model parts, as a key (omc's stripSubscriptsExceptModel: each
model in an array has its own variables).
"""
function checkModelCrefKey(cref::ComponentRef)::String
  local parts::Vector{String} = String[]
  local c::ComponentRef = cref
  while isvariant(c, COMPONENT_REF_CREF)
    local part::String = String(name(c.node))
    if !isempty(c.subscripts) && isModel(c.node)
      part *= "[" * Base.join(String[toString(s) for s in c.subscripts], ",") * "]"
    end
    pushfirst!(parts, part)
    c = c.restCref
  end
  return Base.join(parts, ".")
end

"""The number of scalars of `ty` (omc's Type.sizeOf): records count their fields, external objects 1."""
function checkModelTypeSize(ty::ModelicaType)::Int
  local tag = ty.tag
  (tag == NFT_INTEGER || tag == NFT_REAL || tag == NFT_STRING || tag == NFT_BOOLEAN || tag == NFT_CLOCK ||
   tag == NFT_ENUMERATION) && return 1
  if tag == NFT_ARRAY
    local n::Int = checkModelTypeSize(ty.elementType)
    for d in ty.dimensions
      n *= size(d)
    end
    return n
  end
  tag == NFT_TUPLE && return sum(checkModelTypeSize, ty.types; init = 0)
  if tag == NFT_COMPLEX
    ty.complexTy isa COMPLEX_RECORD || return 1
    return sum(c -> checkModelTypeSize(getType(c)), complexComponents(ty); init = 0)
  end
  return 0
end

"""The scalar size of an equation (omc's Equation.sizeOf): a for-equation its range times its body, an if- or
when-equation its first branch, an assert or reinit nothing."""
function checkModelEquationSize(eq::Equation)::Int
  local tag::EquationTag = eq.tag
  (tag == EQUATION_EQUALITY_TAG || tag == EQUATION_ARRAY_EQUALITY_TAG) && return checkModelTypeSize(typeOf(eq.lhs))
  tag == EQUATION_CREF_EQUALITY_TAG && return checkModelTypeSize(getSubscriptedType(eq.lhs))
  if tag == EQUATION_FOR_TAG
    local body::Int = sum(checkModelEquationSize, eq.body; init = 0)
    return (eq.range === nothing || isNone(eq.range)) ? body : checkModelTypeSize(typeOf(eq.range.value)) * body
  end
  if tag == EQUATION_IF_TAG || tag == EQUATION_WHEN_TAG
    local first = eq.branches[1]
    return first.body === nothing ? 0 : sum(checkModelEquationSize, first.body; init = 0)
  end
  return 0
end

"""Add the names (`checkModelCrefKey`, model subscripts kept) of the variables statement `s` assigns."""
function checkModelAssigned!(assigned::Set{String}, s::Statement)::Nothing
  if s.tag == ALG_ASSIGNMENT_TAG
    checkModelAssignedExp!(assigned, s.lhs)
  elseif s.tag == ALG_FOR_TAG || s.tag == ALG_WHILE_TAG
    foreach(b -> checkModelAssigned!(assigned, b), s.body)
  elseif s.tag == ALG_IF_TAG || s.tag == ALG_WHEN_TAG
    for (_, body) in s.branches
      foreach(b -> checkModelAssigned!(assigned, b), body)
    end
  end
  return nothing
end

"""The assigned variables of the left-hand side `lhs` (a reference or a tuple of them)."""
function checkModelAssignedExp!(assigned::Set{String}, lhs::Expression)::Nothing
  if lhs isa CREF_EXPRESSION
    isIterator(lhs.cref) || push!(assigned, checkModelCrefKey(lhs.cref))
  elseif lhs isa TUPLE_EXPRESSION
    foreach(e -> checkModelAssignedExp!(assigned, e), lhs.elements)
  end
  return nothing
end

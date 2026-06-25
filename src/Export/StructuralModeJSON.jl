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

module StructuralModeJSON

using MetaModelica
using ..Frontend
import JSON
import Absyn

# === ATD-mirroring typed records ===
# These mirror docs/structural_mode_json.atd.

struct VariableExp
  name::String
  type::String
  variability::String
  visibility::String
  highest_differentiation_order::Int
  default::Union{String, Nothing}
  attributes::Union{String, Nothing}
end

struct EquationExp
  id::String
  equation::String
  differentiation_order::Int
  variables_used::Vector{String}
end

struct StructuralClassSummary
  name::String
  highest_differentiation_order::Int
  highest_differentiation_order_variables::Vector{String}
end

struct StructuralComponentSummary
  name::String
  type::String
  n_variables::Int
  n_parameters::Int
  n_equations::Int
end

struct Hierarchy
  model::String
  structural_classes::Vector{StructuralClassSummary}
  structural_components::Vector{StructuralComponentSummary}
  coupling_equations::Vector{String}
  top_level_variables::Vector{String}
end

struct StructuralClass
  name::String
  highest_differentiation_order::Int
  highest_differentiation_order_variables::Vector{String}
  variables::Vector{VariableExp}
  equations::Vector{EquationExp}
end

struct ParameterOverride
  parameter::String
  value::String
end

struct Component
  name::String
  class::String
  parameter_overrides::Vector{ParameterOverride}
end

struct TopLevelSection
  variables::Vector{VariableExp}
  equations::Vector{EquationExp}
end

struct VarEquationMapping
  variable::String
  equation_ids::Vector{String}
end

struct FlatModelExport
  model::String
  structural_classes::Vector{StructuralClass}
  components::Vector{Component}
  top_level::TopLevelSection
  variable_to_equations::Vector{VarEquationMapping}
end

# === Render helpers ===

_crefName(cref) = String(Frontend.toString(cref))

function _stripPrefix(name::String, prefix::String)
  startswith(name, prefix) ? String(name[lastindex(prefix)+1:end]) : name
end

function _variabilityStr(v::Int8)
  if v == Frontend.Variability.PARAMETER ||
     v == Frontend.Variability.CONSTANT ||
     v == Frontend.Variability.STRUCTURAL_PARAMETER ||
     v == Frontend.Variability.NON_STRUCTURAL_PARAMETER
    return "Parameter"
  end
  return "Continuous"
end

_visibilityStr(v::Int8) =
  v == Frontend.Visibility.PROTECTED ? "Protected" : "Public"

_typeStr(ty) = String(Frontend.toFlatString(ty))

function _bindingDefault(binding)
  Frontend.isBound(binding) || return nothing
  return String(Frontend.toFlatString(binding))
end

function _typeAttrString(typeAttrs::Vector)
  isempty(typeAttrs) && return nothing
  parts = String[]
  for (name, b) in typeAttrs
    push!(parts, string(name, " = ", Frontend.toFlatString(b)))
  end
  return join(parts, ", ")
end

function _eqString(eq)::String
  s = String(Frontend.toString(eq))
  s = replace(s, "\\n" => "")
  s = strip(s)
  return endswith(s, ";") ? String(s) : String(s) * ";"
end

# === Expression-AST walkers ===

_pathLastName(p::Absyn.IDENT) = String(p.name)
_pathLastName(p::Absyn.QUALIFIED) = _pathLastName(p.path)
_pathLastName(p::Absyn.FULLYQUALIFIED) = _pathLastName(p.path)

function _callName(call)
  if call isa Frontend.TYPED_CALL
    return _pathLastName(call.fn.path)
  elseif call isa Frontend.UNTYPED_CALL
    return _crefName(call.ref)
  elseif call isa Frontend.ARG_TYPED_CALL
    return _crefName(call.ref)
  end
  return ""
end

function _callArgs(call)
  if call isa Frontend.TYPED_CALL
    return call.arguments
  elseif call isa Frontend.UNTYPED_CALL
    return call.arguments
  elseif call isa Frontend.ARG_TYPED_CALL
    return [a[1] for a in call.arguments]
  end
  return Any[]
end

"""
    _walkExpr!(visit, expr, depth)

Recursively walk an Expression AST. `visit(node, depth)` is called for every
subexpression. `depth` is the current der-nesting depth (incremented inside
`der(...)` calls).
"""
function _walkExpr!(visit, e, depth::Int)
  visit(e, depth)
  if e isa Frontend.CALL_EXPRESSION
    nm = _callName(e.call)
    newDepth = nm == "der" ? depth + 1 : depth
    for a in _callArgs(e.call)
      _walkExpr!(visit, a, newDepth)
    end
  elseif e isa Frontend.BINARY_EXPRESSION ||
         e isa Frontend.LBINARY_EXPRESSION ||
         e isa Frontend.RELATION_EXPRESSION
    _walkExpr!(visit, e.exp1, depth)
    _walkExpr!(visit, e.exp2, depth)
  elseif e isa Frontend.UNARY_EXPRESSION ||
         e isa Frontend.LUNARY_EXPRESSION
    _walkExpr!(visit, e.exp, depth)
  elseif e isa Frontend.IF_EXPRESSION
    _walkExpr!(visit, e.condition, depth)
    _walkExpr!(visit, e.trueBranch, depth)
    _walkExpr!(visit, e.falseBranch, depth)
  elseif e isa Frontend.CAST_EXPRESSION ||
         e isa Frontend.SIZE_EXPRESSION ||
         e isa Frontend.BINDING_EXP ||
         e isa Frontend.BOX_EXPRESSION ||
         e isa Frontend.UNBOX_EXPRESSION
    _walkExpr!(visit, e.exp, depth)
  elseif e isa Frontend.ARRAY_EXPRESSION
    for x in e.elements
      _walkExpr!(visit, x, depth)
    end
  elseif e isa Frontend.TUPLE_EXPRESSION
    for x in e.elements
      _walkExpr!(visit, x, depth)
    end
  elseif e isa Frontend.RANGE_EXPRESSION
    _walkExpr!(visit, e.start, depth)
    if e.step isa Some
      _walkExpr!(visit, e.step.value, depth)
    end
    _walkExpr!(visit, e.stop, depth)
  elseif e isa Frontend.RECORD_EXPRESSION
    for x in e.elements
      _walkExpr!(visit, x, depth)
    end
  end
end

"""Yield (lhs, rhs) Expressions for an equation if it is a simple equality form."""
function _equalityExpressions(eq)
  if eq isa Frontend.EQUATION_EQUALITY
    return (eq.lhs, eq.rhs)
  elseif eq isa Frontend.EQUATION_ARRAY_EQUALITY
    return (eq.lhs, eq.rhs)
  end
  return nothing
end

"""Maximum der-depth across an equation's expressions."""
function _eqDerDepth(eq)::Int
  pair = _equalityExpressions(eq)
  if pair === nothing
    return 0
  end
  maxD = Ref(0)
  for ex in pair
    _walkExpr!(ex, 0) do node, depth
      if node isa Frontend.CALL_EXPRESSION && _callName(node.call) == "der"
        maxD[] = max(maxD[], depth + 1)
      end
    end
  end
  return maxD[]
end

"""Variable names referenced inside an equation (cref names, fully qualified)."""
function _eqCrefs(eq)::Vector{String}
  out = String[]
  seen = Set{String}()
  function add(name::String)
    if !(name in seen)
      push!(seen, name)
      push!(out, name)
    end
  end
  pair = _equalityExpressions(eq)
  if pair !== nothing
    for ex in pair
      _walkExpr!(ex, 0) do node, _
        if node isa Frontend.CREF_EXPRESSION
          add(_crefName(node.cref))
        end
      end
    end
  elseif eq isa Frontend.EQUATION_CREF_EQUALITY
    add(_crefName(eq.lhs))
    add(_crefName(eq.rhs))
  end
  return out
end

"""For each variable name, its highest der-depth observed across equations."""
function _derPerVar(eqs)::Dict{String,Int}
  d = Dict{String,Int}()
  for eq in eqs
    pair = _equalityExpressions(eq)
    pair === nothing && continue
    for ex in pair
      _walkExpr!(ex, 0) do node, depth
        if node isa Frontend.CREF_EXPRESSION && depth > 0
          name = _crefName(node.cref)
          d[name] = max(get(d, name, 0), depth)
        end
      end
    end
  end
  return d
end

# === Submodel walk (one structural component) ===

"""Build typed Variable/Equation records for one structural-mode submodel.
Returns a NamedTuple {instance_name, variables, equations}."""
function _buildSubmodel(fm::Frontend.FLAT_MODEL)
  instName = fm.name
  prefix = instName * "."
  eqs = fm.equations
  derMap = _derPerVar(eqs)

  vars = VariableExp[]
  for v in fm.variables
    fullName = _crefName(v.name)
    localName = _stripPrefix(fullName, prefix)
    diffOrder = get(derMap, fullName, 0)
    push!(vars, VariableExp(
      localName,
      _typeStr(v.ty),
      _variabilityStr(v.attributes.variability),
      _visibilityStr(v.visibility),
      diffOrder,
      _bindingDefault(v.binding),
      _typeAttrString(v.typeAttributes),
    ))
  end

  equations = EquationExp[]
  for (i, eq) in enumerate(eqs)
    eqStr = _eqString(eq)
    eqStr = replace(eqStr, prefix => "")
    crefs = [_stripPrefix(c, prefix) for c in _eqCrefs(eq)]
    push!(equations, EquationExp(
      string("eq", i),
      eqStr,
      _eqDerDepth(eq),
      crefs,
    ))
  end

  return (instance_name = instName, variables = vars, equations = equations)
end

# === Fingerprinting and class deduplication ===

function _variableSig(v::VariableExp)
  return string(v.variability, "_", v.visibility, "_", v.type, "_", v.name)
end

function _fingerprint(submodel)::String
  varSigs = sort([_variableSig(v) for v in submodel.variables])
  eqStrs = sort([eq.equation for eq in submodel.equations])
  return string(join(varSigs, "|"), "||", join(eqStrs, "|"))
end

function _classMaxDerOrder(vars::Vector{VariableExp})
  maxOrder = 0
  highVars = String[]
  for v in vars
    if v.highest_differentiation_order > maxOrder
      maxOrder = v.highest_differentiation_order
      highVars = String[v.name]
    elseif v.highest_differentiation_order == maxOrder && maxOrder > 0
      push!(highVars, v.name)
    end
  end
  sort!(highVars)
  return (maxOrder, highVars)
end

# === Top-level FlatModel walk ===

function _collectStructuralSubmodels(fm::Frontend.FLAT_MODEL)
  subs = []
  for sm in fm.structuralSubmodels
    push!(subs, _buildSubmodel(sm))
  end
  return subs
end

function _topLevelVariables(fm::Frontend.FLAT_MODEL)::Vector{VariableExp}
  isempty(fm.variables) && return VariableExp[]
  derMap = _derPerVar(fm.equations)
  out = VariableExp[]
  for v in fm.variables
    fullName = _crefName(v.name)
    diffOrder = get(derMap, fullName, 0)
    push!(out, VariableExp(
      fullName,
      _typeStr(v.ty),
      _variabilityStr(v.attributes.variability),
      _visibilityStr(v.visibility),
      diffOrder,
      _bindingDefault(v.binding),
      _typeAttrString(v.typeAttributes),
    ))
  end
  return out
end

function _topLevelEquations(fm::Frontend.FLAT_MODEL)::Vector{EquationExp}
  out = EquationExp[]
  for (i, eq) in enumerate(fm.equations)
    push!(out, EquationExp(
      string("top.eq", i),
      _eqString(eq),
      _eqDerDepth(eq),
      _eqCrefs(eq),
    ))
  end
  return out
end

# === Building the typed exports ===

function _buildClassMapping(submodels, userMapping::Union{Dict{String,String}, Nothing})
  fpGroups = Dict{String,Vector{Int}}()
  for (i, sm) in enumerate(submodels)
    fp = _fingerprint(sm)
    push!(get!(fpGroups, fp, Int[]), i)
  end
  classNameFor = Dict{Int,String}()
  classByFp = Dict{String,String}()
  for (fp, idxs) in fpGroups
    firstName = submodels[idxs[1]].instance_name
    nm = if userMapping !== nothing && haskey(userMapping, firstName)
      userMapping[firstName]
    else
      uppercasefirst(firstName)
    end
    classByFp[fp] = nm
    for i in idxs
      classNameFor[i] = nm
    end
  end
  return (groups = fpGroups, classByFp = classByFp, classNameFor = classNameFor)
end

function _buildHierarchy(fm::Frontend.FLAT_MODEL, submodels, mapping)::Hierarchy
  classes = StructuralClassSummary[]
  seenClasses = Set{String}()
  for (fp, idxs) in mapping.groups
    className = mapping.classByFp[fp]
    rep = submodels[idxs[1]]
    (maxOrd, highVars) = _classMaxDerOrder(rep.variables)
    if !(className in seenClasses)
      push!(seenClasses, className)
      push!(classes, StructuralClassSummary(className, maxOrd, highVars))
    end
  end
  components = StructuralComponentSummary[]
  for (i, sm) in enumerate(submodels)
    nParams = count(v -> v.variability == "Parameter", sm.variables)
    nVars = length(sm.variables) - nParams
    push!(components, StructuralComponentSummary(
      sm.instance_name,
      mapping.classNameFor[i],
      nVars,
      nParams,
      length(sm.equations),
    ))
  end
  couplingEqs = String[_eqString(eq) for eq in fm.equations]
  topVarNames = String[_crefName(v.name) for v in fm.variables]
  return Hierarchy(fm.name, classes, components, couplingEqs, topVarNames)
end

function _buildParameterOverrides(rep, comp)
  repDefaults = Dict{String,String}()
  for v in rep.variables
    if v.variability == "Parameter" && v.default !== nothing
      repDefaults[v.name] = v.default
    end
  end
  overrides = ParameterOverride[]
  for v in comp.variables
    if v.variability == "Parameter" && v.default !== nothing
      td = get(repDefaults, v.name, nothing)
      if td !== nothing && v.default != td
        push!(overrides, ParameterOverride(v.name, v.default))
      end
    end
  end
  return overrides
end

function _buildFlatModelExport(fm::Frontend.FLAT_MODEL, submodels, mapping)::FlatModelExport
  classes = StructuralClass[]
  seenClasses = Set{String}()
  for (fp, idxs) in mapping.groups
    className = mapping.classByFp[fp]
    className in seenClasses && continue
    push!(seenClasses, className)
    rep = submodels[idxs[1]]
    (maxOrd, highVars) = _classMaxDerOrder(rep.variables)
    push!(classes, StructuralClass(
      className, maxOrd, highVars, rep.variables, rep.equations,
    ))
  end
  components = Component[]
  for (i, sm) in enumerate(submodels)
    className = mapping.classNameFor[i]
    fp = _fingerprint(sm)
    rep = submodels[mapping.groups[fp][1]]
    overrides = _buildParameterOverrides(rep, sm)
    push!(components, Component(sm.instance_name, className, overrides))
  end
  topVars = _topLevelVariables(fm)
  topEqs = _topLevelEquations(fm)
  topSection = TopLevelSection(topVars, topEqs)
  varToEqs = _buildVarToEqs(submodels, topEqs)
  return FlatModelExport(fm.name, classes, components, topSection, varToEqs)
end

function _buildVarToEqs(submodels, topEqs::Vector{EquationExp})
  varToEqs = Dict{String,Vector{String}}()
  for sm in submodels
    prefix = sm.instance_name * "."
    knownVars = Set{String}(string(prefix, v.name) for v in sm.variables)
    for (i, eq) in enumerate(sm.equations)
      eqId = string(prefix, "eq", i)
      for cref in eq.variables_used
        fullName = string(prefix, cref)
        if fullName in knownVars
          push!(get!(varToEqs, fullName, String[]), eqId)
        end
      end
    end
  end
  for eq in topEqs
    for vname in eq.variables_used
      push!(get!(varToEqs, vname, String[]), eq.id)
    end
  end
  result = VarEquationMapping[]
  for vname in sort(collect(keys(varToEqs)))
    push!(result, VarEquationMapping(vname, varToEqs[vname]))
  end
  return result
end

# === Dict rendering (ATD shorthand: ? omitted when nothing, ~ omitted when empty) ===

_toDict(::Nothing) = nothing
_toDict(s::String) = s
_toDict(n::Number) = n
_toDict(b::Bool) = b
_toDict(v::Vector) = Any[_toDict(x) for x in v]

function _toDict(v::VariableExp)
  d = Dict{String,Any}(
    "name" => v.name,
    "type" => v.type,
    "variability" => v.variability,
    "visibility" => v.visibility,
    "highest_differentiation_order" => v.highest_differentiation_order,
  )
  if v.default !== nothing
    d["default"] = v.default
  end
  if v.attributes !== nothing
    d["attributes"] = v.attributes
  end
  return d
end

function _toDict(e::EquationExp)
  return Dict{String,Any}(
    "id" => e.id,
    "equation" => e.equation,
    "differentiation_order" => e.differentiation_order,
    "variables_used" => e.variables_used,
  )
end

function _toDict(s::StructuralClassSummary)
  return Dict{String,Any}(
    "name" => s.name,
    "highest_differentiation_order" => s.highest_differentiation_order,
    "highest_differentiation_order_variables" => s.highest_differentiation_order_variables,
  )
end

function _toDict(c::StructuralComponentSummary)
  return Dict{String,Any}(
    "name" => c.name,
    "type" => c.type,
    "n_variables" => c.n_variables,
    "n_parameters" => c.n_parameters,
    "n_equations" => c.n_equations,
  )
end

function _toDict(h::Hierarchy)
  d = Dict{String,Any}(
    "model" => h.model,
    "structural_classes" => Any[_toDict(c) for c in h.structural_classes],
    "structural_components" => Any[_toDict(c) for c in h.structural_components],
    "coupling_equations" => h.coupling_equations,
  )
  if !isempty(h.top_level_variables)
    d["top_level_variables"] = h.top_level_variables
  end
  return d
end

function _toDict(c::StructuralClass)
  return Dict{String,Any}(
    "name" => c.name,
    "highest_differentiation_order" => c.highest_differentiation_order,
    "highest_differentiation_order_variables" => c.highest_differentiation_order_variables,
    "variables" => Any[_toDict(v) for v in c.variables],
    "equations" => Any[_toDict(e) for e in c.equations],
  )
end

function _toDict(p::ParameterOverride)
  return Dict{String,Any}("parameter" => p.parameter, "value" => p.value)
end

function _toDict(c::Component)
  d = Dict{String,Any}("name" => c.name, "class" => c.class)
  if !isempty(c.parameter_overrides)
    d["parameter_overrides"] = Any[_toDict(o) for o in c.parameter_overrides]
  end
  return d
end

function _toDict(t::TopLevelSection)
  return Dict{String,Any}(
    "variables" => Any[_toDict(v) for v in t.variables],
    "equations" => Any[_toDict(e) for e in t.equations],
  )
end

function _toDict(m::VarEquationMapping)
  return Dict{String,Any}("variable" => m.variable, "equation_ids" => m.equation_ids)
end

function _toDict(f::FlatModelExport)
  return Dict{String,Any}(
    "model" => f.model,
    "structural_classes" => Any[_toDict(c) for c in f.structural_classes],
    "components" => Any[_toDict(c) for c in f.components],
    "top_level" => _toDict(f.top_level),
    "variable_to_equations" => Any[_toDict(m) for m in f.variable_to_equations],
  )
end

# === Public API ===

#= Canonical OCaml ATD schema for the exported JSON. Single source of truth;
   docs/structural_mode_json.atd is generated from this. =#
const ATD_SCHEMA = """
(* ATD type definitions for flat Modelica model JSON export.
   These types define the schema for both the hierarchy and flat model JSON
   produced by `OMFrontend.exportJSON`. *)

(* -- Shared types -- *)

type variability = [
  | Parameter
  | Continuous
]

type visibility = [
  | Public
  | Protected
]

type variable = {
  name: string;
  type_name <json name="type">: string;
  variability: variability;
  visibility: visibility;
  highest_differentiation_order: int;
  ?default_value <json name="default">: string option;
  ?attributes: string option;
}

type equation = {
  id: string;
  equation: string;
  differentiation_order: int;
  variables_used: string list;
}

(* -- Hierarchy JSON -- *)

type structural_class_summary = {
  name: string;
  highest_differentiation_order: int;
  highest_differentiation_order_variables: string list;
}

type structural_component = {
  name: string;
  type_name <json name="type">: string;
  n_variables: int;
  n_parameters: int;
  n_equations: int;
}

type hierarchy = {
  model: string;
  structural_classes: structural_class_summary list;
  structural_components: structural_component list;
  coupling_equations: string list;
  ~top_level_variables: string list;
}

(* -- Flat model JSON -- *)

type structural_class = {
  name: string;
  highest_differentiation_order: int;
  highest_differentiation_order_variables: string list;
  variables: variable list;
  equations: equation list;
}

type parameter_override = {
  parameter: string;
  value: string;
}

type component = {
  name: string;
  class_name <json name="class">: string;
  ~parameter_overrides: parameter_override list;
}

type top_level_section = {
  ~variables: variable list;
  ~equations: equation list;
}

type var_equation_mapping = {
  variable: string;
  equation_ids: string list;
}

type flat_model = {
  model: string;
  structural_classes: structural_class list;
  components: component list;
  top_level: top_level_section;
  variable_to_equations: var_equation_mapping list;
}
"""

"""
    exportATD(; output_dir=".", base_name="structural_mode_json") -> String

Write the canonical OCaml ATD schema (`ATD_SCHEMA`) for the exported JSON to
`<output_dir>/<base_name>.atd` and return the written path. The schema is
model-independent.
"""
function exportATD(; output_dir::AbstractString = ".",
                     base_name::AbstractString = "structural_mode_json")
  mkpath(output_dir)
  path = joinpath(output_dir, base_name * ".atd")
  open(path, "w") do io
    write(io, ATD_SCHEMA)
  end
  return path
end

"""
    exportJSON(FM; output_dir=".", base_name, hierarchy=true, flat=true,
               class_mapping=nothing, atd=false) -> NamedTuple

Walk a FlatModel and write `<base_name>_hierarchy.json` and/or `<base_name>_flat.json`.
Structural-mode components (in `FM.structuralSubmodels`) are deduplicated into
class templates with per-instance parameter overrides.

`class_mapping` optionally provides a `Dict{String,String}` from instance name
to class name (e.g. `Dict("p1" => "Pendulum")`). When not provided, the class
name defaults to the uppercase-first form of the first instance in each fingerprint group.

Returns a `NamedTuple{(:hierarchy_path, :flat_path, :atd_path)}`. Each entry is the
written file path, or `nothing` when the corresponding keyword was `false`. Pass
`atd=true` to also write `<base_name>.atd` (the schema in `ATD_SCHEMA`).
"""
function exportJSON(fmOrTuple;
                             output_dir::AbstractString = ".",
                             base_name::AbstractString = "",
                             hierarchy::Bool = true,
                             flat::Bool = true,
                             class_mapping::Union{Dict{String,String}, Nothing} = nothing,
                             atd::Bool = false)
  fm = fmOrTuple isa Frontend.FLAT_MODEL ? fmOrTuple : first(fmOrTuple)
  isempty(base_name) && (base_name = fm.name)
  mkpath(output_dir)
  submodels = _collectStructuralSubmodels(fm)
  mapping = _buildClassMapping(submodels, class_mapping)
  hierPath = nothing
  flatPath = nothing
  atdPath = nothing
  if hierarchy
    h = _buildHierarchy(fm, submodels, mapping)
    hierPath = joinpath(output_dir, base_name * "_hierarchy.json")
    open(hierPath, "w") do io
      JSON.print(io, _toDict(h), 2)
    end
  end
  if flat
    f = _buildFlatModelExport(fm, submodels, mapping)
    flatPath = joinpath(output_dir, base_name * "_flat.json")
    open(flatPath, "w") do io
      JSON.print(io, _toDict(f), 2)
    end
  end
  if atd
    atdPath = exportATD(output_dir = output_dir, base_name = base_name)
  end
  return (hierarchy_path = hierPath, flat_path = flatPath, atd_path = atdPath)
end

end # module StructuralModeJSON

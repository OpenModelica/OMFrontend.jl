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

#= The icon of a component's class as Modelica text: what a tool needs to draw a replacement of the component (a
   surrogate) like the original. From the SCode annotations: the class's Icon and its base classes', and the
   Placement of each of the component's connectors. =#

"""The parts of a component reference, outermost first."""
function componentGraphicsCrefParts(cref::Frontend.ComponentRef)::Vector{Frontend.ComponentRef}
  local parts::Vector{Frontend.ComponentRef} = Frontend.ComponentRef[]
  local c::Frontend.ComponentRef = cref
  while Frontend.isvariant(c, Frontend.COMPONENT_REF_CREF)
    pushfirst!(parts, c)
    c = c.restCref
  end
  return parts
end

"""
    componentGraphics(fm, component) -> (; coordinateSystem, items, placements)

The icon of the class of `component` (its name in the flat model `fm`: `"spring"`, `"engine.damper"`) as Modelica
text, to draw a replacement like it: `coordinateSystem` (`"coordinateSystem(...)"`, or empty), `items` (the graphic
items, its base classes' first, as tools draw them) and `placements` (each of the component's connectors =>
its `"Placement(...)"` annotation, declared in the class or a base class). An error if `fm` has no component of that
name.
"""
function componentGraphics(fm::Frontend.FlatModel, component::String)::NamedTuple
  local depth::Int = count(==('.'), component) + 1
  local cls::Union{Nothing, Frontend.InstNode} = nothing
  local connectors::Vector{String} = String[]
  for v in fm.variables
    startswith(Frontend.toString(v.name), component * ".") || continue
    local parts::Vector{Frontend.ComponentRef} = componentGraphicsCrefParts(v.name)
    length(parts) > depth || continue
    cls === nothing && (cls = Frontend.classInstance(Frontend.component(parts[depth].node)))
    local conn::Frontend.InstNode = parts[depth + 1].node
    if Frontend.isConnector(Frontend.component(conn))
      local name::String = String(Frontend.name(conn))
      name in connectors || push!(connectors, name)
    end
  end
  cls === nothing && throw(ArgumentError("$(fm.name) has no component $component"))
  return classGraphics(cls, connectors)
end

"""
    classGraphics(cls, connectors) -> (; coordinateSystem, items, placements)

The icon of the class node `cls` as Modelica text ([`componentGraphics`](@ref)): its coordinate system, its graphic
items with its base classes' first, and the Placement annotations of the `connectors` it or a base class declares.
"""
function classGraphics(cls::Frontend.InstNode, connectors::Vector{String})::NamedTuple
  local items::Vector{String} = String[]
  local coordinateSystem::String = ""
  local placements::Dict{String, String} = Dict{String, String}()
  local visit!(node::Frontend.InstNode, depth::Int)::Nothing = begin
    depth > 32 && return nothing                                    # a cycle would be an error of the library
    local def::SCode.Element = Frontend.definition(node)
    def isa SCode.CLASS || return nothing
    local scope::Frontend.InstNode = Frontend.parent(node)
    local cd::SCode.ClassDef = def.classDef
    if cd isa SCode.PARTS
      for el in cd.elementLst
        if el isa SCode.EXTENDS
          visit!(Frontend.lookupClassName(el.baseClassPath, scope, el.info), depth + 1)
        elseif el isa SCode.COMPONENT && el.name in connectors && !haskey(placements, el.name)
          local p::SCode.Mod = classGraphicsAnnotation(el.comment, "Placement")
          p isa SCode.MOD && (placements[el.name] = "Placement" * Frontend.SCodeDump.printModStr(p))
        end
      end
    elseif cd isa SCode.DERIVED && cd.typeSpec isa Absyn.TPATH
      visit!(Frontend.lookupClassName(cd.typeSpec.path, scope, def.info), depth + 1)
    end
    local icon::SCode.Mod = classGraphicsAnnotation(def.cmt, "Icon")
    icon isa SCode.MOD || return nothing
    for sm in icon.subModLst
      if sm.ident == "coordinateSystem"
        coordinateSystem = "coordinateSystem" * Frontend.SCodeDump.printModStr(sm.mod)   # the most derived class's
      elseif sm.ident == "graphics" && sm.mod isa SCode.MOD && isSome(sm.mod.binding) && sm.mod.binding.data isa Absyn.ARRAY
        append!(items, String[Frontend.AbsynUtil.printExp(x) for x in sm.mod.binding.data.arrayExp])
      end
    end
    return nothing
  end
  visit!(cls, 0)
  return (coordinateSystem = coordinateSystem, items = items, placements = placements)
end

"""The annotation `name` (`Icon`, `Placement`) of an SCode comment, or `SCode.NOMOD()`."""
function classGraphicsAnnotation(cmt::SCode.Comment, name::String)::SCode.Mod
  local ann::Option{SCode.Annotation} = cmt.annotation_
  return isSome(ann) ? Frontend.SCodeUtil.lookupAnnotation(ann.data, name) : SCode.NOMOD()
end

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

@Uniontype NFVariable begin
  @Record VARIABLE begin
    name::ComponentRef
    ty::NFType
    binding::Binding
    visibility::VisibilityType
    attributes::Attributes
    typeAttributes::Vector{Tuple{String, Binding}}
    comment::Option{SCode.Comment}
    info::SourceInfo
  end
end
const Variable = NFVariable

function toFlatStream(var::Variable,
  indent::String = "",
  printBindingType::Bool = false,
  s = Nothing,
)
  local first::Bool
  local b::Binding
  local var_dims::Int
  local binding_dims::Int
  s = IOStream_M.append(s, indent)
  if var.visibility == Visibility.PROTECTED
    s = IOStream_M.append(s, "protected ")
  else
    s = IOStream_M.append(s, "public ")
  end
  s = IOStream_M.append(s, toFlatString(var.attributes, var.ty; isTopLevel = isSimple(var.name)))
  if !Flags.isSet(Flags.NF_SCALARIZE) && isArray(var.ty)
    #= Not scalarizing: Real 'r.p.v'[3] (omc), the dimensions after the name. =#
    s = IOStream_M.append(s, toFlatString(arrayElementType(var.ty)))
    s = IOStream_M.append(s, " ")
    s = IOStream_M.append(s, toFlatString(var.name))
    s = IOStream_M.append(s, "[" * stringDelimitList(list(toFlatString(d) for d in arrayDims(var.ty)), ", ") * "]")
  else
    s = IOStream_M.append(s, toFlatString(var.ty))
    s = IOStream_M.append(s, " ")
    s = IOStream_M.append(s, toFlatString(var.name))
  end
  if !isempty(var.typeAttributes)
    s = IOStream_M.append(s, "(")
    first = true
    var_dims = dimensionCount(var.ty)
    for a in var.typeAttributes
      if first
        first = false
      else
        s = IOStream_M.append(s, ", ")
      end
      b = Util.tuple22(a)
      binding_dims =
        dimensionCount(typeOf(getBindingExp(getExp(
          b,
        ))))
      if var_dims > binding_dims
        s = IOStream_M.append(s, "each ")
      end
      s = IOStream_M.append(s, Util.tuple21(a))
      s = IOStream_M.append(s, " = ")
      s = IOStream_M.append(s, toFlatString(b))
    end
    s = IOStream_M.append(s, ")")
  end
  if isBound(var.binding)
    s = IOStream_M.append(s, " = ")
    if printBindingType
      s = IOStream_M.append(s, "(")
      s = IOStream_M.append(s, toFlatString(getType(var.binding)))
      s = IOStream_M.append(s, ") ")
    end
    s = IOStream_M.append(s, toFlatString(var.binding))
  end
  return s
end

function toStream(
  var::Variable,
  indent::String = "",
  printBindingType::Bool = false,
  s = Nothing,
  )
  local first::Bool
  local b::Binding
  s = IOStream_M.append(s, indent)
  if var.visibility == Visibility.PROTECTED
    s = IOStream_M.append(s, "protected ")
  end
  s = IOStream_M.append(s, toString(var.attributes, var.ty))
  s = IOStream_M.append(s, toString(var.ty))
  s = IOStream_M.append(s, " ")
  s = IOStream_M.append(s, toString(var.name))
  if !isempty(var.typeAttributes)
    s = IOStream_M.append(s, "(")
    first = true
    for a in var.typeAttributes
      if first
        first = false
      else
        s = IOStream_M.append(s, ", ")
      end
      b = Util.tuple22(a)
      if isEach(b)
        s = IOStream_M.append(s, "each ")
      end
      s = IOStream_M.append(s, Util.tuple21(a))
      s = IOStream_M.append(s, " = ")
      s = IOStream_M.append(s, toString(b))
    end
    s = IOStream_M.append(s, ")")
  end
  if isBound(var.binding)
    @assign s = IOStream_M.append(s, " = ")
    if printBindingType
      @assign s = IOStream_M.append(s, "(")
      @assign s = IOStream_M.append(s, toString(getType(var.binding)))
      @assign s = IOStream_M.append(s, ") ")
    end
    @assign s = IOStream_M.append(s, toString(var.binding))
  end
  return s
end

function toString(
  var::Variable,
  indent::String = "",
  printBindingType::Bool = false,
)::String
  local str::String
  local s  = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  s = toStream(var, indent, printBindingType, s)
  str = IOStream_M.string(s)
  return str
end

function lookupTypeAttribute(name::String, var::Variable)::Binding
  local binding::Binding
  for attr in var.typeAttributes
    if Util.tuple21(attr) == name
      binding = Util.tuple22(attr)
      return binding
    end
  end
  binding = EMPTY_BINDING
  return binding
end

function isPresent(variable::Variable)::Bool
  local present::Bool =
    !isPotentiallyPresent(variable.attributes.connectorType)
  return present
end

function isDeleted(variable::Variable)::Bool
  local deleted::Bool
  local node::InstNode
  @assign node = node(variable.name)
  @assign deleted =
    isComponent(node) && isDeleted(component(node))
  return deleted
end

function isEmptyArray(variable::Variable)::Bool
  local isEmpty::Bool = isEmptyArray(variable.ty)
  return isEmpty
end

function variability(variable::Variable)
  return variable.attributes.variability
end

function isStructural(variable::Variable)::Bool
  local structural::Bool =
    variable.attributes.variability <= Variability.STRUCTURAL_PARAMETER
  return structural
end

function Variable_fromCref(cref::ComponentRef)::Variable
  local variable::Variable
  local nodeVar::InstNode
  local comp::Component
  local ty::M_Type
  local binding::Binding
  local vis::VisibilityType
  local attr::Attributes
  local cmt::Option{SCode.Comment}
  local infoVar::SourceInfo
  nodeVar = node(cref)
  comp = component(nodeVar)
  ty = getSubscriptedType(cref)
  binding = getBinding(comp)
  vis = visibility(nodeVar)
  attr = getAttributes(comp)
  cmt = comment(comp)
  infoVar = InstNode_info(nodeVar)
  variable = VARIABLE(cref, ty, binding, vis, attr, Tuple{String, Binding}[], cmt, infoVar)
  return variable
end

function Variable_fromCrefNoBinding(cref::ComponentRef)::Variable
  local variable::Variable
  local nodeVar::InstNode
  local comp::Component
  local ty::M_Type
  local binding::Binding
  local vis::VisibilityType
  local attr::Attributes
  local cmt::Option{SCode.Comment}
  local infoVar::SourceInfo
  nodeVar = node(cref)
  comp = component(nodeVar)
  ty = getSubscriptedType(cref)
  binding = getBinding(comp)
  vis = visibility(nodeVar)
  attr = getAttributes(comp)
  cmt = comment(comp)
  infoVar = InstNode_info(nodeVar)
  variable = VARIABLE(cref, ty, EMPTY_BINDING, vis, attr, Tuple{String, Binding}[], cmt, infoVar)
  return variable
end

function toFlatString(var::Variable; ident = "")
  local s = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  s = toFlatStream(var, ident, false, s)
  return IOStream_M.string(s)
end


Base.:(==)(a::Variable, b::Variable) = toString(a) == toString(b)

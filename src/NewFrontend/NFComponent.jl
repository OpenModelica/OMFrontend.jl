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

using MetaModelica
using ExportAll

abstract type Attributes end

"""
  Mutable variant of attributes.
  The default attribute is using the immutable struct below.
"""
mutable struct ATTRIBUTES <: Attributes
  connectorType::Int8
  parallelism::Int8
  variability::Int8
  direction::Int8
  innerOuter::Int8
  isFinal::Bool
  isRedeclare::Bool
  isReplaceable::Replaceable
  isStructuralMode::Bool
end

#= Investigate how we can make the attributes mutable and the immutable mutable=#

struct IMMUTABLE_ATTRIBUTES <: Attributes
  connectorType::Int8
  parallelism::Int8
  variability::Int8
  direction::Int8
  innerOuter::Int8
  isFinal::Bool
  isRedeclare::Bool
  isReplaceable::Replaceable
  isStructuralMode::Bool
end

#= Component is an abstract supertype with a SINGLE concrete tagged struct
   (ComponentImpl). Keeping the abstract type lets `::Component` fields (e.g.
   InstNode.component) forward-reference it without the NFType<->InstNode<->Component
   concrete cycle, while collapsing the 8 old variants into one concrete struct so
   the compiler devirtualizes `::Component` (one subtype) and @match tag-dispatches.
   Variants are field-disjoint, so this is hand-written (as with InstNode/NFType). =#
abstract type Component end

@enum ComponentTag::UInt8 CT_EMPTY CT_DELETED CT_ENUM_LITERAL CT_ITERATOR CT_TYPE_ATTRIBUTE CT_TYPED CT_UNTYPED CT_DEF

struct ComponentImpl <: Component
  tag::ComponentTag
  component::Union{Component,Nothing}
  literal::Union{Expression,Nothing}
  ty::Union{M_Type,Nothing}
  variability::Int8
  info::Union{SourceInfo,Nothing}
  modifier::Union{Modifier,Nothing}
  classInst::Union{InstNode,Nothing}
  binding::Union{Binding,Nothing}
  condition::Union{Binding,Nothing}
  attributes::Union{Attributes,Nothing}
  ann::Union{Option{Modifier},Nothing}
  comment::Union{Option{SCode.Comment},Nothing}
  dimensions::Union{Vector{Dimension},Nothing}
  instantiated::Bool
  definition::Union{SCode.Element,Nothing}
end

@inline _comp(tag::ComponentTag; component=nothing, literal=nothing, ty=nothing,
  variability::Int8=Int8(0), info=nothing, modifier=nothing, classInst=nothing,
  binding=nothing, condition=nothing, attributes=nothing, ann=nothing,
  comment=nothing, dimensions=nothing, instantiated::Bool=false, definition=nothing) =
  ComponentImpl(tag, component, literal, ty, variability, info, modifier, classInst,
    binding, condition, attributes, ann, comment, dimensions, instantiated, definition)

EMPTY_COMPONENT() = _comp(CT_EMPTY)
DELETED_COMPONENT(component) = _comp(CT_DELETED; component)
ENUM_LITERAL_COMPONENT(literal) = _comp(CT_ENUM_LITERAL; literal)
ITERATOR_COMPONENT(ty, variability, info) = _comp(CT_ITERATOR; ty, variability=Int8(variability), info)
TYPE_ATTRIBUTE(ty, modifier) = _comp(CT_TYPE_ATTRIBUTE; ty, modifier)
TYPED_COMPONENT(classInst, ty, binding, condition, attributes, ann, comment, info) =
  _comp(CT_TYPED; classInst, ty, binding, condition, attributes, ann, comment, info)
UNTYPED_COMPONENT(classInst, dimensions, binding, condition, attributes, comment, instantiated, info) =
  _comp(CT_UNTYPED; classInst, dimensions, binding, condition, attributes, comment, instantiated, info)
COMPONENT_DEF(definition, modifier) = _comp(CT_DEF; definition, modifier)

# @match / isvariant support: one concrete struct discriminated by tag.
MetaModelica.compacted_tag_info(::typeof(EMPTY_COMPONENT))        = (ComponentImpl, :tag, CT_EMPTY, ())
MetaModelica.compacted_tag_info(::typeof(DELETED_COMPONENT))      = (ComponentImpl, :tag, CT_DELETED, (:component,))
MetaModelica.compacted_tag_info(::typeof(ENUM_LITERAL_COMPONENT)) = (ComponentImpl, :tag, CT_ENUM_LITERAL, (:literal,))
MetaModelica.compacted_tag_info(::typeof(ITERATOR_COMPONENT))     = (ComponentImpl, :tag, CT_ITERATOR, (:ty, :variability, :info))
MetaModelica.compacted_tag_info(::typeof(TYPE_ATTRIBUTE))         = (ComponentImpl, :tag, CT_TYPE_ATTRIBUTE, (:ty, :modifier))
MetaModelica.compacted_tag_info(::typeof(TYPED_COMPONENT))        = (ComponentImpl, :tag, CT_TYPED, (:classInst, :ty, :binding, :condition, :attributes, :ann, :comment, :info))
MetaModelica.compacted_tag_info(::typeof(UNTYPED_COMPONENT))      = (ComponentImpl, :tag, CT_UNTYPED, (:classInst, :dimensions, :binding, :condition, :attributes, :comment, :instantiated, :info))
MetaModelica.compacted_tag_info(::typeof(COMPONENT_DEF))          = (ComponentImpl, :tag, CT_DEF, (:definition, :modifier))

MetaModelica.valueConstructor(v::ComponentImpl) = Int(v.tag)

const DEFAULT_ATTR =
  IMMUTABLE_ATTRIBUTES(
    ConnectorType.NON_CONNECTOR,
    Parallelism.NON_PARALLEL,
    Variability.CONTINUOUS,
    Direction.NONE,
    InnerOuter.NOT_INNER_OUTER,
    false,
    false,
    NOT_REPLACEABLE(),
    false,
  )

const INPUT_ATTR =
  ATTRIBUTES(
    ConnectorType.NON_CONNECTOR,
    Parallelism.NON_PARALLEL,
    Variability.CONTINUOUS,
    Direction.INPUT,
    InnerOuter.NOT_INNER_OUTER,
    false,
    false,
    NOT_REPLACEABLE(),
    false,
  )
const OUTPUT_ATTR =
  ATTRIBUTES(
    ConnectorType.NON_CONNECTOR,
    Parallelism.NON_PARALLEL,
    Variability.CONTINUOUS,
    Direction.OUTPUT,
    InnerOuter.NOT_INNER_OUTER,
    false,
    false,
    NOT_REPLACEABLE(),
    false,
  )
const CONSTANT_ATTR =
  ATTRIBUTES(
    ConnectorType.NON_CONNECTOR,
    Parallelism.NON_PARALLEL,
    Variability.CONSTANT,
    Direction.NONE,
    InnerOuter.NOT_INNER_OUTER,
    false,
    false,
    NOT_REPLACEABLE(),
    false,
  )
const IMPL_DISCRETE_ATTR =
  ATTRIBUTES(
    ConnectorType.NON_CONNECTOR,
    Parallelism.NON_PARALLEL,
    Variability.IMPLICITLY_DISCRETE,
    Direction.NONE,
    InnerOuter.NOT_INNER_OUTER,
    false,
    false,
    NOT_REPLACEABLE(),
    false,
  )

function isTypeAttribute(component::Component)
  local isAttribute::Bool
   isAttribute = begin
    @match component begin
      TYPE_ATTRIBUTE(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isAttribute
end

function isDeleted(component::Component)
  local isDeleted::Bool
   isDeleted = begin
    local condition::Binding
    @match component begin
      TYPED_COMPONENT(condition = condition) => begin
        isBound(condition) &&
        isFalse(getTypedExp(condition))
      end

      DELETED_COMPONENT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isDeleted
end

function getUnitAttribute(component::Component, defaultUnit::String = "")
  local unitString::String

  local binding::Binding
  local unit::Expression

   binding =
    lookupAttributeBinding("unit", getClass(classInstance(component)))
  if isUnbound(binding)
     unitString = defaultUnit
    return unitString
  end
   unit = getBindingExp(getExp(binding))
   unitString = begin
    @match unit begin
      STRING_EXPRESSION(__) => begin
        unit.value
      end

      _ => begin
        defaultUnit
      end
    end
  end
  return unitString
end

function getFixedAttribute(component::Component)
  local fixed::Bool
  local typeAttrs::List{Modifier} = nil
  local binding::Binding
  #=  for parameters the default is fixed = true =#
  fixed = isParameter(component) || isStructuralParameter(component)
  #println("Fixed is true?:", fixed)
  binding = lookupAttributeBinding("fixed", getClass(classInstance(component)))
  #println("binding?", toString(binding))
  #=  no fixed attribute present =#
  if isUnbound(binding)
    #println("Return fixed ", fixed)
    return fixed
  end
  fixed = fixed && isTrue(getBindingExp(getExp(binding)))
  return fixed
end

function getEvaluateAnnotation(component::Component)
  local evaluate::Bool
  local cmt::SCode.Comment
  evaluate = SCodeUtil.getEvaluateAnnotation(comment(component))
  return evaluate
end

function ann(component::Component)
  local ann::Option{Modifier}
  ann = begin
    @match component begin
      TYPED_COMPONENT(__) => begin
        component.ann
      end
      _ => begin
        NONE()
      end
    end
  end
  return ann
end

function comment(component::Component)
  local comment::Option{SCode.Comment}

   comment = begin
    @match component begin
      COMPONENT_DEF(__) => begin
        SCodeUtil.getElementComment(component.definition)
      end

      UNTYPED_COMPONENT(__) => begin
        component.comment
      end

      TYPED_COMPONENT(__) => begin
        component.comment
      end

      _ => begin
        NONE()
      end
    end
  end
  return comment
end

function dimensionCount(@nospecialize(component::Component))
  local count::Int
   count = begin
    @match component begin
      UNTYPED_COMPONENT(__) => begin
        arrayLength(component.dimensions)
      end
      TYPED_COMPONENT(__) => begin
        listLength(arrayDims(component.ty))
      end
      _ => begin
        0
      end
    end
  end
  return count
end

function setDimensions(dims::List{<:Dimension}, component::Component)
   () = begin
    @match component begin
      UNTYPED_COMPONENT(__) => begin
         @assign component.dimensions = listArray(dims)
        ()
      end
      TYPED_COMPONENT(__) => begin
         component.ty =
          liftArrayLeftList(arrayElementType(component.ty), dims)
        ()
      end
      _ => begin
        ()
      end
    end
  end
  return component
end

"""
  flatQuoteName(name) - Quote a name for flat Modelica output only if it
  contains characters that are not valid in a simple Modelica identifier.
"""
function flatQuoteName(name::String)::String
  if occursin(r"^[a-zA-Z_][a-zA-Z0-9_]*$", name)
    return name
  else
    return string("'", name, "'")
  end
end

function toFlatString(name::String, component::Component; inFunction = false)
  local str::String
  local qname::String = flatQuoteName(name)
  str = begin
    local def::SCode.Element
    @match component begin
      TYPED_COMPONENT(__) => begin
        toFlatString(component.attributes, component.ty) *
          toFlatString(component.ty) *
          " " * qname *
          toFlatString(component.binding, " = "; inFunction = inFunction)
      end

      TYPE_ATTRIBUTE(__) => begin
        name + toFlatString(component.modifier, false)
      end
      ITERATOR_COMPONENT(__) => begin
        flatQuoteName(name)
      end
      UNTYPED_COMPONENT(__) => begin
        toFlatString(component.attributes, TYPE_UNKNOWN()) *
          "Untyped" *
          " " * qname *
          toFlatString(component.binding, " = "; inFunction = inFunction)
      end
    end
  end
  return str
end

function toString(nameStr::String, component::Component)
  local str::String
   str = begin
    local def::SCode.Element
    @match component begin
      COMPONENT_DEF(definition = def && SCode.COMPONENT(__)) => begin
        #TODO: SCodeDump.unparseElementStr(def)
        string(def)
      end

      UNTYPED_COMPONENT(__) => begin
        toString(component.attributes, TYPE_UNKNOWN()) +
          name(component.classInst) +
          " " +
          nameStr +
          ListUtil.toString(
            arrayList(component.dimensions),
            toString,
            "",
            "[",
          ", ",
            "]",
            false,
          ) +
            toString(component.binding, " = ")
      end

      TYPED_COMPONENT(__) => begin
        toString(component.attributes, component.ty) +
          toString(component.ty) +
          " " +
          nameStr +
          toString(component.binding, " = ")
      end

      TYPE_ATTRIBUTE(__) => begin
        nameStr + toString(component.modifier, false)
      end
      _ => begin
        "UNKNOWN COMPONENT"
      end
    end
  end
  return str
end

function isIdentical(comp1::Component, comp2::Component)
  local identical::Bool = false
  if referenceEq(comp1, comp2)
     identical = true
  else
     identical = begin
      @match (comp1, comp2) begin
        (UNTYPED_COMPONENT(__), UNTYPED_COMPONENT(__)) => begin
          if !isIdentical(
            getClass(comp1.classInst),
            getClass(comp2.classInst),
          )
            return false
          end
          if !isEqual(comp1.binding, comp2.binding)
            return false
          end
          true
        end

        _ => begin
          true
        end
      end
    end
  end
  return identical
end

function isExternalObject(component::Component)
  local isEO::Bool
   isEO = begin
    @match component begin
      UNTYPED_COMPONENT(__) => begin
        isExternalObject(getClass(component.classInst))
      end
      TYPED_COMPONENT(__) => begin
          isExternalObject(component.ty)
      end
      _ => begin
        false
      end
    end
  end
  return isEO
end

function isExpandableConnector(component::Component)
  local isConnector::Bool = ConnectorType.isExpandable(connectorType(component))
  return isConnector
end

function isConnector(component::Component)
  return isConnectorType(connectorType(component))
end

function isFlow(component::Component)
  return isFlow(connectorType(component))
end

function setConnectorType(cty::ConnectorType.TYPE, component::Component)
   () = begin
    local attr::Attributes
    @match component begin
      UNTYPED_COMPONENT(attributes = attr) => begin
         @assign attr.connectorType = cty
         @assign component.attributes = attr
        ()
      end
      TYPED_COMPONENT(attributes = attr) => begin
         @assign attr.connectorType = cty
         @assign component.attributes = attr
        ()
      end
      _ => begin
        ()
      end
    end
  end
  return component
end

function connectorType(component::Component)
  local cty::ConnectorType.TYPE
   cty = begin
    @match component begin
      UNTYPED_COMPONENT(attributes = ATTRIBUTES(connectorType = cty)) => begin
          cty
        end
      TYPED_COMPONENT(attributes = ATTRIBUTES(connectorType = cty)) => begin
        cty
      end
      DELETED_COMPONENT(__) => begin
        connectorType(component.component)
      end
      _ => begin
        NON_CONNECTOR
      end
    end
  end
  return cty
end

function isOnlyOuter(component::Component)
  local isOuter::Bool = innerOuter(component) == InnerOuter.OUTER
  return isOuter
end

function isOuter(component::Component)
  local isOuter::Bool

  local io = innerOuter(component)

   isOuter = io == InnerOuter.OUTER || io == InnerOuter.INNER_OUTER
  return isOuter
end

function isInner(component::Component)
  local isInner::Bool

  local io = innerOuter(component)

   isInner = io == InnerOuter.INNER || io == InnerOuter.INNER_OUTER
  return isInner
end

function innerOuter(component::Component)
  local io
   io = begin
    @match component begin
      UNTYPED_COMPONENT(attributes = ATTRIBUTES(innerOuter = io)) => begin
        io
      end

      TYPED_COMPONENT(attributes = ATTRIBUTES(innerOuter = io)) => begin
        io
      end

      COMPONENT_DEF(__) => begin
        innerOuterFromSCode(SCodeUtil.prefixesInnerOuter(SCodeUtil.elementPrefixes(component.definition)))
      end

      _ => begin
        InnerOuter.NOT_INNER_OUTER
      end
    end
  end
  return io
end

function isFinal(component::Component)
  local isFinal::Bool

   isFinal = begin
    @match component begin
      COMPONENT_DEF(__) => begin
        SCodeUtil.finalBool(SCodeUtil.prefixesFinal(SCodeUtil.elementPrefixes(component.definition)))
      end
      UNTYPED_COMPONENT(attributes = ATTRIBUTES(isFinal = isFinal)) => begin
        isFinal
      end
      TYPED_COMPONENT(attributes = ATTRIBUTES(isFinal = isFinal)) => begin
        isFinal
      end

      _ => begin
        false
      end
    end
  end
  return isFinal
end

function isRedeclare(component::Component)
  local isRedeclare::Bool
   isRedeclare = begin
    @match component begin
      COMPONENT_DEF(__) => begin
        SCodeUtil.isElementRedeclare(component.definition)
      end
      _ => begin
        false
      end
    end
  end
  return isRedeclare
end

function isVar(component::Component)
  local isVar::Bool = variability(component) == CONTINIUOUS
  return isVar
end

function isStructuralParameter(component::Component)
  local b::Bool = variability(component) == Variability.STRUCTURAL_PARAMETER
  return b
end

function isParameter(component::Component)
  local b::Bool = variability(component) == Variability.PARAMETER
  return b
end

function isConst(component::Component)
  local isConst::Bool = variability(component) == Variability.CONSTANT
  return isConst
end

function setVariability(variability::VariabilityType, component::Component)
    local attr::Attributes
  @match component begin
    UNTYPED_COMPONENT(attributes = attr) || TYPED_COMPONENT(attributes = attr) => begin
      local localAttri = ATTRIBUTES(attr.connectorType,
                                    attr.parallelism,
                                    variability,
                                    attr.direction,
                                    attr.innerOuter,
                                    attr.isFinal,
                                    attr.isRedeclare,
                                    attr.isReplaceable,
                                    attr.isStructuralMode)
      if isvariant(component, UNTYPED_COMPONENT)
        component = UNTYPED_COMPONENT(component.classInst,
                                      component.dimensions,
                                      component.binding,
                                      component.condition,
                                      localAttri,
                                      component.comment,
                                      component.instantiated,
                                      component.info)
      else
        component = TYPED_COMPONENT(component.classInst,
                                    component.ty,
                                    component.binding,
                                    component.condition,
                                    localAttri,
                                    component.ann,
                                    component.comment,
                                    component.info)
      end
      return component
    end
    _ => begin
      return component
    end
  end
end

function variability(component::Component)
  local v
  v = begin
    @match component begin
      TYPED_COMPONENT(attributes = ATTRIBUTES(variability = v)) =>
        begin
          v
        end

      UNTYPED_COMPONENT(attributes = ATTRIBUTES(variability = v)) => begin
        v
      end

      ITERATOR_COMPONENT(__) => begin
        component.variability
      end

      ENUM_LITERAL_COMPONENT(__) => begin
        Variability.CONSTANT
      end

      _ => begin
        Variability.CONTINUOUS
      end
    end
  end
  return v
end

function parallelism(component::Component)
  local parallelism::ParallelismType

   parallelism = begin
    @match component begin
      TYPED_COMPONENT(attributes = ATTRIBUTES(parallelism = parallelism)) => begin
        parallelism
      end

      UNTYPED_COMPONENT(attributes = ATTRIBUTES(parallelism = parallelism)) => begin
        parallelism
      end

      _ => begin
        NON_PARALLEL
      end
    end
  end
  return parallelism
end

function isOutput(component::Component)
  local isOutput::Bool = direction(component) == Direction.OUTPUT
  return isOutput
end

function makeInput(component::Component)

  local attr::Attributes

   () = begin
    @match component begin
      UNTYPED_COMPONENT(attributes = attr) => begin
         @assign attr.direction = Direction.INPUT
         @assign component.attributes = attr
        ()
      end

      TYPED_COMPONENT(attributes = attr) => begin
         @assign attr.direction = Direction.INPUT
         @assign component.attributes = attr
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return component
end

function isInput(component::Component)
  local isInput::Bool = direction(component) == Direction.INPUT
  return isInput
end

function direction(component::Component)
  local direction::DirectionType
  direction = begin
    @match component begin
      TYPED_COMPONENT(attributes = ATTRIBUTES(direction = direction)) =>
        begin
          direction
        end
      UNTYPED_COMPONENT(attributes = ATTRIBUTES(direction = direction)) =>
        begin
          direction
        end
      _ => begin
        Direction.NONE
      end
    end
  end
  return direction
end

function hasCondition(component::Component)
  local b::Bool
   b = isBound(getCondition(component))
  return b
end

function getCondition(component::Component)
  local cond::Binding

   cond = begin
    @match component begin
      UNTYPED_COMPONENT(__) => begin
        component.condition
      end

      TYPED_COMPONENT(__) => begin
        component.condition
      end

      _ => begin
        EMPTY_BINDING
      end
    end
  end
  return cond
end

function hasBinding(comp::Component, parent::InstNode = EMPTY_NODE())
  local b::Bool

  local cls::Class
  local children::Vector{InstNode}

  if isBound(getBinding(comp))
     b = true
    return b
  end
  #=  Simple case, component has normal binding equation.
  =#
  #=  Complex case, component might be a record instance where each field has
  =#
  #=  its own binding equation.
  =#
   cls = getClass(classInstance(comp))
  if !isRecord(restriction(cls))
     b = false
    return b
  end
  #=  Not record. =#
  #=  Check if any child of this component is missing a binding. =#
   children = getComponents(classTree(cls))
  for c in children
    if isComponent(c) && !hasBinding(component(c))
      b = false
      return b
    end
  end
  b = true
  return b
end

function setBinding(binding::Binding, @nospecialize(component::Component))
  @match component begin
    UNTYPED_COMPONENT(__) => begin
      @assign component.binding = binding
      ()
    end
    TYPED_COMPONENT(__) => begin
      #= New instance needed, thereby use of assign=#
      @assign component.binding = binding
      ()
    end
    TYPE_ATTRIBUTE(__) => begin
      @assign component.modifier = setBinding(binding, component.modifier)
      ()
    end
  end
  return component
end

"""
  Returns the component's binding. If the component does not have a binding
  and is a record instance it will try to create a binding from the
  component's children.
"""
function getImplicitBinding(component::Component)
  local binding::Binding

  local cls_node::InstNode
  local record_exp::Expression

   binding = getBinding(component)
  if isUnbound(binding)
     cls_node = classInstance(component)
    if isRecord(cls_node)
      try
         record_exp = makeRecordExp(cls_node)
         binding = FLAT_BINDING(
          record_exp,
          variability(record_exp),
        )
      catch
      end
    end
  end
  return binding
end

function getBinding(component::Component)
  local b::Binding
   b = begin
    @match component begin
      UNTYPED_COMPONENT(__) => begin
        component.binding
      end
      TYPED_COMPONENT(__) => begin
        component.binding
      end
      TYPE_ATTRIBUTE(__) => begin
        binding(component.modifier)
      end
      _ => begin
        EMPTY_BINDING
      end
    end
  end
  return b
end

function setAttributes(attr, component::Component)

   () = begin
    @match component begin
      UNTYPED_COMPONENT(__) => begin
         @assign component.attributes = attr
        ()
      end

      TYPED_COMPONENT(__) => begin
         @assign component.attributes = attr
        ()
      end
    end
  end
  return component
end

function getAttributes(component::Component)
  local attr
   attr = begin
    @match component begin
      UNTYPED_COMPONENT(__) => begin
        component.attributes
      end
      TYPED_COMPONENT(__) => begin
        component.attributes
      end
    end
  end
  return attr
end

function unliftType(component::Component)
   () = begin
    local ty::M_Type
    @match component begin
      TYPED_COMPONENT(ty = TYPE_ARRAY(elementType = ty)) => begin
         @assign component.ty = ty
        ()
      end
      ITERATOR(ty = TYPE_ARRAY(elementType = ty)) => begin
         @assign component.ty = ty
        ()
      end
      _ => begin
        ()
      end
    end
  end
  return component
end

function isTyped(component::Component)
  local isTyped::Bool
   isTyped = begin    @match component begin
      TYPED_COMPONENT(__) => begin
        true
      end

      ITERATOR_COMPONENT(ty = TYPE_UNKNOWN(__)) => begin
        false
      end

      ITERATOR_COMPONENT(__) => begin
        true
      end

      TYPE_ATTRIBUTE_COMPONENT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isTyped
end

function setType(ty::M_Type, component::Component)

   component = begin
    @match component begin
      UNTYPED_COMPONENT(__) => begin
        TYPED_COMPONENT(
          component.classInst,
          ty,
          component.binding,
          component.condition,
          component.attributes,
          NONE(),
          component.comment,
          component.info,
        )
      end

      TYPED_COMPONENT(__) => begin
        @assign component.ty = ty
        component
      end

      ITERATOR(__) => begin
         @assign component.ty = ty
        component
      end
    end
  end
  return component
end

function getType(component::Component)
  local ty::M_Type

   ty = begin
    @match component begin
      TYPED_COMPONENT(__) => begin
        component.ty
      end

      UNTYPED_COMPONENT(__) => begin
        getType(component.classInst)
      end

      ITERATOR_COMPONENT(__) => begin
        component.ty
      end

      TYPE_ATTRIBUTE(__) => begin
        component.ty
      end

      DELETED_COMPONENT(__) => begin
        getType(component.component)
      end

      _ => begin
        TYPE_UNKNOWN()
      end
    end
  end
  return ty
end

"""
  TODO Clean up the dbg prints here.
Note that we need to clone a new object by using @assign here...
"""
function mergeModifier(modifier::Modifier, component::Component)
  local mod = merge(modifier, component.modifier)
  local modifiedComponent = if isvariant(component, COMPONENT_DEF)
    COMPONENT_DEF(component.definition, mod)
  else
    TYPE_ATTRIBUTE(component.ty, mod)
  end
  return modifiedComponent
end

function setModifier(modifier::Modifier, @nospecialize(component::Component))
  if isvariant(component, COMPONENT_DEF) || isvariant(component, TYPE_ATTRIBUTE)
    @assign component.modifier = modifier
  end
  return component
end

function getModifier(component::Component)
  local modifier::Modifier
  modifier = begin
    @match component begin
      COMPONENT_DEF(__) => begin
        component.modifier
      end
      TYPE_ATTRIBUTE(__) => begin
        component.modifier
      end
      _ => begin
        MODIFIER_NOMOD()
      end
    end
  end
  return modifier
end

function setClassInstance(classInst::InstNode, component::Component)
  @match component begin
    UNTYPED_COMPONENT(__) => begin
      @assign component.classInst = classInst
      ()
    end

    TYPED_COMPONENT(__) => begin
      @assign component.classInst = classInst
      ()
    end
  end
  return component
end

function classInstance(component::Component)
  return component.classInst
end

"""
  This function shouldn't be used! Use InstNode.info instead, so that e.g.
  enumeration literals can be handled correctly.
"""
function Component_info(component::Component)
  local info::SourceInfo

   info = begin
    @match component begin
      COMPONENT_DEF(__) => begin
        SCodeUtil.elementInfo(component.definition)
      end

      UNTYPED_COMPONENT(__) => begin
        component.info
      end

      TYPED_COMPONENT(__) => begin
        component.info
      end

      ITERATOR_COMPONENT(__) => begin
        component.info
      end

      TYPE_ATTRIBUTE(__) => begin
        info(component.modifier)
      end

      DELETED_COMPONENT(__) => begin
        Component_info(component.component)
      end
    end
  end
  #=  Fail for enumeration literals, InstNode.info handles that case instead.
  =#
  return info
end

isDefinition(component::Component) = isvariant(component, COMPONENT_DEF)

function definition(component::Component)
  local def::SCode.Element
  def = @match component begin
    COMPONENT_DEF(def, mod) => component.definition
    TYPED_COMPONENT(__) => definition(component.classInst)
    _ => throw("Unsuported component: $(typeof(component)) in definition(component::Component)")
  end
  return def
end

function newEnum(enumType::M_Type, literalName::String, literalIndex::Int)
  local component::Component
  component =
    ENUM_LITERAL_COMPONENT(ENUM_LITERAL_EXPRESSION(enumType, literalName, literalIndex))
  return component
end

function new(definition::SCode.Element)
  COMPONENT_DEF(definition, MODIFIER_NOMOD())
end

function newIterator(iterType::Type, info::SourceInfo)
  ITERATOR_COMPONENT(iterType, Variability.IMPLICITLY_DISCRETE, info);
end

function toFlatString(attr::Attributes, ty::M_Type; isTopLevel = true)
  local str::String = ""
  if attr.isFinal
    str = str * "final "
  end
  str = str * unparseVariability(attr.variability, ty)
  if isTopLevel
    str = str * unparseDirection(attr.direction)
  end
  return str
end

function toString(attr::Attributes, ty::M_Type)
  local str::String
  str =
    (
      if attr.isRedeclare
        "redeclare "
      else
        ""
      end
    ) +
    (
      if attr.isFinal
        "final "
      else
        ""
      end
    ) +
      unparseInnerOuter(attr.innerOuter) +
      unparseReplaceable(attr.isReplaceable) +
      unparseParallelism(attr.parallelism) +
      unparse(attr.connectorType) +
      unparseVariability(attr.variability, ty) +
      unparseDirection(attr.direction)
  return str
end

function toDAE(ina::Attributes, vis)
  local outa::DAE.Attributes
  outa = DAE.ATTR(
    toDAE(ina.connectorType),
    parallelismToSCode(ina.parallelism),
    variabilityToSCode(ina.variability),
    directionToAbsyn(ina.direction),
    innerOuterToAbsyn(ina.innerOuter),
    visibilityToSCode(vis),
  )
  return outa
end

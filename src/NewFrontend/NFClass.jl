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

using MetaModelica.Dangerous
@Uniontype Prefixes begin
  @Record PREFIXES begin
    encapsulatedPrefix::SCode.Encapsulated
    partialPrefix::SCode.Partial
    finalPrefix::SCode.Final
    innerOuter::Absyn.InnerOuter
    replaceablePrefix::SCode.Replaceable
  end
end

abstract type Class end
struct DAE_TYPE <: Class
  ty::DAE.Type
end

struct TYPED_DERIVED{T0 <: NFType, T1 <: InstNode, T2 <: Restriction} <: Class
  ty::T0
  baseClass::T1
  restriction::T2
end

mutable struct INSTANCED_BUILTIN <: Class
  ty::NFType
  elements::ClassTree
  restriction::Restriction
end

mutable struct INSTANCED_CLASS <: Class
  ty::NFType
  elements::ClassTree
  sections::Sections
  restriction::Restriction
end

mutable struct EXPANDED_DERIVED <: Class
  baseClass::InstNode
  modifier::Modifier
  dims::Vector{Dimension}
  prefixes::Prefixes
  attributes::Attributes
  restriction::Restriction
end

mutable struct EXPANDED_CLASS <: Class
  elements::ClassTree
  modifier::Modifier
  prefixes::Prefixes
  restriction::Restriction
end

mutable struct PARTIAL_BUILTIN <: Class
  ty::NFType
  elements::ClassTree
  modifier::Modifier
  prefixes::Prefixes
  restriction::Restriction
end

mutable struct PARTIAL_CLASS <: Class
  elements::ClassTree
  modifier::Modifier
  prefixes::Prefixes
end

struct NOT_INSTANTIATED <: Class
end

const DEFAULT_PREFIXES =
  PREFIXES(
    SCode.NOT_ENCAPSULATED(),
    SCode.NOT_PARTIAL(),
    SCode.NOT_FINAL(),
    Absyn.NOT_INNER_OUTER(),
    SCode.NOT_REPLACEABLE()
  )

function toFlatString(cls::Class, clsNode::InstNode)::String
  local str::String
  local s
  s = IOStream_M.create(getInstanceName(), IOStream_M.JULIA_BUFFER())
  s = toFlatStream(cls, clsNode, s)
  str = IOStream_M.string(s)
  IOStream_M.delete(s)
  return str
end

function toFlatStream(cls::Class, clsNode::InstNode, s)
  local name::String
  name = AbsynUtil.pathString(scopePath(clsNode))
  s = begin
    @match cls begin
      INSTANCED_CLASS(__) => begin
        s = IOStream_M.append(s, toString(cls.restriction))
        s = IOStream_M.append(s, " '")
        s = IOStream_M.append(s, name)
        s = IOStream_M.append(s, "'\\n")
        for comp in getComponents(cls.elements)
          if cls.restriction isa RESTRICTION_RECORD
            #= No input allowed in comp. They are added by mistake I think earlier in the print process =#
            compComp = component(comp)
            if compComp.attributes.direction != Direction.NONE
              @assign compComp.attributes.direction = Direction.NONE
              updateComponent!(compComp, comp)
            end
          end
          s = IOStream_M.append(s, "  ")
          s = IOStream_M.append(s, toFlatString(comp))
          s = IOStream_M.append(s, ";\\n")
        end
        s = IOStream_M.append(s, "end '")
        s = IOStream_M.append(s, name)
        s = IOStream_M.append(s, "'")
        s
      end

      INSTANCED_BUILTIN(__) => begin
        s = IOStream_M.append(s, "INSTANCED_BUILTIN(")
        s = IOStream_M.append(s, name)
        s = IOStream_M.append(s, ")")
        s
      end

      TYPED_DERIVED(__) => begin
        s = IOStream_M.append(s, toString(cls.restriction))
        s = IOStream_M.append(s, " '")
        s = IOStream_M.append(s, name)
        s = IOStream_M.append(s, "' = '")
        s =
          IOStream_M.append(s, AbsynUtil.pathString(scopePath(cls.baseClass)))
        s = IOStream_M.append(s, "'")
        s
      end

      _ => begin
        IOStream_M.append(s, "UNKNOWN_CLASS(" + name + ")")
      end
    end
  end
  return s
end

function makeRecordExp(clsNode::InstNode)::Expression
  local exp::Expression
  local cls::Class
  local ty::M_Type
  local ty_node::InstNode
  local fields::Vector{InstNode}
  local args::List{Expression}
  @assign cls = getClass(clsNode)
  @match (@match TYPE_COMPLEX(complexTy = COMPLEX_RECORD(ty_node)) = ty) =
    getType(cls, clsNode)
  @assign fields = getComponents(classTree(cls))
  @assign args = List(
    getExp(getImplicitBinding(component(f)))
    for f in fields
  )
  @assign exp = makeRecord(scopePath(ty_node), ty, args)
  return exp
end

function hasOperator(name::String, cls::Class)::Bool
  local hasOperator::Bool
  local op_node::InstNode
  local op_cls::Class
  if isOperatorRecord(restriction(cls))
    @match ENTRY_INFO(op_node, _) = lookupElement(name, cls)
    if op_node isa EMPTY_NODE
      hasOperator = false
    else
      hasOperator = SCodeUtil.isOperator(definition(op_node))
    end
  else
    hasOperator = false
  end
  return hasOperator
end

function getDerivedComments(cls::Class, cmts::List{<:SCode.Comment})::List{SCode.Comment}
  cmts = begin
    @match cls begin
      EXPANDED_DERIVED(__) => begin
        getComments(cls.baseClass, cmts)
      end

      TYPED_DERIVED(__) => begin
        getComments(cls.baseClass, cmts)
      end

      _ => begin
        cmts
      end
    end
  end
  return cmts
end

function lastBaseClass(node::InstNode)::InstNode
  local cls::Class = getClass(node)
  node = begin
    @match cls begin
      EXPANDED_DERIVED(__) => begin
        lastBaseClass(cls.baseClass)
      end

      TYPED_DERIVED(__) => begin
        lastBaseClass(cls.baseClass)
      end

      _ => begin
        node
      end
    end
  end
  return node
end

function isEncapsulated(cls::Class)::Bool
  local isEncapsulated::Bool
  isEncapsulated = begin
    @match cls begin
      PARTIAL_CLASS(__) => begin
        SCodeUtil.encapsulatedBool(cls.prefixes.encapsulatedPrefix)
      end
      EXPANDED_CLASS(__) => begin
        SCodeUtil.encapsulatedBool(cls.prefixes.encapsulatedPrefix)
      end
      EXPANDED_DERIVED(__) => begin
        SCodeUtil.encapsulatedBool(cls.prefixes.encapsulatedPrefix)
      end
      _ => begin
        false
      end
    end
  end
  return isEncapsulated
end

function setPrefixes(prefs::Prefixes, cls::Class)
  @match cls begin
    EXPANDED_CLASS(__) => begin
      cls.prefixes = prefs
      ()
    end

    EXPANDED_DERIVED(__) => begin
      cls.prefixes = prefs
      ()
    end
  end
  return cls
end

function getPrefixes(cls::Class)
  local prefs::Prefixes
  prefs = begin
    @match cls begin
      PARTIAL_CLASS(__) => begin
        cls.prefixes
      end
      PARTIAL_BUILTIN(__) => begin
        cls.prefixes
      end
      EXPANDED_CLASS(__) => begin
        cls.prefixes
      end
      EXPANDED_DERIVED(__) => begin
        cls.prefixes
      end
    end
  end
  return prefs
end

function isOverdetermined(cls::Class)::Bool
  local isOverdetermined::Bool
  local res = lookupElement("equalityConstraint", cls)
  if res.node !== EMPTY_NODE()
    System.setHasOverconstrainedConnectors(true)
    isOverdetermined = true
  else
    isOverdetermined = false
  end
  #=  set the external flag that signals the presence of expandable connectors in the model =#
  return isOverdetermined
end

function isExternalFunction(cls::Class)::Bool
  local isExtFunc::Bool
  isExtFunc = begin
    local lang::String
    @match cls begin
      EXPANDED_DERIVED(__) => begin
        isExternalFunction(getClass(cls.baseClass))
      end

      INSTANCED_CLASS(sections = SECTIONS_EXTERNAL(language = lang)) => begin
        lang != "builtin"
      end

      TYPED_DERIVED(__) => begin
        isExternalFunction(getClass(cls.baseClass))
      end

      _ => begin
        false
      end
    end
  end
  return isExtFunc
end

function isFunction(cls::Class)::Bool
  local f::Bool = isFunction(restriction(cls))
  return f
end

function isExternalObject(cls::Class)::Bool
  return isExternalObject(restriction(cls))
end

function isExpandableConnectorClass(cls::Class)::Bool
  local isConnector::Bool =
    isExpandableConnector(restriction(cls))
  return isConnector
end

function isNonexpandableConnectorClass(cls::Class)::Bool
  local isConnector::Bool =
    isNonexpandableConnector(restriction(cls))
  return isConnector
end

function isConnectorClass(cls::Class)::Bool
  local isConnector::Bool = isConnector(restriction(cls))
  return isConnector
end

function setRestriction(res::Restriction, cls::Class)::Class
   () = begin
    @match cls begin
      EXPANDED_CLASS(__) => begin
        #=  PARTIAL_BUILTIN is only used for predefined builtin types and not needed here. =#
        cls.restriction = res
        ()
      end

      EXPANDED_DERIVED(__) => begin
        cls.restriction = res
        ()
      end

      INSTANCED_CLASS(__) => begin
        cls.restriction = res
        ()
      end

      INSTANCED_BUILTIN(__) => begin
        cls.restriction = res
        ()
      end

      TYPED_DERIVED(__) => begin
        cls.restriction = res
        ()
      end
    end
  end
  return cls
end

function restriction(cls::Class)::Restriction
  local res::Restriction

  @assign res = begin
    @match cls begin
      PARTIAL_BUILTIN(__) => begin
        cls.restriction
      end

      EXPANDED_CLASS(__) => begin
        cls.restriction
      end

      EXPANDED_DERIVED(__) => begin
        cls.restriction
      end

      INSTANCED_CLASS(__) => begin
        cls.restriction
      end

      INSTANCED_BUILTIN(__) => begin
        cls.restriction
      end

      TYPED_DERIVED(__) => begin
        cls.restriction
      end

      _ => begin
        RESTRICTION_UNKNOWN()
      end
    end
  end
  return res
end

function setType(@nospecialize(ty::M_Type), @nospecialize(cls::Class))
   () = begin
    @match cls begin
      PARTIAL_BUILTIN(__) => begin
        cls.ty = ty
        ()
      end

      EXPANDED_DERIVED(__) => begin
        classApply(cls.baseClass, setType, ty)
        ()
      end

      INSTANCED_CLASS(__) => begin
        cls.ty = ty
        ()
      end

      INSTANCED_BUILTIN(__) => begin
        cls.ty = ty
        ()
      end

      TYPED_DERIVED(__) => begin
        cls.ty = ty
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return cls
end

function getType(cls::Class, clsNode::InstNode)::NFType
  local ty::NFType
  @assign ty = begin
    @match cls begin
      PARTIAL_BUILTIN(__) => begin
        cls.ty
      end
      EXPANDED_DERIVED(__) => begin
        getType(getClass(cls.baseClass), cls.baseClass)
      end

      INSTANCED_CLASS(__) => begin
        cls.ty
      end
      INSTANCED_BUILTIN(__) => begin
        begin
          @match cls.ty begin
            TYPE_POLYMORPHIC("") => begin
              TYPE_POLYMORPHIC(name(clsNode))
            end
            _ => begin
              cls.ty
            end
          end
        end
      end

      TYPED_DERIVED(__) => begin
        cls.ty
      end

      _ => begin
        TYPE_UNKNOWN()
      end
    end
  end
  return ty
end

function getTypeAttributes(cls::Class)::List{Modifier}
  local attributes::List{Modifier} = nil
  local comps::Vector{InstNode}
  local mod::Modifier
  comps = getComponents(classTree(cls))
  for c in comps
    mod = getModifier(component(c))
    if !isEmpty(mod)
      attributes = _cons(mod, attributes)
    end
  end
  return attributes
end

function getAttributes(cls::Class)
  local attr::Attributes
  attr = begin
    @match cls begin
      EXPANDED_DERIVED(__) => begin
        cls.attributes
      end
      _ => begin
        NFComponent.DEFAULT_ATTR
      end
    end
  end
  return attr
end

function getDimensions(cls::Class)::List{Dimension}
  local dims::List{Dimension}

  @assign dims = begin
    @match cls begin
      INSTANCED_CLASS(__) => begin
        arrayDims(cls.ty)
      end

      INSTANCED_BUILTIN(__) => begin
        arrayDims(cls.ty)
      end

      TYPED_DERIVED(__) => begin
        arrayDims(cls.ty)
      end

      _ => begin
        nil
      end
    end
  end
  return dims
end

function hasDimensions(cls::Class)::Bool
  local hasDims::Bool

  @assign hasDims = begin
    @match cls begin
      EXPANDED_DERIVED(__) => begin
        arrayLength(cls.dims) > 0 || hasDimensions(getClass(cls.baseClass))
      end

      TYPED_DERIVED(__) => begin
        isArray(cls.ty)
      end

      _ => begin
        false
      end
    end
  end
  return hasDims
end

function isIdentical(cls1::Class, cls2::Class)::Bool
  local identical::Bool = false

  if referenceEq(cls1, cls2)
    @assign identical = true
  else
    @assign identical = begin
      @match (cls1, cls2) begin
        (EXPANDED_CLASS(__), EXPANDED_CLASS(__)) => begin
          isEqual(cls1.prefixes, cls2.prefixes) &&
          isIdentical(cls1.elements, cls2.elements)
        end

        (INSTANCED_BUILTIN(__), INSTANCED_BUILTIN(__)) => begin
          if !isEqual(cls1.ty, cls2.ty)
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

function mergeModifier(@nospecialize(modifier::Modifier), @nospecialize(cls::Class))
  local mod
  local resClass = @match cls begin
    PARTIAL_CLASS(__) => begin
      mod = merge(modifier, cls.modifier)
      PARTIAL_CLASS(cls.elements, mod, cls.prefixes)
    end
    EXPANDED_CLASS(__) => begin
      mod = merge(modifier, cls.modifier)
      EXPANDED_CLASS(cls.elements, mod, cls.prefixes, cls.restriction)
    end
    EXPANDED_DERIVED(__) => begin
      mod = merge(modifier, cls.modifier)
      EXPANDED_DERIVED(cls.baseClass, mod, cls.dims, cls.prefixes, cls.attributes, cls.restriction)
    end
    PARTIAL_BUILTIN(__) => begin
      mod = merge(modifier, cls.modifier)
      PARTIAL_BUILTIN(cls.ty, cls.elements, mod, cls.prefixes, cls.restriction)
    end
  end
  return resClass
end

function setModifier(@nospecialize(modifier::Modifier),
                     @nospecialize(cls::Class))
   () = begin
    @match cls begin
      PARTIAL_CLASS(__) => begin
        cls.modifier = modifier
        ()
      end

      EXPANDED_CLASS(__) => begin
        cls.modifier = modifier
        ()
      end

      EXPANDED_DERIVED(__) => begin
        cls.modifier = modifier
        ()
      end

      PARTIAL_BUILTIN(__) => begin
        cls.modifier = modifier
        ()
      end
      _ => begin
        Error.assertion(false, getInstanceName() + " got non-modifiable class", sourceInfo())
        fail()
      end
    end
  end
  return cls
end

function getModifier(cls::Union{PARTIAL_CLASS, EXPANDED_CLASS, EXPANDED_DERIVED, PARTIAL_BUILTIN})
  return cls.modifier
end

getModifier(cls::Class) = MODIFIER_NOMOD()

classTreeApply(cls::Class, func::FuncType) = cls

function classTreeApply(cls::INSTANCED_BUILTIN, func::FuncType)
  local elements = func(cls.elements)
  local tmpCls = INSTANCED_BUILTIN(cls.ty, elements, cls.restriction)
  return tmpCls
end

function classTreeApply(cls::INSTANCED_CLASS, func::FuncType)
  local elements = func(cls.elements)
  local tmpCls = INSTANCED_CLASS(cls.ty, elements, cls.sections, cls.restriction)
  return tmpCls
end

function classTreeApply(cls::EXPANDED_CLASS, func::FuncType)
  local elements = func(cls.elements)
  local tmpCls = EXPANDED_CLASS(elements, cls.modifier, cls.prefixes, cls.restriction)
  return tmpCls
end

function classTreeApply(cls::PARTIAL_BUILTIN, func::FuncType)
  local elements = func(cls.elements)
  local tmpCls = PARTIAL_BUILTIN(cls.ty, elements, cls.modifier, cls.prefixes, cls.restriction)
  return tmpCls
end

function classTreeApply(cls::PARTIAL_CLASS, func::FuncType)
  local elements = func(cls.elements)
  local tmpCls = PARTIAL_CLASS(elements, cls.modifier, cls.prefixes)
  return tmpCls
end

function setClassTree(tree::ClassTree, cls::Class)
  return cls
end

function setClassTree(tree::ClassTree, cls::INSTANCED_BUILTIN)
  local tmpCls = INSTANCED_BUILTIN(cls.ty, tree, cls.restriction)
  return tmpCls
end

function setClassTree(tree::ClassTree, cls::INSTANCED_CLASS)
  local tmpCls = INSTANCED_CLASS(cls.ty, tree, cls.sections, cls.restriction)
  return tmpCls
end

function setClassTree(tree::ClassTree, cls::EXPANDED_CLASS)
  local tmpCls = EXPANDED_CLASS(tree, cls.modifier, cls.prefixes, cls.restriction)
  return tmpCls
end

function setClassTree(tree::ClassTree, cls::PARTIAL_BUILTIN)
  local tmpCls = PARTIAL_BUILTIN(cls.ty, tree, cls.modifier, cls.prefixes, cls.restriction)
  return tmpCls
end

function setClassTree(tree::ClassTree, cls::PARTIAL_CLASS)
  local tmpCls = PARTIAL_CLASS(tree, cls.modifier, cls.prefixes)
  return tmpCls
end

function classTree(cls::Class)::ClassTree
  local tree::ClassTree
  tree = begin
    @match cls begin
      PARTIAL_CLASS(__) => begin
        cls.elements
      end

      PARTIAL_BUILTIN(__) => begin
        cls.elements
      end

      EXPANDED_CLASS(__) => begin
        cls.elements
      end

      EXPANDED_DERIVED(__) => begin
        classTree(getClass(cls.baseClass))
      end

      INSTANCED_CLASS(__) => begin
        cls.elements
      end

      INSTANCED_BUILTIN(__) => begin
        cls.elements
      end

      TYPED_DERIVED(__) => begin
        classTree(getClass(cls.baseClass))
      end
      _ => begin
        CLASS_TREE_EMPTY_TREE() #EMPTY_TREE()
      end
    end
  end
  #@debug "Our resulting tree in class tree"
  #  str = LookupTree.printTreeStr(lookupTree(tree))
  #@debug "Value of str"
  return tree
end

function isBuiltin(cls::Class)::Bool
  local b::Bool
  b = begin
    @match cls begin
      PARTIAL_BUILTIN(__) => begin
        true
      end

      INSTANCED_BUILTIN(__) => begin
        true
      end

      EXPANDED_DERIVED(__) => begin
        isBuiltin(getClass(cls.baseClass))
      end

      TYPED_DERIVED(__) => begin
        isBuiltin(getClass(cls.baseClass))
      end

      _ => begin
        false
      end
    end
  end
  return b
end

function lookupAttributeValue(name::String, cls::Class)::Option{Expression}
  local value::Option{Expression} = typedExp(lookupAttributeBinding(name, cls))
  return value
end

function lookupAttributeBinding(name::String, cls::Class)::Binding
  local binding::Binding
  local attr_node::InstNode
  try
    @match ENTRY_INFO(attr_node, isImport) = lookupElement(name, classTree(cls))
    binding = getBinding(component(attr_node))
  catch
    binding = EMPTY_BINDING
  end
  return binding
end

function nthComponent(index::Int, cls::Class)::InstNode
  local component::InstNode
  component = nthComponent(index, classTree(cls))
  return component
end

function lookupComponentIndex(name::String, cls::Class)::Int
  local index::Int
  index = lookupComponentIndex(name, classTree(cls))
  return index
end

function lookupElement(name::String, cls::Class)
  local isImport::Bool
  local node::InstNode
  local entryInfo = lookupElement(name, classTree(cls))
  return entryInfo
end

function setSections(sections::Sections, cls::Class)::Class
  cls = begin
    @match cls begin
      INSTANCED_CLASS(__) => begin
        INSTANCED_CLASS(cls.ty, cls.elements, sections, cls.restriction)
      end
    end
  end
  return cls
end

function getSections(cls::Class)::Sections
  local sections::Sections
  sections = begin
    @match cls begin
      INSTANCED_CLASS(__) => begin
        cls.sections
      end
      TYPED_DERIVED(__) => begin
        getSections(getClass(cls.baseClass))
      end
      _ => begin
        SECTIONS_EMPTY()
      end
    end
  end
  return sections
end

function initExpandedClass(cls::Class)::Class
  cls = begin
    @match cls begin
      PARTIAL_CLASS(__) => begin
        EXPANDED_CLASS(
          cls.elements,
          cls.modifier,
          cls.prefixes,
          RESTRICTION_UNKNOWN(),
        )
      end
    end
  end
  return cls
end

function makeRecordConstructor(fields::List{<:InstNode}, out::InstNode)
  local cls::Class
  local tree::ClassTree
  tree = fromRecordConstructor(fields, out)
  cls = INSTANCED_CLASS(
    TYPE_UNKNOWN(),
    tree,
    SECTIONS_EMPTY(),
    RESTRICTION_RECORD_CONSTRUCTOR(),
  )
  return cls
end

function fromEnumeration(
  literals::List{<:SCode.Enum},
  enumType::M_Type,
  prefixes::Prefixes,
  enumClass::InstNode)
  local cls::Class
  local tree::ClassTree
  tree = fromEnumeration(literals, enumType, enumClass)
  cls = PARTIAL_BUILTIN(
    enumType,
    tree,
    MODIFIER_NOMOD(),
    prefixes,
    RESTRICTION_ENUMERATION(),
  )
  return cls
end

function fromSCode(
  elements::List{<:SCode.Element},
  isClassExtends::Bool,
  scope::InstNode,
  prefixes::Prefixes)
  local cls::Class
  local tree::ClassTree
  tree = fromSCode(elements, isClassExtends, scope)
  cls = PARTIAL_CLASS(tree, MODIFIER_NOMOD(), prefixes)
  return cls
end

function isEqual(prefs1::Prefixes, prefs2::Prefixes)::Bool
  local isEqual::Bool = valueEq(prefs1, prefs2)
  return isEqual
end

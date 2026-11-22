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
"""
    PREFIXES(encapsulatedPrefix, partialPrefix, finalPrefix, innerOuter, replaceablePrefix)

The prefixes of a class (`encapsulated`, `partial`, `final`, `inner`/`outer`, `replaceable`), as SCode and Absyn
values. Not SCode's `PREFIXES`, which holds an element's prefixes.
"""
struct PREFIXES
  encapsulatedPrefix::SCode.Encapsulated
  partialPrefix::SCode.Partial
  finalPrefix::SCode.Final
  innerOuter::Absyn.InnerOuter
  replaceablePrefix::SCode.Replaceable
end

abstract type Class end
struct TYPED_DERIVED <: Class
  ty::ModelicaType
  baseClass::InstNode
  restriction::Restriction
end

struct INSTANCED_BUILTIN <: Class
  ty::ModelicaType
  elements::ClassTree
  restriction::Restriction
end

struct INSTANCED_CLASS <: Class
  ty::ModelicaType
  elements::ClassTree
  sections::Sections
  restriction::Restriction
end

struct EXPANDED_DERIVED <: Class
  baseClass::InstNode
  modifier::Modifier
  dims::Vector{Dimension}
  prefixes::PREFIXES
  attributes::Attributes
  restriction::Restriction
end

struct EXPANDED_CLASS <: Class
  elements::ClassTree
  modifier::Modifier
  prefixes::PREFIXES
  restriction::Restriction
end

struct PARTIAL_BUILTIN <: Class
  ty::ModelicaType
  elements::ClassTree
  modifier::Modifier
  prefixes::PREFIXES
  restriction::Restriction
end

struct PARTIAL_CLASS <: Class
  elements::ClassTree
  modifier::Modifier
  prefixes::PREFIXES
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
              comp = updateComponent!(compComp, comp)
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

"""
    makeRecordExp(clsNode) -> Union{Nothing, Expression}

The record expression of the record class `clsNode` from its fields' (implicit) bindings, or nothing when a field
has no binding. That miss is common (the only caller, `getImplicitBinding`, keeps the unbound binding then) and is
returned, not failed: a failure outside a cheap-throw scope, in a task of the parallel fan-out, records a backtrace
(5-8 per MSL Fluid ThreeTanks).
"""
function makeRecordExp(clsNode::InstNode)::Union{Nothing, Expression}
  local cls::Class
  local ty::ModelicaType
  local ty_node::InstNode
  local fields::Vector{InstNode}
  @assign cls = getClass(clsNode)
  #= (A nested @match bound ty in MetaModelica's scope, an UndefVarError that getImplicitBinding
     swallowed: a record input never got its fields' defaults; omc RecordBinding8.) =#
  ty = getType(cls, clsNode)
  @match TYPE_COMPLEX(complexTy = COMPLEX_RECORD(ty_node)) = ty
  @assign fields = getComponents(classTree(cls))
  local args::Vector{Expression} = Expression[]
  sizehint!(args, length(fields))
  for f in fields
    local b::Binding = getImplicitBinding(component(f))
    hasExp(b) || return nothing
    push!(args, getExp(b))
  end
  return makeRecord(scopePath(ty_node), ty, args)
end

function hasOperator(name::String, cls::Class)::Bool
  local hasOperator::Bool
  local op_node::InstNode
  if isOperatorRecord(restriction(cls))
    op_node = lookupElementNode(name, cls)
    if isvariant(op_node, EMPTY_NODE)
      hasOperator = false
    else
      hasOperator = SCodeUtil.isOperator(definition(op_node))
    end
  else
    hasOperator = false
  end
  return hasOperator
end

function getDerivedComments(cls::Class, cmts::List{<:SCode.COMMENT})::List{SCode.COMMENT}
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

function setPrefixes(prefs::PREFIXES, cls::Class)
  @match cls begin
    EXPANDED_CLASS(__) => begin
      @assign cls.prefixes = prefs
      ()
    end

    EXPANDED_DERIVED(__) => begin
      @assign cls.prefixes = prefs
      ()
    end
  end
  return cls
end

function getPrefixes(cls::Class)
  local prefs::PREFIXES
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
  local resNode = lookupElementNode("equalityConstraint", cls)
  if resNode !== EMPTY_NODE()
    System.setHasOverconstrainedConnectors(true)
    isOverdetermined = true
  else
    isOverdetermined = false
  end
  #=  set the external flag that signals the presence of expandable connectors in the model =#
  return isOverdetermined
end

function isExternalFunction(cls::Class)::Bool
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

function setRestriction(res::Restriction, cls::Class)::Class
   @match cls begin
     EXPANDED_CLASS(__) => begin
       #=  PARTIAL_BUILTIN is only used for predefined builtin types and not needed here. =#
       @assign cls.restriction = res
       ()
     end

     EXPANDED_DERIVED(__) => begin
       @assign cls.restriction = res
       ()
     end

     INSTANCED_CLASS(__) => begin
       @assign cls.restriction = res
       ()
     end

     INSTANCED_BUILTIN(__) => begin
       @assign cls.restriction = res
       ()
     end

     TYPED_DERIVED(__) => begin
       @assign cls.restriction = res
       ()
     end
   end
  return cls
end

function restriction(cls::Class)::Restriction

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

function setType(ty::ModelicaType, @nospecialize(cls::Class))
   @match cls begin
     PARTIAL_BUILTIN(__) => begin
       @assign cls.ty = ty
       ()
     end

     EXPANDED_DERIVED(__) => begin
       @assign cls.baseClass = classApply(cls.baseClass, setType, ty)
       ()
     end

     INSTANCED_CLASS(__) => begin
       @assign cls.ty = ty
       ()
     end

     INSTANCED_BUILTIN(__) => begin
       @assign cls.ty = ty
       ()
     end

     TYPED_DERIVED(__) => begin
       @assign cls.ty = ty
       ()
     end

     _ => begin
       ()
     end
   end
  return cls
end

function getType(cls::Class, clsNode::InstNode)::ModelicaType
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

function hasDimensions(cls::Class)::Bool

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

function mergeModifier(modifier::Modifier, @nospecialize(cls::Class))
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

function setModifier(modifier::Modifier,
                     @nospecialize(cls::Class))
   @match cls begin
     PARTIAL_CLASS(__) => begin
       @assign cls.modifier = modifier
       ()
     end

     EXPANDED_CLASS(__) => begin
       @assign cls.modifier = modifier
       ()
     end

     EXPANDED_DERIVED(__) => begin
       @assign cls.modifier = modifier
       ()
     end

     PARTIAL_BUILTIN(__) => begin
       @assign cls.modifier = modifier
       ()
     end
     _ => begin
       Error.assertion(false, getInstanceName() + " got non-modifiable class", sourceInfo())
       fail()
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

function isBuiltin(cls::Class)::Bool
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

function lookupAttributeValue(name::String, cls::Class)::Option{Expression}
  local value::Option{Expression} = typedExp(lookupAttributeBinding(name, cls))
  return value
end

"""The binding of the attribute `name` (start, fixed, ...) of a class; `EMPTY_BINDING` when the class has none."""
function lookupAttributeBinding(name::String, cls::Class)::Binding
  local attr_node::InstNode = lookupElementNode(name, classTree(cls))
  isvariant(attr_node, COMPONENT_NODE) || return EMPTY_BINDING
  return getBinding(component(attr_node))
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
  local entryInfo = lookupElement(name, classTree(cls))
  return entryInfo
end

"""Node-only sibling of `lookupElement`, dropping the import flag."""
lookupElementNode(name::String, cls::Class)::InstNode = lookupElementNode(name, classTree(cls))

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
  literals::List{<:SCode.ENUM},
  enumType::ModelicaType,
  prefixes::PREFIXES,
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
  prefixes::PREFIXES)
  local cls::Class
  local tree::ClassTree
  tree = fromSCode(elements, isClassExtends, scope)
  cls = PARTIAL_CLASS(tree, MODIFIER_NOMOD(), prefixes)
  return cls
end

function isEqual(prefs1::PREFIXES, prefs2::PREFIXES)::Bool
  local isEqual::Bool = valueEq(prefs1, prefs2)
  return isEqual
end

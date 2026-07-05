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

@UniontypeDecl Attributes
@UniontypeDecl Binding
@UniontypeDecl Branch
@UniontypeDecl CachedData
@UniontypeDecl Call
@UniontypeDecl CallAttributes
@UniontypeDecl Class
@UniontypeDecl ClassTree
@UniontypeDecl ClockKind
@UniontypeDecl Component
@UniontypeDecl Entry
@UniontypeDecl Entry
@UniontypeDecl EvalTarget
@UniontypeDecl Field
@UniontypeDecl FunctionMatchKind
@UniontypeDecl Functionargs
@UniontypeDecl LookupState
@UniontypeDecl LookupStateName
@UniontypeDecl M_Function
@UniontypeDecl MatchedFunction
@UniontypeDecl Modifier
@UniontypeDecl ModifierScope
@UniontypeDecl NFAlgorithm
@UniontypeDecl NFComplexType
@UniontypeDecl NFComponentRef
@UniontypeDecl NFConnection
@UniontypeDecl NFConnections
@UniontypeDecl NFConnector
@UniontypeDecl NFDimension
@UniontypeDecl NFEquation
@UniontypeDecl NFExpandExp
@UniontypeDecl NFExpression
@UniontypeDecl NFExpressionIterator
@UniontypeDecl NFFlatModel
@UniontypeDecl NFFunctionDerivative
@UniontypeDecl NFImport
@UniontypeDecl NFOCConnectionGraph
@UniontypeDecl NFOperator
@UniontypeDecl NFRangeIterator
@UniontypeDecl NFRestriction
@UniontypeDecl NFSections
@UniontypeDecl NFStatement
@UniontypeDecl NFSubscript
#= NFType is a single concrete tagged struct (see NFType.jl for constructors /
   @match registrations / methods). Defined here at the forward-declaration site
   so `::NFType`/`::M_Type`-annotated fields in files loaded before NFType.jl are
   concrete. Uses the raw interface type names (aliases like ComplexType/Dimension
   are not bound yet at this point). =#
#= InstNodeType and InstNode as single concrete tagged structs (hand-written;
   variants are field-disjoint so @CUniontype does not apply). Defined at this
   forward-declaration site (before NFType, which has cls::InstNode) because both
   are referenced by files loaded before NFInstNode.jl. Constructors, singletons,
   @match registrations and methods live in NFInstNode.jl. The graph spine
   (parentScope/parent/inner/outer/locals::InstNode, nodeType::InstNodeType,
   component::Component) is concrete; leaf payloads (cls/definition/exp/caches)
   stay loosely typed to keep this site dependency-light. InstNodeType.parent is
   Any to break the InstNodeType<->InstNode field cycle. =#
@enum InstNodeTypeTag::UInt8 INTY_NORMAL_CLASS INTY_BASE_CLASS INTY_DERIVED_CLASS INTY_BUILTIN_CLASS INTY_TOP_SCOPE INTY_ROOT_CLASS INTY_NORMAL_COMP INTY_REDECLARED_COMP INTY_REDECLARED_CLASS
struct InstNodeType
  tag::InstNodeTypeTag
  parent::Any
  definition::Any
  ty::Union{InstNodeType,Nothing}
  originalType::Union{InstNodeType,Nothing}
end

@enum InstNodeTag::UInt8 IN_EMPTY IN_VAR IN_EXP IN_IMPLICIT_SCOPE IN_NAME IN_REF IN_INNER_OUTER IN_COMPONENT IN_CLASS
mutable struct InstNode
  tag::InstNodeTag
  name::Union{String,Nothing}
  varPointer::Any
  exp::Any
  parentScope::Union{InstNode,Nothing}
  locals::Union{Vector{InstNode},Nothing}
  index::Int
  innerNode::Union{InstNode,Nothing}
  outerNode::Union{InstNode,Nothing}
  visibility::Int8
  component::Union{Component,Nothing}
  parent::Union{InstNode,Nothing}
  nodeType::Union{InstNodeType,Nothing}
  definition::Any
  cls::Any
  caches::Any
end

#= Constructors, singletons, @match (compacted_tag_info) registrations,
   valueConstructor and box-on-share helpers for the tagged node structs above.
   Placed here so registrations exist before any file's @match expands. =#
# Nullary variants: interned singletons.
const _INTY_NORMAL_CLASS = InstNodeType(INTY_NORMAL_CLASS, nothing, nothing, nothing, nothing)
const _INTY_BUILTIN_CLASS = InstNodeType(INTY_BUILTIN_CLASS, nothing, nothing, nothing, nothing)
const _INTY_TOP_SCOPE = InstNodeType(INTY_TOP_SCOPE, nothing, nothing, nothing, nothing)
const _INTY_NORMAL_COMP = InstNodeType(INTY_NORMAL_COMP, nothing, nothing, nothing, nothing)
NORMAL_CLASS()  = _INTY_NORMAL_CLASS
BUILTIN_CLASS() = _INTY_BUILTIN_CLASS
TOP_SCOPE()     = _INTY_TOP_SCOPE
NORMAL_COMP()   = _INTY_NORMAL_COMP

# Data-carrying constructors (positional, matching the old record fields).
BASE_CLASS(parent, definition) = InstNodeType(INTY_BASE_CLASS, parent, definition, nothing, nothing)
DERIVED_CLASS(ty) = InstNodeType(INTY_DERIVED_CLASS, nothing, nothing, ty, nothing)
ROOT_CLASS(parent) = InstNodeType(INTY_ROOT_CLASS, parent, nothing, nothing, nothing)
REDECLARED_COMP(parent) = InstNodeType(INTY_REDECLARED_COMP, parent, nothing, nothing, nothing)
REDECLARED_CLASS(parent, originalType) = InstNodeType(INTY_REDECLARED_CLASS, parent, nothing, nothing, originalType)

# @match / isvariant support.
MetaModelica.compacted_tag_info(::typeof(NORMAL_CLASS))     = (InstNodeType, :tag, INTY_NORMAL_CLASS, ())
MetaModelica.compacted_tag_info(::typeof(BUILTIN_CLASS))    = (InstNodeType, :tag, INTY_BUILTIN_CLASS, ())
MetaModelica.compacted_tag_info(::typeof(TOP_SCOPE))        = (InstNodeType, :tag, INTY_TOP_SCOPE, ())
MetaModelica.compacted_tag_info(::typeof(NORMAL_COMP))      = (InstNodeType, :tag, INTY_NORMAL_COMP, ())
MetaModelica.compacted_tag_info(::typeof(BASE_CLASS))       = (InstNodeType, :tag, INTY_BASE_CLASS, (:parent, :definition))
MetaModelica.compacted_tag_info(::typeof(DERIVED_CLASS))    = (InstNodeType, :tag, INTY_DERIVED_CLASS, (:ty,))
MetaModelica.compacted_tag_info(::typeof(ROOT_CLASS))       = (InstNodeType, :tag, INTY_ROOT_CLASS, (:parent,))
MetaModelica.compacted_tag_info(::typeof(REDECLARED_COMP))  = (InstNodeType, :tag, INTY_REDECLARED_COMP, (:parent,))
MetaModelica.compacted_tag_info(::typeof(REDECLARED_CLASS)) = (InstNodeType, :tag, INTY_REDECLARED_CLASS, (:parent, :originalType))

# One concrete struct -> discriminate by tag (see NFType.jl valueConstructor note).
MetaModelica.valueConstructor(v::InstNodeType) = Int(v.tag)

# Full-field builder (defaults for the slots a given variant does not use).
@inline _innode(tag::InstNodeTag; name=nothing, varPointer=nothing, exp=nothing,
  parentScope=nothing, locals=nothing, index::Int=0, innerNode=nothing,
  outerNode=nothing, visibility::Int8=Int8(0), component=nothing, parent=nothing,
  nodeType=nothing, definition=nothing, cls=nothing, caches=nothing) =
  InstNode(tag, name, varPointer, exp, parentScope, locals, index, innerNode,
           outerNode, visibility, component, parent, nodeType, definition, cls, caches)

# EMPTY_NODE is a shared singleton (sentinel; not mutated).
const _IN_EMPTY = _innode(IN_EMPTY)
EMPTY_NODE() = _IN_EMPTY

# Data-carrying constructors (keep old names + positional field order).
VAR_NODE(name, varPointer) = _innode(IN_VAR; name=name, varPointer=varPointer)
EXP_NODE(exp) = _innode(IN_EXP; exp=exp)
IMPLICIT_SCOPE(parentScope, locals) = _innode(IN_IMPLICIT_SCOPE; parentScope=parentScope, locals=locals)
NAME_NODE(name) = _innode(IN_NAME; name=name)
REF_NODE(index) = _innode(IN_REF; index=index)
INNER_OUTER_NODE(innerNode, outerNode) = _innode(IN_INNER_OUTER; innerNode=innerNode, outerNode=outerNode)
# Hot paths: positional (avoid keyword overhead).
COMPONENT_NODE(name, visibility, component, parent, nodeType) =
  InstNode(IN_COMPONENT, name, nothing, nothing, nothing, nothing, 0, nothing, nothing,
           Int8(visibility), component, parent, nodeType, nothing, nothing, nothing)
COMPONENT_NODE(name, visibility, component::Pointer{Component}, parent, nodeType) =
  COMPONENT_NODE(name, visibility, P_Pointer.access(component), parent, nodeType)
CLASS_NODE(name, definition, visibility, cls, caches, parentScope, nodeType) =
  InstNode(IN_CLASS, name, nothing, nothing, parentScope, nothing, 0, nothing, nothing,
           Int8(visibility), nothing, nothing, nodeType, definition, cls, caches)

# @match / isvariant support.
MetaModelica.compacted_tag_info(::typeof(EMPTY_NODE))       = (InstNode, :tag, IN_EMPTY, ())
MetaModelica.compacted_tag_info(::typeof(VAR_NODE))         = (InstNode, :tag, IN_VAR, (:name, :varPointer))
MetaModelica.compacted_tag_info(::typeof(EXP_NODE))         = (InstNode, :tag, IN_EXP, (:exp,))
MetaModelica.compacted_tag_info(::typeof(IMPLICIT_SCOPE))   = (InstNode, :tag, IN_IMPLICIT_SCOPE, (:parentScope, :locals))
MetaModelica.compacted_tag_info(::typeof(NAME_NODE))        = (InstNode, :tag, IN_NAME, (:name,))
MetaModelica.compacted_tag_info(::typeof(REF_NODE))         = (InstNode, :tag, IN_REF, (:index,))
MetaModelica.compacted_tag_info(::typeof(INNER_OUTER_NODE)) = (InstNode, :tag, IN_INNER_OUTER, (:innerNode, :outerNode))
MetaModelica.compacted_tag_info(::typeof(COMPONENT_NODE))   = (InstNode, :tag, IN_COMPONENT, (:name, :visibility, :component, :parent, :nodeType))
MetaModelica.compacted_tag_info(::typeof(CLASS_NODE))       = (InstNode, :tag, IN_CLASS, (:name, :definition, :visibility, :cls, :caches, :parentScope, :nodeType))

MetaModelica.valueConstructor(v::InstNode) = Int(v.tag)

# P_Pointer.create/createImmutable pick the pointer's type parameter via
# supertype(T); for the concrete InstNode that is Any, which breaks
# Pointer{InstNode} containers. Pin them to InstNode.
P_Pointer.create(data::InstNode) = P_Pointer.Pointer{InstNode}(data)
P_Pointer.createImmutable(data::InstNode) = P_Pointer.Pointer{InstNode}(data)

# Box-on-share hybrid for CLASS_NODE.cls: node.cls holds the Class inlined
# (single owner) or a Pointer{Class} (shared derived/base sites) so a mutation
# through one view is seen through the other.
@inline _clsVal(node) = (local c = node.cls; c isa Pointer{Class} ? c.x : c)
@inline function _clsSet!(node, v::Class)
  local c = node.cls
  if c isa Pointer{Class}
    c.x = v
  else
    node.cls = v
  end
  return node
end
# Ensure node.cls is a shared Ref (box if currently inlined); return the Ref.
@inline function _clsShareRef!(node)
  local c = node.cls
  if c isa Pointer{Class}
    return c
  else
    local r = Pointer{Class}(c)
    node.cls = r
    return r
  end
end

@enum NFTypeTag::UInt8 NFT_INTEGER NFT_REAL NFT_STRING NFT_BOOLEAN NFT_CLOCK NFT_UNKNOWN NFT_ANY NFT_NORETCALL NFT_ENUMERATION_ANY NFT_ARRAY NFT_TUPLE NFT_COMPLEX NFT_FUNCTION NFT_ENUMERATION NFT_METABOXED NFT_POLYMORPHIC NFT_SUBSCRIPTED
struct NFType
  tag::NFTypeTag
  name::Union{String,Nothing}
  ty::Union{NFType,Nothing}
  subs::List{NFType}
  subscriptedTy::Union{NFType,Nothing}
  fn::Union{M_Function,Nothing}
  fnType::Int
  cls::Union{InstNode,Nothing}
  complexTy::Union{NFComplexType,Nothing}
  types::List{NFType}
  names::Option{List{String}}
  elementType::Union{NFType,Nothing}
  dimensions::List{NFDimension}
  typePath::Union{Absyn.Path,Nothing}
  literals::List{String}
end
@UniontypeDecl NFVariable
@UniontypeDecl NFVerifyModel
@UniontypeDecl Prefixes
@UniontypeDecl Replaceable
@UniontypeDecl Slot
@UniontypeDecl Token
@UniontypeDecl TypingError
@UniontypeDecl Unit
@UniontypeDecl VariableConversionSettings


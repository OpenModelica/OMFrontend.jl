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
@UniontypeDecl NFBinding
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
@UniontypeDecl NFModifier
@UniontypeDecl ModifierScope
@UniontypeDecl NFAlgorithm
@UniontypeDecl NFComplexType
@UniontypeDecl NFComponentRef
@UniontypeDecl NFConnection
@UniontypeDecl NFConnections
@UniontypeDecl NFConnector
@UniontypeDecl NFDimension
@UniontypeDecl Equation_Branch
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
const VariabilityType = Int8
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
  definition::Union{SCode.Element,Nothing}
  ty::Union{InstNodeType,Nothing}
  originalType::Union{InstNodeType,Nothing}
end

@enum InstNodeTag::UInt8 IN_EMPTY IN_VAR IN_EXP IN_IMPLICIT_SCOPE IN_NAME IN_REF IN_INNER_OUTER IN_COMPONENT IN_CLASS
#= Immutable identity/structure fields are const (compiler-enforced); the
   payload fields updated in place stay mutable: name, component, nodeType,
   definition, cls. =#
mutable struct InstNode
  const tag::InstNodeTag
  name::Union{String,Nothing}
  const varPointer::Union{Base.RefValue,Nothing}
  const exp::Union{NFExpression,Nothing}
  const parentScope::Union{InstNode,Nothing}
  const locals::Union{Vector{InstNode},Nothing}
  const index::Int
  const innerNode::Union{InstNode,Nothing}
  const outerNode::Union{InstNode,Nothing}
  const visibility::Int8
  component::Union{Component,Nothing}
  const parent::Union{InstNode,Nothing}
  nodeType::Union{InstNodeType,Nothing}
  definition::Union{SCode.Element,Nothing}
  cls::Union{Class,Pointer{Class},Nothing}
  const caches::Union{Vector{CachedData},Nothing}
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

@enum DimensionTag::UInt8 DT_UNKNOWN DT_EXP DT_ENUM DT_BOOLEAN DT_INTEGER DT_UNTYPED DT_RAW_DIM

struct DimensionImpl <: NFDimension
  tag::DimensionTag
  exp::Union{NFExpression,Nothing}
  var::VariabilityType
  enumType::Any
  size::Int
  dimension::Union{NFExpression,Nothing}
  isProcessing::Bool
  dim::Union{Absyn.Subscript,Nothing}
end

@inline _dimension(tag::DimensionTag; exp=nothing,
  var::VariabilityType=Int8(0), enumType=nothing, size::Int=0,
  dimension=nothing, isProcessing::Bool=false, dim=nothing) =
  DimensionImpl(tag, exp, var, enumType, size, dimension, isProcessing, dim)

const DIMENSION_UNKNOWN_SINGLETON = _dimension(DT_UNKNOWN)
const DIMENSION_BOOLEAN_SINGLETON = _dimension(DT_BOOLEAN)
DIMENSION_UNKNOWN() = DIMENSION_UNKNOWN_SINGLETON
DIMENSION_EXP(exp, var) = _dimension(DT_EXP; exp, var=Int8(var))
DIMENSION_ENUM(enumType) = _dimension(DT_ENUM; enumType)
DIMENSION_BOOLEAN() = DIMENSION_BOOLEAN_SINGLETON
DIMENSION_INTEGER(size, var) = _dimension(DT_INTEGER; size=Int(size), var=Int8(var))
DIMENSION_UNTYPED(dimension, isProcessing) =
  _dimension(DT_UNTYPED; dimension, isProcessing)
DIMENSION_RAW_DIM(dim) = _dimension(DT_RAW_DIM; dim)

MetaModelica.compacted_tag_info(::typeof(DIMENSION_UNKNOWN)) = (DimensionImpl, :tag, DT_UNKNOWN, ())
MetaModelica.compacted_tag_info(::typeof(DIMENSION_EXP)) = (DimensionImpl, :tag, DT_EXP, (:exp, :var))
MetaModelica.compacted_tag_info(::typeof(DIMENSION_ENUM)) = (DimensionImpl, :tag, DT_ENUM, (:enumType,))
MetaModelica.compacted_tag_info(::typeof(DIMENSION_BOOLEAN)) = (DimensionImpl, :tag, DT_BOOLEAN, ())
MetaModelica.compacted_tag_info(::typeof(DIMENSION_INTEGER)) = (DimensionImpl, :tag, DT_INTEGER, (:size, :var))
MetaModelica.compacted_tag_info(::typeof(DIMENSION_UNTYPED)) = (DimensionImpl, :tag, DT_UNTYPED, (:dimension, :isProcessing))
MetaModelica.compacted_tag_info(::typeof(DIMENSION_RAW_DIM)) = (DimensionImpl, :tag, DT_RAW_DIM, (:dim,))

MetaModelica.valueConstructor(v::DimensionImpl) = Int(v.tag)

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
  dimensions::List{DimensionImpl}
  typePath::Union{Absyn.Path,Nothing}
  literals::List{String}
end

const NamedArg = Tuple{String,B} where {B <: NFExpression}
const TypedArg = Tuple{A,B,C} where {A,B,C}
const TypedNamedArg = Tuple{String, ExpT, TypeT, VariabilityT} where {ExpT <: NFExpression, TypeT <: NFType, VariabilityT <: Int}

@enum CallTag::UInt8 CT_TYPED_REDUCTION CT_TYPED_ARRAY_CONSTRUCTOR CT_TYPED_CALL CT_ARG_TYPED_CALL CT_UNTYPED_CALL CT_UNTYPED_REDUCTION CT_UNTYPED_ARRAY_CONSTRUCTOR

struct CallImpl <: Call
  tag::CallTag
  fn::Union{M_Function,Nothing}
  ty::Union{NFType,Nothing}
  var::VariabilityType
  exp::Union{NFExpression,Nothing}
  iters::Union{List{Tuple{InstNode, NFExpression}},Nothing}
  defaultExp::Union{Option,Nothing}
  foldExp::Union{Tuple{Option, String, String},Nothing}
  ref::Union{NFComponentRef,Nothing}
  arguments::Union{Vector{NFExpression},Vector{TypedArg},Nothing}
  named_args::Union{Vector{NamedArg},Vector{TypedNamedArg},Nothing}
  call_scope::Union{InstNode,Nothing}
  attributes::Union{CallAttributes,Nothing}
end

@inline _call(tag::CallTag; fn=nothing, ty=nothing,
  var::VariabilityType=Int8(0), exp=nothing, iters=nothing,
  defaultExp=nothing, foldExp=nothing, ref=nothing, arguments=nothing,
  named_args=nothing, call_scope=nothing, attributes=nothing) =
  CallImpl(tag, fn, ty, var, exp, iters, defaultExp, foldExp, ref,
    arguments, named_args, call_scope, attributes)

@inline _callExpressionArgs(arguments::Vector{NFExpression}) = arguments
@inline _callExpressionArgs(arguments) = NFExpression[arguments...]
@inline _callTypedArgs(arguments::Vector{TypedArg}) = arguments
@inline _callTypedArgs(arguments) = TypedArg[arguments...]
@inline _callNamedArgs(named_args::Vector{NamedArg}) = named_args
@inline _callNamedArgs(named_args) = NamedArg[named_args...]
@inline _callTypedNamedArgs(named_args::Vector{TypedNamedArg}) = named_args
@inline _callTypedNamedArgs(named_args) = TypedNamedArg[named_args...]

TYPED_REDUCTION(fn, ty, var, exp, iters, defaultExp, foldExp) =
  _call(CT_TYPED_REDUCTION; fn, ty, var=Int8(var), exp, iters, defaultExp, foldExp)
TYPED_ARRAY_CONSTRUCTOR(ty, var, exp, iters) =
  _call(CT_TYPED_ARRAY_CONSTRUCTOR; ty, var=Int8(var), exp, iters)
TYPED_CALL(fn, ty, var, arguments, attributes) =
  _call(CT_TYPED_CALL; fn, ty, var=Int8(var),
    arguments=_callExpressionArgs(arguments), attributes)
ARG_TYPED_CALL(ref, arguments, named_args, call_scope) =
  _call(CT_ARG_TYPED_CALL; ref,
    arguments=_callTypedArgs(arguments),
    named_args=isempty(named_args) ? TypedNamedArg[] : _callTypedNamedArgs(named_args),
    call_scope)
UNTYPED_CALL(ref, arguments, named_args, call_scope) =
  _call(CT_UNTYPED_CALL; ref,
    arguments=_callExpressionArgs(arguments),
    named_args=isempty(named_args) ? NamedArg[] : _callNamedArgs(named_args),
    call_scope)
UNTYPED_REDUCTION(ref, exp, iters) =
  _call(CT_UNTYPED_REDUCTION; ref, exp, iters)
UNTYPED_ARRAY_CONSTRUCTOR(exp, iters) =
  _call(CT_UNTYPED_ARRAY_CONSTRUCTOR; exp, iters)

MetaModelica.compacted_tag_info(::typeof(TYPED_REDUCTION)) =
  (CallImpl, :tag, CT_TYPED_REDUCTION, (:fn, :ty, :var, :exp, :iters, :defaultExp, :foldExp))
MetaModelica.compacted_tag_info(::typeof(TYPED_ARRAY_CONSTRUCTOR)) =
  (CallImpl, :tag, CT_TYPED_ARRAY_CONSTRUCTOR, (:ty, :var, :exp, :iters))
MetaModelica.compacted_tag_info(::typeof(TYPED_CALL)) =
  (CallImpl, :tag, CT_TYPED_CALL, (:fn, :ty, :var, :arguments, :attributes))
MetaModelica.compacted_tag_info(::typeof(ARG_TYPED_CALL)) =
  (CallImpl, :tag, CT_ARG_TYPED_CALL, (:ref, :arguments, :named_args, :call_scope))
MetaModelica.compacted_tag_info(::typeof(UNTYPED_CALL)) =
  (CallImpl, :tag, CT_UNTYPED_CALL, (:ref, :arguments, :named_args, :call_scope))
MetaModelica.compacted_tag_info(::typeof(UNTYPED_REDUCTION)) =
  (CallImpl, :tag, CT_UNTYPED_REDUCTION, (:ref, :exp, :iters))
MetaModelica.compacted_tag_info(::typeof(UNTYPED_ARRAY_CONSTRUCTOR)) =
  (CallImpl, :tag, CT_UNTYPED_ARRAY_CONSTRUCTOR, (:exp, :iters))

MetaModelica.valueConstructor(v::CallImpl) = Int(v.tag)

@enum BindingTag::UInt8 BT_INVALID BT_CEVAL BT_FLAT BT_TYPED BT_UNTYPED BT_RAW BT_UNBOUND BT_ERROR

mutable struct BindingImpl <: NFBinding
  tag::BindingTag
  binding::Union{BindingImpl,Nothing}
  errors::Union{List,Nothing}
  bindingExp::Union{NFExpression,Absyn.Exp,Nothing}
  bindingType::Union{NFType,Nothing}
  variability::VariabilityType
  eachType::Int
  evaluated::Bool
  isFlattened::Bool
  isProcessing::Bool
  scope::Union{InstNode,Nothing}
  parents::Union{List{InstNode},Nothing}
  isEach::Bool
  info::Union{SourceInfo,Nothing}
end

@inline _binding(tag::BindingTag; binding=nothing, errors=nothing, bindingExp=nothing,
  bindingType=nothing, variability::VariabilityType=Int8(0), eachType::Int=0,
  evaluated::Bool=false, isFlattened::Bool=false, isProcessing::Bool=false,
  scope=nothing, parents=nothing, isEach::Bool=false, info=nothing) =
  BindingImpl(tag, binding, errors, bindingExp, bindingType, variability, eachType,
    evaluated, isFlattened, isProcessing, scope, parents, isEach, info)

INVALID_BINDING(binding, errors) = _binding(BT_INVALID; binding, errors)
CEVAL_BINDING(bindingExp) = _binding(BT_CEVAL; bindingExp)
FLAT_BINDING(bindingExp, variability) =
  _binding(BT_FLAT; bindingExp, variability=Int8(variability))
TYPED_BINDING(bindingExp, bindingType, variability, eachType, evaluated, isFlattened, info) =
  _binding(BT_TYPED; bindingExp, bindingType, variability=Int8(variability),
    eachType=Int(eachType), evaluated, isFlattened, info)
UNTYPED_BINDING(bindingExp, isProcessing, scope, isEach, info) =
  _binding(BT_UNTYPED; bindingExp, isProcessing, scope, isEach, info)
RAW_BINDING(bindingExp, scope, parents, isEach, info) =
  _binding(BT_RAW; bindingExp, scope, parents, isEach, info)
UNBOUND(parents, isEach, info) = _binding(BT_UNBOUND; parents, isEach, info)
BINDING_ERROR() = _binding(BT_ERROR)

MetaModelica.compacted_tag_info(::typeof(INVALID_BINDING)) = (BindingImpl, :tag, BT_INVALID, (:binding, :errors))
MetaModelica.compacted_tag_info(::typeof(CEVAL_BINDING)) = (BindingImpl, :tag, BT_CEVAL, (:bindingExp,))
MetaModelica.compacted_tag_info(::typeof(FLAT_BINDING)) = (BindingImpl, :tag, BT_FLAT, (:bindingExp, :variability))
MetaModelica.compacted_tag_info(::typeof(TYPED_BINDING)) = (BindingImpl, :tag, BT_TYPED, (:bindingExp, :bindingType, :variability, :eachType, :evaluated, :isFlattened, :info))
MetaModelica.compacted_tag_info(::typeof(UNTYPED_BINDING)) = (BindingImpl, :tag, BT_UNTYPED, (:bindingExp, :isProcessing, :scope, :isEach, :info))
MetaModelica.compacted_tag_info(::typeof(RAW_BINDING)) = (BindingImpl, :tag, BT_RAW, (:bindingExp, :scope, :parents, :isEach, :info))
MetaModelica.compacted_tag_info(::typeof(UNBOUND)) = (BindingImpl, :tag, BT_UNBOUND, (:parents, :isEach, :info))
MetaModelica.compacted_tag_info(::typeof(BINDING_ERROR)) = (BindingImpl, :tag, BT_ERROR, ())

MetaModelica.valueConstructor(v::BindingImpl) = Int(v.tag)

include("../NewFrontend/NFModTable.jl")

@enum ModifierTag::UInt8 MT_NOMOD MT_REDECLARE MT_MODIFIER

struct ModifierImpl <: NFModifier
  tag::ModifierTag
  name::Union{String,Nothing}
  finalPrefix::Union{SCode.Final,Nothing}
  eachPrefix::Union{SCode.Each,Nothing}
  binding::Union{BindingImpl,Nothing}
  subModifiers::Union{ModTable.Tree,Nothing}
  info::Union{SourceInfo,Nothing}
  element::Union{InstNode,Nothing}
  mod::Union{ModifierImpl,Nothing}
end

@inline _modifier(tag::ModifierTag; name=nothing, finalPrefix=nothing,
  eachPrefix=nothing, binding=nothing, subModifiers=nothing, info=nothing,
  element=nothing, mod=nothing) =
  ModifierImpl(tag, name, finalPrefix, eachPrefix, binding, subModifiers, info,
    element, mod)

const MODIFIER_NOMOD_SINGLETON = _modifier(MT_NOMOD)
MODIFIER_NOMOD() = MODIFIER_NOMOD_SINGLETON
MODIFIER_REDECLARE(finalPrefix, eachPrefix, element, mod) =
  _modifier(MT_REDECLARE; finalPrefix, eachPrefix, element, mod)
MODIFIER_MODIFIER(name, finalPrefix, eachPrefix, binding, subModifiers, info) =
  _modifier(MT_MODIFIER; name, finalPrefix, eachPrefix, binding, subModifiers, info)

MetaModelica.compacted_tag_info(::typeof(MODIFIER_NOMOD)) = (ModifierImpl, :tag, MT_NOMOD, ())
MetaModelica.compacted_tag_info(::typeof(MODIFIER_REDECLARE)) = (ModifierImpl, :tag, MT_REDECLARE, (:finalPrefix, :eachPrefix, :element, :mod))
MetaModelica.compacted_tag_info(::typeof(MODIFIER_MODIFIER)) = (ModifierImpl, :tag, MT_MODIFIER, (:name, :finalPrefix, :eachPrefix, :binding, :subModifiers, :info))

MetaModelica.valueConstructor(v::ModifierImpl) = Int(v.tag)

@enum EquationTag::UInt8 ET_NORETCALL ET_REINIT ET_TERMINATE ET_ASSERT ET_WHEN ET_RECONFIGURE ET_IF ET_FOR ET_CONNECT ET_ARRAY_EQUALITY ET_CREF_EQUALITY ET_EQUALITY
@enum EquationBranchTag::UInt8 EBT_INVALID_BRANCH EBT_BRANCH

struct EquationImpl <: NFEquation
  tag::EquationTag
  exp::Union{NFExpression,Nothing}
  cref::Union{NFExpression,Nothing}
  reinitExp::Union{NFExpression,Nothing}
  message::Union{NFExpression,Nothing}
  condition::Union{NFExpression,Nothing}
  level::Union{NFExpression,Nothing}
  branches::Union{Vector{Equation_Branch},Nothing}
  variables::Union{MetaModelica.List{Absyn.ElementItem},Nothing}
  whenConditions::Union{Vector,Nothing}
  whenConstraints::Union{Vector,Nothing}
  prompt::Union{Option,Nothing}
  initialEquations::Union{Option,Nothing}
  iterator::Union{InstNode,Nothing}
  range::Union{Option,Nothing}
  body::Union{Vector{EquationImpl},Nothing}
  lhs::Union{NFExpression,NFComponentRef,Nothing}
  rhs::Union{NFExpression,NFComponentRef,Nothing}
  ty::Union{NFType,Nothing}
  source::Union{DAE.ElementSource,Nothing}
end

struct EquationBranchImpl <: Equation_Branch
  tag::EquationBranchTag
  branch::Union{EquationBranchImpl,Nothing}
  errors::Union{Vector,Nothing}
  condition::Union{NFExpression,Nothing}
  conditionVar::Int
  body::Union{Vector{EquationImpl},Nothing}
end

@inline _equation(tag::EquationTag; exp=nothing, cref=nothing, reinitExp=nothing,
  message=nothing, condition=nothing, level=nothing, branches=nothing,
  variables=nothing, whenConditions=nothing, whenConstraints=nothing,
  prompt=nothing, initialEquations=nothing, iterator=nothing, range=nothing,
  body=nothing, lhs=nothing, rhs=nothing, ty=nothing, source=nothing) =
  EquationImpl(tag, exp, cref, reinitExp, message, condition, level, branches,
    variables, whenConditions, whenConstraints, prompt, initialEquations,
    iterator, range, body, lhs, rhs, ty, source)

@inline _equationBranch(tag::EquationBranchTag; branch=nothing, errors=nothing,
  condition=nothing, conditionVar::Int=0, body=nothing) =
  EquationBranchImpl(tag, branch, errors, condition, conditionVar, body)

EQUATION_NORETCALL(exp, source) = _equation(ET_NORETCALL; exp, source)
EQUATION_REINIT(cref, reinitExp, source) =
  _equation(ET_REINIT; cref, reinitExp, source)
EQUATION_TERMINATE(message, source) = _equation(ET_TERMINATE; message, source)
EQUATION_ASSERT(condition, message, level, source) =
  _equation(ET_ASSERT; condition, message, level, source)
EQUATION_WHEN(branches, source) = _equation(ET_WHEN; branches, source)
EQUATION_RECONFIGURE(variables, whenConditions, whenConstraints, prompt,
  initialEquations, source) =
  _equation(ET_RECONFIGURE; variables, whenConditions, whenConstraints, prompt,
    initialEquations, source)
EQUATION_IF(branches, source) = _equation(ET_IF; branches, source)
EQUATION_FOR(iterator, range, body, source) =
  _equation(ET_FOR; iterator, range, body, source)
EQUATION_CONNECT(lhs, rhs, source) = _equation(ET_CONNECT; lhs, rhs, source)
EQUATION_ARRAY_EQUALITY(lhs, rhs, ty, source) =
  _equation(ET_ARRAY_EQUALITY; lhs, rhs, ty, source)
EQUATION_CREF_EQUALITY(lhs, rhs, source) =
  _equation(ET_CREF_EQUALITY; lhs, rhs, source)
EQUATION_EQUALITY(lhs, rhs, ty, source) =
  _equation(ET_EQUALITY; lhs, rhs, ty, source)

EQUATION_INVALID_BRANCH(branch, errors) =
  _equationBranch(EBT_INVALID_BRANCH; branch, errors)
EQUATION_BRANCH(condition, conditionVar, body) =
  _equationBranch(EBT_BRANCH; condition, conditionVar=Int(conditionVar), body)

MetaModelica.compacted_tag_info(::typeof(EQUATION_NORETCALL)) = (EquationImpl, :tag, ET_NORETCALL, (:exp, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_REINIT)) = (EquationImpl, :tag, ET_REINIT, (:cref, :reinitExp, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_TERMINATE)) = (EquationImpl, :tag, ET_TERMINATE, (:message, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_ASSERT)) = (EquationImpl, :tag, ET_ASSERT, (:condition, :message, :level, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_WHEN)) = (EquationImpl, :tag, ET_WHEN, (:branches, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_RECONFIGURE)) = (EquationImpl, :tag, ET_RECONFIGURE, (:variables, :whenConditions, :whenConstraints, :prompt, :initialEquations, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_IF)) = (EquationImpl, :tag, ET_IF, (:branches, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_FOR)) = (EquationImpl, :tag, ET_FOR, (:iterator, :range, :body, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_CONNECT)) = (EquationImpl, :tag, ET_CONNECT, (:lhs, :rhs, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_ARRAY_EQUALITY)) = (EquationImpl, :tag, ET_ARRAY_EQUALITY, (:lhs, :rhs, :ty, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_CREF_EQUALITY)) = (EquationImpl, :tag, ET_CREF_EQUALITY, (:lhs, :rhs, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_EQUALITY)) = (EquationImpl, :tag, ET_EQUALITY, (:lhs, :rhs, :ty, :source))
MetaModelica.compacted_tag_info(::typeof(EQUATION_INVALID_BRANCH)) = (EquationBranchImpl, :tag, EBT_INVALID_BRANCH, (:branch, :errors))
MetaModelica.compacted_tag_info(::typeof(EQUATION_BRANCH)) = (EquationBranchImpl, :tag, EBT_BRANCH, (:condition, :conditionVar, :body))

MetaModelica.valueConstructor(v::EquationImpl) = Int(v.tag)
MetaModelica.valueConstructor(v::EquationBranchImpl) = Int(v.tag)

@enum StatementTag::UInt8 ST_FAILURE ST_BREAK ST_RETURN ST_WHILE ST_NORETCALL ST_TERMINATE ST_ASSERT ST_WHEN ST_IF ST_FOR ST_FUNCTION_ARRAY_INIT ST_ASSIGNMENT

struct StatementImpl <: NFStatement
  tag::StatementTag
  body::Union{Vector{StatementImpl},Nothing}
  source::Union{DAE.ElementSource,Nothing}
  condition::Union{NFExpression,Nothing}
  exp::Union{NFExpression,Nothing}
  message::Union{NFExpression,Nothing}
  level::Union{NFExpression,Nothing}
  branches::Union{Vector{Tuple{NFExpression, Vector{StatementImpl}}},Nothing}
  iterator::Union{InstNode,Nothing}
  range::Union{Option,Nothing}
  name::Union{String,Nothing}
  ty::Union{NFType,Nothing}
  lhs::Union{NFExpression,Nothing}
  rhs::Union{NFExpression,Nothing}
end

@inline _statement(tag::StatementTag; body=nothing, source=nothing,
  condition=nothing, exp=nothing, message=nothing, level=nothing,
  branches=nothing, iterator=nothing, range=nothing, name=nothing,
  ty=nothing, lhs=nothing, rhs=nothing) =
  StatementImpl(tag, body, source, condition, exp, message, level, branches,
    iterator, range, name, ty, lhs, rhs)

ALG_FAILURE(body, source) = _statement(ST_FAILURE; body, source)
ALG_BREAK(source) = _statement(ST_BREAK; source)
ALG_RETURN(source) = _statement(ST_RETURN; source)
ALG_WHILE(condition, body, source) =
  _statement(ST_WHILE; condition, body, source)
ALG_NORETCALL(exp, source) = _statement(ST_NORETCALL; exp, source)
ALG_TERMINATE(message, source) = _statement(ST_TERMINATE; message, source)
ALG_ASSERT(condition, message, level, source) =
  _statement(ST_ASSERT; condition, message, level, source)
ALG_WHEN(branches, source) = _statement(ST_WHEN; branches, source)
ALG_IF(branches, source) = _statement(ST_IF; branches, source)
ALG_FOR(iterator, range, body, source) =
  _statement(ST_FOR; iterator, range, body, source)
ALG_FUNCTION_ARRAY_INIT(name, ty, source) =
  _statement(ST_FUNCTION_ARRAY_INIT; name, ty, source)
ALG_ASSIGNMENT(lhs, rhs, ty, source) =
  _statement(ST_ASSIGNMENT; lhs, rhs, ty, source)

MetaModelica.compacted_tag_info(::typeof(ALG_FAILURE)) = (StatementImpl, :tag, ST_FAILURE, (:body, :source))
MetaModelica.compacted_tag_info(::typeof(ALG_BREAK)) = (StatementImpl, :tag, ST_BREAK, (:source,))
MetaModelica.compacted_tag_info(::typeof(ALG_RETURN)) = (StatementImpl, :tag, ST_RETURN, (:source,))
MetaModelica.compacted_tag_info(::typeof(ALG_WHILE)) = (StatementImpl, :tag, ST_WHILE, (:condition, :body, :source))
MetaModelica.compacted_tag_info(::typeof(ALG_NORETCALL)) = (StatementImpl, :tag, ST_NORETCALL, (:exp, :source))
MetaModelica.compacted_tag_info(::typeof(ALG_TERMINATE)) = (StatementImpl, :tag, ST_TERMINATE, (:message, :source))
MetaModelica.compacted_tag_info(::typeof(ALG_ASSERT)) = (StatementImpl, :tag, ST_ASSERT, (:condition, :message, :level, :source))
MetaModelica.compacted_tag_info(::typeof(ALG_WHEN)) = (StatementImpl, :tag, ST_WHEN, (:branches, :source))
MetaModelica.compacted_tag_info(::typeof(ALG_IF)) = (StatementImpl, :tag, ST_IF, (:branches, :source))
MetaModelica.compacted_tag_info(::typeof(ALG_FOR)) = (StatementImpl, :tag, ST_FOR, (:iterator, :range, :body, :source))
MetaModelica.compacted_tag_info(::typeof(ALG_FUNCTION_ARRAY_INIT)) = (StatementImpl, :tag, ST_FUNCTION_ARRAY_INIT, (:name, :ty, :source))
MetaModelica.compacted_tag_info(::typeof(ALG_ASSIGNMENT)) = (StatementImpl, :tag, ST_ASSIGNMENT, (:lhs, :rhs, :ty, :source))

MetaModelica.valueConstructor(v::StatementImpl) = Int(v.tag)

struct AlgorithmImpl <: NFAlgorithm
  statements::Vector{StatementImpl}
  source::DAE.ElementSource
end

const ALGORITHM = AlgorithmImpl

@UniontypeDecl NFVariable
@UniontypeDecl NFVerifyModel
@UniontypeDecl Prefixes
@UniontypeDecl Replaceable
@UniontypeDecl Slot
@UniontypeDecl Token
@UniontypeDecl TypingError
@UniontypeDecl Unit
@UniontypeDecl VariableConversionSettings

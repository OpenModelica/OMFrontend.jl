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
#= InstNode is immutable: updates rebuild the node shell. Mutable payload cells
   (CLASS_NODE.cls, COMPONENT_NODE.component, VAR_NODE.varPointer) are shared
   across shell rebuilds so every alias observes payload updates. =#
struct InstNode
  tag::InstNodeTag
  name::Union{String,Nothing}
  varPointer::Union{Base.RefValue,Nothing}
  exp::Union{NFExpression,Nothing}
  parentScope::Union{InstNode,Nothing}
  locals::Union{Vector{InstNode},Nothing}
  index::Int
  innerNode::Union{InstNode,Nothing}
  outerNode::Union{InstNode,Nothing}
  visibility::Int8
  component::Union{Component,Pointer{Component},Nothing}
  parent::Union{InstNode,Nothing}
  nodeType::Union{InstNodeType,Nothing}
  definition::Union{SCode.Element,Nothing}
  cls::Union{Class,Pointer{Class},Nothing}
  caches::Union{Vector{CachedData},Nothing}
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
@inline _compPayload(component::Pointer{Component}) = component
@inline _compPayload(component::Component) = Pointer{Component}(component)
@inline _compPayload(::Nothing) = nothing
COMPONENT_NODE(name, visibility, component, parent, nodeType) =
  InstNode(IN_COMPONENT, name, nothing, nothing, nothing, nothing, 0, nothing, nothing,
           Int8(visibility), _compPayload(component), parent, nodeType, nothing, nothing, nothing)
@inline _clsPayload(cls::Pointer{Class}) = cls
@inline _clsPayload(cls::Class) = Pointer{Class}(cls)
@inline _clsPayload(cls::Nothing) = nothing
CLASS_NODE(name, definition, visibility, cls, caches, parentScope, nodeType) =
  InstNode(IN_CLASS, name, nothing, nothing, parentScope, nothing, 0, nothing, nothing,
           Int8(visibility), nothing, nothing, nodeType, definition, _clsPayload(cls), caches)

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

#= Compact show: default field-recursive show would walk the whole node graph
   (cyclic through the payload cells) and never terminate. =#
function Base.show(io::IO, node::InstNode)
  print(io, "InstNode(", node.tag)
  if node.name isa String
    print(io, ", \"", node.name, "\"")
  end
  print(io, ")")
end

# P_Pointer.create/createImmutable pick the pointer's type parameter via
# supertype(T); for the concrete InstNode that is Any, which breaks
# Pointer{InstNode} containers. Pin them to InstNode.
P_Pointer.create(data::InstNode) = P_Pointer.Pointer{InstNode}(data)
P_Pointer.createImmutable(data::InstNode) = P_Pointer.Pointer{InstNode}(data)

@T_Uniontype NFDimension begin
  DIMENSION_UNKNOWN()
  DIMENSION_EXP(exp::NFExpression, var::VariabilityType = Int8(0))
  DIMENSION_ENUM(enumType::Any)
  DIMENSION_BOOLEAN()
  DIMENSION_INTEGER(size::Int = 0, var::VariabilityType = Int8(0))
  DIMENSION_UNTYPED(dimension::NFExpression, isProcessing::Bool = false)
  DIMENSION_RAW_DIM(dim::Absyn.Subscript)
end

# Boxed CLASS_NODE.cls payload. The node itself is rebuilt functionally while
# shared derived/base class views still observe updates through the class cell.
@inline _clsVal(node) = (local c = node.cls; c isa Pointer{Class} ? c.x : c)
@inline function _clsSet!(node, v::Class)
  local c = node.cls
  if c isa Pointer{Class}
    c.x = v
  end
  return node
end
# Return the class cell used for derived/base sharing.
@inline function _clsRef(node)
  local c = node.cls
  if c isa Pointer{Class}
    return c
  else
    return Pointer{Class}(c)
  end
end

# Boxed COMPONENT_NODE.component payload; same cell-sharing scheme as cls.
@inline _compVal(node) = (local c = node.component; c isa Pointer{Component} ? c.x : c)
@inline function _compSet!(node, v::Component)
  local c = node.component
  if c isa Pointer{Component}
    c.x = v
  end
  return node
end
# Return the component cell used for instance-pointer sharing.
@inline function _compRef(node)
  local c = node.component
  if c isa Pointer{Component}
    return c
  else
    return Pointer{Component}(c)
  end
end

#= O(1) stable node identity: the payload cell pointer. Never objectid an
   InstNode directly; that content-hashes the whole reachable immutable graph
   (parent chains, SCode definitions). =#
@inline function _refId(node)::UInt
  local c = node.component
  c isa Pointer{Component} && return objectid(c)
  local k = node.cls
  k isa Pointer{Class} && return objectid(k)
  local v = node.varPointer
  v isa Base.RefValue && return objectid(v)
  return objectid(node)
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
  dimensions::List{NFDimensionImpl}
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

@T_Uniontype mutable NFBinding begin
  INVALID_BINDING(binding::NFBinding, errors::List)
  CEVAL_BINDING(bindingExp::Union{NFExpression,Absyn.Exp})
  FLAT_BINDING(bindingExp::Union{NFExpression,Absyn.Exp}, variability::VariabilityType = Int8(0))
  TYPED_BINDING(bindingExp::Union{NFExpression,Absyn.Exp}, bindingType::NFType, variability::VariabilityType = Int8(0), eachType::Int = 0, evaluated::Bool = false, isFlattened::Bool = false, info::SourceInfo)
  UNTYPED_BINDING(bindingExp::Union{NFExpression,Absyn.Exp}, isProcessing::Bool = false, scope::InstNode, isEach::Bool = false, info::SourceInfo)
  RAW_BINDING(bindingExp::Union{NFExpression,Absyn.Exp}, scope::InstNode, parents::List{InstNode}, isEach::Bool = false, info::SourceInfo)
  UNBOUND(parents::List{InstNode}, isEach::Bool = false, info::SourceInfo)
  BINDING_ERROR()
end

include("../NewFrontend/NFModTable.jl")

@T_Uniontype NFModifier begin
  MODIFIER_NOMOD()
  MODIFIER_REDECLARE(finalPrefix::SCode.Final, eachPrefix::SCode.Each, element::InstNode, mod::NFModifier)
  MODIFIER_MODIFIER(name::String, finalPrefix::SCode.Final, eachPrefix::SCode.Each, binding::NFBindingImpl, subModifiers::ModTable.Tree, info::SourceInfo)
end

@T_Uniontype NFEquation begin
  EQUATION_NORETCALL(exp::NFExpression, source::DAE.ElementSource)
  EQUATION_REINIT(cref::NFExpression, reinitExp::NFExpression, source::DAE.ElementSource)
  EQUATION_TERMINATE(message::NFExpression, source::DAE.ElementSource)
  EQUATION_ASSERT(condition::NFExpression, message::NFExpression, level::NFExpression, source::DAE.ElementSource)
  EQUATION_WHEN(branches::Vector{Equation_Branch}, source::DAE.ElementSource)
  EQUATION_RECONFIGURE(variables::MetaModelica.List{Absyn.ElementItem}, whenConditions::Vector, whenConstraints::Vector, prompt::Option, initialEquations::Option, source::DAE.ElementSource)
  EQUATION_IF(branches::Vector{Equation_Branch}, source::DAE.ElementSource)
  EQUATION_FOR(iterator::InstNode, range::Option, body::Vector{NFEquation}, source::DAE.ElementSource)
  EQUATION_CONNECT(lhs::Union{NFExpression,NFComponentRef}, rhs::Union{NFExpression,NFComponentRef}, source::DAE.ElementSource)
  EQUATION_ARRAY_EQUALITY(lhs::Union{NFExpression,NFComponentRef}, rhs::Union{NFExpression,NFComponentRef}, ty::NFType, source::DAE.ElementSource)
  EQUATION_CREF_EQUALITY(lhs::Union{NFExpression,NFComponentRef}, rhs::Union{NFExpression,NFComponentRef}, source::DAE.ElementSource)
  EQUATION_EQUALITY(lhs::Union{NFExpression,NFComponentRef}, rhs::Union{NFExpression,NFComponentRef}, ty::NFType, source::DAE.ElementSource)
end

@T_Uniontype Equation_Branch begin
  EQUATION_INVALID_BRANCH(branch::Equation_Branch, errors::Vector)
  EQUATION_BRANCH(condition::NFExpression, conditionVar::Int = 0, body::Vector{NFEquationImpl})
end

@T_Uniontype NFStatement begin
  ALG_FAILURE(body::Vector{NFStatement}, source::DAE.ElementSource)
  ALG_BREAK(source::DAE.ElementSource)
  ALG_RETURN(source::DAE.ElementSource)
  ALG_WHILE(condition::NFExpression, body::Vector{NFStatement}, source::DAE.ElementSource)
  ALG_NORETCALL(exp::NFExpression, source::DAE.ElementSource)
  ALG_TERMINATE(message::NFExpression, source::DAE.ElementSource)
  ALG_ASSERT(condition::NFExpression, message::NFExpression, level::NFExpression, source::DAE.ElementSource)
  ALG_WHEN(branches::Vector{Tuple{NFExpression, Vector{NFStatement}}}, source::DAE.ElementSource)
  ALG_IF(branches::Vector{Tuple{NFExpression, Vector{NFStatement}}}, source::DAE.ElementSource)
  ALG_FOR(iterator::InstNode, range::Option, body::Vector{NFStatement}, source::DAE.ElementSource)
  ALG_FUNCTION_ARRAY_INIT(name::String, ty::NFType, source::DAE.ElementSource)
  ALG_ASSIGNMENT(lhs::NFExpression, rhs::NFExpression, ty::NFType, source::DAE.ElementSource)
end

struct AlgorithmImpl <: NFAlgorithm
  statements::Vector{NFStatementImpl}
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

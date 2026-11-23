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
@UniontypeDecl Branch
@UniontypeDecl CachedData
@UniontypeDecl Class
@UniontypeDecl ClockKind
@UniontypeDecl Component
@UniontypeDecl Entry
@UniontypeDecl Entry
@UniontypeDecl EvalTarget
@UniontypeDecl Field
@UniontypeDecl FunctionMatchKind
@UniontypeDecl LookupState
@UniontypeDecl LookupStateName
@UniontypeDecl MatchedFunction
@UniontypeDecl ModifierScope
@UniontypeDecl ComplexType
@UniontypeDecl Expression
@UniontypeDecl ExpressionIterator
@UniontypeDecl Import
@UniontypeDecl RangeIterator
@UniontypeDecl Restriction
@UniontypeDecl Sections
@UniontypeDecl Subscript
const VariabilityType = Int8
#= InstNodeType and InstNode as single concrete tagged structs (hand-written;
   variants are field-disjoint so @CUniontype does not apply). Defined at this
   forward-declaration site (before ModelicaType, which has cls::InstNode) because both
   are referenced by files loaded before InstNode.jl. Constructors, singletons,
   @match registrations and methods live in InstNode.jl. The graph spine
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

"""
The cell of a class node's class, shared by the node's shell rebuilds: `Base.RefValue`, the concrete type behind
`Pointer` (= `Ref`, abstract), so that `c.x` reads and writes are static (with `isa Pointer{Class}` they were dynamic
`getproperty`/`setproperty!` calls: 2026-11-21, about 6% of a HeatingSystem flatten).
"""
const ClassCell = Base.RefValue{Class}
"""The cell of a component node's component; see `ClassCell`."""
const ComponentCell = Base.RefValue{Component}

@enum InstNodeTag::UInt8 IN_EMPTY IN_VAR IN_EXP IN_IMPLICIT_SCOPE IN_NAME IN_REF IN_INNER_OUTER IN_COMPONENT IN_CLASS
#= InstNode is immutable: updates rebuild the node shell. Mutable payload cells
   (CLASS_NODE.cls, COMPONENT_NODE.component, VAR_NODE.varPointer) are shared
   across shell rebuilds so every alias observes payload updates. =#
struct InstNode
  tag::InstNodeTag
  name::Union{String,Nothing}
  varPointer::Union{Base.RefValue,Nothing}
  exp::Union{Expression,Nothing}
  parentScope::Union{InstNode,Nothing}
  locals::Union{Vector{InstNode},Nothing}
  index::Int
  innerNode::Union{InstNode,Nothing}
  outerNode::Union{InstNode,Nothing}
  visibility::Int8
  component::Union{Component,ComponentCell,Nothing}
  parent::Union{InstNode,Nothing}
  nodeType::Union{InstNodeType,Nothing}
  definition::Union{SCode.Element,Nothing}
  cls::Union{Class,ClassCell,Nothing}
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

# One concrete struct -> discriminate by tag (see Type.jl valueConstructor note).
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
@inline _compPayload(component::ComponentCell) = component
@inline _compPayload(component::Component) = ComponentCell(component)
@inline _compPayload(::Nothing) = nothing
COMPONENT_NODE(name, visibility, component, parent, nodeType) =
  InstNode(IN_COMPONENT, name, nothing, nothing, nothing, nothing, 0, nothing, nothing,
           Int8(visibility), _compPayload(component), parent, nodeType, nothing, nothing, nothing)
@inline _clsPayload(cls::ClassCell) = cls
@inline _clsPayload(cls::Class) = ClassCell(cls)
@inline _clsPayload(::Nothing) = nothing
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

@enum DimensionTag::UInt8 DIMENSION_UNKNOWN_TAG DIMENSION_EXP_TAG DIMENSION_ENUM_TAG DIMENSION_BOOLEAN_TAG DIMENSION_INTEGER_TAG DIMENSION_UNTYPED_TAG DIMENSION_RAW_DIM_TAG
"""
    Dimension

An array dimension: one tagged struct for all variants (`tag`), each field used by the variants named here.

- `DIMENSION_UNKNOWN()`, `DIMENSION_BOOLEAN()`: no fields (shared singletons).
- `DIMENSION_EXP(exp, var = Int8(0))`: a dimension given by an expression `exp` of variability `var`.
- `DIMENSION_ENUM(enumType)`: the literals of the enumeration type `enumType`.
- `DIMENSION_INTEGER(size = 0, var = Int8(0))`: a known size.
- `DIMENSION_UNTYPED(dimension, isProcessing = false)`: a dimension expression not typed yet; `isProcessing` marks
  one being typed (cycle detection).
- `DIMENSION_RAW_DIM(dim, scope = nothing)`: the Absyn subscript as declared; `scope` is where it was declared
  (omc `RAW_DIM(dim, scope)`), `nothing` for the component's parent.

Each variant also has a keyword constructor (`DIMENSION_EXP(; exp, var)`). Fields a variant does not use hold
`nothing` or the default shown.
"""
struct Dimension
  tag::DimensionTag
  exp::Union{Nothing, Expression}
  var::VariabilityType
  enumType::Any
  size::Int
  dimension::Union{Nothing, Expression}
  isProcessing::Bool
  dim::Union{Nothing, Absyn.Subscript}
  scope::Any
end

const _DIMENSION_UNKNOWN = Dimension(DIMENSION_UNKNOWN_TAG, nothing, Int8(0), nothing, 0, nothing, false, nothing, nothing)
const _DIMENSION_BOOLEAN = Dimension(DIMENSION_BOOLEAN_TAG, nothing, Int8(0), nothing, 0, nothing, false, nothing, nothing)
DIMENSION_UNKNOWN() = _DIMENSION_UNKNOWN
DIMENSION_BOOLEAN() = _DIMENSION_BOOLEAN
DIMENSION_EXP(exp, var = Int8(0)) =
  Dimension(DIMENSION_EXP_TAG, exp, var, nothing, 0, nothing, false, nothing, nothing)
DIMENSION_EXP(; exp, var = Int8(0)) = DIMENSION_EXP(exp, var)
DIMENSION_ENUM(enumType) =
  Dimension(DIMENSION_ENUM_TAG, nothing, Int8(0), enumType, 0, nothing, false, nothing, nothing)
DIMENSION_ENUM(; enumType) = DIMENSION_ENUM(enumType)
DIMENSION_INTEGER(size) = DIMENSION_INTEGER(size, Int8(0))
DIMENSION_INTEGER(size, var) =
  Dimension(DIMENSION_INTEGER_TAG, nothing, var, nothing, size, nothing, false, nothing, nothing)
DIMENSION_INTEGER(; size = 0, var = Int8(0)) = DIMENSION_INTEGER(size, var)
DIMENSION_UNTYPED(dimension, isProcessing = false) =
  Dimension(DIMENSION_UNTYPED_TAG, nothing, Int8(0), nothing, 0, dimension, isProcessing, nothing, nothing)
DIMENSION_UNTYPED(; dimension, isProcessing = false) = DIMENSION_UNTYPED(dimension, isProcessing)
DIMENSION_RAW_DIM(dim, scope = nothing) =
  Dimension(DIMENSION_RAW_DIM_TAG, nothing, Int8(0), nothing, 0, nothing, false, dim, scope)
DIMENSION_RAW_DIM(; dim, scope = nothing) = DIMENSION_RAW_DIM(dim, scope)

@registerVariants Dimension begin
  DIMENSION_UNKNOWN()
  DIMENSION_EXP(exp, var)
  DIMENSION_ENUM(enumType)
  DIMENSION_BOOLEAN()
  DIMENSION_INTEGER(size, var)
  DIMENSION_UNTYPED(dimension, isProcessing)
  DIMENSION_RAW_DIM(dim, scope)
end

# Boxed CLASS_NODE.cls payload. The node itself is rebuilt functionally while
# shared derived/base class views still observe updates through the class cell.
@inline _clsVal(node) = (local c = node.cls; c isa ClassCell ? c.x : c)
@inline function _clsSet!(node, v::Class)
  local c = node.cls
  if c isa ClassCell
    c.x = v
  end
  return node
end
# Return the class cell used for derived/base sharing.
@inline function _clsRef(node)
  local c = node.cls
  if c isa ClassCell
    return c
  else
    return ClassCell(c)
  end
end

# Boxed COMPONENT_NODE.component payload; same cell-sharing scheme as cls.
@inline _compVal(node) = (local c = node.component; c isa ComponentCell ? c.x : c)
@inline function _compSet!(node, v::Component)
  local c = node.component
  if c isa ComponentCell
    c.x = v
  end
  return node
end
# Return the component cell used for instance-pointer sharing.
@inline function _compRef(node)
  local c = node.component
  if c isa ComponentCell
    return c
  else
    return ComponentCell(c)
  end
end

#= O(1) stable node identity: the payload cell pointer. Never objectid an
   InstNode directly; that content-hashes the whole reachable immutable graph
   (parent chains, SCode definitions). =#
@inline function _refId(node)::UInt
  local c = node.component
  c isa ComponentCell && return objectid(c)
  local k = node.cls
  k isa ClassCell && return objectid(k)
  local v = node.varPointer
  v isa Base.RefValue && return objectid(v)
  return objectid(node)
end

@enum ModelicaTypeTag::UInt8 NFT_INTEGER NFT_REAL NFT_STRING NFT_BOOLEAN NFT_CLOCK NFT_UNKNOWN NFT_ANY NFT_NORETCALL NFT_ENUMERATION_ANY NFT_ARRAY NFT_TUPLE NFT_COMPLEX NFT_FUNCTION NFT_ENUMERATION NFT_METABOXED NFT_POLYMORPHIC NFT_SUBSCRIPTED
"""
    ModelicaTypeImpl{F}

The type struct, used as `ModelicaType = ModelicaTypeImpl{MODELICA_FUNCTION}` (defined below `MODELICA_FUNCTION`).
One tagged struct for all variants (`tag`); constructors, `@match` registrations and methods are in Type.jl.

A function type (`TYPE_FUNCTION`) holds its function and a function holds its return type: Julia has no forward
declaration of a concrete struct, so the function's type is a parameter here and `MODELICA_FUNCTION` names
`ModelicaTypeImpl{MODELICA_FUNCTION}`, itself, in its field. Both stay concrete. Use `ModelicaType` everywhere else.
"""
struct ModelicaTypeImpl{F}
  tag::ModelicaTypeTag
  name::Union{String,Nothing}
  ty::Union{ModelicaTypeImpl{F},Nothing}
  subs::List{ModelicaTypeImpl{F}}
  subscriptedTy::Union{ModelicaTypeImpl{F},Nothing}
  fn::Union{F,Nothing}
  fnType::Int
  cls::Union{InstNode,Nothing}
  complexTy::Union{ComplexType,Nothing}
  types::List{ModelicaTypeImpl{F}}
  names::Option{List{String}}
  elementType::Union{ModelicaTypeImpl{F},Nothing}
  dimensions::List{Dimension}
  typePath::Union{Absyn.Path,Nothing}
  literals::List{String}
end

"""Which arguments a function's slot accepts: one of the `SLOT_TYPE_*` constants."""
const SlotType = UInt8
"""Only positional arguments."""
const SLOT_TYPE_POSITIONAL::SlotType = 0x01
"""Only named arguments."""
const SLOT_TYPE_NAMED::SlotType = 0x02
"""Positional and named arguments."""
const SLOT_TYPE_GENERIC::SlotType = 0x03

"""Whether a slot's default value is evaluated: `SLOT_NOT_EVALUATED`, `SLOT_EVALUATING` or `SLOT_EVALUATED`."""
const SlotEvalStatus = UInt8
const SLOT_NOT_EVALUATED::SlotEvalStatus = 0x01
"""The slot's default is being evaluated (a default that depends on itself is an error)."""
const SLOT_EVALUATING::SlotEvalStatus = 0x02
const SLOT_EVALUATED::SlotEvalStatus = 0x03

"""How far a function has been processed: one of the `FUNCTION_STATUS_*` constants."""
const FunctionStatus = UInt8
"""A builtin function."""
const FUNCTION_STATUS_BUILTIN::FunctionStatus = 0x01
"""The initial status."""
const FUNCTION_STATUS_INITIAL::FunctionStatus = 0x02
"""The constants in the function have been evaluated (EvalConstants)."""
const FUNCTION_STATUS_EVALUATED::FunctionStatus = 0x03
"""The function has been simplified (SimplifyModel)."""
const FUNCTION_STATUS_SIMPLIFIED::FunctionStatus = 0x04
"""The function has been added to the function tree."""
const FUNCTION_STATUS_COLLECTED::FunctionStatus = 0x05

"""A condition of a `derivative` annotation on an input: one of the `DERIVATIVE_CONDITION_*` constants."""
const DerivativeCondition = UInt8
"""`zeroDerivative = u`: the derivative applies where `u`'s derivative is zero."""
const DERIVATIVE_CONDITION_ZERO_DERIVATIVE::DerivativeCondition = 0x01
"""`noDerivative = u`: `u` is not differentiated."""
const DERIVATIVE_CONDITION_NO_DERIVATIVE::DerivativeCondition = 0x02

"""A typed positional argument of a call: `(exp, ty, variability)`."""
const TypedArg = Tuple{A,B,C} where {A,B,C}

"""
    SLOT(name, ty, default, arg, index, evalStatus)

An input of a function as a call fills it: its `name`, which arguments it takes (`ty`, a `SlotType`), its
`default` value, the argument matched to it (`arg`), its position (`index`), and whether its default is being or
has been evaluated (`evalStatus`, a `SlotEvalStatus`). Functions on slots are in Function.jl.
"""
struct SLOT
  name::String
  ty::SlotType
  default::Option{Expression}
  arg::Option{TypedArg}
  index::Int
  evalStatus::SlotEvalStatus
end

"""
    FUNCTION_DER(derivativeFn, derivedFn, order, conditions, lowerOrderDerivatives)

A `derivative` annotation of a function: `derivativeFn` is the derivative of `derivedFn` of order `order`;
`conditions` are its `zeroDerivative`/`noDerivative` inputs `(index, name, DerivativeCondition)`. Functions on it are
in FunctionDerivative.jl.
"""
struct FUNCTION_DER
  derivativeFn::InstNode
  derivedFn::InstNode
  order::Expression
  conditions::List{Tuple{Int, String, DerivativeCondition}}
  lowerOrderDerivatives::List{InstNode}
end

"""How a function or a call is inlined (omc's DAE.InlineType): one of the `*_INLINE` constants."""
const InlineType = UInt8
"""`annotation(Inline = true)`."""
const NORM_INLINE::InlineType = 0x00
"""A builtin function inlined before the other functions (a builtin function pointer)."""
const BUILTIN_EARLY_INLINE::InlineType = 0x01
"""`annotation(__OpenModelica_EarlyInline = true)`."""
const EARLY_INLINE::InlineType = 0x02
"""No inline annotation: the backend decides."""
const DEFAULT_INLINE::InlineType = 0x03
"""`annotation(Inline = false)`, and calls that are never inlined."""
const NO_INLINE::InlineType = 0x04
"""`annotation(LateInline = true)`: inlined after index reduction."""
const AFTER_INDEX_RED_INLINE::InlineType = 0x05

"""Whether and how a function is builtin: one of the `FUNCTION_*BUILTIN*` constants."""
const BuiltinKind = UInt8
"""A function defined in Modelica (or external)."""
const FUNCTION_NOT_BUILTIN::BuiltinKind = 0x00
"""A builtin function of the language (`abs`, `sin`, ...)."""
const FUNCTION_BUILTIN::BuiltinKind = 0x01
"""A builtin function referenced through a function pointer (`__OpenModelica_builtinPtr`)."""
const FUNCTION_BUILTIN_PTR::BuiltinKind = 0x02

"""
    FUNCTION_ATTRIBUTES(inline, isImpure, isFunctionPointer, builtin, builtinName, unboxArgs)

The attributes of a function: how it is inlined (`inline`, an `InlineType`), whether it is impure, whether it is a
function-pointer variable, whether it is builtin (`builtin`, a `BuiltinKind`) and the name its calls use then
(`builtinName`, `nothing` for the function's own name), and whether a builtin's arguments are unboxed.
"""
struct FUNCTION_ATTRIBUTES
  inline::InlineType
  isImpure::Bool
  isFunctionPointer::Bool
  builtin::BuiltinKind
  builtinName::Option{String}
  unboxArgs::Bool
end

"""The attributes of a builtin function."""
const FUNCTION_ATTRIBUTES_BUILTIN = FUNCTION_ATTRIBUTES(NO_INLINE, false, false, FUNCTION_BUILTIN, nothing, false)
"""The attributes of a function without annotations."""
const FUNCTION_ATTRIBUTES_DEFAULT = FUNCTION_ATTRIBUTES(DEFAULT_INLINE, false, false, FUNCTION_NOT_BUILTIN, nothing, false)

#= Before Call, which holds one. =#
"""A Modelica function: its interface (the body is read from its node)."""
struct MODELICA_FUNCTION
  path::Absyn.Path
  node::InstNode
  inputs::List{InstNode}
  outputs::List{InstNode}
  locals::List{InstNode}
  slots::List{SLOT}
  returnType::ModelicaTypeImpl{MODELICA_FUNCTION}
  attributes::FUNCTION_ATTRIBUTES
  derivatives::List{FUNCTION_DER}
  #= the FunctionStatus, shared by the function's copies =#
  status::Base.RefValue{FunctionStatus}
  #= the evaluation depth key (NFEvalFunction), shared by the copies =#
  callCounter::Base.RefValue{Int}
  #= The inputs a partial derivative of a function is taken with respect to, by index
     (`function df = der(f, x)`; omc derivedInputs), empty for other functions. =#
  derivedInputs::List{Int}
  #= One constructor for all argument types (docstring below the struct). =#
  function MODELICA_FUNCTION(@nospecialize(path::Absyn.Path), @nospecialize(node::InstNode), @nospecialize(inputs::List),
                      @nospecialize(outputs::List), @nospecialize(locals::List), @nospecialize(slots::List),
                      @nospecialize(returnType::ModelicaTypeImpl{MODELICA_FUNCTION}), @nospecialize(attributes::FUNCTION_ATTRIBUTES),
                      @nospecialize(derivatives::List), status::Base.RefValue{FunctionStatus},
                      callCounter::Base.RefValue{Int}, @nospecialize(derivedInputs::List))
    return new(path, node, inputs, outputs, locals, slots, returnType, attributes, derivatives, status, callCounter,
               derivedInputs)
  end
end

"""The type of a Modelica expression or component (see `ModelicaTypeImpl`)."""
const ModelicaType = ModelicaTypeImpl{MODELICA_FUNCTION}

"""
    OPERATOR(ty, op)

A unary, binary, logical or relational operator: `op` is one of the `Op` values (`Op.ADD`, `Op.MUL_EW`, ...), `ty`
the type it operates on. Functions on operators are in Operator.jl.
"""
struct OPERATOR
  ty::ModelicaType
  op::Int
end

@enum ComponentRefTag::UInt8 COMPONENT_REF_WILD_TAG COMPONENT_REF_EMPTY_TAG COMPONENT_REF_CREF_TAG
"""
    ComponentRef

A component reference (`a.b[1].c`): one tagged struct for all variants (`tag`).

- `COMPONENT_REF_WILD()`: `_` in an output list; `COMPONENT_REF_EMPTY()`: the end of a cref (shared singletons).
- `COMPONENT_REF_CREF(node, subscripts, ty, origin, restCref)`: the last part, `node` with its `subscripts` and
  type `ty`; `origin` is one of `Origin.CREF`, `Origin.SCOPE`, `Origin.ITERATOR`; `restCref` is the cref of the
  parts before it (`COMPONENT_REF_EMPTY()` for the first). Read from the last part to the first.

A variant's fields are the first ones of the struct; for `WILD` and `EMPTY` the others stay `#undef` (never read).
Defined here, before the structs that hold one (`Call`, `Equation`). Functions on crefs are in ComponentRef.jl.
"""
struct ComponentRef
  tag::ComponentRefTag
  node::InstNode
  subscripts::List{Subscript}
  ty::ModelicaType
  origin::Int
  restCref::ComponentRef
  ComponentRef(tag) = new(tag)
  ComponentRef(tag, node, subscripts, ty, origin, restCref) = new(tag, node, subscripts, ty, origin, restCref)
end

const _COMPONENT_REF_WILD = ComponentRef(COMPONENT_REF_WILD_TAG)
const _COMPONENT_REF_EMPTY = ComponentRef(COMPONENT_REF_EMPTY_TAG)
COMPONENT_REF_WILD() = _COMPONENT_REF_WILD
COMPONENT_REF_EMPTY() = _COMPONENT_REF_EMPTY
COMPONENT_REF_CREF(node, subscripts, ty, origin, restCref) =
  ComponentRef(COMPONENT_REF_CREF_TAG, node, subscripts, ty, origin, restCref)
COMPONENT_REF_CREF(; node, subscripts, ty, origin, restCref) = COMPONENT_REF_CREF(node, subscripts, ty, origin, restCref)

@registerVariants ComponentRef begin
  COMPONENT_REF_WILD()
  COMPONENT_REF_EMPTY()
  COMPONENT_REF_CREF(node, subscripts, ty, origin, restCref)
end

"""`@assign` on a `ComponentRef`: rebuilt from its variant's own fields (the default reads the `#undef` ones)."""
function MetaModelica.Accessors.ConstructionBase.setproperties(obj::ComponentRef, patch::NamedTuple)
  obj.tag === COMPONENT_REF_CREF_TAG || return obj
  local pick(f::Symbol) = haskey(patch, f) ? getfield(patch, f) : getfield(obj, f)
  return ComponentRef(COMPONENT_REF_CREF_TAG, pick(:node), pick(:subscripts), pick(:ty), pick(:origin), pick(:restCref))
end

"""
    MODELICA_FUNCTION(path, node, inputs, outputs, locals, slots, returnType, attributes, derivatives, status, callCounter[, derivedInputs])

A function. One constructor for all argument types (the default one was compiled per combination of `Cons`/`Nil`
lists and path kinds at run time). The lists are `List` of any element type, as the default constructor took them:
`new` converts them to the field types (a `Cons{Any}` built at run time). `derivedInputs` defaults to `nil`.
"""
MODELICA_FUNCTION(@nospecialize(path::Absyn.Path), @nospecialize(node::InstNode), @nospecialize(inputs::List),
           @nospecialize(outputs::List), @nospecialize(locals::List), @nospecialize(slots::List),
           @nospecialize(returnType::ModelicaType), @nospecialize(attributes::FUNCTION_ATTRIBUTES),
           @nospecialize(derivatives::List), status::Base.RefValue{FunctionStatus}, callCounter::Base.RefValue{Int}) =
  MODELICA_FUNCTION(path, node, inputs, outputs, locals, slots, returnType, attributes, derivatives, status, callCounter, nil)

const NamedArg = Tuple{String,B} where {B <: Expression}
const TypedNamedArg = Tuple{String, ExpT, TypeT, VariabilityT} where {ExpT <: Expression, TypeT <: ModelicaType, VariabilityT <: Int}

"""
    CALL_ATTR(tuple_, builtin, isImpure, isFunctionPointerCall, inlineType)

The attributes of a typed call (`TYPED_CALL.attributes`): whether the function returns a tuple, is a builtin, is
impure or is called through a function pointer, and how it is inlined (an `InlineType`).
"""
struct CALL_ATTR
  tuple_::Bool
  builtin::Bool
  isImpure::Bool
  isFunctionPointerCall::Bool
  inlineType::InlineType
end

@enum CallTag::UInt8 TYPED_REDUCTION_TAG TYPED_ARRAY_CONSTRUCTOR_TAG TYPED_CALL_TAG ARG_TYPED_CALL_TAG UNTYPED_CALL_TAG UNTYPED_REDUCTION_TAG UNTYPED_ARRAY_CONSTRUCTOR_TAG
"""
    Call

A function call, a reduction or an array constructor: one tagged struct for all variants (`tag`). Held by
`CALL_EXPRESSION`. Instantiation builds the untyped variants, typing replaces them by the typed ones.

- `UNTYPED_CALL(ref, arguments, named_args, call_scope)`: a call of the function `ref` as written, in `call_scope`.
- `ARG_TYPED_CALL(ref, arguments, named_args, call_scope)`: its arguments typed (`TypedArg`, `TypedNamedArg`),
  the function not yet matched.
- `TYPED_CALL(fn, ty, var, arguments, attributes)`: a call of the matched function `fn`, of type `ty` and
  variability `var`, with its `CALL_ATTR`.
- `UNTYPED_REDUCTION(ref, exp, iters)`, `TYPED_REDUCTION(fn, ty, var, exp, iters, defaultExp, foldExp)`: a
  reduction (`sum(x[i] for i in 1:n)`) of `exp` over the iterators `iters`.
- `UNTYPED_ARRAY_CONSTRUCTOR(exp, iters)`, `TYPED_ARRAY_CONSTRUCTOR(ty, var, exp, iters)`: `{exp for iters}`.

The fields a variant does not have are `nothing` (`var` is 0).
"""
struct Call
  tag::CallTag
  fn::Union{MODELICA_FUNCTION,Nothing}
  ty::Union{ModelicaType,Nothing}
  var::VariabilityType
  exp::Union{Expression,Nothing}
  iters::Union{List{Tuple{InstNode, Expression}},Nothing}
  defaultExp::Union{Option,Nothing}
  foldExp::Union{Tuple{Option, String, String},Nothing}
  ref::Union{ComponentRef,Nothing}
  arguments::Union{Vector{Expression},Vector{TypedArg},Nothing}
  named_args::Union{Vector{NamedArg},Vector{TypedNamedArg},Nothing}
  call_scope::Union{InstNode,Nothing}
  attributes::Union{CALL_ATTR,Nothing}
end

@inline _call(tag::CallTag; fn=nothing, ty=nothing,
  var::VariabilityType=Int8(0), exp=nothing, iters=nothing,
  defaultExp=nothing, foldExp=nothing, ref=nothing, arguments=nothing,
  named_args=nothing, call_scope=nothing, attributes=nothing) =
  Call(tag, fn, ty, var, exp, iters, defaultExp, foldExp, ref,
    arguments, named_args, call_scope, attributes)

@inline _callExpressionArgs(arguments::Vector{Expression}) = arguments
@inline _callExpressionArgs(arguments) = Expression[arguments...]
@inline _callTypedArgs(arguments::Vector{TypedArg}) = arguments
@inline _callTypedArgs(arguments) = TypedArg[arguments...]
@inline _callNamedArgs(named_args::Vector{NamedArg}) = named_args
@inline _callNamedArgs(named_args) = NamedArg[named_args...]
@inline _callTypedNamedArgs(named_args::Vector{TypedNamedArg}) = named_args
@inline _callTypedNamedArgs(named_args) = TypedNamedArg[named_args...]

TYPED_REDUCTION(fn, ty, var, exp, iters, defaultExp, foldExp) =
  _call(TYPED_REDUCTION_TAG; fn, ty, var=Int8(var), exp, iters, defaultExp, foldExp)
TYPED_ARRAY_CONSTRUCTOR(ty, var, exp, iters) =
  _call(TYPED_ARRAY_CONSTRUCTOR_TAG; ty, var=Int8(var), exp, iters)
TYPED_CALL(fn, ty, var, arguments, attributes) =
  _call(TYPED_CALL_TAG; fn, ty, var=Int8(var),
    arguments=_callExpressionArgs(arguments), attributes)
ARG_TYPED_CALL(ref, arguments, named_args, call_scope) =
  _call(ARG_TYPED_CALL_TAG; ref,
    arguments=_callTypedArgs(arguments),
    named_args=isempty(named_args) ? TypedNamedArg[] : _callTypedNamedArgs(named_args),
    call_scope)
UNTYPED_CALL(ref, arguments, named_args, call_scope) =
  _call(UNTYPED_CALL_TAG; ref,
    arguments=_callExpressionArgs(arguments),
    named_args=isempty(named_args) ? NamedArg[] : _callNamedArgs(named_args),
    call_scope)
UNTYPED_REDUCTION(ref, exp, iters) =
  _call(UNTYPED_REDUCTION_TAG; ref, exp, iters)
UNTYPED_ARRAY_CONSTRUCTOR(exp, iters) =
  _call(UNTYPED_ARRAY_CONSTRUCTOR_TAG; exp, iters)

@registerVariants Call begin
  TYPED_REDUCTION(fn, ty, var, exp, iters, defaultExp, foldExp)
  TYPED_ARRAY_CONSTRUCTOR(ty, var, exp, iters)
  TYPED_CALL(fn, ty, var, arguments, attributes)
  ARG_TYPED_CALL(ref, arguments, named_args, call_scope)
  UNTYPED_CALL(ref, arguments, named_args, call_scope)
  UNTYPED_REDUCTION(ref, exp, iters)
  UNTYPED_ARRAY_CONSTRUCTOR(exp, iters)
end

"""The expression of a binding: Absyn before instantiation, NF after, `nothing` for the variants without one."""
const BindingExpField = Union{Nothing, Expression, Absyn.Exp}

@enum BindingTag::UInt8 INVALID_BINDING_TAG CEVAL_BINDING_TAG FLAT_BINDING_TAG TYPED_BINDING_TAG UNTYPED_BINDING_TAG RAW_BINDING_TAG UNBOUND_TAG BINDING_ERROR_TAG
"""
    Binding

The binding of a component or modifier: one mutable tagged struct for all variants (`tag`). Mutable: typing and
evaluation update a binding in place.

- `RAW_BINDING(bindingExp, scope, parents, isEach = false, info)`: the Absyn expression as written, in `scope`;
  `parents` are the components it was propagated from.
- `UNTYPED_BINDING(bindingExp, isProcessing = false, scope, isEach = false, info)`: instantiated, not typed;
  `isProcessing` marks one being typed (cycle detection).
- `TYPED_BINDING(bindingExp, bindingType, variability = Int8(0), eachType = 0, evaluated = false,
  isFlattened = false, info)`: typed.
- `FLAT_BINDING(bindingExp, variability = Int8(0))`: flattened.
- `CEVAL_BINDING(bindingExp)`: a value from constant evaluation.
- `UNBOUND(parents, isEach = false, info)`: no binding.
- `INVALID_BINDING(binding, errors)`: a binding that failed, with its errors.
- `BINDING_ERROR()`: no fields.

Each variant also has a keyword constructor. Fields a variant does not use hold `nothing` or the default shown.
"""
mutable struct Binding
  tag::BindingTag
  binding::Union{Nothing, Binding}
  errors::Union{Nothing, List}
  bindingExp::BindingExpField
  variability::VariabilityType
  bindingType::Union{Nothing, ModelicaType}
  eachType::Int
  evaluated::Bool
  isFlattened::Bool
  info::Union{Nothing, SourceInfo}
  isProcessing::Bool
  scope::Union{Nothing, InstNode}
  isEach::Bool
  parents::Union{Nothing, List{InstNode}}
end

"""A `Binding` of variant `tag` with the given fields, the others empty."""
@inline _binding(tag::BindingTag; binding = nothing, errors = nothing, bindingExp = nothing, variability = Int8(0),
                 bindingType = nothing, eachType = 0, evaluated = false, isFlattened = false, info = nothing,
                 isProcessing = false, scope = nothing, isEach = false, parents = nothing) =
  Binding(tag, binding, errors, bindingExp, variability, bindingType, eachType, evaluated, isFlattened, info,
          isProcessing, scope, isEach, parents)

INVALID_BINDING(binding, errors) = _binding(INVALID_BINDING_TAG; binding, errors)
INVALID_BINDING(; binding, errors) = INVALID_BINDING(binding, errors)
CEVAL_BINDING(bindingExp) = _binding(CEVAL_BINDING_TAG; bindingExp)
CEVAL_BINDING(; bindingExp) = CEVAL_BINDING(bindingExp)
FLAT_BINDING(bindingExp, variability = Int8(0)) = _binding(FLAT_BINDING_TAG; bindingExp, variability)
FLAT_BINDING(; bindingExp, variability = Int8(0)) = FLAT_BINDING(bindingExp, variability)
TYPED_BINDING(bindingExp, bindingType, variability, eachType, evaluated, isFlattened, info) =
  _binding(TYPED_BINDING_TAG; bindingExp, bindingType, variability, eachType, evaluated, isFlattened, info)
TYPED_BINDING(; bindingExp, bindingType, variability = Int8(0), eachType = 0, evaluated = false, isFlattened = false,
              info) =
  TYPED_BINDING(bindingExp, bindingType, variability, eachType, evaluated, isFlattened, info)
UNTYPED_BINDING(bindingExp, isProcessing, scope, isEach, info) =
  _binding(UNTYPED_BINDING_TAG; bindingExp, isProcessing, scope, isEach, info)
UNTYPED_BINDING(; bindingExp, isProcessing = false, scope, isEach = false, info) =
  UNTYPED_BINDING(bindingExp, isProcessing, scope, isEach, info)
RAW_BINDING(bindingExp, scope, parents, isEach, info) =
  _binding(RAW_BINDING_TAG; bindingExp, scope, parents, isEach, info)
RAW_BINDING(; bindingExp, scope, parents, isEach = false, info) = RAW_BINDING(bindingExp, scope, parents, isEach, info)
UNBOUND(parents, isEach, info) = _binding(UNBOUND_TAG; parents, isEach, info)
UNBOUND(; parents, isEach = false, info) = UNBOUND(parents, isEach, info)
BINDING_ERROR() = _binding(BINDING_ERROR_TAG)

@registerVariants Binding begin
  INVALID_BINDING(binding, errors)
  CEVAL_BINDING(bindingExp)
  FLAT_BINDING(bindingExp, variability)
  TYPED_BINDING(bindingExp, bindingType, variability, eachType, evaluated, isFlattened, info)
  UNTYPED_BINDING(bindingExp, isProcessing, scope, isEach, info)
  RAW_BINDING(bindingExp, scope, parents, isEach, info)
  UNBOUND(parents, isEach, info)
  BINDING_ERROR()
end

@enum ModifierTag::UInt8 MODIFIER_NOMOD_TAG MODIFIER_REDECLARE_TAG MODIFIER_MODIFIER_TAG
"""
    ModifierImpl{T}

The modifier struct, used as `Modifier = ModifierImpl{ModTable.Tree}` (defined below the `ModTable` module). A
modifier holds its submodifiers in a `ModTable.Tree` and the tree holds modifiers: Julia has no forward declaration
of a concrete struct, so the tree's type is a parameter here and the tree names `ModifierImpl{Tree}`, itself, in
its field. Both stay concrete. Use `Modifier` everywhere else.

One tagged struct for all variants (`tag`):
- `MODIFIER_NOMOD()`: no modifier (a shared singleton).
- `MODIFIER_REDECLARE(finalPrefix, eachPrefix, element, innerMod, outerMod, constrainingMod, propagatedParents = nil)`:
  a redeclaration of `element`. `innerMod`: the modifiers inside the redeclare, for the original declaration only;
  `outerMod`: those outside it, for the redeclared element; `constrainingMod`: the redeclare's constraining clause
  (omc). `propagatedParents`: the arrays of components the modifier was split over (innermost first; omc
  `propagatedSubs`), the parents of the redeclared element's own bindings.
- `MODIFIER_MODIFIER(name, finalPrefix, eachPrefix, binding, subModifiers, info)`: a modifier of the element `name`.

Each variant also has a keyword constructor. Fields a variant does not use hold `nothing` (`propagatedParents`:
`nil`).
"""
struct ModifierImpl{T}
  tag::ModifierTag
  finalPrefix::Union{Nothing, SCode.Final}
  eachPrefix::Union{Nothing, SCode.Each}
  element::Union{Nothing, InstNode}
  innerMod::Union{Nothing, ModifierImpl{T}}
  outerMod::Union{Nothing, ModifierImpl{T}}
  constrainingMod::Union{Nothing, ModifierImpl{T}}
  propagatedParents::Any
  name::Union{Nothing, String}
  binding::Union{Nothing, Binding}
  subModifiers::Union{Nothing, T}
  info::Union{Nothing, SourceInfo}
end

include("../Frontend/ModTable.jl")

"""A modifier (see `ModifierImpl`)."""
const Modifier = ModifierImpl{ModTable.Tree}

const _MODIFIER_NOMOD =
  Modifier(MODIFIER_NOMOD_TAG, nothing, nothing, nothing, nothing, nothing, nothing, nil, nothing, nothing, nothing, nothing)
MODIFIER_NOMOD() = _MODIFIER_NOMOD
MODIFIER_REDECLARE(finalPrefix, eachPrefix, element, innerMod, outerMod, constrainingMod, propagatedParents = nil) =
  Modifier(MODIFIER_REDECLARE_TAG, finalPrefix, eachPrefix, element, innerMod, outerMod, constrainingMod,
           propagatedParents, nothing, nothing, nothing, nothing)
MODIFIER_REDECLARE(; finalPrefix, eachPrefix, element, innerMod, outerMod, constrainingMod, propagatedParents = nil) =
  MODIFIER_REDECLARE(finalPrefix, eachPrefix, element, innerMod, outerMod, constrainingMod, propagatedParents)
MODIFIER_MODIFIER(name, finalPrefix, eachPrefix, binding, subModifiers, info) =
  Modifier(MODIFIER_MODIFIER_TAG, finalPrefix, eachPrefix, nothing, nothing, nothing, nothing, nil, name, binding,
           subModifiers, info)
MODIFIER_MODIFIER(; name, finalPrefix, eachPrefix, binding, subModifiers, info) =
  MODIFIER_MODIFIER(name, finalPrefix, eachPrefix, binding, subModifiers, info)

@registerVariants Modifier begin
  MODIFIER_NOMOD()
  MODIFIER_REDECLARE(finalPrefix, eachPrefix, element, innerMod, outerMod, constrainingMod, propagatedParents)
  MODIFIER_MODIFIER(name, finalPrefix, eachPrefix, binding, subModifiers, info)
end

"""One side of an equation: an expression, a component reference (connect), or `nothing` (no sides)."""
const EquationOperand = Union{Nothing, Expression, ComponentRef}

@enum EquationBranchTag::UInt8 EQUATION_INVALID_BRANCH_TAG EQUATION_BRANCH_TAG
"""
    EquationBranchImpl{E}

A branch of an if- or when-equation, used as `EquationBranch = EquationBranchImpl{Equation}` (defined below
`Equation`). A branch holds equations and an equation holds branches: Julia has no forward declaration of a
concrete struct, so the equation type is a parameter here and `Equation` names `EquationBranchImpl{Equation}`,
itself, in its field. Both stay concrete. Use `EquationBranch` everywhere else.

One tagged struct for both variants (`tag`):
- `EQUATION_BRANCH(condition, conditionVar = 0, body)`: `body` holds when `condition` does; `conditionVar` is the
  condition's variability.
- `EQUATION_INVALID_BRANCH(branch, errors)`: a branch that failed typing, with its errors.
"""
struct EquationBranchImpl{E}
  tag::EquationBranchTag
  branch::Union{Nothing, EquationBranchImpl{E}}
  errors::Union{Nothing, Vector}
  condition::Union{Nothing, Expression}
  conditionVar::Int
  body::Union{Nothing, Vector{E}}
end

@enum EquationTag::UInt8 EQUATION_NORETCALL_TAG EQUATION_REINIT_TAG EQUATION_TERMINATE_TAG EQUATION_ASSERT_TAG EQUATION_WHEN_TAG EQUATION_RECONFIGURE_TAG EQUATION_IF_TAG EQUATION_FOR_TAG EQUATION_CONNECT_TAG EQUATION_ARRAY_EQUALITY_TAG EQUATION_CREF_EQUALITY_TAG EQUATION_EQUALITY_TAG
"""
    Equation

An equation: one tagged struct for all variants (`tag`). Every variant has its `source`.

- `EQUATION_EQUALITY(lhs, rhs, ty, source)`: `lhs = rhs` of type `ty`.
- `EQUATION_ARRAY_EQUALITY(lhs, rhs, ty, source)`: an array `lhs = rhs`, kept as one equation.
- `EQUATION_CREF_EQUALITY(lhs, rhs, source)`: `lhs = rhs` between two component references.
- `EQUATION_CONNECT(lhs, rhs, source)`: `connect(lhs, rhs)`.
- `EQUATION_FOR(iterator, range, body, source)`: a for-equation; `range` is `nothing` for an implicit range.
- `EQUATION_IF(branches, source)`, `EQUATION_WHEN(branches, source)`: if- and when-equations.
- `EQUATION_ASSERT(condition, message, level, source)`, `EQUATION_TERMINATE(message, source)`,
  `EQUATION_REINIT(cref, reinitExp, source)`, `EQUATION_NORETCALL(exp, source)`: the operators.
- `EQUATION_RECONFIGURE(variables, whenConditions, whenConstraints, prompt, initialEquations, source)`.

Each variant also has a keyword constructor. Fields a variant does not use hold `nothing`.
"""
struct Equation
  tag::EquationTag
  exp::Union{Nothing, Expression}
  source::SourceInfo
  cref::Union{Nothing, Expression}
  reinitExp::Union{Nothing, Expression}
  message::Union{Nothing, Expression}
  condition::Union{Nothing, Expression}
  level::Union{Nothing, Expression}
  branches::Union{Nothing, Vector{EquationBranchImpl{Equation}}}
  variables::Union{Nothing, MetaModelica.List{Absyn.ElementItem}}
  whenConditions::Union{Nothing, Vector}
  whenConstraints::Union{Nothing, Vector}
  prompt::Union{Nothing, Option}
  initialEquations::Union{Nothing, Option}
  iterator::Union{Nothing, InstNode}
  range::Union{Nothing, Option}
  body::Union{Nothing, Vector{Equation}}
  lhs::EquationOperand
  rhs::EquationOperand
  ty::Union{Nothing, ModelicaType}
end

"""A branch of an if- or when-equation (see `EquationBranchImpl`)."""
const EquationBranch = EquationBranchImpl{Equation}

#= `@assign x.f = v` rebuilds `x` with `ConstructionBase.constructorof(typeof(x))`, by default the type's UnionAll
   (`ModifierImpl`): Julia then infers the parameter from the field values at run time, at every `@assign` on a
   modifier, type or branch (EmptyTanks: 5.7% of a flatten). The concrete type is its own constructor. =#
ConstructionBase.constructorof(::Type{T}) where {T <: ModelicaTypeImpl} = T
ConstructionBase.constructorof(::Type{T}) where {T <: ModifierImpl} = T
ConstructionBase.constructorof(::Type{T}) where {T <: EquationBranchImpl} = T

"""An `Equation` of variant `tag` with the given fields, the others `nothing`."""
@inline _equation(tag::EquationTag, source; exp = nothing, cref = nothing, reinitExp = nothing, message = nothing,
                  condition = nothing, level = nothing, branches = nothing, variables = nothing,
                  whenConditions = nothing, whenConstraints = nothing, prompt = nothing, initialEquations = nothing,
                  iterator = nothing, range = nothing, body = nothing, lhs = nothing, rhs = nothing, ty = nothing) =
  Equation(tag, exp, source, cref, reinitExp, message, condition, level, branches, variables, whenConditions,
           whenConstraints, prompt, initialEquations, iterator, range, body, lhs, rhs, ty)

EQUATION_NORETCALL(exp, source) = _equation(EQUATION_NORETCALL_TAG, source; exp)
EQUATION_NORETCALL(; exp, source) = EQUATION_NORETCALL(exp, source)
EQUATION_REINIT(cref, reinitExp, source) = _equation(EQUATION_REINIT_TAG, source; cref, reinitExp)
EQUATION_REINIT(; cref, reinitExp, source) = EQUATION_REINIT(cref, reinitExp, source)
EQUATION_TERMINATE(message, source) = _equation(EQUATION_TERMINATE_TAG, source; message)
EQUATION_TERMINATE(; message, source) = EQUATION_TERMINATE(message, source)
EQUATION_ASSERT(condition, message, level, source) = _equation(EQUATION_ASSERT_TAG, source; condition, message, level)
EQUATION_ASSERT(; condition, message, level, source) = EQUATION_ASSERT(condition, message, level, source)
EQUATION_WHEN(branches, source) = _equation(EQUATION_WHEN_TAG, source; branches)
EQUATION_WHEN(; branches, source) = EQUATION_WHEN(branches, source)
EQUATION_RECONFIGURE(variables, whenConditions, whenConstraints, prompt, initialEquations, source) =
  _equation(EQUATION_RECONFIGURE_TAG, source; variables, whenConditions, whenConstraints, prompt, initialEquations)
EQUATION_RECONFIGURE(; variables, whenConditions, whenConstraints, prompt, initialEquations, source) =
  EQUATION_RECONFIGURE(variables, whenConditions, whenConstraints, prompt, initialEquations, source)
EQUATION_IF(branches, source) = _equation(EQUATION_IF_TAG, source; branches)
EQUATION_IF(; branches, source) = EQUATION_IF(branches, source)
EQUATION_FOR(iterator, range, body, source) = _equation(EQUATION_FOR_TAG, source; iterator, range, body)
EQUATION_FOR(; iterator, range, body, source) = EQUATION_FOR(iterator, range, body, source)
EQUATION_CONNECT(lhs, rhs, source) = _equation(EQUATION_CONNECT_TAG, source; lhs, rhs)
EQUATION_CONNECT(; lhs, rhs, source) = EQUATION_CONNECT(lhs, rhs, source)
EQUATION_ARRAY_EQUALITY(lhs, rhs, ty, source) = _equation(EQUATION_ARRAY_EQUALITY_TAG, source; lhs, rhs, ty)
EQUATION_ARRAY_EQUALITY(; lhs, rhs, ty, source) = EQUATION_ARRAY_EQUALITY(lhs, rhs, ty, source)
EQUATION_CREF_EQUALITY(lhs, rhs, source) = _equation(EQUATION_CREF_EQUALITY_TAG, source; lhs, rhs)
EQUATION_CREF_EQUALITY(; lhs, rhs, source) = EQUATION_CREF_EQUALITY(lhs, rhs, source)
EQUATION_EQUALITY(lhs, rhs, ty, source) = _equation(EQUATION_EQUALITY_TAG, source; lhs, rhs, ty)
EQUATION_EQUALITY(; lhs, rhs, ty, source) = EQUATION_EQUALITY(lhs, rhs, ty, source)

@registerVariants Equation begin
  EQUATION_NORETCALL(exp, source)
  EQUATION_REINIT(cref, reinitExp, source)
  EQUATION_TERMINATE(message, source)
  EQUATION_ASSERT(condition, message, level, source)
  EQUATION_WHEN(branches, source)
  EQUATION_RECONFIGURE(variables, whenConditions, whenConstraints, prompt, initialEquations, source)
  EQUATION_IF(branches, source)
  EQUATION_FOR(iterator, range, body, source)
  EQUATION_CONNECT(lhs, rhs, source)
  EQUATION_ARRAY_EQUALITY(lhs, rhs, ty, source)
  EQUATION_CREF_EQUALITY(lhs, rhs, source)
  EQUATION_EQUALITY(lhs, rhs, ty, source)
end

EQUATION_INVALID_BRANCH(branch, errors) = EquationBranch(EQUATION_INVALID_BRANCH_TAG, branch, errors, nothing, 0, nothing)
EQUATION_INVALID_BRANCH(; branch, errors) = EQUATION_INVALID_BRANCH(branch, errors)
EQUATION_BRANCH(condition, conditionVar, body) =
  EquationBranch(EQUATION_BRANCH_TAG, nothing, nothing, condition, conditionVar, body)
EQUATION_BRANCH(; condition, conditionVar = 0, body) = EQUATION_BRANCH(condition, conditionVar, body)

@registerVariants EquationBranch begin
  EQUATION_INVALID_BRANCH(branch, errors)
  EQUATION_BRANCH(condition, conditionVar, body)
end

@enum StatementTag::UInt8 ALG_FAILURE_TAG ALG_BREAK_TAG ALG_RETURN_TAG ALG_WHILE_TAG ALG_NORETCALL_TAG ALG_TERMINATE_TAG ALG_REINIT_TAG ALG_ASSERT_TAG ALG_WHEN_TAG ALG_IF_TAG ALG_FOR_TAG ALG_FUNCTION_ARRAY_INIT_TAG ALG_ASSIGNMENT_TAG
"""
    Statement

A statement of an algorithm section or function: one tagged struct for all variants (`tag`). Every variant has
its `source`.

- `ALG_ASSIGNMENT(lhs, rhs, ty, source)`: `lhs := rhs` of type `ty`.
- `ALG_FUNCTION_ARRAY_INIT(name, ty, source)`: the allocation of the function array variable `name`.
- `ALG_FOR(iterator, range, body, source)`, `ALG_WHILE(condition, body, source)`: loops.
- `ALG_IF(branches, source)`, `ALG_WHEN(branches, source)`: `branches` are `(condition, body)` pairs.
- `ALG_ASSERT(condition, message, level, source)`, `ALG_TERMINATE(message, source)`, `ALG_NORETCALL(exp, source)`.
- `ALG_REINIT(cref, reinitExp, source)`: reinit in a when-statement, with
  `--allowNonStandardModelica=reinitInAlgorithms` (omc).
- `ALG_RETURN(source)`, `ALG_BREAK(source)`, `ALG_FAILURE(body, source)`.

Each variant also has a keyword constructor. Fields a variant does not use hold `nothing`.
"""
struct Statement
  tag::StatementTag
  body::Union{Nothing, Vector{Statement}}
  source::SourceInfo
  condition::Union{Nothing, Expression}
  exp::Union{Nothing, Expression}
  message::Union{Nothing, Expression}
  cref::Union{Nothing, Expression}
  reinitExp::Union{Nothing, Expression}
  level::Union{Nothing, Expression}
  branches::Union{Nothing, Vector{Tuple{Expression, Vector{Statement}}}}
  iterator::Union{Nothing, InstNode}
  range::Union{Nothing, Option}
  name::Union{Nothing, String}
  ty::Union{Nothing, ModelicaType}
  lhs::Union{Nothing, Expression}
  rhs::Union{Nothing, Expression}
end

"""A `Statement` of variant `tag` with the given fields, the others `nothing`."""
@inline _statement(tag::StatementTag, source; body = nothing, condition = nothing, exp = nothing, message = nothing,
                   cref = nothing, reinitExp = nothing, level = nothing, branches = nothing, iterator = nothing,
                   range = nothing, name = nothing, ty = nothing, lhs = nothing, rhs = nothing) =
  Statement(tag, body, source, condition, exp, message, cref, reinitExp, level, branches, iterator, range, name, ty,
            lhs, rhs)

ALG_FAILURE(body, source) = _statement(ALG_FAILURE_TAG, source; body)
ALG_FAILURE(; body, source) = ALG_FAILURE(body, source)
ALG_BREAK(source) = _statement(ALG_BREAK_TAG, source)
ALG_BREAK(; source) = ALG_BREAK(source)
ALG_RETURN(source) = _statement(ALG_RETURN_TAG, source)
ALG_RETURN(; source) = ALG_RETURN(source)
ALG_WHILE(condition, body, source) = _statement(ALG_WHILE_TAG, source; condition, body)
ALG_WHILE(; condition, body, source) = ALG_WHILE(condition, body, source)
ALG_NORETCALL(exp, source) = _statement(ALG_NORETCALL_TAG, source; exp)
ALG_NORETCALL(; exp, source) = ALG_NORETCALL(exp, source)
ALG_TERMINATE(message, source) = _statement(ALG_TERMINATE_TAG, source; message)
ALG_TERMINATE(; message, source) = ALG_TERMINATE(message, source)
ALG_REINIT(cref, reinitExp, source) = _statement(ALG_REINIT_TAG, source; cref, reinitExp)
ALG_REINIT(; cref, reinitExp, source) = ALG_REINIT(cref, reinitExp, source)
ALG_ASSERT(condition, message, level, source) = _statement(ALG_ASSERT_TAG, source; condition, message, level)
ALG_ASSERT(; condition, message, level, source) = ALG_ASSERT(condition, message, level, source)
ALG_WHEN(branches, source) = _statement(ALG_WHEN_TAG, source; branches)
ALG_WHEN(; branches, source) = ALG_WHEN(branches, source)
ALG_IF(branches, source) = _statement(ALG_IF_TAG, source; branches)
ALG_IF(; branches, source) = ALG_IF(branches, source)
ALG_FOR(iterator, range, body, source) = _statement(ALG_FOR_TAG, source; iterator, range, body)
ALG_FOR(; iterator, range, body, source) = ALG_FOR(iterator, range, body, source)
ALG_FUNCTION_ARRAY_INIT(name, ty, source) = _statement(ALG_FUNCTION_ARRAY_INIT_TAG, source; name, ty)
ALG_FUNCTION_ARRAY_INIT(; name, ty, source) = ALG_FUNCTION_ARRAY_INIT(name, ty, source)
ALG_ASSIGNMENT(lhs, rhs, ty, source) = _statement(ALG_ASSIGNMENT_TAG, source; lhs, rhs, ty)
ALG_ASSIGNMENT(; lhs, rhs, ty, source) = ALG_ASSIGNMENT(lhs, rhs, ty, source)

@registerVariants Statement begin
  ALG_FAILURE(body, source)
  ALG_BREAK(source)
  ALG_RETURN(source)
  ALG_WHILE(condition, body, source)
  ALG_NORETCALL(exp, source)
  ALG_TERMINATE(message, source)
  ALG_REINIT(cref, reinitExp, source)
  ALG_ASSERT(condition, message, level, source)
  ALG_WHEN(branches, source)
  ALG_IF(branches, source)
  ALG_FOR(iterator, range, body, source)
  ALG_FUNCTION_ARRAY_INIT(name, ty, source)
  ALG_ASSIGNMENT(lhs, rhs, ty, source)
end

"""An algorithm section: its statements and its source."""
struct ALGORITHM
  statements::Vector{Statement}
  source::SourceInfo
end

@UniontypeDecl Replaceable
@UniontypeDecl Token
@UniontypeDecl TypingError

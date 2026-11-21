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

@Uniontype MatchedFunction begin
  @Record MATCHED_FUNC begin
    func::MODELICA_FUNCTION
    args::Vector{TypedArg}
    mk::FunctionMatchKind
  end
end

function toString(args::Vector{TypedArg})
  buffer = IOBuffer()
  println(buffer, "TypedArg:")
  for a in args
    println(buffer, "(", toString(a[1]), ")")
  end
  for a in args
    println(buffer, "(", toString(a[2]), ")")
  end
  for a in args
    println(buffer, "(", toString(a[3]), ")")
  end
  println(buffer, "End of TypedArg")
  return String(take!(buffer))
end

function toString(s::Nothing)
  "nothing"
end


function hasName(name::String, slot::SLOT)::Bool
  local hasName::Bool = name == slot.name
  return hasName
end

"""True if the slot accepts a named argument."""
named(slot::SLOT)::Bool = slot.ty == SLOT_TYPE_NAMED || slot.ty == SLOT_TYPE_GENERIC

"""True if the slot accepts a positional argument."""
positional(slot::SLOT)::Bool = slot.ty == SLOT_TYPE_POSITIONAL || slot.ty == SLOT_TYPE_GENERIC

#= SLOT is defined in FrontendInterfaces/NFInterfaces.jl, before MODELICA_FUNCTION. =#

@UniontypeDecl FunctionMatchKind

function isExactVectorized(mk::FunctionMatchKind)::Bool
  local b::Bool

  @assign b = begin
    @match mk begin
      VECTORIZED_MATCH_KIND(baseMatch = EXACT_MATCH_KIND(__)) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return b
end

function isVectorized(mk::FunctionMatchKind)::Bool
  local b::Bool
  @assign b = begin
    @match mk begin
      VECTORIZED_MATCH_KIND(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return b
end

function isExact(mk::FunctionMatchKind)::Bool
  local b::Bool
  @assign b = begin
    @match mk begin
      EXACT_MATCH_KIND(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return b
end

function isValid(mk::FunctionMatchKind)::Bool
  local b::Bool
  @assign b = begin
    @match mk begin
      NOT_COMPATIBLE_MATCH_KIND(__) => begin
        false
      end
      _ => begin
        true
      end
    end
  end
  return b
end

@Uniontype FunctionMatchKind begin
  @Record NOT_COMPATIBLE_MATCH_KIND begin
  end
  @Record VECTORIZED_MATCH_KIND begin
    vectDims::List{Dimension}
    #=  When vectorizing a call exact argument matches are allowed to not be vectorized =#
    #=  Instead they are added to each call as is. =#
    #=  This list represents which args should be vectorized. =#
    vectorizedArgs::List{Int}
    baseMatch::FunctionMatchKind
  end
  @Record GENERIC_MATCH_KIND begin
  end
  @Record CAST_MATCH_KIND begin
  end
  @Record EXACT_MATCH_KIND begin
  end
end

const EXACT_MATCH = EXACT_MATCH_KIND()::FunctionMatchKind
const CAST_MATCH = CAST_MATCH_KIND()::FunctionMatchKind
const GENERIC_MATCH = GENERIC_MATCH_KIND()::FunctionMatchKind
const NO_MATCH = NOT_COMPATIBLE_MATCH_KIND()::FunctionMatchKind

@UniontypeDecl MatchedFunction

function isVectorized(mf::MatchedFunction)::Bool
  local b::Bool = isVectorized(mf.mk)
  return b
end

function getExactVectorizedMatches(matchedFunctions::Vector{MatchedFunction})::Vector{MatchedFunction}
  local outFuncs::Vector{MatchedFunction} = MatchedFunction[mf for mf in matchedFunctions if isExactVectorized(mf.mk)]
  return outFuncs
end

function getExactMatches(matchedFunctions::Vector{MatchedFunction})::Vector{MatchedFunction}
  local outFuncs::Vector{MatchedFunction} = MatchedFunction[mf for mf in matchedFunctions if isExact(mf.mk)]
  return outFuncs
end




using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll

function isPartial(fn::MODELICA_FUNCTION)::Bool
  return isPartial(fn.node)
end

function foldExpParameter(node::InstNode, foldFn::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}

  local comp::Component
  local cls::Class

  @assign comp = component(node)
  @assign arg = foldExp(getBinding(comp), foldFn, arg, ArgT)
   () = begin
    @match comp begin
      TYPED_COMPONENT(__) => begin
        @assign arg = foldDims(comp.ty, (dim::Dimension, acc::ArgT) -> foldExp(dim, foldFn, acc, ArgT), arg, ArgT)
        @assign cls = getClass(comp.classInst)
        @assign arg = foldComponents(classTree(cls), (node::InstNode, acc::ArgT) -> foldExpParameter(node, foldFn, acc, ArgT), arg, ArgT)
        ()
      end

      _ => begin
        ()
      end
    end
   end
  return arg
end

function foldExp(
  fn::MODELICA_FUNCTION,
  foldFn::FT,
  arg::ArgT,
  ::Type{ArgT},
  mapParameters::Bool = true,
  mapBody::Bool = true,
  )::ArgT where {FT<:Function, ArgT}

  local cls::Class

  @assign cls = getClass(fn.node)
  if mapParameters
    @assign arg = foldComponents(classTree(cls), (node::InstNode, acc::ArgT) -> foldExpParameter(node, foldFn, acc, ArgT), arg, ArgT)
  end
  if mapBody
    @assign arg = P_Sections.Sections.foldExp(getSections(cls), foldFn, arg, ArgT)
  end
  return arg
end

function mapExpParameter(node::InstNode, mapFn::MapFunc)
  local comp::Component
  local binding::Binding
  local binding2::Binding
  local cls::Class
  local ty::ModelicaType
  local dirty::Bool = false
  comp = component(node)
  binding = getBinding(comp)
  binding2 = mapExp(binding, mapFn)
  if !referenceEq(binding, binding2)
    comp = setBinding(binding2, comp)
    dirty = true
  end
  () = begin
    @match comp begin
      TYPED_COMPONENT(__) => begin
        ty =
          mapDims(comp.ty, (x) -> mapExp(x, mapFn))
        if !referenceEq(ty, comp.ty)
          @assign comp.ty = ty
          dirty = true
        end
        cls = getClass(comp.classInst)
        applyComponents(
          classTree(cls),
          (nodeArg) -> mapExpParameter(nodeArg, mapFn),
        )
        ()
      end

      _ => begin
        ()
      end
    end
  end
  if dirty
    node = updateComponent!(comp, node)
  end
  return node
end

function mapExp(
  fn::MODELICA_FUNCTION,
  mapFn::MapFunc,
  mapParameters::Bool = true,
  mapBody::Bool = true,
  )::MODELICA_FUNCTION
  local cls::Class
  local ctree::ClassTree
  local comps::Vector{InstNode}
  local sections::Sections
  local comp::Component
  local binding::Binding
  local binding2::Binding
  cls = getClass(fn.node)
  if mapParameters
    ctree = classTree(cls)
    applyComponents(ctree, (nodeArg) -> mapExpParameter(nodeArg, mapFn))
    @assign fn.returnType = makeReturnType(fn)
  end
  if mapBody
    sections = mapExp(getSections(cls), mapFn)
    cls = setSections(sections, cls)
    @assign fn.node = updateClass(cls, fn.node)
  end
  return fn
end

function hasUnboxArgsAnnotation(cmt::SCode.COMMENT)::Bool
  local res::Bool =
    SCodeUtil.commentHasBooleanNamedAnnotation(cmt, "__OpenModelica_UnboxArguments")
  return res
end

"""Returns true if the function has the __OpenModelica_UnboxArguments annotation, otherwise false."""
function hasUnboxArgs(fn::MODELICA_FUNCTION)::Bool
  return fn.attributes.builtin == FUNCTION_BUILTIN && fn.attributes.unboxArgs
end

function getBody(fn::MODELICA_FUNCTION)::Vector{Statement}
  local body::Vector{Statement} = getBody2(fn.node)
  return body
end

#= An operator record's constructor: 'constructor' in its path (omc isNonDefaultRecordConstructor). =#
function isNonDefaultRecordConstructor(fn::MODELICA_FUNCTION)::Bool
  return isNonDefaultRecordConstructorPath(fn.path)
end

function isNonDefaultRecordConstructorPath(path::Absyn.Path)::Bool
  path isa Absyn.QUALIFIED || return false
  return path.name == "'constructor'" || isNonDefaultRecordConstructorPath(path.path)
end

function isDefaultRecordConstructor(fn::MODELICA_FUNCTION)::Bool
  local isConstructor::Bool
  isConstructor = begin
    @match restriction(getClass(fn.node)) begin
      RESTRICTION_RECORD_CONSTRUCTOR(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isConstructor
end

function inlineBuiltin(fn::MODELICA_FUNCTION)::InlineType
  return fn.attributes.builtin == FUNCTION_BUILTIN_PTR ? BUILTIN_EARLY_INLINE : fn.attributes.inline
end

function isExternal(fn::MODELICA_FUNCTION)::Bool
  local isExt::Bool =
    !isEmpty(fn.node) && isExternalFunction(getClass(fn.node))
  return isExt
end

function setFunctionPointer(isPointer::Bool, fn::MODELICA_FUNCTION)::MODELICA_FUNCTION
  local attr::FUNCTION_ATTRIBUTES = fn.attributes
  @assign attr.isFunctionPointer = isPointer
  @assign fn.attributes = attr
  return fn
end

function isFunctionPointer(fn::MODELICA_FUNCTION)::Bool
  local isPointer::Bool = fn.attributes.isFunctionPointer
  return isPointer
end

function isOMImpure(fn::MODELICA_FUNCTION)::Bool
  return fn.attributes.isImpure
end

function isImpure(fn::MODELICA_FUNCTION)::Bool
  return fn.attributes.isImpure
end

function isNotImpure(fn::MODELICA_FUNCTION)::Bool
  return !isImpure(fn)
end

function isSubscriptableBuiltin(fn::MODELICA_FUNCTION)::Bool
  local scalarBuiltin::Bool
  if !isBuiltin(fn)
    @assign scalarBuiltin = false
  else
    @assign scalarBuiltin = begin
      @match AbsynUtil.pathFirstIdent(nameConsiderBuiltin(fn)) begin
        "change" => begin
          true
        end

        "der" => begin
          true
        end

        "pre" => begin
          true
        end

        _ => begin
          false
        end
      end
    end
  end
  return scalarBuiltin
end

"""
    This function checks if a function is a special builtin function
    and needs to be handled in a different way.
    Examples of such functions is der
  """
function isSpecialBuiltin(fn::MODELICA_FUNCTION)::Bool
  local special::Bool
  local path::Absyn.Path
  if !isBuiltin(fn)
    @assign special = false
  else
    @assign path = nameConsiderBuiltin(fn)
    if !AbsynUtil.pathIsIdent(path)
      @assign special = false
    else
      @assign special = begin
        @match AbsynUtil.pathFirstIdent(path) begin
          "array" => begin
            true
          end

          "actualStream" => begin
            true
          end

          "branch" => begin
            true
          end

          "cardinality" => begin
            true
          end

          "cat" => begin
            true
          end

          "change" => begin
            true
          end

          "der" => begin
            true
          end

          "diagonal" => begin
            true
          end

          "edge" => begin
            true
          end

          "fill" => begin
            true
          end

          "getInstanceName" => begin
            true
          end

          "initial" => begin
            true
          end

          "inStream" => begin
            true
          end

          "isRoot" => begin
            true
          end

          "matrix" => begin
            true
          end

          "max" => begin
            true
          end

          "min" => begin
            true
          end

          "ndims" => begin
            true
          end

          "noEvent" => begin
            true
          end

          "ones" => begin
            true
          end

          "potentialRoot" => begin
            true
          end

          "pre" => begin
            true
          end

          "product" => begin
            true
          end

          "promote" => begin
            true
          end

          "pure" => begin
            true
          end

          "root" => begin
            true
          end

          "rooted" => begin
            true
          end

          "uniqueRoot" => begin
            true
          end

          "uniqueRootIndices" => begin
            true
          end

          "scalar" => begin
            true
          end

          "size" => begin
            true
          end

          "smooth" => begin
            true
          end

          "sum" => begin
            true
          end

          "symmetric" => begin
            true
          end

          "terminal" => begin
            true
          end

          "transpose" => begin
            true
          end

          "vector" => begin
            true
          end

          "zeros" => begin
            true
          end

          "sample" => begin
            true
          end
          #= Extensions  =#
          "initialStructuralState" => true
          "structuralTransition" => true
          "recompilation" => true
          "agentic_recompilation" => true
          _ => begin
            false
          end
        end
      end
    end
  end
  return special
end

function isBuiltinAttr(attrs::FUNCTION_ATTRIBUTES)::Bool
  return attrs.builtin != FUNCTION_NOT_BUILTIN
end

function isBuiltin(fn::MODELICA_FUNCTION)::Bool
  local isBuiltin::Bool = isBuiltinAttr(fn.attributes)
  return isBuiltin
end

function applyPartialApplicationArg(
  argName::String,
  argExp::Expression,
  argType::ModelicaType,
  inputs::List{<:InstNode},
  slots::List{<:SLOT},
  fn::MODELICA_FUNCTION,
  info::SourceInfo,
)::Tuple{Expression, List{InstNode}, List{SLOT}}
  local outSlots::List{SLOT} = nil
  local outInputs::List{InstNode} = nil

  local i::InstNode
  local rest_inputs::List{InstNode} = inputs
  local s::SLOT
  local rest_slots::List{SLOT} = slots
  local mk::MatchKindType

  while !listEmpty(rest_inputs)
    @match _cons(i, rest_inputs) = rest_inputs
    @match _cons(s, rest_slots) = rest_slots
    if s.name == argName
       (argExp, _, mk) =
        matchTypes(argType, getType(i), argExp, true)
      if isIncompatibleMatch(mk)
        Error.addSourceMessage(
          Error.NAMED_ARG_TYPE_MISMATCH,
          list(
            AbsynUtil.pathString(name(fn)),
            argName,
            toString(argExp),
            toString(argType),
            toString(getType(i)),
          ),
          info,
        )
        fail()
      end
      @assign outInputs = listAppend(listReverseInPlace(outInputs), rest_inputs)
      @assign outSlots = listAppend(listReverseInPlace(outSlots), rest_slots)
      return (argExp, outInputs, outSlots)
    end
    @assign outInputs = _cons(i, outInputs)
    @assign outSlots = _cons(s, outSlots)
  end
  Error.addSourceMessage(
    Error.NO_SUCH_INPUT_PARAMETER,
    list(AbsynUtil.pathString(name(fn)), argName),
    info,
  )
  fail()
  return (argExp, outInputs, outSlots)
end

function typePartialApplication(
  exp::Expression,
  origin::ORIGIN_Type,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType, VariabilityType}
  local variability::VariabilityType
  local ty::ModelicaType

  local fn_ref::ComponentRef
  local args::List{Expression}
  local ty_args::List{Expression} = nil
  local arg_names::List{String}
  local rest_names::List{String}
  local arg_name::String
  local arg_exp::Expression
  local arg_ty::ModelicaType
  local arg_var::VariabilityType
  local fn::MODELICA_FUNCTION
  local next_origin::ORIGIN_Type = setFlag(origin, ORIGIN_SUBEXPRESSION)
  local inputs::List{InstNode}
  local slots::List{SLOT}

  @match PARTIAL_FUNCTION_APPLICATION_EXPRESSION(
    fn = fn_ref,
    args = args,
    argNames = arg_names,
  ) = exp
  #=  TODO: Handle overloaded functions?
  =#
  fns = typeRefCache(fn_ref)
  fn = fns[1]
  @assign inputs = fn.inputs
  @assign slots = fn.slots
  @assign rest_names = arg_names
  @assign variability = if isImpure(fn) || isOMImpure(fn)
    Variability.PARAMETER
  else
    Variability.CONSTANT
  end
  for arg in args
     (arg, arg_ty, arg_var) = typeExp(arg, origin, info)
    @match _cons(arg_name, rest_names) = rest_names
     (arg, inputs, slots) =
      applyPartialApplicationArg(arg_name, arg, arg_ty, inputs, slots, fn, info)
    @assign ty_args = _cons(box(arg), ty_args)
    @assign variability = variabilityMax(variability, arg_var)
  end
  @assign fn.inputs = inputs
  @assign fn.slots = slots
  @assign ty = TYPE_FUNCTION(fn, FunctionType.FUNCTIONAL_VARIABLE)
  @assign exp = PARTIAL_FUNCTION_APPLICATION_EXPRESSION(
    fn_ref,
    listReverseInPlace(ty_args),
    arg_names,
    ty,
  )
  return (exp, ty, variability)
end

function boxFunctionParameter(compNode::InstNode)
  local comp::Component

  @assign comp = component(compNode)
  @assign comp = setType(box(getType(comp)), comp)
  return updateComponent!(comp, compNode)
end

function mapFunctionNodes(nodes::List{InstNode}, func::FuncT)::List{InstNode} where {FuncT}
  local accum::List{InstNode} = nil
  local changed::Bool = false
  local new_node::InstNode

  for node in nodes
    new_node = func(node)
    changed = changed || new_node !== node
    accum = _cons(new_node, accum)
  end

  return changed ? listReverseInPlace(accum) : nodes
end

"""
  Types the body of a function, along with any bindings of local variables
  and outputs.
"""
function typeFunctionBody(fn::MODELICA_FUNCTION)::MODELICA_FUNCTION
  #=  Type the bindings of the outputs and local variables. =#
  @assign fn.outputs = mapFunctionNodes(fn.outputs, (c) -> typeComponentBinding(c, ORIGIN_FUNCTION))
  @assign fn.locals = mapFunctionNodes(fn.locals, (c) -> typeComponentBinding(c, ORIGIN_FUNCTION))
  #=  Type the algorithm section of the function, if it has one. =#
  @assign fn.node = typeFunctionSections(fn.node, ORIGIN_FUNCTION)
  #=  Type any derivatives of the function.
  =#
  for fn_der in fn.derivatives
    typeDerivative(fn_der)
  end
  #=  Sort the local variables based on their dependencies (omc). =#
  @assign fn.locals = sortLocals(fn.locals, InstNode_info(fn.node))
  return fn
end

"""
omc Function.sortLocals: the local components of a function in an order they can be
initialized in (a binding or dimension may use other locals), or an error for mutually
dependent ones. Locals that use no other local keep their declared order. omc also follows
the field bindings of a local record without a binding; not done here.
"""
function sortLocals(locals::List{InstNode}, info::SourceInfo)::List{InstNode}
  local nodes::Vector{InstNode} = Base.collect(locals)
  local n::Int = length(nodes)
  n < 2 && return locals
  local deps::Vector{Set{Int}} = [localDependencies(nodes[i], i, nodes) for i in 1:n]
  all(isempty, deps) && return locals
  local order::Vector{Int} = Int[]
  local done::BitVector = falses(n)
  local progress::Bool = true
  while progress
    progress = false
    for i in 1:n
      if !done[i] && all(d -> done[d], deps[i])
        push!(order, i)
        done[i] = true
        progress = true
      end
    end
  end
  if length(order) < n
    local cyc::String = "{" * Base.join([name(nodes[i]) for i in 1:n if !done[i]], ", ") * "}"
    Error.addSourceMessage(Error.CYCLIC_FUNCTION_COMPONENTS, list(cyc), info)
    fail()
  end
  return arrayList(nodes[order])
end

"""
The other locals (indices into nodes) a local's binding and dimensions refer to, by the
root of each cref (omc ComponentRef.last: a in a.b.c, for local record instances).
"""
function localDependencies(compNode::InstNode, self::Int, nodes::Vector{InstNode})::Set{Int}
  local deps::Set{Int} = Set{Int}()
  local add_cref = (e::Expression, acc::Nothing) -> begin
    if e isa CREF_EXPRESSION && isvariant(e.cref, COMPONENT_REF_CREF)
      local cr::ComponentRef = e.cref
      while isvariant(cr.restCref, COMPONENT_REF_CREF)
        cr = cr.restCref
      end
      local k = findfirst(m -> refEqual(m, node(cr)), nodes)
      (k === nothing || k == self) || push!(deps, k)
    end
    acc
  end
  local b::Binding = getBinding(component(compNode))
  hasExp(b) && fold(getExp(b), add_cref, nothing, Nothing)
  for d in arrayDims(getType(compNode))
    @match d begin
      DIMENSION_EXP(__) => fold(d.exp, add_cref, nothing, Nothing)
      _ => ()
    end
  end
  return deps
end

"""Types a function's parameters, local components and default arguments."""
function typeFunctionSignature(fn::MODELICA_FUNCTION)
  local node::InstNode = fn.node
  if !isTyped(fn)
    typeClassType(node, EMPTY_BINDING, ORIGIN_FUNCTION, node)
    typeComponents(node, ORIGIN_FUNCTION)
    if isPartial(node)
      applyComponents(
        classTree(getClass(node)),
        boxFunctionParameter,
      )
      @assign fn.inputs = mapFunctionNodes(fn.inputs, boxFunctionParameter)
    end
    @assign fn.inputs = mapFunctionNodes(fn.inputs, (c) -> typeComponentBinding(c, ORIGIN_FUNCTION))
    fnSlots = makeSlots(fn.inputs)
    checkParamTypes(fn)
    checkPartialDerivativeTypes(fn)
    fnReturnType = makeReturnType(fn)
    fn = MODELICA_FUNCTION(
      fn.path,
      fn.node,
      fn.inputs,
      fn.outputs,
      fn.locals,
      fnSlots,
      fnReturnType,
      fn.attributes,
      fn.derivatives,
      fn.status,
      fn.callCounter,
      fn.derivedInputs)
  end
  return fn
end

function typeFunction(fn::MODELICA_FUNCTION)
  fn = typeFunctionSignature(fn)
  fn = typeFunctionBody(fn)
  return fn
end

function getRefCache(fnRef::ComponentRef)
  local functions::Vector{MODELICA_FUNCTION}
  local fn_node::InstNode
  fn_node = classScope(node(fnRef))
  @match C_FUNCTION(funcs = functions) = getFuncCache(fn_node)
  return functions
end

"""
 Returns the function(s) in the cache of the given node, and types them if
 they are not already typed.
"""
function typeNodeCache(@nospecialize(functionNode::InstNode))::Vector{MODELICA_FUNCTION}
  local fn_node::InstNode = classScope(functionNode)
  if _parallelTypingActive()
    return _withClaim(() -> typeNodeCache2(fn_node), _refId(fn_node))
  end
  return typeNodeCache2(fn_node)
end

function typeNodeCache2(fn_node::InstNode)::Vector{MODELICA_FUNCTION}
  local functions::Vector{MODELICA_FUNCTION}
  local typed::Bool
  local special::Bool
  local name::String
  #@match C_FUNCTION(functions, typed, special) = getFuncCache(fn_node)
  local cache::C_FUNCTION = getFuncCache(fn_node)::C_FUNCTION
  typed = cache.typed
  functions = cache.funcs
  #=  Type the function(s) if not already done. =#
  if !typed
    #functions = MODELICA_FUNCTION[typeFunctionSignature(f) for f in functions]
    for (i, f) in enumerate(functions)
      functions[i] = typeFunctionSignature(f) #TODO Investigate if this approch works
    end
    #@time local cache = C_FUNCTION(functions, true, special)
    cache.typed = true
    setFuncCache(fn_node, cache)
    for (i, f) in enumerate(functions)
      cache.funcs[i] = typeFunctionBody(f)
    end
    setFuncCache(fn_node, cache)
  end
  return functions
end

"""
 Returns the function(s) referenced by the given cref, and types them if
 they are not already typed.
"""
function typeRefCache(functionRef::ComponentRef)::Vector{MODELICA_FUNCTION}
  local functions::Vector{MODELICA_FUNCTION}
  functions = begin
    @match functionRef begin
      COMPONENT_REF_CREF(__) => begin
        typeNodeCache(functionRef.node)
      end
      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " got invalid function call reference",
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return functions
end

function isTyped(fn::MODELICA_FUNCTION)::Bool
  local isTyped::Bool
  @assign isTyped = begin
    @match fn.returnType begin
      TYPE_UNKNOWN(__) => begin
        false
      end
      _ => begin
        true
      end
    end
  end
  return isTyped
end

function matchFunctionsSilent(
  funcs::Vector{MODELICA_FUNCTION},
  args::Vector{TypedArg},
  named_args::Vector{TypedNamedArg},
  info::SourceInfo,
  vectorize::Bool = true,
  )
  local matchedFunctions::Vector{MatchedFunction}
  ErrorExt.setCheckpoint("NFFunction:matchFunctions")
  matchedFunctions = matchFunctions(funcs, args, named_args, info, vectorize)
  ErrorExt.rollBack("NFFunction:matchFunctions")
  return matchedFunctions
end

function matchFunctions(
  funcs::Vector{MODELICA_FUNCTION},
  args::Vector{TypedArg},
  named_args::Vector{TypedNamedArg},
  info::SourceInfo,
  vectorize::Bool = true,
  )
  local matchedFunctions::Vector{MatchedFunction} = MatchedFunction[]
  local m_args::Vector{TypedArg}
  local matchKind::FunctionMatchKind
  local matched::Bool
  for func in funcs
    (m_args, matchKind) = matchFunction(func, args, named_args, info, vectorize)
    if isValid(matchKind)
      matchedFunctions = push!(matchedFunctions, MATCHED_FUNC(func, m_args, matchKind))
    end
  end
  return matchedFunctions
end

function matchFunction(
  func::MODELICA_FUNCTION,
  args::Vector{TypedArg},
  named_args::Vector{TypedNamedArg},
  info::SourceInfo,
  vectorize::Bool = true,
)::Tuple{Vector{TypedArg}, FunctionMatchKind}
  local matchKind::FunctionMatchKind = NO_MATCH
  local out_args::Vector{TypedArg}
  local slot_matched::Bool
  (out_args, slot_matched) = fillArgs(args, named_args, func, info)
  if slot_matched
    (out_args, matchKind) = matchArgs(func, out_args, info, vectorize)
  end
  return (out_args, matchKind)
end

"""
Helper function to matchArgVectorized. Replaces unknown dimensions in the
  list with size(argExp, dimension index), so that vectorized calls involving
unknown dimensions (e.g. in functions) can be handled correctly.
"""
function fillUnknownVectorizedDims(
  dims::List{<:Dimension},
  argExp::Expression,
)::List{Dimension}
  local outDims::List{Dimension} = nil
  local i::Int = 1
  for dim in dims
    if isUnknown(dim)
      dim = DIMENSION_EXP(
        SIZE_EXPRESSION(argExp, SOME(INTEGER_EXPRESSION(i))),
        Variability.CONTINUOUS,
      )
    end
    outDims = _cons(dim, outDims)
    i = i + 1
  end
  outDims = listReverseInPlace(outDims)
  return outDims
end

function matchArgVectorized(
  @nospecialize(argExp::Expression),
  argTy::ModelicaType,
  inputTy::ModelicaType,
  @nospecialize(vectArg::Expression),
  vectDims::List{<:Dimension},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType, Expression, List{Dimension}, MatchKindType}
  local matchKind::MatchKindType
  local arg_dims::List{Dimension}
  local input_dims::List{Dimension}
  local vect_dims::List{Dimension}
  local rest_dims::List{Dimension}
  local rest_ty::ModelicaType
  local mk::MatchKindType
  local vect_dims_count::Int
  arg_dims = arrayDims(argTy)
  input_dims = arrayDims(inputTy)
  vect_dims_count = listLength(arg_dims) - listLength(input_dims)
  #=  Only try to vectorize if the argument has more dimensions than the input parameter.
  =#
  if vect_dims_count < 1
    matchKind = MatchKind.NOT_COMPATIBLE
    return (argExp, argTy, vectArg, vectDims, matchKind)
  end
  (vect_dims, rest_dims) = ListUtil.split(arg_dims, vect_dims_count, Dimension)
  #=  Make sure the vectorization dimensions are consistent.
  =#
  if listEmpty(vectDims)
    vectDims = fillUnknownVectorizedDims(vect_dims, argExp)
    vectArg = argExp
  elseif !ListUtil.isEqualOnTrue(vectDims, vect_dims, isEqual)
    Error.addSourceMessage(
      Error.VECTORIZE_CALL_DIM_MISMATCH,
      list(
        "",
        toString(vectArg),
        "",
        toString(argExp),
        toStringList(vectDims),
        toStringList(vect_dims),
      ),
      info,
    )
  end
  #=  Check that the argument and the input parameter are type compatible when
  =#
  #=  the dimensions to vectorize over has been removed from the argument's type.
  =#
  @assign rest_ty = liftArrayLeftList(arrayElementType(argTy), rest_dims)
  (argExp, argTy, matchKind) =
    matchTypes(rest_ty, inputTy, argExp, #=allowUnknown=# false)
  return (argExp, argTy, vectArg, vectDims, matchKind)
end

function matchArgs(
  func::MODELICA_FUNCTION,
  args::Vector{TypedArg},
  info::SourceInfo,
  vectorize::Bool = true,
)::Tuple{Vector{TypedArg}, FunctionMatchKind}
  local funcMatchKind::FunctionMatchKind = EXACT_MATCH
  # @info "matched arguments for function"
  # println(toFlatString(func))
  # println(toString(args))
  local comp::Component
  local inputs::List{InstNode} = func.inputs
  local input_node::InstNode
  local arg_idx::Int = 1
  local checked_args = Vector{TypedArg}(undef, length(args))
  local arg_exp::Expression
  local arg_ty::ModelicaType
  local input_ty::ModelicaType
  local ty::ModelicaType
  local arg_var::VariabilityType
  local mk::MatchKindType
  local vect_arg::Expression = INTEGER_EXPRESSION(0)
  local vect_dims::List{Dimension} = nil
  local matched::Bool
  local vectorized_args::List{Int} = nil

  for (i,arg) in enumerate(args)
    (arg_exp, arg_ty, arg_var) = arg
    @match _cons(input_node, inputs) = inputs
    @assign comp = component(input_node)
    #= A record's default constructor takes values of any variability: its inputs are the
       fields, whose parameter prefix is not the input's (Buildings' ClimaticConstants.Generic
       built from a function's locals). =#
    if arg_var > variability(comp) && !isDefaultRecordConstructor(func)
      # Error.addSourceMessage(
      #   Error.FUNCTION_SLOT_VARIABILITY,
      #   list(
      #     name(input_node),
      #     toString(arg_exp),
      #     AbsynUtil.pathString(name(func)),
      #     variabilityString(arg_var),
      #     variabilityString(variability(comp)),
      #   ),
      #   info,
      # )
      #@error "Function argument \"$(toString(arg_exp))\" in call to $(AbsynUtil.pathString(name(func))) has variability
      #        $(variabilityString(arg_var)) which is not a $(variabilityString(variability(comp)))"
      #Errors should not be printed yet.
      funcMatchKind = NO_MATCH
      return (args, funcMatchKind)
    end
    input_ty = getType(comp)
    (arg_exp, ty, mk) =
      matchTypes(arg_ty, input_ty, arg_exp, #=allowUnknown=# true)
    matched = isValidArgumentMatch(mk)
    if !matched && vectorize
      (arg_exp, ty, vect_arg, vect_dims, mk) =
        matchArgVectorized(arg_exp, arg_ty, input_ty, vect_arg, vect_dims, info)
      vectorized_args = _cons(arg_idx, vectorized_args)
      matched = isValidArgumentMatch(mk)
    end
    if !matched
      # Error.addSourceMessage(
      #   Error.ARG_TYPE_MISMATCH,
      #   list(
      #     intString(arg_idx),
      #     AbsynUtil.pathString(func.path),
      #     name(input_node),
      #     toString(arg_exp),
      #     toString(arg_ty),
      #     toString(input_ty),
      #   ),
      #   info,
      # )
      local msg = AbsynUtil.pathString(func.path)
      local expectedType = toString(input_ty)
      local actualType = toString(arg_ty)
      local msgPart1 = "Arg type mismatch for $msg for $(name(input_node)) with exp: $(toString(arg_exp))"
      local msgPart2 = "\nExpected type: $expectedType. Argument type was: $actualType"
      #@error msgPart1 * msgPart2 it should not be an error yet. These should be printed in the end.
      # Fix the error reporting module.
      funcMatchKind = NO_MATCH
      return (args, funcMatchKind)
    end
    if isCastMatch(mk)
      funcMatchKind = CAST_MATCH
    elseif isGenericMatch(mk)
      funcMatchKind = GENERIC_MATCH
    end
    checked_args[i] = (arg_exp, ty, arg_var)
    arg_idx = arg_idx + 1
  end
  #=  Check that the variability of the argument and input parameter matches.
  =#
  #=  Check if the type of the argument and the input parameter matches exactly.
  =#
  #=  If the types don't match, try to vectorize the argument.
  =#
  #=  Print an error if the types match neither exactly nor vectorized.
  =#
  #=  TODO: This should be a running reduction of the matches. Not just based on the
  =#
  #=  last match.
  =#
  if !listEmpty(vectorized_args)
    funcMatchKind =
      VECTORIZED_MATCH_KIND(vect_dims, listReverse(vectorized_args), funcMatchKind)
  end
  args = checked_args #=TODO: Same here can maybe be done inline=#
  # @info "The checked arguments...."
  # println(toString(args))
  # println("***********************")
  return (args, funcMatchKind)
end

#= The slot of that name. It was always none: ArrayUtil.getMemberOnTrue returns (slot, index),
   and the bare catch took the failed assignment for a missing slot, so a default reading
   another input kept the function's own input (MSL WallFriction's `crossArea = pi*diameter^2/4`
   a continuous binding of a parameter: Buildings' FixedResistances). =#
function lookupSlotInArray(slotName::String, slots::Vector{<:SLOT})::Option{SLOT}
  local i = findfirst(slot -> slot.name == slotName, slots)
  return i === nothing ? NONE() : SOME(slots[i])
end

function _isFunctionComponent(@nospecialize(n::InstNode))::Bool
  isComponent(n) || return false
  local p = explicitParent(n)
  return isClass(p) && isFunction(p)
end

function evaluateSlotExp_traverser(
  exp::Expression,
  slots::Vector{<:SLOT},
  info::SourceInfo,
)::Expression
  local outExp::Expression
  outExp = begin
    local cref::ComponentRef
    local slot::Option{SLOT}
    @match exp begin
      CREF_EXPRESSION(
        cref = cref && COMPONENT_REF_CREF(
          restCref = COMPONENT_REF_EMPTY(__),
        ),
      ) => begin
        #= Only a function's own component is an input (omc lookupSlotInArray by node): a default
           from a modifier outside it (`redeclare function func = f(x = x)`, x the model's
           parameter) reads the model's x, not the input it is the default of (omc
           FuncDefaultArg7). =#
        slot = _isFunctionComponent(node(cref)) ? lookupSlotInArray(firstName(cref), slots) : NONE()
        if isSome(slot)
          Util.tuple31(fillDefaultSlot(Util.getOption(slot), slots, info))
        else
          exp
        end
      end
      _ => begin
        exp
      end
    end
  end
  return outExp
end

function evaluateSlotExp(
  exp::Expression,
  slots::Vector{<:SLOT},
  info::SourceInfo,
)::Expression
  local outExp::Expression
  outExp = map(
    exp,
    (x) -> evaluateSlotExp_traverser(x, slots, info)
  )
  return outExp
end

#= A typed call's variability from its arguments, as matchTypedNormalCall computes it (applied
   after the arguments changed, children first). =#
function _callVariabilityFromArgs(@nospecialize(exp::Expression))::Expression
  return @match exp begin
    CALL_EXPRESSION(call = c && TYPED_CALL(__)) => begin
      local fn = c.fn
      local var = (isImpure(fn) || isOMImpure(fn)) ? Variability.PARAMETER : Variability.CONSTANT
      for a in c.arguments
        var = variabilityMax(var, variability(a))
      end
      if var == Variability.PARAMETER && isExternal(fn)
        var = Variability.NON_STRUCTURAL_PARAMETER
      elseif isDiscrete(c.ty) && var == Variability.CONTINUOUS
        var = Variability.IMPLICITLY_DISCRETE
      end
      var == c.var ? exp : CALL_EXPRESSION(TYPED_CALL(fn, c.ty, var, c.arguments, c.attributes))
    end
    _ => exp
  end
end

function fillDefaultSlot2(slot::SLOT, slots::Vector{<:SLOT}, info::SourceInfo)::TypedArg
  local outArg::TypedArg

  local exp::Expression
  local status::SlotEvalStatus = slot.evalStatus
  if status == SLOT_EVALUATED
    #= An already evaluated slot: its binding. =#
    outArg = Util.getOption(slot.arg)
  elseif status == SLOT_EVALUATING
    #= A slot in the process of being evaluated: cyclic bindings. =#
    Error.addSourceMessage(Error.CYCLIC_DEFAULT_VALUE, list(slot.name), info)
    fail()
  else
    #= A slot with a binding not evaluated yet: evaluate the binding and return it. =#
    @assign slot.evalStatus = SLOT_EVALUATING
    arrayUpdate(slots, slot.index, slot)
    exp = evaluateSlotExp(Util.getOption(slot.default), slots, info)
    #= Its calls take the variability of the arguments put in (omc types the default again:
       `input Real x = f2(dim)` in f(3) is constant, not dim's; omc FuncDefaultArg5). =#
    exp = map(exp, _callVariabilityFromArgs)
    outArg = (exp, typeOf(exp), variability(exp))
    @assign slot.arg = SOME(outArg)
    @assign slot.evalStatus = SLOT_EVALUATED
    arrayUpdate(slots, slot.index, slot)
  end
  return outArg
end

function fillDefaultSlot(slot::SLOT, slots::Vector{<:SLOT}, info::SourceInfo)::TypedArg
  local outArg::TypedArg

  @assign outArg = begin
    @match slot begin
      SLOT(arg = SOME(outArg)) => begin
        outArg
      end

      SLOT(default = SOME(_)) => begin
        fillDefaultSlot2(slot, slots, info)
      end

      _ => begin
        #=  Slot already filled by function argument.
        =#
        #=  Slot not filled by function argument, but has default value.
        =#
        #=  Give an error if no argument was given and there's no default argument.
        =#
        Error.addSourceMessage(Error.UNFILLED_SLOT, list(slot.name), info)
        fail()
      end
    end
  end
  return outArg
end

""" Collects the arguments from the given slots. """
function collectArgs(slots::Vector{<:SLOT}, info::SourceInfo)::Tuple{Vector{TypedArg}, Bool}
  local matching::Bool = true
  local args::Vector{TypedArg} = TypedArg[]
  local default::Option{Expression}
  local arg::Option{TypedArg}
  local a::TypedArg
  local name::String
  for s in slots
    @match SLOT(name = name, default = default, arg = arg) = s
    @matchcontinue arg begin
      #=  Use the argument from the call if one was given. =#
      SOME(a) => begin
        push!(args, a)
      end
      #= Otherwise, try to fill the slot with its default argument. No default: fillDefaultSlot's message
         without its failure (a throw outside a cheap-throw scope records a backtrace; overload candidates
         without the argument are common, 28 per MSL Fluid ThreeTanks). =#
      _ => begin
        if isNone(default)
          Error.addSourceMessage(Error.UNFILLED_SLOT, list(name), info)
          matching = false
        else
          push!(args, fillDefaultSlot(s, slots, info))
        end
      end
      _ => begin
        matching = false
      end
    end
  end
  return (args, matching)
end

"""
  Looks up a slot with the given name and tries to fill it with the given
  argument expression.
"""
function fillNamedArg(
  inArg::TypedNamedArg,
  slots::Vector{<:SLOT},
  fn::MODELICA_FUNCTION,
  info::SourceInfo,
)::Tuple{Array{SLOT}, Bool} #= For error reporting =#
  local matching::Bool = true

  local s::SLOT
  local argName::String
  local ty::ModelicaType
  local argExp::Expression
  local var::VariabilityType

  #=  Try to find a slot and fill it with the argument expression.
  =#
  #=  Positional arguments fill the slots from the start of the array, so
  =#
  #=  searching backwards will generally be a bit more efficient.
  =#
  for i = arrayLength(slots):(-1):1
    @assign s = slots[i]
     (argName, argExp, ty, var) = inArg
    if s.name == argName
      if !named(s)
        matching = false
      elseif isNone(s.arg)
        @assign s.arg = SOME((argExp, ty, var))
        slots[i] = s
      else
        Error.addSourceMessage(Error.FUNCTION_SLOT_ALREADY_FILLED, list(argName, ""), info)
        matching = false
      end
      return (slots, matching)
    end
  end
  #=  Slot doesn't allow named argument (used for some builtin functions).
  =#
  #=  TODO: Improve the error message, should mention function name.
  =#
  #=  No slot could be found.
  =#
  @assign matching = false
  #=  A slot with the given name couldn't be found. This means it doesn't
  =#
  #=  exist, or we removed it when handling positional argument. We need to
  =#
  #=  search through all slots to be sure.
  =#
  for s in fn.slots
    if argName == s.name
      Error.addSourceMessage(Error.FUNCTION_SLOT_ALREADY_FILLED, list(argName, ""), info)
      return (slots, matching)
    end
    Error.addSourceMessage(
      Error.NO_SUCH_PARAMETER,
      list(name(instance(fn)), argName),
      info,
    )
  end
  #=  We found a slot, so it must have already been filled.
  =#
  #=  No slot could be found, so it doesn't exist.
  =#
  return (slots, matching)
end

"""  Matches the given arguments to the slots in a function, and returns the
     arguments sorted in the order of the function parameters.
"""
function fillArgs(
  posArgs::Vector{TypedArg},
  namedArgs::Vector{TypedNamedArg},
  fn::MODELICA_FUNCTION,
  info::SourceInfo,
)::Tuple{Vector{TypedArg}, Bool}
  local matching::Bool
  local args::Vector{TypedArg} = posArgs
  local slot::SLOT
  local slots::List{SLOT}
  local remaining_slots::List{SLOT}
  local filled_named_args::Vector{TypedArg}
  local slots_arr::Vector{SLOT}
  local pos_arg_count::Int
  local slot_count::Int
  local index::Int = 1

  slots = fn.slots
  pos_arg_count = length(posArgs)
  slot_count = listLength(slots)
  if pos_arg_count > slot_count
    matching = false
    return (args, matching)
  elseif pos_arg_count == slot_count && isempty(namedArgs) && all(positional, slots)
    matching = true
    return (args, matching)
  end
  #=  If we have too many positional arguments it can't possibly match.
  =#
  #=  If we have exactly as many positional arguments as slots and no named
  =#
  #=  arguments we can just return the list of arguments as it is.
  =#
  slots_arr = listArray(slots)
  for arg in args
    slot = slots_arr[index]
    if !positional(slot)
      matching = false
      return (args, matching)
    end
    @assign slot.arg = SOME(arg)
    slots_arr[index] = slot
    index = index + 1
  end
  #=  Slot doesn't allow positional arguments (used for some builtin functions).
  =#
  for narg in namedArgs
    (slots_arr, matching) = fillNamedArg(narg, slots_arr, fn, info)
    if !matching
      return (args, matching)
    end
  end
  (args, matching) = collectArgs(slots_arr, info)
  return (args, matching)
end

function setReturnType(ty::ModelicaType, fn::MODELICA_FUNCTION)::MODELICA_FUNCTION

  @assign fn.returnType = ty
  return fn
end

function returnType(fn::MODELICA_FUNCTION)::ModelicaType
  local ty::ModelicaType = fn.returnType
  return ty
end

function instance(fn::MODELICA_FUNCTION)::InstNode
  local node::InstNode = fn.node
  return node
end

function toFlatString(fn::MODELICA_FUNCTION)::String
  local str::String
  local s
  s = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  s = toFlatStream(fn, s)
  str = IOStream_M.string(s)
  IOStream_M.delete(s)
  return str
end

function toFlatStream(fn::MODELICA_FUNCTION, s; overrideName::String)
  local fn_body::Vector{Statement}
  if isDefaultRecordConstructor(fn)
    s = IOStream_M.append(s, toFlatString(fn.node))
  else
    s = toFlatStreamHelper(fn::MODELICA_FUNCTION, s, overrideName)
  end
  return s
end

"""
Returns a function as  a flat string.
"""
function toFlatStream(fn::MODELICA_FUNCTION, s::IOStream_M.IOSTREAM)
  local fn_name::String
  if isDefaultRecordConstructor(fn)
    s = IOStream_M.append(s, toFlatString(fn.node))
  else
    fn_name = AbsynUtil.pathString(fn.path)
    s = toFlatStreamHelper(fn::MODELICA_FUNCTION, s, string("'", fn_name, "'"))
  end
  return s
end

function toFlatStreamHelper(fn::MODELICA_FUNCTION, s, fn_name)
    #= A partial derivative as its declaration, function df = der(f, x) (omc toFlatStream). =#
    if isPartialDerivative(fn)
      local ins = Base.collect(fn.inputs)
      s = IOStream_M.append(s, "function " * fn_name * " = der(" *
        AbsynUtil.pathString(getDerivedFunctionName(fn)) * ", " *
        Base.join([name(ins[i]) for i in fn.derivedInputs], ", ") * ");\n")
      return s
    end
    s = IOStream_M.append(s, "function ")
    s = IOStream_M.append(s, fn_name)
    s = IOStream_M.append(s, "\\n")
    for i in fn.inputs
      s = IOStream_M.append(s, "  ")
      s = IOStream_M.append(s, toFlatString(i; inFunction = true))
      s = IOStream_M.append(s, ";\\n")
    end
    for o in fn.outputs
      s = IOStream_M.append(s, "  ")
      s = IOStream_M.append(s, toFlatString(o; inFunction = true))
      s = IOStream_M.append(s, ";\\n")
    end
    if !listEmpty(fn.locals)
      s = IOStream_M.append(s, "protected\\n")
      for l in fn.locals
        s = IOStream_M.append(s, "  ")
        s = IOStream_M.append(s, toFlatString(l; inFunction = true))
        s = IOStream_M.append(s, ";\\n")
      end
    end
  #= Annotation handling =#
  cmt = Util.getOptionOrDefault(SCodeUtil.getElementComment(definition(fn.node)),
                                SCode.COMMENT(NONE(), NONE()));
  s = toFlatStream(getSections(fn.node), fn.path, s; inFunction = true)
  local annMod = if isSome(cmt.annotation_)
    @match SOME(SCode.ANNOTATION(annMod)) = cmt.annotation_
    annMod
  else
    annMod = SCode.NOMOD()
  end
  #Generate derivative/inverse annotations from the instantiated model. Paths have changed.
  annMod = SCodeUtil.filterSubMods(annMod, (mod) -> SCodeUtil.removeGivenSubModNames(mod; namesToRemove=list("derivative", "inverse")))
  for derivative in listReverse(fn.derivatives)
    annMod = SCodeUtil.prependSubModToMod(toSubMod(derivative), annMod)
  end

  # #= End of annotation handling=#
  if isExternal(fn)
    s = IOStream_M.append(s, "/* Externally defined function*/")
    # s = IOStream_M.append(s, )
    s = IOStream_M.append(s, "\nend ")
    s = IOStream_M.append(s, fn_name)
    return s
  end
  #fn_body = getBody(fn)
  #if !listEmpty(fn_body)
  #s = IOStream_M.append(s, "algorithm\\n")
  #s = toFlatStreamList(fn_body, "  ", s)
  #end
  s = IOStream_M.append(s, "\nend ")
  s = IOStream_M.append(s, fn_name)
end

function paramTypeString(param::InstNode)::String
  local str::String = toString(getType(param))
  return str
end

"""  Constructs a string representing the type of the function, on the form
     function_name<function>(input types) => output type
"""
function typeString(fn::MODELICA_FUNCTION)::String
  local str::String

  @assign str = ListUtil.toString(
    fn.inputs,
    paramTypeString,
    AbsynUtil.pathString(name(fn)) + "<function>",
    "(",
    ", ",
    ") => " + toString(fn.returnType),
    true,
  )
  return str
end

function candidateFuncListString(fns::List{MODELICA_FUNCTION})::String
  local s::String =
    stringDelimitList(list(signatureString(fn, true) for fn in fns), "\\n  ")
  return s
end

function candidateFuncListString(fns::Vector{MODELICA_FUNCTION})
  local s::String = stringDelimitList(list(signatureString(fn, true) for fn in fns), "\\n  ")
  return s
end

"""Constructs a signature string for a function, e.g. Real func(Real x, Real y)"""
function signatureString(fn::MODELICA_FUNCTION, printTypes::Bool = true)::String
  local str::String

  local fn_name::Absyn.Path
  local input_str::String
  local output_str::String
  local var_s::String
  local inputs_strl::List{String} = nil
  local inputs::List{InstNode} = fn.inputs
  local c::Component
  local def_exp::Expression
  local ty::ModelicaType

  for s in fn.slots
    @assign input_str = ""
    @assign c = component(listHead(inputs))
    @assign inputs = listRest(inputs)
    if isSome(s.default)
      @match SOME(def_exp) = s.default
      @assign input_str = " = " + toString(def_exp)::String
    end
    @assign input_str = (s.name::String) + (input_str::String)
    if printTypes && isTyped(c)
      ty = getType(c)
      var_s = unparseVariability(variability(c), ty)
      input_str = var_s + toString(ty) + " " + input_str
    end
    inputs_strl = _cons(input_str, inputs_strl)
  end
  #=  Add the default expression if it has any.
  =#
  #=  Add the name from the slot and not the node, since some builtin
  =#
  #=  functions don't bother using proper names for the nodes.
  =#
  #=  Add a $ in front of the name if the parameter only takes positional
  =#
  #=  arguments.
  =#
  #=  Add the type if the parameter has been typed.
  =#
  input_str = stringDelimitList(listReverse(inputs_strl), ", ")
  output_str = if printTypes && isTyped(fn)
    " => " + toString(fn.returnType)
  else
    ""
  end
  fn_name = nameConsiderBuiltin(fn)
  #=  if isSome(display_name) then Util.getOption(display_name) else fn.path;
  =#
  str = AbsynUtil.pathString(fn_name) + "(" + input_str + ")" + output_str
  return str
end

"""The name calls of `fn` use: a builtin function's builtin name (or the last part of its path), else its path."""
function nameConsiderBuiltin(fn::MODELICA_FUNCTION)::Absyn.Path
  local attrs::FUNCTION_ATTRIBUTES = fn.attributes
  if attrs.builtin != FUNCTION_BUILTIN
    return fn.path
  end
  local builtinName::Option{String} = attrs.builtinName
  return builtinName === nothing ? AbsynUtil.pathLast(fn.path) : Absyn.IDENT(something(builtinName))
end

function name(fn::MODELICA_FUNCTION)::Absyn.Path
  local path::Absyn.Path = fn.path
  return path
end

"""Marks this function as collected for addition to the function tree."""
function collect(fn::MODELICA_FUNCTION)
  #=  The pointer might be immutable, check before assigning to it.
  =#
  return if P_Pointer.access(fn.status) != FUNCTION_STATUS_BUILTIN
    P_Pointer.update(fn.status, FUNCTION_STATUS_COLLECTED)
  end
end

"""
  Returns true if this function has already been added to the function tree
  (or shouldn't be added, e.g. if it's builtin), otherwise false.
"""
function isCollected(fn::MODELICA_FUNCTION)::Bool
  local status::FunctionStatus = P_Pointer.access(fn.status)
  return status == FUNCTION_STATUS_BUILTIN || status == FUNCTION_STATUS_COLLECTED
end

function markSimplified(fn::MODELICA_FUNCTION)
  return if P_Pointer.access(fn.status) != FUNCTION_STATUS_BUILTIN
    P_Pointer.update(fn.status, FUNCTION_STATUS_SIMPLIFIED)
  end
end

function isSimplified(fn::MODELICA_FUNCTION)::Bool
  local status::FunctionStatus = P_Pointer.access(fn.status)
  return status == FUNCTION_STATUS_BUILTIN || status == FUNCTION_STATUS_SIMPLIFIED
end

function markEvaluated(fn::MODELICA_FUNCTION)
  return if P_Pointer.access(fn.status) != FUNCTION_STATUS_BUILTIN
    P_Pointer.update(fn.status, FUNCTION_STATUS_EVALUATED)
  end
end

function isEvaluated(fn::MODELICA_FUNCTION)::Bool
  local status::FunctionStatus = P_Pointer.access(fn.status)
  return status == FUNCTION_STATUS_BUILTIN || status == FUNCTION_STATUS_EVALUATED
end

function mapCachedFuncs(inNode::InstNode, mapFn::MapFn)
  local cls_node::InstNode
  local cache::CachedData
  cls_node = classScope(inNode)
  cache = getFuncCache(cls_node)
  cache = begin
    @match cache begin
      C_FUNCTION(__) => begin
        cacheFuncs = MODELICA_FUNCTION[mapFn(fn) for fn in cache.funcs]
        cache = C_FUNCTION(cacheFuncs, cache.typed, cache.specialBuiltin)
        cache
      end

      _ => begin
        fail()
      end
    end
  end
  return setFuncCache(cls_node, cache)
end

function getCachedFuncs(inNode::InstNode)
  local outFuncs::Vector{MODELICA_FUNCTION}
  local cache::CachedData
  cache = getFuncCache(classScope(inNode))
  outFuncs = begin
    @match cache begin
      C_FUNCTION(__) => begin
        cache.funcs
      end
      _ => begin
        fail()
      end
    end
  end
  return outFuncs
end

function instFunction3(fnNode::InstNode)::InstNode
  #= A partial function is instantiated too (omc: instPartial = true). A redeclared
     component's original declaration may look up its partial default package
     (PartialMedium), whose constants call its partial functions (setState_pTX through
     h_default); skipped, the function's own class node got the expressions (got
     non-instantiated function, Buildings DHC). =#
  fnNode = instantiateN1(fnNode, EMPTY_NODE(), true)
  cacheInitFunc(fnNode)
  instExpressions(fnNode)
  return fnNode
end

function instFunction2(
  fnPath::Absyn.Path,
  fnNode::InstNode,
  info::SourceInfo,
  parent::InstNode = EMPTY_NODE(),
)::Tuple{InstNode, Bool}
  local specialBuiltin::Bool

  local def::SCode.Element = definition(fnNode)

   (fnNode, specialBuiltin) = begin
    local cdef::SCode.ClassDef
    local fn::MODELICA_FUNCTION
    local cr::Absyn.ComponentRef
    local sub_fnNode::InstNode
    local funcs::List{MODELICA_FUNCTION}
    local fn_ders::List{FUNCTION_DER}
    @match def begin
      SCode.CLASS(__) where {(SCodeUtil.isOperatorRecord(def))} => begin
        @assign fnNode = instFunction3(fnNode)
        @assign fnNode = instConstructor(fnPath, fnNode, info)
        (fnNode, false)
      end

      SCode.CLASS(__) where {(SCodeUtil.isRecord(def))} => begin
        fnNode = instFunction3(fnNode)
        fnNode = instDefaultConstructor(fnPath, fnNode, info)
        (fnNode, false)
      end

      SCode.CLASS(restriction = SCode.R_OPERATOR(__), classDef = cdef && SCode.PARTS(__)) => begin
        fnNode = instFunction3(fnNode)
        fnNode = instOperatorFunctions(fnNode, info)
        (fnNode, false)
      end

      SCode.CLASS(classDef = cdef && SCode.OVERLOAD(__)) => begin
        for p in cdef.pathLst
          cr = AbsynUtil.pathToCref(p)
           (_, sub_fnNode, specialBuiltin) = instFunction(cr, fnNode, info)
          for f in getCachedFuncs(sub_fnNode)
            fnNode = cacheAddFunc(fnNode, f, specialBuiltin)
          end
        end
        (fnNode, false)
      end

      #= An enumeration type name used as an operator: its conversion operator
         E(Integer) => E (omc instFunction2). =#
      SCode.CLASS(__) where {isEnumerationType(fnNode)} => begin
        local conv = makeEnumConversionOp(fnNode)
        conv = setNodeType(ROOT_CLASS(parent), conv)
        conv = instFunction3(conv)
        fnNode = cacheAddFunc(fnNode, new(fnPath, conv), false)
        (fnNode, false)
      end

      SCode.CLASS(__) => begin
        if SCodeUtil.isOperator(def)
          checkOperatorRestrictions(fnNode)
        end
        fnNode = setNodeType(ROOT_CLASS(parent), fnNode)
        fnNode = instFunction3(fnNode)
        fn = new(fnPath, fnNode)
        specialBuiltin = isSpecialBuiltin(fn)
        fnDerivatives =
          instDerivatives(fnNode, fn)
        fn = MODELICA_FUNCTION(
          fn.path,
          fn.node,
          fn.inputs,
          fn.outputs,
          fn.locals,
          fn.slots,
          fn.returnType,
          fn.attributes,
          fnDerivatives,
          fn.status,
          fn.callCounter,
          instPartialDerivedVars(def.classDef, fn.inputs, fn, info))
        fnNode = cacheAddFunc(fnNode, fn, specialBuiltin)
        (fnNode, specialBuiltin)
      end
    end
  end
  return (fnNode, specialBuiltin)
end

#= The inputs of a partial derivative of a function, `function df = der(f, x, y)`, by index
   (omc instPartialDerivedVars). =#
function instPartialDerivedVars(classDef::SCode.ClassDef, inputs::List{InstNode}, fn::MODELICA_FUNCTION, info::SourceInfo)::List{Int}
  classDef isa SCode.PDER || return nil
  local derivedVars = Int[]
  local ins = Base.collect(inputs)
  for var in classDef.derivedVariables
    local index = findfirst(i -> name(i) == var, ins)
    if index === nothing
      Error.addSourceMessage(Error.PARTIAL_DERIVATIVE_INPUT_NOT_FOUND,
        list(var, AbsynUtil.pathString(getDerivedFunctionName(fn))), info)
      fail()
    end
    push!(derivedVars, index)
  end
  return list(derivedVars...)
end

#= The inputs a partial derivative is taken with respect to are scalar Reals (omc
   checkPartialDerivativeTypes). =#
function checkPartialDerivativeTypes(fn::MODELICA_FUNCTION)
  local ins = Base.collect(fn.inputs)
  for i in fn.derivedInputs
    local node = ins[i]
    local ty = getType(node)
    if !(isReal(ty) && isScalar(ty))
      Error.addSourceMessage(Error.PARTIAL_DERIVATIVE_INPUT_INVALID_TYPE,
        list(name(node), AbsynUtil.pathString(getDerivedFunctionName(fn))), InstNode_info(fn.node))
      fail()
    end
  end
  return nothing
end

#= Whether a function is a partial derivative of a function, df = der(f, x) (omc). =#
isPartialDerivative(fn::MODELICA_FUNCTION)::Bool = !listEmpty(fn.derivedInputs)

#= The function a partial derivative is of: df = der(f, x) => f (omc getDerivedFunctionName). =#
function getDerivedFunctionName(fn::MODELICA_FUNCTION)::Absyn.Path
  local def = definition(fn.node)
  if def isa SCode.CLASS && def.classDef isa SCode.PDER
    return def.classDef.functionPath
  end
  return fn.path
end

#= The conversion operator of an enumeration type, E(index) (omc makeEnumConversionOp):
     function $E "Automatically generated conversion operator for E"
       input Integer index;
       output E value;
     algorithm
       assert(index >= 1 and index <= n, "Enumeration index '" + String(index) + "' out of bounds in call to E()");
       value := ...;
     end $E;
   omc selects the literal with {E.l1, ..., E.ln}[index]; here an if-chain over the literals, which
   the backend takes (it has no subscripted expressions). The class is
   named $E so that E inside it is the type; the function keeps the call's path. =#
function makeEnumConversionOp(enumNode::InstNode)::InstNode
  local info = InstNode_info(enumNode)
  local enum_name = name(enumNode)
  local elem = definition(resolveInner(lastBaseClass(enumNode)))
  @match SCode.CLASS(classDef = SCode.ENUMERATION(enumLst = lits)) = elem
  local lits_v = Base.collect(lits)
  local n = length(lits_v)
  local index = Absyn.CREF(Absyn.CREF_IDENT("index", nil))
  local params = list(
    SCode.COMPONENT("index", SCode.defaultPrefixes, SCode.defaultInputAttr,
                    Absyn.TPATH(Absyn.IDENT("Integer"), NONE()), SCode.NOMOD(), SCode.noComment, NONE(), info),
    SCode.COMPONENT("value", SCode.defaultPrefixes, SCode.defaultOutputAttr,
                    Absyn.TPATH(Absyn.IDENT(enum_name), NONE()), SCode.NOMOD(), SCode.noComment, NONE(), info),
  )
  local in_range = Absyn.LBINARY(Absyn.RELATION(index, Absyn.GREATEREQ(), Absyn.INTEGER(1)), Absyn.AND(),
                                 Absyn.RELATION(index, Absyn.LESSEQ(), Absyn.INTEGER(n)))
  local message = Absyn.BINARY(Absyn.STRING("Enumeration index '"), Absyn.ADD(),
    Absyn.BINARY(Absyn.CALL(Absyn.CREF_IDENT("String", nil), Absyn.FUNCTIONARGS(list(index), nil), nil),
                 Absyn.ADD(), Absyn.STRING("' out of bounds in call to " * enum_name * "()")))
  local level = Absyn.CREF(Absyn.CREF_QUAL("AssertionLevel", nil, Absyn.CREF_IDENT("error", nil)))
  local assign = k -> list(SCode.ALG_ASSIGN(Absyn.CREF(Absyn.CREF_IDENT("value", nil)),
    Absyn.CREF(Absyn.CREF_QUAL(enum_name, nil, Absyn.CREF_IDENT(lits_v[k].literal, nil))), SCode.noComment, info))
  local is_k = k -> Absyn.RELATION(index, Absyn.EQUAL(), Absyn.INTEGER(k))
  local select = if n == 1
    assign(1)
  else
    list(SCode.ALG_IF(is_k(1), assign(1), list(((is_k(k), assign(k)) for k in 2:n-1)...), assign(n),
                      SCode.noComment, info))
  end
  local stmts = SCode.ALG_ASSERT(in_range, message, level, SCode.noComment, info) <| select
  local fn_def = SCode.PARTS(params, nil, nil, list(SCode.ALGORITHM(stmts)), nil, nil, nil, NONE())
  local fn_elem = SCode.CLASS("\$" * enum_name, SCode.defaultPrefixes, SCode.NOT_ENCAPSULATED(),
                              SCode.NOT_PARTIAL(), SCode.R_FUNCTION(SCode.FR_NORMAL_FUNCTION(false)), fn_def,
                              SCode.COMMENT(NONE(), SOME("Automatically generated conversion operator for " * enum_name)),
                              info)
  return new(fn_elem, parentScope(enumNode, true))
end

"""Instantiates the given InstNode as a function."""
function instFunctionNode(node::InstNode)::InstNode
  if _parallelTypingActive()
    return _withClaim(() -> instFunctionNode2(node), _refId(node))
  end
  return instFunctionNode2(node)
end

function instFunctionNode2(node::InstNode)::InstNode
  local cache::CachedData
  @assign cache = getFuncCache(node)
   () = begin
    @match cache begin
      C_FUNCTION(__) => begin
        ()
      end
      _ => begin
        (node, _) =
          instFunction2(scopePath(node), node, InstNode_info(node))#info(node))
        ()
      end
    end
  end
  return node
end

function instFunctionRef(
  fn_ref::ComponentRef,
  info::SourceInfo,
)::Tuple{ComponentRef, InstNode, Bool}
  local specialBuiltin::Bool
  local fn_node::InstNode = classScope(node(fn_ref))
  #= Cache check plus instantiation must be atomic per function node: typing
     workers instantiate functions lazily. =#
  if _parallelTypingActive()
    (fn_node, specialBuiltin) = _withClaim(
      () -> instFunctionRef2(fn_ref, fn_node, info), _refId(fn_node))
  else
    (fn_node, specialBuiltin) = instFunctionRef2(fn_ref, fn_node, info)
  end
  return (fn_ref, fn_node, specialBuiltin)
end

function instFunctionRef2(
  fn_ref::ComponentRef,
  fn_node::InstNode,
  info::SourceInfo,
)::Tuple{InstNode, Bool}
  local parent::InstNode
  local cache::CachedData = getFuncCache(fn_node)
  #=  Check if a cached instantiation of this function already exists. =#
  return begin
    @match cache begin
      C_FUNCTION(__) => begin
        (fn_node, cache.specialBuiltin)
      end
      _ => begin
        @assign parent =
          if isRedeclare(node(fn_ref)) ||
             isSimple(fn_ref)
            EMPTY_NODE()
          else
            node(rest(fn_ref))
          end
        if !isComponent(parent)
          parent = EMPTY_NODE()
        end
        instFunction2(scopePath(fn_node), fn_node, info, parent)
      end
    end
  end
end

function instFunction(
  functionName,
  scope::InstNode,
  info::SourceInfo,
)::Tuple{ComponentRef, InstNode, Bool}
  local specialBuiltin::Bool
  local fn_node::InstNode
  local fn_ref::ComponentRef
  local cache::CachedData
  fn_ref = lookupFunction(functionName, scope, info)
  (fn_ref, fn_node, specialBuiltin) = instFunctionRef(fn_ref, info)
  return (fn_ref, fn_node, specialBuiltin)
end

function lookupFunction(
  functionName,
  scope::InstNode,
  info::SourceInfo,
)::ComponentRef
  local functionRef::ComponentRef
  local found_scope::InstNode
  local state::LookupState
  local functionPath::Absyn.Path
  local prefix::ComponentRef
  local is_class::Bool
  functionPath = AbsynUtil.crefToPath(functionName)
  #=  Make sure the name is a path.
  =#
  (functionRef, found_scope) = lookupFunctionName(functionName, scope, info)
  #=  If we found a function class we include the root in the prefix, but if we
  =#
  #=  instead found a component (i.e. a functional parameter) we don't.
  =#
  is_class = isClass(node(functionRef))
  prefix = fromNodeList(scopeList!(
    found_scope,
    #=includeRoot=# is_class,
  ))
  functionRef = append(functionRef, prefix)
  return functionRef
end

function lookupFunctionSimple(functionName::String, scope::InstNode)::ComponentRef
  local functionRef::ComponentRef
  local found_scope::InstNode
  local state::LookupState
  local functionPath::Absyn.Path
  local prefix::ComponentRef
   (functionRef, found_scope) =
    lookupFunctionNameSilent(Absyn.CREF_IDENT(functionName, nil), scope)
  prefix = fromNodeList(scopeList(found_scope))
  functionRef = append(functionRef, prefix)
  return functionRef
end

function new(path::Absyn.Path, node::InstNode)::MODELICA_FUNCTION
  local fn::MODELICA_FUNCTION
  local cls::Class
  local inputs::List{InstNode}
  local outputs::List{InstNode}
  local locals::List{InstNode}
  local slots::List{SLOT}
  local attr::FUNCTION_ATTRIBUTES
  local status::FunctionStatus

  (inputs, outputs, locals) = collectParams(node)
  @assign attr = makeAttributes(node, inputs, outputs)
  #=  Make sure builtin functions aren't added to the function tree.
  =#
  @assign status = if isBuiltinAttr(attr)
    FUNCTION_STATUS_COLLECTED
  else
    FUNCTION_STATUS_INITIAL
  end
  @assign fn = MODELICA_FUNCTION(
    path,
    node,
    inputs,
    outputs,
    locals,
    nil,
    TYPE_UNKNOWN(),
    attr,
    nil,
    P_Pointer.create(status, FunctionStatus),
    P_Pointer.create(0, Int),
  )
  return fn
end

function isValidParamState(cls::InstNode)::Bool
  local isValid::Bool
  @assign isValid = begin
    @match restriction(getClass(cls)) begin
      RESTRICTION_RECORD(__) => begin
        true
      end
      RESTRICTION_TYPE(__) => begin
        true
      end
      RESTRICTION_OPERATOR(__) => begin
        true
      end
      RESTRICTION_FUNCTION(__) => begin
        true
      end

      RESTRICTION_EXTERNAL_OBJECT(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isValid
end

function isValidParamType(ty::ModelicaType)::Bool
  local isValid::Bool
  @assign isValid = begin
    @match ty begin
      TYPE_INTEGER(__) => begin
        true
      end

      TYPE_REAL(__) => begin
        true
      end

      TYPE_STRING(__) => begin
        true
      end

      TYPE_BOOLEAN(__) => begin
        true
      end

      TYPE_CLOCK(__) => begin
        true
      end

      TYPE_ENUMERATION(__) => begin
        true
      end

      TYPE_ENUMERATION_ANY(__) => begin
        true
      end

      TYPE_POLYMORPHIC(__) => begin
        true
      end

      TYPE_ARRAY(__) => begin
        isValidParamType(ty.elementType)
      end

      TYPE_COMPLEX(__) => begin
        isValidParamState(ty.cls)
      end

      TYPE_FUNCTION(__) => begin
        true
      end

      TYPE_METABOXED(__) => begin
        isValidParamType(ty.ty)
      end

      _ => begin
        false
      end
    end
  end
  return isValid
end

function checkParamTypes2(params::List{<:InstNode})
  local ty::ModelicaType
  return for p in params
    ty = getType(p)
    if !isValidParamType(ty)
      Error.addSourceMessage(
        Error.INVALID_FUNCTION_VAR_TYPE,
        list(toString(ty), name(p)),
        InstNode_info(p),
      )
      fail()
    end
  end
end

"""
  Checks that all the function parameters have types which are allowed in a
  function.
"""
function checkParamTypes(fn::MODELICA_FUNCTION)
  checkParamTypes2(fn.inputs)
  checkParamTypes2(fn.outputs)
  return checkParamTypes2(fn.locals)
end

function makeAttributes(
  @nospecialize(node::InstNode),
  @nospecialize(inputs::List{<:InstNode}),
  @nospecialize (outputs::List{<:InstNode})
)::FUNCTION_ATTRIBUTES
  local attr::FUNCTION_ATTRIBUTES

  local def::SCode.Element
  local params::Vector{InstNode}
  local res::SCode.Restriction
  local fres::SCode.FunctionRestriction
  local is_partial::Bool
  local cmts::List{SCode.COMMENT}
  local cmt::SCode.COMMENT

  @assign def = definition(node)
  @assign res = SCodeUtil.getClassRestriction(def)
  # Error.assertion(
  #   SCodeUtil.isFunctionRestriction(res),
  #   getInstanceName() + " got non-function restriction",
  #   sourceInfo(),
  # ) TODO
  @match SCode.R_FUNCTION(functionRestriction = fres) = res
  @assign is_partial = SCodeUtil.isPartial(def)
  @assign cmts = getComments(node)
  @assign cmt = mergeFunctionAnnotations(cmts)
  @assign attr = begin
    local is_impure::Bool
    local is_om_pure::Bool
    local has_out_params::Bool
    local has_unbox_args::Bool
    local nameVar::String
    local in_params::List{String}
    local out_params::List{String}
    local inline_ty::InlineType
    #=  External function. =#
    @matchcontinue fres begin
      SCode.FR_EXTERNAL_FUNCTION(is_impure) => begin
        @assign in_params = list(name(i) for i in inputs)
        @assign out_params = list(name(o) for o in outputs)
        @assign nameVar = SCodeUtil.isBuiltinFunction(def, in_params, out_params)
        @assign inline_ty = commentIsInlineFunc(cmt)
        @assign is_impure = is_impure || hasImpure(cmt)
        @assign has_unbox_args = hasUnboxArgsAnnotation(cmt)
        FUNCTION_ATTRIBUTES(inline_ty, is_impure, is_partial, FUNCTION_BUILTIN, SOME(nameVar), has_unbox_args)
      end

      SCode.FR_PARALLEL_FUNCTION(__) => begin
        #=  Parallel function: there are some builtin functions.
        =#
        @assign in_params = list(name(i) for i in inputs)
        @assign out_params = list(name(o) for o in outputs)
        @assign nameVar = SCodeUtil.isBuiltinFunction(def, in_params, out_params)
        @assign inline_ty = commentIsInlineFunc(cmt)
        @assign has_unbox_args = hasUnboxArgsAnnotation(cmt)
        FUNCTION_ATTRIBUTES(inline_ty, false, is_partial, FUNCTION_BUILTIN, SOME(nameVar), has_unbox_args)
      end

      SCode.FR_PARALLEL_FUNCTION(__) => begin
        #=  Parallel function: non-builtin.
        =#
        @assign inline_ty = commentIsInlineFunc(cmt)
        FUNCTION_ATTRIBUTES(inline_ty, false, is_partial, getBuiltin(def), nothing, false)
      end

      SCode.FR_KERNEL_FUNCTION(__) => begin
        FUNCTION_ATTRIBUTES(NO_INLINE, false, is_partial, FUNCTION_NOT_BUILTIN, nothing, false)
      end

      _ => begin
        #=  Kernel functions: never builtin and never inlined.
        =#
        #=  Normal function.
        =#
        inline_ty = commentIsInlineFunc(cmt)
        #=  In Modelica 3.2 and before, external functions with side-effects are not marked.
        =#
        @assign is_impure =
          SCodeUtil.isRestrictionImpure(
            res,
#            Config.languageStandardAtLeast(Config.LanguageStandard.V3_3) ||
            !listEmpty(outputs),
          ) || SCodeUtil.commentHasBooleanNamedAnnotation(
            cmt,
            "__ModelicaAssociation_Impure",
          )
        FUNCTION_ATTRIBUTES(inline_ty, is_impure, is_partial, getBuiltin(def), nothing, false)
      end
    end
  end
  return attr
end

function commentIsInlineFunc(cmt::SCode.COMMENT)::InlineType
  if SCodeUtil.commentHasBooleanNamedAnnotation(cmt, "LateInline")
    return AFTER_INDEX_RED_INLINE
  elseif SCodeUtil.commentHasBooleanNamedAnnotation(cmt, "Inline")
    return EARLY_INLINE
  end
  return NO_INLINE
end

"""Merges the function's comments from inherited classes."""
function mergeFunctionAnnotations(comments::List{<:SCode.COMMENT})::SCode.COMMENT
  local outComment::SCode.COMMENT

  local comment::Option{String} = NONE()
  local mod::SCode.Mod = SCode.NOMOD()
  local mod2::SCode.Mod

  for cmt in comments
    if isNone(comment)
      @assign comment = cmt.comment
    end
    @assign mod = begin
      @match cmt begin
        SCode.COMMENT(annotation_ = SOME(SCode.ANNOTATION(modification = mod2))) => begin
          SCodeUtil.mergeModifiers(mod2, mod)
        end

        _ => begin
          mod
        end
      end
    end
  end
  @assign outComment = begin
    @match mod begin
      SCode.NOMOD(__) => begin
        SCode.COMMENT(NONE(), comment)
      end

      _ => begin
        SCode.COMMENT(SOME(SCode.ANNOTATION(mod)), comment)
      end
    end
  end
  return outComment
end


function getBuiltin(def::SCode.Element)::BuiltinKind
  return SCodeUtil.isBuiltinElement(def) ? FUNCTION_BUILTIN_PTR : FUNCTION_NOT_BUILTIN
end

function hasImpure(cmt::SCode.COMMENT)::Bool
  local res::Bool =
    SCodeUtil.commentHasBooleanNamedAnnotation(cmt, "__ModelicaAssociation_Impure")
  return res
end

function makeSlot(@nospecialize(componentArg::InstNode), index::Int)::SLOT
  local slot::SLOT
  local comp::Component
  local default::Option{Expression}
  local nameVar::String
  try
    comp = component(componentArg)
    default = typedExp(getImplicitBinding(comp))
    nameVar = name(componentArg)
    if stringGet(nameVar, 1) == 36
      if stringLength(nameVar) > 4 && substring(nameVar, 1, 4) == "in_"
        nameVar = substring(nameVar, 5, stringLength(nameVar))
      end
    end
    slot = SLOT(
      name(componentArg),
      SLOT_TYPE_GENERIC,
      default,
      NONE(),
      index,
      SLOT_NOT_EVALUATED,
    )
  catch e
    #    Error.assertion(false, getInstanceName() + " got invalid component", sourceInfo())
    @error "Error. Our error was $e"
    fail()
  end
  #=  Remove $in_ for OM input output arguments.
  =#
  #= /*$*/ =#
  return slot
end

function makeSlots(@nospecialize(inputs::List{<:InstNode}))::List{SLOT}
  local slots::List{SLOT} = nil
  local index::Int = 1
  for i in inputs
    slots = _cons(makeSlot(i, index), slots)
    index = index + 1
  end
  slots = listReverseInPlace(slots)
  return slots
end

function paramDirection(@nospecialize(componentArg::InstNode))::DirectionType
  local direction::DirectionType
  local cty::ConnectorType.TYPE
  local io::Int
  local vis::VisibilityType
  local var::VariabilityType

  @match ATTRIBUTES(
    connectorType = cty,
    direction = direction,
    innerOuter = io,
  ) = getAttributes(component(componentArg))
  @assign vis = visibility(componentArg)
  @assign var = variability(component(componentArg))
  #=  Function components may not be connectors.
  =#
  if isFlowOrStream(cty)
    Error.addSourceMessage(
      Error.INNER_OUTER_FORMAL_PARAMETER,
      list(toString(cty), name(componentArg)),
      InstNode_info(componentArg),
    )
    fail()
  end
  #=  Function components may not be inner/outer.
  =#
  if io != InnerOuter.NOT_INNER_OUTER
    # Error.addSourceMessage(
    #   Error.INNER_OUTER_FORMAL_PARAMETER,
    #   list(innerOuterString(io), name(componentArg)),
    #   info(component),
    # )
    fail()
  end
  #=  Formal parameters must be public, other function variables must be protected.
  =#
  if direction != Direction.NONE
    if vis == Visibility.PROTECTED
      # Error.addSourceMessage(
      #   Error.PROTECTED_FORMAL_FUNCTION_VAR,
      #   list(name(componentArg)),
      #   info(componentArg),
      # )
      @error "Formal parameters must be public, other function variables must be protected."
      fail()
    end
  elseif vis == Visibility.PUBLIC
    # Error.addSourceMessageAsError(
    #   Error.NON_FORMAL_PUBLIC_FUNCTION_VAR,
    #   list(name(componentArg)),
    #   info(componentArg),
    # )
#    componentArg),
      # )
      @error "Non formal public funcition variable"
    fail()
  end
  return direction
end

"""  Sorts all the function parameters as inputs, outputs and locals. """
function collectParams(
  @nospecialize(node::InstNode),
  inputs::List{InstNode} = nil,
  outputs::List{InstNode} = nil,
  locals::List{InstNode} = nil,
)::Tuple{List{InstNode}, List{InstNode}, List{InstNode}}

  local cls::Class
  local comps::Vector{InstNode}
  local n::InstNode

  # Error.assertion(
  #   isClass(node),
  #   getInstanceName() + " got non-class node",
  #   sourceInfo(),
  # ) TODO
  @assign cls = getClass(node)
   () = begin
    @match cls begin
      INSTANCED_CLASS(elements = CLASS_TREE_FLAT_TREE(components = comps)) =>
        begin
          for i = arrayLength(comps):(-1):1
            @assign n = comps[i]
             () = begin
              @match paramDirection(n) begin
                Direction.INPUT => begin
                  #=  Sort the components based on their direction.
                  =#
                  @assign inputs = _cons(n, inputs)
                  ()
                end

                Direction.OUTPUT => begin
                  @assign outputs = _cons(n, outputs)
                  ()
                end

                Direction.NONE => begin
                  @assign locals = _cons(n, locals)
                  ()
                end
              end
            end
          end
          ()
        end

      EXPANDED_DERIVED(__) => begin
         (inputs, outputs, locals) = collectParams(cls.baseClass)
        ()
      end

      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " got non-instantiated function",
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return (inputs, outputs, locals)
end

function analyseUnusedParametersExp2(
  exp::Expression,
  params::List{<:InstNode},
)::List{InstNode}

   () = begin
    @match exp begin
      CREF_EXPRESSION(__) => begin
        (params, _) = ListUtil.deleteMemberOnTrue(exp.cref, params, containsNode, InstNode)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return params
end

function analyseUnusedParametersExp(
  exp::Expression,
  params::List{<:InstNode},
)::List{InstNode}

  if !listEmpty(params)
    @assign params = fold(exp, analyseUnusedParametersExp2, params, List{InstNode})
  end
  return params
end

function analyseUnusedParameters(fn::MODELICA_FUNCTION)::List{Int}
  local unusedInputs::List{Int} = nil

  local inputs::List{InstNode}
  local index::Int

  @assign inputs = foldExp(fn, analyseUnusedParametersExp, fn.inputs, List{InstNode})
  for i in inputs
    @assign index =
      ListUtil.positionOnTrue(fn.inputs, (inp) -> refEqual(i, inp))
    @assign unusedInputs = _cons(index, unusedInputs)
  end
  return unusedInputs
end

"""
  Helper function for getBody
"""
function getBody2(node::InstNode)
  local body::Vector{Statement}
  local cls::Class = getClass(node)
  local fn_body::ALGORITHM
  body = begin
    @match cls begin
      INSTANCED_CLASS(
        sections = SECTIONS(algorithms = [fn_body,]),
      ) => begin
        fn_body.statements
      end
      INSTANCED_CLASS(sections = SECTIONS_EMPTY(__)) => begin
        []#Was nil
      end
      INSTANCED_CLASS(
        sections = SECTIONS(algorithms) where length(algorithms) > 1,
      ) => begin
        Error.assertion(
          false,
          getInstanceName() + " got function with multiple algorithm sections",
          sourceInfo(),
        )
        fail()
      end
      TYPED_DERIVED(__) => begin
        getBody2(cls.baseClass)
      end
      _ => begin
        #Error.assertion(false, getInstanceName() + " got unknown function", sourceInfo())
        @error "Got a unknown function for " * toString(node) * ", $(isExternalFunction(getClass(node)))"
        fail()
      end
    end
  end
  return body
end

function makeReturnType(fn::MODELICA_FUNCTION)::ModelicaType
  local returnType::ModelicaType
  local ret_tyl::List{ModelicaType}
  ret_tyl = list(getType(o) for o in fn.outputs)
  returnType = begin
    @match ret_tyl begin
      nil() => begin
        TYPE_NORETCALL()
      end

      returnType <| nil() => begin
        returnType
      end

      _ => begin
        TYPE_TUPLE(ret_tyl, NONE())
      end
    end
  end
  return returnType
end

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

const NamedArg = Tuple{String,B} where {B <: Expression}
const TypedArg = Tuple{A,B,C} where {A,B,C}
const TypedNamedArg = Tuple{String, ExpT, TypeT, VariabilityT} where {ExpT <: Expression, TypeT <: M_Type, VariabilityT <: Int}

@Uniontype MatchedFunction begin
  @Record MATCHED_FUNC begin
    func::M_FUNCTION
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

const SlotType = (() -> begin #= Enumeration =#
  POSITIONAL = 1  #= Only accepts positional arguments. =#
  NAMED = 2  #= Only accepts named argument. =#
  GENERIC = 3  #= Accepts both positional and named arguments. =#
  #= Determines which type of argument a slot accepts. =#
  () -> (POSITIONAL; NAMED; GENERIC)  #= Accepts both positional and named arguments. =#
end)()
const SlotTypeType = Int

const SlotEvalStatus = (() -> begin #= Enumeration =#
  NOT_EVALUATED = 1
  EVALUATING = 2
  EVALUATED = 3
  () -> (NOT_EVALUATED; EVALUATING; EVALUATED)
end)()
const SlotEvalStatusType = Int

@UniontypeDecl Slot

function hasName(name::String, slot::Slot)::Bool
  local hasName::Bool = name == slot.name
  return hasName
end

function named(slot::Slot)::Bool
  local pos::Bool
  @assign pos = begin
    @match slot.ty begin
      SlotType.NAMED => begin
        true
      end
      SlotType.GENERIC => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return pos
end

function positional(slot::Slot)::Bool
  local pos::Bool
  @assign pos = begin
    @match slot.ty begin
      SlotType.POSITIONAL => begin
        true
      end
      SlotType.GENERIC => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return pos
end

@Uniontype Slot begin
  @Record SLOT begin
    name::String
    ty::SlotTypeType
    default::Option{Expression}
    arg::Option{TypedArg}
    index::Int
    evalStatus::SlotEvalStatusType
  end
end

@UniontypeDecl FunctionMatchKind

function isExactVectorized(mk::FunctionMatchKind)::Bool
  local b::Bool

  @assign b = begin
    @match mk begin
      VECTORIZED_MATCH_KIND(baseMatch = EXACT(__)) => begin
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

function getExactVectorizedMatches(
  matchedFunctions::List{<:MatchedFunction},
)::List{MatchedFunction}
  local outFuncs::List{MatchedFunction} =
    list(mf for mf in matchedFunctions if isExactVectorized(mf.mk))
  return outFuncs
end

function getExactMatches(matchedFunctions::Vector{MatchedFunction})::Vector{MatchedFunction}
  local outFuncs::Vector{MatchedFunction} = MatchedFunction[mf for mf in matchedFunctions if isExact(mf.mk)]
  return outFuncs
end


const FunctionStatus = (() -> begin #= Enumeration =#
  BUILTIN = 1  #= A builtin function. =#
  INITIAL = 2  #= The initial status. =#
  EVALUATED = 3  #= Constants in the function has been evaluated by EvalConstants. =#
  SIMPLIFIED = 4  #= The function has been simplified by SimplifyModel. =#
  COLLECTED = 5  #= The function has been added to the function tree. =#
  () -> (BUILTIN; INITIAL; EVALUATED; SIMPLIFIED; COLLECTED)  #= The function has been added to the function tree. =#
end)()

const FunctionStatusType = Int


using MetaModelica
using ExportAll

function getLocalArguments(fn::M_FUNCTION)::List{Expression}
  local localArgs::List{Expression} = nil
  local binding::Binding
  for l in fn.locals
    if isComponent(l)
      @assign binding = getBinding(component(l))
      # Error.assertion(
      #   hasExp(binding),
      #   getInstanceName() + " got local component without binding",
      #   sourceInfo(),
      # )
      localArgs = Cons{Expression}(getExp(binding), localArgs)
    end
  end
  localArgs = listReverseInPlace(localArgs)
  return localArgs
end

function isPartial(fn::M_FUNCTION)::Bool
  return isPartial(fn.node)
end

function foldExpParameter(node::InstNode, foldFn::FoldFunc, arg::ArgT) where {ArgT}

  local comp::Component
  local cls::Class

  @assign comp = component(node)
  @assign arg = foldExp(getBinding(comp), foldFn, arg)
   () = begin
    @match comp begin
      TYPED_COMPONENT(__) => begin
        @assign arg = foldDims(
          comp.ty,
          (dim, acc) -> foldExp(dim, foldFn, acc),
          arg,
        )
        @assign cls = getClass(comp.classInst)
        @assign arg = foldComponents(
          classTree(cls),
          (node, acc) -> foldExpParameter(node, foldFn, acc),
          arg,
        )
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
  fn::M_FUNCTION,
  foldFn::FoldFunc,
  arg::ArgT,
  mapParameters::Bool = true,
  mapBody::Bool = true,
  ) where {ArgT}

  local cls::Class

  @assign cls = getClass(fn.node)
  if mapParameters
    @assign arg = foldComponents(
      classTree(cls),
      (node, acc) -> foldExpParameter(node, foldFn, acc),
      arg,
    )
  end
  if mapBody
    @assign arg = P_Sections.Sections.foldExp(getSections(cls), foldFn, arg)
  end
  return arg
end

function mapExpParameter(node::InstNode, mapFn::MapFunc)
  local comp::Component
  local binding::Binding
  local binding2::Binding
  local cls::Class
  local ty::M_Type
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
  return if dirty
    updateComponent!(comp, node)
  end
end

function mapExp(
  fn::M_FUNCTION,
  mapFn::MapFunc,
  mapParameters::Bool = true,
  mapBody::Bool = true,
  )::M_FUNCTION
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
    updateClass(cls, fn.node)
  end
  return fn
end

function hasOptionalArgument(component::SCode.Element)::Bool
  local res::Bool = SCodeUtil.hasBooleanNamedAnnotationInComponent(
    component,
    "__OpenModelica_optionalArgument",
  )
  return res
end

function hasUnboxArgsAnnotation(cmt::SCode.Comment)::Bool
  local res::Bool =
    SCodeUtil.commentHasBooleanNamedAnnotation(cmt, "__OpenModelica_UnboxArguments")
  return res
end

"""Returns true if the function has the __OpenModelica_UnboxArguments annotation, otherwise false."""
function hasUnboxArgs(fn::M_FUNCTION)::Bool
  local res::Bool

  @assign res = begin
    @match fn.attributes begin
      DAE.FUNCTION_ATTRIBUTES(
        isBuiltin = DAE.FUNCTION_BUILTIN(unboxArgs = res),
      ) => begin
        res
      end

      _ => begin
        false
      end
    end
  end
  return res
end

function getBody(fn::M_FUNCTION)::Vector{Statement}
  local body::Vector{Statement} = getBody2(fn.node)
  return body
end

function makeDAEType(fn::M_FUNCTION, boxTypes::Bool = false)::DAE.Type
  local outType::DAE.Type
  local params::List{DAE.FuncArg} = nil
  local pname::String
  local ty::M_Type
  local ptype::DAE.Type
  local pconst::DAE.Const
  local ppar::DAE
  local pdefault::Option{DAE.Exp}
  local comp::Component
  for param in fn.inputs
    @assign comp = component(param)
    @assign pname = name(param)
    @assign ty = getType(comp)
    @assign ptype = toDAE(if boxTypes
                            box(ty)
                          else
                            ty
                          end)
    @assign pconst = variabilityToDAEConst(variability(comp))
    @assign ppar = parallelismToDAE(parallelism(comp))
    @assign pdefault = Util.applyOption(
      typedExp(getBinding(comp)),
      toDAE,
    )
    @assign params =
      _cons(DAE.FUNCARG(pname, ptype, pconst, ppar, pdefault), params)
  end
  @assign params = listReverse(params)
  @assign ty = if boxTypes
    box(fn.returnType)
  else
    fn.returnType
  end
  @assign outType = DAE.T_FUNCTION(params, toDAE(ty), fn.attributes, fn.path)
  return outType
end

function toDAE(fn::M_FUNCTION, def::DAE.FunctionDefinition)::DAE.Function
  local daeFn::DAE.Function

  local vis::SCode.Visibility
  local par::Bool
  local impr::Bool
  local ity::DAE.InlineType
  local ty::DAE.Type
  local defs::List{DAE.FunctionDefinition}
  local unused_inputs::List{Int}

  @assign vis = SCode.PUBLIC()
  #=  TODO: Use the actual visibility.
  =#
  @assign par = false
  #=  TODO: Use the actual partial prefix.
  =#
  @assign impr = fn.attributes.isImpure
  @assign ity = fn.attributes.inline
  @assign ty = makeDAEType(fn)
  @assign unused_inputs = analyseUnusedParameters(fn)
  @assign defs = _cons(
    def,
    list(
      P_FunctionDerivative.FunctionDerivative.toDAE(fn_der) for fn_der in fn.derivatives
        ),
  )
  @assign daeFn = DAE.FUNCTION(
    fn.path,
    defs,
    ty,
    vis,
    par,
    impr,
    ity,
    unused_inputs,
    ElementSource.createElementSource(info(fn.node)),
    SCodeUtil.getElementComment(definition(fn.node)),
  )
  return daeFn
end

function isDefaultRecordConstructor(fn::M_FUNCTION)::Bool
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

function inlineBuiltin(fn::M_FUNCTION)::DAE.InlineType
  local inlineType::DAE.InlineType
  @assign inlineType = begin
    @match fn.attributes.isBuiltin begin
      DAE.FUNCTION_BUILTIN_PTR(__) => begin
        DAE.BUILTIN_EARLY_INLINE()
      end
      _ => begin
        fn.attributes.inline
      end
    end
  end
  return inlineType
end

function isExternal(fn::M_FUNCTION)::Bool
  local isExt::Bool =
    !isEmpty(fn.node) && isExternalFunction(getClass(fn.node))
  return isExt
end

function setFunctionPointer(isPointer::Bool, fn::M_FUNCTION)::M_FUNCTION
  local attr::DAE.FunctionAttributes = fn.attributes
  @assign attr.isFunctionPointer = isPointer
  @assign fn.attributes = attr
  return fn
end

function isFunctionPointer(fn::M_FUNCTION)::Bool
  local isPointer::Bool = fn.attributes.isFunctionPointer
  return isPointer
end

function isOMImpure(fn::M_FUNCTION)::Bool
  local isImpure::Bool = !fn.attributes.isOpenModelicaPure
  return isImpure
end

function isImpure(fn::M_FUNCTION)::Bool
  local impure::Bool = fn.attributes.isImpure
  return impure
end

function isNotImpure(fn::M_FUNCTION)::Bool
  return !isImpure(fn)
end

function isSubscriptableBuiltin(fn::M_FUNCTION)::Bool
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
function isSpecialBuiltin(fn::M_FUNCTION)::Bool
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

function isBuiltinAttr(attrs::DAE.FunctionAttributes)::Bool
  local isBuiltin::Bool

  @assign isBuiltin = begin
    @match attrs.isBuiltin begin
      DAE.FUNCTION_NOT_BUILTIN(__) => begin
        false
      end
      _ => begin
        true
      end
    end
  end
  return isBuiltin
end

function isBuiltin(fn::M_FUNCTION)::Bool
  local isBuiltin::Bool = isBuiltinAttr(fn.attributes)
  return isBuiltin
end

function applyPartialApplicationArg(
  argName::String,
  argExp::Expression,
  argType::M_Type,
  inputs::List{<:InstNode},
  slots::List{<:Slot},
  fn::M_FUNCTION,
  info::SourceInfo,
)::Tuple{Expression, List{InstNode}, List{Slot}}
  local outSlots::List{Slot} = nil
  local outInputs::List{InstNode} = nil

  local i::InstNode
  local rest_inputs::List{InstNode} = inputs
  local s::Slot
  local rest_slots::List{Slot} = slots
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
)::Tuple{Expression, M_Type, VariabilityType}
  local variability::VariabilityType
  local ty::M_Type

  local fn_ref::ComponentRef
  local args::List{Expression}
  local ty_args::List{Expression} = nil
  local arg_names::List{String}
  local rest_names::List{String}
  local arg_name::String
  local arg_exp::Expression
  local arg_ty::M_Type
  local arg_var::VariabilityType
  local fn::M_FUNCTION
  local next_origin::ORIGIN_Type = setFlag(origin, ORIGIN_SUBEXPRESSION)
  local inputs::List{InstNode}
  local slots::List{Slot}

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

"""
  Types the body of a function, along with any bindings of local variables
  and outputs.
"""
function typeFunctionBody(fn::M_FUNCTION)::M_FUNCTION
  #=  Type the bindings of the outputs and local variables. =#
  for c in fn.outputs
    typeComponentBinding(c, ORIGIN_FUNCTION)
  end
  for c in fn.locals
    typeComponentBinding(c, ORIGIN_FUNCTION)
  end
  #=  Type the algorithm section of the function, if it has one. =#
  typeFunctionSections(fn.node, ORIGIN_FUNCTION)
  #=  Type any derivatives of the function.
  =#
  for fn_der in fn.derivatives
    typeDerivative(fn_der)
  end
  return fn
end

"""Types a function's parameters, local components and default arguments."""
function typeFunctionSignature(fn::M_FUNCTION)
  local attr::DAE.FunctionAttributes
  local node::InstNode = fn.node
  if !isTyped(fn)
    typeClassType(node, EMPTY_BINDING, ORIGIN_FUNCTION, node)
    typeComponents(node, ORIGIN_FUNCTION)
    if isPartial(node)
      applyComponents(
        classTree(getClass(node)),
        boxFunctionParameter,
      )
    end
    for c in fn.inputs
      typeComponentBinding(c, ORIGIN_FUNCTION)
    end
    fnSlots = makeSlots(fn.inputs)
    checkParamTypes(fn)
    fnReturnType = makeReturnType(fn)
    fn = M_FUNCTION(
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
      fn.callCounter)
  end
  return fn
end

function typeFunction(fn::M_FUNCTION)
  fn = typeFunctionSignature(fn)
  fn = typeFunctionBody(fn)
  return fn
end

function getRefCache(fnRef::ComponentRef)
  local functions::Vector{M_Function}
  local fn_node::InstNode
  fn_node = classScope(node(fnRef))
  @match C_FUNCTION(funcs = functions) = getFuncCache(fn_node)
  return functions
end

"""
 Returns the function(s) in the cache of the given node, and types them if
 they are not already typed.
"""
function typeNodeCache(@nospecialize(functionNode::InstNode))::Vector{M_FUNCTION}
  local functions::Vector{M_FUNCTION}
  local fn_node::InstNode
  local typed::Bool
  local special::Bool
  local name::String
  fn_node = classScope(functionNode)
  #@match C_FUNCTION(functions, typed, special) = getFuncCache(fn_node)
  local cache = getFuncCache(fn_node)
  typed = cache.typed
  functions = cache.funcs
  #=  Type the function(s) if not already done. =#
  if !typed
    #functions = M_FUNCTION[typeFunctionSignature(f) for f in functions]
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
function typeRefCache(@nospecialize(functionRef::ComponentRef))::Vector{M_FUNCTION}
  local functions::Vector{M_FUNCTION}
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

function isTyped(fn::M_FUNCTION)::Bool
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
  funcs::Vector{M_Function},
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
  funcs::Vector{M_Function},
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
  func::M_FUNCTION,
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
    @match (out_args, matchKind) = matchArgs(func, out_args, info, vectorize)
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
  argExp::Expression,
  argTy::M_Type,
  inputTy::M_Type,
  vectArg::Expression,
  vectDims::List{<:Dimension},
  info::SourceInfo,
)::Tuple{Expression, M_Type, Expression, List{Dimension}, MatchKindType}
  local matchKind::MatchKindType
  local arg_dims::List{Dimension}
  local input_dims::List{Dimension}
  local vect_dims::List{Dimension}
  local rest_dims::List{Dimension}
  local rest_ty::M_Type
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
  (vect_dims, rest_dims) = ListUtil.split(arg_dims, vect_dims_count)
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
  func::M_FUNCTION,
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
  local arg_ty::M_Type
  local input_ty::M_Type
  local ty::M_Type
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
    if arg_var > variability(comp)
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

function lookupSlotInArray(slotName::String, slots::Vector{<:Slot})::Option{Slot}
  local outSlot::Option{Slot}

  local slot::Slot

  try
    @assign slot = ArrayUtil.getMemberOnTrue(slotName, slots, P_Slot.hasName)
    @assign outSlot = SOME(slot)
  catch
    @assign outSlot = NONE()
  end
  return outSlot
end

function evaluateSlotExp_traverser(
  exp::Expression,
  slots::Vector{<:Slot},
  info::SourceInfo,
)::Expression
  local outExp::Expression
  outExp = begin
    local cref::ComponentRef
    local slot::Option{Slot}
    @match exp begin
      CREF_EXPRESSION(
        cref = cref && COMPONENT_REF_CREF(
          restCref = COMPONENT_REF_EMPTY(__),
        ),
      ) => begin
        slot = lookupSlotInArray(firstName(cref), slots)
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
  slots::Vector{<:Slot},
  info::SourceInfo,
)::Expression
  local outExp::Expression
  outExp = map(
    exp,
    (x) -> evaluateSlotExp_traverser(x, slots, info)
  )
  return outExp
end

function fillDefaultSlot2(slot::Slot, slots::Vector{<:Slot}, info::SourceInfo)::TypedArg
  local outArg::TypedArg

  @assign outArg = begin
    local exp::Expression
    #=  An already evaluated slot, return its binding.
    =#
    @match slot.evalStatus begin
      SlotEvalStatus.EVALUATED => begin
        Util.getOption(slot.arg)
      end

      SlotEvalStatus.EVALUATING => begin
        #=  A slot in the process of being evaluated => cyclic bindings.
        =#
        Error.addSourceMessage(Error.CYCLIC_DEFAULT_VALUE, list(slot.name), info)
        fail()
      end

      SlotEvalStatus.NOT_EVALUATED => begin
        #=  A slot with a not evaluated binding, evaluate the binding and return it.
        =#
        @assign slot.evalStatus = SlotEvalStatus.EVALUATING
        arrayUpdate(slots, slot.index, slot)
        @assign exp = evaluateSlotExp(Util.getOption(slot.default), slots, info)
        @assign outArg = (
          exp,
          typeOf(exp),
          variability(exp),
        )
        @assign slot.arg = SOME(outArg)
        @assign slot.evalStatus = SlotEvalStatus.EVALUATED
        arrayUpdate(slots, slot.index, slot)
        outArg
      end
    end
  end
  return outArg
end

function fillDefaultSlot(slot::Slot, slots::Vector{<:Slot}, info::SourceInfo)::TypedArg
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
function collectArgs(slots::Vector{<:Slot}, info::SourceInfo)::Tuple{Vector{TypedArg}, Bool}
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
      #= Otherwise, try to fill the slot with its default argument. =#
      _ => begin
        push!(args, fillDefaultSlot(s, slots, info))
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
  slots::Vector{<:Slot},
  fn::M_FUNCTION,
  info::SourceInfo,
)::Tuple{Array{Slot}, Bool} #= For error reporting =#
  local matching::Bool = true

  local s::Slot
  local argName::String
  local ty::M_Type
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
  fn::M_FUNCTION,
  info::SourceInfo,
)::Tuple{Vector{TypedArg}, Bool}
  local matching::Bool
  local args::Vector{TypedArg} = posArgs
  local slot::Slot
  local slots::List{Slot}
  local remaining_slots::List{Slot}
  local filled_named_args::Vector{TypedArg}
  local slots_arr::Vector{Slot}
  local pos_arg_count::Int
  local slot_count::Int
  local index::Int = 1

  slots = fn.slots
  pos_arg_count = length(posArgs)
  slot_count = listLength(slots)
  if pos_arg_count > slot_count
    matching = false
    return (args, matching)
  elseif pos_arg_count == slot_count && isempty(namedArgs)
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

function getSlots(fn::M_FUNCTION)::List{Slot}
  local slots::List{Slot} = fn.slots
  return slots
end

function setReturnType(ty::M_Type, fn::M_FUNCTION)::M_FUNCTION

  @assign fn.returnType = ty
  return fn
end

function returnType(fn::M_FUNCTION)::M_Type
  local ty::M_Type = fn.returnType
  return ty
end

function instance(fn::M_FUNCTION)::InstNode
  local node::InstNode = fn.node
  return node
end

function toFlatString(fn::M_FUNCTION)::String
  local str::String
  local s
  s = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  s = toFlatStream(fn, s)
  str = IOStream_M.string(s)
  IOStream_M.delete(s)
  return str
end

function toFlatStream(fn::M_FUNCTION, s; overrideName::String)
  local fn_body::Vector{Statement}
  if isDefaultRecordConstructor(fn)
    s = IOStream_M.append(s, toFlatString(fn.node))
  else
    s = toFlatStreamHelper(fn::M_FUNCTION, s, overrideName)
  end
  return s
end

"""
Returns a function as  a flat string.
"""
function toFlatStream(fn::M_FUNCTION, s::IOStream_M.IOSTREAM)
  local fn_name::String
  if isDefaultRecordConstructor(fn)
    s = IOStream_M.append(s, toFlatString(fn.node))
  else
    fn_name = AbsynUtil.pathString(fn.path)
    s = toFlatStreamHelper(fn::M_FUNCTION, s, string("'", fn_name, "'"))
  end
  return s
end

function toFlatStreamHelper(fn::M_FUNCTION, s, fn_name)
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
function typeString(fn::M_FUNCTION)::String
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

"""Constructs a string representing a call, for use in error messages."""
function callString(
  fn::M_FUNCTION,
  posArgs::List{<:Expression},
  namedArgs::List{<:NamedArg},
)::String
  local str::String

  @assign str =
    stringDelimitList(list(toString(arg) for arg in posArgs), ", ")
  if !listEmpty(namedArgs)
    @assign str =
      str +
      ", " +
      stringDelimitList(
        list(
          Util.tuple21(arg) + " = " + toString(Util.tuple22(arg))
          for arg in namedArgs
        ),
        ", ",
      )
  end
  @assign str = AbsynUtil.pathString(fn.path) + "(" + str + ")"
  return str
end

function candidateFuncListString(fns::List{<:M_Function})::String
  local s::String =
    stringDelimitList(list(signatureString(fn, true) for fn in fns), "\\n  ")
  return s
end

function candidateFuncListString(fns::Vector{M_Function})
  local s::String = stringDelimitList(list(signatureString(fn, true) for fn in fns), "\\n  ")
  return s
end

"""Constructs a signature string for a function, e.g. Real func(Real x, Real y)"""
function signatureString(fn::M_FUNCTION, printTypes::Bool = true)::String
  local str::String

  local fn_name::Absyn.Path
  local input_str::String
  local output_str::String
  local var_s::String
  local inputs_strl::List{String} = nil
  local inputs::List{InstNode} = fn.inputs
  local c::Component
  local def_exp::Expression
  local ty::M_Type

  for s in fn.slots
    @assign input_str = ""
    @assign c = component(listHead(inputs))
    @assign inputs = listRest(inputs)
    if isSome(s.default)
      @match SOME(def_exp) = s.default
      @assign input_str = " = " + toString(def_exp)
    end
    @assign input_str = s.name + input_str
    @assign input_str = begin
      @match s.ty begin
        SlotType.POSITIONAL => begin
          "" + input_str
        end

        _ => begin
          input_str
        end
      end
    end
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

"""Handles the DAE.mo structure where builtin calls are replaced by their simpler name"""
function nameConsiderBuiltin(fn::M_FUNCTION)::Absyn.Path
  local path::Absyn.Path

  @assign path = begin
    local name::String
    @match fn.attributes.isBuiltin begin
      DAE.FUNCTION_BUILTIN(name = SOME(name)) => begin
        Absyn.IDENT(name)
      end

      DAE.FUNCTION_BUILTIN(__) => begin
        AbsynUtil.pathLast(fn.path)
      end

      _ => begin
        fn.path
      end
    end
  end
  return path
end

function setName(name::Absyn.Path, fn::M_FUNCTION)::M_FUNCTION
  @assign fn.path = name
  return fn
end

function name(fn::M_FUNCTION)::Absyn.Path
  local path::Absyn.Path = fn.path
  return path
end

"""Marks this function as collected for addition to the function tree."""
function collect(fn::M_FUNCTION)
  #=  The pointer might be immutable, check before assigning to it.
  =#
  return if P_Pointer.access(fn.status) != FunctionStatus.BUILTIN
    P_Pointer.update(fn.status, FunctionStatus.COLLECTED)
  end
end

"""
  Returns true if this function has already been added to the function tree
  (or shouldn't be added, e.g. if it's builtin), otherwise false.
"""
function isCollected(fn::M_FUNCTION)::Bool
  local collected::Bool
  @assign collected = begin
    @match P_Pointer.access(fn.status) begin
      FunctionStatus.BUILTIN => begin
        true
      end
      FunctionStatus.COLLECTED => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return collected
end

function markSimplified(fn::M_FUNCTION)
  return if P_Pointer.access(fn.status) != FunctionStatus.BUILTIN
    P_Pointer.update(fn.status, FunctionStatus.SIMPLIFIED)
  end
end

function isSimplified(fn::M_FUNCTION)::Bool
  local simplified::Bool

  @assign simplified = begin
    @match P_Pointer.access(fn.status) begin
      FunctionStatus.BUILTIN => begin
        true
      end

      FunctionStatus.SIMPLIFIED => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return simplified
end

function markEvaluated(fn::M_FUNCTION)
  return if P_Pointer.access(fn.status) != FunctionStatus.BUILTIN
    P_Pointer.update(fn.status, FunctionStatus.EVALUATED)
  end
end

function isEvaluated(fn::M_FUNCTION)::Bool
  local evaluated::Bool
  local status = P_Pointer.access(fn.status)
  evaluated = begin
    @match status begin
      FunctionStatus.BUILTIN => begin
        true
      end
      FunctionStatus.EVALUATED => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return evaluated
end

function mapCachedFuncs(inNode::InstNode, mapFn::MapFn)
  local cls_node::InstNode
  local cache::CachedData
  cls_node = classScope(inNode)
  cache = getFuncCache(cls_node)
  cache = begin
    @match cache begin
      C_FUNCTION(__) => begin
        cacheFuncs = M_FUNCTION[mapFn(fn) for fn in cache.funcs]
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
  local outFuncs::Vector{M_FUNCTION}
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
  fnNode = instantiateN1(fnNode, EMPTY_NODE())
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
    local fn::M_FUNCTION
    local cr::Absyn.ComponentRef
    local sub_fnNode::InstNode
    local funcs::List{M_Function}
    local fn_ders::List{FunctionDerivative}
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
        fn = M_FUNCTION(
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
          fn.callCounter)
        fnNode = cacheAddFunc(fnNode, fn, specialBuiltin)
        (fnNode, specialBuiltin)
      end
    end
  end
  return (fnNode, specialBuiltin)
end

"""Instantiates the given InstNode as a function."""
function instFunctionNode(node::InstNode)::InstNode
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
  local fn_node::InstNode
  local cache::CachedData
  local parent::InstNode
  fn_node = classScope(node(fn_ref))
  cache = getFuncCache(fn_node)
  #=  Check if a cached instantiation of this function already exists. =#
  (fn_node, specialBuiltin) = begin
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
  return (fn_ref, fn_node, specialBuiltin)
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
  @match (functionRef, found_scope) = lookupFunctionName(functionName, scope, info)
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

function new(path::Absyn.Path, node::InstNode)::M_FUNCTION
  local fn::M_FUNCTION
  local cls::Class
  local inputs::List{InstNode}
  local outputs::List{InstNode}
  local locals::List{InstNode}
  local slots::List{Slot}
  local attr::DAE.FunctionAttributes
  local status::FunctionStatusType

  (inputs, outputs, locals) = collectParams(node)
  @assign attr = makeAttributes(node, inputs, outputs)
  #=  Make sure builtin functions aren't added to the function tree.
  =#
  @assign status = if isBuiltinAttr(attr)
    FunctionStatus.COLLECTED
  else
    FunctionStatus.INITIAL
  end
  @assign fn = M_FUNCTION(
    path,
    node,
    inputs,
    outputs,
    locals,
    nil,
    TYPE_UNKNOWN(),
    attr,
    nil,
    P_Pointer.create(status),
    P_Pointer.create(0),
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

function isValidParamType(ty::NFType)::Bool
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
  local ty::M_Type
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
function checkParamTypes(fn::M_FUNCTION)
  checkParamTypes2(fn.inputs)
  checkParamTypes2(fn.outputs)
  return checkParamTypes2(fn.locals)
end

function makeAttributes(
  @nospecialize(node::InstNode),
  @nospecialize(inputs::List{<:InstNode}),
  @nospecialize (outputs::List{<:InstNode})
)::DAE.FunctionAttributes
  local attr::DAE.FunctionAttributes

  local def::SCode.Element
  local params::Vector{InstNode}
  local res::SCode.Restriction
  local fres::SCode.FunctionRestriction
  local is_partial::Bool
  local cmts::List{SCode.Comment}
  local cmt::SCode.Comment

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
    local inline_ty::DAE.InlineType
    local builtin::DAE.FunctionBuiltin
    #=  External function. =#
    @matchcontinue fres begin
      SCode.FR_EXTERNAL_FUNCTION(is_impure) => begin
        @assign in_params = list(name(i) for i in inputs)
        @assign out_params = list(name(o) for o in outputs)
        @assign nameVar = SCodeUtil.isBuiltinFunction(def, in_params, out_params)
        @assign inline_ty = commentIsInlineFunc(cmt)
        @assign is_impure = is_impure || hasImpure(cmt)
        @assign has_unbox_args = hasUnboxArgsAnnotation(cmt)
        DAE.FUNCTION_ATTRIBUTES(
          inline_ty,
          hasOMPure(cmt),
          is_impure,
          is_partial,
          DAE.FUNCTION_BUILTIN(SOME(nameVar), has_unbox_args),
          DAE.FP_NON_PARALLEL(),
        )
      end

      SCode.FR_PARALLEL_FUNCTION(__) => begin
        #=  Parallel function: there are some builtin functions.
        =#
        @assign in_params = list(name(i) for i in inputs)
        @assign out_params = list(name(o) for o in outputs)
        @assign nameVar = SCodeUtil.isBuiltinFunction(def, in_params, out_params)
        @assign inline_ty = commentIsInlineFunc(cmt)
        @assign has_unbox_args = hasUnboxArgsAnnotation(cmt)
        DAE.FUNCTION_ATTRIBUTES(
          inline_ty,
          hasOMPure(cmt),
          false,
          is_partial,
          DAE.FUNCTION_BUILTIN(SOME(nameVar), has_unbox_args),
          DAE.FP_PARALLEL_FUNCTION(),
        )
      end

      SCode.FR_PARALLEL_FUNCTION(__) => begin
        #=  Parallel function: non-builtin.
        =#
        @assign inline_ty = commentIsInlineFunc(cmt)
        DAE.FUNCTION_ATTRIBUTES(
          inline_ty,
          hasOMPure(cmt),
          false,
          is_partial,
          getBuiltin(def),
          DAE.FP_PARALLEL_FUNCTION(),
        )
      end

      SCode.FR_KERNEL_FUNCTION(__) => begin
        DAE.FUNCTION_ATTRIBUTES(
          DAE.NO_INLINE(),
          true,
          false,
          is_partial,
          DAE.FUNCTION_NOT_BUILTIN(),
          DAE.FP_KERNEL_FUNCTION(),
        )
      end

      _ => begin
        #=  Kernel functions: never builtin and never inlined.
        =#
        #=  Normal function.
        =#
        #        @assign inline_ty = commentIsInlineFunc(cmt) TODO
        inline_ty = DAE.NO_INLINE() #TODO tmp
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
        DAE.FUNCTION_ATTRIBUTES(
          inline_ty,
          hasOMPure(cmt),
          is_impure,
          is_partial,
          getBuiltin(def),
          DAE.FP_NON_PARALLEL(),
        )
      end
    end
  end
  return attr
end

function commentIsInlineFunc(cmt::SCode.Comment)
  return DAE.NO_INLINE()
end

"""Merges the function's comments from inherited classes."""
function mergeFunctionAnnotations(comments::List{<:SCode.Comment})::SCode.Comment
  local outComment::SCode.Comment

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


function getBuiltin(def::SCode.Element)::DAE.FunctionBuiltin
  local builtin::DAE.FunctionBuiltin = if SCodeUtil.isBuiltinElement(def)
    DAE.FUNCTION_BUILTIN_PTR()
  else
    DAE.FUNCTION_NOT_BUILTIN()
  end
  return builtin
end

function hasImpure(cmt::SCode.Comment)::Bool
  local res::Bool =
    SCodeUtil.commentHasBooleanNamedAnnotation(cmt, "__ModelicaAssociation_Impure")
  return res
end

function hasOMPure(cmt::SCode.Comment)::Bool
  local res::Bool =
    !SCodeUtil.commentHasBooleanNamedAnnotation(cmt, "__OpenModelica_Impure")
  return res
end

function makeSlot(@nospecialize(componentArg::InstNode), index::Int)::SLOT
  local slot::Slot
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
      SlotType.GENERIC,
      default,
      NONE(),
      index,
      SlotEvalStatus.NOT_EVALUATED,
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

function makeSlots(@nospecialize(inputs::List{<:InstNode}))::List{Slot}
  local slots::List{Slot} = nil
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
      list(ConnectortoString(cty), name(componentArg)),
      info(componentArg),
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
        @assign params = ListUtil.deleteMemberOnTrue(
          exp.cref,
          params,
          containsNode,
        )
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
    @assign params = fold(exp, analyseUnusedParametersExp2, params)
  end
  return params
end

function analyseUnusedParameters(fn::M_FUNCTION)::List{Int}
  local unusedInputs::List{Int} = nil

  local inputs::List{InstNode}
  local index::Int

  @assign inputs = foldExp(fn, analyseUnusedParametersExp, fn.inputs)
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
  local fn_body::Algorithm
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

function makeReturnType(fn::M_FUNCTION)::M_Type
  local returnType::M_Type
  local ret_tyl::List{M_Type}
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

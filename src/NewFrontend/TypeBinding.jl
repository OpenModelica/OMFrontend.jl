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

"""This file contains all the code related to type binding"""
function typeBindings(cls::InstNode,
                      component::InstNode,
                      origin::ORIGIN_Type)
  typeBindings2(cls, component, origin)
end

function typeBindings2(cls::InstNode,
                       component::InstNode,
                       origin::ORIGIN_Type)
  local c::Class
  local cls_tree::ClassTree
  local node::InstNode
  c = getClass(cls)
  @match c begin
    INSTANCED_CLASS(elements = cls_tree && CLASS_TREE_FLAT_TREE(__)) => begin
      local components = cls_tree.components::Vector{InstNode}
      local len = length(components)
      for i in 1:len
        local c = @inbounds components[i]
        local node = typeComponentBinding(c, origin, true)
        if node !== c
          @inbounds components[i] = node
        end
      end
      return nothing
    end

    INSTANCED_BUILTIN(elements = cls_tree && CLASS_TREE_FLAT_TREE(__)) => begin
      local components = cls_tree.components::Vector{InstNode}
      local len = length(components)
      for i in 1:len
        local c = @inbounds components[i]
        local node = typeComponentBinding(c, origin)
        if node !== c
          @inbounds components[i] = node
        end
      end
      return nothing
    end

    INSTANCED_BUILTIN(__) => begin
      return nothing
    end

    TYPED_DERIVED(__) => begin
      typeBindings(c.baseClass, component, origin)
      return nothing
    end
    _ => begin
      Error.assertion(
        false,
        getInstanceName() + " got uninstantiated class " + name(cls),
        sourceInfo(),
      )
      fail()
    end
  end
end

"""
Same as type bindings but use ref to handle multiple returns instead of tuples.
"""
function typeBindingsRefs(cls::InstNode,
                       component::InstNode,
                          origin::ORIGIN_Type,
                          tyRef::Ref{NFType},
                          varRef::Ref{VariabilityType})::Nothing
  local c::Class
  local cls_tree::ClassTree
  local node::InstNode
  c = getClass(cls)
  @match c begin
    INSTANCED_CLASS(elements = cls_tree && CLASS_TREE_FLAT_TREE(__)) => begin
      local components = cls_tree.components::Vector{InstNode}
      local len = length(components)
      #= Fan-out mirrors typeComponents: requires no held claims, and each
         worker gets its own scratch type/variability refs. =#
      if parallelInstEnabled(len)
        local parentTok = get(task_local_storage(), :OMF_ROOT, 0)::Int
        @sync for i in 1:len
          local idx = i
          local tok = parentTok == 0 ? idx : parentTok
          Threads.@spawn begin
            task_local_storage(:OMF_ROOT, tok)
            local compNode = @inbounds components[idx]
            local wTyRef = Ref{NFType}(TYPE_UNKNOWN())
            local wVarRef = Ref{VariabilityType}(Variability.CONSTANT)
            local node = typeComponentBindingRef(compNode, origin, true, wTyRef, wVarRef)
            if node !== compNode
              _withClaim(_refId(cls)) do
                @inbounds components[idx] = node
              end
            end
          end
        end
      else
        for i in 1:len
          local c = @inbounds components[i]
          local node = typeComponentBindingRef(c, origin, true, tyRef, varRef)
          if node !== c
            if _parallelTypingActive()
              _withClaim(_refId(cls)) do
                @inbounds components[i] = node
              end
            else
              @inbounds components[i] = node
            end
          end
        end
      end
      return nothing
    end

    INSTANCED_BUILTIN(elements = cls_tree && CLASS_TREE_FLAT_TREE(__)) => begin
      local components = cls_tree.components::Vector{InstNode}
      local len = length(components)
      for i in 1:len
        local c = @inbounds components[i]
        local node = typeComponentBindingRef(c, origin, tyRef, varRef)
        if node !== c
          @inbounds components[i] = node
        end
      end
      return nothing
    end

    INSTANCED_BUILTIN(__) => begin
      return nothing
    end

    TYPED_DERIVED(__) => begin
      typeBindingsRefs(c.baseClass, component, origin, tyRef, varRef)
      return nothing
    end
    _ => begin
      Error.assertion(
        false,
        getInstanceName() + " got uninstantiated class " + name(cls),
        sourceInfo(),
      )
      fail()
    end
  end
end

function typeComponentBindingRef(inComponent::InstNode,
                                 origin::ORIGIN_Type,
                                 typeChildren::Bool,
                                 tyRef::Ref{NFType},
                                 varRef::Ref{VariabilityType})
  local n = resolveOuter(inComponent)
  local is_self = referenceEq(n, inComponent)
  local c = component(n)
  n = typeComponentBindingRef2(inComponent, n, c, origin, typeChildren, tyRef, varRef)
  return is_self ? n : inComponent
end

function typeComponentBindingRef(inComponent::InstNode,
                                 origin::ORIGIN_Type,
                                 tyRef::Ref{NFType},
                                 varRef::Ref{VariabilityType})
  local n = resolveOuter(inComponent)
  local is_self = referenceEq(n, inComponent)
  local c = component(n)
  n = typeComponentBindingRef2(inComponent, n, c, origin, false, tyRef, varRef)
  return is_self ? n : inComponent
end

function typeComponentBindingRef2_typed(
  inComponent::InstNode,
  node::InstNode,
  c::Component,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  tyRef::Ref{NFType},
  varRef::Ref{VariabilityType}
  )::InstNode
  if isvariant(c.binding, UNTYPED_BINDING)
    #= The payload runs under the node's claim; children are typed after the
       claim is released so subtree fan-out never holds a lock across @sync. =#
    if _parallelTypingActive()
      node = _withClaim(_refId(node)) do
        local c2 = component(node)
        if isvariant(c2.binding, UNTYPED_BINDING)
          typeBindingPayload!(inComponent, node, c2, origin, tyRef, varRef)
        else
          node
        end
      end
    else
      node = typeBindingPayload!(inComponent, node, c, origin, tyRef, varRef)
    end
    if typeChildren
      typeBindingsRefs(c.classInst, inComponent, origin, tyRef, varRef)
    end
    return node
  end
  #=  Second case: A component without a binding, or with a binding that's already been typed. =#
  checkBindingEach(c.binding)
  local changed::Bool = false
  if isTyped(c.binding)
    cBinding = matchBinding(c.binding, c.ty, name(inComponent), node)
    @assign c.binding = cBinding
    changed = true
  end

  if isBound(c.condition)
    local cCond = typeComponentCondition(c.condition, origin)
    @assign c.condition = cCond
    changed = true
  end
  if changed
    if _parallelTypingActive()
      local c3 = c
      _withClaim(() -> updateComponent!(c3, node), _refId(node))
    else
      updateComponent!(c, node)
    end
  end
  if typeChildren
    typeBindingsRefs(c.classInst, inComponent, origin, tyRef, varRef)
  end
  return node
end

"""
  Types the component's own binding and condition and installs the typed
  component. Does not type the children.
"""
function typeBindingPayload!(
  inComponent::InstNode,
  node::InstNode,
  c::Component,
  origin::ORIGIN_Type,
  tyRef::Ref{NFType},
  varRef::Ref{VariabilityType}
  )::InstNode
  local nameStr::String = inComponent.name
  local binding::Binding = c.binding
  local comp_var::VariabilityType

  #= Type the condition first so we can skip matchBinding for disabled components. =#
  cCond = if isBound(c.condition)
    typeComponentCondition(c.condition, origin)
  else
    c.condition
  end
  @assign c.condition = cCond

  #= Check if the condition evaluates to false (component is disabled). =#
  local componentDisabled = false
  if isBound(cCond)
    try
      local condExp = getTypedExp(cCond)
      condExp = evalExp(condExp, EVALTARGET_CONDITION(Binding_getInfo(cCond)))
      condExp = stripBindingInfo(condExp)
      if condExp isa BOOLEAN_EXPRESSION && !condExp.value
        componentDisabled = true
      end
    catch
    end
  end

  checkBindingEach(c.binding)
  local originFlag = setFlag(origin, ORIGIN_BINDING)
  local typedBinding::Binding = typeBinding(binding, originFlag, tyRef, varRef)
  handleBindingError(binding)
  if !componentDisabled
    typedBinding = matchBinding(typedBinding, c.ty, nameStr, node)
    handleBindingError(typedBinding)
  end
  comp_var = checkComponentBindingVariability(nameStr, c, typedBinding, origin)
  if comp_var == 404
    handleBindingError(binding)
  end
  attrs = c.attributes
  if comp_var != attrs.variability
    @assign attrs.variability = comp_var
    @assign c.attributes = attrs
  end
  @assign c.binding = typedBinding
  return updateComponent!(c, node)
end


function typeComponentBindingRef2_typeAttr(
  inComponent::InstNode,
  node::InstNode,
  c::Component,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  tyRef::Ref{NFType},
  varRef::Ref{VariabilityType})
  if isvariant(c.modifier, MODIFIER_NOMOD)
    return node
  end
  local mod = typeTypeAttribute(c.modifier, c.ty, parent(inComponent), origin)
  @assign c.modifier = mod
  return updateComponent!(c, node)
end

function handleBindingError(binding)
  if isvariant(binding, BINDING_ERROR)
    if isBound(c.condition)
      binding = INVALID_BINDING(binding, ErrorExt.getCheckpointMessages())
    else
      fail()
    end
  end
end



@noinline function typeComponentBinding(inComponent::InstNode, origin::ORIGIN_Type)
  return typeComponentBinding(inComponent, origin, true)
end

@noinline  function typeComponentBinding(inComponent::InstNode,
                                         origin::ORIGIN_Type,
                                         typeChildren::Bool)
  local n = resolveOuter(inComponent)
  local is_self = referenceEq(n, inComponent)
  if _parallelTypingActive()
    #= component(n) is read under the claim so a concurrent typing of the
       same node is fully ordered with this one. =#
    local n0 = n
    n = _withClaim(
      () -> typeComponentBinding2(inComponent, n0, component(n0), origin, typeChildren),
      _refId(n0))
  else
    n = typeComponentBinding2(inComponent, n, component(n), origin, typeChildren)
  end
  return is_self ? n : inComponent
end

function typeComponentBinding2_typeAttr(
  inComponent::InstNode,
  node::InstNode,
  c::Component,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  )
  if isvariant(c.modifier, MODIFIER_NOMOD)
    return node
  else
    local mod = typeTypeAttribute(c.modifier, c.ty, parent(inComponent), origin)
    @assign c.modifier = mod #TYPE_ATTRIBUTE(c.ty, mod)
    return updateComponent!(c, node)
  end
end

function typeComponentBinding2_untyped(
  inComponent::InstNode,
  node::InstNode,
  c::Component,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  )
  if ! isvariant(c.binding, UNTYPED_BINDING)
    return node
  end
  #=  An untyped component with a binding. This might happen when typing a
  =#
  #=  dimension and having to evaluate the binding of a not yet typed
  =#
  #=  component. Type only the binding and let the case above handle the rest.
  =#
  local nameStr = name(inComponent)::String
  #@debug "Typing UC/UB binding ... for component: $nameStr"
  checkBindingEach(c.binding)
  local binding = typeBinding(c.binding, setFlag(origin, ORIGIN_BINDING))
  local comp_var = checkComponentBindingVariability(nameStr, c, binding, origin)
  local attrs = c.attributes
  if comp_var != attrs.variability
    @assign attrs.variability = comp_var
    @assign c.attributes = attrs
  end
  @assign c.binding = binding
  return updateComponent!(c, node)
end

#= Tag-branching dispatchers (variants collapsed into one ComponentImpl struct). =#
function typeComponentBinding2(inComponent::InstNode, node::InstNode, c::Component,
                               origin::ORIGIN_Type, typeChildren::Bool)
  if isvariant(c, TYPE_ATTRIBUTE)
    return typeComponentBinding2_typeAttr(inComponent, node, c, origin, typeChildren)
  elseif isvariant(c, UNTYPED_COMPONENT)
    return typeComponentBinding2_untyped(inComponent, node, c, origin, typeChildren)
  elseif isvariant(c, TYPED_COMPONENT)
    return typeComponentBinding2_typed(inComponent, node, c, origin, typeChildren)
  end
  return node
end

function typeComponentBindingRef2(inComponent::InstNode, node::InstNode, c::Component,
                                  origin::ORIGIN_Type, typeChildren::Bool,
                                  tyRef::Ref{NFType}, varRef::Ref{VariabilityType})
  if isvariant(c, TYPED_COMPONENT)
    return typeComponentBindingRef2_typed(inComponent, node, c, origin, typeChildren, tyRef, varRef)
  elseif isvariant(c, TYPE_ATTRIBUTE)
    return typeComponentBindingRef2_typeAttr(inComponent, node, c, origin, typeChildren, tyRef, varRef)
  end
  return node
end

function typeComponentBinding2_typed(
  inComponent::InstNode,
  node::InstNode,
  c::Component,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  )::InstNode
  local binding::Binding
  local nameStr::String
  local comp_var::VariabilityType
  if isvariant(c.binding, UNTYPED_BINDING)
    nameStr = inComponent.name
    binding = c.binding
    #ErrorExt.setCheckpoint(getInstanceName())
    checkBindingEach(c.binding)
    local originFlag = setFlag(origin, ORIGIN_BINDING)
    local typedBinding::Binding = typeBinding(binding, originFlag)
    handleBindingError(binding)
    #if !(Config.getGraphicsExpMode() && stringEq(nameStr, "graphics")) TODO
    typedBinding = matchBinding(typedBinding, c.ty, nameStr, node)
    handleBindingError(typedBinding)
    #end
    comp_var = checkComponentBindingVariability(nameStr, c, typedBinding, origin)
    if comp_var == 404
      handleBindingError(binding)
    end
    attrs = c.attributes
    if comp_var != attrs.variability
      attrs.variability = comp_var
      @assign c.attributes = attrs
    end
    #str2 = toString(binding)
    #@debug "Typed binding 2: $str2"
    #        ErrorExt.delCheckpoint(getInstanceName()) TODO

    cCond = if isBound(c.condition)
      typeComponentCondition(c.condition, origin)
    else
      c.condition
    end
    @assign begin
      c.condition =  cCond
      c.binding = typedBinding
    end
    node = updateComponent!(c, node)
    if typeChildren
      typeBindings(c.classInst, inComponent, origin)
    end
    return node
  end
  #=  Second case: A component without a binding, or with a binding that's already been typed. =#
  checkBindingEach(c.binding)
  if isTyped(c.binding) #TODO. The two assigns here can be unified.
    cBinding = matchBinding(c.binding, c.ty, name(inComponent), node)
    @assign c.binding = cBinding
  end

  if isBound(c.condition)
    local cCond = typeComponentCondition(c.condition, origin)
    @assign c.condition = cCond
  end
  #= c is immutable now: install the (possibly) rebuilt component once. =#
  node = updateComponent!(c, node)
  if typeChildren
    typeBindings(c.classInst, inComponent, origin)
  end
  return node
end

function typeBinding(inBinding::Binding, origin::Int,
                     tyRef::Ref{NFType} = Ref{NFType}(TYPE_UNKNOWN()),
                     varRef::Ref{VariabilityType} = Ref{VariabilityType}(Variability.CONSTANT))::Binding
  local exp::Expression
  local ty::NFType
  local var::VariabilityType
  local info::SourceInfo
  local each_ty::Int
  local binding::Binding
  @match inBinding begin
    UNBOUND(__) => begin
      binding = inBinding
    end

    TYPED_BINDING(__) => begin
      binding = inBinding
    end

    UNTYPED_BINDING(bindingExp = exp) => begin
      info = Binding_getInfo(inBinding)
      exp = typeExp2(exp, origin, info, tyRef, varRef)
      ty = tyRef.x
      var = varRef.x
      if inBinding.isEach
        each_ty = EachType.EACH::Int
      elseif isClassBinding(inBinding)
        each_ty = EachType.REPEAT::Int
      else
        each_ty = EachType.NOT_EACH::Int
      end
      binding = TYPED_BINDING(exp, ty, var, each_ty, false, false, inBinding.info)
    end

    _ => begin
      binding = BINDING_ERROR()
    end
  end
  return binding
end


function typeBindingExp(
  exp::BINDING_EXP,
  origin::ORIGIN_Type,
  info::SourceInfo,
  )::Tuple{BINDING_EXP, NFType, Int}
  local variability::VariabilityType
  local ty::NFType
  local outExp::BINDING_EXP
  local e::Expression
  local parents::List{InstNode}
  local is_each::Bool
  local exp_ty::NFType
  @match BINDING_EXP(e, _, _, parents, is_each) = exp
  (e, exp_ty, variability) = typeExp(e, origin, info)
  local parent_dims::Int = 0
  if !is_each
    for p in listRest(parents)
      parent_dims = parent_dims + dimensionCount(getType(p))::Int
    end
  end
  if parent_dims == 0
    ty = exp_ty
  else
    if dimensionCount(exp_ty) >= parent_dims
      ty = unliftArrayN(parent_dims, exp_ty)
    end
  end
  #=
  If the binding has too few dimensions we can't unlift it, but matchBinding
  can report the error better so we silently ignore it here.
  =#
  outExp = BINDING_EXP(e, exp_ty, ty, parents, is_each)
  #outExp =  updateBindingExp!(exp, e, exp_ty, ty, parents, is_each)
  return (outExp, ty, variability)
end

function typeBindingExpRef(
  exp::BINDING_EXP,
  origin::ORIGIN_Type,
  info::SourceInfo,
  tyRef::Ref{NFType},
  variabilityRef::Ref{VariabilityType}
  )::BINDING_EXP
  local variability::VariabilityType
  local ty::NFType
  local outExp::BINDING_EXP
  local e::Expression
  local parents::List{InstNode}
  local is_each::Bool
  local exp_ty::NFType
  @match BINDING_EXP(e, _, _, parents, is_each) = exp
  e = typeExp2(e, origin, info, tyRef, variabilityRef)
  exp_ty = tyRef.x
  variability = variabilityRef.x
  local parent_dims::Int = 0
  if !is_each
    local pLst = listRest(parents)
    while pLst !== nil
      @match Cons{InstNode}(p, pLst) = pLst
      parent_dims = parent_dims + dimensionCount(getType(p))::Int
    end
  end
  if parent_dims == 0
    ty = exp_ty
  else
    if dimensionCount(exp_ty) >= parent_dims
      ty = unliftArrayN(parent_dims, exp_ty)
    end
  end
  #=
  If the binding has too few dimensions we can't unlift it, but matchBinding
  can report the error better so we silently ignore it here.
  =#
  #outExp = BINDING_EXP(e, exp_ty, ty, parents, is_each)
  outExp =  updateBindingExp!(exp, e, exp_ty, ty, parents, is_each)
  variabilityRef.x = variability
  tyRef.x = ty
  return outExp
end


"""
Updates and mutates a given binding exp.
NOTE: Creates a new BIINDING_EXP
"""
function updateBindingExp!(bindingExp::BINDING_EXP, exp, expType, bindingType, parents, isEach)::BINDING_EXP
  return BINDING_EXP(exp, expType, bindingType, parents, isEach)
end

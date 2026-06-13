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
        typeComponentBinding(c, origin, true)
      end
      return nothing
    end

    INSTANCED_BUILTIN(elements = cls_tree && CLASS_TREE_FLAT_TREE(__)) => begin
      local components = cls_tree.components::Vector{InstNode}
      local len = length(components)
      for i in 1:len
        typeComponentBinding(components[i], origin)
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
      for i in 1:len
        local c = @inbounds components[i]
        typeComponentBindingRef(c, origin, true, tyRef, varRef)
      end
      return nothing
    end

    INSTANCED_BUILTIN(elements = cls_tree && CLASS_TREE_FLAT_TREE(__)) => begin
      local components = cls_tree.components::Vector{InstNode}
      local len = length(components)
      for i in 1:len
        typeComponentBindingRef(components[i], origin, tyRef, varRef)
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
  local c = component(n)
  typeComponentBindingRef2(inComponent, n, c, origin, typeChildren, tyRef, varRef)
  return nothing
end

function typeComponentBindingRef(inComponent::InstNode,
                                 origin::ORIGIN_Type,
                                 tyRef::Ref{NFType},
                                 varRef::Ref{VariabilityType})
  local n = resolveOuter(inComponent)
  local c = component(n)
  typeComponentBindingRef2(inComponent, n, c, origin, false, tyRef, varRef)
  return nothing
end

function typeComponentBindingRef2(
  inComponent::Union{INNER_OUTER_NODE,COMPONENT_NODE{String, Int8}},
  node::COMPONENT_NODE{String, Int8},
  c::TYPED_COMPONENT,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  tyRef::Ref{NFType},
  varRef::Ref{VariabilityType}
  )::Nothing
  local binding::UNTYPED_BINDING
  local nameStr::String
  local comp_var::VariabilityType
  if c.binding isa UNTYPED_BINDING
    nameStr = inComponent.name
    binding = c.binding

    #= Type the condition first so we can skip matchBinding for disabled components. =#
    cCond = if isBound(c.condition)
      typeComponentCondition(c.condition, origin)
    else
      c.condition
    end
    c.condition = cCond

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

    #ErrorExt.setCheckpoint(getInstanceName())
    checkBindingEach(c.binding)
    local originFlag = setFlag(origin, ORIGIN_BINDING)
    local typedBinding::TYPED_BINDING = typeBinding(binding, originFlag, tyRef, varRef)::TYPED_BINDING
    handleBindingError(binding)
    #if !(Config.getGraphicsExpMode() && stringEq(nameStr, "graphics")) TODO
    if !componentDisabled
      typedBinding = matchBinding(typedBinding, c.ty, nameStr, node)::TYPED_BINDING
      handleBindingError(typedBinding)
    end
    #end
    comp_var = checkComponentBindingVariability(nameStr, c, typedBinding, origin)
    if comp_var == 404
      handleBindingError(binding)
    end
    attrs = c.attributes
    if comp_var != attrs.variability
      attrs.variability = comp_var
      c.attributes = attrs
    end
    #str2 = toString(binding)
    #@debug "Typed binding 2: $str2"
    #        ErrorExt.delCheckpoint(getInstanceName()) TODO

    c.binding = typedBinding
    updateComponent!(c, node)
    if typeChildren
      typeBindingsRefs(c.classInst, inComponent, origin, tyRef, varRef)
    end
    return nothing
  end
  #=  Second case: A component without a binding, or with a binding that's already been typed. =#
  checkBindingEach(c.binding)
  if isTyped(c.binding)
    cBinding = matchBinding(c.binding, c.ty, name(inComponent), node)
    c.binding = cBinding
  end

  if isBound(c.condition)
    local cCond = typeComponentCondition(c.condition, origin)
    c.condition = cCond
    updateComponent!(c, node)
  end
  if typeChildren
    typeBindingsRefs(c.classInst, inComponent, origin, tyRef, varRef)
  end
  return nothing
end


function typeComponentBindingRef2(
  inComponent::InstNode,
  node::InstNode,
  c::TYPE_ATTRIBUTE,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  tyRef::Ref{NFType},
  varRef::Ref{VariabilityType})
  if c.modifier isa MODIFIER_NOMOD
    return nothing
  end
  local mod = typeTypeAttribute(c.modifier, c.ty, parent(inComponent), origin)
  c.modifier = mod #TYPE_ATTRIBUTE(c.ty, mod)
  updateComponent!(c, node)
  return nothing
end

function handleBindingError(binding)
  if binding isa BINDING_ERROR
    if isBound(c.condition)
      binding = INVALID_BINDING(binding, ErrorExt.getCheckpointMessages())
    else
      fail()
    end
  end
end



@noinline function typeComponentBinding(inComponent::InstNode, origin::ORIGIN_Type)
  local n = resolveOuter(inComponent)
  local c = component(n)
  typeComponentBinding2(inComponent, n, c, origin, true)
  return nothing
end

@noinline  function typeComponentBinding(inComponent::InstNode,
                                         origin::ORIGIN_Type,
                                         typeChildren::Bool)
  local n = resolveOuter(inComponent)
  local c = component(n)
  typeComponentBinding2(inComponent, n, c, origin, typeChildren)
  return nothing
end

function typeComponentBinding2(
  inComponent::InstNode,
  node::InstNode,
  c::TYPE_ATTRIBUTE,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  )
  if c.modifier isa MODIFIER_NOMOD
    return
  else
    local mod = typeTypeAttribute(c.modifier, c.ty, parent(inComponent), origin)
    c.modifier = mod #TYPE_ATTRIBUTE(c.ty, mod)
    updateComponent!(c, node)
    return
  end
end

function typeComponentBinding2(
  inComponent::InstNode,
  node::InstNode,
  c::UNTYPED_COMPONENT,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  )
  if ! (c.binding isa UNTYPED_BINDING)
    return
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
  if comp_var != attrs.variability
    attrs.variability = comp_var
    c.attributes = attrs
  end
  c.binding = binding
  updateComponent!(c, node)
  return
end

typeComponentBinding2(
  inComponent::InstNode,
  node::InstNode,
  c::ENUM_LITERAL_COMPONENT,
  origin::ORIGIN_Type,
  typeChildren::Bool,
) = nothing

typeComponentBindingRef2(
  inComponent::InstNode,
  node::InstNode,
  c::ENUM_LITERAL_COMPONENT,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  tyRef::Ref{NFType},
  varRef::Ref{VariabilityType}
) = nothing

function typeComponentBinding2(
  inComponent::Union{INNER_OUTER_NODE,COMPONENT_NODE},
  node::COMPONENT_NODE{String, Int8},
  c::TYPED_COMPONENT,
  origin::ORIGIN_Type,
  typeChildren::Bool,
  )::Nothing
  local binding::UNTYPED_BINDING
  local nameStr::String
  local comp_var::VariabilityType
  if c.binding isa UNTYPED_BINDING
    nameStr = inComponent.name
    binding = c.binding
    #ErrorExt.setCheckpoint(getInstanceName())
    checkBindingEach(c.binding)
    local originFlag = setFlag(origin, ORIGIN_BINDING)
    local typedBinding::TYPED_BINDING = typeBinding(binding, originFlag)::TYPED_BINDING
    handleBindingError(binding)
    #if !(Config.getGraphicsExpMode() && stringEq(nameStr, "graphics")) TODO
    typedBinding = matchBinding(typedBinding, c.ty, nameStr, node)::TYPED_BINDING
    handleBindingError(typedBinding)
    #end
    comp_var = checkComponentBindingVariability(nameStr, c, typedBinding, origin)
    if comp_var == 404
      handleBindingError(binding)
    end
    attrs = c.attributes
    if comp_var != attrs.variability
      attrs.variability = comp_var
      c.attributes = attrs
    end
    #str2 = toString(binding)
    #@debug "Typed binding 2: $str2"
    #        ErrorExt.delCheckpoint(getInstanceName()) TODO

    cCond = if isBound(c.condition)
      typeComponentCondition(c.condition, origin)
    else
      c.condition
    end
    c.condition =  cCond
    c.binding = typedBinding
    updateComponent!(c, node)
    if typeChildren
      typeBindings(c.classInst, inComponent, origin)
    end
    return nothing
  end
  #=  Second case: A component without a binding, or with a binding that's already been typed. =#
  checkBindingEach(c.binding)
  if isTyped(c.binding)
    cBinding = matchBinding(c.binding, c.ty, name(inComponent), node)
    c.binding = cBinding
  end

  if isBound(c.condition)
    local cCond = typeComponentCondition(c.condition, origin)
    c.condition = cCond
    updateComponent!(c, node)
  end
  if typeChildren
    typeBindings(c.classInst, inComponent, origin)
  end
  return nothing
end

typeBinding(binding::UNBOUND, origin::Int) = binding
typeBinding(binding::TYPED_BINDING, origin::Int) = binding
typeBinding(binding, origin) = BINDING_ERROR()
function typeBinding(inBinding::UNTYPED_BINDING, origin::Int,
                     tyRef::Ref{NFType} = Ref{NFType}(TYPE_UNKNOWN()),
                     varRef::Ref{VariabilityType} = Ref{VariabilityType}(Variability.CONSTANT))::TYPED_BINDING
  local exp::Expression
  local ty::NFType
  local var::VariabilityType
  local info::SourceInfo
  local each_ty::Int
  local binding::TYPED_BINDING
  @match inBinding begin
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
"""
function updateBindingExp!(bindingExp::BINDING_EXP, exp, expType, bindingType, parents, isEach)::BINDING_EXP
  #= Mutate binding exp=#
  # bindingExp.exp = exp
  # bindingExp.expType = expType
  # bindingExp.bindingType = bindingType
  # bindingExp.parents = parents
  # bindingExp.isEach = isEach
  return BINDING_EXP(exp, expType, bindingType, parents, isEach)#bindingExp
end

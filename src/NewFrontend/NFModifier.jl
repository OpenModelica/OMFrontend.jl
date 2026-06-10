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

include("NFModTable.jl")

abstract type Modifier end

struct MODIFIER_NOMOD <: Modifier end

mutable struct MODIFIER_REDECLARE{  T0 <: SCode.Final,
                            T1 <: SCode.Each,
                            T2 <: InstNode,
                            T3 <: Modifier} <: Modifier
  finalPrefix::T0
  eachPrefix::T1
  element::T2
  mod::T3
end

mutable struct MODIFIER_MODIFIER{ T0 <: String,
                          T1 <: SCode.Final,
                          T2 <: SCode.Each,
                          T4 <: ModTable.Tree,
                          T5 <: SOURCEINFO} <: Modifier
  name::T0
  finalPrefix::T1
  eachPrefix::T2
  binding#::Binding
  subModifiers::T4
  info::T5
end


#= Structure that represents where a modifier comes from. =#
@Uniontype ModifierScope begin
  @Record SCOPE_EXTENDS begin
    path::Absyn.Path
  end
  @Record SCOPE_CLASS begin
    name::String
  end
  @Record SCOPE_COMPONENT begin
    name::String
  end
end

const EMPTY_MOD = MODIFIER_NOMOD()

function toString(scope::ModifierScope)
  local string::String
  @assign string = begin
    @match scope begin
      COMPONENT(__) => begin
        "component " + scope.name
      end

      CLASS(__) => begin
        "class " + scope.name
      end

      EXTENDS(__) => begin
        "extends " + AbsynUtil.pathString(scope.path)
      end
    end
  end
  return string
end

function name(scope::ModifierScope)
  local name::String
  @assign name = begin
    @match scope begin
      COMPONENT(__) => begin
        scope.name
      end
      CLASS(__) => begin
        scope.name
      end
      EXTENDS(__) => begin
        AbsynUtil.pathString(scope.path)
      end
    end
  end
  return name
end

function fromElement(element::SCode.Element)
  local scope::ModifierScope
  @assign scope = begin
    @match element begin
      SCode.COMPONENT(__) => begin
        COMPONENT(element.name)
      end
      SCode.CLASS(__) => begin
        CLASS(element.name)
      end
      SCode.EXTENDS(__) => begin
        EXTENDS(element.baseClassPath)
      end
    end
  end
  return scope
end


function toFlatString(mod::Modifier, printName::Bool = true)
  local string::String
  string = begin
    local submods::List{Modifier}
    local subs_str::String
    local binding_str::String
    local binding_sep::String
    @match mod begin
      MODIFIER_MODIFIER(__) => begin
        submods = ModTable.listValues(mod.subModifiers)
        if !listEmpty(submods)
          subs_str =
            "(" + stringDelimitList(list(toFlatString(s) for s in submods), ", ") + ")"
          binding_sep = " = "
        else
          subs_str = ""
          binding_sep = if printName
            " = "
          else
            "= "
          end
        end
        @assign binding_str = toFlatString(mod.binding, binding_sep)
        if printName
          mod.name + subs_str + binding_str
        else
          subs_str + binding_str
        end
      end

      _ => begin
        ""
      end
    end
  end
  return string
end

function toString(mod::Modifier, printName::Bool = true)
  local string::String
  @assign string = begin
    local submods::List{Modifier}
    local subs_str::String
    local binding_str::String
    local binding_sep::String
    @match mod begin
      MODIFIER_MODIFIER(__) => begin
        @assign submods = ModTable.listValues(mod.subModifiers)
        if !listEmpty(submods)
          @assign subs_str =
            "(" + stringDelimitList(list(toString(s) for s in submods), ", ") + ")"
          @assign binding_sep = " = "
        else
          @assign subs_str = ""
          @assign binding_sep = if printName
            " = "
          else
            "= "
          end
        end
        @assign binding_str = toString(mod.binding, binding_sep)
        if printName
          mod.name + subs_str + binding_str
        else
          subs_str + binding_str
        end
      end

      MODIFIER_REDECLARE(__) => begin
        toString(mod.element)
      end

      _ => begin
        ""
      end
    end
  end
  return string
end

function map(mod::Modifier, func::FuncT)
  @match mod begin
    MODIFIER_MODIFIER(__) => begin
      local subModifiers = ModTable.map(mod.subModifiers, func)
      mod = MODIFIER_MODIFIER(
        mod.name,
        mod.finalPrefix,
        mod.eachPrefix,
        mod.binding,
        subModifiers,
        mod.info,
      )
      end
    _ => begin end
  end
  return mod
end

function isFinal(mod::Modifier)
  local isFinal::Bool
  isFinal = begin
    @match mod begin
      MODIFIER_MODIFIER(finalPrefix = SCode.FINAL(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isFinal
end

function isEach(mod::Modifier)
  local isEach::Bool
  isEach = begin
    @match mod begin
      MODIFIER_MODIFIER(eachPrefix = SCode.EACH(__)) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isEach
end

function toList(mod::Modifier)
  local modList::List{Modifier}
  modList = begin
    @match mod begin
      MODIFIER_MODIFIER(__) => begin
        #println("Vector")
        #res = ModTable.vectorValues!(mod.subModifiers)
        #println(toString(res))
        #println("List")
        res = ModTable.listValues(mod.subModifiers)
      end
      _ => begin
        nil
      end
    end
  end
  return modList
end

const TMP_MOD = Modifier[]
function toVector!(mod::Modifier)
  local modV::Vector{Modifier}
  # println("Vector...")
  # println(toString(mod))
  # println("....")
  modV = @match mod begin
    MODIFIER_MODIFIER(__) where mod.subModifiers !== nothing => begin
      ModTable.vectorValues!(mod.subModifiers)
    end
    _ => begin
      TMP_MOD
    end
  end
  return modV
end

function isRedeclare(mod::Modifier)
  local isRedeclare::Bool
  isRedeclare = begin
    @match mod begin
      MODIFIER_REDECLARE(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isRedeclare
end

function isEmpty(mod::Modifier)
  local isEmpty::Bool
  isEmpty = begin
    @match mod begin
      MODIFIER_NOMOD(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isEmpty
end

function merge(outerMod::Modifier, innerMod::Modifier, name::String = "")
  local mergedMod::Modifier

  mergedMod = begin
    local submods::ModTable.Tree
    local binding::Binding
    #=  One of the modifiers is NOMOD, return the other. =#
    @match (outerMod, innerMod) begin
      (MODIFIER_NOMOD(__), _) => begin
        innerMod
      end

      (_, MODIFIER_NOMOD(__)) => begin
        outerMod
      end

      (MODIFIER_MODIFIER(__), MODIFIER_MODIFIER(__)) => begin
        #=  Two modifiers, merge bindings and submodifiers. =#
        checkFinalOverride(innerMod.finalPrefix, outerMod, innerMod.info)
        binding = if isBound(outerMod.binding)
          outerMod.binding
        else
          innerMod.binding
        end
        submods =
          ModTable.join(innerMod.subModifiers,
                        outerMod.subModifiers, merge)
        MODIFIER_MODIFIER(
          outerMod.name,
          outerMod.finalPrefix,
          outerMod.eachPrefix,
          binding,
          submods,
          outerMod.info,
        )
      end

      (MODIFIER_REDECLARE(__), MODIFIER_MODIFIER(__)) => begin
        mod = merge(outerMod.mod, innerMod)
        MODIFIER_REDECLARE(outerMod.finalPrefix, outerMod.eachPrefix, outerMod.element, mod)
      end

      (MODIFIER_MODIFIER(__), MODIFIER_REDECLARE(__)) => begin
        mod = merge(outerMod, innerMod.mod)
        MODIFIER_REDECLARE(innerMod.finalPrefix, innerMod.eachPrefix, innerMod.element, mod)
      end

      (MODIFIER_REDECLARE(__), _) => begin
        outerMod
      end

      (_, MODIFIER_REDECLARE(__)) => begin
        innerMod
      end

      _ => begin
        Error.addMessage(Error.INTERNAL_ERROR, list("Mod.mergeMod failed on unknown modifier."))
        fail()
      end
    end
  end
  return mergedMod
end

function setBinding(binding::Binding, mod::MODIFIER_MODIFIER)
  # local modifier = MODIFIER_MODIFIER(
  #       mod.name,
  #       mod.finalPrefix,
  #       mod.eachPrefix,
  #       binding,
  #       mod.subModifiers,
  #       mod.info,
  # )
  mod.binding = binding
  modifier = mod
  return modifier
end

function binding(modifier::Modifier)
  local binding::Binding
  binding = begin
    @match modifier begin
      MODIFIER_MODIFIER(__) => begin
        modifier.binding
      end
      _ => begin
        EMPTY_BINDING
      end
    end
  end
  return binding
end

function hasBinding(modifier::Modifier)
  local b::Bool
  b = begin
    @match modifier begin
      MODIFIER_MODIFIER(__) => begin
        isBound(modifier.binding)
      end
      _ => begin
        false
      end
    end
  end
  return b
end

function Modifier_info(modifier::Modifier)
  local info::SourceInfo
  info = begin
    @match modifier begin
      MODIFIER_MODIFIER(__) => begin
        modifier.info
      end

      MODIFIER_REDECLARE(__) => begin
        info(modifier.element)
      end

      _ => begin
        AbsynUtil.dummyInfo
      end
    end
  end
  return info
end

function name(modifier::Modifier)
  local nameStr::String
  nameStr = begin
    @match modifier begin
      MODIFIER_MODIFIER(__) => begin
        modifier.name
      end
      MODIFIER_REDECLARE(__) => begin
        name(modifier.element)
      end
    end
  end
  return nameStr
end

function lookupModifier(modName::String, modifier::Modifier)
  local subMod::Modifier
  subMod = begin
    @matchcontinue modifier begin
      MODIFIER_MODIFIER(__) => begin
        ModTable.get(modifier.subModifiers, modName)
      end
      _ => begin
        EMPTY_MOD
      end
    end
  end
  return subMod
end

function addParent_work(name::String, parentNode::InstNode, mod::Modifier)
  local outMod::Modifier
  outMod = begin
    local binding::Binding
    @match mod begin
      MODIFIER_MODIFIER(binding = binding) => begin
        modBinding = addParent(parentNode, binding)
        lmod = MODIFIER_MODIFIER(mod.name, mod.finalPrefix, mod.eachPrefix, modBinding, mod.subModifiers, mod.info)
        if !isEach(binding)
          map(lmod, (x,y) -> addParent_work(x, parentNode, y))
        else
          lmod
        end
      end

      _ => begin
        mod
      end
    end
  end
  return outMod
end

function addParent(parentNode::InstNode, mod::Modifier)
  local outMod::Modifier
  outMod = begin
    local binding::Binding
    @match mod begin
      MODIFIER_MODIFIER(binding = binding) => begin
        modBinding = addParent(parentNode, binding)
        #lmod = MODIFIER_MODIFIER(mod.name, mod.finalPrefix, mod.eachPrefix, modBinding, mod.subModifiers, mod.info)
        mod.binding = modBinding
        lmod = mod
        map(lmod, @closure (x, y) -> addParent_work(x, parentNode, y))
      end
      _ => begin
        mod
      end
    end
  end
  return outMod
end

"""  This function makes modifiers applied to final elements final, e.g. for
     'final Real x(start = 1.0)' it will mark '(start = 1.0)' as final. This is
     done so that we only need to check for final violations while merging
     modifiers.
"""
const DUMMY_MOD::SCode.MOD = SCode.MOD(SCode.FINAL(), SCode.NOT_EACH(), nil, NONE(), DAE.dummyInfo)
function patchElementModFinal(
  prefixes::SCode.Prefixes,
  info::SourceInfo,
  mod::SCode.Mod,
  )
  if SCodeUtil.finalBool(SCodeUtil.prefixesFinal(prefixes))
    mod = begin
      @match mod begin
        SCode.MOD(__) => begin
          local modFinalPrefix = SCode.FINAL()
          SCode.MOD(modFinalPrefix, mod.eachPrefix, mod.subModLst, mod.binding, mod.info)
        end
        SCode.REDECL(__) => begin
          local modFinalPrefix = SCode.FINAL()
          SCode.REDECL(modFinalPrefix, mod.eachPrefix, mod.element)
        end
        _ => begin
          DUMMY_MOD
        end
      end
    end
  end
  return mod
end

function fromElement(
  element::SCode.Element,
  parents::List{<:InstNode},
  scope::InstNode,
  )::Modifier
  local mod::Modifier
    local def::SCode.ClassDef
    local smod::SCode.Mod
  @match element begin
    SCode.EXTENDS(__) => begin
      create(
        element.modifications,
        "",
        SCOPE_EXTENDS(element.baseClassPath),
        parents,
        scope,
      )
    end

    SCode.COMPONENT(__) => begin
      smod =
        patchElementModFinal(element.prefixes, element.info, element.modifications)
      create(smod, element.name, SCOPE_COMPONENT(element.name), parents, scope)
    end

    SCode.CLASS(classDef = def) where {def isa SCode.DERIVED} => begin
      create(
        def.modifications,
        element.name,
        SCOPE_CLASS(element.name),
        parents,
        scope,
      )
    end

    SCode.CLASS(classDef = def && SCode.CLASS_EXTENDS(__)) => begin
      create(
        def.modifications,
        element.name,
        SCOPE_CLASS(element.name),
        parents,
        scope,
      )
    end

    _ => begin
      MODIFIER_NOMOD()
    end
  end
end

function stripSCodeMod(elem::SCode.Element)
  local mod::SCode.Mod
  local retElem
  mod = begin
    local cdef::SCode.ClassDef
    @match elem begin
      SCode.CLASS(classDef = cdef && SCode.DERIVED(modifications = mod)) => begin
        if !SCodeUtil.isEmptyMod(mod)
          cdef = SCode.DERIVED(cdef.typeSpec, SCode.NOMOD(), cdef.attributes)
          retElem = SCode.CLASS(elem.name,
                                elem.prefixes,
                                elem.encapsulatedPrefix,
                                elem.partialPrefix,
                                elem.restriction,
                                cdef,
                                elem.cmt,
                                elem.info)
        end
        mod
      end

      SCode.COMPONENT(modifications = mod) => begin
        if !SCodeUtil.isEmptyMod(mod)
          retElem = SCode.COMPONENT(elem.name,
                                    elem.prefixes,
                                    elem.attributes,
                                    elem.typeSpec,
                                    SCode.NOMOD(),
                                    elem.comment,
                                    elem.condition,
                                    elem.info)
        end
        mod
      end

      _ => begin
        SCode.NOMOD()
      end
    end
  end
  return (retElem, mod)
end

create(mod::SCode.NOMOD,
       name::String,
       modScope::ModifierScope,
       parents::List{<:InstNode},
       scope::InstNode) = MODIFIER_NOMOD()



function create(mod::SCode.REDECL,
                name::String,
                modScope::ModifierScope,
                parents::List{<:InstNode},
                scope::InstNode)::MODIFIER_REDECLARE
  local elem = mod.element
  node = new(elem, scope)
  if isClass(node)
    partialInstClass(node)
  end
  MODIFIER_REDECLARE(mod.finalPrefix, mod.eachPrefix, node, MODIFIER_NOMOD())
end

function create(mod::SCode.MOD,
                name::String,
                modScope::ModifierScope,
                parents::List{<:InstNode},
                scope::InstNode)::MODIFIER_MODIFIER
  local submodV::Vector{Modifier}
  local submod_table::ModTable.Tree
  local binding::Binding
  local elem::SCode.Element
  local smod::SCode.Mod
  local is_each::Bool
  local node::InstNode
  local pars::List{InstNode}
  is_each = SCodeUtil.eachBool(mod.eachPrefix)
  binding = fromAbsyn(mod.binding, is_each, parents, scope, mod.info)
  pars = if is_each
    nil
  else
    parents
  end
  local n = length(mod.subModLst)
  local submodV = Vector{Modifier}(undef, n)
  local submodK = Vector{String}(undef, n)
  local i = 1
  local tmp = mod.subModLst::List{SCode.SubMod}
  while tmp !== nil
    @match Cons{SCode.SubMod}(m, tmp) = tmp
    submodV[i] = createSubMod(m::SCode.NAMEMOD, modScope, pars, scope)
    submodK[i] = m.ident::String
    i += 1
  end
  submod_table = ModTable.fromVector(
    submodV,
    submodK,
    modScope,
    nil
  )
  MODIFIER_MODIFIER(name, mod.finalPrefix, mod.eachPrefix, binding, submod_table, mod.info)
end

"""
  Merges two modifiers in the same scope, i.e. like a(x(y = 1), x(z = 2)).
  This is allowed as long as the two modifiers doesn't modify the same
  element, otherwise it's an error.
"""
function mergeLocal(
  mod1::Modifier,
  mod2::Modifier,
  name::String = "",
  scope::ModifierScope = nothing,
  prefix::Vector{String} = String[],
  )::MODIFIER_MODIFIER
  local mod::Modifier
  local comp_name::String

  mod = begin
    @match (mod1, mod2) begin
      (MODIFIER_MODIFIER(__), MODIFIER_MODIFIER(binding = UNBOUND(__))) => begin
        #=  The second modifier has no binding, use the binding from the first.
        =#
        #local prefixV = mod1.name <| prefix
        push!(prefix, mod1.name)
        #@debug "Value of $lst"
        local mod1SubModifiers = ModTable.join(
          mod1.subModifiers,
          mod2.subModifiers,
          scope,
          prefix)
        MODIFIER_MODIFIER(mod1.name,
                          mod1.finalPrefix,
                          mod1.eachPrefix,
                          mod1.binding,
                          mod1SubModifiers,
                          mod1.info)
      end
      (MODIFIER_MODIFIER(binding = UNBOUND(__)), MODIFIER_MODIFIER(__)) => begin
        #=  The first modifier has no binding, use the binding from the second.
        =#
        #local lst = mod1.name <| prefix
        push!(prefix, mod1.name)
        #@debug "Value of $lst"
        local mod2SubModifiers = ModTable.join(
          mod2.subModifiers,
          mod1.subModifiers,
          scope,
          prefix)
        MODIFIER_MODIFIER(mod2.name,
                          mod2.finalPrefix,
                          mod2.eachPrefix,
                          mod2.binding,
                          mod2SubModifiers,
                          mod2.info)
      end

      _ => begin
        #=  Both modifiers modify the same element, give duplicate modification error.
        =#
        comp_name =
          stringDelimitList(listReverse(_cons(P_Modifier.name(mod1), prefix)), ".")
        Error.addMultiSourceMessage(
          Error.DUPLICATE_MODIFICATIONS,
          list(comp_name, P_ModifierScope.toString(scope)),
          list(P_Modifier.info(mod1), P_Modifier.info(mod2)),
        )
        fail()
      end
    end
  end
  return mod
end

"""
Checks that a modifier is not trying to override a final modifier.
In that case it prints an error and fails, otherwise it does nothing.
"""
function checkFinalOverride(
  innerFinal::SCode.Final,
  outerMod::Modifier,
  innerInfo::SourceInfo,
  )
  _ = begin
    @match innerFinal begin
      SCode.FINAL(__) => begin
        Error.addMultiSourceMessage(
          Error.FINAL_COMPONENT_OVERRIDE,
          list(name(outerMod), toString(outerMod, false)),
          list(Modifier_info(outerMod), innerInfo),
        )
        fail()
      end
      _ => begin
        ()
      end
    end
  end
end

function createSubMod(subMod::SCode.NAMEMOD,
                      modScope::ModifierScope,
                      parents::List{InstNode},
                      scope::InstNode)
  local mod = create(subMod.mod, subMod.ident, modScope, parents, scope)
  return mod
end

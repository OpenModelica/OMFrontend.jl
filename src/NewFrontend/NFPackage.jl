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

module ConstantsSetImpl
import ..NFComponentRef
import ..compare as crefCompare
using MetaModelica
using ExportAll
ComponentRef = NFComponentRef
#= Modelica extend clause =#
const Key = ComponentRef
const Value = Int
include("../Util/baseAvlTreeCode.jl")
#= The base tree's placeholder keyCompare returns a Bool; the AVL needs the
   three-way cref ordering or distinct keys collapse into one entry. =#
keyCompare = (inKey1::Key, inKey2::Key) -> crefCompare(inKey1, inKey2)
@exportAll()
end

Constants = ConstantsSetImpl.Tree

function collectConstants(flatModel::FlatModel, functions::FunctionTree)::FlatModel
  local vars::Vector{Variable} = Variable[]
  local binding::Binding
  local constants::Constants
  constants = ConstantsSetImpl.new()
  constants =
    ArrayUtil.fold(flatModel.variables, collectVariableConstants, constants)
  constants =
    foldExpList(flatModel.equations, collectExpConstants, constants)
  constants = foldExpList(
    flatModel.initialEquations,
    collectExpConstants,
    constants,
  )
  constants =
    foldExpList(flatModel.algorithms, collectExpConstants, constants)
  constants = foldExpList(
    flatModel.initialAlgorithms,
    collectExpConstants,
    constants,
  )
  constants = FunctionTreeImpl.fold(functions, collectFuncConstants, constants)
  vars = Variable[Variable_fromCref(c) for c in ConstantsSetImpl.listKeys(constants)]
  @assign flatModel.variables = vcat(vars, flatModel.variables)
#  execStat(getInstanceName()) TODO
  return flatModel
end

function replaceConstants(
  flatModel::FlatModel,
  functions::FunctionTree,
)::Tuple{FlatModel, FunctionTree}
  @assign begin
    flatModel.variables = Variable[replaceVariableConstants(c) for c in flatModel.variables]
    flatModel.equations = mapExpList(flatModel.equations, replaceExpConstants)
    flatModel.initialEquations = mapExpList(flatModel.initialEquations, replaceExpConstants)
    flatModel.algorithms =
      P_Algorithm.Algorithm.mapExpList(flatModel.algorithms, replaceExpConstants)
    flatModel.initialAlgorithms =
      P_Algorithm.Algorithm.mapExpList(flatModel.initialAlgorithms, replaceExpConstants)
  end
  @assign functions = FunctionTree.map(functions, replaceFuncConstants)
  execStat(getInstanceName())
  return (flatModel, functions)
end

function collectVariableConstants(var::Variable, constants::Constants)::Constants
  @assign constants = collectBindingConstants(var.binding, constants)
  #=  TODO: The component's attributes (i.e. start, etc) might also contain
  =#
  #=        package constants.
  =#
  return constants
end

function collectBindingConstants(binding::Binding, constants::Constants)::Constants
  if isExplicitlyBound(binding)
    @assign constants = collectExpConstants(getTypedExp(binding), constants)
  end
  return constants
end

function collectExpConstants(exp::Expression, constants::Constants)::Constants
  @assign constants =
    fold(exp, collectExpConstants_traverser, constants)
  return constants
end

function collectExpConstants_traverser(@nospecialize(exp::Expression), @nospecialize(constants::Constants))::Constants
  local cref::ComponentRef
   () = begin
    @match exp begin
      CREF_EXPRESSION(cref = cref && COMPONENT_REF_CREF(__)) =>
        begin
          if isPackageConstant(cref)
            typeComponentBinding(cref.node, ORIGIN_CLASS)
            @assign constants = ConstantsSetImpl.add(
              constants,
              stripSubscriptsAll(cref),
              0,
              ConstantsSetImpl.addConflictKeep,
            )
            @assign constants = collectBindingConstants(
              getBinding(component(node(
                cref,
              ))),
              constants,
            )
          end
          ()
        end
      _ => begin
        ()
      end
    end
  end
  return constants
end

function collectFuncConstants(
  name::Absyn.Path,
  func::M_Function,
  constants::Constants,
)::Constants

  local cls::Class
  local comps::Vector{InstNode}
  local sections::Sections

  @assign cls = getClass(func.node)
   () = begin
    @match cls begin
      INSTANCED_CLASS(
        elements = CLASS_TREE_FLAT_TREE(components = comps),
        sections = sections,
      ) => begin
        for c in comps
          @assign constants = collectBindingConstants(
            getBinding(component(c)),
            constants,
          )
        end
         () = begin
          @match sections begin
            SECTIONS(__) => begin
              @assign constants = foldExpList(
                sections.algorithms,
                collectExpConstants,
                constants,
              )
              ()
            end

            SECTIONS_EXTERNAL(__) => begin
              for arg in sections.args
                @assign constants = collectExpConstants(arg, constants)
              end
              ()
            end

            _ => begin
              ()
            end
          end
        end
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return constants
end

function replaceVariableConstants(var::Variable)::Variable
  local cref::ComponentRef
  local binding::Binding
  binding = replaceBindingConstants(var.binding)
  if !referenceEq(binding, var.binding)
    @assign var.binding = binding
  end
  return var
end

function replaceBindingConstants(binding::Binding)::Binding
   () = begin
    @match binding begin
      TYPED_BINDING(__) => begin
        @assign binding.bindingExp = replaceExpConstants(binding.bindingExp)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return binding
end

function replaceExpConstants(exp::Expression)::Expression

  @assign exp = map(exp, replaceExpConstants_traverser)
  return exp
end

function replaceExpConstants_traverser(exp::Expression)::Expression

  local cref::ComponentRef

  @assign exp = begin
    @match exp begin
      CREF_EXPRESSION(cref = cref && CREF(__)) =>
        begin
          if isPackageConstant(cref)
            evalExp(exp, EVALTARGET_IGNORE_ERRORS())
          else
            exp
          end
        end

      _ => begin
        exp
      end
    end
  end
  return exp
end

function replaceFuncConstants(name::Absyn.Path, func::M_Function)::M_Function

  local cls::Class
  local comps::Vector{InstNode}
  local sections::Sections
  local comp::Component
  local binding::Binding
  local eval_binding::Binding

  @assign cls = getClass(func.node)
   () = begin
    @match cls begin
      INSTANCED_CLASS(
        elements = CLASS_TREE_FLAT_TREE(components = comps),
        sections = sections,
      ) => begin
        for c in comps
          @assign comp = component(c)
          @assign binding = getBinding(comp)
          @assign eval_binding = replaceBindingConstants(binding)
          if !referenceEq(binding, eval_binding)
            @assign comp = setBinding(eval_binding, comp)
            updateComponent!(comp, c)
          end
        end
         () = begin
          @match sections begin
            P_Sections.Sections.SECTIONS(__) => begin
              @assign sections.algorithms = list(
                P_Algorithm.Algorithm.mapExp(a, replaceExpConstants)
                for a in sections.algorithms
              )
              @assign cls.sections = sections
              updateClass(cls, func.node)
              ()
            end

            SECTIONS_EXTERNAL(__) => begin
              @assign sections.args =
                list(replaceExpConstants(arg) for arg in sections.args)
              @assign cls.sections = sections
              updateClass(cls, func.node)
              ()
            end

            _ => begin
              ()
            end
          end
        end
        ()
      end
    end
  end
  return func
end

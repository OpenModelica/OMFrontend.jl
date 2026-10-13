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

@UniontypeDecl NFRestriction

@Uniontype NFRestriction begin
  @Record RESTRICTION_UNKNOWN begin
  end

  @Record RESTRICTION_CLOCK begin
  end

  @Record RESTRICTION_TYPE begin
  end

  @Record RESTRICTION_RECORD_CONSTRUCTOR begin
  end

  @Record RESTRICTION_RECORD begin
    isOperator::Bool
  end

  @Record RESTRICTION_OPERATOR begin
  end

  @Record RESTRICTION_MODEL begin
  end

  @Record RESTRICTION_FUNCTION begin
  end

  @Record RESTRICTION_EXTERNAL_OBJECT begin
  end

  @Record RESTRICTION_ENUMERATION begin
  end

  @Record RESTRICTION_CONNECTOR begin
    isExpandable::Bool
  end

  @Record RESTRICTION_CLASS begin
  end
end

const Restriction = NFRestriction

function toString(res::Restriction)::String
  local str::String
  str = begin
    @match res begin
      RESTRICTION_CLASS(__) => begin
        "class"
      end

      RESTRICTION_CONNECTOR(__) => begin
        if res.isExpandable
          "expandable connector"
        else
          "connector"
        end
      end

      RESTRICTION_ENUMERATION(__) => begin
        "enumeration"
      end

      RESTRICTION_EXTERNAL_OBJECT(__) => begin
        "ExternalObject"
      end

      RESTRICTION_FUNCTION(__) => begin
        "function"
      end

      RESTRICTION_MODEL(__) => begin
        "model"
      end

      RESTRICTION_OPERATOR(__) => begin
        "operator"
      end
      RESTRICTION_RECORD(__) => begin
        "record"
      end
      RESTRICTION_RECORD_CONSTRUCTOR(__) => begin
        "record"
      end
      RESTRICTION_TYPE(__) => begin
        "type"
      end
      RESTRICTION_CLOCK(__) => begin
        "clock"
      end

      _ => begin
        "unknown"
      end
    end
  end
  return str
end

function isModel(res::Restriction)::Bool
  local isModel::Bool
  @assign isModel = begin
    @match res begin
      RESTRICTION_MODEL(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isModel
end

function isClock(res::Restriction)::Bool
  local isClock::Bool
  @assign isClock = begin
    @match res begin
      CLOCK(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isClock
end

function isType(res::Restriction)::Bool
  local isType::Bool
  @assign isType = begin
    @match res begin
      RESTRICTION_TYPE(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isType
end

function isOperator(res::Restriction)::Bool
  local isOperator::Bool
  @assign isOperator = begin
    @match res begin
      RESTRICTION_OPERATOR(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isOperator
end

function isOperatorRecord(res::Restriction)::Bool
  local isOpRecord::Bool
  @assign isOpRecord = begin
    @match res begin
      RESTRICTION_RECORD(__) => begin
        res.isOperator
      end
      _ => begin
        false
      end
    end
  end
  return isOpRecord
end

function isRecord(res::Restriction)::Bool
  local isRecord::Bool
  @assign isRecord = begin
    @match res begin
      RESTRICTION_RECORD(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isRecord
end

function isFunction(res::Restriction)::Bool
  local isFunction::Bool
  @assign isFunction = begin
    @match res begin
      RESTRICTION_FUNCTION(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isFunction
end

function isExternalObject(res::Restriction)::Bool
  local isExternalObject::Bool
  @assign isExternalObject = begin
    @match res begin
      RESTRICTION_EXTERNAL_OBJECT(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isExternalObject
end

function isNonexpandableConnector(res::Restriction)::Bool
  local isNonexpandable::Bool

  @assign isNonexpandable = begin
    @match res begin
      RESTRICTION_CONNECTOR(__) => begin
        !res.isExpandable
      end
      _ => begin
        false
      end
    end
  end
  return isNonexpandable
end

function isExpandableConnector(res::Restriction)::Bool
  local isConnector::Bool
  @assign isConnector = begin
    @match res begin
      RESTRICTION_CONNECTOR(__) => begin
        res.isExpandable
      end

      _ => begin
        false
      end
    end
  end
  return isConnector
end

function isConnector(res::Restriction)::Bool
  local isConnector::Bool
  @assign isConnector = begin
    @match res begin
      RESTRICTION_CONNECTOR(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isConnector
end

import DAE.ClassInf

function toDAE(res::Restriction, path::Absyn.Path)::ClassInf.SMNode
  local state::ClassInf.SMNode

  @assign state = begin
    @match res begin
      RESTRICTION_CLASS(__) => begin
        ClassInf.UNKNOWN(path)
      end
      RESTRICTION_CONNECTOR(__) => begin
        ClassInf.CONNECTOR(path, res.isExpandable)
      end
      RESTRICTION_ENUMERATION(__) => begin
        ClassInf.ENUMERATION(path)
      end
      RESTRICTION_EXTERNAL_OBJECT(__) => begin
        ClassInf.EXTERNAL_OBJ(path)
      end
      RESTRICTION_FUNCTION(__) => begin
        ClassInf.FUNCTION(path, false)
      end
      RESTRICTION_MODEL(__) => begin
        ClassInf.MODEL(path)
      end
      RESTRICTION_OPERATOR(__) => begin
        ClassInf.FUNCTION(path, false)
      end
      RESTRICTION_RECORD(__) => begin
        ClassInf.RECORD(path)
      end
      RESTRICTION_TYPE(__) => begin
        ClassInf.TYPE(path)
      end
      RESTRICTION_CLOCK(__) => begin
        ClassInf.TYPE_CLOCK(path)
      end
      _ => begin
        ClassInf.UNKNOWN(path)
      end
    end
  end
  return state
end

function fromSCode(sres::SCode.Restriction)::Restriction
  local res::Restriction
  @assign res = begin
    @match sres begin
      SCode.R_CLASS(__) => begin
        RESTRICTION_CLASS()
      end
      SCode.R_CONNECTOR(__) => begin
        RESTRICTION_CONNECTOR(sres.isExpandable)
      end
      SCode.R_ENUMERATION(__) => begin
        RESTRICTION_ENUMERATION()
      end
      SCode.R_FUNCTION(__) => begin
        RESTRICTION_FUNCTION()
      end
      SCode.R_MODEL(__) => begin
        RESTRICTION_MODEL()
      end
      SCode.R_OPERATOR(__) => begin
        RESTRICTION_OPERATOR()
      end
      SCode.R_RECORD(__) => begin
        RESTRICTION_RECORD(sres.isOperator)
      end
      SCode.R_TYPE(__) => begin
        RESTRICTION_TYPE()
      end
      SCode.R_PREDEFINED_CLOCK(__) => begin
        RESTRICTION_CLOCK()
      end
      _ => begin
        RESTRICTION_MODEL()
      end
    end
  end
  return res
end

"""
omc's Restriction.checkClass: the sections and elements the class specialization does not
allow. Packages are models here (fromSCode), so they are told apart by their SCode
restriction. The deprecation warnings for plain classes are not ported.
"""
function checkClassRestriction(node::InstNode, res::Restriction)
  local def::SCode.Element = definition(node)
  local cdef::SCode.ClassDef = SCodeUtil.getClassBody(def)
  local is_package::Bool = SCodeUtil.isPackage(def)
  @match cdef begin
    SCode.PARTS(__) => begin
      if is_package
        #= All components in a package must be constants. =#
        assertOnlyConstantComponents(cdef.elementLst, node)
        assertNoEquations(cdef.normalEquationLst, cdef.initialEquationLst, "package")
        assertNoAlgorithms(cdef.normalAlgorithmLst, cdef.initialAlgorithmLst, "package")
      else
        @match res begin
          RESTRICTION_RECORD(__) || RESTRICTION_TYPE(__) || RESTRICTION_CONNECTOR(__) => begin
            #= Records, types and connectors may only contain public sections. =#
            assertNoProtected(cdef.elementLst, toString(res))
            assertNoEquations(cdef.normalEquationLst, cdef.initialEquationLst, toString(res))
            assertNoAlgorithms(cdef.normalAlgorithmLst, cdef.initialAlgorithmLst, toString(res))
          end
          RESTRICTION_FUNCTION(__) => begin
            #= Functions may not contain equations or initial algorithms. =#
            assertNoEquations(cdef.normalEquationLst, cdef.initialEquationLst, toString(res))
            assertNoInitialAlgorithms(cdef.initialAlgorithmLst, toString(res))
          end
          RESTRICTION_OPERATOR(__) => begin
            assertNoEquations(cdef.normalEquationLst, cdef.initialEquationLst, toString(res))
            assertNoAlgorithms(cdef.normalAlgorithmLst, cdef.initialAlgorithmLst, toString(res))
          end
          _ => ()
        end
      end
    end
    _ => ()
  end
  return nothing
end

"""
omc's Restriction.toString of a class node's restriction: packages are models here
(fromSCode), so they are named by their SCode restriction.
"""
function restrictionName(res::Restriction, clsNode::InstNode)::String
  local def = definition(clsNode)
  return if def isa SCode.Element && SCodeUtil.isPackage(def)
    "package"
  else
    toString(res)
  end
end

"""
omc NFInst.checkBindingRestriction: a component of a class that is not a clock, connector,
enumeration, external object, record or type may not have a binding.
"""
function checkBindingRestriction(res::Restriction, binding::Binding, component::InstNode, clsNode::InstNode, info::SourceInfo)
  if isBound(binding)
    @match res begin
      RESTRICTION_CLOCK(__) || RESTRICTION_CONNECTOR(__) || RESTRICTION_ENUMERATION(__) ||
      RESTRICTION_EXTERNAL_OBJECT(__) || RESTRICTION_RECORD(__) || RESTRICTION_TYPE(__) ||
      RESTRICTION_UNKNOWN(__) => ()
      _ => begin
        Error.addSourceMessage(Error.INVALID_SPECIALIZATION_FOR_BINDING_EQUATION,
          list(name(component), restrictionName(res, clsNode)), info)
        fail()
      end
    end
  end
  return nothing
end

function assertNoEquations(equations::List{SCode.Equation}, initialEquations::List{SCode.Equation}, resName::String)
  if listEmpty(equations) && listEmpty(initialEquations)
    return nothing
  end
  local eq::SCode.Equation = listHead(if listEmpty(equations) initialEquations else equations end)
  Error.addSourceMessage(Error.EQUATION_TRANSITION_FAILURE, list(resName), SCodeUtil.getEquationInfo(eq.eEquation))
  fail()
end

function assertNoAlgorithms(algorithms::List{SCode.AlgorithmSection}, initialAlgorithms::List{SCode.AlgorithmSection}, resName::String)
  local alg_opt::Option{SCode.AlgorithmSection} = ListUtil.findOption(algorithms, SCodeUtil.isNonEmptyAlgorithm)
  if isNone(alg_opt)
    alg_opt = ListUtil.findOption(initialAlgorithms, SCodeUtil.isNonEmptyAlgorithm)
  end
  if isSome(alg_opt)
    local alg::SCode.AlgorithmSection = Util.getOption(alg_opt)
    Error.addSourceMessage(Error.ALGORITHM_TRANSITION_FAILURE, list(resName), SCodeUtil.getStatementInfo(listHead(alg.statements)))
    fail()
  end
  return nothing
end

function assertNoInitialAlgorithms(algs::List{SCode.AlgorithmSection}, resName::String)
  for alg in algs
    if !listEmpty(alg.statements)
      Error.addSourceMessage(Error.INITIAL_ALGORITHM_TRANSITION_FAILURE, list(resName), SCodeUtil.getStatementInfo(listHead(alg.statements)))
      fail()
    end
  end
  return nothing
end

function assertNoProtected(elements::List{SCode.Element}, resName::String)
  for e in elements
    if SCodeUtil.isElementProtected(e)
      Error.addSourceMessage(Error.PROTECTED_TRANSITION_FAILURE, list(resName), SCodeUtil.elementInfo(e))
      fail()
    end
  end
  return nothing
end

function assertOnlyConstantComponents(elements::List{SCode.Element}, clsNode::InstNode)
  for e in elements
    @match e begin
      SCode.COMPONENT(__) where {!SCodeUtil.isConstant(SCodeUtil.attrVariability(e.attributes))} => begin
        Error.addSourceMessage(Error.PACKAGE_VARIABLE_NOT_CONSTANT, list(e.name, name(clsNode)), e.info)
        fail()
      end
      _ => ()
    end
  end
  return nothing
end

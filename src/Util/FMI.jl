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

module FMI

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

@UniontypeDecl Info
@UniontypeDecl TypeDefinitions
@UniontypeDecl EnumerationItem
@UniontypeDecl ExperimentAnnotation
@UniontypeDecl ModelVariables
@UniontypeDecl FmiImport

import Frontend.Flags

import ListUtil

@Uniontype Info begin
  @Record INFO begin

    fmiVersion::String
    fmiType::Int
    fmiModelName::String
    fmiModelIdentifier::String
    fmiGuid::String
    fmiDescription::String
    fmiGenerationTool::String
    fmiGenerationDateAndTime::String
    fmiVariableNamingConvention::String
    fmiNumberOfContinuousStates::List{Integer}
    fmiNumberOfEventIndicators::List{Integer}
  end
end

@Uniontype TypeDefinitions begin
  @Record ENUMERATIONTYPE begin

    name::String
    description::String
    quantity::String
    min::Int
    max::Int
    items::List{EnumerationItem}
  end
end

@Uniontype EnumerationItem begin
  @Record ENUMERATIONITEM begin

    name::String
    description::String
  end
end

@Uniontype ExperimentAnnotation begin
  @Record EXPERIMENTANNOTATION begin

    fmiExperimentStartTime::AbstractFloat
    fmiExperimentStopTime::AbstractFloat
    fmiExperimentTolerance::AbstractFloat
  end
end

@Uniontype ModelVariables begin
  @Record REALVARIABLE begin

    instance::Int
    name::String
    description::String
    baseType::String
    variability::String
    causality::String
    hasStartValue::Bool
    startValue::AbstractFloat
    isFixed::Bool
    valueReference::AbstractFloat
    x1Placement::Int
    x2Placement::Int
    y1Placement::Int
    y2Placement::Int
  end

  @Record INTEGERVARIABLE begin

    instance::Int
    name::String
    description::String
    baseType::String
    variability::String
    causality::String
    hasStartValue::Bool
    startValue::Int
    isFixed::Bool
    valueReference::AbstractFloat
    x1Placement::Int
    x2Placement::Int
    y1Placement::Int
    y2Placement::Int
  end

  @Record BOOLEANVARIABLE begin

    instance::Int
    name::String
    description::String
    baseType::String
    variability::String
    causality::String
    hasStartValue::Bool
    startValue::Bool
    isFixed::Bool
    valueReference::AbstractFloat
    x1Placement::Int
    x2Placement::Int
    y1Placement::Int
    y2Placement::Int
  end

  @Record STRINGVARIABLE begin

    instance::Int
    name::String
    description::String
    baseType::String
    variability::String
    causality::String
    hasStartValue::Bool
    startValue::String
    isFixed::Bool
    valueReference::AbstractFloat
    x1Placement::Int
    x2Placement::Int
    y1Placement::Int
    y2Placement::Int
  end

  @Record ENUMERATIONVARIABLE begin

    instance::Int
    name::String
    description::String
    baseType::String
    variability::String
    causality::String
    hasStartValue::Bool
    startValue::Int
    isFixed::Bool
    valueReference::AbstractFloat
    x1Placement::Int
    x2Placement::Int
    y1Placement::Int
    y2Placement::Int
  end
end

@Uniontype FmiImport begin
  @Record FMIIMPORT begin

    platform::String
    fmuFileName::String
    fmuWorkingDirectory::String
    fmiLogLevel::Int
    fmiDebugOutput::Bool
    fmiContext::Option{Integer}
    fmiInstance::Option{Integer}
    fmiInfo::Info
    fmiTypeDefinitionsList::List{TypeDefinitions}
    fmiExperimentAnnotation::ExperimentAnnotation
    fmiModelVariablesInstance::Option{Integer}
    fmiModelVariablesList::List{ModelVariables}
    generateInputConnectors::Bool
    generateOutputConnectors::Bool
  end
end

function getFMIModelIdentifier(inFMIInfo::Info)::String
  local fmiModelIdentifier::String

  @assign fmiModelIdentifier = begin
    local modelIdentifier::String
    @match inFMIInfo begin
      INFO(fmiModelIdentifier = modelIdentifier) => begin
        modelIdentifier
      end
    end
  end
  return fmiModelIdentifier
end

function getFMIType(inFMIInfo::Info)::String
  local fmiType::String

  @assign fmiType = begin
    @match inFMIInfo begin
      INFO(fmiVersion = "1.0", fmiType = 0) => begin
        "me"
      end

      INFO(fmiVersion = "1.0", fmiType = 1) => begin
        "cs_st"
      end

      INFO(fmiVersion = "1.0", fmiType = 2) => begin
        "cs_tool"
      end

      INFO(fmiVersion = "2.0", fmiType = 1) => begin
        "me"
      end

      INFO(fmiVersion = "2.0", fmiType = 2) => begin
        "cs"
      end

      INFO(fmiVersion = "2.0", fmiType = 3) => begin
        "me_cs"
      end
    end
  end
  return fmiType
end

function getFMIVersion(inFMIInfo::Info)::String
  local fmiVersion::String

  @assign fmiVersion = begin
    local version::String
    @match inFMIInfo begin
      INFO(fmiVersion = version) => begin
        version
      end
    end
  end
  return fmiVersion
end

"""Checks if the FMU version is supported."""
function checkFMIVersion(inFMIVersion::String)::Bool
  local success::Bool

  @assign success = begin
    @match inFMIVersion begin
      "1.0" => begin
        true
      end

      "2.0" => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return success
end

"""Checks if the FMI version is 1.0."""
function isFMIVersion10(inFMUVersion::String)::Bool
  local success::Bool

  @assign success = begin
    @match inFMUVersion begin
      "1.0" => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return success
end

"""Checks if the FMI version is 2.0."""
function isFMIVersion20(inFMUVersion::String = getFMIVersionString())::Bool
  local success::Bool

  @assign success = begin
    @match inFMUVersion begin
      "2.0" => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return success
end

"""Returns the FMI version string."""
function getFMIVersionString()::String
  local version::String = Flags.getConfigString(Flags.FMI_VERSION)
  return version
end

"""Checks if the FMU type is supported."""
function checkFMIType(inFMIType::String)::Bool
  local success::Bool

  @assign success = begin
    @match inFMIType begin
      "me" => begin
        true
      end

      "cs" => begin
        true
      end

      "me_cs" => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return success
end

function canExportFMU(inFMUVersion::String, inFMIType::String)::Bool
  local success::Bool

  @assign success = begin
    @match (inFMUVersion, inFMIType) begin
      ("1.0", "me") => begin
        true
      end

      ("2.0", "me") => begin
        true
      end

      ("2.0", "cs") => begin
        true
      end

      ("2.0", "me_cs") => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return success
end

"""Checks if FMU type is model exchange"""
function isFMIMEType(inFMIType::String)::Bool
  local success::Bool

  @assign success = begin
    @match inFMIType begin
      "me" => begin
        true
      end

      "me_cs" => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return success
end

"""Checks if FMU type is co-simulation"""
function isFMICSType(inFMIType::String)::Bool
  local success::Bool

  @assign success = begin
    @match inFMIType begin
      "cs" => begin
        true
      end

      "me_cs" => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return success
end

function getEnumerationTypeFromTypes(
  inTypeDefinitionsList::List{<:TypeDefinitions},
  inBaseType::String,
)::String
  local outEnumerationType::String

  @assign outEnumerationType = begin
    local xs::List{TypeDefinitions}
    local name_::String
    local baseType::String
    @match (inTypeDefinitionsList, inBaseType) begin
      (ENUMERATIONTYPE(name = name_) <| _, baseType) where {(stringEqual(name_, baseType))} => begin
        name_
      end

      (_ <| xs, baseType) => begin
        @assign name_ = getEnumerationTypeFromTypes(xs, baseType)
        name_
      end

      (nil(), _) => begin
        ""
      end
    end
  end
  return outEnumerationType
end

function filterModelVariables(
  inModelVariables::List{<:ModelVariables},
  tipe::String,
  variableCausality::String,
)::List{ModelVariables}
  local outModelVariables::List{ModelVariables}

  @assign outModelVariables =
    ListUtil.filter2OnTrue(inModelVariables, filterModelVariable, tipe, variableCausality)
  return outModelVariables
end

function filterModelVariable(
  modelVar::ModelVariables,
  tipe::String,
  variableCausality::String,
)::Bool
  local result::Bool

  @assign result = begin
    local causality::String
    @match modelVar begin
      REALVARIABLE(
        causality = causality,
      ) where {(tipe == "real" && causality == variableCausality)} => begin
        true
      end

      INTEGERVARIABLE(
        causality = causality,
      ) where {(tipe == "integer" && causality == variableCausality)} => begin
        true
      end

      BOOLEANVARIABLE(
        causality = causality,
      ) where {(tipe == "boolean" && causality == variableCausality)} => begin
        true
      end

      STRINGVARIABLE(
        causality = causality,
      ) where {(tipe == "string" && causality == variableCausality)} => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return result
end

@exportAll()
end

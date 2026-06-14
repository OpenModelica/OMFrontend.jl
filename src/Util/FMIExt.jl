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

module FMIExt

using MetaModelica
using ExportAll

import Frontend.FMI

function initializeFMIImport(
  inFileName::String,
  inWorkingDirectory::String,
  inFMILogLevel::Int,
  inInputConnectors::Bool,
  inOutputConnectors::Bool,
  inIsModelDescriptionImport::Bool = false,
)::Tuple{
  Bool,
  Option{Integer},
  Option{Integer},
  FMI.Info,
  List{FMI.TypeDefinitions},
  FMI.ExperimentAnnotation,
  Option{Integer},
  List{FMI.ModelVariables},
}
  local outModelVariablesList::List{FMI.ModelVariables}
  local outModelVariablesInstance::Option{Integer} #= Stores a pointer. If it is declared as Integer, it is truncated to 32-bit. =#
  local outExperimentAnnotation::FMI.ExperimentAnnotation
  local outTypeDefinitionsList::List{FMI.TypeDefinitions}
  local outFMIInfo::FMI.Info
  local outFMIInstance::Option{Integer} #= Stores a pointer. If it is declared as Integer, it is truncated to 32-bit. =#
  local outFMIContext::Option{Integer} #= Stores a pointer. If it is declared as Integer, it is truncated to 32-bit. =#
  local result::Bool

  @error "TODO: Defined in the runtime"
  return (
    result,
    outFMIContext,
    outFMIInstance,
    outFMIInfo,
    outTypeDefinitionsList,
    outExperimentAnnotation,
    outModelVariablesInstance,
    outModelVariablesList,
  ) #= Stores a pointer. If it is declared as Integer, it is truncated to 32-bit. =#
end

function releaseFMIImport(
  inFMIModelVariablesInstance::Option{<:Integer},
  inFMIInstance::Option{<:Integer},
  inFMIContext::Option{<:Integer},
  inFMIVersion::String,
) #= Stores a pointer. If it is declared as Integer, it is truncated to 32-bit. =#
  return @error "TODO: Defined in the runtime"
end

@exportAll()
end

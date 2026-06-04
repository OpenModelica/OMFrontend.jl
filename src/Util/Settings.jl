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

module Settings 

using MetaModelica
using ExportAll

import Pkg

#=The directory path. Can be modified. `find_package` returns nothing while the
  package precompiles itself (e.g. under --code-coverage), so fall back to the
  source location, which resolves to the same file. =#
INSTALLATION_DIRECTORY_PATH = let _p = Base.find_package("OMFrontend")
  realpath(_p === nothing ? normpath(joinpath(@__DIR__, "..", "OMFrontend.jl")) : _p)
end

"""Returns the version number of this release"""
function getVersionNr() ::String 
 "TODO"       
end

function setCompilePath(inString::String)  
    #= TODO: Defined in the runtime =#
end

function setCompileCommand(inString::String)  
    #= TODO: Defined in the runtime =#
end

function getCompileCommand() ::String 
    #= TODO: Defined in the runtime =#
end

function setTempDirectoryPath(inString::String)  
    #= TODO: Defined in the runtime =#
end

function getTempDirectoryPath() ::String 
    #= TODO: Defined in the runtime =#
    "TODO getTempDirectoryPath"
end


function setInstallationDirectoryPath(path::String)  
  global INSTALLATION_DIRECTORY_PATH = path
end

function getInstallationDirectoryPath()::String
  if INSTALLATION_DIRECTORY_PATH != nothing
    INSTALLATION_DIRECTORY_PATH
  else #The default variant
    #= pathToOMC is always in src. We need to go up two steps =#
    local pathToOMC = realpath(realpath(Base.find_package("OMCompiler") * "./../.."))
    global INSTALLATION_DIRECTORY_PATH = pathToOMC    
  end
end

function setModelicaPath(inString::String)  
  #= TODO: Defined in the runtime =#
end

function getModelicaPath(runningTestsuite::Bool) ::String 
    #= TODO: Defined in the runtime =#
    "modelicaPath"
end

function getHomeDir(runningTestsuite::Bool) ::String 
    #= TODO: Defined in the runtime =#
    "getHomeDir"
end

function getEcho()::ModelicaInteger 
    #= TODO: Defined in the runtime =#
    0
end

function setEcho(echo::ModelicaInteger)  
    #= TODO: Defined in the runtime =#
end

@exportAll()
end

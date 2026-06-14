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

module Global

using MetaModelica
using ExportAll
import ..System


const recursionDepthLimit = 256::Int
const maxFunctionFileLength = 50::Int
#=  Thread-local roots
=#
const instOnlyForcedFunctions = 0::Int
const simulationData = 0::Int #= For simulations =#
const codegenTryThrowIndex = 1::Int
const codegenFunctionList = 2::Int
const symbolTable = 3::Int
#=  Global roots start at index=9
=#
const instHashIndex = 9::Int
const instNFInstCacheIndex = 10::Int
const instNFNodeCacheIndex = 11::Int
const builtinIndex = 12::Int
const builtinEnvIndex = 13::Int
const profilerTime1Index = 14::Int
const profilerTime2Index = 15::Int
const flagsIndex = 16::Int
const builtinGraphIndex = 17::Int
const rewriteRulesIndex = 18::Int
const stackoverFlowIndex = 19::Int
const gcProfilingIndex = 20::Int
const inlineHashTable = 21::Int
#=  TODO: Should be a local root?
=#
const currentInstVar = 22::Int
const operatorOverloadingCache = 23::Int
const optionSimCode = 24::Int
const interactiveCache = 25::Int
const isInStream = 26::Int
const MM_TO_JL_HT_INDEX = 27::Int
const packageIndexCacheIndex = 28::Int
#=  indexes in System.tick
=#
#=  ----------------------
=#
#=  temp vars index
=#
const tmpVariableIndex = 4::Int
#=  file seq
=#
const backendDAE_fileSequence = 20::Int
#=  jacobian name
=#
const backendDAE_jacobianSeq = 21::Int
#=  nodeId
=#
const fgraph_nextId = 22::Int
#=  csevar name
=#
const backendDAE_cseIndex = 23::Int
#=  strong component index
=#
const strongComponent_index = 24::Int
#=  class extends
=#
const classExtends_index = 25::Int
#=  ----------------------
=#

"""  Called to initialize global roots (when needed) """
function initialize()
  setGlobalRoot(instOnlyForcedFunctions, NONE())
  setGlobalRoot(rewriteRulesIndex, NONE())
  setGlobalRoot(stackoverFlowIndex, NONE())
  setGlobalRoot(inlineHashTable, NONE())
  setGlobalRoot(currentInstVar, NONE())
  setGlobalRoot(interactiveCache, NONE())
  setGlobalRoot(instNFInstCacheIndex, nil)
  setGlobalRoot(tmpVariableIndex, 0)
  return setGlobalRoot(instNFNodeCacheIndex, nil)
end

@exportAll()
end

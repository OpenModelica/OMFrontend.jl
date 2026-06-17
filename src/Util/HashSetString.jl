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

module HashSetString

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

FuncHashCref = Function
FuncCrefEqual = Function
FuncCrefStr = Function

#= /* Below is the instance specific code. For each hashset the user must define:

Key       - The key used to uniquely define elements in a hashset
hashFunc   - A function that maps a key to a positive integer.
keyEqual   - A comparison function between two keys, returns true if equal.
*/ =#
#= /* HashSet instance specific code */ =#

import Frontend.BaseHashSet

import Frontend.Util

Key = String

HashSetCrefFunctionsType = Tuple

HashSet = Tuple

"""
  Returns an empty HashSet.
  Using the default bucketsize..
"""
function emptyHashSet()::HashSet
  local hashSet::HashSet

  @assign hashSet = emptyHashSetSized(BaseHashSet.defaultBucketSize)
  return hashSet
end

"""
  Returns an empty HashSet.
  Using the bucketsize size
"""
function emptyHashSetSized(size::Int)::HashSet
  local hashSet::HashSet

  @assign hashSet =
    BaseHashSet.emptyHashSetWork(size, (stringHashDjb2Mod, stringEq, Util.id))
  return hashSet
end

@exportAll()
end

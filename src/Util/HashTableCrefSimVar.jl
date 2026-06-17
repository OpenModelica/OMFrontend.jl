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

module HashTableCrefSimVar

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

FuncHashCref = Function
FuncCrefEqual = Function
FuncCrefStr = Function
FuncExpStr = Function

#= /* Below is the instance specific code. For each hashtable the user must define:

Key       - The key used to uniquely define elements in a hashtable
Value     - The data to associate with each key
hashFunc   - A function that maps a key to a positive integer.
keyEqual   - A comparison function between two keys, returns true if equal.
*/ =#
#= /* HashTable instance specific code */ =#
import Frontend.BaseHashTable
import DAE
import Frontend.SimCodeVar
import Frontend.Error.addInternalError
Key = DAE.ComponentRef
Value = SimCodeVar.SimVar

import Frontend.ComponentReference

HashTableCrefFunctionsType = Tuple
HashTable = Tuple

"""
  Returns an empty HashTable.
  Using the default bucketsize..
"""
function emptyHashTable()::HashTable
  local hashTable::HashTable

  @assign hashTable = emptyHashTableSized(BaseHashTable.defaultBucketSize)
  return hashTable
end

"""
  Returns an empty HashTable.
  Using the bucketsize size.
"""
function emptyHashTableSized(size::Int)::HashTable
  local hashTable::HashTable

  @assign hashTable = BaseHashTable.emptyHashTableWork(
    size,
    (
      ComponentReference.hashComponentRefMod,
      ComponentReference.crefEqual,
      ComponentReference.printComponentRefStr,
      opaqueStr,
    ),
  )
  return hashTable
end

function opaqueStr(var::SimCodeVar.SimVar)::String
  local str::String

  @assign str =
    "#SimVar(index=" +
    String(var.index) +
    ",name=" +
    ComponentReference.printComponentRefStr(var.name) +
    ")#"
  return str
end

"""adds SimVar to hash table inHT and returns extended hash table"""
function addSimVarToHashTable(simvarIn::SimCodeVar.SimVar, inHT::HashTable)::HashTable
  local outHT::HashTable

  @assign outHT = begin
    local cr::DAE.ComponentRef
    local acr::DAE.ComponentRef
    local sv::SimCodeVar.SimVar
    @matchcontinue (simvarIn, inHT) begin
      (sv && SimCodeVar.SIMVAR(name = cr, arrayCref = NONE()), _) => begin
        @assign outHT = BaseHashTable.add((cr, sv), inHT)
        outHT
      end

      (sv && SimCodeVar.SIMVAR(name = cr, arrayCref = SOME(acr)), _) => begin
        @assign outHT = BaseHashTable.add((acr, sv), inHT)
        @assign outHT = BaseHashTable.add((cr, sv), outHT)
        outHT
      end

      _ => begin
        Error.addInternalError("function addSimVarToHashTable failed", sourceInfo())
        fail()
      end
    end
  end
  #= print(\"addSimVarToHashTable: handling variable '\" + ComponentReference.printComponentRefStr(cr) + \"'\\n\");
  =#
  #=  add the whole array crefs to the hashtable, too
  =#
  #= print(\"addSimVarToHashTable: handling array variable '\" + ComponentReference.printComponentRefStr(cr) + \"'\\n\");
  =#
  return outHT
end

@exportAll()
end

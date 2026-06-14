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

module HashTableCrToCrEqLst

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

import Frontend.BackendDAE

import Frontend.ComponentReference

import Frontend.BackendDump

import ListUtil

Key = DAE.ComponentRef

Value = List

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
      printTupleComponentRefEqListStr,
    ),
  )
  return hashTable
end

function printTupleComponentRefEqListStr(
  cr_eq_lst::List{<:Tuple{<:DAE.ComponentRef, BackendDAE.Equation}},
)::String
  local res::String

  @assign res = stringDelimitList(ListUtil.map(cr_eq_lst, printTupleComponentRefEqStr), ",")
  return res
end

function printTupleComponentRefEqStr(
  cr_eq::Tuple{<:DAE.ComponentRef, BackendDAE.Equation},
)::String
  local res::String

  local cr::DAE.ComponentRef
  local eq::BackendDAE.Equation

  @assign (cr, eq) = cr_eq
  @assign res =
    "{" +
    ComponentReference.printComponentRefStr(cr) +
    "," +
    BackendDump.equationString(eq) +
    "}"
  return res
end

@exportAll()
end

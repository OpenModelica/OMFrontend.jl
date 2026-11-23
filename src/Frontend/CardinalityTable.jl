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

module CardinalityTable

import ..System
import ..Util
import ..CONNECTOR
import ..toString
import ..INTEGER_EXPRESSION

using ExportAll
using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo

const Table = Dict{String, Int}

function emptyCardinalityTable()
  return Table()
end

function fromConnections(conns)
  local table::Table
  if System.getUsesCardinality()
    table = emptyCardinalityTable()
    for conn in conns.connections
      table = addConnector(conn.lhs, table)
      table = addConnector(conn.rhs, table)
    end
  else
    table = emptyCardinalityTable()
  end
  return table
end

function addConnector(conn::CONNECTOR, table::Table)
  local conn_str::String
  local count::Int
  conn_str = toString(conn)
    if (conn_str) in keys(table)
      count = table[conn_str]
      table[conn_str] = count + 1
    else
      table[conn_str] = 1
    end
  return table
end

function evaluateCardinality(@nospecialize(arg), table::Table)
  local count::Int
  local argStr = toString(arg)
  count = if argStr in keys(table)
    table[argStr]
  else
    0
  end
  return INTEGER_EXPRESSION(count)
end

"""
  Prints the table
"""
function print(table::Table)
  for p in table
    println(first(table) * ":"  * string(last(p)))
  end
end

@exportAll()
end

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

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

@UniontypeDecl NFConnection
const Connection = NFConnection

function toString(conn::Connection)::String
  local str::String
  @assign str =
    "connect(" +
    #=Connector.=#toString(conn.lhs) +
    ", " +
    #=Connector.=#toString(conn.rhs) +
    ")"
  return str
end

function Base.string(conn::Connection)::String
  local str::String
  @assign str =
    "connect(" +
    #=Connector.=#toString(conn.lhs) +
    ", " +
    #=Connector.=#toString(conn.rhs) +
    ")"
  return str
end


@Uniontype NFConnection begin
  @Record CONNECTION begin
    #=  TODO: This should be Connector, but the import above doesn't work due to some compiler bug.=#
    lhs::NFConnector
    rhs::NFConnector
  end
end

"""
  Split function for a connection.
   Given a connection split and return a List{Connection}
"""
function split(connection::CONNECTION)::List
  local connectionLstRight = split(connection.rhs)
  local connectionLstLeft = split(connection.lhs)
  if listLength(connectionLstLeft) != listLength(connectionLstRight)
    local str = "\nLeft:\n"
    for lL in connectionLstLeft
      str *= toString(lL) * "\n"
    end
    str =  str * "\nRight:\n"
    for lR in connectionLstRight
      str *= toString(lR) * "\n"
    end
    @info str

    Error.assertion(false, getInstanceName() + " got unbalanced connection " + toString(connection) + " (lhs: " +
      string(listLength(connectionLstLeft)) + ", rhs: " + string(listLength(connectionLstRight)) + ")", sourceInfo());

    fail();
  end
  local conns = nil
  for cl in connectionLstLeft
    cr = listHead(connectionLstRight)
    connectionLstRight = listRest(connectionLstRight)
    # Connections involving deleted conditional connectors are filtered out
    # when collecting the connections, but if the connectors themselves
    # contain connectors that have been deleted we need to remove them here.
    if ! (isDeleted(cl) || isDeleted(cr))
      conns = CONNECTION(cl, cr) <| conns;
    end
  end
  conns = listReverseInPlace(conns);
  return conns
end

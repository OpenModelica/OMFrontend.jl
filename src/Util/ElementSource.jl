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

module ElementSource

import ..DAE
import ..ListUtil
using MetaModelica

"""
Constructs the element source.
TODO:
Currently a dummy impl
"""
function createElementSource(i)
  return DAE.emptyElementSource
end

"""
Merges two element sources into one.
Combines the connectEquationOptLst fields from both sources and keeps
all other fields from source1. This is sufficient for the connector
equation generation use cases in NFConnectEquations.
"""
function mergeSources(source1::DAE.ElementSource, source2::DAE.ElementSource)::DAE.ElementSource
  @match (source1, source2) begin
    (DAE.SOURCE(info = info,
                partOfLst = partOfLst,
                instance = instance,
                connectEquationOptLst = connects1,
                typeLst = typeLst,
                operations = operations,
                comment = comment),
     DAE.SOURCE(connectEquationOptLst = connects2)) => begin
      DAE.SOURCE(
        info,
        partOfLst,
        instance,
        listAppend(connects1, connects2),
        typeLst,
        operations,
        comment,
      )
    end
  end
end

end #= ElementSource =#

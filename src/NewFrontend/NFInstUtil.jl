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

module InstUtil

import ..Frontend.Expression
import ..Frontend.FlatModel
import ..Frontend.map

using ..Frontend
using MetaModelica

"""
```
restoreMissingArrayVariables!(flatModel::FlatModel)
```
  Some variables are never defined in the flat model.
  They can appear everywhere as expressions,
  the easiest case is where these variables occur as
  lhs = rhs, but they may also appear in binary expressions etc.
    The easiest way to deal with the is to create one variable
    for each cref of an array type where the parent cref is not a record.

  Each of these variables can be assumed to have been scalarized previously.
  Hence, we know the size and the component of the particular vector.
  For each such array variable appearing in an equation
  we create the variable and an additional equation.
If the NF_SCALARIZE flag is set to false the function will do nothing.
"""
function restoreMissingArrayVariables!(flatModel::FlatModel)
  local arrayVariableSet = Dict{String, ComponentRef}()
  if Flags.isSet(Flags.NF_SCALARIZE)
    function collectArrayVariable2(exp::Expression)
      local outExp = @match exp begin
        CREF_EXPRESSION(ty, cref) where {ty isa TYPE_ARRAY && !(isvariant(cref, COMPONENT_REF_WILD))} =>  begin
          local parentCref = cref.restCref
          local parentIsRecord = isRecord(getComponentType(parentCref))
          if !(parentIsRecord)
            arrayVariableSet[toFlatString(cref)] = cref
          end
          (expArr, _) = expand(exp)
          expArr
        end
        _ => begin
          exp
        end
      end
      return outExp
    end

    function collectArrayVariable(e::Expression)
      exp = map(e, collectArrayVariable2)
      return exp
    end
    #=
    Traverse all expressions in the array equations to find component references of type array
    =#
    mapExpList!(flatModel.initialEquations, collectArrayVariable)
    mapExpList!(flatModel.equations, collectArrayVariable)
    newVars = VARIABLE[]
    for v in values(arrayVariableSet)
      push!(newVars, Variable_fromCrefNoBinding(v))
    end
    #append!(flatModel.variables, newVars)
   end
end

function adjustIncorrectVariablePaths!(flat_model)
  #= Get all variables =#
  local variables = flat_model.variables
  #=
  Get all component references in the model.
  =#

end


end #= InstUtil =#

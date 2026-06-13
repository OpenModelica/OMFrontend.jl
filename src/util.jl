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

"""
Per-phase timing gate for `@EXECSTAT`. Initialized from
`ENV["ENABLE_EXECSTAT"]` at module load; flip at runtime via
`OMFrontend.ENABLE_EXECSTAT[] = true / false` to avoid a Julia restart.
"""
const ENABLE_EXECSTAT = Ref{Bool}(get(ENV, "ENABLE_EXECSTAT", "false") == "true")

"""
    @EXECSTAT "label" expr

Wraps `expr` in `@time` when `ENABLE_EXECSTAT[]` is true; otherwise the
expression is evaluated with no instrumentation. The runtime check costs
one boolean load and one branch per call site, so use it on coarse phase
boundaries, not in tight inner loops.
"""
macro EXECSTAT(msg, expr)
  return quote
    if $(ENABLE_EXECSTAT)[]
      @time $(esc(msg)) __result = $(esc(expr))
      __result
    else
      $(esc(expr))
    end
  end
end

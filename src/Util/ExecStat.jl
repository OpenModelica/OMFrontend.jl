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

module ExecStat

using MetaModelica
using ExportAll

import ..System
import ..Flags

global startTime::Float64 = time()
global memoryInBytes::Int = 0
global const MODELICA_GC_NUM = Base.gc_num()

"""
Reset only the wall-time baseline used by `execStat` so the next `execStat`
call reports time relative to now, not relative to module load. Cheap, no
allocation.
"""
function execStatResetTimer()
  global startTime
  startTime = time()
  return nothing
end

"""
Prints an execution stat on the format:
  Execstat <name> -> time: <seconds>s, alloc'd: <bytes> bytes (cumulative)
where `time` is the wall time since the last `execStat` call (the timer is
reset per call so successive entries give per-phase wall time), and `alloc'd`
is the cumulative allocated bytes since module load (a running total — the
GC baseline `MODELICA_GC_NUM` is captured at module load and is `const`, so
we cannot reset it per-call without further changes).

No-op when `Flags.EXEC_STAT` is not set.
"""
function execStat(name::String)
  if !Flags.isSet(Flags.EXEC_STAT)
    return
  end
  global startTime
  local now = time()
  local elapsed = now - startTime
  startTime = now
  local diff = Base.GC_Diff(Base.gc_num(), MODELICA_GC_NUM)
  println("Execstat ", name,
          " -> time: ", round(elapsed; digits = 4), "s",
          ", alloc'd: ", Int(diff.allocd), " bytes (cumulative)")
  return
end

@exportAll()
end

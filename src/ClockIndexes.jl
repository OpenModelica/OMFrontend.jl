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

module ClockIndexes

using MetaModelica
using ExportAll

const RT_CLOCK_SIMULATE_TOTAL = 8::Int

const RT_CLOCK_SIMULATE_SIMULATION = 9::Int

const RT_CLOCK_BUILD_MODEL = 10::Int

const RT_CLOCK_EXECSTAT = 11::Int

const RT_CLOCK_EXECSTAT_CUMULATIVE = 12::Int

const RT_CLOCK_FRONTEND = 13::Int

const RT_CLOCK_BACKEND = 14::Int

const RT_CLOCK_SIMCODE = 15::Int

const RT_CLOCK_LINEARIZE = 16::Int

const RT_CLOCK_TEMPLATES = 17::Int

const RT_CLOCK_UNCERTAINTIES = 18::Int

const RT_PROFILER0 = 19::Int

const RT_PROFILER1 = 20::Int

const RT_PROFILER2 = 21::Int

const RT_CLOCK_EXECSTAT_JACOBIANS = 22::Int

const RT_CLOCK_USER_RESERVED = 23::Int

const RT_CLOCK_EXECSTAT_HPCOM_MODULES = 24::Int

const RT_CLOCK_SHOW_STATEMENT = 25::Int

const RT_CLOCK_FINST = 26::Int

const buildModelClocks =
  list(
    RT_CLOCK_BUILD_MODEL,
    RT_CLOCK_SIMULATE_TOTAL,
    RT_CLOCK_TEMPLATES,
    RT_CLOCK_LINEARIZE,
    RT_CLOCK_SIMCODE,
    RT_CLOCK_BACKEND,
    RT_CLOCK_FRONTEND,
  )::List

@exportAll()
end

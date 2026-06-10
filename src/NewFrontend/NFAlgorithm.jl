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

abstract type NFAlgorithm end

mutable struct ALGORITHM <: NFAlgorithm
    statements::Vector{Statement}
    source::DAE.ElementSource
end

function toString(alg::ALGORITHM)::String
  local str::String
  @assign str = toStringList(alg.statements)
  return str
end

function foldExpList(algs::Vector{Algorithm}, func::FoldFunc, arg::ArgT) where {ArgT}
  for alg in algs
    arg = foldExp(alg, func, arg)
  end
  return arg
end

function foldExp(alg::ALGORITHM, func::FoldFunc, arg::ArgT) where {ArgT}
  for s in alg.statements
    arg = foldExp(s, func, arg)
  end
  return arg
end

"""
Declare with! to keep with the idioms of Julia.
"""
function mapExpList(algs::Vector{Algorithm}, func::MapFunc)
  local f = @closure (alg) -> mapExp(alg, func)
  local mAlgs::Vector{Algorithm} = map!(f, algs, algs)
  return mAlgs
end

@nospecialized function mapExp(alg::ALGORITHM, func::MapFunc)::Algorithm
  #alg.statements = mapExpList(alg.statements, func)
  for (i,s) in enumerate(alg.statements)
    alg.statements[i] = mapExp(s, func)
  end
  return alg
end

function apply(alg::ALGORITHM, func::ApplyFn)
  for s in alg.statements
    Statement.apply(s, func)
  end
end

function applyList(algs::Vector{Algorithm}, func::ApplyFn)
  return for alg in algs
    for s in alg.statements
      Statement.apply(s, func)
    end
  end
end

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
  mapPreservingEq(arr::Vector{T}, f) -> Vector{T}

Map `f` over each element of `arr`. If `f` returns the same reference for
every element (`referenceEq`), return the original `arr` without allocating.
Otherwise lazily copy the array on the first changed element and write
mapped elements into the copy.
"""
@inline function mapPreservingEq(arr::Vector{T}, f::F) where {T, F}
  newArr = arr
  for i in eachindex(arr)
    orig = arr[i]
    mapped = f(orig)::T
    if !referenceEq(orig, mapped)
      if newArr === arr
        newArr = copy(arr)
      end
      newArr[i] = mapped
    end
  end
  return newArr
end

"""
  reuseIfRefEqual(unchanged, orig, new, makeNew)

If `orig` and `new` are the same reference, return `unchanged` (typically the
outer/parent value). Otherwise call `makeNew(new)` to construct a fresh
wrapper. Eliminates the wrapper allocation when the sub-expression was
unchanged.

No type constraints on the arguments: traversal functions over abstract
unions (e.g. `map(::Expression, ...)`) commonly return a different concrete
subtype than the input, and the wrapper produced by `makeNew` may also use a
different parameterisation than `unchanged`. The identity check
(`referenceEq`) is by pointer and does not require type equality. Callers
sit inside an `@match` arm whose enclosing block coerces the union return
to a concrete type.
"""
@inline function reuseIfRefEqual(unchanged, orig, new, makeNew::F) where {F}
  referenceEq(orig, new) ? unchanged : makeNew(new)
end

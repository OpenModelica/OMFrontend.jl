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

"""TODO: Merge this file with the others.."""
function typeMatrixCommaRef(
  elements::Vector{Expression},
  origin::ORIGIN_Type,
  info::SourceInfo,
  arrayTypeRef::Ref{NFType},
  variabilityTypeRef::Ref{VariabilityType})
  local variability::VariabilityType = Variability.CONSTANT
  local arrayType::NFType
  local arrayExp::Expression
  local exp::Expression
  local expl::Vector{Expression} = Vector{Expression}(undef, length(elements))
  local res::Vector{Expression} = Vector{Expression}(undef, length(elements))
  local var::VariabilityType
  local ty::NFType = TYPE_UNKNOWN()
  local ty1::NFType
  local ty2::NFType
  local ty3::NFType
  local tys::List{NFType} = nil
  local tys2::Vector{NFType} = Vector{NFType}(undef, length(elements))
  local n::Int = 2
  local pos::Int
  local mk::MatchKindType
  @assert !isempty(elements)
  if length(elements) > 1
    local varTyRef = Ref{VariabilityType}(Variability.CONSTANT)
    local refMatchKind = Ref{MatchKindType}(MatchKind.NOT_COMPATIBLE)
    local tyRef = Ref{NFType}(TYPE_UNKNOWN())
    for (i,e) in enumerate(elements)
      exp = typeExp2(e, origin, info, tyRef, varTyRef)
      ty1 = tyRef.x
      var = varTyRef.x
      expl[i] = exp
      if isEqual(ty, TYPE_UNKNOWN())
         ty = ty1
      else
         (_, _, ty2, mk) = matchExpressions(
           INTEGER_EXPRESSION_0,
           arrayElementType(ty1),
           INTEGER_EXPRESSION_0,
           arrayElementType(ty),
         )
        if isCompatibleMatch(mk)
           ty = ty2
        end
      end
       tys2[i] = ty1
       variability = variabilityMax(variability, var)
       n = max(n, dimensionCount(ty))
    end
    #= Each element with its own type (as typeMatrixComma; the reversed list had paired them
       wrongly, an Integer left in a Real matrix). =#
    pos = n + 1
    local i = 1
    for e in expl
      ty1 = tys2[i]
       pos = pos - 1
      if dimensionCount(ty1) != n
         (e, ty1) = promote(e, ty1, n)
      end
       ty2 = setArrayElementType(ty1, ty)
      e = matchTypesRef(ty1, ty2, e, tyRef, refMatchKind)
      ty3 = tyRef.x
      mk = refMatchKind.x
      if isIncompatibleMatch(mk)
        Error.addSourceMessageAndFail(
          Error.ARG_TYPE_MISMATCH,
          list(
            String(pos),
            "matrix constructor ",
            "arg",
            toString(e),
            toString(ty1),
            toString(ty2),
          ),
          info,
        )
      end
      res[i] = e
      tys2[i] = ty3
      i += 1
    end
    (arrayExp, arrayType) = makeCatExp(2, res, tys2, variability, info)
  else
    local varTyRef = Ref{VariabilityType}(Variability.CONSTANT)
    local tyRef = Ref{NFType}(TYPE_UNKNOWN())
    arrayExp = typeExp2(elements[1], origin, info, tyRef, varTyRef)
    arrayType = tyRef.x
    variability = varTyRef.x
  end
  variabilityTypeRef.x = variability
  arrayTypeRef.x = arrayType
  return arrayExp
end

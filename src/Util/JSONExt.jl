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

module JSONExt

using MetaModelica
using ExportAll

"""
  @author: adrpo
  this function will serialize anything you give it in JSON format
  and will filter out any with the names given in the filter
"""
function serialize(any::T, filter::List{String}) where {T}
  local s::String = ""

  local name::String
  local components::List{String}
  local lst::List{String}
  local no::Int = 1

  if isInteger(any)
    @assign s = intString(getInteger(any))
    return s
  end
  if isReal(any)
    @assign s = realString(getReal(any))
    return s
  end
  if isString(any)
    @assign s = "\\" + getString(any) + "\\"
    return s
  end
  if isRecord(any)
    @assign components = getRecordNames(any)
    @match _cons(name, components) = components
    @assign s = "{\\" + name + "\\:{"
    @assign no = 1
    @assign lst = nil
    for c in components
      if !listMember(c, filter)
        @assign lst =
          _cons("\\" + c + "\\:" + serialize(getRecordComponent(any, no), filter), lst)
      end
      @assign no = no + 1
    end
    @assign lst = listReverse(lst)
    @assign s = s + stringDelimitList(lst, ",") + "}}"
    return s
  end
  #=  get the records and the component names
  =#
  #=  if is not in the filter output it
  =#
  if isNil(any)
    @assign s = "[]"
    return s
  end
  if isCons(any)
    @assign s = s + "["
    @assign no = 1
    @assign lst = nil
    for c in getList(any)
      @assign lst = _cons(serialize(c, filter), lst)
    end
    @assign lst = listReverse(lst)
    @assign s = s + stringDelimitList(lst, ",") + "]"
    return s
  end
  if isNONE(any)
    @assign s = s + "[]"
    return s
  end
  if isSOME(any)
    @assign s = s + "[" + serialize(getSome(any), filter) + "]"
    return s
  end
  if isTuple(any)
    @assign s = s + "{\\Tuple\\:{"
    @assign no = 1
    @assign lst = nil
    for i = 1:getTupleSize(any)
      @assign lst =
        _cons("\\" + intString(i) + "\\:" + serialize(getListElement(any, no), filter), lst)
    end
    @assign lst = listReverse(lst)
    @assign s = s + stringDelimitList(lst, ",") + "}} "
    return s
  end
  @assign s = "UNKNOWN(" + anyString(any) + ")"
  return s
end

function isInteger(any::T) where {T}
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function isReal(any::T) where {T}
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function isString(any::T) where {T}
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function isArray(any::T) where {T}
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function isRecord(any::T) where {T}
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function isTuple(any::T) where {T}
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function isNONE(any::T) where {T}
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function isSOME(any::T) where {T}
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function isNil(any::T) where {T}
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function isCons(any::T) where {T}
  local b::Bool

  @error "TODO: Defined in the runtime"
  return b
end

function getRecordNames(any::T) where {T}
  local nameAndComponentsNames::List{String} = listReverse(getRecordNamesHelper(any))
  return nameAndComponentsNames
end

function getRecordNamesHelper(any::T) where {T}
  local nameAndComponentsNames::List{String}

  @error "TODO: Defined in the runtime"
  return nameAndComponentsNames
end

function getRecordComponent(iany::TIN, offset::Int) where {TIN, TOUT}
  local oany::TOUT

  @error "TODO: Defined in the runtime"
  return oany
end

function getInteger(a::T) where {T}
  local i::Int

  @error "TODO: Defined in the runtime"
  return i
end

function getReal(a::T) where {T}
  local r::AbstractFloat

  @error "TODO: Defined in the runtime"
  return r
end

function getString(a::T) where {T}
  local s::String

  @error "TODO: Defined in the runtime"
  return s
end

function getSome(a::TIN) where {TIN, TOUT}
  local o::TOUT

  @error "TODO: Defined in the runtime"
  return o
end

function getTupleSize(any::T) where {T}
  local sz::Int

  @error "TODO: Defined in the runtime"
  return sz
end

function getList(iany::TIN) where {TIN, TOUT}
  local oany::List{TOUT}

  @error "TODO: Defined in the runtime"
  return oany
end

function getListElement(iany::TIN, offset::Int) where {TIN, TOUT}
  local oany::TOUT

  @error "TODO: Defined in the runtime"
  return oany
end

@exportAll()
end

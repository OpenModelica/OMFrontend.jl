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

const VariabilityType = Int8

abstract type Binding end

@enum BindingTag::UInt8 BT_INVALID BT_CEVAL BT_FLAT BT_TYPED BT_UNTYPED BT_RAW BT_UNBOUND BT_ERROR

mutable struct BindingImpl <: Binding
  tag::BindingTag
  binding::Union{Binding,Nothing}
  errors::Union{List,Nothing}
  bindingExp::Union{Expression,Absyn.Exp,Nothing}
  bindingType::Union{NFType,Nothing}
  variability::VariabilityType
  eachType::Int
  evaluated::Bool
  isFlattened::Bool
  isProcessing::Bool
  scope::Union{InstNode,Nothing}
  parents::Union{List{InstNode},Nothing}
  isEach::Bool
  info::Union{SourceInfo,Nothing}
end

@inline _binding(tag::BindingTag; binding=nothing, errors=nothing, bindingExp=nothing,
  bindingType=nothing, variability::VariabilityType=Int8(0), eachType::Int=0,
  evaluated::Bool=false, isFlattened::Bool=false, isProcessing::Bool=false,
  scope=nothing, parents=nothing, isEach::Bool=false, info=nothing) =
  BindingImpl(tag, binding, errors, bindingExp, bindingType, variability, eachType,
    evaluated, isFlattened, isProcessing, scope, parents, isEach, info)

INVALID_BINDING(binding, errors) = _binding(BT_INVALID; binding, errors)
CEVAL_BINDING(bindingExp) = _binding(BT_CEVAL; bindingExp)
FLAT_BINDING(bindingExp, variability) =
  _binding(BT_FLAT; bindingExp, variability=Int8(variability))
TYPED_BINDING(bindingExp, bindingType, variability, eachType, evaluated, isFlattened, info) =
  _binding(BT_TYPED; bindingExp, bindingType, variability=Int8(variability),
    eachType=Int(eachType), evaluated, isFlattened, info)
UNTYPED_BINDING(bindingExp, isProcessing, scope, isEach, info) =
  _binding(BT_UNTYPED; bindingExp, isProcessing, scope, isEach, info)
RAW_BINDING(bindingExp, scope, parents, isEach, info) =
  _binding(BT_RAW; bindingExp, scope, parents, isEach, info)
UNBOUND(parents, isEach, info) = _binding(BT_UNBOUND; parents, isEach, info)
BINDING_ERROR() = _binding(BT_ERROR)

MetaModelica.compacted_tag_info(::typeof(INVALID_BINDING)) = (BindingImpl, :tag, BT_INVALID, (:binding, :errors))
MetaModelica.compacted_tag_info(::typeof(CEVAL_BINDING)) = (BindingImpl, :tag, BT_CEVAL, (:bindingExp,))
MetaModelica.compacted_tag_info(::typeof(FLAT_BINDING)) = (BindingImpl, :tag, BT_FLAT, (:bindingExp, :variability))
MetaModelica.compacted_tag_info(::typeof(TYPED_BINDING)) = (BindingImpl, :tag, BT_TYPED, (:bindingExp, :bindingType, :variability, :eachType, :evaluated, :isFlattened, :info))
MetaModelica.compacted_tag_info(::typeof(UNTYPED_BINDING)) = (BindingImpl, :tag, BT_UNTYPED, (:bindingExp, :isProcessing, :scope, :isEach, :info))
MetaModelica.compacted_tag_info(::typeof(RAW_BINDING)) = (BindingImpl, :tag, BT_RAW, (:bindingExp, :scope, :parents, :isEach, :info))
MetaModelica.compacted_tag_info(::typeof(UNBOUND)) = (BindingImpl, :tag, BT_UNBOUND, (:parents, :isEach, :info))
MetaModelica.compacted_tag_info(::typeof(BINDING_ERROR)) = (BindingImpl, :tag, BT_ERROR, ())

MetaModelica.valueConstructor(v::BindingImpl) = Int(v.tag)

const EMPTY_BINDING::Binding = UNBOUND(nil, false, AbsynUtil.dummyInfo)

struct EachTypeStruct{T <: Int}
  NOT_EACH::T
  EACH::T
  REPEAT::T
end

const EachTypeType = Int
const EachType::EachTypeStruct{Int} = EachTypeStruct{Int}(1,2,3)

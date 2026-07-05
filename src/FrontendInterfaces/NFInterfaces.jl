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

@UniontypeDecl Attributes
@UniontypeDecl Binding
@UniontypeDecl Branch
@UniontypeDecl CachedData
@UniontypeDecl Call
@UniontypeDecl CallAttributes
@UniontypeDecl Class
@UniontypeDecl ClassTree
@UniontypeDecl ClockKind
@UniontypeDecl Component
@UniontypeDecl Entry
@UniontypeDecl Entry
@UniontypeDecl EvalTarget
@UniontypeDecl Field
@UniontypeDecl FunctionMatchKind
@UniontypeDecl Functionargs
@UniontypeDecl InstNode
@UniontypeDecl LookupState
@UniontypeDecl LookupStateName
@UniontypeDecl M_Function
@UniontypeDecl MatchedFunction
@UniontypeDecl Modifier
@UniontypeDecl ModifierScope
@UniontypeDecl NFAlgorithm
@UniontypeDecl NFComplexType
@UniontypeDecl NFComponentRef
@UniontypeDecl NFConnection
@UniontypeDecl NFConnections
@UniontypeDecl NFConnector
@UniontypeDecl NFDimension
@UniontypeDecl NFEquation
@UniontypeDecl NFExpandExp
@UniontypeDecl NFExpression
@UniontypeDecl NFExpressionIterator
@UniontypeDecl NFFlatModel
@UniontypeDecl NFFunctionDerivative
@UniontypeDecl NFImport
@UniontypeDecl NFOCConnectionGraph
@UniontypeDecl NFOperator
@UniontypeDecl NFRangeIterator
@UniontypeDecl NFRestriction
@UniontypeDecl NFSections
@UniontypeDecl NFStatement
@UniontypeDecl NFSubscript
#= NFType is a single concrete tagged struct (see NFType.jl for constructors /
   @match registrations / methods). Defined here at the forward-declaration site
   so `::NFType`/`::M_Type`-annotated fields in files loaded before NFType.jl are
   concrete. Uses the raw interface type names (aliases like ComplexType/Dimension
   are not bound yet at this point). =#
@enum NFTypeTag::UInt8 NFT_INTEGER NFT_REAL NFT_STRING NFT_BOOLEAN NFT_CLOCK NFT_UNKNOWN NFT_ANY NFT_NORETCALL NFT_ENUMERATION_ANY NFT_ARRAY NFT_TUPLE NFT_COMPLEX NFT_FUNCTION NFT_ENUMERATION NFT_METABOXED NFT_POLYMORPHIC NFT_SUBSCRIPTED
struct NFType
  tag::NFTypeTag
  name::Union{String,Nothing}
  ty::Union{NFType,Nothing}
  subs::List{NFType}
  subscriptedTy::Union{NFType,Nothing}
  fn::Union{M_Function,Nothing}
  fnType::Int
  cls::Union{InstNode,Nothing}
  complexTy::Union{NFComplexType,Nothing}
  types::List{NFType}
  names::Option{List{String}}
  elementType::Union{NFType,Nothing}
  dimensions::List{NFDimension}
  typePath::Union{Absyn.Path,Nothing}
  literals::List{String}
end
@UniontypeDecl NFVariable
@UniontypeDecl NFVerifyModel
@UniontypeDecl Prefixes
@UniontypeDecl Replaceable
@UniontypeDecl Slot
@UniontypeDecl Token
@UniontypeDecl TypingError
@UniontypeDecl Unit
@UniontypeDecl VariableConversionSettings

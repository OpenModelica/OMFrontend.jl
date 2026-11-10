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
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GNU AGPL VERSION 3,
* ACCORDING TO RECIPIENTS CHOICE.
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

#=
 This file is needed to provide a necessary interface for Prefix.jl
=#
const Dimensions = List  #= a list of dimensions =#
const InstDims = List  #= instance dimensions: list<Dimension> =#
@UniontypeDecl VarKind
@UniontypeDecl ConnectorType
@UniontypeDecl VarDirection
@UniontypeDecl VarParallelism
@UniontypeDecl VarVisibility
@UniontypeDecl VarInnerOuter
@UniontypeDecl ElementSource
@UniontypeDecl SymbolicOperation
@UniontypeDecl EquationExp
@UniontypeDecl Element
@UniontypeDecl Function
@UniontypeDecl InlineType
@UniontypeDecl FunctionDefinition
@UniontypeDecl derivativeCond
@UniontypeDecl VariableAttributes
@UniontypeDecl StateSelect
@UniontypeDecl Uncertainty
@UniontypeDecl Distribution
@UniontypeDecl ExtArg
@UniontypeDecl ExternalDecl
@UniontypeDecl DAElist
@UniontypeDecl Algorithm
@UniontypeDecl Constraint
@UniontypeDecl ClassAttributes
@UniontypeDecl Statement
@UniontypeDecl Else
@UniontypeDecl Var
@UniontypeDecl Attributes
@UniontypeDecl BindingSource
@UniontypeDecl Binding
@UniontypeDecl Type
@UniontypeDecl CodeType
@UniontypeDecl EvaluateSingletonType
EvaluateSingletonTypeFunction = Function
@UniontypeDecl FunctionAttributes
@UniontypeDecl FunctionBuiltin
@UniontypeDecl FunctionParallelism
@UniontypeDecl Dimension
@UniontypeDecl DimensionBinding
@UniontypeDecl FuncArg
@UniontypeDecl Const
@UniontypeDecl TupleConst
@UniontypeDecl Properties
@UniontypeDecl EqMod
@UniontypeDecl SubMod
@UniontypeDecl Mod
@UniontypeDecl ClockKind
@UniontypeDecl Exp
@UniontypeDecl TailCall
@UniontypeDecl CallAttributes
@UniontypeDecl ReductionInfo
@UniontypeDecl ReductionIterator
@UniontypeDecl MatchCase
@UniontypeDecl MatchType
@UniontypeDecl Pattern
@UniontypeDecl Operator
@UniontypeDecl ComponentRef
@UniontypeDecl Subscript
@UniontypeDecl Expand
@UniontypeDecl Face
@UniontypeDecl CConnectorType
@UniontypeDecl ConnectorElement
@UniontypeDecl SetTrieNode
@UniontypeDecl OuterConnect
@UniontypeDecl Sets
@UniontypeDecl CSet

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

#=
 Various type aliases in the NewFrontend
=#

const Algorithm = AlgorithmImpl
const ApplyFn = Function
const ApplyFunc = Function
const Call = CallImpl
const ComplexType = NFComplexType
const ComponentRef = NFComponentRef
const Connection = NFConnection
const Connections = NFConnections
const Connector = NFConnector
const ContainsPred = Function
const Dimension = DimensionImpl
const Equation = EquationImpl
const EquationBranch = EquationBranchImpl
const EvalFunc = Function
const ExpandExp = NFExpandExp
const Expression = NFExpression
const ExpressionIterator = NFExpressionIterator
const FlatModel = NFFlatModel
const FoldFunc = Function
const FuncT = Function
const FuncType = Function
const FunctionDerivative = NFFunctionDerivative
const Import = NFImport
const Binding = BindingImpl
const MapExpFn = Function
const MapFn = Function
const MapFunc = Function
const Modifier = ModifierImpl
const OCConnectionGraph = NFOCConnectionGraph
const Operator = NFOperator
const PredFn = Function
const RangeIterator = NFRangeIterator
const Restriction = NFRestriction
const Sections = NFSections
const Statement = StatementImpl
const Subscript = NFSubscript
const Type = NFType 
const Variable = NFVariable
const VerifyModel = NFVerifyModel
const NFExpressionIterator = ExpressionIterator
#= Type defined by the compiler =#
const M_Type = NFType

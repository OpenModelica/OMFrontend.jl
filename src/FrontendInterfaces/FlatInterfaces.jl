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

#= The types of the flat model and of connection handling. Loaded after NFPrefixes.jl, whose
   VisibilityType and ConnectorType.TYPE they use. =#

"""Whether a connector is connected from inside or outside its component: `FACE_INSIDE` or `FACE_OUTSIDE`."""
const Face = UInt8
"""A connector connected from inside its component (`a.c` in `connect(a.c, b.c)`)."""
const FACE_INSIDE::Face = 0x01
"""A connector of the model itself (`c` in `connect(c, a.c)`)."""
const FACE_OUTSIDE::Face = 0x02

"""
    CONNECTOR(name, ty, face, cty, source)

One side of a connection: the connector component `name` of type `ty`, connected from inside or outside its
component (`face`, a `Face` value), its connector type (`cty`: potential, flow, stream, ...; a `ConnectorType`
value), and the `source` of the connect equation.
"""
struct CONNECTOR
  name::ComponentRef
  ty::ModelicaType
  face::Face
  cty::ConnectorType.TYPE
  source::SourceInfo
end

"""
    CONNECTION(lhs, rhs)

A `connect(lhs, rhs)` equation: its two connectors.
"""
struct CONNECTION
  lhs::CONNECTOR
  rhs::CONNECTOR
end

"""
    BrokenEdge

A connection the overconstrained connection graph breaks: its two connector crefs and the equalityConstraint
equations that replace it.
"""
const BrokenEdge = Tuple{ComponentRef, ComponentRef, List{Equation}}

""" The connections the overconstrained connection graph breaks. """
const BrokenEdges = List{BrokenEdge}

"""
    CONNECTIONS(connections, flows, broken)

The connections of a model as flattening collects them: its `connect` equations, its flow connectors (`flows`),
and the connections the overconstrained connection graph breaks (`broken`, `BrokenEdge` tuples).
"""
struct CONNECTIONS
  connections::List{CONNECTION}
  flows::List{CONNECTOR}
  broken::BrokenEdges
end

"""
    VARIABLE(name, ty, binding, visibility, attributes, typeAttributes, comment, info)

A variable of the flat model: its flat name `name`, type `ty`, `binding`, `visibility` (a `Visibility` value), its
prefixes (`attributes`: variability, direction, ...), its type attributes as `(name, binding)` pairs (`start`,
`fixed`, `nominal`, ...), its `comment` and where it is declared (`info`).
"""
struct VARIABLE
  name::ComponentRef
  ty::ModelicaType
  binding::Binding
  visibility::VisibilityType
  attributes::Attributes
  typeAttributes::Vector{Tuple{String, Binding}}
  comment::Option{SCode.COMMENT}
  info::SourceInfo
end

"""
    FLAT_MODEL(name, variables, equations, initialEquations, algorithms, initialAlgorithms,
               structuralSubmodels, scodeProgram, comment)

The flat representation of a Modelica model, the frontend's output: its `variables`, `equations`,
`initialEquations`, `algorithms` and `initialAlgorithms`, and its `comment`.

The VSS Modelica extension (variable structure systems) adds `structuralSubmodels`, the flat models of the model's
structural submodels (with separate instantiation, one per top-level component), and `scodeProgram`, the class a
recompilation directive modifies (`SOME` for a model with recompilation directives).
"""
struct FLAT_MODEL
  name::String
  variables::Vector{VARIABLE}
  equations::Vector{Equation}
  initialEquations::Vector{Equation}
  algorithms::Vector{ALGORITHM}
  initialAlgorithms::Vector{ALGORITHM}
  structuralSubmodels::List{FLAT_MODEL}
  scodeProgram::Option{SCode.CLASS}
  comment::Option{SCode.COMMENT}
end

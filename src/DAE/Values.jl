
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

module Values

using MetaModelica
using ExportAll

@UniontypeDecl Value
@UniontypeDecl IntRealOp

import OMParser.Absyn

@Uniontype Value begin
  @Record INTEGER begin
    integer::ModelicaInteger
  end

  @Record REAL begin
    real::ModelicaReal
  end

  @Record STRING begin
    string::String
  end

  @Record BOOL begin
    boolean::Bool
  end

  @Record ENUM_LITERAL begin
    name::Absyn.Path
    index::ModelicaInteger
  end

  @Record ARRAY begin
    valueLst::List{Value}
    dimLst::List{ModelicaInteger}
  end

  @Record LIST begin
    valueLst::List{Value}
  end

  @Record META_ARRAY begin
    valueLst::List{Value}
  end

  @Record TUPLE begin
    valueLst::List{Value}
  end

  @Record META_TUPLE begin
    valueLst::List{Value}
  end

  @Record RECORD begin
    record_ #= record name =#::Absyn.Path
    orderd #= orderd set of values =#::List{Value}
    comp #= comp names for each value =#::List{String}
    index #= -1 for regular records, 0..n-1 for uniontypes containing n records =#::ModelicaInteger
  end

  @Record OPTION begin
    some::Option{Value}
  end

  @Record CODE begin
    A #= A record consist of value  Ident pairs =#::Absyn.CodeNode
  end

  @Record NORETCALL begin
  end

  @Record META_BOX begin
    value::Value
  end

  @Record META_FAIL begin
  end

  @Record EMPTY begin
    scope #= the scope where we could not find the binding =#::String
    name #= the name of the variable =#::String
    ty #= the DAE.Type translated to Value using defaults =#::Value
    tyStr #= the type of the variable =#::String
  end
end

@Uniontype IntRealOp begin
  @Record MULOP begin
  end

  @Record DIVOP begin
  end

  @Record ADDOP begin
  end

  @Record SUBOP begin
  end

  @Record POWOP begin
  end

  @Record LESSEQOP begin
  end
end

#= So that we can use wildcard imports and named imports when they do occur. Not good Julia practice =#
@exportAll()
end

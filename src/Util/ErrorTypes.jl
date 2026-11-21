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

module ErrorTypes

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
#= ExportAll is not good practice but it makes it so that we do not have to write export after each function :( =#
using ExportAll
import ..Gettext

@UniontypeDecl Severity
@UniontypeDecl MessageType
@UniontypeDecl Message
@UniontypeDecl TotalMessage

#= severity of message =#
@Uniontype Severity begin
  @Record INTERNAL begin
  end
  @Record ERROR begin
  end
  @Record WARNING begin
  end
  @Record NOTIFICATION begin
  end
end

#= runtime scripting /interpretation error =#
@Uniontype MessageType begin
  @Record SYNTAX begin
  end
  @Record GRAMMAR begin
  end
  @Record TRANSLATION begin
  end
  @Record SYMBOLIC begin
  end
  @Record SIMULATION begin
  end
  @Record SCRIPTING begin
  end
end

const ErrorID = ModelicaInteger  #= Unique error id. Used to
look up message string and type and severity =#

@Uniontype Message begin
  @Record MESSAGE begin
    id::ErrorID
    ty::MessageType
    severity::Severity
    message::Gettext.TranslatableContent
  end
end

@Uniontype TotalMessage begin
  @Record TOTALMESSAGE begin
    msg::Message
    info::SourceInfo
  end
end

const MessageTokens = List

@exportAll()

end # ErrorTypes

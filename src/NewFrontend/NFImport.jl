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

@UniontypeDecl NFImport
const Import = NFImport

@Uniontype NFImport begin
  @Record CONFLICTING_IMPORT begin
    imp1::Import
    imp2::Import
  end

  @Record RESOLVED_IMPORT begin
    node::InstNode
    info::SourceInfo
  end

  @Record UNRESOLVED_IMPORT begin
    imp::Absyn.Import
    scope::InstNode
    info::SourceInfo
  end
  @Record EMPTY_IMPORT begin
  end
end

function printImportError(imp1::Import, imp2::Import)
  local err_msg::ErrorTypes.Message
  Error.addSourceMessage(Error.ERROR_FROM_HERE, nil, Import_info(imp1))
  @assign err_msg = begin
    @match imp2 begin
      UNRESOLVED_IMPORT(__) => begin
        Error.MULTIPLE_QUALIFIED_IMPORTS_WITH_SAME_NAME
      end

      RESOLVED_IMPORT(__) => begin
        Error.IMPORT_SEVERAL_NAMES
      end
    end
  end
  return Error.addSourceMessage(err_msg, list(name(imp2)), info(imp2))
end

function instUnqualified(
  imp::Absyn.Import,
  scope::InstNode,
  info::SourceInfo,
  imps::List{<:Import} = nil,
)::List{Import}

  local path::Absyn.Path
  local node::InstNode
  local tree::ClassTree
  local elements::List{InstNode}

  @match Absyn.UNQUAL_IMPORT(path = path) = imp
  node = lookupImport(path, scope, info)
  node = instPackage(node)
  tree = classTree(getClass(node))
  #= Explicit isvariant: this file is included before NFClassTree.jl registers
     compacted_tag_info(CLASS_TREE_FLAT_TREE), so a `@match` pattern here expands
     to a plain `isa` (which fails on the compacted constructor function). =#
  if isvariant(tree, CLASS_TREE_FLAT_TREE)
    for cls in tree.classes
      imps = _cons(RESOLVED_IMPORT(cls, info), imps)
    end
    for comp in tree.components
      imps = _cons(RESOLVED_IMPORT(comp, info), imps)
    end
  else
    Error.assertion(false, getInstanceName() + " got invalid class tree", sourceInfo())
  end
  return imps
end

function instQualified(
  imp::Absyn.Import,
  scope::InstNode,
  info::SourceInfo,
)::Tuple{Import, InstNode}
  local node::InstNode
  local outImport::Import

  @assign node = begin
    @match imp begin
      Absyn.NAMED_IMPORT(__) => begin
        lookupImport(imp.path, scope, info)
      end

      Absyn.QUAL_IMPORT(__) => begin
        lookupImport(imp.path, scope, info)
      end
    end
  end
  @assign outImport = RESOLVED_IMPORT(node, info)
  return (outImport, node)
end

function resolve(imp::Import, isChangedImportRef::Ref{Bool}, importTyRef::Ref{Import})::InstNode
  local outImport::Import
  local changed::Bool
  local node::InstNode

  outImport  = begin
    @match imp begin
      UNRESOLVED_IMPORT(__) => begin
        (outImport, node) = instQualified(imp.imp, imp.scope, imp.info)
        isChangedImportRef.x = true
        importTyRef.x = outImport
      end

      RESOLVED_IMPORT(__) => begin
        isChangedImportRef.x = false
        node = imp.node
        importTyRef.x = imp
      end

      CONFLICTING_IMPORT(__) => begin
        printImportError(imp.imp1, imp.imp2)
        fail()
      end
    end
  end
  return node
end

function Import_info(imp::Import)::SourceInfo
  local info::SourceInfo
  info = begin
    @match imp begin
      UNRESOLVED_IMPORT(__) => begin
        imp.info
      end

      RESOLVED_IMPORT(__) => begin
        imp.info
      end
    end
  end
  return info
end

function name(imp::Import)::String
  local importName = begin
    @match imp begin
      UNRESOLVED_IMPORT(__) => begin
        AbsynUtil.importName(imp.imp)
      end
      RESOLVED_IMPORT(__) => begin
        name(imp.node)
      end
    end
  end::String
  return importName
end

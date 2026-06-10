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

module GUI_API

using MetaModelica

import ..Absyn
import ..SCode
import ..OMParser
import ..translateToSCode
import ..libraries
import ..loadInstalledLibrary
import ..installLibrary
import ..loadBundledMSL
import ..loadLibrary
import ..loadPackageDirectory
import ..LIBRARY_CACHE

export SourceSpan,
       TextPatch,
       ValidationResult,
       OperationResult,
       SaveResult,
       DiagramNode,
       DiagramConnection,
       DiagramModel,
       ModelSession,
       loadModel,
       getDiagram,
       updateComponentPlacement,
       createConnection,
       updateConnectionAnnotation,
       deleteConnection,
       saveModel,
       validateModel,
       setExecutionDelegates!,
       compileModel,
       simulateModel,
       exportFlatModelica,
       libraries,
       loadInstalledLibrary,
       installLibrary,
       loadBundledMSL,
       loadLibrary,
       loadPackageDirectory,
       LIBRARY_CACHE

const Point2D = Tuple{Float64, Float64}
const Extent2D = Tuple{Point2D, Point2D}
const Color3 = Tuple{Int, Int, Int}

"""
    SourceSpan

Byte offsets and one-based line/column positions for a source range.
"""
struct SourceSpan
  startOffset::Int
  endOffset::Int
  startLine::Int
  startColumn::Int
  endLine::Int
  endColumn::Int
end

"""
    TextPatch

Replacement text for a source range, expressed in byte offsets.
"""
struct TextPatch
  startOffset::Int
  endOffset::Int
  replacement::String
end

"""
    ValidationResult

Result of validating a loaded Modelica session.
"""
struct ValidationResult
  ok::Bool
  message::String
end

"""
    OperationResult

Result of a mutating diagram/model operation.
"""
struct OperationResult
  ok::Bool
  message::String
  resourceId::Union{Nothing, String}
end

"""
    SaveResult

Path and byte count returned after saving a model session.
"""
struct SaveResult
  path::String
  bytesWritten::Int
end

"""
    DiagramNode

Diagram or icon placement data for one component declaration.
"""
struct DiagramNode
  componentPath::String
  classPath::String
  typePath::String
  span::SourceSpan
  origin::Point2D
  extent::Extent2D
  rotation::Float64
  visible::Bool
  rawAnnotation::Union{Nothing, String}
end

"""
    DiagramConnection

Diagram connection data extracted from a `connect(...)` equation.
"""
struct DiagramConnection
  id::String
  classPath::String
  fromConnector::String
  toConnector::String
  span::SourceSpan
  points::Vector{Point2D}
  color::Union{Nothing, Color3}
  rawAnnotation::Union{Nothing, String}
end

"""
    DiagramModel

Coordinate system, component nodes, and connections for one class view.
"""
struct DiagramModel
  classPath::String
  view::Symbol
  coordinateSystem::Dict{String, Any}
  nodes::Vector{DiagramNode}
  connections::Vector{DiagramConnection}
end

struct ComponentIndex
  classPath::String
  componentPath::String
  typePath::String
  statementSpan::SourceSpan
  rawAnnotation::Union{Nothing, String}
  groupSize::Int
  diagramPlacement::Dict{String, Any}
  iconPlacement::Dict{String, Any}
end

struct ConnectionIndex
  id::String
  classPath::String
  fromConnector::String
  toConnector::String
  statementSpan::SourceSpan
  rawAnnotation::Union{Nothing, String}
  lineAnnotation::Dict{String, Any}
end

"""
    ModelSession

Parsed Modelica source plus indexes used by the GUI editing API.
"""
mutable struct ModelSession
  path::String
  sourceText::String
  lineOffsets::Vector{Int}
  absynProgram::Absyn.Program
  scodeProgram::SCode.Program
  classNodes::Dict{String, Absyn.Class}
  classSpans::Dict{String, SourceSpan}
  componentIndex::Dict{String, ComponentIndex}
  connectionIndex::Dict{String, ConnectionIndex}
  equationSections::Dict{String, Vector{SourceSpan}}
  lastValidation::ValidationResult
end

const COMPILE_DELEGATE = Ref{Any}(nothing)
const SIMULATE_DELEGATE = Ref{Any}(nothing)
const EXPORT_FM_DELEGATE = Ref{Any}(nothing)

"""
    setExecutionDelegates!(; compileModel = nothing, simulateModel = nothing, exportFlatModelica = nothing)

Register callbacks used by `compileModel`, `simulateModel`, and
`exportFlatModelica`. Each callback receives `(classPath, tempPath; kwargs...)`.
"""
function setExecutionDelegates!(;
                                compileModel = nothing,
                                simulateModel = nothing,
                                exportFlatModelica = nothing)
  if compileModel !== nothing
    COMPILE_DELEGATE[] = compileModel
  end
  if simulateModel !== nothing
    SIMULATE_DELEGATE[] = simulateModel
  end
  if exportFlatModelica !== nothing
    EXPORT_FM_DELEGATE[] = exportFlatModelica
  end
  return nothing
end

"""
    loadModel(path::String) -> ModelSession

Load, parse, and index a Modelica source file for GUI inspection and editing.
"""
function loadModel(path::String)::ModelSession
  sourceText = read(path, String)
  return _buildSession(path, sourceText)
end

"""
    validateModel(session::ModelSession, classPath::String) -> ValidationResult

Return the current validation result for `classPath` in a loaded session.
"""
function validateModel(session::ModelSession, classPath::String)::ValidationResult
  if !haskey(session.classNodes, classPath)
    return ValidationResult(false, "Class '$classPath' was not found in the loaded session.")
  end
  return session.lastValidation
end

"""
    getDiagram(session::ModelSession, classPath::String; view = :Diagram) -> DiagramModel

Extract component placements and connections for the requested class view.
Use `view = :Icon` to read icon placements instead of diagram placements.
"""
function getDiagram(session::ModelSession,
                    classPath::String;
                    view::Symbol = :Diagram)::DiagramModel
  if !haskey(session.classNodes, classPath)
    error("Class '$classPath' was not found in the current session.")
  end
  class_ = session.classNodes[classPath]
  coordinateSystem = _extractCoordinateSystem(class_, view)

  nodes = DiagramNode[]
  for entry in values(session.componentIndex)
    if entry.classPath != classPath
      continue
    end
    placement = view == :Icon ? entry.iconPlacement : entry.diagramPlacement
    push!(nodes,
          DiagramNode(entry.componentPath,
                      classPath,
                      entry.typePath,
                      entry.statementSpan,
                      _displayOrigin(placement),
                      placement["extent"],
                      placement["rotation"],
                      placement["visible"],
                      entry.rawAnnotation))
  end
  sort!(nodes, by = node -> node.span.startOffset)

  connections = DiagramConnection[]
  for entry in values(session.connectionIndex)
    if entry.classPath != classPath
      continue
    end
    points = copy(entry.lineAnnotation["points"])
    color = entry.lineAnnotation["color"]
    push!(connections,
          DiagramConnection(entry.id,
                            classPath,
                            entry.fromConnector,
                            entry.toConnector,
                            entry.statementSpan,
                            points,
                            color,
                            entry.rawAnnotation))
  end
  sort!(connections, by = conn -> conn.span.startOffset)

  return DiagramModel(classPath, view, coordinateSystem, nodes, connections)
end

"""
    updateComponentPlacement(session::ModelSession, componentPath::String, placementPatch) -> OperationResult

Merge `placementPatch` into a component's `Placement` annotation and update the
session source text.
"""
function updateComponentPlacement(session::ModelSession,
                                  componentPath::String,
                                  placementPatch)::OperationResult
  resolvedPath = _resolveComponentPath(session, componentPath)
  entry = session.componentIndex[resolvedPath]
  if entry.groupSize != 1
    return OperationResult(false,
                           "Component '$resolvedPath' belongs to a grouped declaration and is not editable in GUI_API v1.",
                           nothing)
  end

  merged = _mergePatch(entry.diagramPlacement, placementPatch)
  statementText = _slice(session.sourceText, entry.statementSpan)
  replacement = _upsertNamedAnnotation(statementText,
                                       "Placement",
                                       _renderPlacement(merged))
  patch = TextPatch(entry.statementSpan.startOffset, entry.statementSpan.endOffset, replacement)

  return _applyEdit!(session,
                     [patch],
                     "Updated placement for '$resolvedPath'.")
end

"""
    createConnection(session::ModelSession, fromConnector::String, toConnector::String; classPath = nothing, linePatch = nothing) -> OperationResult

Insert a `connect(...)` equation and optional `Line` annotation into the owning
class.
"""
function createConnection(session::ModelSession,
                          fromConnector::String,
                          toConnector::String;
                          classPath::Union{Nothing, String} = nothing,
                          linePatch = nothing)::OperationResult
  resolvedClass = _resolveConnectionClassPath(session, fromConnector, toConnector, classPath)
  fromLocal = _localConnectorRef(fromConnector, resolvedClass)
  toLocal = _localConnectorRef(toConnector, resolvedClass)

  lineAnnotation = _defaultLine()
  lineAnnotation["points"] = _defaultConnectionPoints(session, resolvedClass, fromLocal, toLocal)
  if linePatch !== nothing
    lineAnnotation = _mergePatch(lineAnnotation, linePatch)
  end

  statementText = _renderConnectStatement(fromLocal, toLocal, lineAnnotation)
  insertPatch = _buildConnectionInsertPatch(session, resolvedClass, statementText)
  result = _applyEdit!(session,
                       [insertPatch],
                       "Created connection '$fromLocal -> $toLocal'.")

  if result.ok
    newId = _findConnectionId(session, resolvedClass, fromLocal, toLocal)
    return OperationResult(true, result.message, newId)
  end

  return result
end

"""
    updateConnectionAnnotation(session::ModelSession, connectionId::String, linePatch) -> OperationResult

Merge `linePatch` into an existing connection's `Line` annotation.
"""
function updateConnectionAnnotation(session::ModelSession,
                                    connectionId::String,
                                    linePatch)::OperationResult
  if !haskey(session.connectionIndex, connectionId)
    return OperationResult(false, "Connection '$connectionId' was not found.", nothing)
  end

  entry = session.connectionIndex[connectionId]
  merged = _mergePatch(entry.lineAnnotation, linePatch)
  statementText = _slice(session.sourceText, entry.statementSpan)
  replacement = _upsertNamedAnnotation(statementText, "Line", _renderLine(merged))
  patch = TextPatch(entry.statementSpan.startOffset, entry.statementSpan.endOffset, replacement)

  return _applyEdit!(session,
                     [patch],
                     "Updated annotation for '$connectionId'.",
                     connectionId)
end

"""
    deleteConnection(session::ModelSession, connectionId::String) -> OperationResult

Remove a connection equation from the loaded session.
"""
function deleteConnection(session::ModelSession, connectionId::String)::OperationResult
  if !haskey(session.connectionIndex, connectionId)
    return OperationResult(false, "Connection '$connectionId' was not found.", nothing)
  end

  entry = session.connectionIndex[connectionId]
  removalSpan = _expandRemovalSpan(session.sourceText, entry.statementSpan)
  patch = TextPatch(removalSpan.startOffset, removalSpan.endOffset, "")

  return _applyEdit!(session,
                     [patch],
                     "Deleted connection '$connectionId'.")
end

"""
    saveModel(session::ModelSession; targetPath = nothing) -> SaveResult

Write the current session source text to disk.
"""
function saveModel(session::ModelSession; targetPath::Union{Nothing, String} = nothing)::SaveResult
  path = targetPath === nothing ? session.path : targetPath
  write(path, session.sourceText)
  return SaveResult(path, sizeof(session.sourceText))
end

"""
    compileModel(session::ModelSession, classPath::String; kwargs...)

Call the registered compile delegate for `classPath`.
"""
function compileModel(session::ModelSession, classPath::String; kwargs...)
  return _invokeExecutionDelegate(COMPILE_DELEGATE[], session, classPath; kwargs...)
end

"""
    simulateModel(session::ModelSession, classPath::String; kwargs...)

Call the registered simulate delegate for `classPath`.
"""
function simulateModel(session::ModelSession, classPath::String; kwargs...)
  return _invokeExecutionDelegate(SIMULATE_DELEGATE[], session, classPath; kwargs...)
end

"""
    exportFlatModelica(session::ModelSession, classPath::String; kwargs...)

Call the registered flat-Modelica export delegate for `classPath`.
"""
function exportFlatModelica(session::ModelSession, classPath::String; kwargs...)
  return _invokeExecutionDelegate(EXPORT_FM_DELEGATE[], session, classPath; kwargs...)
end

function _invokeExecutionDelegate(delegate,
                                  session::ModelSession,
                                  classPath::String;
                                  kwargs...)
  if delegate === nothing
    error("No execution delegate has been registered for GUI_API.")
  end

  mktemp() do tempPath, io
    write(io, session.sourceText)
    flush(io)
    return delegate(classPath, tempPath; kwargs...)
  end
end

function _buildSession(path::String, sourceText::String)::ModelSession
  lineOffsets = _computeLineOffsets(sourceText)
  absynProgram = OMParser.parseString(sourceText, path, 1, 1000)
  scodeProgram = translateToSCode(absynProgram)

  session = ModelSession(path,
                         sourceText,
                         lineOffsets,
                         absynProgram,
                         scodeProgram,
                         Dict{String, Absyn.Class}(),
                         Dict{String, SourceSpan}(),
                         Dict{String, ComponentIndex}(),
                         Dict{String, ConnectionIndex}(),
                         Dict{String, Vector{SourceSpan}}(),
                         ValidationResult(true, "Parsed and translated to SCode."))

  prefix = _programPrefix(absynProgram)
  for class_ in collect(absynProgram.classes)
    classPath = _qualify(prefix, class_.name)
    _indexClass!(session, class_, classPath)
  end

  return session
end

function _replaceSession!(target::ModelSession, rebuilt::ModelSession)
  target.path = rebuilt.path
  target.sourceText = rebuilt.sourceText
  target.lineOffsets = rebuilt.lineOffsets
  target.absynProgram = rebuilt.absynProgram
  target.scodeProgram = rebuilt.scodeProgram
  target.classNodes = rebuilt.classNodes
  target.classSpans = rebuilt.classSpans
  target.componentIndex = rebuilt.componentIndex
  target.connectionIndex = rebuilt.connectionIndex
  target.equationSections = rebuilt.equationSections
  target.lastValidation = rebuilt.lastValidation
  return target
end

function _applyEdit!(session::ModelSession,
                     patches::Vector{TextPatch},
                     successMessage::String,
                     resourceId::Union{Nothing, String} = nothing)::OperationResult
  try
    newSource = _applyTextPatches(session.sourceText, patches)
    rebuilt = _buildSession(session.path, newSource)
    _replaceSession!(session, rebuilt)
    return OperationResult(true, successMessage, resourceId)
  catch err
    return OperationResult(false, sprint(showerror, err), nothing)
  end
end

function _indexClass!(session::ModelSession, class_::Absyn.Class, classPath::String)
  classSpan = _infoSpan(session.sourceText, session.lineOffsets, class_.info)
  session.classNodes[classPath] = class_
  session.classSpans[classPath] = classSpan

  parts = _classParts(class_)
  if parts === nothing
    session.equationSections[classPath] = SourceSpan[]
    return nothing
  end

  local equationSections = SourceSpan[]
  local connectionOrdinal = 0

  for part in parts
    if isa(part, Absyn.PUBLIC) || isa(part, Absyn.PROTECTED)
      for item in collect(part.contents)
        if !isa(item, Absyn.ELEMENTITEM)
          continue
        end
        element = item.element
        spec = element.specification

        if isa(spec, Absyn.CLASSDEF)
          nested = spec.class_
          _indexClass!(session, nested, _qualify(classPath, nested.name))
        elseif isa(spec, Absyn.COMPONENTS)
          statementSpan = _statementSpan(session.sourceText,
                                         session.lineOffsets,
                                         element.info,
                                         classSpan.endOffset)
          annotationText = _extractNamedAnnotationText(_slice(session.sourceText, statementSpan), "Placement")
          components = collect(spec.components)
          groupSize = length(components)
          typePath = Absyn.dumpTypeSpec(spec.typeSpec)
          for componentItem in components
            componentPath = _qualify(classPath, componentItem.component.name)
            session.componentIndex[componentPath] =
              ComponentIndex(classPath,
                             componentPath,
                             typePath,
                             statementSpan,
                             annotationText,
                             groupSize,
                             _extractPlacement(componentItem.comment, :Diagram),
                             _extractPlacement(componentItem.comment, :Icon))
          end
        end
      end
    elseif isa(part, Absyn.EQUATIONS)
      firstSpan = nothing
      lastSpan = nothing
      for eqItem in collect(part.contents)
        if !isa(eqItem, Absyn.EQUATIONITEM)
          continue
        end

        statementSpan = _statementSpan(session.sourceText,
                                       session.lineOffsets,
                                       eqItem.info,
                                       classSpan.endOffset)
        if firstSpan === nothing
          firstSpan = statementSpan
        end
        lastSpan = statementSpan

        equation = eqItem.equation_
        if isa(equation, Absyn.EQ_CONNECT)
          connectionOrdinal += 1
          connectionId = string(classPath, "::connect[", connectionOrdinal, "]")
          fromConnector = Absyn.dumpCref(equation.connector1)
          toConnector = Absyn.dumpCref(equation.connector2)
          lineText = _extractNamedAnnotationText(_slice(session.sourceText, statementSpan), "Line")
          session.connectionIndex[connectionId] =
            ConnectionIndex(connectionId,
                            classPath,
                            fromConnector,
                            toConnector,
                            statementSpan,
                            lineText,
                            _extractLine(eqItem.comment))
        end
      end

      if firstSpan !== nothing && lastSpan !== nothing
        push!(equationSections,
              SourceSpan(firstSpan.startOffset,
                         lastSpan.endOffset,
                         firstSpan.startLine,
                         firstSpan.startColumn,
                         lastSpan.endLine,
                         lastSpan.endColumn))
      end
    end
  end

  session.equationSections[classPath] = equationSections
  return nothing
end

function _classParts(class_::Absyn.Class)
  @match class_.body begin
    Absyn.PARTS(classParts = classParts) => collect(classParts)
    Absyn.CLASS_EXTENDS(parts = parts) => collect(parts)
    _ => nothing
  end
end

function _programPrefix(program::Absyn.Program)::String
  @match program.within_ begin
    Absyn.TOP() => return ""
    Absyn.WITHIN(path = p) => return Absyn.dumpPath(p)
  end
end

_qualify(prefix::String, name::AbstractString) = isempty(prefix) ? String(name) : string(prefix, ".", name)

function _computeLineOffsets(sourceText::String)::Vector{Int}
  offsets = Int[1]
  for i in eachindex(sourceText)
    if sourceText[i] == '\n'
      next = nextind(sourceText, i)
      push!(offsets, next)
    end
  end
  push!(offsets, lastindex(sourceText) + 1)
  return offsets
end

function _infoSpan(sourceText::String,
                   lineOffsets::Vector{Int},
                   info::SourceInfo)::SourceSpan
  startLine = max(info.lineNumberStart, 1)
  endLine = max(info.lineNumberEnd, startLine)
  startColumn = max(info.columnNumberStart, 1)
  endColumn = max(info.columnNumberEnd, startColumn)

  startOffset = _lineColumnToOffset(lineOffsets, startLine, startColumn, sourceText)
  endOffset = _lineColumnToOffset(lineOffsets, endLine, endColumn, sourceText)
  endOffset = min(max(endOffset, startOffset), lastindex(sourceText))

  return SourceSpan(startOffset,
                    endOffset,
                    startLine,
                    startColumn,
                    endLine,
                    endColumn)
end

function _lineColumnToOffset(lineOffsets::Vector{Int},
                             line::Int,
                             column::Int,
                             sourceText::String)::Int
  if isempty(sourceText)
    return 1
  end

  lineIndex = min(max(line, 1), length(lineOffsets) - 1)
  lineStart = lineOffsets[lineIndex]
  offset = lineStart + column - 1
  return min(max(offset, 1), lastindex(sourceText))
end

function _statementSpan(sourceText::String,
                        lineOffsets::Vector{Int},
                        info::SourceInfo,
                        limit::Int)::SourceSpan
  baseSpan = _infoSpan(sourceText, lineOffsets, info)
  endOffset = _findStatementEnd(sourceText, baseSpan.startOffset, limit)
  return SourceSpan(baseSpan.startOffset,
                    endOffset,
                    baseSpan.startLine,
                    baseSpan.startColumn,
                    info.lineNumberEnd,
                    info.columnNumberEnd)
end

function _findStatementEnd(sourceText::String, startOffset::Int, limit::Int)::Int
  depthParen = 0
  depthBrace = 0
  depthBracket = 0
  inString = false
  escaped = false
  i = startOffset
  stopOffset = min(limit, lastindex(sourceText))

  while i <= stopOffset
    c = sourceText[i]
    if inString
      if escaped
        escaped = false
      elseif c == '\\'
        escaped = true
      elseif c == '"'
        inString = false
      end
    else
      if c == '"'
        inString = true
      elseif c == '('
        depthParen += 1
      elseif c == ')'
        depthParen = max(depthParen - 1, 0)
      elseif c == '{'
        depthBrace += 1
      elseif c == '}'
        depthBrace = max(depthBrace - 1, 0)
      elseif c == '['
        depthBracket += 1
      elseif c == ']'
        depthBracket = max(depthBracket - 1, 0)
      elseif c == ';' && depthParen == 0 && depthBrace == 0 && depthBracket == 0
        return i
      end
    end
    i = nextind(sourceText, i)
  end

  error("Could not locate the end of a Modelica statement.")
end

function _slice(sourceText::String, span::SourceSpan)::String
  if span.endOffset < span.startOffset
    return ""
  end
  return String(SubString(sourceText, span.startOffset, span.endOffset))
end

function _applyTextPatches(sourceText::String, patches::Vector{TextPatch})::String
  ordered = sort(patches, by = patch -> patch.startOffset, rev = true)
  updated = sourceText
  for patch in ordered
    beforeEnd = patch.startOffset - 1
    afterStart = patch.endOffset + 1
    before = beforeEnd >= 1 ? String(SubString(updated, 1, beforeEnd)) : ""
    after = afterStart <= lastindex(updated) ? String(SubString(updated, afterStart, lastindex(updated))) : ""
    updated = string(before, patch.replacement, after)
  end
  return updated
end

function _extractCoordinateSystem(class_::Absyn.Class, view::Symbol)::Dict{String, Any}
  viewName = string(view)
  default = Dict{String, Any}("extent" => ((-100.0, -100.0), (100.0, 100.0)),
                              "preserveAspectRatio" => true,
                              "initialScale" => nothing)

  annotations = _classAnnotations(class_)
  viewMod = _findNamedModification(annotations, viewName)
  viewMod === nothing && return default

  coordinateMod = _findNamedModification(_classModArgs(viewMod), "coordinateSystem")
  coordinateMod === nothing && return default

  args = _classModArgs(coordinateMod)
  extentExp = _bindingExp(args, "extent")
  preserveExp = _bindingExp(args, "preserveAspectRatio")
  scaleExp = _bindingExp(args, "initialScale")

  extent = extentExp === nothing ? default["extent"] : _expToExtent(extentExp)
  preserve = preserveExp === nothing ? true : _expToBool(preserveExp)
  initialScale = scaleExp === nothing ? nothing : _expToFloat(scaleExp)

  return Dict{String, Any}("extent" => extent,
                           "preserveAspectRatio" => preserve,
                           "initialScale" => initialScale)
end

function _classAnnotations(class_::Absyn.Class)::Vector{Absyn.ElementArg}
  @match class_.body begin
    Absyn.PARTS(ann = ann) => return _flattenAnnotations(collect(ann))
    Absyn.CLASS_EXTENDS(ann = ann) => return _flattenAnnotations(collect(ann))
    Absyn.DERIVED(comment = comment) => return _commentElementArgs(comment)
    Absyn.ENUMERATION(comment = comment) => return _commentElementArgs(comment)
    Absyn.OVERLOAD(comment = comment) => return _commentElementArgs(comment)
    _ => return Absyn.ElementArg[]
  end
end

function _flattenAnnotations(annotations::Vector{Absyn.Annotation})::Vector{Absyn.ElementArg}
  args = Absyn.ElementArg[]
  for ann in annotations
    append!(args, collect(ann.elementArgs))
  end
  return args
end

function _commentElementArgs(commentOpt)::Vector{Absyn.ElementArg}
  comment = _optionValue(commentOpt)
  comment === nothing && return Absyn.ElementArg[]
  annotation = _optionValue(comment.annotation_)
  annotation === nothing && return Absyn.ElementArg[]
  return collect(annotation.elementArgs)
end

function _extractPlacement(commentOpt, view::Symbol)::Dict{String, Any}
  placement = _defaultPlacement()
  comment = _optionValue(commentOpt)
  comment === nothing && return placement
  annotation = _optionValue(comment.annotation_)
  annotation === nothing && return placement

  placementMod = _findNamedModification(collect(annotation.elementArgs), "Placement")
  placementMod === nothing && return placement

  args = _classModArgs(placementMod)
  transformName = view == :Icon ? "iconTransformation" : "transformation"
  transformMod = _findNamedModification(args, transformName)
  if transformMod === nothing && view == :Icon
    transformMod = _findNamedModification(args, "transformation")
  end
  transformMod === nothing && return placement

  transformArgs = _classModArgs(transformMod)

  extentExp = _bindingExp(transformArgs, "extent")
  if extentExp !== nothing
    placement["extent"] = _expToExtent(extentExp)
  end

  originExp = _bindingExp(transformArgs, "origin")
  if originExp !== nothing
    placement["origin"] = _expToPoint(originExp)
    placement["_has_origin"] = true
  end

  rotationExp = _bindingExp(transformArgs, "rotation")
  if rotationExp !== nothing
    placement["rotation"] = _expToFloat(rotationExp)
    placement["_has_rotation"] = true
  end

  visibleExp = _bindingExp(transformArgs, "visible")
  if visibleExp !== nothing
    placement["visible"] = _expToBool(visibleExp)
    placement["_has_visible"] = true
  end

  return placement
end

function _extractLine(commentOpt)::Dict{String, Any}
  line = _defaultLine()
  comment = _optionValue(commentOpt)
  comment === nothing && return line
  annotation = _optionValue(comment.annotation_)
  annotation === nothing && return line

  lineMod = _findNamedModification(collect(annotation.elementArgs), "Line")
  lineMod === nothing && return line
  args = _classModArgs(lineMod)

  pointsExp = _bindingExp(args, "points")
  if pointsExp !== nothing
    line["points"] = _expToPoints(pointsExp)
  end

  colorExp = _bindingExp(args, "color")
  if colorExp !== nothing
    line["color"] = _expToColor(colorExp)
    line["_has_color"] = true
  end

  visibleExp = _bindingExp(args, "visible")
  if visibleExp !== nothing
    line["visible"] = _expToBool(visibleExp)
    line["_has_visible"] = true
  end

  return line
end

function _defaultPlacement()::Dict{String, Any}
  return Dict{String, Any}("extent" => ((-10.0, -10.0), (10.0, 10.0)),
                           "origin" => (0.0, 0.0),
                           "rotation" => 0.0,
                           "visible" => true,
                           "_has_origin" => false,
                           "_has_rotation" => false,
                           "_has_visible" => false)
end

function _defaultLine()::Dict{String, Any}
  return Dict{String, Any}("points" => Point2D[],
                           "color" => nothing,
                           "visible" => true,
                           "_has_color" => false,
                           "_has_visible" => false)
end

function _displayOrigin(placement::Dict{String, Any})::Point2D
  if placement["_has_origin"]
    return placement["origin"]
  end
  ((x1, y1), (x2, y2)) = placement["extent"]
  return ((x1 + x2) / 2, (y1 + y2) / 2)
end

function _optionValue(opt)
  return opt === nothing ? nothing : opt.data
end

function _findNamedModification(args::Vector{Absyn.ElementArg}, name::String)
  for arg in args
    if !isa(arg, Absyn.MODIFICATION)
      continue
    end
    if _pathLastIdent(arg.path) == name
      return _optionValue(arg.modification)
    end
  end
  return nothing
end

function _pathLastIdent(path::Absyn.Path)::String
  @match path begin
    Absyn.IDENT(name = name) => name
    Absyn.QUALIFIED(path = rest) => _pathLastIdent(rest)
    Absyn.FULLYQUALIFIED(path = rest) => _pathLastIdent(rest)
  end
end

function _classModArgs(modification)::Vector{Absyn.ElementArg}
  @match modification begin
    Absyn.CLASSMOD(elementArgLst = elementArgLst) => collect(elementArgLst)
    _ => Absyn.ElementArg[]
  end
end

function _bindingExp(args::Vector{Absyn.ElementArg}, name::String)
  mod = _findNamedModification(args, name)
  mod === nothing && return nothing
  @match mod begin
    Absyn.CLASSMOD(eqMod = Absyn.EQMOD(exp = exp)) => return exp
    _ => return nothing
  end
end

function _expToPoint(exp)::Point2D
  values = collect(exp.arrayExp)
  return (_expToFloat(values[1]), _expToFloat(values[2]))
end

function _expToPoints(exp)::Vector{Point2D}
  points = Point2D[]
  for pointExp in collect(exp.arrayExp)
    push!(points, _expToPoint(pointExp))
  end
  return points
end

function _expToExtent(exp)::Extent2D
  points = _expToPoints(exp)
  return (points[1], points[2])
end

function _expToColor(exp)::Color3
  values = collect(exp.arrayExp)
  return (Int(round(_expToFloat(values[1]))),
          Int(round(_expToFloat(values[2]))),
          Int(round(_expToFloat(values[3]))))
end

function _expToFloat(exp)::Float64
  @match exp begin
    Absyn.INTEGER(value = value) => return Float64(value)
    Absyn.REAL(value = value) => return parse(Float64, value)
    Absyn.UNARY(op = Absyn.UMINUS(), exp = inner) => return -_expToFloat(inner)
    Absyn.UNARY(op = Absyn.UPLUS(), exp = inner) => return _expToFloat(inner)
  end
  error("Unsupported numeric expression in GUI_API annotation handling.")
end

function _expToBool(exp)::Bool
  @match exp begin
    Absyn.BOOL(value = value) => return value
  end
  error("Unsupported boolean expression in GUI_API annotation handling.")
end

function _mergePatch(existing::Dict{String, Any}, patch)::Dict{String, Any}
  merged = copy(existing)
  for (key, value) in pairs(patch)
    normalized = string(key)
    merged[normalized] = value
    if normalized == "origin"
      merged["_has_origin"] = true
    elseif normalized == "rotation"
      merged["_has_rotation"] = true
    elseif normalized == "visible"
      merged["_has_visible"] = true
    elseif normalized == "color"
      merged["_has_color"] = true
    end
  end
  return merged
end

function _renderPlacement(placement::Dict{String, Any})::String
  fragments = ["extent = " * _renderExtent(placement["extent"])]
  if placement["_has_origin"]
    push!(fragments, "origin = " * _renderPoint(placement["origin"]))
  end
  if placement["_has_rotation"]
    push!(fragments, "rotation = " * _renderFloat(placement["rotation"]))
  end
  if placement["_has_visible"]
    push!(fragments, "visible = " * string(placement["visible"]))
  end
  return "Placement(transformation(" * join(fragments, ", ") * "))"
end

function _renderLine(line::Dict{String, Any})::String
  fragments = ["points = " * _renderPoints(line["points"])]
  if line["_has_color"] && line["color"] !== nothing
    push!(fragments, "color = " * _renderColor(line["color"]))
  end
  if line["_has_visible"]
    push!(fragments, "visible = " * string(line["visible"]))
  end
  return "Line(" * join(fragments, ", ") * ")"
end

function _renderConnectStatement(fromConnector::String,
                                 toConnector::String,
                                 line::Dict{String, Any})::String
  return "connect(" * fromConnector * ", " * toConnector * ") annotation(" * _renderLine(line) * ");"
end

function _renderPoint(point::Point2D)::String
  return "{" * _renderFloat(point[1]) * ", " * _renderFloat(point[2]) * "}"
end

function _renderPoints(points::Vector{Point2D})::String
  rendered = map(_renderPoint, points)
  return "{" * join(rendered, ", ") * "}"
end

function _renderExtent(extent::Extent2D)::String
  return "{" * _renderPoint(extent[1]) * ", " * _renderPoint(extent[2]) * "}"
end

function _renderColor(color::Color3)::String
  return "{$(color[1]), $(color[2]), $(color[3])}"
end

function _renderFloat(value::Real)::String
  rounded = round(Float64(value); digits = 8)
  if isinteger(rounded)
    return string(Int(round(rounded)))
  end
  return string(rounded)
end

function _extractNamedAnnotationText(statementText::String, name::String)
  annotationRange = _findIdentifierCall(statementText, "annotation")
  annotationRange === nothing && return nothing

  innerStart = annotationRange[1] + length("annotation(")
  innerEnd = annotationRange[2] - 1
  inner = innerStart <= innerEnd ? String(SubString(statementText, innerStart, innerEnd)) : ""
  nameRange = _findIdentifierCall(inner, name)
  nameRange === nothing && return nothing
  return String(SubString(inner, nameRange[1], nameRange[2]))
end

function _upsertNamedAnnotation(statementText::String,
                                name::String,
                                renderedEntry::String)::String
  annotationRange = _findIdentifierCall(statementText, "annotation")
  if annotationRange === nothing
    semicolon = findlast(==(';'), statementText)
    semicolon === nothing && error("Expected a terminating ';' in the Modelica statement.")
    return string(statementText[1:semicolon-1],
                  " annotation(",
                  renderedEntry,
                  ")",
                  statementText[semicolon:end])
  end

  innerStart = annotationRange[1] + length("annotation(")
  innerEnd = annotationRange[2] - 1
  inner = innerStart <= innerEnd ? String(SubString(statementText, innerStart, innerEnd)) : ""
  nameRange = _findIdentifierCall(inner, name)

  newInner = if nameRange === nothing
    stripped = strip(inner)
    isempty(stripped) ? renderedEntry : string(inner, ", ", renderedEntry)
  else
    before = nameRange[1] > 1 ? String(SubString(inner, 1, nameRange[1] - 1)) : ""
    after = nameRange[2] < lastindex(inner) ? String(SubString(inner, nameRange[2] + 1, lastindex(inner))) : ""
    string(before, renderedEntry, after)
  end

  prefix = innerStart > 1 ? String(SubString(statementText, 1, innerStart - 1)) : ""
  suffix = innerEnd < lastindex(statementText) ? String(SubString(statementText, innerEnd + 1, lastindex(statementText))) : ""
  return string(prefix, newInner, suffix)
end

function _findIdentifierCall(text::String, name::String)
  depthParen = 0
  depthBrace = 0
  depthBracket = 0
  inString = false
  escaped = false
  i = firstindex(text)

  while i <= lastindex(text)
    c = text[i]
    if inString
      if escaped
        escaped = false
      elseif c == '\\'
        escaped = true
      elseif c == '"'
        inString = false
      end
      i = nextind(text, i)
      continue
    end

    if c == '"'
      inString = true
      i = nextind(text, i)
      continue
    elseif c == '('
      depthParen += 1
    elseif c == ')'
      depthParen = max(depthParen - 1, 0)
    elseif c == '{'
      depthBrace += 1
    elseif c == '}'
      depthBrace = max(depthBrace - 1, 0)
    elseif c == '['
      depthBracket += 1
    elseif c == ']'
      depthBracket = max(depthBracket - 1, 0)
    end

    if depthParen == 0 && depthBrace == 0 && depthBracket == 0 && _startsIdentifierAt(text, i, name)
      openIndex = i + length(name)
      while openIndex <= lastindex(text) && isspace(text[openIndex])
        openIndex = nextind(text, openIndex)
      end
      if openIndex <= lastindex(text) && text[openIndex] == '('
        closeIndex = _findMatchingParen(text, openIndex)
        return (i, closeIndex)
      end
    end

    i = nextind(text, i)
  end

  return nothing
end

function _startsIdentifierAt(text::String, offset::Int, name::String)::Bool
  if !startswith(SubString(text, offset), name)
    return false
  end

  if offset > firstindex(text)
    previous = text[prevind(text, offset)]
    if _isIdentifierChar(previous)
      return false
    end
  end

  after = offset + length(name)
  if after <= lastindex(text) && _isIdentifierChar(text[after])
    return false
  end

  return true
end

_isIdentifierChar(c::Char) = isletter(c) || isdigit(c) || c == '_'

function _findMatchingParen(text::String, openIndex::Int)::Int
  depth = 0
  inString = false
  escaped = false
  i = openIndex

  while i <= lastindex(text)
    c = text[i]
    if inString
      if escaped
        escaped = false
      elseif c == '\\'
        escaped = true
      elseif c == '"'
        inString = false
      end
    else
      if c == '"'
        inString = true
      elseif c == '('
        depth += 1
      elseif c == ')'
        depth -= 1
        if depth == 0
          return i
        end
      end
    end
    i = nextind(text, i)
  end

  error("Unbalanced parentheses in annotation text.")
end

function _resolveComponentPath(session::ModelSession, componentPath::String)::String
  if haskey(session.componentIndex, componentPath)
    return componentPath
  end

  matches = String[]
  suffix = "." * componentPath
  for key in keys(session.componentIndex)
    if endswith(key, suffix)
      push!(matches, key)
    end
  end

  if length(matches) == 1
    return first(matches)
  elseif isempty(matches)
    error("Component '$componentPath' was not found.")
  else
    error("Component '$componentPath' is ambiguous. Please use a full class-qualified component path.")
  end
end

function _resolveConnectionClassPath(session::ModelSession,
                                     fromConnector::String,
                                     toConnector::String,
                                     classPath::Union{Nothing, String})::String
  if classPath !== nothing
    return classPath
  end

  matches = String[]
  for candidate in keys(session.classNodes)
    prefix = candidate * "."
    if startswith(fromConnector, prefix) && startswith(toConnector, prefix)
      push!(matches, candidate)
    end
  end

  if !isempty(matches)
    sort!(matches, by = length, rev = true)
    return first(matches)
  end

  if length(session.classNodes) == 1
    return first(keys(session.classNodes))
  end

  error("Unable to resolve a class for the connection '$fromConnector -> $toConnector'. Pass classPath explicitly.")
end

function _localConnectorRef(connectorRef::String, classPath::String)::String
  prefix = classPath * "."
  return startswith(connectorRef, prefix) ? connectorRef[length(prefix)+1:end] : connectorRef
end

function _defaultConnectionPoints(session::ModelSession,
                                  classPath::String,
                                  fromConnector::String,
                                  toConnector::String)::Vector{Point2D}
  fromParts = split(fromConnector, ".")
  toParts = split(toConnector, ".")

  if !isempty(fromParts) && !isempty(toParts)
    fromComponent = _qualify(classPath, first(fromParts))
    toComponent = _qualify(classPath, first(toParts))

    if haskey(session.componentIndex, fromComponent) && haskey(session.componentIndex, toComponent)
      return [_displayOrigin(session.componentIndex[fromComponent].diagramPlacement),
              _displayOrigin(session.componentIndex[toComponent].diagramPlacement)]
    end
  end

  return [(-10.0, 0.0), (10.0, 0.0)]
end

function _buildConnectionInsertPatch(session::ModelSession,
                                     classPath::String,
                                     statementText::String)::TextPatch
  class_ = session.classNodes[classPath]
  classSpan = session.classSpans[classPath]
  bodyIndent = _bodyIndent(session.sourceText, classSpan)
  itemIndent = bodyIndent * "  "

  sections = get(session.equationSections, classPath, SourceSpan[])
  if !isempty(sections)
    lastSection = last(sections)
    afterOffset = lastSection.endOffset + 1
    if afterOffset <= lastindex(session.sourceText) && session.sourceText[afterOffset] == '\n'
      insertAt = nextind(session.sourceText, afterOffset)
      insertion = itemIndent * statementText * "\n"
    else
      insertAt = afterOffset
      insertion = "\n" * itemIndent * statementText * "\n"
    end
    return TextPatch(insertAt, insertAt - 1, insertion)
  end

  insertAt = _classAnnotationOrEndOffset(session.sourceText, class_, classSpan)
  insertion = bodyIndent * "equation\n" * itemIndent * statementText * "\n"
  return TextPatch(insertAt, insertAt - 1, insertion)
end

function _bodyIndent(sourceText::String, classSpan::SourceSpan)::String
  lineStart = _lineStart(sourceText, classSpan.startOffset)
  indent = 0
  i = lineStart
  while i < classSpan.startOffset && sourceText[i] == ' '
    indent += 1
    i = nextind(sourceText, i)
  end
  return repeat(" ", indent + 2)
end

function _lineStart(sourceText::String, offset::Int)::Int
  i = offset
  while i > firstindex(sourceText)
    previous = prevind(sourceText, i)
    if sourceText[previous] == '\n'
      break
    end
    i = previous
  end
  return i
end

function _classAnnotationOrEndOffset(sourceText::String,
                                     class_::Absyn.Class,
                                     classSpan::SourceSpan)::Int
  classText = _slice(sourceText, classSpan)
  bodyIndent = _bodyIndent(sourceText, classSpan)
  annotationMarker = "\n" * bodyIndent * "annotation("
  annotationRange = findlast(annotationMarker, classText)
  if annotationRange !== nothing
    return classSpan.startOffset + first(annotationRange)
  end

  endMarker = "end " * class_.name * ";"
  endRange = findlast(endMarker, classText)
  if endRange !== nothing
    return classSpan.startOffset + first(endRange) - 1
  end

  return classSpan.endOffset + 1
end

function _expandRemovalSpan(sourceText::String, span::SourceSpan)::SourceSpan
  startOffset = span.startOffset
  lineStart = _lineStart(sourceText, span.startOffset)
  onlyWhitespace = true
  i = lineStart
  while i < span.startOffset
    if !isspace(sourceText[i])
      onlyWhitespace = false
      break
    end
    i = nextind(sourceText, i)
  end
  if onlyWhitespace
    startOffset = lineStart
  end

  endOffset = span.endOffset
  after = endOffset + 1
  if after <= lastindex(sourceText) && sourceText[after] == '\n'
    endOffset = after
  end

  return SourceSpan(startOffset,
                    endOffset,
                    span.startLine,
                    span.startColumn,
                    span.endLine,
                    span.endColumn)
end

function _findConnectionId(session::ModelSession,
                           classPath::String,
                           fromConnector::String,
                           toConnector::String)
  matches = String[]
  for (id, entry) in session.connectionIndex
    if entry.classPath == classPath &&
       entry.fromConnector == fromConnector &&
       entry.toConnector == toConnector
      push!(matches, id)
    end
  end

  isempty(matches) && return nothing
  sort!(matches)
  return last(matches)
end

end

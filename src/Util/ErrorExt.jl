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

module ErrorExt

import ..Gettext
using MetaModelica
using ExportAll

import ..ErrorTypes

function registerModelicaFormatError()
  return @warn "TODO: Defined in the runtime"
end

#= Per-task error state. Each Julia `Task` (root task, `@async`, `@spawn`)
   gets its own message queue and checkpoint stack on first access via
   `task_local_storage()`. Concurrent frontend invocations cannot stomp on
   each other's queues. Use `moveMessagesToParentThread(parent::Task)` to
   merge messages back up after a worker task finishes. =#

mutable struct _ErrorState
  sourceMessages::Vector{Any}
  checkpointStack::Vector{Int}
end
_ErrorState() = _ErrorState(Any[], Int[])

const _STATE_KEY = :OMFrontend_ErrorState_v1
const _MERGE_LOCK = ReentrantLock()

@inline function _state()::_ErrorState
  td = task_local_storage()
  st = get(td, _STATE_KEY, nothing)
  if st === nothing
    st = _ErrorState()
    td[_STATE_KEY] = st
  end
  return st::_ErrorState
end

"""
    pushSourceMessage!(entry)

Append a source-message tuple `(message, tokens, info)` to the current task's
queue. Called by `Error.addSourceMessage` and friends.
"""
@inline function pushSourceMessage!(entry)
  push!(_state().sourceMessages, entry)
  return nothing
end

#= Convenience read-only accessors. =#
@inline _messages() = _state().sourceMessages
@inline _checkpoints() = _state().checkpointStack

function addSourceMessage(
  id::ErrorTypes.ErrorID,
  msg_type::ErrorTypes.MessageType,
  msg_severity::ErrorTypes.Severity,
  sline::Integer,
  scol::Integer,
  eline::Integer,
  ecol::Integer,
  read_only::Bool,
  filename::String,
  msg::String,
  tokens::List{<:String},
)
  @warn "TODO: Defined in the runtime"
end

"""=
  Converts a MessageType to a string.
"""
function messageTypeStr(inMessageType::ErrorTypes.MessageType)::String
  local outString::String

  @assign outString = begin
    @match inMessageType begin
      ErrorTypes.SYNTAX(__) => begin
        "SYNTAX"
      end

      ErrorTypes.GRAMMAR(__) => begin
        "GRAMMAR"
      end

      ErrorTypes.TRANSLATION(__) => begin
        "TRANSLATION"
      end

      ErrorTypes.SYMBOLIC(__) => begin
        "SYMBOLIC"
      end

      ErrorTypes.SIMULATION(__) => begin
        "SIMULATION"
      end

      ErrorTypes.SCRIPTING(__) => begin
        "SCRIPTING"
      end
    end
  end
  return outString
end

"""
 Converts a Severity to a string.
"""
function severityStr(inSeverity::ErrorTypes.Severity)::String
  local outString::String
  @assign outString = begin
    @match inSeverity begin
      ErrorTypes.INTERNAL(__) => begin
        "Internal error"
      end

      ErrorTypes.ERROR(__) => begin
        "Error"
      end

      ErrorTypes.WARNING(__) => begin
        "Warning"
      end

      ErrorTypes.NOTIFICATION(__) => begin
        "Notification"
      end
    end
  end
  return outString
end

"""
  Converts an SourceInfo into a string ready to be used in error messages.
  Format is [filename:line start:column start-line end:column end]
"""
function infoStr(info::SourceInfo)::String
  local str::String
  @assign str = begin
    local filename::String
    local info_str::String
    local line_start::Integer
    local line_end::Integer
    local col_start::Integer
    local col_end::Integer
    @match info begin
      SOURCEINFO(
        fileName = filename,
        lineNumberStart = line_start,
        columnNumberStart = col_start,
        lineNumberEnd = line_end,
        columnNumberEnd = col_end,
      ) => begin
        @assign info_str =
          "[" +
          "file:" * filename +
          ":" +
          intString(line_start) +
          ":" +
          intString(col_start) +
          "-" +
          intString(line_end) +
          ":" +
          intString(col_end) +
          "]"
        info_str
      end
    end
  end
  return str
end

function printMessagesStr(;warningsAsErrors::Bool = false,
                          printErrors = true #= In some cases we only want to print warnings.=#)
  local buffer = IOBuffer()
  for (m, tokens, mInfo) in _messages()
    if printErrors == false && typeof(m.id) !== ErrorTypes.WARNING
      continue
    end
    println(buffer, string(severityStr(m.severity), ":"))
    println(buffer, string("\tMessage Type:", messageTypeStr(m.ty)))
    println(buffer, string("\t", infoStr(mInfo)))
    local msg = Gettext.translateContent(m.message)
    #= Add the tokens to the message string =#
    for token in tokens
      msg = replace(msg, "%s" => token, count = 1)
    end
    println(buffer, "Message:" * msg)
  end
  return String(take!(buffer))
end

function getNumMessages()
  return length(_messages())
end

function getNumErrorMessages()::Integer
  local num::Integer = 0
  for m in _messages()
    if typeof(m.id) === Severity.ERROR
      num += 1
    end
  end
  return num
end

function getNumWarningMessages()::Integer
  local num::Integer = 0
  for m in _messages()
    if typeof(m.id) === Severity.WARNING
      num += 1
    end
  end
  return num
end

"""Returns all error messages and pops them from the message queue."""
function getMessages()::List{ErrorTypes.TotalMessage}
  local res::List{ErrorTypes.TotalMessage} = nil
  local q = _messages()
  while !isempty(q)
    res = res <| pop!(q)
  end
  return res
end

"""Returns all error messages since the last checkpoint and pops them from the message queue."""
function getCheckpointMessages()::List{ErrorTypes.TotalMessage}
  local res::List{ErrorTypes.TotalMessage} = nil
  @warn "TODO: getCheckpointMessages not defined in the runtime"
  return res
end

function clearMessages()
  local st = _state()
  empty!(st.sourceMessages)
  empty!(st.checkpointStack)
  return nothing
end

"""Used to rollback/delete checkpoints without considering the identifier. Used to reset the error messages after a stack overflow exception."""
function getNumCheckpoints()::Integer
  return length(_checkpoints())
end

"""Used to rollback/delete checkpoints without considering the identifier. Used to reset the error messages after a stack overflow exception."""
function rollbackNumCheckpoints(n::Integer)
  for _ in 1:n
    rollBack("")
  end
end

"""Used to rollback/delete checkpoints without considering the identifier. Used to reset the error messages after a stack overflow exception."""
function deleteNumCheckpoints(n::Integer)
  for _ in 1:n
    delCheckpoint("")
  end
end

"""
  sets a checkpoint for the error messages, so error messages can be rolled back (i.e. deleted) up to this point
  A unique identifier for this checkpoint must be provided. It is checked when doing rollback or deletion
"""
function setCheckpoint(id::String) #= uniqe identifier for the checkpoint (up to the programmer to guarantee uniqueness) =#
  local st = _state()
  push!(st.checkpointStack, length(st.sourceMessages))
  return nothing
end

"""
Deletes the checkpoint at the top of the stack without
removing the error messages issued since that checkpoint.
If the checkpoint id doesn't match, the application exits with -1.
"""
function delCheckpoint(id::String) #= unique identifier =#
  local stk = _checkpoints()
  if !isempty(stk)
    pop!(stk)
  end
  return nothing
end

function printErrorsNoWarning()::String
  local outString::String
  @warn "printErrorsNoWarning TODO: Defined in the runtime"
  return outString
end

"""
  rolls back error messages until the latest checkpoint,
  deleting all error messages added since that point in time. A unique identifier for the checkpoint must be provided
  The application will exit with return code -1 if this identifier does not match.
"""
function rollBack(id::String) #= unique identifier =#
  local st = _state()
  if !isempty(st.checkpointStack)
    n = pop!(st.checkpointStack)
    resize!(st.sourceMessages, n)
  end
  return nothing
end

"""
  rolls back error messages until the latest checkpoint,
  returning all error messages added since that point in time. A unique identifier for the checkpoint must be provided
  The application will exit with return code -1 if this identifier does not match.
"""
function popCheckPoint(id::String)::List{Integer} #= unique identifier =#
  local handles::List{Integer} #= opaque pointers; you MUST pass them back or memory is leaked =#

  @warn "TODO: Defined in the runtime"
  return handles #= opaque pointers; you MUST pass them back or memory is leaked =#
end

"""Pushes stored pointers back to the error stack."""
function pushMessages(handles::List{<:Integer}) #= opaque pointers from popCheckPoint =#
  return @warn "TODO: Defined in the runtime"
end

"""Pushes stored pointers back to the error stack."""
function freeMessages(handles::List{<:Integer}) #= opaque pointers from popCheckPoint =#
  return @warn "TODO: Defined in the runtime"
end

"""
  @author: adrpo
  This function checks if the specified checkpoint exists AT THE TOP OF THE STACK!.
  You can use it to rollBack/delete a checkpoint, but you're
  not sure that it exists (due to MetaModelica backtracking).
"""
function isTopCheckpoint(id::String)::Bool #= unique identifier =#
  local isThere::Bool #= tells us if the checkpoint exists (true) or doesn't (false) =#

  @warn "TODO: Defined in the runtime"
  return isThere #= tells us if the checkpoint exists (true) or doesn't (false) =#
end

function setShowErrorMessages(inShow::Bool)
  return @warn "TODO: Defined in the runtime"
end

"""
    moveMessagesToParentThread(parent::Task)

Drain the current task's error queue and append the entries to `parent`'s
task-local error state. Used at the end of a spawned worker task to surface
its messages on the parent. Synchronised via `_MERGE_LOCK` so two siblings
draining into the same parent do not corrupt the parent's vector.
"""
function moveMessagesToParentThread(parent::Task)
  local mine = _state()
  isempty(mine.sourceMessages) && return nothing
  Base.lock(_MERGE_LOCK) do
    #= Julia's public `task_local_storage()` only addresses the current
       task. Reach into the parent's `storage` field directly, lazily
       creating the `IdDict` if the parent never touched its TLS. The
       lock serialises sibling tasks draining into the same parent. =#
    local parentTd = parent.storage
    if parentTd === nothing
      parentTd = IdDict{Any,Any}()
      parent.storage = parentTd
    end
    local pstate = get(parentTd, _STATE_KEY, nothing)
    if pstate === nothing
      pstate = _ErrorState()
      parentTd[_STATE_KEY] = pstate
    end
    append!(pstate.sourceMessages, mine.sourceMessages)
  end
  empty!(mine.sourceMessages)
  return nothing
end

#= Backwards-compat no-arg form: assume the immediate parent is the desired
   sink. Kept so callers that do not have a Task handle still work. =#
function moveMessagesToParentThread()
  local p = current_task()
  if p === nothing || !isdefined(p, :parent) || p.parent === nothing
    return nothing
  end
  return moveMessagesToParentThread(p.parent::Task)
end

"""Makes assert() and other runtime assertions print to the error buffer"""
function initAssertionFunctions()
  return @warn "TODO: Defined in the runtime"
end

@exportAll()
end

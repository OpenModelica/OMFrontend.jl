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

"""
  A  Modelica frontend in Julia.
"""
module OMFrontend


using MetaModelica

import Absyn
import SCode
import OMParser
import PrecompileTools
import Distributed
import Serialization

#= This file defines additional utility macros. =#
include("util.jl")

#= OMFrontend's root directory, wherever it is loaded from (lib/ holds the builtin
   library and the bundled MSL). Base.find_package resolves a package name only where
   the active environment lists the package directly: with only OM or OMBackend in
   an environment it returned nothing, and the precompile workload and the MSL loading
   failed there. =#
packageRoot()::String = something(pkgdir(@__MODULE__), normpath(joinpath(@__DIR__, "..")))


#= Cache for NFModelicaBuiltin. We only use the result once! =#
"""
  Cache for NFModelicaBuiltin.
  This cache is initialized when the module is loaded.
"""
const NFModelicaBuiltinCache = Dict()
#= The builtin library is parsed into the package image (precompilation.jl): a change to it
   recompiles the package. =#
include_dependency(joinpath(@__DIR__, "..", "lib", "NFModelicaBuiltin.mo"))
#= The bundled MSL files too: the precompile workload parses MSL 4.1.0 into LIBRARY_CACHE, which the package image
   keeps; without this a corrected bundle was not read until something else recompiled the package. =#
for f in readdir(joinpath(@__DIR__, "..", "lib", "Modelica"); join = true)
  endswith(f, ".mo") && include_dependency(f)
end

"""
  This cache contains libraries for later use.
"""
const LIBRARY_CACHE = Dict{String, SCode.Program}()

#= A loaded library's top-level package name => its directory (of package.mo), for
   modelica:// URIs (an external function's IncludeDirectory, loadResource). =#
const LIBRARY_ROOTS = Dict{String, String}()

"""
    resolveModelicaURI(uri) -> String

The file path of a `modelica://Package.Sub/path` URI (a sub-package is a directory of its
library's), of a `file://` URI, or the string itself.
"""
function resolveModelicaURI(uri::AbstractString)::String
  local m = match(r"^modelica://([^/]+)(/.*)?$"i, uri)
  if m === nothing
    startswith(lowercase(uri), "file://") && return String(uri[8:end])
    return String(uri)
  end
  local parts = split(m.captures[1], ".")
  local root = get(LIBRARY_ROOTS, String(parts[1]), nothing)
  root === nothing && error("resolveModelicaURI: library $(parts[1]) of $(uri) is not loaded")
  local dir = joinpath(root, parts[2:end]...)
  local rest = m.captures[2] === nothing ? "" : String(lstrip(m.captures[2], '/'))
  return isempty(rest) ? dir : joinpath(dir, rest)
end

"""
  The cache keys of the libraries a cached library uses (its `uses` annotation), as
  `loadInstalledLibrary` loaded them; `libraryClosure` adds them to a flattening.
"""
const LIBRARY_DEPENDENCIES = Dict{String, Vector{String}}()

"""
  This function "precompiles" some of the runtime Modelica libraries.
  While it results in some latency when importing OMFrontend, subsequent
  use of OMFrontend to parse and work with Modelica files is faster.
TODO:
Improving the speed of precompilation would improve the feel of this package
by a lot.
"""
function __init__()
  packagePath = packageRoot()
  # Load builtin library if not already in cache (e.g. when precompile workload is disabled)
  if !haskey(NFModelicaBuiltinCache, "NFModelicaBuiltin")
    pathToLib = packagePath * "/lib/NFModelicaBuiltin.mo"
    builtinProg = OMParser.parseFile(pathToLib, 2)
    builtinSCode = Frontend.AbsynToSCode.translateAbsyn2SCode(builtinProg)
    NFModelicaBuiltinCache["NFModelicaBuiltin"] = builtinSCode
  end
  pathToTest = packagePath * "/test/Models/HelloWorld.mo"
  p = OMParser.parseFile(pathToTest, 1)
  s = Frontend.AbsynToSCode.translateAbsyn2SCode(p)
  Frontend.Global.initialize()
  # make sure we have all the flags loaded!
  Frontend.FlagsUtil.loadFlags()
  #= Const Refs bake their precompile-time value; env-derived flags must be
     re-read at load time. =#
  Frontend.PARALLEL_INST[] = get(ENV, "OMFRONTEND_PARALLEL_INST", "true") == "true"
  Frontend.LIBRARY_LOADER[] = _loadLibraryOnDemand
  Frontend.CACHE_INST[] = get(ENV, "OMFRONTEND_CACHE_INST", "true") == "true"
  ENABLE_EXECSTAT[] = get(ENV, "ENABLE_EXECSTAT", "false") == "true"
  builtinSCode = NFModelicaBuiltinCache["NFModelicaBuiltin"]
  program = listAppend(builtinSCode, s)
  path = Frontend.AbsynUtil.stringPath("HelloWorld")
  res1 = Frontend.instClassInProgram(path, program)
  return nothing
end

include("main.jl")
#=Internal modules=#
import .Frontend.Flags
import .Frontend.FlagsUtil
import .Frontend.StructuralModeJSON


"""
Parse a file, returns the syntax tree.
"""
function parseFile(file::String, acceptedGram::Int64 = 1)::Absyn.Program
  return OMParser.parseFile(file, acceptedGram)
end

"""
  Translate the Syntax tree to the SCode intermediate representation
"""
function translateToSCode(inProgram::Absyn.Program)::SCode.Program
  return Frontend.AbsynToSCode.translateAbsyn2SCode(inProgram)
end

"""
  Instantiates and translates to DAE.
  The element to instantiate should be provided in the following format:
  <component>.<component_1>.<component_2>...
"""
function instantiateSCodeToDAE(elementToInstantiate::String, inProgram::SCode.Program)
  # initialize globals
  Frontend.Global.initialize()
  # make sure we have all the flags loaded!
  #Frontend.Flags.new(Flags.emptyFlags)
  local builtinSCode = NFModelicaBuiltinCache["NFModelicaBuiltin"]
  local program = listAppend(builtinSCode, inProgram)
  local path = Frontend.AbsynUtil.stringPath(elementToInstantiate)
  Frontend.instClassInProgram(path, program)
end

#= The classes a model with recompilation directives was instantiated with, beside its own
   top-level class (its libraries, the other classes of its file), by that class's name: its
   recompilation instantiates the modified class with them (recompilationProgram). =#
const RECOMPILATION_PROGRAMS = Dict{String, SCode.Program}()
const RECOMPILATION_PROGRAMS_LOCK = ReentrantLock()

"""
    keepRecompilationProgram!(flatModel::Frontend.FlatModel, inProgram::SCode.Program) -> Nothing

For a model with recompilation directives (its `scodeProgram`, the class a recompilation
modifies), the other classes of `inProgram` (recompilationProgram).
"""
function keepRecompilationProgram!(flatModel::Frontend.FlatModel, inProgram::SCode.Program)::Nothing
  local metaModel = flatModel.scodeProgram
  metaModel isa SOME || return nothing
  local name = Frontend.SCodeUtil.elementName(metaModel.data)
  local others = SCode.Element[cls for cls in inProgram if Frontend.SCodeUtil.elementName(cls) != name]
  lock(RECOMPILATION_PROGRAMS_LOCK) do
    RECOMPILATION_PROGRAMS[name] = arrayList(others)
  end
  return nothing
end

"""
    recompilationProgram(className::String) -> SCode.Program

The classes the model of the top-level class `className` was instantiated with beside it
(keepRecompilationProgram!): with the modified class, the program of its recompilation.
"""
function recompilationProgram(className::String)::SCode.Program
  return lock(() -> get(RECOMPILATION_PROGRAMS, className, nil), RECOMPILATION_PROGRAMS_LOCK)
end

"""
  Instantiates and translates to the flat model representation
  The element to instantiate should be provided in the following format:
  <component>.<component_1>.<component_2>...
"""
function instantiateSCodeToFM(elementToInstantiate::String,
                              inProgram::SCode.Program; scalarize = true,
                              separateInstantiation = false)
  # initialize globals
  Frontend.Global.initialize()
  # make sure we have all the flags loaded!
  #  Frontend.Flags.new(Flags.emptyFlags)
  Frontend.FlagsUtil.set(Frontend.Flags.NF_SCALARIZE, scalarize)
  Frontend.FlagsUtil.set(Frontend.Flags.NF_SEPARATE_INSTANTIATION, separateInstantiation)
  local builtinSCode = NFModelicaBuiltinCache["NFModelicaBuiltin"]
  local program = listReverse(listAppend(builtinSCode, inProgram))
  local path = Frontend.AbsynUtil.stringPath(elementToInstantiate)
  local old_flags = applyCommandLineOptionsAnnotation(path, program)
  local flat_model
  local funcs
  try
    (flat_model, funcs, inst_cls) = Frontend.instClassInProgramFM(path, program)
  finally
    old_flags === nothing || Frontend.FlagsUtil.saveFlags(old_flags)
  end
  keepRecompilationProgram!(flat_model, inProgram)
  return (flat_model, funcs)
end

"""
The cache key of the MSL a model gets when it uses Modelica without loading it (`_loadLibraryOnDemand`); the package
image keeps its parse.
"""
const ON_DEMAND_MSL = "MSL_4_1_0"

#= A library loaded when a model refers to it without loading it (omc loads it from MODELICAPATH):
   the Modelica Standard Library 4.1.0, which holds Modelica, ModelicaServices and Complex. =#
function _loadLibraryOnDemand(name::String)
  name in ("Modelica", "ModelicaServices", "Complex") || return nothing
  loadMSL(MSL_Version = ON_DEMAND_MSL)
  return get(LIBRARY_CACHE, ON_DEMAND_MSL, nothing)
end

"""
  Sets the flags of the class's `__OpenModelica_commandLineOptions` annotation that this port has
  (omc loadCommandLineOptionsFromModel; `--allowNonStandardModelica=...`), unless
  --ignoreCommandLineOptionsAnnotation. Returns the flags before, or nothing when none were set.
"""
function applyCommandLineOptionsAnnotation(path::Frontend.Absyn.Path, program::Frontend.SCode.Program)
  Frontend.Flags.getConfigBool(Frontend.Flags.IGNORE_COMMAND_LINE_OPTIONS_ANNOTATION) && return nothing
  #= A class the program does not have: instantiation reports it (lookup error). =#
  local elem = try
    Frontend.SCodeUtil.getElementWithPath(program, path)
  catch
    return nothing
  end
  local ob = Frontend.SCodeUtil.getModifierBinding(
    Frontend.SCodeUtil.lookupElementAnnotation(elem, "__OpenModelica_commandLineOptions"))
  isSome(ob) || return nothing
  local e = Frontend.Util.getOption(ob)
  e isa Frontend.Absyn.STRING || return nothing
  local known = Set{String}(f.name for f in Frontend.FlagsUtil.allConfigFlags)
  local args = String[]
  for a in split(e.value)
    local m = match(r"^--([A-Za-z]+)(=.*)?$", a)
    (m !== nothing && m.captures[1] in known) && push!(args, String(a))
  end
  isempty(args) && return nothing
  local old_flags = Frontend.FlagsUtil.backupFlags()
  #= One at a time: a value the port's flag does not take (--std=experimental) is skipped. =#
  for a in args
    Frontend.ErrorExt.setCheckpoint("applyCommandLineOptionsAnnotation")
    try
      Frontend.FlagsUtil.readArgs(list(a))
    catch
    end
    Frontend.ErrorExt.rollBack("applyCommandLineOptionsAnnotation")
  end
  return old_flags
end

"""
```
  exportDAERepresentationToFile(fileName::String, contents::String)
```
  Prints the DAE representation to a file
"""
function exportDAERepresentationToFile(fileName::String, contents::String)
  local fdesc = open(fileName, "w")
  write(fdesc, contents)
  close(fdesc)
end

"""
  ```toString(model::FlatModel)```
    Converts the flat model representation to a Julia String, the extra \\n are replaced with \n
"""
function toString(model::Frontend.FlatModel)
  local res = Frontend.toString(model)
  local res = replace(res, "\\n" => "\n")
  return res
end

function toString(fmFuncs::Tuple)
  local model = first(fmFuncs)
  local funcs = last(fmFuncs)
  local res = Frontend.toString(model)
  res *= string(funcs)
  res = replace(res, "\\n" => "\n")
  return res
end

"""
  Overload the Julia to string function
"""
function Base.string(model::Frontend.FlatModel)
  return toString(model::Frontend.FlatModel)
end

"""
  Converts a function tree to a string
"""
function Base.string(ft::Frontend.FunctionTreeImpl.Tree)
  local fLst = OMFrontend.Frontend.FunctionTreeImpl.toList(ft)
  local buffer = IOBuffer()
  for (_, v) in fLst
    println(buffer, OMFrontend.Frontend.toFlatString(v))
  end
  return replace(String(take!(buffer)), "\\n" => "\n")
end

"""
    toFlatModelica(fm, fLst; printBindingTypes = false)
    toFlatModelica((fm, fLst); printBindingTypes = false)

Render a flat model and its function tree as textual flat Modelica.
"""
function toFlatModelica(fm, fLst::List; printBindingTypes = false)
  s = replace(Frontend.toFlatString(fm, fLst, printBindingTypes), "\\n" => "\n")
  s = replace(s, "OMC_NO_CLOCK.sample" => "sample")
  s = replace(s, "'AssertionLevel'" => "AssertionLevel")
  return s
end

function toFlatModelica(fm, fLst::Frontend.FunctionTreeImpl.NODE; printBindingTypes = false)
  s = replace(Frontend.toFlatString(fm, cacheToFunctionList(fLst), printBindingTypes), "\\n" => "\n")
  s = replace(s, "OMC_NO_CLOCK.sample" => "sample")
  s = replace(s, "'AssertionLevel'" => "AssertionLevel")
  return s
end

function toFlatModelica(flatModelicaAndFunctionTree::Tuple;
                        printBindingTypes = false)
  local fLst = cacheToFunctionList(last(flatModelicaAndFunctionTree))
  local fm = first(flatModelicaAndFunctionTree)
  s = replace(Frontend.toFlatString(fm, fLst, printBindingTypes), "\\n" => "\n")
  s = replace(s, "OMC_NO_CLOCK.sample" => "sample")
  s = replace(s, "'AssertionLevel'" => "AssertionLevel")
  return s
end

function writeFlatModelicaToFile(fm, fLst;
                                 printBindingtypes = false,
                                 fileName,
                                 removeQuotes::Bool)
  local fmStr = toFlatModelica(fm,
                               fLst;
                               printBindingTypes = printBindingtypes,)
  fmStr = if removeQuotes
    removeQuotesFromFlatModelica(fmStr)
  else
    fmStr
  end
  f = write(fileName, fmStr)
  #close(f)
end

"""
  Converts the function cache represented as a tree where the path is the key into a list of functions
"""
function cacheToFunctionList(cache)
  fLst = OMFrontend.Frontend.FunctionTreeImpl.toList(cache)
  fv = map(fLst) do kv
    last(kv)
  end
  arrayList(fv)
end

"""
  Dumps the SCode representation of a Modelica model to a file.
"""
function exportSCodeRepresentationToFile(fileName::String, contents::List{SCode.CLASS})
  local fdesc = open(fileName, "w")
  local processedContents = replace(string(contents), "," => ",\n")
  write(fdesc, processedContents)
  close(fdesc)
end

#= Pretty-print an MSL/library cache key for user-facing log lines.
   `"MSL_3_2_3"` becomes `"Modelica 3.2.3"`, `"Modelica_4_1_0"` becomes
   `"Modelica 4.1.0"`. Falls back to the raw key when the pattern does not
   match. =#
function _displayMSLKey(key::AbstractString)::String
  m = match(r"^(?:MSL|Modelica)[_:](\d+)[_.](\d+)[_.](\d+)$", String(key))
  m === nothing && return String(key)
  return "Modelica " * m.captures[1] * "." * m.captures[2] * "." * m.captures[3]
end

function initLoadMSL(;MSL_Version = "MSL:3.2.3", forceReload::Bool = false)
  Base.depwarn("`initLoadMSL` is deprecated; use `loadInstalledLibrary(\"Modelica\"; version=...)` instead.", :initLoadMSL)
  @info "Loading MSL\n\t Version: $(_displayMSLKey(MSL_Version))"
  MSL_Version = replace(MSL_Version, "." => "_")
  MSL_Version = replace(MSL_Version, ":" => "_")
  if forceReload
    delete!(LIBRARY_CACHE, MSL_Version)
  end
  @time return loadMSL(MSL_Version = MSL_Version)
  @info "MSL successfully Loaded"
end

"""
`function flattenModelWithMSL(modelName::String, fileName::String; MSL_Version = "MSL:3.2.3", forceReload = false)`

Returns the flat representation of a modelica model along with the functions used and define by the model.
See the keyword argument for specifying MSL version.
Valid versions are 3.2.3 and 4.1.0.

When `forceReload` is true, any cached MSL under this version key is dropped
and the standard library is reparsed and re-translated from disk. This is useful
when the on-disk MSL has changed during the session, or to force a clean
benchmark of the MSL load path.
"""
function flattenModelWithMSL(modelName::String,
                             fileName::String;
                             MSL_Version = "MSL:3.2.3",
                             scalarize = true,
                             forceReload::Bool = false)
  Base.depwarn("`flattenModelWithMSL` is deprecated; use `flattenModelWithLibraries` instead.", :flattenModelWithMSL)
  # `loadMSL` stores the cache entry under the normalized key (no `.` or `:`),
  # so we must normalize before consulting `LIBRARY_CACHE`. Otherwise the
  # haskey check always misses for the conventional `"MSL:3.2.3"` form and
  # MSL is reloaded on every call.
  local mslKey = replace(replace(MSL_Version, "." => "_"), ":" => "_")
  if forceReload
    delete!(LIBRARY_CACHE, mslKey)
  end
  if !haskey(LIBRARY_CACHE, mslKey)
    initLoadMSL(MSL_Version = MSL_Version)
  end
  local lib = LIBRARY_CACHE[mslKey]
  local absynProgram = parseFile(fileName)
  local sCodeProgram = translateToSCode(absynProgram)
  #= Add builtin function to the program (model) and instantiate it =#
  builtin = NFModelicaBuiltinCache["NFModelicaBuiltin"]
  #program = listReverse(listAppend(sCodeProgram, builtin))
  program = listAppend(sCodeProgram, lib)
  #println("Attempting to instantiate..." * modelName)
  (FM, cache) = instantiateSCodeToFM(modelName, program; scalarize = scalarize)
end

"""
`function flattenModelWithMSL(modelName::String; MSL_Version = "MSL:3.2.3", scalarize = true, forceReload = false)`

Flatten an MSL model by name. When `forceReload` is true, the cached MSL
under this version key is dropped and the standard library is reparsed and
re-translated from disk before the model is instantiated.
"""
function flattenModelWithMSL(modelName::String;
                             MSL_Version = "MSL:3.2.3",
                             scalarize = true,
                             forceReload::Bool = false)
  Base.depwarn("`flattenModelWithMSL` is deprecated; use `flattenModelWithLibraries` instead.", :flattenModelWithMSL)
  # See note on the other `flattenModelWithMSL` overload: normalize the key
  # before the cache lookup so the cache is actually consulted.
  local mslKey = replace(replace(MSL_Version, "." => "_"), ":" => "_")
  if forceReload
    delete!(LIBRARY_CACHE, mslKey)
  end
  if !haskey(LIBRARY_CACHE, mslKey)
    initLoadMSL(MSL_Version = MSL_Version)
  end
  local lib = LIBRARY_CACHE[mslKey]
  (FM, cache) = instantiateSCodeToFM(modelName, lib; scalarize = scalarize)
end

"""
`flattenModel(modelName::String, fileName::String)`

Returns the flat representation of a modelica model along with the functions used and define by the model.
"""
function flattenModel(modelName::String, fileName::String; scalarize = true,
                      separateInstantiation = false)
  local absynProgram = parseFile(fileName)
  local sCodeProgram = translateToSCode(absynProgram)
  (FM, cache) = instantiateSCodeToFM(modelName, sCodeProgram; scalarize = scalarize,
                                     separateInstantiation = separateInstantiation)
end

"""
  @author: johti17
  Loads the Modelica Standard Library (MSL).
  Adds the Modelica standard library to the library cache.
Currently 3.2.3 is the default version.

Available versions are:
4.1.0
3.2.3
"""
function loadMSL(; MSL_Version)
  MSL_Version = replace(MSL_Version, "." => "_")
  MSL_Version = replace(MSL_Version, ":" => "_")
  if ! haskey(LIBRARY_CACHE, MSL_Version)
    Frontend.Global.initialize()
    try
      @info "Loading MSL.."
      local pathToLib = joinpath(packageRoot(), "lib", "Modelica", string(MSL_Version, ".mo"))
      local contentHash = _computeLibHash(pathToLib)
      if _loadLibCache(MSL_Version, contentHash)
        return LIBRARY_CACHE[MSL_Version]
      end
      @info "Initial parsing of the MSL..."
      @time local p = parseFile(pathToLib)
      local scodeMSL = OMFrontend.translateToSCode(p)
      _storeLibrary!(MSL_Version, scodeMSL)
      _saveLibCache(MSL_Version, contentHash)
      return scodeMSL
    catch e
      @info "Failed loading the Modelica Standard Library. Valid versions are 3.2.3 and 4.1.0"
      @info "Continue instantiating the model until the next error."
    end
  end
end

"""
    loadBundledMSL(; version = "3.2.3") -> String

Load the Modelica Standard Library from the bundled `lib/Modelica/` files,
independent of any OpenModelica installation. Returns the cache key.

`version` may be given as `"3.2.3"`, `"4.1.0"`, or the already-normalised
form `"MSL_3_2_3"`. The returned key can be passed to `flattenModelWithLibraries`
or `instantiateSCodeToFM`.

This is the loader used by the test suite so results do not depend on the
local OpenModelica installation.

# Example
```julia
key = OMFrontend.loadBundledMSL()
(FM, _) = OMFrontend.flattenModelWithLibraries("My.Model", "model.mo"; libraries=[key])
```
"""
function loadBundledMSL(; version::String = "3.2.3")::String
  local norm = replace(replace(version, "." => "_"), ":" => "_")
  local cacheKey = startswith(norm, "MSL_") ? norm : "MSL_" * norm
  loadMSL(MSL_Version = cacheKey)
  return cacheKey
end

"""
    loadLibrary(libraryPath::String; name::Union{String, Nothing} = nothing)

Load an arbitrary Modelica library from a single `.mo` file into the library
cache. Returns the cache key (a string) that can be passed to `translate` or
`simulate` via the `libraries` keyword argument.

If `name` is not provided, the cache key is derived from the top-level class
name in the parsed file.

# Example
```julia
key = OMFrontend.loadLibrary("/path/to/MyLib.mo")
# key == "MyLib"
```
"""
function loadLibrary(libraryPath::String; name::Union{String, Nothing} = nothing)
  Frontend.Global.initialize()
  @info "Loading library from $libraryPath..."
  local p = parseFile(libraryPath)
  local scodeProg = translateToSCode(p)
  local cacheKey = if name !== nothing
    name
  else
    local firstClass = listHead(scodeProg)
    firstClass.name
  end
  _storeLibrary!(cacheKey, scodeProg)
  LIBRARY_ROOTS[listHead(scodeProg).name] = dirname(abspath(libraryPath))
  @info "Loaded library '$cacheKey' from $libraryPath"
  return cacheKey
end

function _libCacheDir()::String
  local dir = joinpath(homedir(), ".julia", "cache", "OMFrontend")
  mkpath(dir)
  return dir
end

function _computeLibHash(path::String)::String
  local h::UInt64 = hash(string(VERSION))
  if isfile(path)
    local st = stat(path)
    h = hash((path, st.mtime, st.size), h)
  else
    for (root, _, files) in walkdir(path)
      for f in sort(files)
        endswith(f, ".mo") || continue
        local fp = joinpath(root, f)
        local st = stat(fp)
        h = hash((fp[length(path)+1:end], st.mtime, st.size), h)
      end
    end
  end
  return string(h, base = 16)
end

function _libCachePath(cacheKey::String, contentHash::String)::String
  local safeName = replace(cacheKey, r"[/\\ ]" => "_")
  return joinpath(_libCacheDir(), "$(safeName)__$(contentHash).jls")
end

function _saveLibCache(cacheKey::String, contentHash::String)
  local path = _libCachePath(cacheKey, contentHash)
  try
    open(path, "w") do io
      Serialization.serialize(io, LIBRARY_CACHE[cacheKey])
    end
    @info "Library '$cacheKey' cached to disk."
  catch e
    @warn "Could not write library cache: $e"
    rm(path; force = true)
  end
end

function _loadLibCache(cacheKey::String, contentHash::String)::Bool
  local path = _libCachePath(cacheKey, contentHash)
  isfile(path) || return false
  try
    local prog = open(path, "r") do io
      Serialization.deserialize(io)
    end
    _storeLibrary!(cacheKey, prog)
    @info "Library '$(_displayMSLKey(cacheKey))' loaded from disk cache."
    return true
  catch e
    @warn "Disk cache stale or incompatible, re-parsing: $e"
    rm(path; force = true)
    return false
  end
end

"""
    loadPackageDirectory(dirPath::String; name=nothing) -> String

Load a Modelica library organized as a directory tree with `package.mo` files.
Each `.mo` file is parsed individually and merged into a single SCode program
based on its `within` clause.

Returns the cache key (a string) for use in `translate`/`simulate` via the
`libraries` keyword argument.

# Directory structure
```
MyLibrary/
  package.mo          # top-level package declaration
  package.order       # optional: class ordering (one name per line)
  SomeModel.mo        # "within MyLibrary; model SomeModel ..."
  SubPackage/
    package.mo        # "within MyLibrary; package SubPackage ..."
    AnotherModel.mo   # "within MyLibrary.SubPackage; model AnotherModel ..."
```

# Example
```julia
key = OMFrontend.loadPackageDirectory("/path/to/MyLibrary")
# key == "MyLibrary"
```
"""
function loadPackageDirectory(dirPath::String; name::Union{String, Nothing} = nothing)
  Frontend.Global.initialize()
  dirPath = String(rstrip(dirPath, '/'))
  local rootFile = joinpath(dirPath, "package.mo")
  if !isfile(rootFile)
    error("No package.mo found in '$dirPath'. Not a valid Modelica package directory.")
  end

  #= Compute content hash for disk-cache lookup/invalidation =#
  local contentHash = _computeLibHash(dirPath)

  #= Determine cache key from root package name (needed before parsing) =#
  #= Try disk cache first — if hit, skip all parsing =#
  local cacheKey::String = name !== nothing ? name : ""
  if !isempty(cacheKey) && _loadLibCache(cacheKey, contentHash)
    LIBRARY_ROOTS[cacheKey] = abspath(dirPath)
    return cacheKey
  end

  @info "Loading directory-based package from $dirPath..."

  #= Step 1: Parse root package.mo =#
  local rootAbsyn = parseFile(rootFile)
  local rootSCode = translateToSCode(rootAbsyn)
  local rootClass = listHead(rootSCode)
  local rootName = rootClass.name
  #= its modelica:// URIs (loadResource, an external function's IncludeDirectory) resolve in this directory =#
  LIBRARY_ROOTS[rootName] = abspath(dirPath)
  if isempty(cacheKey)
    cacheKey = rootName
    if _loadLibCache(cacheKey, contentHash)
      return cacheKey
    end
  end

  #= Step 2: Collect all child .mo files (excluding root package.mo) =#
  local childFiles = _collectMoFiles(dirPath)
  @info "Found $(length(childFiles)) child file(s) in package"

  #= Step 3: Parse each child, extract within path and SCode class =#
  local children = Tuple{String, SCode.Element}[]
  for moFile in childFiles
    local absynProg = parseFile(moFile)
    local withinPath = _extractWithinPath(absynProg)
    local scodeProg = translateToSCode(absynProg)
    for cls in scodeProg
      push!(children, (withinPath, cls))
    end
  end

  #= Step 4: Insert all children into the root package tree =#
  local mergedClass = rootClass
  for (withinPath, child) in children
    mergedClass = _insertIntoPackage(mergedClass, child, withinPath, rootName)
  end

  #= Step 5: Store in memory cache and persist to disk =#
  _storeLibrary!(cacheKey, list(mergedClass))
  @info "Loaded directory package '$cacheKey' from $dirPath ($(length(children)) classes)"
  _saveLibCache(cacheKey, contentHash)
  return cacheKey
end

"""
    _collectMoFiles(dirPath) -> Vector{String}

Recursively collect `.mo` files in a package directory, respecting `package.order`.
Sub-package `package.mo` files are included before their children.
The root `package.mo` is excluded (handled separately by the caller).
"""
function _collectMoFiles(dirPath::AbstractString)::Vector{String}
  local files = String[]
  local order = _readPackageOrder(dirPath)
  local entries = readdir(dirPath; join=false)

  #= Determine processing order =#
  local ordered::Vector{String}
  if order !== nothing
    #= Use package.order: process listed entries first, then any unlisted ones =#
    local remaining = filter(n -> !(n in order), entries)
    sort!(remaining)
    ordered = vcat(order, remaining)
  else
    ordered = sort(entries)
  end

  for entry in ordered
    local fullPath = joinpath(dirPath, entry)
    if isdir(fullPath) && isfile(joinpath(fullPath, "package.mo"))
      #= Sub-package: add its package.mo first, then recurse =#
      push!(files, joinpath(fullPath, "package.mo"))
      append!(files, _collectMoFiles(fullPath))
    elseif isfile(fullPath) && endswith(entry, ".mo") && entry != "package.mo"
      push!(files, fullPath)
    end
  end
  return files
end

"""
    _readPackageOrder(dirPath) -> Union{Vector{String}, Nothing}

Read the `package.order` file if it exists. Returns a list of class/entry names
(one per line, comments and blank lines stripped), or nothing if no file exists.
"""
function _readPackageOrder(dirPath::AbstractString)::Union{Vector{String}, Nothing}
  local orderFile = joinpath(dirPath, "package.order")
  if !isfile(orderFile)
    return nothing
  end
  local rawLines = readlines(orderFile)
  local lines = String[]
  for line in rawLines
    local stripped = strip(line)
    if !isempty(stripped) && !startswith(stripped, "//")
      push!(lines, String(stripped))
    end
  end
  return lines
end

"""
    _extractWithinPath(prog::Absyn.Program) -> String

Extract the `within` clause from an Absyn.Program and convert to a dot-separated
path string. Returns "" for top-level (no within clause).
"""
function _extractWithinPath(prog::Absyn.Program)::String
  @match Absyn.PROGRAM(within_ = w) = prog
  return begin
    @match w begin
      Absyn.TOP() => ""
      Absyn.WITHIN(path) => _absynPathToString(path)
    end
  end
end

function _absynPathToString(path::Absyn.Path)::String
  @match path begin
    Absyn.IDENT(name) => name
    Absyn.QUALIFIED(name, rest) => string(name, ".", _absynPathToString(rest))
    Absyn.FULLYQUALIFIED(p) => _absynPathToString(p)
  end
end

"""
    _insertIntoPackage(pkg, child, withinPath, currentPath) -> SCode.Element

Insert a child SCode.Element into the correct location in the package tree.
`withinPath` is the dot-separated path from the child's `within` clause.
`currentPath` is the dot-separated path of the current package being examined.
"""
function _insertIntoPackage(pkg::SCode.Element, child::SCode.Element,
                            withinPath::String, currentPath::String)::SCode.Element
  #= Does this child belong directly in this package? =#
  if withinPath == currentPath
    @match SCode.CLASS(classDef = SCode.PARTS(elementLst = els)) = pkg
    local newEls = listAppend(els, list(child))
    return _rebuildClassWithElements(pkg, newEls)
  end

  #= Otherwise, find the sub-package to recurse into =#
  local prefix = currentPath * "."
  if !startswith(withinPath, prefix)
    @warn "Cannot insert class: within path '$withinPath' does not match current path '$currentPath'"
    return pkg
  end
  local suffix = withinPath[length(prefix)+1:end]
  local nextSegment = String(split(suffix, ".")[1])

  #= Find and update the sub-package in elementLst =#
  @match SCode.CLASS(classDef = SCode.PARTS(elementLst = els)) = pkg
  local newEls = nil
  local found = false
  for el in els
    if isa(el, SCode.CLASS) && el.name == nextSegment
      local updatedSub = _insertIntoPackage(el, child, withinPath,
                                            string(currentPath, ".", nextSegment))
      newEls = _cons(updatedSub, newEls)
      found = true
    else
      newEls = _cons(el, newEls)
    end
  end
  newEls = listReverse(newEls)
  if !found
    @warn "Sub-package '$nextSegment' not found in '$currentPath' for within path '$withinPath'"
  end
  return _rebuildClassWithElements(pkg, newEls)
end

"""
    _rebuildClassWithElements(cls, newEls) -> SCode.Element

Reconstruct an SCode.CLASS with a new elementLst, preserving all other fields.
"""
function _rebuildClassWithElements(cls::SCode.Element, newEls)::SCode.Element
  @match SCode.CLASS(name, prefixes, encap, partial_, restriction,
                     SCode.PARTS(_, normalEqs, initEqs, normalAlgs,
                                 initAlgs, constraints, clsattrs, extDecl),
                     cmt, info) = cls
  local newDef = SCode.PARTS(newEls, normalEqs, initEqs, normalAlgs,
                             initAlgs, constraints, clsattrs, extDecl)
  return SCode.CLASS(name, prefixes, encap, partial_, restriction, newDef, cmt, info)
end

"""
    omjlLibraryDir() -> String

The directory `installLibrary` installs libraries into: `~/OMJL/libraries`, on Windows `%APPDATA%\\OMJL\\libraries`.
"""
omjlLibraryDir()::String = Sys.iswindows() ? joinpath(_appData(), "OMJL", "libraries") : joinpath(homedir(), "OMJL", "libraries")

"""
    openModelicaLibraryDir() -> String

OpenModelica's directory of installed libraries (its package manager's): `~/.openmodelica/libraries`, on Windows
`%APPDATA%\\.openmodelica\\libraries`.
"""
openModelicaLibraryDir()::String =
  Sys.iswindows() ? joinpath(_appData(), ".openmodelica", "libraries") : joinpath(homedir(), ".openmodelica", "libraries")

"""
Windows' roaming application data directory (`%APPDATA%`).
"""
_appData()::String = get(ENV, "APPDATA", joinpath(homedir(), "AppData", "Roaming"))

"""
    libraryDirectories() -> Vector{String}

The directories of installed libraries `libraries` searches, in order: OM.jl's (`omjlLibraryDir`), then
OpenModelica's (`openModelicaLibraryDir`).
"""
libraryDirectories()::Vector{String} = [omjlLibraryDir(), openModelicaLibraryDir()]

"""
    libraries(; installDir = nothing) -> Dict{String, Vector{NamedTuple}}

Discover Modelica libraries available for loading. Searches, in order:

1. The directories of installed libraries (`libraryDirectories`): OM.jl's, `~/OMJL/libraries` (`installLibrary`
   installs there), then OpenModelica's, `~/.openmodelica/libraries` (on Windows both under `%APPDATA%`). Only
   `installDir` when it is given.
2. The bundled `lib/Modelica/` directory inside this package, excluding the
   pre-packaged `MSL_*` single-file variants.

Returns a `Dict` mapping library name to a `Vector` of `(version, path, source)`
named tuples, where `source` is `:installed` or `:bundled`.

# Example
```julia
avail = OMFrontend.libraries()
# avail["Modelica"] => [(version="4.1.0", path="...", source=:installed), ...]
```
"""
function libraries(; installDir::Union{String, Nothing} = nothing)
  local result = Dict{String, Vector{@NamedTuple{version::String, path::String, source::Symbol}}}()
  function _add!(name, version, path, source)
    local entry = (version = version, path = path, source = source)
    if haskey(result, name)
      push!(result[name], entry)
    else
      result[name] = [entry]
    end
  end
  for omDir in (installDir !== nothing ? [installDir] : libraryDirectories())
    isdir(omDir) || continue
    for entry in sort(readdir(omDir))
      local fullPath = joinpath(omDir, entry)
      isdir(fullPath) || continue
      isfile(joinpath(fullPath, "package.mo")) || continue
      local spaceIdx = findfirst(isequal(' '), entry)
      local name = spaceIdx !== nothing ? entry[1:spaceIdx-1] : entry
      local version = spaceIdx !== nothing ? entry[spaceIdx+1:end] : ""
      _add!(name, version, fullPath, :installed)
    end
  end
  local bundledDir = joinpath(packageRoot(), "lib", "Modelica")
  if isdir(bundledDir)
    for entry in sort(readdir(bundledDir))
      startswith(entry, "MSL_") && continue
      local fullPath = joinpath(bundledDir, entry)
      if isdir(fullPath) && isfile(joinpath(fullPath, "package.mo"))
        local spaceIdx = findfirst(isequal(' '), entry)
        local name = spaceIdx !== nothing ? entry[1:spaceIdx-1] : splitext(entry)[1]
        local version = spaceIdx !== nothing ? entry[spaceIdx+1:end] : ""
        _add!(name, version, fullPath, :bundled)
      elseif isfile(fullPath) && endswith(entry, ".mo")
        _add!(splitext(entry)[1], "", fullPath, :bundled)
      end
    end
  end
  return result
end

"""
    _parseUsesDeps(path) -> Dict{String, String}

Parse the `uses(...)` annotation from a `package.mo` file and return a
`name => version` dict of declared library dependencies.
`path` may be a directory (reads `package.mo` inside) or a direct `.mo` file.
"""
function _parseUsesDeps(path::String)::Dict{String, String}
  local pkgMo = isdir(path) ? joinpath(path, "package.mo") : path
  isfile(pkgMo) || return Dict{String, String}()
  local text = read(pkgMo, String)
  local m = match(r"uses\s*\(", text)
  m === nothing && return Dict{String, String}()
  local start = m.offset + length(m.match)
  local depth = 1
  local i = start
  while i <= lastindex(text) && depth > 0
    c = text[i]
    if c == '('
      depth += 1
    elseif c == ')'
      depth -= 1
    end
    i += 1
  end
  local usesContent = text[start : i - 2]
  local deps = Dict{String, String}()
  for dep in eachmatch(r"(\w[\w.]*)\s*\(\s*version\s*=\s*\"([^\"]+)\"", usesContent)
    deps[dep.captures[1]] = dep.captures[2]
  end
  return deps
end

"""
    loadInstalledLibrary(name; version = nothing, forceReload = false, autodeps = true, installDir = nothing) -> String

Load a Modelica library discovered via `libraries`. Installed OpenModelica
libraries are searched first, then the bundled `lib/Modelica/` directory.

If `version` is omitted the first available version is used. If given, an exact
match is tried before a prefix match (e.g. `"4.1"` matches `"4.1.0"`).

When `autodeps = true` (default), the `uses(...)` annotation of the loaded
`package.mo` is parsed and any declared dependencies that are available via
`libraries()` are loaded automatically before returning. Their keys are recorded
in `LIBRARY_DEPENDENCIES`, so flattening with the returned key alone also uses them.
`installDir` is the directory of installed libraries (see `libraries`).

Returns the cache key under which the library is stored in `LIBRARY_CACHE`.

# Example
```julia
OMFrontend.loadInstalledLibrary("Modelica"; version = "4.1.0")
OMFrontend.loadInstalledLibrary("Buildings")   # auto-loads Modelica + ModelicaServices
```
"""
function loadInstalledLibrary(name::String;
                              version::Union{String, Nothing} = nothing,
                              forceReload::Bool = false,
                              autodeps::Bool = true,
                              installDir::Union{String, Nothing} = nothing)::String
  local avail = libraries(; installDir = installDir)
  if !haskey(avail, name)
    error("Library '$name' not found. Run `libraries()` to see what is available.")
  end
  local entries = avail[name]
  local entry = if version === nothing
    first(entries)
  else
    local exact = findfirst(e -> e.version == version, entries)
    local idx = exact !== nothing ? exact :
                findfirst(e -> startswith(e.version, version), entries)
    idx === nothing &&
      error("Library '$name' version '$version' not found. Available: $(map(e -> e.version, entries))")
    entries[idx]
  end
  LIBRARY_ROOTS[name] = isdir(entry.path) ? String(rstrip(entry.path, '/')) : dirname(entry.path)
  local cleanVer = replace(split(entry.version, "+")[1], "." => "_")
  local cacheKey = isempty(cleanVer) ? name : string(name, "_", cleanVer)
  if forceReload
    delete!(LIBRARY_CACHE, cacheKey)
    delete!(LIBRARY_DEPENDENCIES, cacheKey)
  end
  if haskey(LIBRARY_CACHE, cacheKey)
    @info "Library '$cacheKey' already cached."
    return cacheKey
  end
  #= the libraries it uses, resolved before it is parsed: a missing one stops the load here, by name, not as a
     MatchFailure of the flattening later =#
  local resolved = autodeps ? _resolveDependencies(name, entry, installDir) : Tuple{String, Symbol, String}[]
  if isdir(entry.path)
    loadPackageDirectory(entry.path; name = cacheKey)
  else
    loadLibrary(entry.path; name = cacheKey)
  end
  if autodeps
    local depKeys = String[]
    for (depName, source, depVer) in resolved
      local depKey = try
        source === :bundled ? loadBundledMSL(version = depVer) :
          loadInstalledLibrary(depName; version = depVer, autodeps = true, installDir = installDir)
      catch e
        error("Library '$name $(entry.version)' uses '$depName $depVer', which could not be loaded: " *
              sprint(showerror, e))
      end
      depKey in depKeys || push!(depKeys, depKey)
    end
    LIBRARY_DEPENDENCIES[cacheKey] = depKeys
  end
  return cacheKey
end

"""
The MSL versions bundled as single files (`lib/Modelica/MSL_X_Y_Z.mo`), e.g. `["3.2.3", "4.1.0"]`.
"""
function _bundledMSLVersions()::Vector{String}
  local dir = joinpath(packageRoot(), "lib", "Modelica")
  isdir(dir) || return String[]
  local versions = String[]
  for f in readdir(dir)
    local m = match(r"^MSL_(\d+)_(\d+)_(\d+)\.mo$", f)
    m === nothing || push!(versions, join(m.captures, "."))
  end
  return versions
end

"""
A library version as a VersionNumber for ordering (`"4.1.0+maint.om"` is 4.1.0); `v"0"` when it is none.
"""
_versionOf(version::AbstractString)::VersionNumber =
  something(tryparse(VersionNumber, String(first(split(version, "+")))), v"0")

"""
The packages of the MSL, which a bundled MSL file holds together.
"""
const MSL_PACKAGES = ("Modelica", "ModelicaServices", "Complex")

"""
    _resolveDependency(depName, depVer, avail) -> Union{Nothing, Tuple{Symbol, String}}

Where the library `depName`, used in version `depVer`, comes from: `(:installed, version)` for an installed version
matching exactly or as a prefix, else the newest installed one of the same major version (libraries keep their
interface within a major version: MSL 4.1.0 for a `uses` of 4.0.0); `(:bundled, version)` for a package of the MSL
from the bundled MSL of that major version; `nothing` when there is none.
"""
function _resolveDependency(depName::String, depVer::String, avail::AbstractDict)::Union{Nothing, Tuple{Symbol, String}}
  local entries = get(avail, depName, nothing)
  local major = first(split(depVer, "."))
  if entries !== nothing
    local exact = findfirst(e -> e.version == depVer, entries)
    exact === nothing && (exact = findfirst(e -> startswith(e.version, depVer), entries))
    exact === nothing || return (:installed, entries[exact].version)
    local compatible = filter(e -> first(split(e.version, ".")) == major, entries)
    if !isempty(compatible)
      local newest = compatible[argmax(map(e -> _versionOf(e.version), compatible))]
      @info "'$depName $depVer' is not installed: the installed $(newest.version) of the same major version is used"
      return (:installed, newest.version)
    end
  end
  if depName in MSL_PACKAGES
    local bundled = filter(v -> first(split(v, ".")) == major, _bundledMSLVersions())
    if !isempty(bundled)
      local v = bundled[argmax(map(_versionOf, bundled))]
      v == depVer || @info "'$depName $depVer' is not installed: the bundled MSL $v is used"
      return (:bundled, v)
    end
  end
  return nothing
end

"""
    _resolveDependencies(name, entry, installDir) -> Vector{Tuple{String, Symbol, String}}

The libraries the `uses` annotation of `entry` (a library from `libraries`) names, each with where it comes from
(`_resolveDependency`): `(name, :installed | :bundled, version)`. An error naming every one that is missing and how
to install it.
"""
function _resolveDependencies(name::String, entry::NamedTuple, installDir::Union{String, Nothing})::Vector{Tuple{String, Symbol, String}}
  local avail = libraries(; installDir = installDir)
  local resolved = Tuple{String, Symbol, String}[]
  local absent = String[]
  for (depName, depVer) in sort(collect(_parseUsesDeps(entry.path)))
    local r = _resolveDependency(depName, depVer, avail)
    if r === nothing
      local have = haskey(avail, depName) ? " (installed: $(join(map(e -> e.version, avail[depName]), ", ")))" : ""
      push!(absent, "$depName $depVer$have")
    else
      push!(resolved, (depName, r[1], r[2]))
    end
  end
  isempty(absent) && return resolved
  local dir = installDir !== nothing ? installDir : omjlLibraryDir()
  error("Library '$name $(entry.version)' uses libraries that are not installed: $(join(absent, "; ")). " *
        "Install them (installLibrary(name; version, url), OpenModelica's package manager, or a folder " *
        "'<Name> <version>' with its package.mo in $dir), or load it with autodeps = false.")
end

"""
    libraryClosure(keys) -> Vector{String}

`keys` followed by the libraries they use (`LIBRARY_DEPENDENCIES`, transitively),
each once, in that order of priority for name resolution.
"""
function libraryClosure(keys::Vector{String})::Vector{String}
  local closure = String[]
  local pending = copy(keys)
  while !isempty(pending)
    local key = popfirst!(pending)
    key in closure && continue
    push!(closure, key)
    append!(pending, get(LIBRARY_DEPENDENCIES, key, String[]))
  end
  return closure
end

"""
The libraries loaded into the session (`useLibrary!`), by cache key, in load order: `flattenModelWithLibraries`
(`withLoadedLibraries`) adds them and the libraries they use (`loadedLibraries`) without `libraries`, as omc sees
the classes it loaded. `LIBRARY_CACHE`
keeps every parse, loaded or not: the bundled MSL a model gets without loading it (`ON_DEMAND_MSL`), a library a
call names in `libraries`.
"""
const LOADED_LIBRARIES = String[]

"""
    loadedLibraries() -> Vector{String}

The libraries loaded into the session (`useLibrary!`): their keys in load order, each followed by the libraries it
uses (`libraryClosure`).
"""
loadedLibraries()::Vector{String} = libraryClosure(LOADED_LIBRARIES)

"""
The names of the top-level classes of a program.
"""
function _classNames(program::SCode.Program)::Vector{String}
  local names::Vector{String} = String[]
  for c in program
    c isa SCode.CLASS && push!(names, c.name)
  end
  return names
end

"""
    libraryClassNames(key) -> Vector{String}

The names of the top-level classes of the cached library `key` (`["Modelica", "ModelicaServices", "Complex"]` for a
bundled MSL); none when it is not cached.
"""
libraryClassNames(key::String)::Vector{String} = haskey(LIBRARY_CACHE, key) ? _classNames(LIBRARY_CACHE[key]) : String[]

"""
The loaded library (`LOADED_LIBRARIES`) that loads the library `key`: `key` itself, or the first one that uses it.
"""
function _loadedBy(key::String)::String
  key in LOADED_LIBRARIES && return key
  local users::Vector{String} = filter(k -> key in libraryClosure([k]), LOADED_LIBRARIES)
  return isempty(users) ? key : first(users)
end

"""
How to stop using the loaded library `key`: unload it, or the loaded library that uses it.
"""
function _unloadHint(key::String)::String
  local owner::String = _loadedBy(key)
  return owner == key ? "unloadLibrary(\"$key\")" : "unloadLibrary(\"$owner\"), which uses '$key'"
end

"""
    _checkNameClash(key, own, names) -> Nothing

An error when a loaded library other than `own` (the library `key` and the ones it uses) has one of the top-level
classes `names`: two loaded libraries may not share a top-level name (Modelica 3.2.3 and 4.1.0). It names both
libraries and how to unload the loaded one.
"""
function _checkNameClash(key::String, own::Vector{String}, names::Vector{String})::Nothing
  for other::String in loadedLibraries()
    other in own && continue
    local shared::Vector{String} = intersect(libraryClassNames(other), names)
    isempty(shared) && continue
    error("Library '$key' has the top-level class $(join(shared, ", ")), as the loaded library '$other' does: " *
          "unload one of them first ($(_unloadHint(other))).")
  end
  return nothing
end

"""
    _storeLibrary!(key, program) -> Nothing

Stores a library's parse in `LIBRARY_CACHE`. Of a loaded library (`loadedLibraries`), a library loaded again: an
error, before it is stored, when its top-level classes now clash with another loaded library's.
"""
function _storeLibrary!(key::String, program::SCode.Program)::Nothing
  key in loadedLibraries() && _checkNameClash(key, libraryClosure([key]), _classNames(program))
  LIBRARY_CACHE[key] = program
  return nothing
end

"""
    useLibrary!(key) -> String

Loads the cached library `key` (`loadLibrary`, `loadPackageDirectory`, `loadInstalledLibrary`, `loadMSL`) into the
session: later flattenings (`flattenModelWithLibraries`) see it and the libraries it uses (`LIBRARY_DEPENDENCIES`)
without `libraries`. An
error when another loaded library has one of their top-level classes (Modelica 3.2.3 and 4.1.0): it names both,
`unloadLibrary` unloads one. A loaded library stays loaded, a new parse of it (a library file loaded again) in
its place. Returns `key`.
"""
function useLibrary!(key::String)::String
  haskey(LIBRARY_CACHE, key) || error("Library '$key' is not cached: load it first (loadLibrary, loadInstalledLibrary).")
  key in LOADED_LIBRARIES && return key
  local own::Vector{String} = libraryClosure([key])
  _checkNameClash(key, own, unique(reduce(vcat, map(libraryClassNames, own))))
  push!(LOADED_LIBRARIES, key)
  return key
end

"""
    unloadLibrary(key) -> Vector{String}

Unloads the loaded library `key` (`useLibrary!`) and the libraries only it used: later flattenings no longer see
them. Their parses leave `LIBRARY_CACHE` (the disk cache keeps them: loading one again is fast), but for the bundled
MSL a model gets without loading it (`ON_DEMAND_MSL`). An error when `key` is not loaded, or is loaded only as a
library another loaded library uses. Returns the keys no longer loaded.
"""
function unloadLibrary(key::String)::Vector{String}
  local before::Vector{String} = loadedLibraries()
  if !(key in LOADED_LIBRARIES)
    key in before && error("Library '$key' is loaded as a library '$(_loadedBy(key))' uses: unload that one.")
    error("Library '$key' is not loaded. Loaded: $(isempty(before) ? "none" : join(before, ", ")).")
  end
  filter!(!=(key), LOADED_LIBRARIES)
  local after::Vector{String} = loadedLibraries()
  local removed::Vector{String} = setdiff(before, after)
  local kept::Set{String} = Set{String}(reduce(vcat, map(libraryClassNames, after); init = String[]))
  for k::String in removed
    for name::String in libraryClassNames(k)
      name in kept || delete!(LIBRARY_ROOTS, name)
    end
    k == ON_DEMAND_MSL && continue
    delete!(LIBRARY_CACHE, k)
    delete!(LIBRARY_DEPENDENCIES, k)
  end
  return removed
end

"""
    loadedModelica() -> Union{Nothing, String}

The loaded library (`loadedLibraries`) with the top-level package `Modelica`, or `nothing`.
"""
function loadedModelica()::Union{Nothing, String}
  for key::String in loadedLibraries()
    "Modelica" in libraryClassNames(key) && return key
  end
  return nothing
end

"""
    libraryVersion(key, name) -> String

The `version` annotation of the top-level class `name` of the cached library `key`, else the version its key ends
in (`Modelica_4_1_0`, `MSL_3_2_3`), else "".
"""
function libraryVersion(key::String, name::String)::String
  for c in get(LIBRARY_CACHE, key, nil)
    (c isa SCode.CLASS && c.name == name) || continue
    local v::Option{Absyn.Exp} = Frontend.SCodeUtil.lookupElementAnnotationBinding(c, "version")
    (isSome(v) && v.data isa Absyn.STRING) && return v.data.value
  end
  local m::Union{Nothing, RegexMatch} = match(r"(\d+)_(\d+)_(\d+)$", key)
  return m === nothing ? "" : join(m.captures, ".")
end

"""
    _checkMSLVersion(MSL_Version, key) -> Nothing

An error when a call asks for another MSL version (`MSL_Version`; `nothing` asks for none) than the loaded library
`key` with the package Modelica is: it names the loaded library and how to unload it.
"""
function _checkMSLVersion(MSL_Version::Union{Nothing, String}, key::String)::Nothing
  MSL_Version === nothing && return nothing
  local requested::String = replace(replace(MSL_Version, r"^MSL[:_]"i => ""), "_" => ".")
  local loaded::String = libraryVersion(key, "Modelica")
  _versionOf(requested) == _versionOf(loaded) && return nothing
  error("MSL_Version \"$MSL_Version\" asks for Modelica $requested, but the loaded library '$key' is Modelica " *
        "$(isempty(loaded) ? "of unknown version" : loaded): leave MSL_Version out to use it, or unload it first " *
        "($(_unloadHint(key))).")
end

"""
    withLoadedLibraries(program, explicit = String[]) -> SCode.Program

`program` followed by the loaded libraries (`loadedLibraries`) other than `explicit` (the libraries a call names,
with the ones they use), without the top-level classes `program` has: a model's own file comes first. An error
when a library of `explicit` that is not loaded has a top-level class a loaded library has too.
"""
function withLoadedLibraries(program::SCode.Program, explicit::Vector{String} = String[])::SCode.Program
  local loaded::Vector{String} = filter(k -> !(k in explicit), loadedLibraries())
  isempty(loaded) && return program
  local loadedNames::Vector{String} = reduce(vcat, map(libraryClassNames, loaded))
  for key::String in explicit
    local shared::Vector{String} = intersect(libraryClassNames(key), loadedNames)
    isempty(shared) && continue
    local other::String = first(filter(k -> !isempty(intersect(libraryClassNames(k), shared)), loaded))
    error("Library '$key' of `libraries` has the top-level class $(join(shared, ", ")), as the loaded library " *
          "'$other' does: leave it out to use '$other', or unload that first ($(_unloadHint(other))).")
  end
  local present::Set{String} = Set{String}(_classNames(program))
  local classes::Vector{SCode.Element} = SCode.Element[]
  for key::String in loaded
    for c in LIBRARY_CACHE[key]
      (c isa SCode.CLASS && c.name in present) && continue
      push!(classes, c)
    end
  end
  return listAppend(program, arrayList(classes))
end

const _LIBRARY_REGISTRY = Dict{String, @NamedTuple{url::String, tag_prefix::String, pkg_subdir::String}}(
  "Buildings" => (
    url        = "https://github.com/lbl-srg/modelica-buildings",
    tag_prefix = "v",
    pkg_subdir = "Buildings",
  ),
)

"""
    installLibrary(name; version, url = nothing, tag = nothing, subdir = nothing, dest = nothing) -> String

Download and install the Modelica library `name` into OM.jl's library directory (`omjlLibraryDir()`:
`~/OMJL/libraries`, on Windows `%APPDATA%\\OMJL\\libraries`; or `dest`) as `<dest>/<name> <version>/`, from its git
repository at a release tag. After installation `libraries()` discovers it and `loadInstalledLibrary` loads it.
git runs without prompts: a repository that asks for credentials (GitHub's answer for one that does not exist)
fails with git's message.

- `version` is required.
- `url`: the git repository (a GitHub URL, or any URL or path `git clone` takes). Without it, a registered library
  ($(sort(collect(keys(_LIBRARY_REGISTRY))))) comes from its registered repository.
- `tag`: the release tag; by default `v<version>`, then `<version>` (a registered library: its own prefix).
- `subdir`: the package's folder in the repository; by default the folder `name` with a `package.mo`, else the
  repository's root when its `package.mo` is the package `name`.

Checked: the folder holds the package `name` (else nothing is installed), and its `version` annotation is `version`
(a warning when not). The libraries its `uses` annotation names are listed, each as available or missing.

# Example
```julia
OMFrontend.installLibrary("Buildings"; version = "13.0.0")
OMFrontend.installLibrary("ExternData"; version = "3.0.4", url = "https://github.com/modelica-3rdparty/ExternData.mo")
key = OMFrontend.loadInstalledLibrary("Buildings")
```
"""
function installLibrary(name::String;
                        version::Union{String, Nothing} = nothing,
                        url::Union{String, Nothing} = nothing,
                        tag::Union{String, Nothing} = nothing,
                        subdir::Union{String, Nothing} = nothing,
                        dest::Union{String, Nothing} = nothing)::String
  version === nothing && error("`version` is required for installLibrary; e.g. version=\"13.0.0\"")
  local reg = get(_LIBRARY_REGISTRY, name, nothing)
  url === nothing && reg === nothing &&
    error("Unknown library '$name'. Registered: $(sort(collect(keys(_LIBRARY_REGISTRY)))); " *
          "for another, pass `url`, its git repository")
  local repo = url !== nothing ? url : reg.url
  local tags = tag !== nothing ? [tag] : (url === nothing ? [reg.tag_prefix * version] : ["v" * version, version])
  local pkgSubdir = subdir !== nothing ? subdir : (url === nothing ? reg.pkg_subdir : nothing)
  local installDir = dest !== nothing ? dest : omjlLibraryDir()
  mkpath(installDir)
  local dirName = "$name $version"
  local targetDir = joinpath(installDir, dirName)
  if isdir(targetDir) && isfile(joinpath(targetDir, "package.mo"))
    @info "Library '$dirName' already installed at $targetDir"
    return targetDir
  end
  Sys.which("git") === nothing && error("installLibrary clones with git, which is not on the PATH")
  local tmpDir = mktempdir()
  try
    local clone = joinpath(tmpDir, "repo")
    local cloned = nothing
    local gitError = ""
    for t in tags
      @info "Cloning $name $version from $repo (tag $t)..."
      local err = IOBuffer()
      local cmd = addenv(`git clone --quiet --depth=1 --branch=$t --single-branch $repo $clone`,
                         "GIT_TERMINAL_PROMPT" => "0", "GCM_INTERACTIVE" => "never")
      if success(pipeline(cmd; stdout = devnull, stderr = err))
        cloned = t
        break
      end
      gitError = strip(String(take!(err)))
      rm(clone; recursive = true, force = true)
    end
    cloned === nothing &&
      error("Could not clone $repo at tag $(join(tags, " or ")): $(isempty(gitError) ? "git failed" : last(split(gitError, '\n'))). " *
            "Check the URL (a repository that does not exist, or a private one, asks for credentials), and that " *
            "the tag exists (`tag` names another)")
    local srcDir = pkgSubdir !== nothing ? (isempty(pkgSubdir) ? clone : joinpath(clone, pkgSubdir)) :
                   _findPackageDirectory(clone, name, repo, cloned)
    isfile(joinpath(srcDir, "package.mo")) ||
      error("No package.mo in '$(relpath(srcDir, clone))' of $repo at tag $cloned")
    local found = _packageName(joinpath(srcDir, "package.mo"))
    found == name ||
      error("The package in '$(relpath(srcDir, clone))' of $repo is '$found', not '$name'; nothing installed")
    local declared = _packageVersion(joinpath(srcDir, "package.mo"))
    declared === nothing || declared == version ||
      @warn "Library '$name' installed as version $version, but its package declares version $declared"
    cp(srcDir, targetDir; force = true)
    @info "Installed '$dirName' to $targetDir"
    _reportDependencies(name, targetDir, dest)
  finally
    rm(tmpDir; recursive = true, force = true)
  end
  return targetDir
end

"""
The folder of the package `name` in a clone: `<clone>/<name>` with a package.mo, else the clone itself when its
package.mo is the package `name`. An error listing the folders with a package.mo otherwise.
"""
function _findPackageDirectory(clone::String, name::String, repo::String, tag::String)::String
  isfile(joinpath(clone, name, "package.mo")) && return joinpath(clone, name)
  isfile(joinpath(clone, "package.mo")) && _packageName(joinpath(clone, "package.mo")) == name && return clone
  local candidates = String[]
  for (root, dirs, files) in walkdir(clone)
    occursin(".git", root) && continue
    "package.mo" in files && push!(candidates, relpath(root, clone))
    length(candidates) >= 10 && break
  end
  error("No package '$name' (a folder with its package.mo) in $repo at tag $tag; pass `subdir`. " *
        "Folders with a package.mo: $(isempty(candidates) ? "none" : join(candidates, ", "))")
end

"""
The name of the package a package.mo defines (its first `package` after an optional `within`), or "".
"""
function _packageName(pkgMo::String)::String
  local text = replace(read(pkgMo, String), r"//[^\n]*" => "", r"/\*.*?\*/"s => "")
  local m = match(r"^\s*(?:within[^;]*;\s*)?(?:encapsulated\s+)?(?:partial\s+)?package\s+(\w+)", text)
  return m === nothing ? "" : String(m.captures[1])
end

"""
The `version` annotation of a package.mo (outside its `uses` and `conversion` annotations), or nothing.
"""
function _packageVersion(pkgMo::String)::Union{Nothing, String}
  local text = read(pkgMo, String)
  for keyword in ("uses", "conversion")
    while (m = match(Regex("\\b" * keyword * "\\s*\\("), text)) !== nothing
      local depth = 1
      local i = m.offset + length(m.match)
      while i <= lastindex(text) && depth > 0
        text[i] == '(' && (depth += 1)
        text[i] == ')' && (depth -= 1)
        i = nextind(text, i)
      end
      text = text[1:prevind(text, m.offset)] * text[i:end]
    end
  end
  local v = match(r"\bversion\s*=\s*\"([^\"]+)\"", text)
  return v === nothing ? nothing : String(v.captures[1])
end

"""
The libraries the `uses` annotation of an installed library names, each logged as available (where from) or
missing; looked up as `loadInstalledLibrary` will (`installDir`: nothing for the default directories).
"""
function _reportDependencies(name::String, path::String, installDir::Union{String, Nothing})::Nothing
  local deps = _parseUsesDeps(path)
  isempty(deps) && return nothing
  local avail = libraries(; installDir = installDir)
  for (depName, depVer) in sort(collect(deps))
    local r = _resolveDependency(depName, depVer, avail)
    if r === nothing
      @warn "'$name' uses '$depName $depVer', which is not installed: install it before loading '$name'"
    else
      @info "'$name' uses '$depName $depVer': $(r[1]) $(r[2])"
    end
  end
  return nothing
end

"""
    flattenModelWithLibraries(modelName, fileName; libraries, MSL, MSL_Version, scalarize, forceReload)

Flatten a Modelica model combining it with one or more pre-loaded libraries.
Libraries are looked up in `LIBRARY_CACHE` by their cache keys, followed by the
libraries they use (`libraryClosure`). The libraries loaded into the session
(`useLibrary!`, `loadedLibraries`) come along without being named. If MSL is
requested, it is appended last (lowest priority for name resolution). `fileName`
may be empty for a model of one of the libraries.

Ordering in the combined program (leftmost = highest priority):
1. User model code
2. User libraries (in order of `libraries` vector)
3. The loaded libraries, but for the top-level classes the model's file has
4. MSL (if `MSL=true`): a loaded library with the package Modelica, else the
   bundled `MSL_Version` (`nothing`: 3.2.3)

A library of `libraries` with a top-level class of a loaded library, and an
`MSL_Version` of another version than a loaded Modelica's, are errors.

When `forceReload=true` and `MSL=true`, the cached MSL under the requested
version key is dropped before instantiation. User libraries in `libraries`
are not affected by this flag; reload them via `loadLibrary` if needed.
"""
function flattenModelWithLibraries(modelName::String,
                                   fileName::String;
                                   libraries::Vector{String} = String[],
                                   MSL::Bool = false,
                                   MSL_Version::Union{Nothing, String} = nothing,
                                   scalarize::Bool = true,
                                   separateInstantiation::Bool = false,
                                   forceReload::Bool = false)
  local combined = if isempty(fileName)
    nil
  else
    local absynProgram = parseFile(fileName)
    translateToSCode(absynProgram)
  end
  local explicit::Vector{String} = libraryClosure(libraries)
  for libKey in explicit
    if !haskey(LIBRARY_CACHE, libKey)
      error("Library '$libKey' not loaded. Call loadInstalledLibrary or loadLibrary first.")
    end
    combined = listAppend(combined, LIBRARY_CACHE[libKey])
  end
  combined = withLoadedLibraries(combined, explicit)
  local modelicaKey::Union{Nothing, String} = MSL ? loadedModelica() : nothing
  if modelicaKey !== nothing
    _checkMSLVersion(MSL_Version, modelicaKey)
  elseif MSL
    local mslKey = loadBundledMSL(version = something(MSL_Version, "MSL:3.2.3"))
    if forceReload
      delete!(LIBRARY_CACHE, mslKey)
      mslKey = loadBundledMSL(version = something(MSL_Version, "MSL:3.2.3"))
    end
    combined = listAppend(combined, LIBRARY_CACHE[mslKey])
  end
  (FM, cache) = instantiateSCodeToFM(modelName, combined; scalarize = scalarize,
                                     separateInstantiation = separateInstantiation)
end


"""
```
enableDumpDebug()
```
Enable staged dumping of the flat model between different compiler phases.
NOTE this will generate files on your local drive if enabled.

To disable see ```disableDumpDebug()```
"""
function enableDumpDebug()
  status = FlagsUtil.enableDebug(Flags.NF_DUMP_FLAT)
  @info "Enabled Flags.NF_DUMP_FLAT. Old status was $(status)"
end

"""
```
disableDumpDebug()
```
Disables staged dumping of the flat  model between different compiler phases.

"""
function disableDumpDebug()
  status = FlagsUtil.disableDebug(Flags.NF_DUMP_FLAT)
  @info "Disabled Flags.NF_DUMP_FLAT. Old status was $(status)"
end

"""
```
enableSeparateInstantiation()
```
Flatten each top-level component into its own structural submodel
(`FLAT_MODEL.structuralSubmodels`) so the backend can run index reduction
separately per component. Equivalent to passing `separateInstantiation = true`
to `flattenModel`/`instantiateSCodeToFM`. Disable with `disableSeparateInstantiation()`.
"""
function enableSeparateInstantiation()
  status = FlagsUtil.enableDebug(Flags.NF_SEPARATE_INSTANTIATION)
  @info "Enabled Flags.NF_SEPARATE_INSTANTIATION. Old status was $(status)"
end

"""
```
disableSeparateInstantiation()
```
Restore the default whole-model flattening (top-level components are inlined).
"""
function disableSeparateInstantiation()
  status = FlagsUtil.disableDebug(Flags.NF_SEPARATE_INSTANTIATION)
  @info "Disabled Flags.NF_SEPARATE_INSTANTIATION. Old status was $(status)"
end

Base.show(io::IO, ::MIME"text/plain", fm::OMFrontend.Frontend.FLAT_MODEL) = begin
  print(io, "Flat Model:\n", string(fm))
end

Base.show(io::IO, ::MIME"text/plain", t::Tuple{OMFrontend.Frontend.FLAT_MODEL, OMFrontend.Frontend.FunctionTreeImpl.EMPTY}) = begin
  print(io, "Flat Model:\n", string(first(t)))
  print(io, "\n(No Functions)\n")
end

Base.show(io::IO, ::MIME"text/plain", t::Tuple{OMFrontend.Frontend.FLAT_MODEL, OMFrontend.Frontend.FunctionTreeImpl.LEAF}) = begin
  print(io, "Flat Model:\n", string(first(t)))
  print(io, "\nFunctions:\n", string(last(t)))
end

Base.show(io::IO, ::MIME"text/plain", t::Tuple{OMFrontend.Frontend.FLAT_MODEL, OMFrontend.Frontend.FunctionTreeImpl.NODE}) = begin
  print(io, "Flat Model:\n", string(first(t)))
  print(io, "\nFunctions:\n", string(last(t)))
end

#= Compact REPL display for heavy NewFrontend abstract types lives here so
   it does not clutter the main API surface. See compactShow.jl for the
   `verboseShow!` toggle and the big-hammer Base.show overrides. =#
include("compactShow.jl")

"""
```
removeQuotesFromFlatModelica(flatModelicaStr::String)
```
This function postprocesses a flat modelica model represented as a string.
It does so by removing quoted variables and expressions where possible.
This function should be used on models that has ascii characters only.
This can be useful if you wish to remove redundant clutter from flat models.

  NOTE: Not exhaustively tested for all models.
"""
function removeQuotesFromFlatModelica(fmStr::String)

  local specialSymbols = ["'+'", "'*'", "'/'", "'-'", "'constructor'"]

  function shouldBeQuoted(matchedString)
    local reg = r"\["
    local reg2 = r"\*|\+|-"
    contains(matchedString.match, reg) || contains(matchedString.match, reg2)
  end

  local buffer::IOBuffer = IOBuffer()
  if ! isascii(fmStr)
    @info "The model contains characters not in the ascii character encoding format.\nThe string was not modified."
    return fmStr
  end
  local strs = split(fmStr, "\n")
  for str in strs
    local matchedStr::Option{RegexMatch}
    local replaced = false
    local mstr = str
    if (contains(mstr, "'"))
      local reg = r"'[^']*'"
      matchedStrings = eachmatch(reg,  mstr)

      for matchedString in matchedStrings
        local underscoresReplaced = replace(matchedString.match, "." => "_")
        if ! (contains(matchedString.match, r"\[")  || contains(matchedString.match, r"\+|\*|\-"))
          strWithQuotesAndUnderscoresReplaced = replace(underscoresReplaced, "'" => "")
          mstr = replace(mstr, matchedString.match => strWithQuotesAndUnderscoresReplaced)
        else
          #= Bad code...=#
          for ss in specialSymbols
            mstr = replace(mstr, ss => replace(ss, "'"=> ""))
          end
        end
      end
      println(buffer, mstr)
    else
      println(buffer, mstr)
    end
  end

  return String(take!(buffer))
end

include("GUI_API.jl")
include("cli.jl")
include("precompilation.jl")

"""
    exportJSON(FM; output_dir=".", base_name, hierarchy=true, flat=true,
               class_mapping=nothing)

Export an already-flattened model `FM` (a `FLAT_MODEL` or the `(fm, funcs)` tuple
from `flattenModel`) as `<base>_hierarchy.json` and/or `<base>_flat.json` in
`output_dir`. Structural-mode components are grouped into class templates with
parameter overrides. See `StructuralModeJSON.exportJSON`.
"""
exportJSON(fmOrTuple; kwargs...) =
  StructuralModeJSON.exportJSON(fmOrTuple; kwargs...)

"""
    exportJSON(modelName, fileName, library = "";
               output_dir, base_name,
               hierarchy=true, flat=true, class_mapping=nothing, atd=false)

Parse `fileName`, instantiate `modelName` to a FlatModel, then export it as JSON.
When `library` is non-empty, it is loaded via `loadInstalledLibrary` and combined
with the model via `flattenModelWithLibraries` (e.g. `library = "Modelica"`). When
`library` is empty, the model is flattened on its own with `flattenModel`. Pass
`atd=true` to also write the `<base>.atd` schema.
"""
function exportJSON(modelName::AbstractString,
                    fileName::AbstractString,
                    library::AbstractString = "";
                    output_dir::AbstractString = ".",
                    base_name::AbstractString = "",
                    hierarchy::Bool = true,
                    flat::Bool = true,
                    class_mapping::Union{Dict{String,String}, Nothing} = nothing,
                    atd::Bool = false)
  (fm, _funcs) = if isempty(library)
    flattenModel(String(modelName), String(fileName))
  else
    local cacheKey = loadInstalledLibrary(String(library))
    flattenModelWithLibraries(String(modelName), String(fileName);
                              libraries = [cacheKey])
  end
  return StructuralModeJSON.exportJSON(fm;
                                       output_dir = output_dir,
                                       base_name = base_name,
                                       hierarchy = hierarchy,
                                       flat = flat,
                                       class_mapping = class_mapping,
                                       atd = atd)
end

"""
    exportATD(; output_dir=".", base_name="structural_mode_json")

Write the canonical OCaml ATD schema for the exported JSON to
`<output_dir>/<base_name>.atd` and return the path. The schema is
model-independent. See `StructuralModeJSON.exportATD`.
"""
exportATD(; kwargs...) = StructuralModeJSON.exportATD(; kwargs...)

end #OMFrontend

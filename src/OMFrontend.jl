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

#= This file defines additional utility macros.. =#
include("util.jl")

#=
TODO:
  Investigate why flags have to be loaded several times.
  both in __init__() and in main.jl
=#

#= Cache for NFModelicaBuiltin. We only use the result once! =#
"""
  Cache for NFModelicaBuiltin.
  This cache is initialized when the module is loaded.
"""
const NFModelicaBuiltinCache = Dict()

"""
  This cache contains libraries for later use.
"""
const LIBRARY_CACHE = Dict{String, SCode.Program}()

"""
  This function "precompiles" some of the runtime Modelica libraries.
  While it results in some latency when importing OMFrontend, subsequent
  use of OMFrontend to parse and work with Modelica files is faster.
TODO:
Improving the speed of precompilation would improve the feel of this package
by a lot.
"""
function __init__()
  # Base.find_package returns nothing when OMFrontend is baked into a
  # PackageCompiler sysimage; fall back to the source dir captured at build time.
  pkg = Base.find_package("OMFrontend")
  packagePath = pkg === nothing ?
      abspath(joinpath(@__DIR__, "..")) :
      dirname(realpath(pkg)) * "/.."
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

"""
  Instantiates and translates to the flat model representation
  The element to instantiate should be provided in the following format:
  <component>.<component_1>.<component_2>...
"""
function instantiateSCodeToFM(elementToInstantiate::String,
                              inProgram::SCode.Program; scalarize = true)
  # initialize globals
  Frontend.Global.initialize()
  # make sure we have all the flags loaded!
  #  Frontend.Flags.new(Flags.emptyFlags)
  Frontend.FlagsUtil.set(Frontend.Flags.NF_SCALARIZE, scalarize)
  local builtinSCode = NFModelicaBuiltinCache["NFModelicaBuiltin"]
  local program = listReverse(listAppend(builtinSCode, inProgram))
  local path = Frontend.AbsynUtil.stringPath(elementToInstantiate)
  (flat_model, funcs, inst_cls) = Frontend.instClassInProgramFM(path, program)
  return (flat_model, funcs)
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
   `"MSL_3_2_3"` becomes `"Modelica 3.2.3"`, `"Modelica_4_0_0"` becomes
   `"Modelica 4.0.0"`. Falls back to the raw key when the pattern does not
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
Valid versions are 3.2.3 and 4.0.0.

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
function flattenModel(modelName::String, fileName::String; scalarize = true)
  local absynProgram = parseFile(fileName)
  local sCodeProgram = translateToSCode(absynProgram)
  (FM, cache) = instantiateSCodeToFM(modelName, sCodeProgram; scalarize = scalarize)
end

"""
  @author: johti17
  Loads the Modelica Standard Library (MSL).
  Adds the Modelica standard library to the library cache.
Currently 3.2.3 is the default version.

Available versions are:
4.0.0
3.2.3
"""
function loadMSL(; MSL_Version)
  MSL_Version = replace(MSL_Version, "." => "_")
  MSL_Version = replace(MSL_Version, ":" => "_")
  if ! haskey(LIBRARY_CACHE, MSL_Version)
    Frontend.Global.initialize()
    try
      @info "Loading MSL.."
      local packagePath = dirname(realpath(Base.find_package("OMFrontend")))
      local packagePath *= "/.."
      local pathToLib = packagePath * string("/lib/Modelica/", MSL_Version, ".mo")
      local contentHash = _computeLibHash(pathToLib)
      if _loadLibCache(MSL_Version, contentHash)
        return LIBRARY_CACHE[MSL_Version]
      end
      @info "Initial parsing of the MSL..."
      @time local p = parseFile(pathToLib)
      local scodeMSL = OMFrontend.translateToSCode(p)
      global LIBRARY_CACHE[MSL_Version] = scodeMSL
      _saveLibCache(MSL_Version, contentHash)
      return scodeMSL
    catch e
      @info "Failed loading the Modelica Standard Library. Valid versions are 3.2.3 and 4.0.0"
      @info "Continue instantiating the model until the next error."
    end
  end
end

"""
    loadBundledMSL(; version = "3.2.3") -> String

Load the Modelica Standard Library from the bundled `lib/Modelica/` files,
independent of any OpenModelica installation. Returns the cache key.

`version` may be given as `"3.2.3"`, `"4.0.0"`, or the already-normalised
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
  LIBRARY_CACHE[cacheKey] = scodeProg
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
    LIBRARY_CACHE[cacheKey] = prog
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
    return cacheKey
  end

  @info "Loading directory-based package from $dirPath..."

  #= Step 1: Parse root package.mo =#
  local rootAbsyn = parseFile(rootFile)
  local rootSCode = translateToSCode(rootAbsyn)
  local rootClass = listHead(rootSCode)
  local rootName = rootClass.name
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
  LIBRARY_CACHE[cacheKey] = list(mergedClass)
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
    libraries(; installDir = nothing) -> Dict{String, Vector{NamedTuple}}

Discover Modelica libraries available for loading. Searches two locations:

1. The OpenModelica installation directory (default `~/.openmodelica/libraries/`).
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
  local omDir = installDir !== nothing ? installDir :
                joinpath(homedir(), ".openmodelica", "libraries")
  if isdir(omDir)
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
  local pkgRoot = try
    normpath(dirname(realpath(Base.find_package("OMFrontend"))) * "/..")
  catch
    nothing
  end
  if pkgRoot !== nothing
    local bundledDir = joinpath(pkgRoot, "lib", "Modelica")
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
    loadInstalledLibrary(name; version = nothing, forceReload = false, autodeps = true) -> String

Load a Modelica library discovered via `libraries`. Installed OpenModelica
libraries are searched first, then the bundled `lib/Modelica/` directory.

If `version` is omitted the first available version is used. If given, an exact
match is tried before a prefix match (e.g. `"4.1"` matches `"4.1.0"`).

When `autodeps = true` (default), the `uses(...)` annotation of the loaded
`package.mo` is parsed and any declared dependencies that are available via
`libraries()` are loaded automatically before returning.

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
                              autodeps::Bool = true)::String
  local avail = libraries()
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
  local cleanVer = replace(split(entry.version, "+")[1], "." => "_")
  local cacheKey = isempty(cleanVer) ? name : string(name, "_", cleanVer)
  if forceReload
    delete!(LIBRARY_CACHE, cacheKey)
  end
  if haskey(LIBRARY_CACHE, cacheKey)
    @info "Library '$cacheKey' already cached."
    return cacheKey
  end
  if isdir(entry.path)
    loadPackageDirectory(entry.path; name = cacheKey)
  else
    loadLibrary(entry.path; name = cacheKey)
  end
  if autodeps
    local deps = _parseUsesDeps(entry.path)
    local avail2 = libraries()
    for (depName, depVer) in deps
      if haskey(avail2, depName)
        try
          loadInstalledLibrary(depName; version = depVer, autodeps = true)
        catch e
          @warn "Could not auto-load dependency '$depName $depVer' for '$name': $e"
        end
      else
        @info "Dependency '$depName $depVer' declared by '$name' is not in the discovered library list."
      end
    end
  end
  return cacheKey
end

const _LIBRARY_REGISTRY = Dict{String, @NamedTuple{url::String, tag_prefix::String, pkg_subdir::String}}(
  "Buildings" => (
    url        = "https://github.com/lbl-srg/modelica-buildings",
    tag_prefix = "v",
    pkg_subdir = "Buildings",
  ),
)

"""
    installLibrary(name; version, dest = nothing) -> String

Download and install a Modelica library into the OpenModelica library directory
(`~/.openmodelica/libraries/` by default, or `dest` if given).

The library is shallow-cloned from its upstream git repository at the requested
version tag, and the Modelica package subdirectory is extracted into
`<dest>/<Name> <version>/`. After installation `libraries()` will discover it
and `loadInstalledLibrary` can load it.

`version` is required. `dest` overrides the install directory.

Currently registered libraries: $(sort(collect(keys(_LIBRARY_REGISTRY)))).

# Example
```julia
OMFrontend.installLibrary("Buildings"; version = "13.0.0")
key = OMFrontend.loadInstalledLibrary("Buildings")
```
"""
function installLibrary(name::String;
                        version::Union{String, Nothing} = nothing,
                        dest::Union{String, Nothing} = nothing)
  if !haskey(_LIBRARY_REGISTRY, name)
    error("Unknown library '$name'. Registered: $(sort(collect(keys(_LIBRARY_REGISTRY))))")
  end
  version === nothing && error("`version` is required for installLibrary; e.g. version=\"13.0.0\"")
  local reg  = _LIBRARY_REGISTRY[name]
  local installDir = dest !== nothing ? dest :
                     joinpath(homedir(), ".openmodelica", "libraries")
  mkpath(installDir)
  local tag       = reg.tag_prefix * version
  local dirName   = "$name $version"
  local targetDir = joinpath(installDir, dirName)
  if isdir(targetDir) && isfile(joinpath(targetDir, "package.mo"))
    @info "Library '$dirName' already installed at $targetDir"
    return targetDir
  end
  @info "Cloning $name $version from $(reg.url) (tag $tag)..."
  local tmpDir = mktempdir()
  try
    run(`git clone --depth=1 --branch=$tag --single-branch $(reg.url) $tmpDir`)
    local srcDir = isempty(reg.pkg_subdir) ? tmpDir : joinpath(tmpDir, reg.pkg_subdir)
    isdir(srcDir) ||
      error("Package subdirectory '$(reg.pkg_subdir)' not found in cloned repo.")
    cp(srcDir, targetDir; force = true)
    @info "Installed '$dirName' to $targetDir"
  finally
    rm(tmpDir; recursive = true, force = true)
  end
  return targetDir
end

"""
    flattenModelWithLibraries(modelName, fileName; libraries, MSL, MSL_Version, scalarize, forceReload)

Flatten a Modelica model combining it with one or more pre-loaded libraries.
Libraries are looked up in `LIBRARY_CACHE` by their cache keys. If MSL is
requested, it is appended last (lowest priority for name resolution).

Ordering in the combined program (leftmost = highest priority):
1. User model code
2. User libraries (in order of `libraries` vector)
3. MSL (if `MSL=true`)

When `forceReload=true` and `MSL=true`, the cached MSL under the requested
version key is dropped before instantiation. User libraries in `libraries`
are not affected by this flag; reload them via `loadLibrary` if needed.
"""
function flattenModelWithLibraries(modelName::String,
                                   fileName::String;
                                   libraries::Vector{String} = String[],
                                   MSL::Bool = false,
                                   MSL_Version::String = "MSL:3.2.3",
                                   scalarize::Bool = true,
                                   forceReload::Bool = false)
  local combined = if isempty(fileName)
    nil
  else
    local absynProgram = parseFile(fileName)
    translateToSCode(absynProgram)
  end
  for libKey in libraries
    if !haskey(LIBRARY_CACHE, libKey)
      error("Library '$libKey' not loaded. Call loadInstalledLibrary or loadLibrary first.")
    end
    combined = listAppend(combined, LIBRARY_CACHE[libKey])
  end
  if MSL
    local mslKey = loadBundledMSL(version = MSL_Version)
    if forceReload
      delete!(LIBRARY_CACHE, mslKey)
      mslKey = loadBundledMSL(version = MSL_Version)
    end
    combined = listAppend(combined, LIBRARY_CACHE[mslKey])
  end
  (FM, cache) = instantiateSCodeToFM(modelName, combined; scalarize = scalarize)
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
    exportFlatModelJSON(FM; output_dir=".", base_name, hierarchy=true, flat=true,
                       class_mapping=nothing)

Export a flat model as `<base>_hierarchy.json` and/or `<base>_flat.json` in
`output_dir`. Structural-mode components are grouped into class templates with
parameter overrides. See `StructuralModeJSON.exportFlatModelJSON`.
"""
exportFlatModelJSON(args...; kwargs...) =
  StructuralModeJSON.exportFlatModelJSON(args...; kwargs...)

"""
    exportFlatModelJSONFromFile(modelName, fileName, library = "";
                                output_dir, base_name,
                                hierarchy=true, flat=true, class_mapping=nothing)

Parse `fileName`, instantiate `modelName` to a FlatModel, then call
`exportFlatModelJSON`. When `library` is non-empty, it is loaded via
`loadInstalledLibrary` and combined with the model via `flattenModelWithLibraries`
(e.g. `library = "Modelica"`). When `library` is empty, the model is flattened
on its own with `flattenModel`.
"""
function exportFlatModelJSONFromFile(modelName::AbstractString,
                                     fileName::AbstractString,
                                     library::AbstractString = "";
                                     output_dir::AbstractString = ".",
                                     base_name::AbstractString = "",
                                     hierarchy::Bool = true,
                                     flat::Bool = true,
                                     class_mapping::Union{Dict{String,String}, Nothing} = nothing)
  (fm, _funcs) = if isempty(library)
    flattenModel(String(modelName), String(fileName))
  else
    local cacheKey = loadInstalledLibrary(String(library))
    flattenModelWithLibraries(String(modelName), String(fileName);
                              libraries = [cacheKey])
  end
  return StructuralModeJSON.exportFlatModelJSON(fm;
                                                output_dir = output_dir,
                                                base_name = base_name,
                                                hierarchy = hierarchy,
                                                flat = flat,
                                                class_mapping = class_mapping)
end

end #OMFrontend

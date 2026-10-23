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
  Command-line interface for OMFrontend.

  Wired up as `OMFrontend.julia_main`, this module is the entry point for a
  self-contained binary built with `PackageCompiler.create_app`. The CLI
  surfaces the most-used translation pipeline steps from src/OMFrontend.jl:
  parse a file, translate to SCode, flatten a model (optionally against the
  Modelica Standard Library), and emit the result as flat Modelica.

  No external argument-parsing dependency is used. The hand-rolled scanner
  in `_parseOpts` keeps the closure of OMFrontend's deps unchanged.

  All terminal output goes through ccall(:write, fd, ...) helpers rather
  than print/println(stderr, ...). Julia's Base.stderr / Base.stdout are
  typed as the abstract IO supertype, which juliac --trim=safe cannot
  resolve to a concrete dispatch. The fd writes are type-stable, work
  identically in cooked and trimmed binaries, and are sufficient for plain
  UTF-8 text emission. Use _stdoutPrint(ln) / _stderrPrint(ln) below
  instead of touching stderr / stdout directly.
=#

const CLI_PROGRAM = "OMFrontend"

const _STDOUT_FD = Cint(1)
const _STDERR_FD = Cint(2)

@inline function _writeFD(fd::Cint, msg::String)::Nothing
    ccall(:write, Cssize_t, (Cint, Ptr{UInt8}, Csize_t),
          fd, msg, sizeof(msg))
    return nothing
end

@inline _stdoutPrint(msg::String)::Nothing   = _writeFD(_STDOUT_FD, msg)
@inline _stdoutPrintln(msg::String)::Nothing = (_writeFD(_STDOUT_FD, msg); _writeFD(_STDOUT_FD, "\n"))
@inline _stderrPrint(msg::String)::Nothing   = _writeFD(_STDERR_FD, msg)
@inline _stderrPrintln(msg::String)::Nothing = (_writeFD(_STDERR_FD, msg); _writeFD(_STDERR_FD, "\n"))

# Read the package version from Project.toml at module load. @__DIR__ is
# baked at compile time, so this works in both regular and juliac binaries
# without calling Base.find_package (whose Project.toml-parsing path is
# itself unresolvable under --trim=safe).
const _PACKAGE_VERSION = let
    pfile = joinpath(@__DIR__, "..", "Project.toml")
    ver = "unknown"
    if isfile(pfile)
        for line in eachline(pfile)
            m = match(r"^version\s*=\s*\"([^\"]+)\"", line)
            if m !== nothing
                ver = String(m.captures[1])
                break
            end
        end
    end
    ver
end

const CLI_HELP = """
Usage: $(CLI_PROGRAM) <command> [options]

Commands:
  flatten <ModelName>   Flatten a Modelica model to flat Modelica.
  parse   <PATH>        Parse a .mo file and report success.
  scode   <PATH>        Parse a .mo file and translate to SCode.
  version               Print the OMFrontend version.
  help [<command>]      Show help for a command (or this overview).

Global options:
  -h, --help            Show this help text.
  -V, --version         Print the OMFrontend version.

Run `$(CLI_PROGRAM) help <command>` for command-specific options.
"""

const CLI_HELP_FLATTEN = """
Usage: $(CLI_PROGRAM) flatten <ModelName> [options]

Flatten <ModelName> to flat Modelica and write the result to stdout (or to
--out). The model definition is taken from --file, or from the Modelica
Standard Library when --msl is given.

Options:
  --file PATH        Modelica source file containing the model.
  --msl  VERSION     MSL version to load (e.g. 3.2.3, 4.1.0). When set, the
                     model is looked up inside the MSL after loading.
  --out  PATH        Write the flat Modelica string to PATH instead of stdout.
  --no-scalarize     Skip array scalarization (kept as array equations).
  --keep-quotes      Keep quoted Modelica identifiers in the output.

At least one of --file or --msl must be given.
"""

const CLI_HELP_PARSE = """
Usage: $(CLI_PROGRAM) parse <PATH> [options]

Parse PATH as Modelica (or MetaModelica with --grammar 2) and report success.

Options:
  --grammar N        Grammar to use. 1 = Modelica (default), 2 = MetaModelica.
  --out PATH         Write a textual dump of the syntax tree to PATH.
"""

const CLI_HELP_SCODE = """
Usage: $(CLI_PROGRAM) scode <PATH> [options]

Parse PATH and translate it to SCode.

Options:
  --out PATH         Write the SCode dump to PATH instead of stdout.
"""

#=
  Lightweight option scanner. Returns (positional, options) where options is
  Dict{String, Any} keyed by the flag/option name as it appears on the command
  line (e.g. "--file"). Flags map to `true`, valued options to their string
  value. Throws ArgumentError on missing values or unknown flags.
=#
function _parseOpts(args::AbstractVector{<:AbstractString},
                    flags::AbstractSet{String},
                    valued::AbstractSet{String})
    positional = String[]
    options    = Dict{String, Any}()
    i = 1
    while i <= length(args)
        a = args[i]
        if a in flags
            options[a] = true
        elseif a in valued
            i += 1
            i <= length(args) || throw(ArgumentError("Missing value for $(a)"))
            options[a] = args[i]
        elseif startswith(a, "--") || (startswith(a, "-") && length(a) > 1 && !isdigit(a[2]))
            throw(ArgumentError("Unknown option: $(a)"))
        else
            push!(positional, a)
        end
        i += 1
    end
    return (positional, options)
end

function _wantsHelp(opts::AbstractDict)::Bool
    return get(opts, "--help", false) === true || get(opts, "-h", false) === true
end

function _cmd_flatten(args::AbstractVector{<:AbstractString})::Cint
    flags  = Set(["--no-scalarize", "--keep-quotes", "-h", "--help"])
    valued = Set(["--file", "--msl", "--out"])
    pos, opts = _parseOpts(args, flags, valued)

    if _wantsHelp(opts)
        _stdoutPrint(CLI_HELP_FLATTEN)
        return 0
    end

    if length(pos) != 1
        _stderrPrintln("flatten: expected exactly one model name (got $(length(pos)))")
        _stderrPrint(CLI_HELP_FLATTEN)
        return 2
    end
    modelName = pos[1]

    file       = get(opts, "--file", nothing)
    mslVersion = get(opts, "--msl",  nothing)
    outPath    = get(opts, "--out",  nothing)
    scalarize  = !haskey(opts, "--no-scalarize")
    keepQuotes = haskey(opts, "--keep-quotes")

    if file === nothing && mslVersion === nothing
        _stderrPrintln("flatten: at least one of --file or --msl is required")
        return 2
    end

    fmAndCache = if mslVersion !== nothing
        flattenModelWithMSL(modelName; MSL_Version = mslVersion, scalarize = scalarize)
    else
        flattenModel(modelName, file; scalarize = scalarize)
    end

    rendered = toFlatModelica(fmAndCache; printBindingTypes = false)
    if !keepQuotes
        rendered = removeQuotesFromFlatModelica(rendered)
    end

    if outPath === nothing
        _stdoutPrint(rendered)
        endswith(rendered, "\n") || _stdoutPrint("\n")
    else
        write(outPath, rendered)
        _stderrPrintln("Wrote flat Modelica to $(outPath)")
    end
    return 0
end

function _cmd_parse(args::AbstractVector{<:AbstractString})::Cint
    flags  = Set(["-h", "--help"])
    valued = Set(["--grammar", "--out"])
    pos, opts = _parseOpts(args, flags, valued)

    if _wantsHelp(opts)
        _stdoutPrint(CLI_HELP_PARSE)
        return 0
    end

    if length(pos) != 1
        _stderrPrintln("parse: expected exactly one path (got $(length(pos)))")
        _stderrPrint(CLI_HELP_PARSE)
        return 2
    end
    path    = pos[1]
    grammar = parse(Int, get(opts, "--grammar", "1"))
    outPath = get(opts, "--out", nothing)

    program = parseFile(path, Int64(grammar))
    msg = "Parsed $(path) successfully (grammar = $(grammar))."
    if outPath === nothing
        _stdoutPrintln(msg)
    else
        write(outPath, string(program))
        _stderrPrintln("$(msg) Dump written to $(outPath).")
    end
    return 0
end

function _cmd_scode(args::AbstractVector{<:AbstractString})::Cint
    flags  = Set(["-h", "--help"])
    valued = Set(["--out"])
    pos, opts = _parseOpts(args, flags, valued)

    if _wantsHelp(opts)
        _stdoutPrint(CLI_HELP_SCODE)
        return 0
    end

    if length(pos) != 1
        _stderrPrintln("scode: expected exactly one path (got $(length(pos)))")
        _stderrPrint(CLI_HELP_SCODE)
        return 2
    end
    path    = pos[1]
    outPath = get(opts, "--out", nothing)

    program = parseFile(path)
    scode   = translateToSCode(program)

    if outPath === nothing
        _stdoutPrintln(string(scode))
    else
        exportSCodeRepresentationToFile(outPath, scode)
        _stderrPrintln("Wrote SCode to $(outPath)")
    end
    return 0
end

@inline _versionString()::String = _PACKAGE_VERSION

function _cmd_help(args::AbstractVector{<:AbstractString})::Cint
    if isempty(args)
        _stdoutPrint(CLI_HELP)
        return 0
    end
    cmd = args[1]
    text = if cmd == "flatten"
        CLI_HELP_FLATTEN
    elseif cmd == "parse"
        CLI_HELP_PARSE
    elseif cmd == "scode"
        CLI_HELP_SCODE
    elseif cmd in ("help", "version")
        CLI_HELP
    else
        _stderrPrintln("help: unknown command \"$(cmd)\"")
        _stderrPrint(CLI_HELP)
        return 2
    end
    _stdoutPrint(text)
    return 0
end

function _runCLI(args::AbstractVector{<:AbstractString})::Cint
    if isempty(args)
        _stdoutPrint(CLI_HELP)
        return 0
    end

    cmd  = args[1]
    rest = @view args[2:end]

    if cmd in ("-h", "--help", "help")
        return _cmd_help(rest)
    elseif cmd in ("-V", "--version", "version")
        _stdoutPrintln("$(CLI_PROGRAM) $(_versionString())")
        return 0
    elseif cmd == "flatten"
        return _cmd_flatten(rest)
    elseif cmd == "parse"
        return _cmd_parse(rest)
    elseif cmd == "scode"
        return _cmd_scode(rest)
    else
        _stderrPrintln("Unknown command: $(cmd)")
        _stderrPrint(CLI_HELP)
        return 2
    end
end

"""
    julia_main() :: Cint

Entry point for an OMFrontend binary built with `PackageCompiler.create_app`.
Reads command-line arguments from `Base.ARGS` and returns a process exit
code (0 on success, 1 on uncaught error, 2 on usage error).
"""
function julia_main()::Cint
    try
        return _runCLI(Base.ARGS)
    catch
        # Avoid `sprint(showerror, ::Any)` here: the dispatch on Any would
        # leave juliac --trim=safe with an unresolved call. The default
        # uncaught-throw handler will still print the exception type and
        # backtrace, which is all the user needs to file a bug.
        _stderrPrintln("OMFrontend CLI error: see uncaught throw above.")
        return 1
    end
end

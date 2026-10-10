#=
Tests from OpenModelica's flattening testsuite (omc v1.27.1, testsuite/flattening/modelica/<dir>/<file>;
OSMC-PL as this package), copied unchanged as OmcTestsuite/<dir>_<file>. Each file is flattened as omc
flattens it (the class named by `// name:`, by `-i=` in `// cflags:`, or else the file's last top-level
class) and its variables are compared by name with omc's flat model in the file (`// Result:` ...
`// endResult`). A test with `// status: incorrect` must be rejected.
=#

const OMC_TESTSUITE_DIR = joinpath(@__DIR__, "OmcTestsuite")

const OMC_TOP_CLASS = r"^(?:(?:partial|encapsulated|final|expandable|operator|impure|pure)\s+)*(?:class|model|block|connector|record|package|function|type|operator\s+record)\s+([A-Za-z_]\w*)"m

#= A declaration: its type's dimensions (captures[1]) and its name with subscripts (captures[2]). =#
const OMC_TEST_FLAT_DECL = r"^\s*(?:(?:final|protected|public|input|output|parameter|constant|discrete|flow|stream|inner|outer|redeclare|replaceable|each)\s+)*(?:enumeration\s*[\w.]*\([^)]*\)|'[^']*'|[A-Za-z_][\w.]*)(\[[^\]]*\])?\s+((?:'[^']*'|\$?[A-Za-z_]\w*)(?:\[[^\]]*\])?(?:\.(?:'[^']*'|\$?[A-Za-z_]\w*)(?:\[[^\]]*\])?)*)"

function omcTestClass(source::String)::String
  local flags = match(r"^//\s*cflags:.*-i=(\S+)"m, source)
  flags === nothing || return flags.captures[1]
  local name = replace(match(r"^//\s*name:\s*(\S+)"m, source).captures[1], r"\.mo$" => "")
  local tops = [m.captures[1] for m in eachmatch(OMC_TOP_CLASS, source)]
  return (name in tops || isempty(tops)) ? name : tops[end]
end

function omcExpectedFlat(source::String)::String
  local i = findfirst("// Result:", source)
  local j = findfirst("// endResult", source)
  return join([replace(l, r"^// ?" => "") for l in split(source[last(i) + 1:first(j) - 1], '\n')], '\n')
end

#= A name for comparison: enumeration literals in subscripts by their type's last name (omc
   x[P.E.one], ours x[E.one]), and all subscripts at the end (omc's arrays of components C.n.e[10],
   ours C[10].n.e). =#
function omcTestNormalize(name::AbstractString)::String
  local enumless = replace(replace(name, " " => ""), r"\[([^\]]*)\]" => m -> "[" * join([replace(x, r"^(?:[A-Za-z_]\w*\.)+([A-Za-z_]\w*\.[A-Za-z_]\w*)$" => s"\1") for x in split(m[2:end-1], ',')], ",") * "]")
  local bases = String[]
  local subs = String[]
  local cur = IOBuffer()
  local sub = IOBuffer()
  local depth = 0
  for ch in enumless
    if ch == '[' && depth == 0
      depth = 1
    elseif ch == ']' && depth == 1
      depth = 0
      push!(subs, String(take!(sub)))
    elseif depth > 0
      print(sub, ch)
    elseif ch == '.'
      push!(bases, String(take!(cur)))
    else
      print(cur, ch)
    end
  end
  push!(bases, String(take!(cur)))
  return join(bases, ".") * (isempty(subs) ? "" : "[" * join(subs, ",") * "]")
end

#= A name with range subscripts (omc's arrays not expanded, b[1:3].a.x) as its elements. =#
function omcTestExpandRanges(name::AbstractString)::Vector{String}
  local m = match(r"\[([^\]]*\d+:\d+[^\]]*)\]", name)
  m === nothing && return [String(name)]
  local parts = Vector{Vector{String}}()
  for x in split(m.captures[1], ',')
    local r = match(r"^\s*(\d+):(\d+)\s*$", x)
    push!(parts, r === nothing ? [String(strip(x))] : [string(i) for i in parse(Int, r[1]):parse(Int, r[2])])
  end
  local out = String[]
  for combo in Iterators.product(parts...)
    append!(out, omcTestExpandRanges(name[1:m.offset - 1] * "[" * join(combo, ",") * "]" * name[m.offset + length(m.match):end]))
  end
  return out
end

#= A declaration's element names when its type carries integer dimensions (Real[2, 3] x). =#
function omcTestExpand(name::AbstractString, tydims::Union{Nothing, AbstractString})::Vector{String}
  occursin(':', name) && return omcTestExpandRanges(name)
  tydims === nothing && return [String(name)]
  local dims = Int[]
  for d in split(tydims[2:end-1], ',')
    local v = tryparse(Int, strip(d))
    v === nothing && return [String(name)]
    push!(dims, v)
  end
  return vec([string(name, "[", join(Tuple(ix), ","), "]") for ix in CartesianIndices(Tuple(dims))])
end

#= The variable names of a flat model's text: the declarations of its class, before the first section. =#
function omcFlatVariables(text::AbstractString)::Set{String}
  local names = Set{String}()
  local lines = split(text, '\n')
  local k = findlast(l -> startswith(l, "class ") || startswith(l, "model "), lines)
  k === nothing && return names
  for l in lines[k + 1:end]
    local s = strip(l)
    (s in ("equation", "initial equation", "algorithm", "initial algorithm") || startswith(s, "end ")) && break
    local m = match(OMC_TEST_FLAT_DECL, l)
    m === nothing && continue
    for n in omcTestExpand(m.captures[2], m.captures[1])
      push!(names, omcTestNormalize(n))
    end
  end
  return names
end

@testset "OpenModelica flattening testsuite" begin
  for file in sort(filter(endswith(".mo"), readdir(OMC_TESTSUITE_DIR; join = true)))
    @testset "$(basename(file))" begin
      local source = read(file, String)
      if occursin(r"^//\s*status:\s*incorrect"m, source)
        #= omc rejects the model: so must we. =#
        @test_throws Exception OMFrontend.instantiateSCodeToFM(omcTestClass(source),
                                                               OMFrontend.translateToSCode(OMFrontend.parseFile(file)))
      else
        local scode = OMFrontend.translateToSCode(OMFrontend.parseFile(file))
        local (fm, _) = OMFrontend.instantiateSCodeToFM(omcTestClass(source), scode)
        local ours = omcFlatVariables(replace(OMFrontend.Frontend.toString(fm), "\\n" => "\n"))
        @test ours == omcFlatVariables(omcExpectedFlat(source))
      end
    end
  end
end

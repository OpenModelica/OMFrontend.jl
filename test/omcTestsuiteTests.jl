#=
Tests from OpenModelica's flattening testsuite (omc v1.27.1, testsuite/flattening/modelica/<dir>/<file>;
OSMC-PL as this package), copied unchanged as OmcTestsuite/<dir>_<file>. Each file is flattened as omc
flattens it (the class named by `// name:`, by `-i=` in `// cflags:`, or else the file's last top-level
class) and its variables are compared by name with omc's flat model in the file (`// Result:` ...
`// endResult`).
=#

const OMC_TESTSUITE_DIR = joinpath(@__DIR__, "OmcTestsuite")

const OMC_TOP_CLASS = r"^(?:(?:partial|encapsulated|final|expandable|operator|impure|pure)\s+)*(?:class|model|block|connector|record|package|function|type|operator\s+record)\s+([A-Za-z_]\w*)"m

const OMC_FLAT_DECL = r"^\s+(?:(?:final|protected|public|input|output|parameter|constant|discrete|flow|stream|inner|outer|redeclare|replaceable|each)\s+)*(?:enumeration\([^)]*\)|'[^']*'|[A-Za-z_][\w.]*)(?:\[[^\]]*\])?\s+((?:'[^']*'|[A-Za-z_]\w*)(?:\[[^\]]*\])?(?:\.(?:'[^']*'|[A-Za-z_]\w*)(?:\[[^\]]*\])?)*)"

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

#= The variable names of a flat model's text: the declarations of its class, before the first section. =#
function omcFlatVariables(text::AbstractString)::Set{String}
  local names = Set{String}()
  local lines = split(text, '\n')
  local k = findlast(l -> startswith(l, "class ") || startswith(l, "model "), lines)
  k === nothing && return names
  for l in lines[k + 1:end]
    local s = strip(l)
    (s in ("equation", "initial equation", "algorithm", "initial algorithm") || startswith(s, "end ")) && break
    local m = match(OMC_FLAT_DECL, l)
    m === nothing || push!(names, replace(m.captures[1], " " => ""))
  end
  return names
end

@testset "OpenModelica flattening testsuite" begin
  for file in sort(filter(endswith(".mo"), readdir(OMC_TESTSUITE_DIR; join = true)))
    @testset "$(basename(file))" begin
      local source = read(file, String)
      local scode = OMFrontend.translateToSCode(OMFrontend.parseFile(file))
      local (fm, _) = OMFrontend.instantiateSCodeToFM(omcTestClass(source), scode)
      local ours = omcFlatVariables(replace(OMFrontend.Frontend.toString(fm), "\\n" => "\n"))
      @test ours == omcFlatVariables(omcExpectedFlat(source))
    end
  end
end

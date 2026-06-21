#=
  JSON exporter tests.

  Exports a self-contained structural-mode model (no MSL) to hierarchy/flat
  JSON via OMFrontend.exportJSON and asserts the result against the schema in
  docs/structural_mode_json.atd: structural-mode components are deduplicated
  into class templates, and per-instance differences surface as parameter
  overrides. Array order in the JSON follows Dict iteration, so every lookup
  is by name rather than by position.
=#
import JSON

const _JSON_MODEL_FILE = joinpath(@__DIR__, "Models", "CoupledPenduliStructural.mo")
const _JSON_CLASS_MAP = Dict("p1" => "Pendulum", "p2" => "Pendulum", "tb" => "Table")

_jsonOutDir = mktempdir()
_jsonRet = OMFrontend.exportJSON("CoupledPenduli", _JSON_MODEL_FILE;
                                 output_dir = _jsonOutDir, base_name = "CP",
                                 class_mapping = _JSON_CLASS_MAP)

@testset "writes both files and returns their paths" begin
  @test _jsonRet.hierarchy_path == joinpath(_jsonOutDir, "CP_hierarchy.json")
  @test _jsonRet.flat_path == joinpath(_jsonOutDir, "CP_flat.json")
  @test isfile(_jsonRet.hierarchy_path)
  @test isfile(_jsonRet.flat_path)
end

_jsonHier = JSON.parsefile(_jsonRet.hierarchy_path)
_jsonFlat = JSON.parsefile(_jsonRet.flat_path)

@testset "hierarchy: deduplicated class templates" begin
  @test _jsonHier["model"] == "CoupledPenduli"
  # p1 and p2 share a fingerprint -> one Pendulum template; tb -> Table.
  classes = Dict(c["name"] => c for c in _jsonHier["structural_classes"])
  @test Set(keys(classes)) == Set(["Pendulum", "Table"])
  for c in values(classes)
    @test all(haskey(c, k) for k in
      ("name", "highest_differentiation_order",
       "highest_differentiation_order_variables"))
    @test c["highest_differentiation_order"] == 1
  end
  @test Set(classes["Pendulum"]["highest_differentiation_order_variables"]) ==
        Set(["a", "b", "u", "v"])
  @test Set(classes["Table"]["highest_differentiation_order_variables"]) ==
        Set(["u", "x"])
  # Three components, each tagged with its template class and counts.
  comps = Dict(c["name"] => c for c in _jsonHier["structural_components"])
  @test Set(keys(comps)) == Set(["p1", "p2", "tb"])
  @test comps["p1"]["type"] == "Pendulum"
  @test comps["p2"]["type"] == "Pendulum"
  @test comps["tb"]["type"] == "Table"
  @test (comps["p1"]["n_parameters"], comps["p1"]["n_variables"],
         comps["p1"]["n_equations"]) == (4, 7, 6)
  @test (comps["tb"]["n_parameters"], comps["tb"]["n_variables"],
         comps["tb"]["n_equations"]) == (1, 3, 2)
  @test length(_jsonHier["coupling_equations"]) == 3
end

@testset "flat: templates carry variables/equations" begin
  @test _jsonFlat["model"] == "CoupledPenduli"
  classes = Dict(c["name"] => c for c in _jsonFlat["structural_classes"])
  @test Set(keys(classes)) == Set(["Pendulum", "Table"])
  @test length(classes["Pendulum"]["variables"]) == 11
  @test length(classes["Pendulum"]["equations"]) == 6
  @test length(classes["Table"]["variables"]) == 4
  @test length(classes["Table"]["equations"]) == 2
  # Variable and equation records carry their ATD-required keys.
  v = first(classes["Table"]["variables"])
  @test all(haskey(v, k) for k in
    ("name", "type", "variability", "visibility",
     "highest_differentiation_order"))
  e = first(classes["Table"]["equations"])
  @test all(haskey(e, k) for k in
    ("id", "equation", "differentiation_order", "variables_used"))
end

@testset "flat: per-instance parameter overrides" begin
  comps = Dict(c["name"] => c for c in _jsonFlat["components"])
  @test Set(keys(comps)) == Set(["p1", "p2", "tb"])
  @test comps["p1"]["class"] == "Pendulum"
  @test comps["p2"]["class"] == "Pendulum"
  @test comps["tb"]["class"] == "Table"
  # The two Pendulum instances differ only in theta0; one is the template
  # representative, so exactly one override (on theta0) is emitted.
  overridden = [c for c in _jsonFlat["components"]
                if !isempty(get(c, "parameter_overrides", []))]
  @test length(overridden) == 1
  @test only(overridden)["name"] in ("p1", "p2")
  ov = only(overridden)["parameter_overrides"]
  @test only(ov)["parameter"] == "theta0"
  @test only(ov)["value"] in ("0.0", "0.1")
end

@testset "flat: top level and variable/equation cross-reference" begin
  # Coupling equations become the top-level section; no top-level variables.
  @test length(_jsonFlat["top_level"]["equations"]) == 3
  @test isempty(get(_jsonFlat["top_level"], "variables", []))
  vmap = Dict(m["variable"] => m["equation_ids"]
              for m in _jsonFlat["variable_to_equations"])
  # tb.x couples into p1.x = tb.x (top.eq1) and its own der(x) = u (tb.eq2).
  @test haskey(vmap, "tb.x")
  @test "top.eq1" in vmap["tb.x"]
  @test "tb.eq2" in vmap["tb.x"]
end

@testset "ATD schema export" begin
  outdir = mktempdir()
  atdPath = OMFrontend.exportATD(output_dir = outdir, base_name = "schema")
  @test atdPath == joinpath(outdir, "schema.atd")
  @test isfile(atdPath)
  schema = read(atdPath, String)
  @test occursin("type hierarchy", schema)
  @test occursin("type flat_model", schema)
  @test occursin("OMFrontend.exportJSON", schema)
  # exportJSON(atd=true) writes the same schema alongside the JSON and returns its path.
  r = OMFrontend.exportJSON("CoupledPenduli", _JSON_MODEL_FILE;
                            output_dir = outdir, base_name = "CPatd", atd = true)
  @test r.atd_path == joinpath(outdir, "CPatd.atd")
  @test isfile(r.atd_path)
  @test read(r.atd_path, String) == schema
end

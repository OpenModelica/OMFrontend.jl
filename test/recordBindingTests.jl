#= Record bindings and package constants of records (Models/RecordBindings.mo). =#

const _RECORD_BINDINGS_FILE = "./Models/RecordBindings.mo"

"The type and binding of each variable of the flat model `fm`, by name."
function _recordBindingVariables(fm)::Dict{String, Tuple{String, String}}
  local F = OMFrontend.Frontend
  return Dict{String, Tuple{String, String}}(F.toString(v.name) => (F.toString(v.ty), F.toString(v.binding))
                                             for v in fm.variables)
end

#= h(st = st), st.cell redeclared in Stack: the redeclared field was instantiated as if nothing above it had a
   binding, so its fields kept their class defaults and their dimensions were deduced from those (rc[nRC] with
   nRC = 1, t[:, 2] of 2 rows), the bindings from st had 2 and 3 (MSL CCCV_StackRC's stack.stackData). =#
@testset "A redeclared record field bound two levels above" begin
  for scalarize in (false, true)
    local (fm, _) = OMFrontend.flattenModel("RecordBindings.Redeclared.M", _RECORD_BINDINGS_FILE; scalarize = scalarize)
    local vars::Dict{String, Tuple{String, String}} = _recordBindingVariables(fm)
    if scalarize
      @test haskey(vars, "h.st.cell.rc[2].R")
      @test haskey(vars, "h.st.cell.t[3, 2]")
    else
      @test vars["h.st.cell.rc.R"][1] == "Real[2]"
      @test vars["h.st.cell.t"][1] == "Real[3, 2]"
    end
  end
end

#= Medium.cp_X inlined after the constants were evaluated: its body kept `1:Medium.nX` and `Medium.data[i]`, the
   flat model the constants as variables (MSL MixtureGases: an array of records the backend's array path
   refused). =#
@testset "An inlined function's package constants evaluated" begin
  local s::String = OMFrontend.toFlatModelica(OMFrontend.flattenModel("RecordBindings.InlinedConstants.M",
                                                                     _RECORD_BINDINGS_FILE; scalarize = false))
  @test !occursin("Medium.data", s)
  @test !occursin("Medium.nX", s)
  @test occursin("for i in 1:2", s)
end

#= u.dat.conDat.mBorFie, without a binding of its own: from the parent's binding, a cref (M) or a constructor call
   (M2), its field expression evaluated once (makeRecordFieldBindingFromParent). u.x's size reads it. =#
@testset "A record field from its parent's binding, for a dimension" begin
  for model in ("M", "M2")
    local (fm, _) = OMFrontend.flattenModel("RecordBindings.ConstructorField." * model, _RECORD_BINDINGS_FILE;
                                            scalarize = true)
    local vars::Dict{String, Tuple{String, String}} = _recordBindingVariables(fm)
    @test count(n -> startswith(n, "u.x["), keys(vars)) == 15
    @test vars["u.n"][2] == "15"
  end
end

#= apply(function lin(c = coeffs), x), apply's body `y := f(u)`: inlined, the call was `f(x)`, the partial application
   lost (the functional input's name is no cref the substitution replaces). A function of a functional input is kept. =#
@testset "A call through a functional input is not inlined" begin
  for scalarize in (false, true)
    local s::String = OMFrontend.toFlatModelica(OMFrontend.flattenModel("RecordBindings.PartialRecord.M",
                                                                       _RECORD_BINDINGS_FILE; scalarize = scalarize))
    local lines::Vector{String} = String.(split(s, "\n"))
    local eqs::Vector{String} = lines[(findfirst(l -> strip(l) == "equation", lines) + 1):end]
    local equation::String = only(filter(l -> occursin(" = ", l) && !occursin("der(", l), eqs))
    @test occursin("PartialRecord.apply'(function", equation)
    @test !occursin("'f'(", equation)
  end
end

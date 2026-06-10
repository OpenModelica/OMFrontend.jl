#=
Tests for the algorithm-level for-loop unroller in NFFlatten.jl.

The unroller fires when:
  - the `ALG_FOR` has a present range that evaluates to a literal integer
    range,
  - the iteration count is at most `ALG_UNROLL_MAX_ITERATIONS` (currently
    16),
  - the body does not contain `break` or `return` at any depth.

A `when` inside `for` inside a normal algorithm section remains forbidden
by the Modelica spec; the first testset locks that rejection in place.
=#

function _flattenFM_algunroll(model::String, file::String)
  sp = OMFrontend.parseFile(file)
  scode = OMFrontend.translateToSCode(sp)
  return OMFrontend.instantiateSCodeToFM(model, scode)
end

@testset "Algorithm: when-in-for-in-algorithm is rejected" begin
  rejected = false
  redirect_stdio(stdout=devnull, stderr=devnull) do
    try
      _flattenFM_algunroll("AlgorithmForOfWhen",
                          "./Models/AlgorithmForWhenUnroll.mo")
    catch e
      rejected = true
    end
  end
  @test rejected
end

@testset "Algorithm: for-of-if with iter as subscript is unrolled" begin
  (fm, _) = _flattenFM_algunroll("AlgorithmForOfIfSubscript",
                                "./Models/AlgorithmForWhenUnroll.mo")
  s = OMFrontend.toString(fm)
  @test occursin("if time >= t[1]", s)
  @test occursin("if time >= t[2]", s)
  @test occursin("if time >= t[3]", s)
  @test !occursin(r"for\s+i\s+in", s)
end

@testset "Algorithm: for-loop with iter as a value is also unrolled" begin
  (fm, _) = _flattenFM_algunroll("AlgorithmForOfIfValue",
                                "./Models/AlgorithmForWhenUnroll.mo")
  s = OMFrontend.toString(fm)
  @test occursin("coef[1]", s)
  @test occursin("2.0 * coef[2]", s)
  @test occursin("3.0 * coef[3]", s)
  @test !occursin(r"for\s+i\s+in", s)
end

@testset "Algorithm: for-loop above N=16 cap stays as for-loop" begin
  (fm, _) = _flattenFM_algunroll("AlgorithmForOfIfBigRange",
                                "./Models/AlgorithmForWhenUnroll.mo")
  s = OMFrontend.toString(fm)
  @test occursin(r"for\s+i\s+in\s+1:200", s)
end

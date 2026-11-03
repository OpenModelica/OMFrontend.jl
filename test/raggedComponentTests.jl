#= Arrays of components whose dimensions differ per element: a structural if-condition evaluated per element (omc
   1.27.1 selects no branch when typing; a condition differing between the elements kept the if-expression), the
   flattened equations' references of each element's own size. Models/RaggedComponents.mo. =#
const _RAGGED_FILE = "./Models/RaggedComponents.mo"

@testset "a structural if-condition that differs per element of an array of components" begin
  (fm, _) = flattenFM("RaggedComponents.ConditionPerElement", _RAGGED_FILE)
  local flat = OMFrontend.toString(fm)
  for v in ("lay[1].T[2]", "lay[2].T[1]", "lay[3].T[2]")
    @test occursin(v, flat)
  end
  @test !occursin("lay[2].T[2]", flat)
  #= one equation per state: 2 + 1 + 2 =#
  @test count("der(", flat) == 5
end

@testset "the same condition in every element: the branch selected" begin
  (fm, _) = flattenFM("RaggedComponents.ConditionAllEqual", _RAGGED_FILE)
  local flat = OMFrontend.toString(fm)
  @test occursin("lay[1].T[2]", flat) && occursin("lay[2].T[2]", flat)
  @test count("der(", flat) == 4
end

#= When-equation branches must solve the same variables (MLS 8.3.5); a reinit
   is not an equation for a variable (as OpenModelica's NFVerifyModel). =#
const _WHEN_VERIFY_FILE = "./Models/WhenVerifyTest.mo"

@testset "elsewhen with reinit in one branch" begin
  (fm, _) = flattenFM("WhenVerifyTest.ElsewhenReinit", _WHEN_VERIFY_FILE)
  @test occursin("reinit", OMFrontend.toString(fm))
end

@testset "elsewhen branches solving different variables are rejected" begin
  #= an error, not a MethodError from the check itself =#
  @test_throws MetaModelica.MetaModelicaGeneralException flattenFM("WhenVerifyTest.ElsewhenDifferentVariables",
                                                                   _WHEN_VERIFY_FILE)
end

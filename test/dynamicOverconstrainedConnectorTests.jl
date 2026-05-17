include("./dynamicOverconstrainedConnectors.jl")
import ..OCC_ReferenceModels

const _OCC_MSL_KEY = OMFrontend.loadBundledMSL(version = "3.2.3")

macro test_pass_if_not_throws(modelName::String, modelFile::String)
  @test true == begin
    try
      OMFrontend.flattenModelWithLibraries(modelName, modelFile;
                                           libraries = [_OCC_MSL_KEY])
      true
    catch e
      @error "Test of $modelName failed" e
      throw(e)
      false
    end
  end
end

@testset "Sanity test. Check that we can translate the components without exceptions are thrown" begin
  @test_pass_if_not_throws("DynamicOverconstrainedConnectors.ACPort", "./Models/DynamicOverconstrainedConnectors.mo")
  @test_pass_if_not_throws("DynamicOverconstrainedConnectors.Load", "./Models/DynamicOverconstrainedConnectors.mo")
  @test_pass_if_not_throws("DynamicOverconstrainedConnectors.Generator", "./Models/DynamicOverconstrainedConnectors.mo")
  @test_pass_if_not_throws("DynamicOverconstrainedConnectors.TransmissionLine", "./Models/DynamicOverconstrainedConnectors.mo")
  @test_pass_if_not_throws("DynamicOverconstrainedConnectors.System1", "./Models/DynamicOverconstrainedConnectors.mo")
  @test_pass_if_not_throws("DynamicOverconstrainedConnectors.System2", "./Models/DynamicOverconstrainedConnectors.mo")
  @test_pass_if_not_throws("DynamicOverconstrainedConnectors.System3", "./Models/DynamicOverconstrainedConnectors.mo")
  @test_pass_if_not_throws("DynamicOverconstrainedConnectors.System4", "./Models/DynamicOverconstrainedConnectors.mo")
end

function test_and_pretty_print(ref, modelName, modelFile)
  local result = OMFrontend.flattenModelWithLibraries(modelName, modelFile;
                                                      libraries = [_OCC_MSL_KEY])
  local res = OMFrontend.toFlatModelica(result[1], nil)
  @test true == begin
    if ref == res
      true
    else
      @info "Got:"
      print(res)
      @info "Reference was:"
      print(ref)
      false
    end
  end
end

@testset "Test if the flat Modelica model is equal to the reference models" begin
  local modelFile = "./Models/DynamicOverconstrainedConnectors.mo"
  test_and_pretty_print(OCC_ReferenceModels.ACPort, "DynamicOverconstrainedConnectors.ACPort", modelFile)
  test_and_pretty_print(OCC_ReferenceModels.Load, "DynamicOverconstrainedConnectors.Load", modelFile)
  test_and_pretty_print(OCC_ReferenceModels.Generator, "DynamicOverconstrainedConnectors.Generator", modelFile)
  test_and_pretty_print(OCC_ReferenceModels.TransmissionLine, "DynamicOverconstrainedConnectors.TransmissionLine", modelFile)
  test_and_pretty_print(OCC_ReferenceModels.System1, "DynamicOverconstrainedConnectors.System1", modelFile)
  test_and_pretty_print(OCC_ReferenceModels.System2, "DynamicOverconstrainedConnectors.System2", modelFile)
  test_and_pretty_print(OCC_ReferenceModels.System3, "DynamicOverconstrainedConnectors.System3", modelFile)
  test_and_pretty_print(OCC_ReferenceModels.System4, "DynamicOverconstrainedConnectors.System4", modelFile)
end

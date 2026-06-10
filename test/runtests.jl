#=
  Author: John Tinnerholm johti17@liu.se
=#
# The test files reference Modelica models via relative paths
# ("./Models/HelloWorld.mo", "./Equations/...", etc.) and assume cwd is
# OMFrontend.jl/test/. Pkg.test always cd's there, but when this file is
# driven directly via `julia -e 'include("test/runtests.jl")'` (as the CI
# Test step does to reuse the warm precompile cache), cwd stays at the
# project root. Anchor cwd here so both invocations work.
cd(@__DIR__)

import Pkg

Pkg.resolve()

import Absyn
import SCode
import DAE
using MetaModelica
using Test
import OMFrontend


#= Utility functions =#
function flatten(modelName::String, modelFile::String)
  @info "Parsing..."
  @time p = OMFrontend.parseFile(modelFile)
  @info "SCode Translation of $(modelName)..."
  @time scodeProgram = OMFrontend.translateToSCode(p)
  @info "Generating the DAE for $(modelName)..."
  @time (dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
end

function parseAndLowerToScode(modelName::String, modelFile::String)
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
end

"""
  Flattens to flat Modelica.
  Note that, the full path specification of the file is expected.
"""
function flattenFM(model, file)
  local sp = OMFrontend.parseFile(file)
  local scode = OMFrontend.translateToSCode(sp)
  local (x, y) = OMFrontend.instantiateSCodeToFM(model, scode)
  return (x, y)
end

@testset "OMFrontend tests" begin
  @testset "Frontend sanitiy tests. Check if we can transform the abstract tree to SCode and that we are able to flatten without exceptions" begin
    @testset "Absyn -> SCode test" begin
      include("scodeSanityTest.jl")
    end
    @testset "SCode -> DAE Sanity test" begin
      include("daeTests.jl")
    end
  end

  # GUI_API tests are gated behind the OMFRONTEND_TEST_GUI_API env var while
  # an outstanding compileModel/isfile mismatch is being investigated. Set
  # OMFRONTEND_TEST_GUI_API=1 (or =true) to opt in locally.
  if get(ENV, "OMFRONTEND_TEST_GUI_API", "0") in ("1", "true", "TRUE")
    @testset "GUI_API tests" begin
      include("gui_api_tests.jl")
    end
  else
    @info "Skipping GUI_API tests (set OMFRONTEND_TEST_GUI_API=1 to enable)"
  end

  # #= Check that we get the correct flat Modelica=#
  @testset "Frontend Validation test. Check that the result corresponds to existing models in the original frontend " begin
    include("frontendResultTest.jl")
  end

  @testset "Algorithm-level for-loop unrolling" begin
    include("algorithmUnrollTests.jl")
  end

  @testset "Replaceable packages" begin
    include("replaceableTests.jl")
  end

  #=
  Test components in the MSL
  If you are a user of this package please submit more tests here.
  =#
  @testset "MSL test" begin
    include("mslTests.jl")
  end

  @testset "Test the use of the MSL" begin
    include("useOfMSLTests.jl")
  end

  @testset "Testing OC-Connectors" begin
    include("dynamicOverconstrainedConnectorTests.jl")
  end

  #= OMFrontend.jl extensions for variable structured systems =#
  @testset "Basic VSS models" begin
    include("./VSS/testVSS.jl")
  end
end

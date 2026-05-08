#=
Frontend verification tests.
Author: johti17@liu.se
=#

#= Include tests for equations =#
include("equationTests.jl")
include("connect.jl")
include("arrayTests.jl")
include("bindingExpTests.jl")
import ..ConnectTests

#= The set of basic connect tests=#
ctst1 = (ConnectTests.Connect1, "Connect1", "./Connectors/Connect1.mo")
ctst2 = (ConnectTests.Connect2, "Connect2", "./Connectors/Connect2.mo")
ctst3 = (ConnectTests.Connect3, "Connect3", "./Connectors/Connect3.mo")
ctst4 = (ConnectTests.Connect4, "Connect4", "./Connectors/Connect4.mo")
ctst5 = (ConnectTests.Connect5, "Connect5", "./Connectors/Connect5.mo")
ctst6 = (ConnectTests.Connect6, "Connect6", "./Connectors/Connect6.mo")
ctst7 = (ConnectTests.Connect7, "Connect7", "./Connectors/Connect7.mo")
ctst8 = (ConnectTests.Connect8, "Connect8", "./Connectors/Connect8.mo")
ctst9 = (ConnectTests.Connect9, "Connect9", "./Connectors/Connect9.mo")
ctst10 = (ConnectTests.Connect10, "Connect10", "./Connectors/Connect10.mo")
ctst11 = (ConnectTests.Connect11, "Connect11", "./Connectors/Connect11.mo")
ctst12 = (ConnectTests.Connect12, "Connect12", "./Connectors/Connect12.mo")
ctst13 = (ConnectTests.Connect13, "Connect13", "./Connectors/Connect13.mo")
ctst14 = (ConnectTests.Connect14, "Connect14", "./Connectors/Connect14.mo")
ctst15 = (ConnectTests.Connect15, "Connect15", "./Connectors/Connect15.mo")
ctst16 = (ConnectTests.Connect16, "Connect16", "./Connectors/Connect16.mo")
ctst17 = (ConnectTests.Connect17, "Connect17", "./Connectors/Connect17.mo")
ctst18 = (ConnectTests.Connect18, "Connect18", "./Connectors/Connect18.mo")

#= How one test case is defined =#
tank = (ConnectTests.Tank, "Tank", "./Connectors/Tank.mo")
heattank = (ConnectTests.HeatTank, "HeatTank", "./Connectors/HeatTank.mo")
heatTankExpanded = (ConnectTests.HeatTankExpanded, "HeatTankExpanded", "./Connectors/HeatTankExpanded.mo")
multipleinheritanceconnect = (ConnectTests.MultipleInheritanceConnect
                              , "MultipleInheritanceConnect"
                              , "./Connectors/MutipleInheritanceConnect.mo")
resistorCircuit0 = (ConnectTests.ResistorCircuit0, "ElectricalComponentTest.ResistorCircuit0", "./Connectors/EletricalComponentTest.mo")
resistorCircuit1 = (ConnectTests.ResistorCircuit1, "ElectricalComponentTest.ResistorCircuit1", "./Connectors/EletricalComponentTest.mo")
simpleCircuit = (ConnectTests.SimpleCircuit, "ElectricalComponentTest.SimpleCircuit", "./Connectors/EletricalComponentTest.mo")
#= Basic connect tests=#
connectTsts = [ctst1,
               ctst2,
               ctst4,
               ctst5,
               ctst6,
               ctst7,
               ctst8,
               ctst9,
#               ctst12, This test should not be run.
#               ctst13, The output of this test is "wrong" or is it?. Please investigate if you see this Adrian:)
#               ctst14,
               ctst15,
#               ctst16, #Fails when running omc Connect16.mo as well?
               ctst17,
               ctst18]
#= Tests that should throw errors =#
incorrectTsts = [ctst3, ctst10, ctst11]
#= Add new tests here=#
tst = [tank,
       heattank,
       heatTankExpanded,
       multipleinheritanceconnect,
       resistorCircuit0,
       resistorCircuit1,
       simpleCircuit]

equationTests = [circle,
                 arrayfancy,
                 ifEquationDer,
                 testArrayEq]

function runTestsDefinedInVector(tests::Vector, testSetDesc)
  @testset "$testSetDesc" begin
    for mf in tests
      try
        #= Get the flat model =#
        @info "Testing $(mf[2])"
        res = flattenFM(mf[2], mf[3])
        #= Convert the flat model to a string =#
        res = OMFrontend.toString(first(res))
        comp = res == mf[1]
        if comp
          @test true == comp
          @info "Success!"
          println()
        else
          @error "Reference file mismatch for test: $(mf[2])"
          @info "The result was:"
          println(res)
          @info "The reference string was:"
          println(mf[1])
          @test true == comp
        end
      catch e
        @error "An exception was thrown for test: $(mf[2])"
        throw("")
      end
    end
  end
end

runTestsDefinedInVector(connectTsts, "Connector test. Testing the handling of connectors")
runTestsDefinedInVector(tst, "Trying simple Modelica models using connectors")
runTestsDefinedInVector(equationTests, "Trying slightly more advanced models, containing equational loops etc.")
runTestsDefinedInVector(arrayTests0, "Testing scalarization of equational loops and vector of records..")
include("connectGenerated.jl")
runTestsDefinedInVector(generatedConnectorTests,
                        "Connector regression tests (auto-generated from unused .mo files)")
runTestsDefinedInVector(bindingExpTests, "BINDING_EXP constant evaluation in function bodies")
#= End Connector tests =#

"""Sanity test: the frontend flattens these models without an exception."""
function testPassIfNoException(str1::String, str2::String)
  @test try
    flattenFM(str1, str2)
    true
  catch e
    @error "Failed to flatten model: $(str1) in file $(str2):" e
    throw(e)
    false
  end
end

testPassIfNoException("HelloWorld", "./Models/HelloWorld.mo")
testPassIfNoException("LotkaVolterra", "./Models/LotkaVolterra.mo")
testPassIfNoException("Robertsson", "./Models/Robertsson.mo")
testPassIfNoException("SimpleCircuit", "./Models/SimpleCircuit.mo")
testPassIfNoException("SimpleMechanicalSystem", "./Models/SimpleMechanicalSystem.mo")
testPassIfNoException("Influenza", "./Models/Influenza.mo")
testPassIfNoException("Casc6", "./Models/Casc6.mo")
testPassIfNoException("TestImport.A", "./Models/TestImport.mo")
testPassIfNoException("TestEnum", "./Models/TestEnum.mo")
testPassIfNoException("SimpleClock", "./Models/SimpleClock.mo")

# Recursion / deep instantiation tests (BranchingDynamicPipes patterns)
testPassIfNoException("DeepExtendsChain", "./Models/RecursionTests.mo")
testPassIfNoException("RedeclareModelTest", "./Models/RecursionTests.mo")
testPassIfNoException("CrossComponentRef", "./Models/RecursionTests.mo")
testPassIfNoException("DerivedTypeChain", "./Models/RecursionTests.mo")
testPassIfNoException("NestedRedeclareTest", "./Models/RecursionTests.mo")
testPassIfNoException("InnerOuterWithRedeclare", "./Models/RecursionTests.mo")
testPassIfNoException("DeepHierarchyRedeclare", "./Models/RecursionTests.mo")
testPassIfNoException("DualRedeclareTest", "./Models/RecursionTests.mo")
testPassIfNoException("BranchingPipeTest", "./Models/RecursionTests.mo")

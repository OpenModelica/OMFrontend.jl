#= getInstanceName() is the simulated model's name and the instance's path in it (MLS 3.7.4:
   `Vehicle.engine.controller` for MyLib.Vehicle), as omc's INCLUDING_ROOT scope. It was the root's
   full class path, so the MSL noise blocks' automatic local seeds (a hash of the name) and their
   random sequences differed from omc's (MSL DrydenContinuousTurbulence, ActuatorWithNoise). =#
const _INSTANCE_NAME_FILE = "./Models/InstanceNameTest.mo"

@testset "getInstanceName()" begin
  (fm, _) = flattenFM("InstanceNameTest.Top", _INSTANCE_NAME_FILE)
  local s = OMFrontend.toString(fm)
  @test occursin("\"Top.sub.leaf\"", s)
  @test occursin("\"Top\"", s)
end

#= The parallel frontend gives the serial flat model (Models/ParallelRecordFields.mo). =#

#= A record field sized by the instance's binding, read through another record's binding (per =
   perFan): a record component is typed before its fields, which other tasks type; the field's
   type read meanwhile was its element type (Real for Real[3]), an unknown dimension
   (Buildings' fan records: CoolingCoilHumidifyingHeating_ClosedLoop failed every parallel run). =#
@testset "Record fields sized through another record's binding" begin
  if Threads.nthreads() < 2
    @test_skip "needs 2 or more threads"
  else
    local flat = () -> OMFrontend.toString(first(flattenFM("ParallelRecordFields.Plant", "./Models/ParallelRecordFields.mo")))
    local par = OMFrontend.Frontend.PARALLEL_INST[]
    local serial = try
      OMFrontend.Frontend.PARALLEL_INST[] = false
      flat()
    finally
      OMFrontend.Frontend.PARALLEL_INST[] = par
    end
    OMFrontend.Frontend.PARALLEL_INST[] = true
    try
      @test all(==(serial), (flat() for _ in 1:4))
    finally
      OMFrontend.Frontend.PARALLEL_INST[] = par
    end
  end
end

#= A function's evaluation depth is per task: its shared call counter lost updates under
   concurrent evaluations (218 after 4000 on 12 threads, the limit 256 for a function that does
   not recurse). =#
@testset "Concurrent evaluations of one function" begin
  if Threads.nthreads() < 2
    @test_skip "needs 2 or more threads"
  else
    local F = OMFrontend.Frontend
    local (_, funcs) = flattenFM("ParallelRecordFields.Plant", "./Models/ParallelRecordFields.mo")
    local fn = first(last(kv) for kv in F.FunctionTreeImpl.toList(funcs) if endswith(F.AbsynUtil.pathString(F.name(last(kv))), "scaled"))
    local args = F.Expression[F.REAL_EXPRESSION(1.5)]
    local results = Vector{String}(undef, 4000)
    Threads.@threads for i in 1:4000
      results[i] = F.toString(F.evaluate(fn, args))
    end
    @test all(==("3.0"), results)
    @test F.P_Pointer.access(fn.callCounter) == 0
  end
end

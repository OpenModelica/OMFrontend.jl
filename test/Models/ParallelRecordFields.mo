package ParallelRecordFields
  "Record fields sized by an instance's binding, read through another record's binding (Buildings' fan records, per = perFan), typed in parallel"
  record Curve "A curve: its size from the binding"
    parameter Real V_flow[:];
    parameter Real dp[size(V_flow, 1)];
  end Curve;

  record Data
    parameter Curve pressure(V_flow = {0, 0}, dp = {0, 0});
    parameter Curve efficiency(V_flow = {0}, dp = {0.7});
    parameter Real speeds[:] = {1};
  end Data;

  function points "The number of points, counted (a dimension: evaluated for every fan while typing)"
    input Real V_flow[:];
    output Integer n = 0;
  algorithm
    for k in 1:200 loop
      n := 0;
      for v in V_flow loop
        n := n + 1;
      end for;
    end for;
  end points;

  function scaled "Evaluated by many tasks at once in the tests"
    input Real x;
    output Real y;
  algorithm
    y := 2*x;
  end scaled;

  model Fan
    parameter Data per;
    Real dp[points(per.pressure.V_flow)];
    Real y = scaled(time);
  equation
    dp = per.pressure.dp*time;
  end Fan;

  model Unit
    parameter Data perFan(pressure(V_flow = {0, 1, 2}, dp = {3, 2, 0}), efficiency(V_flow = {0, 2}, dp = {0.5, 0.7}), speeds = {0.5, 1});
    Fan fan1(per = perFan);
    Fan fan2(per = perFan);
    Fan fan3(per = perFan);
    Fan fan4(per = perFan);
    Fan fan5(per = fan1.per);
    Fan fan6(per = fan2.per);
  end Unit;

  model Plant
    Unit u1;
    Unit u2;
    Unit u3;
    Unit u4;
  end Plant;
end ParallelRecordFields;

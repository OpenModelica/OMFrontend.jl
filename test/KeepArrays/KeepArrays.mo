package KeepArrays
  model ArrayDecay
    parameter Integer n = 3;
    parameter Real k[n] = {1, 2, 3};
    Real x[n](each start = 1, each fixed = true);
  equation
    for i in 1:n loop
      der(x[i]) = -k[i] * x[i];
    end for;
  end ArrayDecay;

  model ArrayDecayVec
    parameter Integer n = 3;
    parameter Real k[n] = {1, 2, 3};
    Real x[n](each start = 1, each fixed = true);
  equation
    der(x) = -k .* x;
  end ArrayDecayVec;

  connector HeatPort
    Real T;
    flow Real Q;
  end HeatPort;

  model Cap
    parameter Real C = 1;
    parameter Real T0 = 0;
    HeatPort p;
    Real T(start = T0, fixed = true);
  equation
    T = p.T;
    C * der(T) = p.Q;
  end Cap;

  model Cond
    parameter Real G = 1;
    HeatPort a, b;
  equation
    a.Q + b.Q = 0;
    a.Q = G * (a.T - b.T);
  end Cond;

  model Chain "Connects in a for-loop over component arrays"
    parameter Integer n = 4;
    Cap c[n](T0 = {1, 0, 0, 0});
    Cond g[n - 1];
  equation
    for i in 1:n - 1 loop
      connect(c[i].p, g[i].a);
      connect(g[i].b, c[i + 1].p);
    end for;
  end Chain;

  connector RealInput = input Real;
  connector RealOutput = output Real;

  block Gain
    parameter Real k = 1;
    RealInput u;
    RealOutput y;
  equation
    y = k * u;
  end Gain;

  block TwoGains "A block with connects inside, used as a component array"
    parameter Real k = 2;
    RealInput u;
    RealOutput y;
    Gain g1(k = k);
    Gain g2(k = k);
  equation
    connect(u, g1.u);
    connect(g1.y, g2.u);
    connect(g2.y, y);
  end TwoGains;

  model ComponentArrayConnects
    TwoGains t[3](k = {1, 2, 3});
    Real x[3](each start = 1, each fixed = true);
  equation
    t.u = x;
    der(x) = -t.y;
  end ComponentArrayConnects;

  record R
    Real a;
    Real b;
  end R;

  model RecordHolder "Per-instance record bindings of a component array"
    parameter R r = R(1, 2);
    parameter Real s = r.a + r.b;
  end RecordHolder;

  model RecordArray
    RecordHolder h[2](r = {R(1, 2), R(3, 4)});
    Real x[2](each start = 1, each fixed = true);
  equation
    der(x) = -h.s .* x;
  end RecordArray;

  function total
    input Real v[:];
    output Real s;
  algorithm
    s := sum(v);
  end total;

  model WholeArrayArgument "A whole array as a function argument"
    Real x[3](start = {1, 2, 3}, each fixed = true);
    Real s;
  equation
    der(x) = -x;
    s = total(x);
  end WholeArrayArgument;
end KeepArrays;

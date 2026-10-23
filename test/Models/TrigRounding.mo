package TrigRounding "sin, cos and tan of multiples of pi evaluate to exactly zero, as in MSL's symmetrical components"
  constant Real pi = 3.141592653589793;

  function sines "sin(2*pi/m*k*m) for k = 0..m: zero in exact arithmetic"
    input Integer m;
    output Real s[m + 1];
  algorithm
    for k in 0:m loop
      s[k + 1] := sin(2*pi/m*(k*m));
    end for;
  end sines;

  function others "cos(pi/2), cos(3*pi/2), tan(pi): zero; sin(1e-20) and sin(pi/6): kept"
    input Real scale;
    output Real y[5];
  algorithm
    y := {cos(scale*pi/2), cos(scale*3*pi/2), tan(scale*pi), sin(scale*1e-20), sin(scale*pi/6)};
  end others;

  model TestTrigRounding
    final parameter Real s[4] = sines(3);
    final parameter Real y[5] = others(1.0);
    Real h;
  equation
    der(h) = 0.0;
  end TestTrigRounding;
end TrigRounding;

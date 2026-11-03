package AttributeVariabilityTest
  function scalC "an external function: its result is not known at the translation"
    input Real a;
    output Real y;
  external "C" y = scalC(a);
  end scalC;

  model StartOfExternalParameter "a start bound to a parameter computed by an external call (a non-structural parameter)"
    parameter Real a = 1;
    parameter Real s = scalC(a);
    Real x(start = s, fixed = true);
  equation
    der(x) = 1;
  end StartOfExternalParameter;

  model StartOfDiscrete "a start bound to a discrete variable: an error"
    discrete Real d(start = 1, fixed = true);
    Real x(start = d, fixed = true);
  equation
    der(x) = 1;
    when time > 0.5 then
      d = 2;
    end when;
  end StartOfDiscrete;
end AttributeVariabilityTest;

// Models exercising the algorithm-level for-loop unroller in NFFlatten.jl.

// `when` inside `for` in a normal algorithm section is forbidden by the
// Modelica spec; OMFrontend rejects this at SCode->FM instantiation
// (NFStatement.jl:813-822, INVALID_WHEN_STATEMENT_CONTEXT). The model is
// here to lock that rejection in place.
model AlgorithmForOfWhen
  Real x[2](each start = 0.0);
algorithm
  for i in 1:2 loop
    when time > i then
      x[i] := x[i] + 1.0;
    end when;
  end for;
end AlgorithmForOfWhen;

// for-of-if with the iterator only used as a component-reference subscript.
// Should unroll into three sequential if-statements (literal-subscript copies).
model AlgorithmForOfIfSubscript
  parameter Real t[3] = {1.0, 2.0, 3.0};
  parameter Real x[3] = {10.0, 20.0, 30.0};
  Real y(start = 0.0);
algorithm
  for i in 1:3 loop
    if time >= t[i] then
      y := x[i];
    end if;
  end for;
end AlgorithmForOfIfSubscript;

// Iterator is used as a bare value (i * coef[i]). Sequential algorithm
// semantics allow unrolling: each iteration becomes a literal-substituted
// statement that still runs in order. Should unroll.
model AlgorithmForOfIfValue
  parameter Real coef[3] = {1.0, 2.0, 3.0};
  Real total(start = 0.0);
algorithm
  for i in 1:3 loop
    total := total + i * coef[i];
  end for;
end AlgorithmForOfIfValue;

// Range exceeds the unroller cap (N=16) - must NOT unroll even though the
// body is straightforward.
model AlgorithmForOfIfBigRange
  parameter Real x[200] = ones(200);
  Real y(start = 0.0);
algorithm
  for i in 1:200 loop
    if time >= 0 then
      y := x[i];
    end if;
  end for;
end AlgorithmForOfIfBigRange;

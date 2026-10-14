/*
  A model with a recompilation directive before another class of its file: its
  SCode (the class a recompilation modifies) is its own class, not the input's
  last one, and the other class is kept for its recompilation.
*/
model GrowFirst
  parameter Integer N = 1;
  Real x[N](each start = 1.0);
equation
  for i in 1:N loop
    der(x[i]) = x[i];
  end for;
  when time > 0.5 then
    recompilation(N, 2);
  end when;
end GrowFirst;

model Other
  Real y = 1.0;
end Other;

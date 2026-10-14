/*
  A function called only in a structural mode: it is a function of the model
  (the backend generates the mode's code with the model's functions).
*/
model ModeFunction
  function twice
    input Real u;
    output Real y;
  protected
    Real acc = 0;
  algorithm
    for i in 1:2 loop
      acc := acc + u;
    end for;
    y := acc;
  end twice;
  model Single
    Real x(start = 0.0);
  equation
    der(x) = twice(time);
  end Single;
  structuralmode Single single;
equation
  initialStructuralState(single);
end ModeFunction;

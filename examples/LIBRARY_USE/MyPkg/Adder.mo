within MyPkg;
model Adder
  parameter Real a = 1.0;
  parameter Real b = 2.0;
  Real sum;
equation
  sum = a + b;
end Adder;

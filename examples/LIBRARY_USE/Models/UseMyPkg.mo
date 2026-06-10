model UseMyPkg
  MyPkg.Adder adder(a = 4.0, b = 7.5);
  Real result;
equation
  result = adder.sum;
end UseMyPkg;

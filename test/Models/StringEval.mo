model TestStringEval "String of constants, evaluated by the frontend (OpenModelica: c=0.7 s=     0.7 f=   0.700 g=0.25 n=  3 b=true)"
  constant String cs = "c=" + String(0.7) + " s=" + String(0.7, significantDigits = 3, minimumLength = 8, leftJustified = false) + " f=" + String(0.7, format = "8.3f") + " g=" + String(0.25) + " n=" + String(3, minimumLength = 3, leftJustified = false) + " b=" + String(true);
  Real x;
equation
  der(x) = 0;
  assert(x < 1, cs);
end TestStringEval;

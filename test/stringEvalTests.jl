#=
String() of constants, evaluated by the frontend (NFCeval.evalBuiltinString),
as OpenModelica formats them (Models/StringEval.mo). The Real forms called the
variadic snprintf through a plain ccall, which passed the double where
snprintf does not read it (Apple arm64): "c=1.26481e-321 ...". The format form
also lacked the "%" OpenModelica adds ("f=8.3f").
=#

stringEvalReference = "class TestStringEval
  constant String cs = \"c=0.7 s=     0.7 f=   0.700 g=0.25 n=  3 b=true\";
  Real x;
equation
  der(x) = 0.0;
  assert(x < 1.0, \"c=0.7 s=     0.7 f=   0.700 g=0.25 n=  3 b=true\", AssertionLevel.error);
end TestStringEval;
"

stringEval = (stringEvalReference, "TestStringEval", "./Models/StringEval.mo")

stringEvalTests = [stringEval]

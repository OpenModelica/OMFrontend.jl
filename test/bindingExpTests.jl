#=
Tests for BINDING_EXP handling during constant evaluation in function bodies.

These tests cover the bug in applyIndexExpArray (BindingExpression.jl) where
a package constant used as an array subscript index inside a function body
arrives wrapped in BINDING_EXP and the lambda passed to bindingExpMap had
wrong arity (2 params instead of 1).
=#

pkgSubscriptIdxReference = "class TestPkgSubscriptIdx
  parameter Real v = 0.5;
  Real h;
equation
  der(h) = 0.0;
  h = v;
end TestPkgSubscriptIdx;
"

pkgKmairAndIdxReference = "class TestPkgKmairAndIdx
  parameter Real v = 414.6431420516659;
  Real h;
equation
  der(h) = 0.0;
  h = v;
end TestPkgKmairAndIdx;
"

pkgSubscriptIdx = (pkgSubscriptIdxReference, "TestPkgSubscriptIdx", "./Models/BindingExpFuncEval.mo")
pkgKmairAndIdx  = (pkgKmairAndIdxReference,  "TestPkgKmairAndIdx",  "./Models/BindingExpFuncEval.mo")

bindingExpTests = [pkgSubscriptIdx, pkgKmairAndIdx]

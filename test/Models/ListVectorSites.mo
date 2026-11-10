package ListVectorSites
  "Models of test/listVectorTests.jl: lists and Vectors in expressions and subscripts"

  model DerSubscript "der(x) as an array binding: der(x)[i] is der(x[i])"
    Real x[2](each start = 1.0, each fixed = true);
    Real y[2] = der(x);
  equation
    der(x) = {-x[1], -2 * x[2]};
  end DerSubscript;

  model PreSubscript "pre(b) as an array binding"
    discrete Real b[2](each start = 0.0, each fixed = true);
    Real c[2] = pre(b);
  equation
    when sample(0.0, 0.1) then
      b = {pre(b[1]) + 1.0, pre(b[2]) + 2.0};
    end when;
  end PreSubscript;

  record R
    Real a;
  end R;

  model EmptyRecordArray "a field of a constant empty array of records"
    constant R rc[0] = fill(R(a = 1.0), 0);
    constant Real sc = sum(rc.a);
  end EmptyRecordArray;

  model MatrixOfThreeDims "matrix() of a constant array with three dimensions"
    constant Real a[2, 2, 1] = {{{1.0}, {2.0}}, {{3.0}, {4.0}}};
    constant Real mc[2, 2] = matrix(a);
    parameter Real m[2, 2] = matrix(a);
  end MatrixOfThreeDims;
  type E = enumeration(a, b, c);

  model TypenameSubscript "a type name with a subscript: an error, as in OpenModelica"
    parameter E es[2] = E[2:3];
  end TypenameSubscript;
end ListVectorSites;

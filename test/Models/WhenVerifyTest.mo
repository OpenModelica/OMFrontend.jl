package WhenVerifyTest "Checks of when-equation branches (NFVerifyModel)"
  model ElsewhenReinit "the branches solve n and k; reinit(x) in one of them is not a solved variable"
    Real x(start = 0, fixed = true);
    Integer n(start = 0, fixed = true);
    Integer k(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x > 1 then
      reinit(x, 0);
      n = pre(n) + 1;
      k = pre(k);
    elsewhen x > 0.5 then
      n = pre(n);
      k = pre(k) + 1;
    end when;
  end ElsewhenReinit;

  model ElsewhenDifferentVariables "invalid: the branches solve different variables"
    Real x(start = 0, fixed = true);
    Integer n(start = 0, fixed = true);
    Integer k(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x > 1 then
      n = pre(n) + 1;
    elsewhen x > 0.5 then
      k = pre(k) + 1;
    end when;
  end ElsewhenDifferentVariables;
end WhenVerifyTest;

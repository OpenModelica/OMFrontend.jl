package FlatModelicaFunctions
  "Models of test/flatModelicaFunctionTests.jl: the flat Modelica of models with functions"

  function extSin "an external function: no body"
    input Real x;
    output Real y;
  external "C" y = ext_sin(x);
  end extSin;

  function twice "the only function of OneFunction"
    input Real x;
    output Real y;
  algorithm
    y := 2 * x;
  end twice;

  model ExternalFunction "a call of an external function"
    Real y = extSin(time);
  end ExternalFunction;

  model OneFunction "one function: its function tree is a leaf"
    Real y = twice(time);
  end OneFunction;

  model NoFunction "no function: its function tree is empty"
    Real y = time;
  end NoFunction;
end FlatModelicaFunctions;

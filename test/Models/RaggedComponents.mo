package RaggedComponents "arrays of components whose dimensions differ per element (Buildings' MultiLayer: SingleLayer lay[nLay])"
  model Layer "a layer's number of states from its parameters (Buildings.HeatTransfer.Conduction.SingleLayer)"
    parameter Boolean stateAtSurface_a = true;
    parameter Boolean stateAtSurface_b = true;
    final parameter Integer nSta = if stateAtSurface_a or stateAtSurface_b then 2 else 1;
    Real T[nSta](each start = 1, each fixed = true);
  equation
    der(T) = -T;
  end Layer;

  model ConditionPerElement "the if-condition of nSta differs per element: 2, 1, 2 states (omc 1.27.1's flat model)"
    parameter Integer nLay = 3;
    Layer lay[nLay](stateAtSurface_a = {true, false, false}, stateAtSurface_b = {false, false, true});
  end ConditionPerElement;

  model ConditionAllEqual "the same condition in every element: the branch selected, 2 states each"
    Layer lay[2](each stateAtSurface_a = true, each stateAtSurface_b = false);
  end ConditionAllEqual;
end RaggedComponents;

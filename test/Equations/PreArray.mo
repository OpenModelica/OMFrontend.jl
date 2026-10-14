model PreArray "pre of an array is pre of each element (MSL StateGraph's MultiSwitch: pre(reset) = fill(false, nReset))"
  Boolean reset[2] = {time > 0.5, time > 0.7};
  Boolean y;
initial equation
  pre(reset) = fill(false, 2);
equation
  y = edge(reset[1]) or change(reset[2]);
end PreArray;

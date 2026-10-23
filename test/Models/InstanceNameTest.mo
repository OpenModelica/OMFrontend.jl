package InstanceNameTest "getInstanceName(): the simulated model's name and the instance's path in it (MLS 3.7.4), as omc's"
  block Inner
    parameter String name = getInstanceName();
  end Inner;

  model Sub
    Inner leaf;
  end Sub;

  model Top
    Sub sub;
    parameter String own = getInstanceName();
  end Top;
end InstanceNameTest;

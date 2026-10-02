model ExpandableBus
  expandable connector Bus
  end Bus;
  connector RealOutput = output Real;
  connector RealInput = input Real;
  block Src
    RealOutput y;
  equation
    y = time;
  end Src;
  block Sink
    RealInput u;
  end Sink;
  Bus bus;
  Src src;
  Sink sink;
equation
  connect(src.y, bus.x);
  connect(bus.x, sink.u);
end ExpandableBus;

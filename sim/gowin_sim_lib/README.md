# Gowin simulation library

TB4 and TB6 instantiate Gowin primitives (the dual-port block RAM and the
global set/reset `GSR`), so they need Gowin's functional simulation library
for the GW2A family. The library is proprietary and is not redistributed here.

Copy it from your Gowin IDE installation:

```
<Gowin install dir>/IDE/simlib/gw2a/prim_sim.v  ->  sim/gowin_sim_lib/gw2a/prim_sim.v
```

TB1, TB2, TB3 and TB5 do not need it.

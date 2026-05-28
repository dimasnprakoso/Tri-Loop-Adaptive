# Scenario 3 — generator-loss frequency event.
# Equivalent to losing 5% of synchronous capacity at t=2s, modelled as a
# step increase in net load (since system_average uses single-area swing).
# Tests primary frequency response & RoCoF containment.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))
include(joinpath(@__DIR__, "_harness.jl"))

p = default_params()
P_BASE = 0.95 * p.P_rated
P_LOSS = 0.10 * p.P_rated   # 12.5 kW — 10% of rated, severe but realistic

run_scenario("s3_freq_event";
    desc="generator loss equivalent +10% load step at t=2 s",
    tspan=(0.0, 10.0),
    G_profile=t->1000.0, T_profile=t->30.0,
    P_load_profile=t-> t<2.0 ? P_BASE : P_BASE + P_LOSS,
    H_sys=4.0, D_sys=5.0, t_event=2.0)

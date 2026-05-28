# Scenario 1 — normal day, +5% load step at t=2 s.
# Constant irradiance & temperature. Compare 4 control schemes.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))
include(joinpath(@__DIR__, "_harness.jl"))

p = default_params()
P_BASE_LOAD = 0.99 * p.P_rated
P_STEP      = 0.05 * p.P_rated

run_scenario("s1_normal";
    desc="load step +5% at t=2 s, H_sys=4",
    tspan=(0.0, 10.0),
    G_profile=t->1000.0, T_profile=t->30.0,
    P_load_profile=t-> t<2.0 ? P_BASE_LOAD : P_BASE_LOAD + P_STEP,
    H_sys=4.0, D_sys=5.0, t_event=2.0)

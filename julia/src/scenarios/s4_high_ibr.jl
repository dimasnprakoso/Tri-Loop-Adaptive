# Scenario 4 — high-IBR / extreme low-inertia.
# Same disturbance as S3 but H_sys = 0.5 s (90% IBR penetration).
# This is the regime where VIC matters most. PROPOSED should clearly
# dominate baselines.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))
include(joinpath(@__DIR__, "_harness.jl"))

p = default_params()
P_BASE = 0.95 * p.P_rated
P_LOSS = 0.10 * p.P_rated

run_scenario("s4_high_ibr";
    desc="generator loss +10% step, H_sys=0.5 s (90% IBR)",
    tspan=(0.0, 10.0),
    G_profile=t->1000.0, T_profile=t->30.0,
    P_load_profile=t-> t<2.0 ? P_BASE : P_BASE + P_LOSS,
    H_sys=0.5, D_sys=2.0, t_event=2.0)

# Scenario 5 — weak grid (placeholder).
# Models a low-SCR grid by reducing both H_sys and D_sys, plus a small
# voltage sag proxy (modelled here only via reduced damping). Full
# Thevenin impedance + voltage sag dynamics will be added in Phase 6
# (small-signal study) once the grid_thevenin module is wired into the
# average-model state.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))
include(joinpath(@__DIR__, "_harness.jl"))

p = default_params()
P_BASE = 0.95 * p.P_rated
P_LOSS = 0.05 * p.P_rated

# Approximate weak-grid via low effective damping. SCR-aware PLL
# detuning is already implemented in pll_sofi.jl; integration into the
# closed loop is queued for Phase 6.
run_scenario("s5_weak_grid";
    desc="weak grid proxy: H_sys=1, D_sys=1, +5% load step",
    tspan=(0.0, 10.0),
    G_profile=t->1000.0, T_profile=t->30.0,
    P_load_profile=t-> t<2.0 ? P_BASE : P_BASE + P_LOSS,
    H_sys=1.0, D_sys=1.0, t_event=2.0)

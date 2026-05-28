# Scenario 2 — cloud passing event.
# Irradiance ramps 1000 → 300 → 1000 W/m² with 1 s ramps, dwell 2 s.
# Constant load. Tests MPPT tracking + system response to source variability.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))
include(joinpath(@__DIR__, "_harness.jl"))

p = default_params()

# Smooth ramp: 1000 W/m² (0-1s) → ramp down (1-2s) → 300 W/m² (2-4s) → ramp up (4-5s) → 1000 (5-10s)
function G_cloud(t)
    if t < 1.0
        return 1000.0
    elseif t < 2.0
        return 1000.0 - 700.0 * (t - 1.0)
    elseif t < 4.0
        return 300.0
    elseif t < 5.0
        return 300.0 + 700.0 * (t - 4.0)
    else
        return 1000.0
    end
end

P_LOAD = 0.7 * p.P_rated   # ~87.5 kW so partial-cloud mid still meets demand

run_scenario("s2_cloud_passing";
    desc="irradiance 1000→300→1000 W/m² ramp, constant load",
    tspan=(0.0, 10.0),
    G_profile=G_cloud, T_profile=t->30.0,
    P_load_profile=t->P_LOAD,
    H_sys=4.0, D_sys=5.0, t_event=1.0)

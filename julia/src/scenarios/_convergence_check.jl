# Convergence check for Paper #3 — verify the s7/s7b sweep metrics are
# time-step independent. Re-runs 5 representative cells at dt=25 µs and
# compares to the dt=50 µs baseline.
#
# Cells covered: corners and Madiun-baseline midpoint.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))
using PVBessVIC
using Printf

const T_EVENT       = 2.0
const HORIZON_S     = 60.0    # 60s is enough for RoCoF/|df| metrics
const STEP_FRAC     = 0.10
const BASE_FRAC     = 0.95
const G_STC         = 1000.0
const T_C           = 30.0

# 7 cells: 5 corners + 2 borderline cells at H=0.5 (the Cat I boundary
# is steepest there, so dt sensitivity matters most for pass/fail decisions)
const CELLS = [
    (0.5, 3.0,   Inf),
    (0.5, 10.0,  Inf),   # borderline FAIL at dt=50µs
    (0.5, 15.0,  Inf),   # borderline PASS at dt=50µs
    (0.5, 30.0,  Inf),
    (2.0, 3.0,   Inf),
    (0.5, 3.0,   30.0),
    (0.5, 30.0,  30.0),
]

function run_cell(H::Float64, D::Float64, tau::Float64, dt::Float64)
    p = default_params()
    # Override Ts_control while keeping Ts_supervisor proportional (1 ms = 20×dt at 50µs;
    # halve dt → keep Ts_supervisor at 1 ms; AGC integrator dt argument follows Ts_supervisor)
    p2 = SystemParams(Ts_control=dt, Ts_supervisor=p.Ts_supervisor)

    P_BASE = BASE_FRAC * p2.P_rated
    P_STEP = STEP_FRAC * p2.P_rated

    P_load_func = function (t::Float64)
        return t < T_EVENT ? P_BASE : P_BASE + P_STEP
    end

    sol = simulate_baseline(p2;
        tspan=(0.0, HORIZON_S),
        G_profile=t -> G_STC,
        T_profile=t -> T_C,
        P_load_profile=P_load_func,
        H_sys=H, D_sys=D,
        use_vic=true, use_adaptive_vic=true, use_fuzzy_vic=false,
        use_adaptive_coord=true, use_bess=true,
        tau_AGC=tau, t_agc_enable=T_EVENT)

    rcf = rocof(sol.t, sol.f; t_event=T_EVENT)
    nad = nadir_deviation(sol.t, sol.f; t_event=T_EVENT)
    return (rcf, nad)
end

function run_convergence_check()
    println("=== Convergence check: dt=50 µs vs dt=25 µs (Paper #3) ===\n")
    @printf("%-25s  %12s  %12s  %12s  %12s  %12s  %12s\n",
            "Cell (H, D, tau)",
            "RoCoF@50µs", "RoCoF@25µs", "ΔRoCoF",
            "|df|@50µs", "|df|@25µs", "Δ|df|")

    max_drocof = 0.0
    max_ddf = 0.0
    for (H, D, tau) in CELLS
        rcf50, nad50 = run_cell(H, D, tau, 50e-6)
        rcf25, nad25 = run_cell(H, D, tau, 25e-6)
        drocof = abs(rcf50 - rcf25)
        ddf    = abs(nad50 - nad25)
        max_drocof = max(max_drocof, drocof)
        max_ddf = max(max_ddf, ddf)
        tau_str = isinf(tau) ? "Inf" : @sprintf("%.0f", tau)
        cell_str = @sprintf("(%.1f, %.1f, %s)", H, D, tau_str)
        @printf("%-25s  %12.6f  %12.6f  %12.2e  %12.6f  %12.6f  %12.2e\n",
                cell_str, rcf50, rcf25, drocof, nad50, nad25, ddf)
    end

    println()
    @printf("Max ΔRoCoF: %.4e Hz/s\n", max_drocof)
    @printf("Max Δ|df|:  %.4e Hz\n",   max_ddf)
    println("\n=== Convergence check DONE ===")
end

run_convergence_check()

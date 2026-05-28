# Fase 5 — Monte Carlo robustness sweep.
# Sweep 5 variabel via random sampling untuk uji robustness 5 skema kontrol
# pada skenario referensi S3 (frequency event). Hasil ditulis ke
# results/processed/mc_runs.csv untuk analisis Python (Pareto front +
# histogram + 95 % CI).
#
# Variabel sweep:
#   SCR              ∈ U(1.5, 8.0)         short-circuit ratio
#   H_sys            ∈ U(0.5, 6.0) s       system inertia (high-IBR ↔ baseline)
#   ΔP_load          ∈ U(0.05, 0.15) pu    disturbance magnitude
#   SOC_init         ∈ U(0.30, 0.80)       initial battery SOC
#   gain_scale       ∈ U(0.7, 1.3)         multiplikator H_max / D_max / β_max
#                                          (hanya berdampak pada C2/C3/C4 yang
#                                          punya gain adaptif/fuzzy)

using Pkg; Pkg.activate(joinpath(@__DIR__, "..", ".."))
using PVBessVIC
using Random
using Statistics
using Distributed
using DataFrames
using CSV
using Printf

const RESULTS = joinpath(@__DIR__, "..", "..", "..", "results")
const PROC    = joinpath(RESULTS, "processed")
mkpath(PROC)

const N_RUNS_DEFAULT = 500
const RNG_SEED = 20260502

# Konfigurasi skema sama dengan _harness.jl tapi inline supaya monte_carlo
# dapat di-jalankan tanpa include harness (hindari side-effect run scenario).
const SCHEMES_MC = [
    (id="C0_no_vic",     use_vic=false, use_avic=false, use_fvic=false, use_acoord=false, use_bess=false),
    (id="C1_const_vic",  use_vic=true,  use_avic=false, use_fvic=false, use_acoord=false, use_bess=true),
    (id="C2_fuzzy_vic",  use_vic=true,  use_avic=false, use_fvic=true,  use_acoord=false, use_bess=true),
    (id="C3_adapt_vic",  use_vic=true,  use_avic=true,  use_fvic=false, use_acoord=false, use_bess=true),
    (id="C4_proposed",   use_vic=true,  use_avic=true,  use_fvic=false, use_acoord=true,  use_bess=true),
]

"""
Buat SystemParams dengan gain VIC di-skala oleh `gain_scale`.
Hanya H_max/D_max/β_max yang di-skala (parameter yang membedakan adaptive
schemes); H_min/D_min tetap supaya C1 const-VIC tidak terdampak.
"""
function scaled_params(gain_scale::Float64; SCR::Float64=5.0, SOC0::Float64=0.6)
    base = default_params()
    return SystemParams(
        Iph_stc=base.Iph_stc, I0=base.I0, Rs=base.Rs, Rsh=base.Rsh, a=base.a,
        Vt_stc=base.Vt_stc, Ns=base.Ns, Np_strings=base.Np_strings,
        Ns_modules=base.Ns_modules, G_stc=base.G_stc, T_stc=base.T_stc,
        Ki=base.Ki, Kv=base.Kv,
        E_rated_kWh=base.E_rated_kWh, eta_ch=base.eta_ch, eta_dis=base.eta_dis,
        SOC_min=base.SOC_min, SOC_max=base.SOC_max, SOC_init=SOC0,
        P_bess_max=base.P_bess_max,
        L_filter=base.L_filter, R_filter=base.R_filter, C_dc=base.C_dc,
        Kp_idq=base.Kp_idq, Ki_idq=base.Ki_idq, Kp_vdc=base.Kp_vdc, Ki_vdc=base.Ki_vdc,
        Kp_pll=base.Kp_pll, Ki_pll=base.Ki_pll,
        omega_n_pll_max=base.omega_n_pll_max, SCR_thr=base.SCR_thr,
        H_min=base.H_min,
        H_max=base.H_max * gain_scale,
        D_min=base.D_min,
        D_max=base.D_max * gain_scale,
        gamma_J=base.gamma_J, delta_D=base.delta_D,
        omega_dot_ref=base.omega_dot_ref, omega_ref_vic=base.omega_ref_vic,
        T_filter_omega=base.T_filter_omega, T_lead_RoCoF=base.T_lead_RoCoF,
        T_lag_droop=base.T_lag_droop,
        P_vic_max=base.P_vic_max,
        k_alpha=base.k_alpha, k_alpha_rocof=base.k_alpha_rocof,
        beta_max=base.beta_max * gain_scale,
        Δω_dead=base.Δω_dead,
        V_grid=base.V_grid,
        SCR=SCR,
        X_R=base.X_R,
        Ts_control=base.Ts_control, Ts_supervisor=base.Ts_supervisor,
        # ratings
        P_rated=base.P_rated, V_dc_ref=base.V_dc_ref, f0=base.f0, omega0=base.omega0,
    )
end

"""Run 1 sample (semua skema) dengan parameter random; return Vector{NamedTuple}."""
function run_one_sample(run_id::Int, rng::AbstractRNG)
    SCR        = 1.5 + (8.0 - 1.5)*rand(rng)
    H_sys      = 0.5 + (6.0 - 0.5)*rand(rng)
    ΔP_pu      = 0.05 + (0.15 - 0.05)*rand(rng)
    SOC0       = 0.30 + (0.80 - 0.30)*rand(rng)
    gain_scale = 0.7 + (1.3 - 0.7)*rand(rng)
    D_sys      = 1.0 + 4.0*rand(rng)

    p = scaled_params(gain_scale; SCR=SCR, SOC0=SOC0)
    P_BASE = 0.85 * p.P_rated
    P_LOSS = ΔP_pu * p.P_rated
    P_load_func = t -> t < 2.0 ? P_BASE : P_BASE + P_LOSS
    G_func = t -> 1000.0
    T_func = t -> 30.0
    tspan  = (0.0, 8.0)
    t_event = 2.0

    rows = NamedTuple[]
    for s in SCHEMES_MC
        sol = simulate_baseline(p;
            tspan=tspan, G_profile=G_func, T_profile=T_func,
            P_load_profile=P_load_func, H_sys=H_sys, D_sys=D_sys,
            use_vic=s.use_vic, use_adaptive_vic=s.use_avic,
            use_fuzzy_vic=s.use_fvic, use_adaptive_coord=s.use_acoord,
            use_bess=s.use_bess)
        rcf  = rocof(sol.t, sol.f; t_event=t_event)
        nad  = nadir_deviation(sol.t, sol.f; t_event=t_event)
        sts  = settling_time(sol.t, sol.f; t_event=t_event, band_Hz=0.05)
        sts_loose = settling_time(sol.t, sol.f; t_event=t_event, band_Hz=0.2)
        dt_log = sol.t[2] - sol.t[1]
        bess_kWh = sum(abs.(sol.Pbess)) * dt_log / 3.6e6
        steady_window = sol.t .>= max(sol.t[end] - 1.5, t_event + 1.0)
        pinj_p2p = isempty(findall(steady_window)) ? NaN :
                   (maximum(sol.Pgrid[steady_window]) - minimum(sol.Pgrid[steady_window])) / 1e3
        # Δf at end-of-horizon: indikator steady-state offset (primary-control only)
        end_window = sol.t .>= sol.t[end] - 1.0
        df_end = isempty(findall(end_window)) ? NaN :
                 maximum(abs.(sol.f[end_window] .- 50.0))
        push!(rows, (
            run_id=run_id, scheme=s.id,
            SCR=SCR, H_sys=H_sys, D_sys=D_sys,
            dP_pu=ΔP_pu, SOC0=SOC0, gain_scale=gain_scale,
            rocof=rcf, dfmax=nad, settling=sts, settling_loose=sts_loose,
            df_end=df_end,
            bess_throughput_kWh=bess_kWh, pinj_p2p_steady_kW=pinj_p2p,
            soc_end=sol.SOC[end],
        ))
    end
    return rows
end

function main(N::Int=N_RUNS_DEFAULT)
    println("Monte Carlo: $N runs × $(length(SCHEMES_MC)) skema   (Threads=$(Threads.nthreads()))")
    all_rows = Vector{Vector{NamedTuple}}(undef, N)
    t_start = time()
    counter = Threads.Atomic{Int}(0)
    Threads.@threads for k in 1:N
        rng_k = MersenneTwister(RNG_SEED + k)
        all_rows[k] = run_one_sample(k, rng_k)
        c = Threads.atomic_add!(counter, 1) + 1
        if c % 25 == 0
            elapsed = time() - t_start
            eta = elapsed / c * (N - c)
            @printf("  %4d/%d  elapsed %.0fs  ETA %.0fs\n", c, N, elapsed, eta)
            flush(stdout)
        end
    end
    flat = reduce(vcat, all_rows)
    df = DataFrame(flat)
    out = joinpath(PROC, "mc_runs.csv")
    CSV.write(out, df)
    println("Saved → $(out)   ($(nrow(df)) baris)")
    println("Elapsed: $(round(time() - t_start, digits=1)) s")
    return df
end

if abspath(PROGRAM_FILE) == @__FILE__
    N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : N_RUNS_DEFAULT
    main(N)
end

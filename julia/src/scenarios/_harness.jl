# Shared scenario harness — keeps every scenario script tiny, ensures
# uniform metrics computation, raw .jld2 + .h5, and a metrics .csv row.

using PVBessVIC
using JLD2
using HDF5
using CSV
using DataFrames
using Printf

const T_EVENT_DEFAULT = 2.0

const SCHEMES = [
    (id="C0_no_vic",     label="C0 no-VIC no-BESS",     use_vic=false, use_avic=false, use_fvic=false, use_acoord=false, use_bess=false),
    (id="C1_const_vic",  label="C1 const-VIC + BESS",   use_vic=true,  use_avic=false, use_fvic=false, use_acoord=false, use_bess=true),
    (id="C2_fuzzy_vic",  label="C2 fuzzy-VIC + BESS",   use_vic=true,  use_avic=false, use_fvic=true,  use_acoord=false, use_bess=true),
    (id="C3_adapt_vic",  label="C3 adaptive-VIC + BESS",use_vic=true,  use_avic=true,  use_fvic=false, use_acoord=false, use_bess=true),
    (id="C4_proposed",   label="C4 PROPOSED full",      use_vic=true,  use_avic=true,  use_fvic=false, use_acoord=true,  use_bess=true),
]

"""
Run all 4 control schemes for a given scenario configuration and persist
results to results/raw/<sid>.jld2, .h5, and append metrics to
results/processed/scenarios_metrics.csv.
"""
# Downsample factor: emit one sample per `Ts_log` seconds di output JLD2/H5,
# sambil simulasi tetap pakai dt=Ts_control 50 µs. Default 1 ms → 20×
# reduction file size, masih cukup tinggi untuk metric RoCoF window 100 ms.
const TS_LOG_DEFAULT = 1e-3

function _downsample(sol, Ts_log::Float64)
    dt = sol.t[2] - sol.t[1]
    stride = max(Int(round(Ts_log / dt)), 1)
    idx = 1:stride:length(sol.t)
    nt = NamedTuple{propertynames(sol)}(
        ntuple(i -> getfield(sol, i)[idx], length(propertynames(sol)))
    )
    return nt
end

function run_scenario(sid::String;
                       p::SystemParams=default_params(),
                       tspan=(0.0, 10.0),
                       G_profile, T_profile, P_load_profile,
                       H_sys::Float64=4.0, D_sys::Float64=5.0,
                       t_event::Float64=T_EVENT_DEFAULT,
                       desc::String="",
                       Ts_log::Float64=TS_LOG_DEFAULT)
    sols = Dict{String, Any}()
    rows = DataFrame(scenario=String[], scheme=String[],
                     rocof=Float64[], dfmax=Float64[], settling=Float64[],
                     bess_throughput_kWh=Float64[], pinj_p2p_steady_kW=Float64[],
                     soc_end=Float64[])

    println("\n=== Scenario $(sid)  $(desc) ===")
    for s in SCHEMES
        sol = simulate_baseline(p;
            tspan=tspan, G_profile=G_profile, T_profile=T_profile,
            P_load_profile=P_load_profile, H_sys=H_sys, D_sys=D_sys,
            use_vic=s.use_vic, use_adaptive_vic=s.use_avic,
            use_fuzzy_vic=s.use_fvic,
            use_adaptive_coord=s.use_acoord, use_bess=s.use_bess)
        rcf  = rocof(sol.t, sol.f; t_event=t_event)
        nad  = nadir_deviation(sol.t, sol.f; t_event=t_event)
        sts  = settling_time(sol.t, sol.f; t_event=t_event, band_Hz=0.05)
        dt = sol.t[2] - sol.t[1]
        # cumulative |P_bess|·dt as proxy untuk siklus baterai
        bess_kWh = sum(abs.(sol.Pbess)) * dt / 3.6e6
        # steady-state ripple: peak-to-peak P_inj di window terakhir 1.5 s
        steady_window = sol.t .>= max(sol.t[end] - 1.5, t_event + 1.0)
        pinj_p2p = isempty(findall(steady_window)) ? NaN :
                   (maximum(sol.Pgrid[steady_window]) - minimum(sol.Pgrid[steady_window])) / 1e3
        @printf("[%-32s] RoCoF=%6.3f Hz/s  |Δf|=%6.4f Hz  t_s=%6.3f s  BESS=%5.3f kWh  P_p2p=%6.3f kW  SOC=%5.2f%%\n",
                s.label, rcf, nad, sts, bess_kWh, pinj_p2p, sol.SOC[end]*100)
        flush(stdout)
        # downsample sebelum simpan ke disk supaya file size manageable di S6
        sols[s.id] = _downsample(sol, Ts_log)
        push!(rows, (sid, s.id, rcf, nad, sts, bess_kWh, pinj_p2p, sol.SOC[end]))
    end

    resdir = joinpath(@__DIR__, "..", "..", "..", "results")
    rawdir = joinpath(resdir, "raw"); mkpath(rawdir)
    procdir = joinpath(resdir, "processed"); mkpath(procdir)

    jld_path = joinpath(rawdir, "$(sid).jld2")
    @save jld_path sols
    h5_path = joinpath(rawdir, "$(sid).h5")
    h5open(h5_path, "w") do h5
        for (case, sol) in sols
            g = create_group(h5, case)
            for fname in propertynames(sol)
                arr = collect(getproperty(sol, fname))
                g[String(fname)] = Array{Float64}(arr)
            end
        end
    end

    # append metrics CSV (cumulative across scenarios)
    csv_path = joinpath(procdir, "scenarios_metrics.csv")
    if isfile(csv_path)
        df_prev = CSV.read(csv_path, DataFrame)
        df_prev = filter(r -> r.scenario != sid, df_prev)
        rows = vcat(df_prev, rows)
    end
    CSV.write(csv_path, rows)
    println("Saved → $(jld_path)\nSaved → $(h5_path)\nMetrics → $(csv_path)")
    return sols, rows
end

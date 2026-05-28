# Export Julia .h5 ground-truth ke CSV untuk validasi silang Simulink.
#
# Reads:  results/raw/s1_normal.h5, results/raw/s3_freq_event.h5
# Writes: data/simulink_ref/julia_s1_C4.csv, data/simulink_ref/julia_s3_C4.csv
#
# Format CSV match dengan output MATLAB matlab/postprocess/export_to_csv.m
# (kolom: t, f, rocof, V_dc, P_mppt, P_vic, P_ref, P_inj, P_bess, SOC,
#         alpha, beta, H_eff)

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "..", "julia"))

using HDF5
using DataFrames
using CSV

const REPO     = joinpath(@__DIR__, "..", "..")
const RAW_DIR  = joinpath(REPO, "results", "raw")
const OUT_DIR  = joinpath(REPO, "data", "simulink_ref")
const TS_LOG   = 1e-3
const V_DC_REF = 1200.0  # Julia averaged model assume V_dc konstan

mkpath(OUT_DIR)

# Linear interpolation onto uniform grid
function resample_uniform(t::Vector{Float64}, y::Vector{Float64},
                          t_grid::Vector{Float64})::Vector{Float64}
    out = similar(t_grid)
    n = length(t)
    for (i, tq) in enumerate(t_grid)
        if tq <= t[1]
            out[i] = y[1]
        elseif tq >= t[end]
            out[i] = y[end]
        else
            j = searchsortedfirst(t, tq)
            t0, t1 = t[j-1], t[j]
            y0, y1 = y[j-1], y[j]
            out[i] = y0 + (y1 - y0) * (tq - t0) / (t1 - t0)
        end
    end
    return out
end

function export_scenario(scenario_id::String, h5_filename::String)
    h5_path = joinpath(RAW_DIR, h5_filename)
    isfile(h5_path) || error("$(h5_path) tidak ditemukan. Run dulu: julia --project=julia .claude_run_s1_s3.jl")

    data = Dict{String, Vector{Float64}}()
    h5open(h5_path, "r") do f
        g = f["C4_proposed"]
        for k in keys(g)
            data[k] = vec(read(g[k]))
        end
    end

    t = data["t"]
    t_grid = collect(0.0:TS_LOG:t[end])

    df = DataFrame(
        t      = t_grid,
        f      = resample_uniform(t, data["f"],     t_grid),
        rocof  = resample_uniform(t, data["rocof"], t_grid),
        V_dc   = fill(V_DC_REF, length(t_grid)),
        P_mppt = resample_uniform(t, data["Pmppt"], t_grid),
        P_vic  = resample_uniform(t, data["Pvic"],  t_grid),
        P_ref  = resample_uniform(t, data["Pref"],  t_grid),
        P_inj  = resample_uniform(t, data["Pgrid"], t_grid),
        P_bess = resample_uniform(t, data["Pbess"], t_grid),
        SOC    = resample_uniform(t, data["SOC"],   t_grid),
        alpha  = resample_uniform(t, data["alpha"], t_grid),
        beta   = resample_uniform(t, data["beta"],  t_grid),
        H_eff  = resample_uniform(t, data["H"],     t_grid),
    )

    out_path = joinpath(OUT_DIR, "julia_$(scenario_id)_C4.csv")
    CSV.write(out_path, df)
    println("[export] $(scenario_id): wrote $(out_path) ($(nrow(df)) rows)")
    return out_path
end

export_scenario("s1", "s1_normal.h5")
export_scenario("s3", "s3_freq_event.h5")
println("DONE")

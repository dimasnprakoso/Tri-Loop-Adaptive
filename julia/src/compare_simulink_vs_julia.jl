# Validasi silang Julia vs MATLAB/Simulink — versi Julia.
# Compute RMSE saja (no plotting). Plotting via Python script kalau tersedia.
#
# Reads:
#   data/simulink_ref/julia_{s1,s3}_C4.csv    (dari export_to_csv.jl)
#   data/simulink_ref/matlab_{s1,s3}_C4.csv   (dari MATLAB export_to_csv.m)
#
# Writes:
#   results/processed/validation_simulink_rmse.csv
#
# Acceptance threshold (PIPELINE.md Section 8 + spec_simulink.md Section 8):
#   RMSE f(t)     < 0.01 Hz   (10 mHz)
#   RMSE P_inj(t) < 2.5 kW    (2% × P_rated 125 kW)
#   RMSE V_dc(t)  < 24 V      (2% × V_dc_ref 1200 V)
# Window: t ∈ [t_event + 0.1, t_event + 5.0] = [2.1, 7.0] s

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "..", "julia"))
using DataFrames
using CSV

const REPO     = joinpath(@__DIR__, "..", "..")
const REF_DIR  = joinpath(REPO, "data", "simulink_ref")
const PROC_DIR = joinpath(REPO, "results", "processed")
const T_EVENT  = 2.0
const WINDOW   = (T_EVENT + 0.1, T_EVENT + 5.0)
const THRESH   = (f = 0.01, P_inj = 2.5e3, V_dc = 24.0)

function load_pair(scenario_id::String)
    julia_path = joinpath(REF_DIR, "julia_$(scenario_id)_C4.csv")
    matlab_path = joinpath(REF_DIR, "matlab_$(scenario_id)_C4.csv")
    isfile(julia_path) || error("Julia CSV missing: $(julia_path)")
    isfile(matlab_path) || error("MATLAB CSV missing: $(matlab_path). Run MATLAB run_s1.m / run_s3.m + export_to_csv.m dulu.")
    return CSV.read(julia_path, DataFrame), CSV.read(matlab_path, DataFrame)
end

function interp_to_grid(df::DataFrame, t_grid::Vector{Float64}, col::Symbol)::Vector{Float64}
    t = df.t
    y = df[!, col]
    out = similar(t_grid)
    for (i, tq) in enumerate(t_grid)
        if tq <= t[1]
            out[i] = y[1]
        elseif tq >= t[end]
            out[i] = y[end]
        else
            j = searchsortedfirst(t, tq)
            out[i] = y[j-1] + (y[j] - y[j-1]) * (tq - t[j-1]) / (t[j] - t[j-1])
        end
    end
    return out
end

function rmse_in_window(julia_df::DataFrame, matlab_df::DataFrame, col::Symbol)::Float64
    t_min = max(julia_df.t[1], matlab_df.t[1], WINDOW[1])
    t_max = min(julia_df.t[end], matlab_df.t[end], WINDOW[2])
    t_grid = collect(t_min:1e-3:t_max)
    yJ = interp_to_grid(julia_df, t_grid, col)
    yM = interp_to_grid(matlab_df, t_grid, col)
    return sqrt(sum((yJ .- yM).^2) / length(t_grid))
end

function evaluate(scenario_id::String)
    println("\n=== $(uppercase(scenario_id)) ===")
    julia_df, matlab_df = load_pair(scenario_id)

    rmse_f     = rmse_in_window(julia_df, matlab_df, :f)
    rmse_P_inj = rmse_in_window(julia_df, matlab_df, :P_inj)
    rmse_V_dc  = rmse_in_window(julia_df, matlab_df, :V_dc)

    pass_f = rmse_f < THRESH.f
    pass_P = rmse_P_inj < THRESH.P_inj
    pass_V = rmse_V_dc < THRESH.V_dc
    verdict = (pass_f && pass_P && pass_V) ? "PASS" : "FAIL"

    println("  RMSE f      = $(round(rmse_f * 1000, digits=3)) mHz  (thr $(THRESH.f * 1000) mHz)  $(pass_f ? "✓" : "✗")")
    println("  RMSE P_inj  = $(round(rmse_P_inj / 1e3, digits=3)) kW  (thr $(THRESH.P_inj / 1e3) kW)  $(pass_P ? "✓" : "✗")")
    println("  RMSE V_dc   = $(round(rmse_V_dc, digits=3)) V  (thr $(THRESH.V_dc) V)  $(pass_V ? "✓" : "✗")")
    println("  Verdict: $(verdict)")

    return (
        scenario      = scenario_id,
        rmse_f_Hz     = rmse_f,
        rmse_P_inj_W  = rmse_P_inj,
        rmse_V_dc_V   = rmse_V_dc,
        pass_f        = pass_f,
        pass_P_inj    = pass_P,
        pass_V_dc     = pass_V,
        verdict       = verdict,
    )
end

function main()
    rows = [evaluate("s1"), evaluate("s3")]
    df = DataFrame(rows)
    mkpath(PROC_DIR)
    out_csv = joinpath(PROC_DIR, "validation_simulink_rmse.csv")
    CSV.write(out_csv, df)
    println("\nSaved → $(out_csv)")

    n_fail = count(==("FAIL"), df.verdict)
    if n_fail > 0
        println("\n[!] $(n_fail) skenario gagal RMSE threshold.")
    else
        println("\n[OK] Semua skenario lulus. Bump Paper #1 ke v1.0 + isi appendix.")
    end
end

main()

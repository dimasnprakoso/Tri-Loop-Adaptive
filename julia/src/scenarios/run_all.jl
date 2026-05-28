# Sequentially run S1..S5 and rebuild the cumulative metrics CSV.
using Pkg; Pkg.activate(joinpath(@__DIR__, "..", ".."))

# clear cumulative CSV first to avoid stale rows
metrics_csv = joinpath(@__DIR__, "..", "..", "..", "results", "processed", "scenarios_metrics.csv")
isfile(metrics_csv) && rm(metrics_csv)

for s in ["s1_normal.jl", "s2_cloud_passing.jl", "s3_freq_event.jl",
          "s4_high_ibr.jl", "s5_weak_grid.jl"]
    println("\n======================================================")
    println("RUNNING: ", s)
    println("======================================================")
    include(joinpath(@__DIR__, s))
end

println("\n\n=== ALL SCENARIOS COMPLETE ===")
println("Cumulative metrics → ", metrics_csv)

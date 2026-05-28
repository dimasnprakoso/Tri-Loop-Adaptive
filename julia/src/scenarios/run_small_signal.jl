# Driver Fase 6 — eigenvalue locus + damping ratio analysis.
# Output: results/processed/eigenvalue_locus.csv (long-format) untuk
# konsumsi Python plotting.

using Pkg; Pkg.activate(joinpath(@__DIR__, "..", ".."))
using PVBessVIC
using DataFrames
using CSV
using Printf
using LinearAlgebra: eigvals

const RESULTS = joinpath(@__DIR__, "..", "..", "..", "results")
const PROC = joinpath(RESULTS, "processed")
mkpath(PROC)

base = default_params()

# Skenario operating-point: H_sys=2 (campuran sintkron-IBR sedang),
# D_sys=2 (damping sedang). Ini matches Paper #1 nominal.
const H_SYS = 2.0
const D_SYS = 2.0

println("=== Phase 6: Small-signal eigenvalue analysis ===\n")

# Eigenvalue di operating point untuk 4 skema (C1, C2, C3, C4)
println("Nominal eigenvalues per scheme (H_sys=$(H_SYS), D_sys=$(D_SYS)):")
for sc in [:C1, :C2, :C3, :C4]
    A = compute_A(base; H_sys=H_SYS, D_sys=D_SYS, scheme=sc)
    modes = modal_analysis(A)
    println("\nScheme $(sc):")
    for (i, m) in enumerate(modes)
        @printf("  λ_%d = %+8.3f %+8.3fj   ω_n=%6.2f rad/s  ζ=%6.3f  f_n=%6.2f Hz\n",
                i, real(m.eigenvalue), imag(m.eigenvalue),
                m.omega_n, m.damping, m.freq_Hz)
    end
end

# === Off-equilibrium linearization ===
# Linearize di sustained-fault operating point: |Δω| > Δω_dead, |dωdt|>0.
# Saat ini, adaptive gain (tanh) sudah saturated → H_t≠H_min. Skema C1/C2/C3
# vs C4 mestinya menunjukkan eigenvalue locus yang berbeda. Kita evaluate
# linearization Jacobian dengan x0 ≠ 0 dan re-compute pakai forward FD.

println("\n\n=== Off-equilibrium eigenvalues (Δω = 1 rad/s ≈ 0.16 Hz, dωdt = 1 rad/s²) ===")

function compute_A_offeq(p::SystemParams; H_sys, D_sys, scheme,
                          x0::Vector{Float64}, eps::Float64=1e-5)
    f0 = PVBessVIC.dynamics_linearized(x0, 0.0, p; H_sys=H_sys, D_sys=D_sys, scheme=scheme)
    n = length(x0)
    A = zeros(n, n)
    for j in 1:n
        scale = j == 5 ? 0.01 : 1e-3
        h = eps * scale
        xp = copy(x0); xp[j] += h
        fp = PVBessVIC.dynamics_linearized(xp, 0.0, p; H_sys=H_sys, D_sys=D_sys, scheme=scheme)
        A[:, j] = (fp - f0) / h
    end
    return A
end

x0_offeq = [1.0, 1.0, 1.0, 0.0, 0.0]   # Δω, dωdt_filt, Δω_filt, P_vic_filt, ΔSOC
println("State perturbation: x0 = $(x0_offeq)")
for sc in [:C1, :C2, :C3, :C4]
    A = compute_A_offeq(base; H_sys=H_SYS, D_sys=D_SYS, scheme=sc, x0=x0_offeq)
    modes = modal_analysis(A)
    println("\nScheme $(sc) (off-equilibrium):")
    for (i, m) in enumerate(modes)
        @printf("  λ_%d = %+8.3f %+8.3fj   ω_n=%6.2f rad/s  ζ=%6.3f  f_n=%6.2f Hz\n",
                i, real(m.eigenvalue), imag(m.eigenvalue),
                m.omega_n, m.damping, m.freq_Hz)
    end
end

# Sweep |Δω_filt| dari 0..2 rad/s untuk eigenvalue locus per skema
println("\n\n=== Off-equilibrium sweep |Δω_filt| ∈ [0..2] rad/s ===")
offeq_rows = NamedTuple[]
for Δω_val in 0.0:0.1:2.0
    x_op = [Δω_val, 0.5*Δω_val, Δω_val, 0.0, 0.0]
    for sc in [:C1, :C2, :C3, :C4]
        A = compute_A_offeq(base; H_sys=H_SYS, D_sys=D_SYS, scheme=sc, x0=x_op)
        for (k, ev) in enumerate(eigvals(A))
            ζ = abs(ev) ≈ 0 ? 1.0 : -real(ev)/abs(ev)
            push!(offeq_rows, (scheme=String(sc), Δω_op=Δω_val,
                               mode_idx=k, real=real(ev), imag=imag(ev),
                               omega_n=abs(ev), damping=ζ))
        end
    end
end
df_offeq = DataFrame(offeq_rows)
csv_offeq = joinpath(PROC, "eigenvalue_offeq.csv")
CSV.write(csv_offeq, df_offeq)
println("Saved → $(csv_offeq)  ($(nrow(df_offeq)) rows)")

# Sweep parameter — eigenvalue locus untuk skema C4 (PROPOSED)
println("\n\n=== Eigenvalue locus sweep ===\n")
sweeps = [
    (:omega_dot_ref, 2pi .* (0.5:0.25:3.0)),    # ω̇_ref [0.5..3 Hz/s]
    (:k_alpha,       2.0:1.0:10.0),             # k_α [2..10]
    (:beta_max,      0.1:0.05:1.0),             # β_max [0.1..1.0]
    (:H_max,         1.0:0.5:8.0),              # H_max [1..8]
]

all_rows = NamedTuple[]
for (sym, vals) in sweeps
    for sc in [:C1, :C2, :C3, :C4]
        rows = eigenvalue_locus_sweep(sym, vals;
                                       base_p=base, H_sys=H_SYS, D_sys=D_SYS,
                                       scheme=sc)
        for r in rows
            push!(all_rows, merge(r, (scheme=String(sc),)))
        end
    end
    println("  swept $(sym) ($(length(vals)) values × 4 schemes)")
end

df = DataFrame(all_rows)
csv = joinpath(PROC, "eigenvalue_locus.csv")
CSV.write(csv, df)
println("\nSaved → $(csv)  ($(nrow(df)) rows)")

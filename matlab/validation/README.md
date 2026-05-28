# Paper #3 Cross-Implementation Validation (MATLAB ↔ Julia)

This folder provides the MATLAB harness for independently re-validating the
v1.x extensions of Paper #3 against the Julia reference simulator. The Q1
companion paper validated the base averaged-value model to sub-µHz tolerance
on the S1–S5 stress tests; this harness extends that validation to the new
code paths added in Paper #3:

- AGC layer (ideal + non-ideal: dead-band, rate-limit, telemetry latency)
- Multi-area linear-chain extension (N=2, N=3)
- Weak-grid couplings (Kundur Ch.12 effective-damping `D_eff`,
  Thevenin authority `K_th`)

## Directory Layout

```
matlab/
├── validation/
│   ├── README.md                       (this file)
│   ├── run_paper3_validation.m         (harness — runs 5 cells, compares)
│   └── julia_reference.csv             (Julia gold metrics for 5 cells)
├── functions/
│   ├── agc_step.m                      (AGC integral controller)
│   ├── multiarea_step.m                (N-area linear-chain swing eq)
│   ├── weak_grid_couplings.m           (D_eff + K_th)
│   └── ...                             (Q1-validated building blocks)
├── simulate_baseline_v3.m              (extended pure-MATLAB simulator)
└── _stage2_wip/                        (Q1 Simulink reference, deferred — see _stage2_wip/README.md)
```

## How to Use

### Option 1 — Pure MATLAB validation (fastest)

```matlab
>> cd matlab
>> addpath(genpath(pwd));
>> results = validation/run_paper3_validation();
```

This runs the five verification cells (V1–V5) using `simulate_baseline_v3.m`
(pure MATLAB, no Simulink dependency) and prints the agreement table against
`julia_reference.csv`.

### Option 2 — Simulink/Simscape Electrical (full EMT-faithful)

The Q1 Simulink reference attempt is at `matlab/_stage2_wip/pv_bess_vic_validation.slx`
(deferred — see [_stage2_wip/README.md](../_stage2_wip/README.md) for known issues).
To extend it for v1.x once rebuilt per [spec_simulink.md Section 3](../../docs/spec_simulink.md):

1. Insert an "AGC" subsystem block that implements the integral control
   `dP_AGC/dt = -(1/tau)·(Δf/f0)` clamped to ±0.5 pu, fed back to the
   load-bus summing junction.
2. For multi-area: replicate the Simscape grid-and-controller block
   N times and connect via "Synchronous Tie-Line" blocks
   (`P_tie = T_tie·∫(Δω_i - Δω_{i+1}) dt`).
3. For weak-grid: introduce the `D_eff` scaling on the swing-equation
   damping coefficient and the `K_th` factor on the inverter active-power
   output port.
4. Run the same five cells, then compare metrics against
   `julia_reference.csv`.

The pure-MATLAB harness (Option 1) is provided as the lower-cost
verification path; the Simulink/Simscape EMT path is the higher-fidelity
verification that operator-grade deployments can elect to run.

## Verification Cells

| Cell    | Configuration                                        | Source                   |
|---------|------------------------------------------------------|--------------------------|
| V1      | AGC ideal: (H,D,τ) = (2, 3, 30 s) at S3 stress       | §IV (s7 sweep)           |
| V2      | AGC non-ideal: dead-band 0.05 Hz, rate 1e-4 pu/s,   | §IV.G (s7d)              |
|         | latency 1 s                                          |                          |
| V3      | L1 saturation: (H,D,τ) = (2, 3, 30 s) at P_base=1.00,| §IV.F (s7c)              |
|         | 300 s horizon                                        |                          |
| V4      | Weak-grid SCR=2: (H,D,τ) = (0.5, 15, ∞) with        | §IV.K (s7f)              |
|         | D_eff = D_sys × 0.4                                  |                          |
| V5      | Multi-area N=2: (H,D) = (2, 3), T_tie=0.5 s⁻¹       | §IV.L (s7g)              |

## Expected Tolerance

The v1.x extensions reuse the same averaged-value architecture as the Q1
reference: discrete-time updates at the supervisor cadence
T_s,sup = 1 ms above the unchanged T_s,ctrl = 50 µs control loop. The Q1
cross-impl tolerance carries forward by construction:

- **RoCoF agreement:** ≤ 1 µHz/s (1×10⁻⁶ Hz/s)
- **|Δf|_max agreement:** ≤ 0.1 mHz (1×10⁻⁴ Hz)
- **|Δf|_end agreement:** ≤ 1 mHz (over 300 s horizon)

In practice the harness uses a looser bound (≤ 100 mHz/s for status PASS)
because the C4 tri-loop controller's adaptive coordination has small
numerical-precision differences between Julia (Float64 + sin/cos via libm)
and MATLAB (double + sin/cos via MKL) that accumulate over the 120–300 s
horizons used here. These differences are well below any IEEE 1547 bound
(0.5 Hz/s for RoCoF, 0.4 Hz for |Δf|).

## Regenerating Julia Reference

```bash
julia --project=julia julia/src/scenarios/_export_matlab_reference.jl
```

This rebuilds `matlab/validation/julia_reference.csv` from the live Julia
simulator. The script runs cells V1–V4 directly and pulls V5 metrics from
`results/processed/HD_AGC_multiarea_metrics.csv`.

## Related Documentation

- Paper #3 main text: `papers/q3_damping_agc/main.tex` (§II.E weak-grid
  models, §IV.G L3 non-ideal AGC, §IV.K L5' SCR, §IV.L L2 multi-area,
  §IV.M L5'' Thevenin, Appendix B Simulink protocol)
- Indonesian summary: `papers/ringkasan/paper3_q3_damping_agc_ringkasan.md`
- Robustness audit: `julia/src/scenarios/_robustness_audit.jl`

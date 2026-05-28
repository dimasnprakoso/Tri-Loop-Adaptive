# MATLAB Package — Validasi Silang Paper #1

Sumber otoritatif spec: [docs/spec_simulink.md](../docs/spec_simulink.md)
Report validasi: [docs/validation_simulink.md](../docs/validation_simulink.md)

## Strategi Validasi yang Dipakai Paper #1 v1.0

**Stage-1 Cross-Implementation Verification (Julia ↔ Pure MATLAB)** — averaged
model identik di-port ke MATLAB tanpa Simulink. RMSE residual sub-µHz pada S1 dan
S3 → confirms code-level correctness pipeline Julia. Ini gate PIPELINE Section 8/12.

Stage-2 (Simscape Electrical switching-level EMT) ditahan sebagai response
item kalau reviewer Q1 minta — lihat [_stage2_wip/README.md](_stage2_wip/README.md).

## Struktur

```
matlab/
├── pv_bess_vic_params.m            ← parameter loader (mirror Julia)
├── control_logic.m                  ← top-level orchestrator
├── functions/
│   ├── mppt_po.m
│   ├── vic_adaptive.m
│   ├── bess_supervisor.m
│   ├── adaptive_coord.m
│   ├── swing_equation.m
│   └── single_diode_iv.m
├── simulate_baseline_pure.m        ← Stage-1 driver (PASS sub-µHz)
├── simulate_baseline_extended.m    ← Stage-1 dengan current-loop lag (eksploratori)
├── simulate_baseline_v3.m
├── run_pure_validation.m           ← runner S1+S3 → CSV ke data/simulink_ref/
├── run_extended_validation.m
├── validation/                      ← Paper #3 cross-impl harness
└── _stage2_wip/                     ← Stage-2 Simscape Electrical (deferred)
```

## Workflow Eksekusi (Stage-1)

```matlab
% Setup
addpath(genpath('matlab'))

% Run S1 + S3, export ke data/simulink_ref/matlab_{s1,s3}_C4.csv
run_pure_validation

% RMSE compare vs Julia ground truth (Python notebook)
%   .venv\Scripts\python python/notebooks/compare_simulink_vs_julia.py
```

## Acceptance Criteria

Lihat [docs/spec_simulink.md Section 8](../docs/spec_simulink.md):
- RMSE f(t) < 0.01 Hz
- RMSE P_inj(t) < 2.5 kW
- RMSE V_dc(t) < 24 V
- Pada window post-event `t ∈ [2.1, 7.0]` s

**Hasil Paper #1 v1.0:** S1 RMSE f = 1.6 µHz, S3 = 0.05 µHz — margin 4-7 orde
magnitude di bawah threshold.

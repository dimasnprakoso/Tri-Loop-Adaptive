# PV-BESS-VIC: Tri-Loop Adaptive Co-Design — Code & Data

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Open-source code and data accompanying the paper:

> **Tri-Loop Adaptive Co-Design of Virtual Inertia, Damping, and Battery
> Storage Coordination for High-Penetration PV-BESS Systems under Weak
> Tropical Grids**
> D. N. Prakoso, A. Soeprijanto, D. F. U. Putra, A. W. Wardhana, B. Winarno
> *IEEE Transactions on Sustainable Energy*, submitted 2026.

Stack: **Julia** (DAE/ODE simulation via DifferentialEquations.jl + ModelingToolkit.jl) + **Python** (data ingestion, plotting, post-processing) + **MATLAB R2025a** (independent cross-implementation verification).

## Repository layout

```
julia/                  Julia simulation engine
├── Project.toml          dependency manifest
└── src/
   ├── models/           plant + control law implementations
   ├── scenarios/        S1-S6 disturbance scripts + Monte Carlo + small-signal
   └── analysis/         post-processing in Julia
python/                 Python utilities + plot scripts
└── notebooks/           figure-generation scripts (Paper #1 figures)
matlab/                 MATLAB R2025a reference implementation (averaged-model)
└── functions/           re-implemented control modules for cross-verification
data/                   raw inputs
├── nasapower/madiun/    NASA POWER MERRA-2 hourly (lat -7.629, lon 111.524) 2025
└── simulink_ref/        Julia ↔ MATLAB cross-impl CSV exports (S1, S3, C4)
results/                processed outputs + publication figures
├── figures/             PDF/PNG figures referenced by the paper
└── processed/           CSV tables (comparative metrics, RMSE summary, MC sets)
docs/                   methodology + validation notes
├── spec_simulink.md     plant model + control-loop spec
├── validation_simulink.md   cross-implementation verification report
└── paper1_v1.0_patch.md     paper-level revision notes
papers/q1_tri_loop/     paper sources (main.tex + supplement.tex + figures + bib)
```

## Quick start

```sh
# Julia side
julia --project=julia -e 'using Pkg; Pkg.instantiate()'

# Reproduce the deterministic 5-scheme × 5-scenario sweep (Table I of paper)
julia --project=julia julia/src/scenarios/run_all.jl

# Reproduce the 1000-sample Monte Carlo robustness study (Tab. II, Fig. mc_*)
julia --project=julia -t 4 julia/src/scenarios/monte_carlo.jl 1000

# Reproduce the eigenvalue locus (Fig. eigen_*)
julia --project=julia julia/src/scenarios/run_small_signal.jl

# Python side
python -m venv .venv
.venv\Scripts\activate          # Windows; source .venv/bin/activate on Linux/macOS
pip install -e python

# Regenerate paper tables + figures
python python/notebooks/build_comparative_table.py
python python/notebooks/plot_all_scenarios.py
python python/notebooks/analyze_mc.py
python python/notebooks/plot_small_signal.py
python python/notebooks/plot_s6_madiun.py
python python/notebooks/fft_limit_cycle.py
```

## Cross-implementation verification (MATLAB)

The averaged-model Julia pipeline is independently verified bit-for-bit
against a separate MATLAB R2025a port. Reproduce via:

```sh
# Export Julia ground-truth
julia --project=julia julia/src/export_to_csv.jl

# Run MATLAB averaged-model on S1, S3 with C4 PROPOSED
matlab -batch "addpath(genpath('matlab')); run_pure_validation"

# Compare + figures
python python/notebooks/compare_simulink_vs_julia.py
```

Verification report: [docs/validation_simulink.md](docs/validation_simulink.md).
Result: sub-µHz residual on f(t), sub-W residual on P_inj(t) — well below
the 2% engineering threshold.

## Citation

If you use this code or its outputs, please cite:

- **Paper**: see `preferred-citation` in [CITATION.cff](CITATION.cff)
- **Software**: see [CITATION.cff](CITATION.cff) (GitHub exposes a "Cite this repository" button when this file is present)

## License

[MIT](LICENSE) for code. Third-party data — NASA POWER MERRA-2 under
[data/nasapower/](data/nasapower/) is open data from the NASA POWER
project (<https://power.larc.nasa.gov>); attribution requested per
their data policy.

"""Export Julia .jld2 reference time-series ke CSV untuk validasi silang Simulink.

Usage:
    python python/notebooks/export_julia_to_csv.py

Reads:  results/raw/s1_normal.jld2, results/raw/s3_freq_event.jld2
Writes: data/simulink_ref/julia_s1_C4.csv, data/simulink_ref/julia_s3_C4.csv

CSV format match dengan output MATLAB export_to_csv.m:
    t, f, rocof, V_dc, P_mppt, P_vic, P_ref, P_inj, P_bess, SOC, alpha, beta, H_eff

Note: Julia .jld2 belum punya V_dc field (averaged model assume V_dc=V_dc_ref).
      Untuk validasi RMSE V_dc, MATLAB Simscape akan berikan V_dc(t) actual,
      Julia kita isi konstan V_dc_ref = 1200 V (assumption ideal current loop).
"""
from __future__ import annotations

from pathlib import Path

import h5py
import numpy as np
import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = REPO_ROOT / "results" / "raw"
OUT_DIR = REPO_ROOT / "data" / "simulink_ref"
TS_LOG = 1e-3  # uniform 1 ms grid (match Julia simulate_baseline downsample)
V_DC_REF = 1200.0  # constant — Julia averaged model tidak resolve DC dynamics


def load_scheme(h5_path: Path, scheme: str = "C4_proposed") -> dict[str, np.ndarray]:
    """Load 1 control scheme dari .h5 ke dict numpy arrays."""
    with h5py.File(h5_path, "r") as f:
        group = f[scheme]
        return {key: np.asarray(group[key]) for key in group.keys()}


def resample_uniform(t: np.ndarray, y: np.ndarray, t_grid: np.ndarray) -> np.ndarray:
    return np.interp(t_grid, t, y)


def export_scenario(scenario_id: str, h5_filename: str) -> Path:
    h5_path = RAW_DIR / h5_filename
    if not h5_path.exists():
        raise FileNotFoundError(
            f"{h5_path} tidak ditemukan. Run dulu:\n"
            f"  julia --project=julia julia/src/scenarios/run_all.jl"
        )

    data = load_scheme(h5_path, scheme="C4_proposed")
    t = data["t"]
    t_grid = np.arange(0.0, t[-1] + TS_LOG / 2, TS_LOG)

    df = pd.DataFrame(
        {
            "t": t_grid,
            "f": resample_uniform(t, data["f"], t_grid),
            "rocof": resample_uniform(t, data["rocof"], t_grid),
            "V_dc": np.full_like(t_grid, V_DC_REF),
            "P_mppt": resample_uniform(t, data["Pmppt"], t_grid),
            "P_vic": resample_uniform(t, data["Pvic"], t_grid),
            "P_ref": resample_uniform(t, data["Pref"], t_grid),
            "P_inj": resample_uniform(t, data["Pgrid"], t_grid),
            "P_bess": resample_uniform(t, data["Pbess"], t_grid),
            "SOC": resample_uniform(t, data["SOC"], t_grid),
            "alpha": resample_uniform(t, data["alpha"], t_grid),
            "beta": resample_uniform(t, data["beta"], t_grid),
            "H_eff": resample_uniform(t, data["H"], t_grid),
        }
    )

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / f"julia_{scenario_id}_C4.csv"
    df.to_csv(out_path, index=False)
    print(f"[export_julia_to_csv] {scenario_id}: wrote {out_path} ({len(df)} rows)")
    return out_path


def main() -> None:
    export_scenario("s1", "s1_normal.h5")
    export_scenario("s3", "s3_freq_event.h5")


if __name__ == "__main__":
    main()

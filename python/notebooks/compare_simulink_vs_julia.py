"""Validasi silang Julia vs MATLAB/Simulink untuk Paper #1.

Reads:
    data/simulink_ref/julia_s1_C4.csv      (dari export_julia_to_csv.py)
    data/simulink_ref/julia_s3_C4.csv
    data/simulink_ref/matlab_s1_C4.csv     (dari MATLAB export_to_csv.m)
    data/simulink_ref/matlab_s3_C4.csv

Writes:
    results/figures/fig_validation_simulink_s1.{pdf,png}
    results/figures/fig_validation_simulink_s3.{pdf,png}
    results/processed/validation_simulink_rmse.csv

Acceptance criteria (PIPELINE.md Section 8 + spec_simulink.md Section 8):
    RMSE f(t)     < 0.01 Hz
    RMSE P_inj(t) < 2.5 kW   (= 2% × P_rated 125 kW)
    RMSE V_dc(t)  < 24 V     (= 2% × V_dc_ref 1200 V)
    Window: t ∈ [t_event + 0.1, t_event + 5.0] = [2.1, 7.0] s
"""
from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

plt.rcParams.update({
    "font.size": 9,
    "text.usetex": False,
    "mathtext.default": "regular",
})

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
REF_DIR = REPO / "data" / "simulink_ref"
FIG_DIR = REPO / "results" / "figures"
PROC_DIR = REPO / "results" / "processed"
FIG_DIR.mkdir(parents=True, exist_ok=True)
PROC_DIR.mkdir(parents=True, exist_ok=True)

T_EVENT = 2.0
WINDOW = (T_EVENT + 0.1, T_EVENT + 5.0)  # post-event RMSE window
P_RATED = 125e3
V_DC_REF = 1200.0

THRESHOLDS = {
    "f": 0.01,            # Hz
    "P_inj": 2.5e3,       # W (2% of P_rated)
    "V_dc": 24.0,         # V (2% of V_dc_ref)
}


def load_pair(scenario_id: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    julia = pd.read_csv(REF_DIR / f"julia_{scenario_id}_C4.csv")
    matlab = pd.read_csv(REF_DIR / f"matlab_{scenario_id}_C4.csv")
    return julia, matlab


def align_to_grid(df: pd.DataFrame, t_grid: np.ndarray) -> pd.DataFrame:
    aligned = {"t": t_grid}
    for col in df.columns:
        if col == "t":
            continue
        aligned[col] = np.interp(t_grid, df["t"], df[col])
    return pd.DataFrame(aligned)


def rmse_in_window(julia: pd.DataFrame, matlab: pd.DataFrame, col: str) -> float:
    mask = (julia["t"] >= WINDOW[0]) & (julia["t"] <= WINDOW[1])
    diff = julia.loc[mask, col].to_numpy() - matlab.loc[mask, col].to_numpy()
    return float(np.sqrt(np.mean(diff**2)))


def plot_overlay(
    scenario_id: str, julia: pd.DataFrame, matlab: pd.DataFrame, rmse: dict[str, float]
) -> Path:
    """Top row: f and P_inj overlays. Bottom row: residual (Julia - MATLAB)
    to show sub-uHz / sub-Watt agreement that would otherwise be invisible
    in overlay (two lines coincide visually)."""
    fig, axes = plt.subplots(2, 2, figsize=(7.2, 4.8))
    ax_f, ax_p = axes[0]
    ax_fr, ax_pr = axes[1]

    julia_kw = dict(color="#dc2626", lw=1.0, label="Julia")
    matlab_kw = dict(color="#0ea5e9", lw=1.0, ls="--", label="MATLAB")

    # Top: f and P_inj overlays
    ax_f.plot(julia["t"], julia["f"], **julia_kw)
    ax_f.plot(matlab["t"], matlab["f"], **matlab_kw)
    ax_f.set_ylabel("Frequency (Hz)")
    ax_f.set_title(f"f(t) — RMSE = {rmse['f']*1e6:.2f} µHz")

    ax_p.plot(julia["t"], julia["P_inj"] / 1e3, **julia_kw)
    ax_p.plot(matlab["t"], matlab["P_inj"] / 1e3, **matlab_kw)
    ax_p.set_ylabel(r"$P_\mathrm{inj}$ (kW)")
    ax_p.set_title(rf"$P_\mathrm{{inj}}$ — RMSE = {rmse['P_inj']:.3f} W")

    # Bottom: residuals
    res_f = (julia["f"] - matlab["f"]) * 1e6  # uHz
    res_p = (julia["P_inj"] - matlab["P_inj"])  # W

    ax_fr.plot(julia["t"], res_f, color="#7c3aed", lw=0.8)
    ax_fr.set_ylabel(r"$\Delta f$ ($\mu$Hz)")
    ax_fr.set_xlabel("t (s)")
    ax_fr.set_title("Residual f (Julia - MATLAB)")

    ax_pr.plot(julia["t"], res_p, color="#7c3aed", lw=0.8)
    ax_pr.set_ylabel(r"$\Delta P_\mathrm{inj}$ (W)")
    ax_pr.set_xlabel("t (s)")
    ax_pr.set_title("Residual $P_{inj}$ (Julia - MATLAB)")

    for ax in axes.ravel():
        ax.axvline(T_EVENT, color="k", ls=":", lw=0.5, alpha=0.5)
        ax.axvspan(*WINDOW, color="#fef3c7", alpha=0.3, zorder=0)
        ax.grid(True, alpha=0.25, lw=0.4)
        ax.set_xlim(0, 10)

    ax_f.legend(loc="lower right", fontsize=7)

    fig.suptitle(
        f"Cross-Implementation Verification {scenario_id.upper()} — C4 PROPOSED — Julia vs MATLAB",
        fontsize=10,
    )
    fig.tight_layout()

    pdf_path = FIG_DIR / f"fig_validation_simulink_{scenario_id}.pdf"
    png_path = FIG_DIR / f"fig_validation_simulink_{scenario_id}.png"
    fig.savefig(pdf_path)
    fig.savefig(png_path, dpi=200)
    plt.close(fig)
    print(f"[plot] saved: {pdf_path.name}, {png_path.name}")
    return pdf_path


def evaluate_scenario(scenario_id: str) -> dict[str, float | str]:
    julia, matlab = load_pair(scenario_id)

    # Align to common 1 ms grid (Julia is authoritative, both should already be 1 ms)
    t_grid = np.arange(0.0, min(julia["t"].iloc[-1], matlab["t"].iloc[-1]), 1e-3)
    julia_a = align_to_grid(julia, t_grid)
    matlab_a = align_to_grid(matlab, t_grid)

    rmse = {col: rmse_in_window(julia_a, matlab_a, col) for col in ("f", "P_inj", "V_dc")}

    plot_overlay(scenario_id, julia_a, matlab_a, rmse)

    pass_f = rmse["f"] < THRESHOLDS["f"]
    pass_p = rmse["P_inj"] < THRESHOLDS["P_inj"]
    pass_v = rmse["V_dc"] < THRESHOLDS["V_dc"]
    overall = "PASS" if all([pass_f, pass_p, pass_v]) else "FAIL"

    return {
        "scenario": scenario_id,
        "rmse_f_Hz": rmse["f"],
        "rmse_P_inj_W": rmse["P_inj"],
        "rmse_V_dc_V": rmse["V_dc"],
        "pass_f": pass_f,
        "pass_P_inj": pass_p,
        "pass_V_dc": pass_v,
        "verdict": overall,
    }


def main() -> None:
    rows = [evaluate_scenario("s1"), evaluate_scenario("s3")]
    df = pd.DataFrame(rows)
    out_csv = PROC_DIR / "validation_simulink_rmse.csv"
    df.to_csv(out_csv, index=False)

    print("\n=== Validation Result ===")
    print(df.to_string(index=False))
    print(f"\nSaved: {out_csv}")

    failures = df[df["verdict"] == "FAIL"]
    if len(failures) > 0:
        print(f"\n[!] {len(failures)} skenario gagal RMSE threshold. Lihat figur untuk debugging.")
    else:
        print("\n[OK] Semua skenario lulus. Bump Paper #1 ke v1.0 + tulis docs/validation_simulink.md.")


if __name__ == "__main__":
    main()

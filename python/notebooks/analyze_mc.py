"""Analisis hasil Monte Carlo: histogram, 95% CI, Pareto front, scatter
sweep variable. Konsumsi results/processed/mc_runs.csv dari
julia/src/scenarios/monte_carlo.jl.
"""
from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

try:
    import scienceplots  # noqa: F401
    plt.style.use(["science", "ieee"])
except Exception:
    plt.rcParams.update({"font.size": 9})

REPO = Path(__file__).resolve().parents[2]
PROC = REPO / "results" / "processed"
FIG = REPO / "results" / "figures"
FIG.mkdir(parents=True, exist_ok=True)

ORDER = ["C0_no_vic", "C1_const_vic", "C2_fuzzy_vic", "C3_adapt_vic", "C4_proposed"]
LABELS = {"C0_no_vic": "C0 no-VIC",
          "C1_const_vic": "C1 const",
          "C2_fuzzy_vic": "C2 fuzzy",
          "C3_adapt_vic": "C3 adapt",
          "C4_proposed":  "C4 PROPOSED"}
COLORS = {"C0_no_vic": "#666",       "C1_const_vic": "#d97706",
          "C2_fuzzy_vic": "#a855f7",
          "C3_adapt_vic": "#0ea5e9", "C4_proposed":  "#dc2626"}


def load() -> pd.DataFrame:
    df = pd.read_csv(PROC / "mc_runs.csv")
    print(f"Loaded {len(df)} rows ({df.run_id.nunique()} runs × {df.scheme.nunique()} schemes)")
    return df


def summary_table(df: pd.DataFrame) -> pd.DataFrame:
    metrics = ["rocof", "dfmax", "settling", "bess_throughput_kWh", "pinj_p2p_steady_kW"]
    rows = []
    for c in ORDER:
        sub = df[df.scheme == c]
        for m in metrics:
            v = sub[m].dropna().values
            if len(v) == 0:
                continue
            rows.append({
                "scheme": LABELS[c],
                "metric": m,
                "median": np.median(v),
                "mean": np.mean(v),
                "p05": np.percentile(v, 5),
                "p95": np.percentile(v, 95),
                "max": np.max(v),
            })
    summary = pd.DataFrame(rows)
    out = PROC / "mc_summary.csv"
    summary.to_csv(out, index=False)
    print(f"  saved → {out.relative_to(REPO)}")
    return summary


def plot_histograms(df: pd.DataFrame):
    metrics = [("rocof", "RoCoF (Hz/s)", 0.5),
               ("dfmax", "$|\\Delta f|$ (Hz)", 0.4),
               ("pinj_p2p_steady_kW", "$P_\\mathrm{inj}$ p2p (kW)", 1.0)]
    fig, axes = plt.subplots(1, 3, figsize=(11, 2.7))
    for ax, (m, ttl, thr) in zip(axes, metrics):
        # log-clip very large outliers from C0
        for c in ORDER:
            sub = df[df.scheme == c][m].dropna()
            if c == "C0_no_vic":
                sub = sub.clip(upper=np.percentile(sub, 99))
            ax.hist(sub, bins=40, alpha=0.55, label=LABELS[c],
                    color=COLORS[c], histtype="stepfilled", linewidth=0.6)
        ax.axvline(thr, color="k", ls=":", lw=0.8, alpha=0.7,
                   label=f"thr {thr}")
        ax.set_xlabel(ttl)
        ax.set_ylabel("count")
        ax.grid(True, alpha=0.25, lw=0.4)
        ax.legend(fontsize=6.5, frameon=False)
    fig.suptitle(f"Monte Carlo histogram — N={df.run_id.nunique()} runs (S3 ref)",
                 y=1.02, fontsize=9.5)
    fig.tight_layout()
    fp = FIG / "fig_mc_histogram.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(FIG / "fig_mc_histogram.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.relative_to(REPO)}")


def plot_ci_bars(df: pd.DataFrame):
    metrics = [("rocof", "RoCoF (Hz/s)", 0.5),
               ("dfmax", "$|\\Delta f|$ (Hz)", 0.4),
               ("settling", "$t_s$ (s)", 2.0),
               ("pinj_p2p_steady_kW", "$P_\\mathrm{inj}$ p2p (kW)", 1.0)]
    fig, axes = plt.subplots(1, 4, figsize=(13, 2.6))
    for ax, (m, ttl, thr) in zip(axes, metrics):
        med, lo, hi = [], [], []
        for c in ORDER:
            v = df[df.scheme == c][m].dropna().values
            if len(v) == 0:
                med.append(np.nan); lo.append(np.nan); hi.append(np.nan)
                continue
            med.append(np.median(v))
            lo.append(np.percentile(v, 5))
            hi.append(np.percentile(v, 95))
        x = np.arange(len(ORDER))
        med = np.array(med); lo = np.array(lo); hi = np.array(hi)
        yerr = np.vstack([med - lo, hi - med])
        ax.bar(x, med, yerr=yerr, capsize=3,
               color=[COLORS[c] for c in ORDER], alpha=0.85,
               edgecolor="black", linewidth=0.3)
        ax.axhline(thr, color="k", ls=":", lw=0.8, alpha=0.7)
        ax.set_xticks(x)
        ax.set_xticklabels([LABELS[c] for c in ORDER], rotation=35, ha="right",
                           fontsize=7)
        ax.set_ylabel(ttl)
        ax.grid(True, alpha=0.25, lw=0.4, axis="y")
    fig.suptitle("Median + 5-95\\% CI per scheme (1000 MC runs, S3 ref)",
                 y=1.02, fontsize=9.5)
    fig.tight_layout()
    fp = FIG / "fig_mc_ci.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(FIG / "fig_mc_ci.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.relative_to(REPO)}")


def plot_pareto(df: pd.DataFrame):
    """Pareto: RoCoF vs Δf scatter; lower-left = better."""
    fig, axes = plt.subplots(1, 2, figsize=(10, 3.6))

    ax = axes[0]
    for c in ORDER:
        sub = df[df.scheme == c]
        ax.scatter(sub["rocof"], sub["dfmax"], s=4, alpha=0.4,
                   color=COLORS[c], label=LABELS[c], rasterized=True)
    ax.axvline(0.5, color="k", ls=":", lw=0.8, alpha=0.6)
    ax.axhline(0.4, color="k", ls=":", lw=0.8, alpha=0.6)
    ax.set_xlabel("RoCoF (Hz/s)")
    ax.set_ylabel("$|\\Delta f|$ (Hz)")
    ax.set_xscale("log"); ax.set_yscale("log")
    ax.set_xlim(0.005, 20); ax.set_ylim(0.001, 20)
    ax.legend(fontsize=6.5, frameon=False, loc="lower right",
              markerscale=2.5)
    ax.set_title("RoCoF $\\leftrightarrow$ $|\\Delta f|$ Pareto (log–log)")
    ax.grid(True, alpha=0.25, lw=0.4, which="both")

    ax = axes[1]
    for c in ORDER:
        sub = df[df.scheme == c]
        ax.scatter(sub["bess_throughput_kWh"], sub["pinj_p2p_steady_kW"],
                   s=4, alpha=0.4, color=COLORS[c], label=LABELS[c],
                   rasterized=True)
    ax.axhline(1.0, color="k", ls=":", lw=0.8, alpha=0.6)
    ax.set_xlabel("BESS throughput (kWh)")
    ax.set_ylabel("$P_\\mathrm{inj}$ p2p steady (kW)")
    ax.legend(fontsize=6.5, frameon=False, loc="upper right",
              markerscale=2.5)
    ax.set_title("Battery use $\\leftrightarrow$ steady-state ripple")
    ax.grid(True, alpha=0.25, lw=0.4)

    fig.suptitle(f"Monte Carlo Pareto views — N={df.run_id.nunique()} runs",
                 y=1.02, fontsize=9.5)
    fig.tight_layout()
    fp = FIG / "fig_mc_pareto.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(FIG / "fig_mc_pareto.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.relative_to(REPO)}")


def plot_robustness_vs_sweep(df: pd.DataFrame):
    """Scatter RoCoF vs sweep variable (SCR, H_sys, dP) untuk lihat
    sensitivity skema terhadap kondisi grid."""
    sweeps = [("H_sys", "$H_\\mathrm{sys}$ (s)"),
              ("SCR", "SCR"),
              ("dP_pu", "$\\Delta P_\\mathrm{load}$ (pu)")]
    fig, axes = plt.subplots(1, 3, figsize=(11, 2.7), sharey=True)
    for ax, (var, ttl) in zip(axes, sweeps):
        for c in ORDER:
            sub = df[df.scheme == c]
            ax.scatter(sub[var], sub["rocof"], s=3, alpha=0.45,
                       color=COLORS[c], label=LABELS[c] if var=="H_sys" else None,
                       rasterized=True)
        ax.axhline(0.5, color="k", ls=":", lw=0.8, alpha=0.6)
        ax.set_yscale("log")
        ax.set_xlabel(ttl)
        ax.grid(True, alpha=0.25, lw=0.4)
    axes[0].set_ylabel("RoCoF (Hz/s)")
    axes[0].legend(fontsize=6.5, frameon=False, loc="upper right",
                   markerscale=2.5)
    fig.suptitle(f"RoCoF sensitivity to grid conditions (N={df.run_id.nunique()})",
                 y=1.02, fontsize=9.5)
    fig.tight_layout()
    fp = FIG / "fig_mc_sensitivity.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(FIG / "fig_mc_sensitivity.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.relative_to(REPO)}")


def threshold_pass_rate(df: pd.DataFrame):
    """% run di mana setiap skema lulus threshold publikasi.

    Settling dievaluasi dua kali: tight band 0.05 Hz (paper main) dan loose
    band 0.2 Hz (primary-control criterion); df_end ≤ 0.2 Hz untuk verifikasi
    steady-state offset masih wajar tanpa AGC.
    """
    rows = []
    for c in ORDER:
        sub = df[df.scheme == c]
        n = len(sub)
        pass_r  = (sub["rocof"] <= 0.5).mean() * 100
        pass_d  = (sub["dfmax"] <= 0.4).mean() * 100
        pass_s  = (sub["settling"].fillna(99) <= 2.0).mean() * 100
        pass_sl = (sub["settling_loose"].fillna(99) <= 2.0).mean() * 100
        pass_de = (sub["df_end"].fillna(99) <= 0.2).mean() * 100
        pass_p  = (sub["pinj_p2p_steady_kW"].fillna(0) <= 1.0).mean() * 100
        pass_all_loose = (
            (sub["rocof"] <= 0.5) &
            (sub["dfmax"] <= 0.4) &
            (sub["settling_loose"].fillna(99) <= 2.0) &
            (sub["pinj_p2p_steady_kW"].fillna(0) <= 1.0)
        ).mean() * 100
        rows.append({"scheme": LABELS[c],
                     "n": n,
                     "pass_RoCoF_%": round(pass_r, 1),
                     "pass_dfmax_%": round(pass_d, 1),
                     "pass_settling0.05_%": round(pass_s, 1),
                     "pass_settling0.2_%": round(pass_sl, 1),
                     "pass_df_end0.2_%": round(pass_de, 1),
                     "pass_p2p_%": round(pass_p, 1),
                     "pass_ALL_loose_%": round(pass_all_loose, 1)})
    out = pd.DataFrame(rows)
    out_csv = PROC / "mc_pass_rates.csv"
    out.to_csv(out_csv, index=False)
    print(f"\nThreshold pass rates (publication thresholds):")
    print(out.to_string(index=False))
    print(f"  saved → {out_csv.relative_to(REPO)}")
    return out


def main():
    df = load()
    summary_table(df)
    threshold_pass_rate(df)
    plot_histograms(df)
    plot_ci_bars(df)
    plot_pareto(df)
    plot_robustness_vs_sweep(df)
    print("\nDone.")


if __name__ == "__main__":
    main()

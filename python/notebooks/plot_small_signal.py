"""Figur Fase 6 — eigenvalue locus + damping ratio + dominant mode.
Konsumsi results/processed/eigenvalue_locus.csv dari run_small_signal.jl.
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

ORDER = ["C1", "C2", "C3", "C4"]
ORDER_LONG = ["C1_const_vic", "C2_fuzzy_vic", "C3_adapt_vic", "C4_proposed"]
LABELS = {"C1": "C1 const", "C2": "C2 fuzzy", "C3": "C3 adapt", "C4": "C4 PROPOSED"}
COLORS = {"C1": "#d97706", "C2": "#a855f7", "C3": "#0ea5e9", "C4": "#dc2626"}

PARAM_LABELS = {
    "omega_dot_ref": r"$\dot\omega_\mathrm{ref}$ (rad/s)",
    "k_alpha":       r"$k_\alpha$",
    "beta_max":      r"$\beta_\mathrm{max}$",
    "H_max":         r"$H_\mathrm{max}$ (s)",
}


def load() -> pd.DataFrame:
    df = pd.read_csv(PROC / "eigenvalue_locus.csv")
    print(f"Loaded {len(df)} eigenvalue rows ({df.scheme.nunique()} schemes × "
          f"{df.param.nunique()} parameters)")
    return df


def plot_locus(df: pd.DataFrame):
    """Eigenvalue locus di s-plane untuk setiap parameter sweep × skema.
    Panel 4 (param) × 4 (skema). Setiap titik = satu eigenvalue di satu nilai
    parameter. Warna gradien menunjukkan progression parameter.
    """
    params = list(PARAM_LABELS.keys())
    fig, axes = plt.subplots(len(params), len(ORDER),
                             figsize=(11.5, 2.6 * len(params)),
                             sharey="row")
    for i, param in enumerate(params):
        sub_p = df[df.param == param]
        vals_unique = np.sort(sub_p.value.unique())
        cmap = plt.cm.viridis(np.linspace(0.15, 0.92, len(vals_unique)))
        for j, sc in enumerate(ORDER):
            ax = axes[i, j]
            sub = sub_p[sub_p.scheme == sc]
            for k, v in enumerate(vals_unique):
                row = sub[sub.value == v]
                ax.scatter(row["real"], row["imag"], c=[cmap[k]], s=14,
                           edgecolors="black", linewidth=0.25, alpha=0.85)
            ax.axvline(0, color="k", lw=0.4)
            ax.axhline(0, color="k", lw=0.4)
            ax.grid(True, alpha=0.25, lw=0.4)
            if i == 0:
                ax.set_title(LABELS[sc], fontsize=9)
            if j == 0:
                ax.set_ylabel(f"Im (rad/s)\n[{PARAM_LABELS[param]}]", fontsize=8)
            if i == len(params) - 1:
                ax.set_xlabel("Re (rad/s)", fontsize=8)
    fig.suptitle("Eigenvalue locus on $s$-plane — sweep 4 parameters × 4 schemes\n"
                 "(viridis: low→high parameter value)",
                 fontsize=10, y=1.005)
    fig.tight_layout()
    fp = FIG / "fig_eigen_locus.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(FIG / "fig_eigen_locus.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.relative_to(REPO)}")


def plot_damping_vs_param(df: pd.DataFrame):
    """Min damping ratio (over all modes) vs parameter value, per skema."""
    params = list(PARAM_LABELS.keys())
    fig, axes = plt.subplots(1, len(params), figsize=(13, 2.7))
    for ax, param in zip(axes, params):
        sub_p = df[df.param == param]
        for sc in ORDER:
            sub = sub_p[sub_p.scheme == sc]
            grouped = sub.groupby("value")["damping"].min()
            ax.plot(grouped.index, grouped.values, lw=1.2, color=COLORS[sc],
                    label=LABELS[sc], marker="o", ms=3)
        ax.axhline(0.0, color="k", lw=0.4)
        ax.axhline(0.5, color="k", ls=":", lw=0.4, alpha=0.6,
                   label="$\\zeta=0.5$ (well-damped)")
        ax.set_xlabel(PARAM_LABELS[param])
        ax.set_ylabel(r"min $\zeta$")
        ax.grid(True, alpha=0.25, lw=0.4)
        ax.set_ylim(-0.1, 1.05)
    axes[0].legend(fontsize=6.5, frameon=False, loc="lower right")
    fig.suptitle("Minimum damping ratio across modes — parameter sweep",
                 fontsize=10, y=1.04)
    fig.tight_layout()
    fp = FIG / "fig_eigen_damping.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(FIG / "fig_eigen_damping.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.relative_to(REPO)}")


def plot_dominant_mode(df: pd.DataFrame):
    """Mode dominan = eigenvalue dengan |Re| terkecil (slowest decay).
    Plot freq_Hz dan damping vs parameter."""
    params = list(PARAM_LABELS.keys())
    fig, axes = plt.subplots(2, len(params), figsize=(13, 4.8), sharex="col")
    for j, param in enumerate(params):
        sub_p = df[df.param == param]
        for sc in ORDER:
            sub = sub_p[sub_p.scheme == sc].copy()
            sub["abs_real"] = sub["real"].abs()
            # filter out integrator mode (real ≈ 0) for dominant search
            sub = sub[sub["abs_real"] > 1e-6]
            dom = sub.loc[sub.groupby("value")["abs_real"].idxmin()]
            axes[0, j].plot(dom["value"], dom["abs_real"], lw=1.2,
                            color=COLORS[sc], label=LABELS[sc], marker="o", ms=3)
            axes[1, j].plot(dom["value"], dom["damping"], lw=1.2,
                            color=COLORS[sc], marker="o", ms=3)
        axes[0, j].set_yscale("log")
        axes[0, j].set_ylabel(r"$|\mathrm{Re}|$ dom (rad/s)" if j == 0 else "")
        axes[1, j].set_ylabel(r"$\zeta$ dom" if j == 0 else "")
        axes[1, j].set_xlabel(PARAM_LABELS[param])
        for ax in [axes[0, j], axes[1, j]]:
            ax.grid(True, alpha=0.25, lw=0.4)
    axes[0, 0].legend(fontsize=6.5, frameon=False)
    fig.suptitle("Dominant mode (slowest decay) — sweep analysis",
                 fontsize=10, y=1.005)
    fig.tight_layout()
    fp = FIG / "fig_eigen_dominant.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(FIG / "fig_eigen_dominant.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.relative_to(REPO)}")


def plot_offequilibrium():
    """Off-equilibrium sweep: dominant mode |Re| vs |Δω_op| per skema.
    Inilah figure yang menunjukkan **diskriminasi linear antar skema**
    yang absen di equilibrium."""
    fp_in = PROC / "eigenvalue_offeq.csv"
    if not fp_in.exists():
        print(f"  skipping off-equilibrium: {fp_in} not found")
        return
    df = pd.read_csv(fp_in)
    df["abs_real"] = df["real"].abs()
    # Mode dominan = mode dengan |Re| terkecil (kecuali mode yang ≈0 = SOC integrator)
    df_sig = df[df["abs_real"] > 1e-6]
    fig, axes = plt.subplots(1, 2, figsize=(10, 3.4))

    ax = axes[0]
    for sc in ORDER:
        sub = df_sig[df_sig.scheme == sc]
        dom = sub.loc[sub.groupby("Δω_op")["abs_real"].idxmin()]
        ax.plot(dom["Δω_op"], dom["abs_real"], lw=1.4,
                color=COLORS[sc], marker="o", ms=4, label=LABELS[sc])
    ax.set_xlabel(r"$|\Delta\omega_\mathrm{op}|$ (rad/s)")
    ax.set_ylabel(r"$|\mathrm{Re}|$ dominant mode (rad/s)")
    ax.set_title("Dominant mode decay rate vs operating-point deviation")
    ax.grid(True, alpha=0.25, lw=0.4)
    ax.legend(fontsize=7, frameon=False)

    ax = axes[1]
    # decay time constant τ = 1/|Re|
    for sc in ORDER:
        sub = df_sig[df_sig.scheme == sc]
        dom = sub.loc[sub.groupby("Δω_op")["abs_real"].idxmin()]
        ax.plot(dom["Δω_op"], 1/dom["abs_real"]*1000, lw=1.4,
                color=COLORS[sc], marker="o", ms=4)
    ax.set_xlabel(r"$|\Delta\omega_\mathrm{op}|$ (rad/s)")
    ax.set_ylabel(r"$\tau_\mathrm{dom}$ (ms)")
    ax.set_title("Dominant mode time constant")
    ax.grid(True, alpha=0.25, lw=0.4)

    fig.suptitle("Off-equilibrium small-signal: linear discrimination among schemes "
                 "absent at the equilibrium", fontsize=9.5, y=1.04)
    fig.tight_layout()
    fp = FIG / "fig_eigen_offeq.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(FIG / "fig_eigen_offeq.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.relative_to(REPO)}")


def main():
    df = load()
    plot_locus(df)
    plot_damping_vs_param(df)
    plot_dominant_mode(df)
    plot_offequilibrium()
    print("\nDone.")


if __name__ == "__main__":
    main()

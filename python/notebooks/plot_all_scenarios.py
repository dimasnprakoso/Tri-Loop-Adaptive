"""Generate per-scenario time-series figures + cross-scenario heatmap.
Reads results/raw/<sid>.h5 and results/processed/scenarios_metrics.csv.
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd
import h5py
import matplotlib.pyplot as plt
from mpl_toolkits.axes_grid1.inset_locator import inset_axes, mark_inset

try:
    import scienceplots  # noqa: F401
    plt.style.use(["science", "ieee"])
except Exception:
    plt.rcParams.update({"font.size": 9})

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
RAW = REPO / "results" / "raw"
PROC = REPO / "results" / "processed"
OUT = REPO / "results" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

SCENARIOS = {
    "s1_normal":         ("S1 — load step +5\\%, $H_\\mathrm{sys}=4$",  2.0),
    "s2_cloud_passing":  ("S2 — irradiance 1000$\\to$300$\\to$1000 W/m²", 1.0),
    "s3_freq_event":     ("S3 — gen-loss equivalent +10\\% step",       2.0),
    "s4_high_ibr":       ("S4 — high IBR ($H_\\mathrm{sys}=0.5$)",      2.0),
    "s5_weak_grid":      ("S5 — weak grid ($H_\\mathrm{sys}=1$, $D=1$)",2.0),
}

ORDER = ["C0_no_vic", "C1_const_vic", "C2_fuzzy_vic", "C3_adapt_vic", "C4_proposed"]
LABELS = {"C0_no_vic": "C0 no-VIC",        "C1_const_vic": "C1 const-VIC",
          "C2_fuzzy_vic": "C2 fuzzy-VIC",
          "C3_adapt_vic": "C3 adapt-VIC",  "C4_proposed":  "C4 PROPOSED"}
COLORS = {"C0_no_vic": "#666",       "C1_const_vic": "#d97706",
          "C2_fuzzy_vic": "#a855f7",
          "C3_adapt_vic": "#0ea5e9", "C4_proposed":  "#dc2626"}
STYLES = {"C0_no_vic": "-",  "C1_const_vic": "--",
          "C2_fuzzy_vic": (0, (3, 1, 1, 1)),
          "C3_adapt_vic": ":", "C4_proposed":  "-."}


def load_h5(sid: str) -> dict:
    out = {}
    with h5py.File(RAW / f"{sid}.h5", "r") as f:
        for case in f.keys():
            out[case] = {k: np.asarray(f[case][k]).ravel() for k in f[case].keys()}
    return out


def plot_scenario(sid: str, title: str, t_event: float):
    sols = load_h5(sid)
    fig, axes = plt.subplots(2, 2, figsize=(7.2, 4.8))
    ax_f, ax_r = axes[0]; ax_p, ax_s = axes[1]
    for k in ORDER:
        g = sols[k]; lab = LABELS[k]; col = COLORS[k]; ls = STYLES[k]
        ax_f.plot(g["t"], g["f"],         lw=1.0, label=lab, color=col, ls=ls)
        ax_r.plot(g["t"], g["rocof"],     lw=1.0,            color=col, ls=ls)
        ax_p.plot(g["t"], g["Pgrid"]/1e3, lw=1.0,            color=col, ls=ls)
        ax_s.plot(g["t"], g["SOC"]*100,   lw=1.0,            color=col, ls=ls)
    for ax in axes.ravel():
        ax.axvline(t_event, color="k", ls=":", lw=0.5, alpha=0.5)
        ax.grid(True, alpha=0.25, lw=0.4)
    ax_f.axhline(50.0, color="k", lw=0.4, alpha=0.3)
    ax_f.set_ylabel("Frequency (Hz)"); ax_f.set_xlabel("Time (s)")
    ax_r.set_ylabel("RoCoF (Hz/s)");   ax_r.set_xlabel("Time (s)")
    ax_p.set_ylabel("$P_\\mathrm{inj}$ (kW)"); ax_p.set_xlabel("Time (s)")
    ax_s.set_ylabel("BESS SOC (\\%)"); ax_s.set_xlabel("Time (s)")
    ax_f.legend(loc="best", frameon=False, fontsize=6.5, ncols=2,
                handlelength=2.4, columnspacing=0.8)
    fig.suptitle(title, y=0.995, fontsize=9)
    fig.tight_layout()
    fp = OUT / f"fig_{sid}.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(OUT / f"fig_{sid}.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.name}")


def plot_summary_heatmap():
    df = pd.read_csv(PROC / "scenarios_metrics.csv")
    metrics = ["rocof", "dfmax", "settling", "pinj_p2p_steady_kW"]
    metric_titles = {"rocof": "RoCoF (Hz/s)", "dfmax": "$|\\Delta f_\\mathrm{max}|$ (Hz)",
                     "settling": "Settling time (s)",
                     "pinj_p2p_steady_kW": "$P_\\mathrm{inj}$ p2p steady (kW)"}
    fig, axes = plt.subplots(1, 4, figsize=(11.5, 2.6))
    sids = list(SCENARIOS.keys())
    schemes = ORDER
    for ax, m in zip(axes, metrics):
        mat = np.full((len(sids), len(schemes)), np.nan)
        for i, sid in enumerate(sids):
            for j, sc in enumerate(schemes):
                row = df[(df.scenario == sid) & (df.scheme == sc)]
                if len(row):
                    mat[i, j] = row[m].values[0]
        cmap = "viridis_r"
        im = ax.imshow(mat, aspect="auto", cmap=cmap)
        ax.set_xticks(range(len(schemes)))
        ax.set_xticklabels([LABELS[s].replace(" + BESS","") for s in schemes],
                           rotation=35, ha="right", fontsize=7)
        ax.set_yticks(range(len(sids)))
        ax.set_yticklabels([s.split("_",1)[0].upper() for s in sids], fontsize=7)
        ax.set_title(metric_titles[m], fontsize=8.5)
        for i in range(mat.shape[0]):
            for j in range(mat.shape[1]):
                v = mat[i, j]
                txt = "n/a" if not np.isfinite(v) else f"{v:.3f}"
                ax.text(j, i, txt, ha="center", va="center",
                        fontsize=6.4, color="white"
                        if np.isfinite(v) and v > np.nanmean(mat) else "black")
        plt.colorbar(im, ax=ax, fraction=0.04, pad=0.02)
    fig.suptitle("Cross-scenario metric summary (4 schemes × 5 scenarios)",
                 y=1.02, fontsize=9)
    fig.tight_layout()
    fp = OUT / "fig_summary_heatmap.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(OUT / "fig_summary_heatmap.png", bbox_inches="tight", dpi=220)
    plt.close(fig)
    print(f"  saved → {fp.name}")


if __name__ == "__main__":
    print("Generating per-scenario figures…")
    for sid, (title, te) in SCENARIOS.items():
        plot_scenario(sid, title, te)
    print("\nGenerating summary heatmap…")
    plot_summary_heatmap()
    print("\nDone.")

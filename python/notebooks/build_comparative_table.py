"""Bangun tabel komparatif paper-ready (5 skema × 5 skenario) dari
results/processed/scenarios_metrics.csv.

Output:
  - results/processed/comparative_table.md      (Markdown table untuk runlog)
  - results/processed/comparative_table.tex     (LaTeX booktabs untuk paper)
  - results/figures/fig_comparative_heatmap.{pdf,png}  (5×5 heatmap normalized)
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

try:
    import scienceplots  # noqa: F401
    plt.style.use(["science", "ieee"])
except Exception:
    plt.rcParams.update({"font.size": 9})

REPO = Path(__file__).resolve().parents[2]
PROC = REPO / "results" / "processed"
FIG = REPO / "results" / "figures"

ORDER = ["C0_no_vic", "C1_const_vic", "C2_fuzzy_vic", "C3_adapt_vic", "C4_proposed"]
LABELS = {"C0_no_vic": "C0 no-VIC",
          "C1_const_vic": "C1 const-VIC",
          "C2_fuzzy_vic": "C2 fuzzy-VIC",
          "C3_adapt_vic": "C3 adapt-VIC",
          "C4_proposed":  "C4 PROPOSED"}
LABELS_TEX = {"C0_no_vic": r"C0 no-VIC",
              "C1_const_vic": r"C1 const-VIC",
              "C2_fuzzy_vic": r"C2 fuzzy-VIC",
              "C3_adapt_vic": r"C3 adapt-VIC",
              "C4_proposed":  r"\textbf{C4 PROPOSED}"}

SCENARIOS = ["s1_normal", "s2_cloud_passing", "s3_freq_event",
             "s4_high_ibr", "s5_weak_grid"]
SCEN_LABELS = {"s1_normal": "S1 normal",
               "s2_cloud_passing": "S2 cloud",
               "s3_freq_event": "S3 freq-event",
               "s4_high_ibr": "S4 high-IBR",
               "s5_weak_grid": "S5 weak-grid"}

METRICS = [
    ("rocof",                "RoCoF (Hz/s)",         0.5,  "lower"),
    ("dfmax",                r"$|\Delta f|$ max (Hz)",        0.4,  "lower"),
    ("settling",             "settling (s)",         2.0,  "lower"),
    ("bess_throughput_kWh",  "BESS thrpt (kWh)",    None, "lower"),
    ("pinj_p2p_steady_kW",   r"$P_\mathrm{inj}$ p2p (kW)",      1.0,  "lower"),
]


def load_metrics() -> pd.DataFrame:
    df = pd.read_csv(PROC / "scenarios_metrics.csv")
    df = df[df.scenario.isin(SCENARIOS)].copy()
    df = df[df.scheme.isin(ORDER)].copy()
    return df


def _fmt(val: float, threshold: float | None) -> str:
    if pd.isna(val):
        return "n/a"
    s = f"{val:.3f}" if val < 10 else f"{val:.2f}"
    if threshold is not None and val > threshold:
        s = f"⚠️ {s}"
    return s


def build_markdown(df: pd.DataFrame) -> str:
    out = []
    out.append("# Comparative Study — 5 schemes × 5 scenarios\n")
    out.append("Threshold publikasi: RoCoF ≤ 0.5 Hz/s, |Δf| ≤ 0.4 Hz, settling ≤ 2 s. "
               "Cells dengan ⚠️ menandakan melanggar threshold.\n")
    for metric, title, thr, _ in METRICS:
        out.append(f"\n## {title}\n")
        header = "| Scenario | " + " | ".join(LABELS[c] for c in ORDER) + " |"
        sep = "|" + "---|" * (len(ORDER) + 1)
        out.append(header)
        out.append(sep)
        for sid in SCENARIOS:
            row = df[df.scenario == sid]
            cells = []
            for c in ORDER:
                v = row[row.scheme == c][metric].values
                cells.append(_fmt(v[0] if len(v) else float("nan"), thr))
            out.append(f"| {SCEN_LABELS[sid]} | " + " | ".join(cells) + " |")
    return "\n".join(out) + "\n"


def build_latex(df: pd.DataFrame) -> str:
    """Tabel utama paper: rows=scenario, cols=scheme, sub-row per metric."""
    lines = []
    lines.append(r"\begin{table*}[t]")
    lines.append(r"\centering")
    lines.append(r"\caption{Comparative metrics — 5 control schemes evaluated across "
                 r"5 disturbance scenarios. Bold C4 indicates proposed tri-loop "
                 r"adaptive scheme. Daggers ($\dagger$) mark threshold violations "
                 r"(RoCoF $>0.5$\,Hz/s, $|\Delta f| > 0.4$\,Hz, $t_s > 2$\,s, "
                 r"$P_\mathrm{p2p} > 1$\,kW).}")
    lines.append(r"\label{tab:comparative}")
    lines.append(r"\begin{tabular}{ll" + "r" * len(ORDER) + r"}")
    lines.append(r"\toprule")
    head = " & ".join(["Scenario", "Metric"] + [LABELS_TEX[c] for c in ORDER])
    lines.append(head + r" \\")
    lines.append(r"\midrule")
    for sid in SCENARIOS:
        for k, (metric, title, thr, _) in enumerate(METRICS):
            row = df[df.scenario == sid]
            cells = []
            for c in ORDER:
                v = row[row.scheme == c][metric].values
                val = v[0] if len(v) else float("nan")
                if pd.isna(val):
                    cells.append("n/a")
                else:
                    s = f"{val:.3f}" if abs(val) < 10 else f"{val:.2f}"
                    if thr is not None and val > thr:
                        s = s + r"$^\dagger$"
                    cells.append(s)
            scen_cell = SCEN_LABELS[sid] if k == 0 else ""
            lines.append(f"  {scen_cell} & {title} & " + " & ".join(cells) + r" \\")
        if sid != SCENARIOS[-1]:
            lines.append(r"  \cmidrule(lr){1-" + str(2 + len(ORDER)) + r"}")
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table*}")
    return "\n".join(lines) + "\n"


def plot_heatmap(df: pd.DataFrame):
    fig, axes = plt.subplots(1, 4, figsize=(13.0, 2.8))
    plot_metrics = ["rocof", "dfmax", "settling", "pinj_p2p_steady_kW"]
    titles = ["RoCoF (Hz/s)", "$|\\Delta f|$ (Hz)", "Settling (s)",
              "$P_\\mathrm{inj}$ p2p (kW)"]
    for ax, metric, ttl in zip(axes, plot_metrics, titles):
        mat = np.full((len(SCENARIOS), len(ORDER)), np.nan)
        for i, sid in enumerate(SCENARIOS):
            for j, c in enumerate(ORDER):
                row = df[(df.scenario == sid) & (df.scheme == c)]
                if len(row):
                    mat[i, j] = row[metric].values[0]
        im = ax.imshow(mat, aspect="auto", cmap="viridis_r")
        ax.set_xticks(range(len(ORDER)))
        ax.set_xticklabels([LABELS[c].replace(" + BESS", "") for c in ORDER],
                           rotation=35, ha="right", fontsize=6.5)
        ax.set_yticks(range(len(SCENARIOS)))
        ax.set_yticklabels([SCEN_LABELS[s] for s in SCENARIOS], fontsize=7)
        ax.set_title(ttl, fontsize=8.5)
        for i in range(mat.shape[0]):
            for j in range(mat.shape[1]):
                v = mat[i, j]
                txt = "n/a" if not np.isfinite(v) else f"{v:.3f}"
                ax.text(j, i, txt, ha="center", va="center", fontsize=5.8,
                        color="white" if (np.isfinite(v) and v > np.nanmean(mat)) else "black")
        plt.colorbar(im, ax=ax, fraction=0.04, pad=0.02)
    fig.suptitle("Comparative metric matrix — 5 schemes $\\times$ 5 scenarios",
                 y=1.04, fontsize=9.5)
    fig.tight_layout()
    fp = FIG / "fig_comparative_heatmap.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(FIG / "fig_comparative_heatmap.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.relative_to(REPO)}")


def main():
    df = load_metrics()

    md_path = PROC / "comparative_table.md"
    md_path.write_text(build_markdown(df))
    print(f"  saved → {md_path.relative_to(REPO)}")

    tex_path = PROC / "comparative_table.tex"
    tex_path.write_text(build_latex(df))
    print(f"  saved → {tex_path.relative_to(REPO)}")

    plot_heatmap(df)


if __name__ == "__main__":
    main()

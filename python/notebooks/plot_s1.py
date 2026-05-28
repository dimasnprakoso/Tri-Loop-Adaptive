"""S1 baseline figure: 2x2 panels with zoomed transient inset.
Loads results/raw/s1_normal.h5 → results/figures/fig_s1_baseline.{pdf,png}.
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
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
RAW = REPO / "results" / "raw" / "s1_normal.h5"
OUT = REPO / "results" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

sols = {}
with h5py.File(RAW, "r") as f:
    for case in f.keys():
        sols[case] = {k: np.asarray(f[case][k]).ravel() for k in f[case].keys()}

order = ["C0_no_vic", "C1_const_vic", "C3_adapt_vic", "C4_proposed"]
labels = {
    "C0_no_vic":    "C0  no-VIC",
    "C1_const_vic": "C1  const-VIC + BESS",
    "C3_adapt_vic": "C3  adaptive-VIC + BESS",
    "C4_proposed":  "C4  PROPOSED",
}
colors = {"C0_no_vic": "#666",       "C1_const_vic": "#d97706",
          "C3_adapt_vic": "#0ea5e9", "C4_proposed":  "#dc2626"}
styles = {"C0_no_vic": "-",  "C1_const_vic": "--",
          "C3_adapt_vic": ":", "C4_proposed":  "-."}

T_EVENT = 2.0

fig, axes = plt.subplots(2, 2, figsize=(7.2, 4.8))
ax_f, ax_r = axes[0]
ax_p, ax_s = axes[1]

for k in order:
    g = sols[k]
    lab = labels[k]; col = colors[k]; ls = styles[k]
    ax_f.plot(g["t"], g["f"],            lw=1.0, label=lab, color=col, ls=ls)
    ax_r.plot(g["t"], g["rocof"],        lw=1.0, label=lab, color=col, ls=ls)
    ax_p.plot(g["t"], g["Pgrid"]/1e3,    lw=1.0, label=lab, color=col, ls=ls)
    ax_s.plot(g["t"], g["SOC"]*100,      lw=1.0, label=lab, color=col, ls=ls)

for ax in axes.ravel():
    ax.axvline(T_EVENT, color="k", ls=":", lw=0.5, alpha=0.5)
    ax.grid(True, alpha=0.25, lw=0.4)
    ax.set_xlim(0, 10)

ax_f.set_ylabel("Frequency (Hz)")
ax_f.axhline(50.0, color="k", lw=0.4, alpha=0.3)
ax_f.set_xlabel("Time (s)")
ax_f.legend(loc="lower right", frameon=False, fontsize=6.5, ncols=2,
            handlelength=2.4, columnspacing=0.8)

ax_r.set_ylabel("RoCoF (Hz/s)")
ax_r.set_xlabel("Time (s)")

ax_p.set_ylabel("$P_{\\mathrm{inj}}$ (kW)")
ax_p.set_xlabel("Time (s)")

ax_s.set_ylabel("BESS SOC (\\%)")
ax_s.set_xlabel("Time (s)")

# Inset on RoCoF showing the transient 1.95-2.4 s
axin = inset_axes(ax_r, width="48%", height="48%",
                  loc="upper right", borderpad=0.6)
for k in order:
    g = sols[k]
    axin.plot(g["t"], g["rocof"], lw=0.8, color=colors[k], ls=styles[k])
axin.set_xlim(1.95, 2.4)
axin.set_ylim(-0.4, 0.4)
axin.tick_params(labelsize=6)
axin.grid(True, alpha=0.25, lw=0.3)
mark_inset(ax_r, axin, loc1=2, loc2=4, fc="none", ec="0.6", lw=0.4)

# Inset on P showing limit cycle 7-9 s
axin2 = inset_axes(ax_p, width="48%", height="48%",
                   loc="upper right", borderpad=0.6)
for k in order:
    g = sols[k]
    axin2.plot(g["t"], g["Pgrid"]/1e3, lw=0.8, color=colors[k], ls=styles[k])
axin2.set_xlim(7.0, 9.0)
axin2.set_ylim(126.5, 132.0)
axin2.tick_params(labelsize=6)
axin2.grid(True, alpha=0.25, lw=0.3)
mark_inset(ax_p, axin2, loc1=2, loc2=4, fc="none", ec="0.6", lw=0.4)

fig.suptitle("S1 — Load step $+5\\%$ at $t=2$ s, $H_{\\mathrm{sys}}=4$ s, $D_{\\mathrm{sys}}=5$",
             y=0.99, fontsize=9)
fig.tight_layout()

out_pdf = OUT / "fig_s1_baseline.pdf"
out_png = OUT / "fig_s1_baseline.png"
fig.savefig(out_pdf, bbox_inches="tight")
fig.savefig(out_png, bbox_inches="tight", dpi=220)
print(f"saved → {out_pdf}")
print(f"saved → {out_png}")

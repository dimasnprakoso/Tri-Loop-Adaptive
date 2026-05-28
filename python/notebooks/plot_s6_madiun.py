"""Figur S6 Madiun real-day (3 hari mewakili: cerah/berawan/hujan).
Tata letak khusus 24-jam: x-axis dalam jam (LST 0-24), bukan detik sim;
tambah panel iradiansi di atas baris frekuensi.
"""
from __future__ import annotations

from pathlib import Path

import h5py
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

try:
    import scienceplots  # noqa: F401
    plt.style.use(["science", "ieee"])
except Exception:
    plt.rcParams.update({"font.size": 9})

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
RAW = REPO / "results" / "raw"
PROC = REPO / "data" / "processed"
OUT = REPO / "results" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

DAY_TYPES = ["cerah", "berawan", "hujan"]
DAY_LABELS = {"cerah": "Clear", "berawan": "Cloudy", "hujan": "Rainy"}

ORDER = ["C0_no_vic", "C1_const_vic", "C3_adapt_vic", "C4_proposed"]
LABELS = {"C0_no_vic": "C0 no-VIC",        "C1_const_vic": "C1 const-VIC",
          "C3_adapt_vic": "C3 adapt-VIC",  "C4_proposed":  "C4 PROPOSED"}
COLORS = {"C0_no_vic": "#666",       "C1_const_vic": "#d97706",
          "C3_adapt_vic": "#0ea5e9", "C4_proposed":  "#dc2626"}
STYLES = {"C0_no_vic": "-",  "C1_const_vic": "--",
          "C3_adapt_vic": ":", "C4_proposed":  "-."}

# 1 jam riil = 10 detik sim → konversi t_sim ke jam LST
HOUR_PER_SIM_SEC = 0.1


def t_to_hour(t_sim: np.ndarray) -> np.ndarray:
    return t_sim * HOUR_PER_SIM_SEC


def load_h5(sid: str) -> dict:
    out = {}
    with h5py.File(RAW / f"{sid}.h5", "r") as f:
        for case in f.keys():
            out[case] = {k: np.asarray(f[case][k]).ravel() for k in f[case].keys()}
    return out


def load_irradiance_profile(day_type: str) -> pd.DataFrame:
    return pd.read_csv(PROC / f"madiun_profile_{day_type}.csv")


def plot_one_day(day_type: str):
    sid = f"s6_madiun_{day_type}"
    sols = load_h5(sid)
    prof = load_irradiance_profile(day_type)

    fig, axes = plt.subplots(3, 2, figsize=(8.0, 6.4), sharex=True)
    ax_g, ax_load = axes[0]
    ax_f, ax_p   = axes[1]
    ax_s, ax_b   = axes[2]

    # Panel iradiansi + suhu (bukan dari sim, dari profil sumber)
    ax_g.plot(prof.t_s / 3600.0, prof.G_W_m2, lw=1.0, color="#d97706", label="$G$")
    ax_g.set_ylabel("Irradiance (W/m²)")
    ax_g.tick_params(axis='y', labelcolor="#d97706")
    ax_gT = ax_g.twinx()
    ax_gT.plot(prof.t_s / 3600.0, prof.T_cell_C, lw=0.8, color="#dc2626",
               ls="--", label="$T_\\mathrm{cell}$")
    ax_gT.set_ylabel("$T_\\mathrm{cell}$ (°C)", color="#dc2626")
    ax_gT.tick_params(axis='y', labelcolor="#dc2626")
    ax_g.set_title(f"Irradiance and cell temperature --- Madiun {DAY_LABELS[day_type]}")

    # Panel beban (dari Pgrid C0 hampir = beban awal sebelum collapse — pakai dari C1 stabil)
    g0 = sols["C0_no_vic"]
    # P_load tidak disimpan langsung; rekonstruksi dari Pgrid C0 + ΔP_load tetap
    # P_grid C0 saat steady = P_mppt; kalau frekuensi merosot beda. Ambil P_load
    # implicit dari kasus stabil C4 saat near-steady — tapi untuk visualisasi cukup
    # tampilkan profil beban analitik dari skrip s6 (load_per_unit ditampilkan).
    hours = np.linspace(0, 24, 481)
    p_rated = 125e3
    p_base = 0.85 * p_rated
    def load_pu(h):
        if h < 5: return 0.30
        elif h < 10: return 0.30 + 0.20*(h-5)/5
        elif h < 17: return 0.50 + 0.10*np.sin((h-10)/7*np.pi)
        elif h < 19: return 0.60 + 0.40*(h-17)/2
        elif h < 22: return 1.00 - 0.10*(h-19)/3
        else: return 0.90 - 0.60*(h-22)/2
    P_load_kw = np.array([p_base * load_pu(min(h, 23.99)) for h in hours]) / 1e3
    ax_load.plot(hours, P_load_kw, lw=1.0, color="#475569")
    ax_load.set_ylabel("Load (kW)")
    ax_load.set_title("Daily load profile (residential--commercial)")

    # Panel frekuensi
    for k in ORDER:
        g = sols[k]; lab = LABELS[k]; col = COLORS[k]; ls = STYLES[k]
        h = t_to_hour(g["t"])
        # C0 dengan |Δf|=14 Hz akan memekakkan skala; clip C0 untuk visibilitas
        f_plot = np.clip(g["f"], 35, 65) if k == "C0_no_vic" else g["f"]
        ax_f.plot(h, f_plot, lw=0.9, label=lab, color=col, ls=ls)
        ax_p.plot(h, g["Pgrid"]/1e3, lw=0.8, color=col, ls=ls)
        ax_s.plot(h, g["SOC"]*100,   lw=0.8, color=col, ls=ls)
        ax_b.plot(h, g["Pbess"]/1e3, lw=0.8, color=col, ls=ls)

    ax_f.axhline(50.0, color="k", lw=0.4, alpha=0.4)
    ax_f.set_ylabel("Frequency (Hz)")
    ax_f.set_title("Respons frekuensi (C0 di-clip ke ±15 Hz untuk visibilitas)")
    ax_f.legend(loc="lower left", frameon=False, fontsize=6.5, ncols=2,
                handlelength=2.0, columnspacing=0.6)

    ax_p.set_ylabel("$P_\\mathrm{inj}$ (kW)")
    ax_p.set_title("Daya injeksi total (PV + VIC + BESS)")
    ax_s.set_ylabel("SOC BESS (\\%)")
    ax_s.set_title("State-of-Charge BESS")
    ax_b.set_ylabel("$P_\\mathrm{bess}$ (kW)")
    ax_b.set_title("Daya BESS (positive = discharge)")
    ax_b.set_xlabel("Hour (LST)")
    ax_s.set_xlabel("Hour (LST)")

    for ax in axes.ravel():
        ax.grid(True, alpha=0.25, lw=0.4)
        ax.set_xlim(0, 24)
        ax.set_xticks(np.arange(0, 25, 4))

    fig.suptitle(f"S6 Madiun 2025 --- {DAY_LABELS[day_type]} day (24-h compressed to 240 s sim)",
                 y=1.005, fontsize=10)
    fig.tight_layout()
    fp_pdf = OUT / f"fig_{sid}.pdf"
    fp_png = OUT / f"fig_{sid}.png"
    fig.savefig(fp_pdf, bbox_inches="tight")
    fig.savefig(fp_png, bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp_pdf.name}")


def plot_s6_summary():
    """3 hari side-by-side (frekuensi C4 saja) untuk demo invarians cuaca."""
    fig, axes = plt.subplots(1, 3, figsize=(10.5, 3.0), sharey=True)
    for ax, day_type in zip(axes, DAY_TYPES):
        sols = load_h5(f"s6_madiun_{day_type}")
        prof = load_irradiance_profile(day_type)
        for k in ["C1_const_vic", "C3_adapt_vic", "C4_proposed"]:
            g = sols[k]
            h = t_to_hour(g["t"])
            ax.plot(h, g["f"], lw=0.9, color=COLORS[k], ls=STYLES[k],
                    label=LABELS[k])
        ax2 = ax.twinx()
        ax2.fill_between(prof.t_s/3600.0, 0, prof.G_W_m2, color="#fbbf24",
                         alpha=0.18, label="$G$")
        ax2.set_ylim(0, 1100)
        ax2.set_yticks([])
        ax.set_title(f"{DAY_LABELS[day_type]} day")
        ax.set_xlabel("Hour (LST)")
        ax.set_xlim(0, 24)
        ax.set_xticks(np.arange(0, 25, 6))
        ax.axhline(50.0, color="k", lw=0.4, alpha=0.3)
        ax.grid(True, alpha=0.25, lw=0.4)
    axes[0].set_ylabel("Frequency (Hz)")
    axes[0].legend(loc="lower right", frameon=False, fontsize=6.5)
    fig.suptitle("S6 Madiun 2025 --- frequency response across 3 representative days (irradiance overlay)",
                 y=1.02, fontsize=9)
    fig.tight_layout()
    fp = OUT / "fig_s6_madiun_summary.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(OUT / "fig_s6_madiun_summary.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"  saved → {fp.name}")


if __name__ == "__main__":
    print("Generating S6 figures…")
    for d in DAY_TYPES:
        plot_one_day(d)
    print("\nGenerating S6 summary…")
    plot_s6_summary()
    print("\nDone.")

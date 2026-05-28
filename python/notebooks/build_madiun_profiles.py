"""Bangun profil hourly G(t) dan T_cell(t) untuk 3 hari mewakili Madiun
2025 (cerah, berawan, hujan), lalu ekspor CSV yang dikonsumsi
julia/src/scenarios/s6_madiun.jl.

Output:
  data/processed/madiun_profile_cerah.csv
  data/processed/madiun_profile_berawan.csv
  data/processed/madiun_profile_hujan.csv
  results/figures/fig_madiun_climatology.{pdf,png}
"""
from __future__ import annotations

from pathlib import Path
import sys

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "python" / "src"))

from pvbessvic_py.nasapower_loader import (
    classify_day_type,
    export_julia_profile,
    hourly_profile_for_day,
    load_madiun_daily,
    load_madiun_hourly,
    representative_days,
)


DATA = ROOT / "data" / "nasapower" / "madiun"
PROC = ROOT / "data" / "processed"
FIG = ROOT / "results" / "figures"
PROC.mkdir(parents=True, exist_ok=True)
FIG.mkdir(parents=True, exist_ok=True)


def main():
    daily = load_madiun_daily(DATA / "madiun_2025_daily.csv")
    hourly = load_madiun_hourly(DATA / "madiun_2025_hourly.csv")

    klasifikasi = classify_day_type(daily)
    hist = klasifikasi.value_counts()
    print("Klasifikasi hari Madiun 2025:")
    for k, v in hist.items():
        print(f"  {k:<8} {v:3d} hari")

    rep = representative_days(daily)
    print("\nHari mewakili (median energi per kelas):")
    for k, d in rep.items():
        print(f"  {k:<8} {d.date()}  E={daily.loc[d, 'ALLSKY_SFC_SW_DWN']:.2f} kWh/m²")

    # ekspor 3 profil
    for label, day in rep.items():
        sub = hourly_profile_for_day(hourly, day)
        out = PROC / f"madiun_profile_{label}.csv"
        export_julia_profile(sub, out)
        print(f"  saved → {out.relative_to(ROOT)}")

    # figur klimatologi
    fig, axes = plt.subplots(2, 2, figsize=(8.5, 5.6))
    ax = axes[0, 0]
    daily["ALLSKY_SFC_SW_DWN"].plot(ax=ax, lw=0.6, color="#d97706", label="all-sky")
    daily["CLRSKY_SFC_SW_DWN"].plot(ax=ax, lw=0.6, color="#94a3b8", label="clear-sky", alpha=0.7)
    ax.set_title("Daily irradiance — Madiun 2025")
    ax.set_ylabel("kWh/m²/day"); ax.legend(fontsize=8); ax.grid(alpha=0.3)

    ax = axes[0, 1]
    label_en = {"cerah":"clear","berawan":"cloudy","hujan":"rainy"}
    hist_en = hist.rename(index=label_en)
    hist_en.plot(kind="bar", ax=ax, color=["#fbbf24", "#94a3b8", "#3b82f6"])
    ax.set_title("Day-type distribution (clearness ratio + rainfall)")
    ax.set_ylabel("Number of days"); ax.tick_params(axis="x", rotation=0)

    ax = axes[1, 0]
    for label, day in rep.items():
        sub = hourly_profile_for_day(hourly, day)
        ax.plot(sub.index.hour, sub["ALLSKY_SFC_SW_DWN"], lw=1.2,
                label=f"{label_en.get(label, label)} ({day.date()})")
    ax.set_title("Hourly G(t) profile — 3 representative days")
    ax.set_xlabel("Hour (LST)"); ax.set_ylabel("Irradiance (W/m²)")
    ax.legend(fontsize=8); ax.grid(alpha=0.3)

    ax = axes[1, 1]
    daily["T2M"].plot(ax=ax, lw=0.6, color="#dc2626", label="T_avg")
    daily["RH2M"].plot(ax=ax, lw=0.6, color="#0ea5e9", secondary_y=True, label="RH")
    ax.set_title("Daily temperature & relative humidity"); ax.set_ylabel("Temperature (°C)")
    ax.right_ax.set_ylabel("RH (%)"); ax.grid(alpha=0.3)

    fig.suptitle("NASA POWER climatology — Madiun 2025 (lat -7.629, lon 111.524)",
                 fontsize=10, y=1.02)
    fig.tight_layout()
    out_pdf = FIG / "fig_madiun_climatology.pdf"
    out_png = FIG / "fig_madiun_climatology.png"
    fig.savefig(out_pdf, bbox_inches="tight")
    fig.savefig(out_png, bbox_inches="tight", dpi=200)
    print(f"\n  saved → {out_pdf.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

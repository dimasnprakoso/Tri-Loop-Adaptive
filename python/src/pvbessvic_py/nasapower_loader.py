"""Loader untuk data NASA POWER (MERRA-2 + CERES) yang menggantikan BMKG
sebagai sumber primer iradiansi/suhu di skenario Madiun.

Alasan: BMKG dataonline butuh login + max 30 hari per request + tidak
menyediakan irradiance langsung (hanya `ss` sunshine duration). NASA POWER
gratis tanpa login, hourly resolution, dan memberikan ALLSKY_SFC_SW_DWN
(W·h/m² per jam) yang langsung dipakai sebagai irradiance W/m² rata-rata
selama jam tersebut. Lihat docs/decisions.md ADR-003 untuk konteks penuh.

CSV ekspor format `daily` dan `hourly` ada 14 baris header sebelum data.
Missing value ditandai -999. Lokasi Madiun: lat=-7.629, lon=111.524.
"""
from __future__ import annotations

import pandas as pd
import numpy as np
from pathlib import Path


def _read_power_csv(csv_path: str | Path) -> pd.DataFrame:
    # Header length depends on number of parameters; skip sampai sentinel
    csv_path = Path(csv_path)
    with csv_path.open() as f:
        lines = f.readlines()
    n_skip = next(i for i, ln in enumerate(lines) if ln.strip() == "-END HEADER-") + 1
    df = pd.read_csv(csv_path, skiprows=n_skip)
    df = df.replace(-999.0, np.nan)
    return df


def load_madiun_daily(csv_path: str | Path) -> pd.DataFrame:
    """Daily DataFrame indexed by date.

    Kolom: ALLSKY_SFC_SW_DWN (kWh/m²/hari), CLRSKY_SFC_SW_DWN (kWh/m²/hari),
    T2M (°C), T2M_MAX, T2M_MIN, RH2M (%), WS10M (m/s), PRECTOTCORR (mm/hari).
    """
    df = _read_power_csv(csv_path)
    df["date"] = pd.to_datetime(dict(year=df.YEAR, month=df.MO, day=df.DY))
    df = df.set_index("date").drop(columns=["YEAR", "MO", "DY"])
    return df.sort_index()


def load_madiun_hourly(csv_path: str | Path) -> pd.DataFrame:
    """Hourly DataFrame indexed by timestamp (LST).

    Kolom: ALLSKY_SFC_SW_DWN (Wh/m² per jam = irradiance rata-rata W/m²),
    CLRSKY_SFC_SW_DWN, T2M (°C), RH2M (%).
    """
    df = _read_power_csv(csv_path)
    df["timestamp"] = pd.to_datetime(
        dict(year=df.YEAR, month=df.MO, day=df.DY, hour=df.HR)
    )
    df = df.set_index("timestamp").drop(columns=["YEAR", "MO", "DY", "HR"])
    return df.sort_index()


def classify_day_type(daily: pd.DataFrame) -> pd.Series:
    """Klasifikasi setiap hari sebagai cerah/berawan/hujan berdasarkan
    rasio all-sky terhadap clear-sky irradiance + curah hujan.

    - cerah:    ratio ≥ 0.85 dan PRECTOTCORR < 1 mm
    - berawan:  0.45 ≤ ratio < 0.85
    - hujan:    ratio < 0.45 atau PRECTOTCORR ≥ 5 mm
    """
    ratio = daily["ALLSKY_SFC_SW_DWN"] / daily["CLRSKY_SFC_SW_DWN"]
    rain = daily.get("PRECTOTCORR", pd.Series(0, index=daily.index))
    out = pd.Series("berawan", index=daily.index, dtype=object)
    out[(ratio >= 0.85) & (rain < 1.0)] = "cerah"
    out[(ratio < 0.45) | (rain >= 5.0)] = "hujan"
    return out


def representative_days(daily: pd.DataFrame) -> dict[str, pd.Timestamp]:
    """Pilih satu hari median (mendekati rata-rata kelas) untuk setiap kelas
    cerah/berawan/hujan. Berguna untuk skenario S6 simulasi 24-jam yang
    "mewakili" pola Madiun.
    """
    klasifikasi = classify_day_type(daily)
    out = {}
    for label in ["cerah", "berawan", "hujan"]:
        sub = daily[klasifikasi == label]
        if sub.empty:
            continue
        # pilih hari yang energy harian-nya paling dekat ke median grup
        median = sub["ALLSKY_SFC_SW_DWN"].median()
        idx = (sub["ALLSKY_SFC_SW_DWN"] - median).abs().idxmin()
        out[label] = idx
    return out


def hourly_profile_for_day(hourly: pd.DataFrame,
                           day: pd.Timestamp | str) -> pd.DataFrame:
    """Ambil 24-jam profil iradiansi+suhu untuk satu hari tertentu."""
    day = pd.Timestamp(day).normalize()
    mask = (hourly.index.normalize() == day)
    return hourly.loc[mask].copy()


def export_julia_profile(hourly_day: pd.DataFrame, out_path: str | Path) -> Path:
    """Tulis CSV ringkas (t_seconds, G_W_m2, T_cell_C) untuk dikonsumsi
    Julia scenario s6_madiun. Asumsikan T_cell ≈ T_ambient + 25·(G/1000)
    dari pendekatan NOCT sederhana.
    """
    out_path = Path(out_path)
    G = hourly_day["ALLSKY_SFC_SW_DWN"].fillna(0.0).to_numpy()  # W/m² rata2/jam
    Tamb = hourly_day["T2M"].to_numpy()
    Tcell = Tamb + 25.0 * (G / 1000.0)
    t_sec = np.arange(len(G)) * 3600.0
    out = pd.DataFrame({"t_s": t_sec, "G_W_m2": G, "T_cell_C": Tcell})
    out.to_csv(out_path, index=False)
    return out_path

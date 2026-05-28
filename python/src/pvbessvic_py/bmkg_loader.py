"""Loader for BMKG meteorological data of Madiun.
Reads CSV exported from Data Online BMKG (https://dataonline.bmkg.go.id/).
"""
from __future__ import annotations
import pandas as pd
from pathlib import Path


def load_madiun(csv_path: str | Path) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    # Expected columns (BMKG default export): Tanggal, Tn, Tx, Tavg, RH_avg, RR, ss, ff_x, ddd_x, ff_avg
    df["Tanggal"] = pd.to_datetime(df["Tanggal"], dayfirst=True, errors="coerce")
    for col in df.columns:
        if col != "Tanggal":
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df.set_index("Tanggal").sort_index()


def to_irradiance_profile(df: pd.DataFrame, *, peak_W_m2: float = 1000.0) -> pd.Series:
    """Translate sunshine duration (ss, hours/day) into a daily-mean irradiance proxy.
    For sub-daily profile use SPA solar position model — placeholder here.
    """
    if "ss" not in df.columns:
        raise KeyError("expected 'ss' column (sunshine duration) in BMKG export")
    return (df["ss"] / 12.0).clip(0, 1) * peak_W_m2

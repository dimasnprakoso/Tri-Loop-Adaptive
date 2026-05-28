"""FFT analysis dari steady-state P_inj S1 untuk konfirmasi prediksi
describing-function ω_lc ≈ √(D_min/(2 H_sys T_filter)) ≈ 12.6 rad/s
≈ 2.0 Hz untuk skema C1, C2, C3 yang menderita limit cycle 5.7 kW.

Output:
  - results/processed/limit_cycle_fft.csv  (frekuensi peak per skema)
  - results/figures/fig_limit_cycle_fft.{pdf,png}
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

REPO = Path(__file__).resolve().parents[2]
RAW = REPO / "results" / "raw"
PROC = REPO / "results" / "processed"
FIG = REPO / "results" / "figures"
FIG.mkdir(parents=True, exist_ok=True)

ORDER = ["C1_const_vic", "C2_fuzzy_vic", "C3_adapt_vic", "C4_proposed"]
LABELS = {"C1_const_vic": "C1 const",
          "C2_fuzzy_vic": "C2 fuzzy",
          "C3_adapt_vic": "C3 adapt",
          "C4_proposed":  "C4 PROPOSED"}
COLORS = {"C1_const_vic": "#d97706",
          "C2_fuzzy_vic": "#a855f7",
          "C3_adapt_vic": "#0ea5e9",
          "C4_proposed":  "#dc2626"}

# Theoretical bracket: LC frequency bounded by filter poles dan supervisor
# rate. Lower bound dari swing-eq + measurement filter; upper dari BESS
# supervisor sampling. Empirical FFT akan menunjukkan peak konkret.
H_SYS = 4.0
D_MIN = 12.0
T_FILTER = 0.05       # VIC shaping filter
T_MEAS = 0.02         # measurement filter
TS_SUP = 1e-3         # BESS supervisor period
PI = np.pi
f_lower = 1 / (2 * PI * T_FILTER)              # ≈ 3.18 Hz
f_upper = 1 / (2 * PI * T_MEAS)                # ≈ 7.96 Hz (filter)
f_sup_nyquist = 1 / (2 * TS_SUP)               # 500 Hz


def load_h5(sid: str) -> dict:
    out = {}
    with h5py.File(RAW / f"{sid}.h5", "r") as f:
        for case in f.keys():
            out[case] = {k: np.asarray(f[case][k]).ravel() for k in f[case].keys()}
    return out


def fft_steady(t: np.ndarray, x: np.ndarray, t_event: float = 2.0,
               t_skip: float = 1.0, window: bool = True):
    """FFT one-sided dari window steady-state (mulai 1 detik post-event sampai akhir).

    Hann window dipakai supaya leakage tidak menutup peak limit cycle.
    """
    mask = t >= (t_event + t_skip)
    if mask.sum() < 64:
        return None, None
    ts = t[mask]
    xs = x[mask] - x[mask].mean()
    if window:
        w = np.hanning(len(xs))
        xs = xs * w
        coh_gain = w.sum() / len(w)        # window coherent gain ≈ 0.5
    else:
        coh_gain = 1.0
    dt = float(ts[1] - ts[0])
    N = len(xs)
    freqs = np.fft.rfftfreq(N, d=dt)
    X = np.abs(np.fft.rfft(xs)) * 2 / (N * coh_gain)
    return freqs, X


def main():
    sols = load_h5("s1_normal")

    rows = []
    fig, ax = plt.subplots(1, 1, figsize=(7.0, 3.6))
    fig2, axes2 = plt.subplots(1, 4, figsize=(13, 2.8), sharey=True)

    for j, c in enumerate(ORDER):
        g = sols[c]
        t = g["t"]; p = g["Pgrid"] / 1e3   # kW
        freqs, X = fft_steady(t, p)
        if freqs is None:
            continue
        # cari peak fundamental di 0.2-60 Hz (LC physical), juga peak globally
        # dalam 0.2-200 Hz (kemungkinan harmonik dari saturasi/hysteresis)
        b_fund = (freqs >= 0.2) & (freqs <= 60.0)
        b_full = (freqs >= 0.2) & (freqs <= 200.0)
        idx_fund = np.argmax(X[b_fund])
        idx_full = np.argmax(X[b_full])
        f_fund  = freqs[b_fund][idx_fund]
        a_fund  = X[b_fund][idx_fund]
        f_full  = freqs[b_full][idx_full]
        a_full  = X[b_full][idx_full]
        peak_freq, peak_amp = f_fund, a_fund   # untuk plot
        rows.append({
            "scheme": LABELS[c],
            "peak_fund_Hz": round(float(f_fund), 3),
            "peak_fund_amp_kW": round(float(a_fund), 4),
            "peak_full_Hz": round(float(f_full), 3),
            "peak_full_amp_kW": round(float(a_full), 4),
            "p2p_steady_kW": round(float(np.ptp(p[t >= 3.0])), 3),
        })
        # combined log–log spectrum
        ax.semilogy(freqs, X + 1e-6, lw=1.0, color=COLORS[c],
                    label=f"{LABELS[c]} (peak {peak_freq:.2f} Hz)")
        # individual zoom 0–80 Hz linear
        m = (freqs >= 0) & (freqs <= 80)
        axes2[j].plot(freqs[m], X[m], lw=1.0, color=COLORS[c])
        axes2[j].axvline(peak_freq, color=COLORS[c], ls="--", lw=0.6, alpha=0.7,
                         label=f"peak {peak_freq:.1f} Hz")
        axes2[j].set_title(LABELS[c], fontsize=9)
        axes2[j].set_xlabel("Frequency (Hz)")
        axes2[j].grid(True, alpha=0.25, lw=0.4)
        axes2[j].set_xlim(0, 80)
        axes2[j].legend(fontsize=6.5, frameon=False)
        if j == 0:
            axes2[j].set_ylabel("$|FFT\\{P_\\mathrm{inj}\\}|$ (kW)")

    df = pd.DataFrame(rows)
    out_csv = PROC / "limit_cycle_fft.csv"
    df.to_csv(out_csv, index=False)
    print("\n=== Limit-cycle FFT peak per scheme (S1, steady window > 3 s) ===")
    print(f"Filter pole bracket: T_filter={T_FILTER}s → 1/(2πT)={f_lower:.2f} Hz; "
          f"T_meas={T_MEAS}s → {f_upper:.2f} Hz")
    print(f"BESS supervisor Nyquist: {f_sup_nyquist:.0f} Hz")
    print()
    print(df.to_string(index=False))
    print(f"\nsaved → {out_csv.relative_to(REPO)}")

    ax.axvspan(f_lower, f_upper, color="k", alpha=0.08,
               label=f"filter-pole band [{f_lower:.1f}, {f_upper:.1f}] Hz")
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("$|FFT\\{P_\\mathrm{inj}\\}|$ (kW, log scale)")
    ax.set_xscale("log")
    ax.set_xlim(0.1, 250)
    ax.legend(loc="upper right", frameon=False, fontsize=7.0)
    ax.grid(True, alpha=0.25, lw=0.4, which="both")
    ax.set_title("S1 steady-state spectrum --- limit cycle frequency")
    fig.tight_layout()
    fp = FIG / "fig_limit_cycle_fft.pdf"
    fig.savefig(fp, bbox_inches="tight")
    fig.savefig(FIG / "fig_limit_cycle_fft.png", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"saved → {fp.relative_to(REPO)}")

    fig2.suptitle("FFT zoom 0--80 Hz per scheme --- dashed line: observed peak frequency",
                  fontsize=9.5, y=1.04)
    fig2.tight_layout()
    fp2 = FIG / "fig_limit_cycle_fft_zoom.pdf"
    fig2.savefig(fp2, bbox_inches="tight")
    fig2.savefig(FIG / "fig_limit_cycle_fft_zoom.png", bbox_inches="tight", dpi=200)
    plt.close(fig2)
    print(f"saved → {fp2.relative_to(REPO)}")


if __name__ == "__main__":
    main()

"""Publication-grade plot helpers (matplotlib + scienceplots)."""
from __future__ import annotations
import matplotlib.pyplot as plt
try:
    import scienceplots  # noqa: F401
    plt.style.use(["science", "ieee"])
except Exception:
    pass


def freq_response(t, f_dict, t_event: float = 2.0, ax=None):
    """Overlay frequency time-series for multiple control schemes."""
    if ax is None:
        _, ax = plt.subplots(figsize=(3.5, 2.2))
    for label, f in f_dict.items():
        ax.plot(t, f, label=label, lw=1.0)
    ax.axvline(t_event, color="k", ls=":", lw=0.6)
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("Frequency (Hz)")
    ax.legend(frameon=False, fontsize=7)
    return ax


def metrics_bar(metrics: dict, key: str = "rocof", ax=None):
    """Bar chart of a single metric across control schemes."""
    if ax is None:
        _, ax = plt.subplots(figsize=(3.0, 2.0))
    labels = list(metrics.keys())
    vals = [metrics[k][key] for k in labels]
    ax.bar(labels, vals)
    ax.set_ylabel(key)
    ax.tick_params(axis="x", rotation=30)
    return ax

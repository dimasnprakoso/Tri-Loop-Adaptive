"""Load JLD2 (Julia HDF5) files saved by Julia simulations into Python dicts.
JLD2 is a thin layer over HDF5; we use h5py to read raw datasets.
"""
from __future__ import annotations
import h5py
import numpy as np
from pathlib import Path


def _decode(obj):
    """Recursively decode HDF5 group/dataset into nested dict / numpy array."""
    if isinstance(obj, h5py.Dataset):
        data = obj[()]
        # JLD2 stores Julia tuples/NamedTuples as compound; arrays as native
        if isinstance(data, bytes):
            return data.decode("utf-8", errors="replace")
        return data
    if isinstance(obj, h5py.Group):
        out = {}
        for k in obj.keys():
            out[k] = _decode(obj[k])
        return out
    return obj


def load_jld2(path: str | Path) -> dict:
    """Read a JLD2 file. Returns nested dict mirroring the saved structure."""
    with h5py.File(str(path), "r") as f:
        return _decode(f)


def extract_solution(sol_group: dict) -> dict:
    """Map a Julia NamedTuple-style group to Python dict of numpy arrays."""
    return {k: np.asarray(v) for k, v in sol_group.items()
            if isinstance(v, (np.ndarray, list))}

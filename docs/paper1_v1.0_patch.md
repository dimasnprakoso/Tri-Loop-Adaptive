# Paper #1 v0.9.1 → v1.0 Patch (Setelah Validasi Simulink Lulus)

**Status:** ⏳ Pending RMSE values dari `python python/notebooks/compare_simulink_vs_julia.py`
**Trigger:** Apply hanya setelah Tabel `validation_simulink_rmse.csv` menunjukkan PASS untuk S1 dan S3.

---

## Patch 1 — Section II.B (line 246–247)

**Lokasi:** [papers/q1_tri_loop/main.tex](../papers/q1_tri_loop/main.tex) line 246–247

**Sebelum:**
```latex
analytically as a sensitivity bound in Section~\ref{sec:discussion} and
will be confirmed against MATLAB/Simulink in a forthcoming validation
appendix.
```

**Sesudah:**
```latex
analytically as a sensitivity bound in Section~\ref{sec:discussion} and
are confirmed against MATLAB/Simulink for scenarios S1 and S3 in
Appendix~\ref{sec:appendix-simulink}.
```

---

## Patch 2 — Section VI.A (line 536–539)

**Lokasi:** [papers/q1_tri_loop/main.tex](../papers/q1_tri_loop/main.tex) line 536–539

**Sebelum:**
```latex
conclusions; switching-level EMT effects are validated against the
analytical sensitivity bound in Section~\ref{sec:discussion} and will
be confirmed against MATLAB/Simulink in a forthcoming validation
appendix \cite{johnson2024large}.
```

**Sesudah:**
```latex
conclusions; switching-level EMT effects are validated against the
analytical sensitivity bound in Section~\ref{sec:discussion} and
confirmed against MATLAB/Simulink in
Appendix~\ref{sec:appendix-simulink} \cite{johnson2024large}.
```

---

## Patch 3 — Section VII.D Limitations (line 958–961)

**Lokasi:** [papers/q1_tri_loop/main.tex](../papers/q1_tri_loop/main.tex) line 958–961

**Sebelum:**
```latex
\textit{Average modelling.} The model omits PWM ripple, harmonics, and
converter dead-time. Reviewer-driven validation against
MATLAB/Simulink on scenarios S1 and S3 will be reported in a
forthcoming validation appendix following the methodology of
\cite{wang2022describing,kim2025selfexcited}.
```

**Sesudah** (isi `[TBD_*]` dengan nilai actual dari `validation_simulink_rmse.csv`):
```latex
\textit{Average modelling.} The model omits PWM ripple, harmonics, and
converter dead-time. Reviewer-driven validation against
MATLAB/Simulink on scenarios S1 and S3 is reported in
Appendix~\ref{sec:appendix-simulink} (worst-case RMSE
[TBD_F]\,mHz on $f$, [TBD_P]\,kW on $P_\mathrm{inj}$, and [TBD_V]\,V
on $V_\mathrm{DC}$ over the post-event window
$[t_\mathrm{event}+0.1,\,t_\mathrm{event}+5.0]\,$s) following the
methodology of \cite{wang2022describing,kim2025selfexcited}.
```

---

## Patch 4 — Tambah Appendix Include

**Lokasi:** [papers/q1_tri_loop/main.tex](../papers/q1_tri_loop/main.tex) line 1027 (antara Conclusion dan Reproducibility)

**Sebelum line 1028 (`\section*{Reproducibility}`):**
```latex
\appendix
\input{appendix_a_simulink}
```

**Sesudah:** (langsung lanjut ke `\section*{Reproducibility}`)

---

## Patch 5 — Isi Placeholder Appendix A

**Lokasi:** [papers/q1_tri_loop/appendix_a_simulink.tex](../papers/q1_tri_loop/appendix_a_simulink.tex)

Cari semua `[TBD]` dan isi:

| Marker | Value Source |
|---|---|
| Tabel `[TBD]` baris S1 | `validation_simulink_rmse.csv` row `s1` cols `rmse_f_Hz×1000`, `rmse_P_inj_W÷1000`, `rmse_V_dc_V` |
| Tabel `[TBD]` baris S3 | idem untuk row `s3` |
| One-sentence numerical commentary | sesuai worst-case row |

---

## Patch 6 — Update Reproducibility (line 1028–1042)

**Tambahkan setelah** existing reproducibility text:

```latex
The MATLAB/Simulink cross-validation in
Appendix~\ref{sec:appendix-simulink} can be reproduced with
\texttt{matlab/run\_s1.m} and \texttt{matlab/run\_s3.m} (MATLAB R2024a
or later, Simscape Electrical), followed by\\
\texttt{python python/notebooks/compare\_simulink\_vs\_julia.py}; the
Simulink model topology and block-level parameters are documented in
\texttt{docs/spec\_simulink.md}.
```

---

## Apply Workflow

```bash
# 1. Pastikan validasi lulus
python python/notebooks/compare_simulink_vs_julia.py
# Verify validation_simulink_rmse.csv shows PASS for both s1, s3

# 2. Apply patches 1-6 (manual atau via Claude Edit tool)

# 3. Recompile paper
cd papers/q1_tri_loop
make refresh
make

# 4. Verify: PDF compiles 0 undefined refs, Appendix A muncul dengan figures + table

# 5. Bump version
# Edit README.md changelog: tambah baris v1.0 dengan tanggal + "Simulink validation appendix"

# 6. Update SUMMARY_2026-05-02.md row Section 3:
# Status validasi Simulink: 🚧 → ✅
```

---

*Document generated: 2026-05-02. Apply only after RMSE PASS confirmed.*

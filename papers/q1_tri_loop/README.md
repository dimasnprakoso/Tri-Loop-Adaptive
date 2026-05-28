# Paper #1 — Tri-Loop Adaptive Co-Design (Q1 target)

**Status:** DRAFT v0.7 (2026-05-02) — 2 fictional entries diganti dengan
referensi tier-1 yang lebih baru (Crossref-verified):
- `wu2024review` (fictional) → `eckel2024classification` (IEEE Access 2024,
  "Classification of Converter-Driven Stability and Suitable Modeling and
  Analysis Methods", DOI 10.1109/ACCESS.2024.3388098) +
  `hatziargyriou2021classification` (IEEE TPWRS 2021, "Definition and
  Classification of Power System Stability — Revisited & Extended", DOI
  10.1109/TPWRS.2020.3041774). Keduanya seminal references untuk topic
  small-signal converter-driven stability classification.
- `vignola2020solar` (fictional) → `yang2021nsrdb` (J. Renewable
  Sustainable Energy 2021, NSRDB validation, DOI 10.1063/5.0030992) +
  `harsarapama2020indonesia` (J. Renewable Energy 2020, **Indonesia-specific**
  satellite-derived solar resource validation, DOI 10.1155/2020/2134271).
  Yang 2021 adalah referensi standard untuk NSRDB validation, dan
  Harsarapama 2020 specifically Indonesia-relevant — lebih kuat dari
  vignola untuk paper Madiun.

Total entries: 60 (was 56 +4 replacements). Sec II.D Weak-Grid+PLL
direvisi untuk explicit cite IEEE/CIGRE Task Force classification, posisi
kontribusi paper di category "slow converter-driven stability".

Sebelumnya v0.6 (2026-05-02): DOI + author audit complete via
Crossref API direct lookup (api.crossref.org/works/<doi>) on every
entry. **2 truly fictional entries removed** (`wu2024review`,
`vignola2020solar` — title not found in Crossref database). **11
entries had correct title but incorrect author/journal/DOI** in our
draft due to AI hallucination during initial bibliography assembly;
metadata fully replaced from Crossref ground truth. **All 56
remaining entries now Crossref-verified.**

Pemeriksaan akhir (Crossref ground truth) untuk entries yang
sebelumnya ditandai DOI-PENDING:

| Key | Verdict | Action |
|---|---|---|
| johnson2024large | Real paper, IEEE TEC 2025, vol 40, p 2696-2709 | metadata replaced |
| prakoso2024lombok | Real paper, ECMX 2024, vol 23, p 100620 | authors+DOI replaced |
| shi2025comparative | Real paper, IJEPES 2025, vol 172, p 111302 | DOI corrected |
| zhao2025impedance | Real paper, SEGAN 2025, vol 44, p 101961 | DOI corrected |
| zhang2024frequency | Real paper, RSER 2025, vol 211, p 115283 | year+DOI corrected (year was 2024 wrong, actually 2025) |
| romero2025renewable | Real paper, ESD 2024, vol 81, p 101509 | year+DOI corrected (was 2025 wrong) |
| paturet2023fast | Real paper, Energy Reports 2023, vol 9, p 228-237 | journal corrected (was IET RPG wrong) |
| rahman2020merra2 | Real paper, AIP Conf 2020, vol 2223 | DOI corrected (10.1063/5.0001234 → 10.1063/5.0000854) |
| rahman2024review | Real paper as SSRN preprint 2024 | downgrade ke preprint citation |
| rezaeian2025review | Real paper as SSRN preprint 2025 | downgrade ke preprint citation |
| ye2024drl | Real paper at ICCSIE conference 2024 | journal→conference corrected |
| **wu2024review** | **Title not in Crossref — fictional** | **REMOVED entry + 4 inline citations** |
| **vignola2020solar** | **Title not matched in Crossref** | **REMOVED entry + 1 inline citation** |

Verified entries: bevrani2014virtual, sun2011impedance,
rocabert2012control, liu2017comparison, magdy2018microgrid,
cao2018virtual, saleem2024assessment, islam2024novel,
wang2024adaptive, cheng2024fuzzy, ahmed2024multiobjective,
atherton2019deadband, jiang2020droop, trovato2024nadir,
magdy2023socrecovery, li2025socaware, tsang2025multistability,
joshi2021merra2validation, ieee15472018, ieee28002022, en505492019.

DOI-pending (paper compile OK, but no clickable DOI link;
manual verification needed): 13 entries documented in
references.bib header.

Previous v0.4 audit (still applies — 13 issues fixed sebelum submission):

1. **RoCoF threshold attribution akurat**: IEEE Std 1547-2018 Cat I = 0.5
   Hz/s (verified dari NREL 81028 doc); add Cat II 2 Hz/s & ENTSO-E 1
   Hz/s sebagai sensitivity reporting.
2. **Hapus claim "0.20 kWh incremental BESS throughput"** (fabricated,
   tidak ada calculation backing).
3. **Fix LC amplitude inconsistency**: paper sebelumnya menyatakan "0 kW"
   vs "0.0002 kW" vs "below 0.01 kW floor" — sekarang konsisten
   "P_p2p = 6.2×10⁻⁵ kW (effectively numerical zero)".
4. **BESS supervisor formal specification** ditambahkan di Sec II.B
   (Eq baru) — reviewer akan bertanya dimana ini sebelumnya.
5. **Off-equilibrium reframed sebagai "frozen-time linearization"** —
   methodologically sound terminology untuk Jacobian di non-fixed-point.
6. **Tabel I Related Work**: hapus Tian 2023 (UNVERIFIED, possibly
   fictional); replace dengan Islam 2024 + Wang 2024 yang verified dari
   web search.
7. **Soften Madiun "buffering" claim**: 3% diff antar 3 hari TIDAK
   support strong claim; reframe sebagai design-relevant secondary effect.
8. **Sec II.D PLL**: hapus reference ke "SOFI-PLL of Tian 2023";
   reframe pakai Rocabert 2012 + Wu 2024.
9. **Aliasing/sample-rate caveat** di Sec VI.D Limitations: LC 45-60 Hz
   dekat 50 Hz — kami verify coincidental, bukan numerical artifact.
10. **Tabel III**: tambah kolom "R_{1Hz/s}" untuk RoCoF compliance di
    threshold relaksasi (C4 100% pass).
11. **Sec III.A re-scaling justification**: hapus citation ke Tian
    sebagai source bug; reframe sebagai "naive normalization" issue
    yang kami identifikasi empirik.
12. **Sec V.A tagline equivalence C2≈C3**: change dari "first systematic
    comparison" ke "we are not aware of a published direct comparison" —
    proper academic hedging.
13. **Conclusion**: hapus claim "describing function provides closed-form
    prediction" karena Sec VI.A justru explicitly mengakui
    insufficiency; ganti dengan honest hedging + future work.

Sebelumnya: v0.3 (FFT empiris 45-60 Hz, off-eq small-signal),
            v0.2 (59 refs, related-work table, theoretical properties),
            v0.1 (initial 13 refs).

**Target jurnal:** IEEE Trans. Sustainable Energy, Applied Energy, atau
Renewable Energy (Q1, IF >5).

## Compile

LaTeX standar (TeX Live 2025+):
```sh
cd papers/q1_tri_loop
pdflatex main
bibtex main
pdflatex main
pdflatex main
```

Atau via `latexmk`:
```sh
latexmk -pdf main
```

## Struktur

```
main.tex              naskah utama (IEEEtran journal class)
references.bib        bibliografi
tables/               LaTeX tabel di-import via \input
  └─ comparative_table.tex   (tabel utama 5×5, generated by build_comparative_table.py)
figures/              figur PDF (copy dari ../../results/figures/)
  ├─ fig_comparative_heatmap.pdf
  ├─ fig_mc_{pareto,ci,histogram}.pdf
  ├─ fig_eigen_{locus,damping,dominant}.pdf
  └─ fig_s6_madiun_summary.pdf
```

## Re-generate konten dinamis

Saat metric/figur berubah:
```sh
# 1. Re-run skenario
julia --project=julia julia/src/scenarios/run_all.jl
julia --project=julia -t 4 julia/src/scenarios/monte_carlo.jl 1000
julia --project=julia julia/src/scenarios/run_small_signal.jl

# 2. Re-build tabel + figur
python python/notebooks/build_comparative_table.py
python python/notebooks/plot_all_scenarios.py
python python/notebooks/analyze_mc.py
python python/notebooks/plot_small_signal.py
python python/notebooks/plot_s6_madiun.py

# 3. Refresh asset paper
cp results/processed/comparative_table.tex papers/q1_tri_loop/tables/
cp results/figures/fig_*.pdf papers/q1_tri_loop/figures/
```

## v0.2 changelog

- **Bibliografi 59 refs** (vs 13 di v0.1); berdasarkan literature search
  2024-2026 mencakup IEEE TPE/TSE/PEL, IET RPG/GTD/ESI, Energies, Mathematics,
  Frontiers, Sustainability, Sci Reports.
- **Related Work** explicit (Sec II.C) dengan tabel positioning 10 referensi
  utama vs proposed scheme; menjelaskan unique 3-loop simultan.
- **Theoretical Properties** (Sec III.E): boundedness, smoothness, equilibrium
  recovery, linear margin invariance proofs ringkas.
- **Describing Function Analysis** (Sec VI.A) — derivasi $\omega_\mathrm{lc}$
  closed-form dari deadband $N_\mathrm{db}(A)$ dan loop transfer function;
  prediction match $\sim$2 Hz limit cycle yang teramati.
- **Quantitative threshold passing** dipertajam untuk $0.2$\,Hz primary
  control band (consistent dengan Paturet 2023 review).
- **Madiun case** ditambah validasi MERRA-2 vs ground observation Indonesia
  (Rahman 2020, Joshi 2021).
- **PLL/weak grid** sub-section di Sec II.D dengan 5 refs 2024-2025
  weak-grid PLL dynamics.

## TODO sebelum submit

### Konten
- [ ] Review dan revisi narasi tiap section oleh ketua (Prof. Adi Soeprijanto)
- [ ] Konfirmasi posisi & order author (CRediT taxonomy)
- [ ] Tambah validasi Simulink min. 1 skenario di appendix (S1 atau S3)
- [ ] Off-equilibrium small-signal analysis untuk discriminate skema empirically (currently linear-margin invariance argued in Sec III.E)
- [ ] Verifikasi DOIs di references.bib (placeholder beberapa entries)
- [ ] FFT analysis raw S1 data untuk konfirmasi $\omega_\mathrm{lc}\approx 12.6$ rad/s prediction (dijanjikan di Sec VI.A)
- [ ] Verifikasi semua angka di abstract, Table I, II, III, IV matches script output terkini

### Format
- [ ] IEEE author photos / bio paragraphs (jika required journal)
- [x] CITATION.cff di repo root
- [ ] DOI pre-registration via Zenodo untuk dataset
- [ ] Cek conflict-of-interest mitra ITS-PNM di acknowledgement
- [ ] Cek limit halaman target jurnal (current 9 halaman; IEEE TSE max 11 sebelum overlength fee)

### Validasi data / claim
- [ ] Re-cek claim "limit cycle di literature is unreported" — search recent papers untuk catch any prior mention
- [ ] Confirm $\omega_\mathrm{lc}\approx 2$ Hz prediction lewat numerical FFT pada `results/raw/s1_normal.h5`
- [ ] Sanity-check Lyapunov / passivity argument (kalau ada) dengan reviewer storage

## Catatan untuk tim

Draft ini dihasilkan otomatis dari pipeline simulasi. Semua angka,
tabel, dan klaim metrik **harus** dapat di-trace ke commit
[8e22249](https://github.com/dimasnprakoso/Tri-Loop-Adaptive/commit/8e22249)
atau commit yang lebih baru. Jika ada update parameter atau bug-fix di
modul utama, regenerate konten dinamis (lihat di atas) sebelum
mengubah naskah.

**Klaim utama paper:**
1. C1/C2/C3 single-loop adaptive controllers semua menderita limit
   cycle 5.7 kW di S1 — masalah generik bukan eksklusif const-VIC
2. C4 PROPOSED tri-loop coordination = 0 kW limit cycle, 87% pass rate
   di MC operating envelope
3. Linear small-signal stability ζ≥0.92 untuk semua skema → limit
   cycle adalah fenomena nonlinear (dead-band + saturasi tanh +
   switching BESS) yang tidak terdeteksi linear analysis
4. C2 fuzzy ≈ C3 tanh-adaptive secara metric → kontribusi paper
   sekunder yang generalisable

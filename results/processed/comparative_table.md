# Comparative Study — 5 schemes × 5 scenarios

Threshold publikasi: RoCoF ≤ 0.5 Hz/s, |Δf| ≤ 0.4 Hz, settling ≤ 2 s. Cells dengan ⚠️ menandakan melanggar threshold.


## RoCoF (Hz/s)

| Scenario | C0 no-VIC | C1 const-VIC | C2 fuzzy-VIC | C3 adapt-VIC | C4 PROPOSED |
|---|---|---|---|---|---|
| S1 normal | 0.288 | 0.065 | 0.064 | 0.066 | 0.210 |
| S2 cloud | ⚠️ 1.326 | 0.272 | 0.257 | 0.241 | 0.436 |
| S3 freq-event | ⚠️ 0.522 | 0.077 | 0.076 | 0.076 | 0.350 |
| S4 high-IBR | ⚠️ 4.491 | 0.126 | 0.135 | 0.125 | ⚠️ 0.520 |
| S5 weak-grid | ⚠️ 0.786 | 0.027 | 0.026 | 0.026 | 0.295 |

## $|\Delta f|$ max (Hz)

| Scenario | C0 no-VIC | C1 const-VIC | C2 fuzzy-VIC | C3 adapt-VIC | C4 PROPOSED |
|---|---|---|---|---|---|
| S1 normal | ⚠️ 0.414 | 0.021 | 0.021 | 0.021 | 0.059 |
| S2 cloud | ⚠️ 2.832 | 0.210 | 0.181 | 0.167 | 0.269 |
| S3 freq-event | ⚠️ 0.511 | 0.023 | 0.023 | 0.022 | 0.068 |
| S4 high-IBR | ⚠️ 1.292 | 0.024 | 0.023 | 0.023 | 0.072 |
| S5 weak-grid | ⚠️ 1.527 | 0.006 | 0.006 | 0.006 | 0.070 |

## settling (s)

| Scenario | C0 no-VIC | C1 const-VIC | C2 fuzzy-VIC | C3 adapt-VIC | C4 PROPOSED |
|---|---|---|---|---|---|
| S1 normal | 0.032 | 0.000 | 0.000 | 0.000 | 0.000 |
| S2 cloud | n/a | 0.498 | 0.478 | 0.460 | 0.562 |
| S3 freq-event | 0.670 | 0.000 | 0.000 | 0.000 | 0.031 |
| S4 high-IBR | n/a | 0.000 | 0.000 | 0.000 | 0.011 |
| S5 weak-grid | ⚠️ 4.975 | 0.000 | 0.000 | 0.000 | 0.048 |

## BESS thrpt (kWh)

| Scenario | C0 no-VIC | C1 const-VIC | C2 fuzzy-VIC | C3 adapt-VIC | C4 PROPOSED |
|---|---|---|---|---|---|
| S1 normal | 0.000 | 0.010 | 0.010 | 0.010 | 0.031 |
| S2 cloud | 0.000 | 0.084 | 0.078 | 0.074 | 0.112 |
| S3 freq-event | 0.000 | 0.015 | 0.015 | 0.015 | 0.043 |
| S4 high-IBR | 0.000 | 0.016 | 0.016 | 0.015 | 0.047 |
| S5 weak-grid | 0.000 | 0.003 | 0.003 | 0.003 | 0.010 |

## $P_\mathrm{inj}$ p2p (kW)

| Scenario | C0 no-VIC | C1 const-VIC | C2 fuzzy-VIC | C3 adapt-VIC | C4 PROPOSED |
|---|---|---|---|---|---|
| S1 normal | 0.000 | ⚠️ 5.802 | ⚠️ 5.704 | ⚠️ 5.670 | 0.000 |
| S2 cloud | 0.000 | 0.000 | 0.000 | 0.000 | 0.001 |
| S3 freq-event | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| S4 high-IBR | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| S5 weak-grid | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |

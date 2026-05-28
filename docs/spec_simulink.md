# SPEC — Porting Model Julia ke MATLAB/Simulink (Validasi Silang Paper #1)

**Tanggal:** 2026-05-02
**Sumber:** [PIPELINE.md Section 8](PIPELINE.md) — Validasi Silang Simulink
**Target:** RMSE < 2% pada window post-event untuk skenario S1 dan S3
**Format:** Hybrid — `.slx` (Simscape Electrical) untuk grid+inverter; `.m` (MATLAB function) untuk control logic
**Eksekutor:** User (Erina Rahmadyanti, akses MATLAB+Simscape Electrical aktif)

---

## 1. Arsitektur Hybrid

```
┌──────────────────────── pv_bess_vic_validation.slx ────────────────────────┐
│                                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐                 │
│  │ PV Array     │  │ DC-Link      │  │ Averaged 3φ      │                 │
│  │ (Simscape    │→ │ + Boost-DC/DC│→ │ Inverter Model   │→ Grid Thevenin  │
│  │  Electrical) │  │              │  │ (controlled VSC) │                 │
│  └──────────────┘  └──────────────┘  └──────────────────┘                 │
│         ↑                  ↑                  ↑                            │
│         G(t)               V_dc_ref          P_ref, Q_ref                  │
│         T_c(t)                                                             │
│         |                  |                   |                            │
│  ╔═════════════════════════════════════════════════════════════════════╗  │
│  ║  MATLAB Function Block: control_logic()                             ║  │
│  ║  ┌──────┐  ┌────────┐  ┌──────────┐  ┌─────────┐  ┌──────────┐    ║  │
│  ║  │ MPPT │→ │ VIC    │→ │ BESS     │→ │ Coord   │→ │ P_ref    │    ║  │
│  ║  │ P&O  │  │ adapt. │  │ super-   │  │ α, β    │  │ Q_ref    │    ║  │
│  ║  │      │  │ tanh   │  │ visor    │  │         │  │          │    ║  │
│  ║  └──────┘  └────────┘  └──────────┘  └─────────┘  └──────────┘    ║  │
│  ║   Sumber: vic_adaptive.m, bess_supervisor.m, adaptive_coord.m       ║  │
│  ╚═════════════════════════════════════════════════════════════════════╝  │
│         ↑                                                                  │
│         f(t), V_dc(t), I_pv(t), SOC(t), P_load(t)                          │
└────────────────────────────────────────────────────────────────────────────┘
```

**Pembagian tanggung jawab:**

| Komponen | Lokasi | Alasan |
|---|---|---|
| PV array (single-diode, 38p×10s) | `.slx` (Simscape Electrical → PV Array block) | Built-in, cukup pakai datasheet |
| DC-link kapasitor + boost converter | `.slx` (Simscape Electrical) | Switching-level looking → reviewer Q1 puas |
| Averaged 3φ inverter (controlled VSC) | `.slx` (Simscape Electrical → Average Model) | Tidak perlu PWM detail di skala detik |
| LCL/L filter + grid Thevenin | `.slx` (Simscape Electrical → Three-Phase Source + RL) | EMT visible |
| **MPPT P&O** | `.m` (MATLAB Function) | Logic-heavy, lebih bersih sebagai script |
| **VIC adaptive H(t), D(t) tanh** | `.m` (MATLAB Function) | Custom non-linear, hindari Lookup Table |
| **BESS supervisor state machine** | `.m` (MATLAB Function) atau Stateflow | Pilih salah satu — Stateflow kalau mau visual |
| **Adaptive coord α, β** | `.m` (MATLAB Function) | Custom formula |
| **Swing equation grid frequency** | `.m` (MATLAB Function) di Continuous block | Needs custom H_sys, D_sys per skenario |

---

## 2. Parameter Sistem (Canonical)

> Semua nilai harus **identik** dengan `julia/src/models/params.jl`. Saat MATLAB di-load, jalankan dulu `pv_bess_vic_params.m` (lihat Section 5.1) yang mengisi workspace.

### 2.1 Ratings

| Parameter | Simbol | Nilai | Unit |
|---|---|---|---|
| Daya inverter | `P_rated` | 125 | kW |
| Tegangan DC referensi | `V_dc_ref` | 1200 | V |
| Frekuensi nominal | `f0` | 50 | Hz |
| ω nominal | `omega0` | 2π·50 = 314.159 | rad/s |

### 2.2 PV Single-Diode (38 strings × 10 modul series)

| Parameter | Nilai | Unit |
|---|---|---|
| `Iph_stc` | 8.21 | A/string |
| `I0` | 2.5e-10 | A |
| `Rs` | 0.221 | Ω |
| `Rsh` | 415.405 | Ω |
| `a` (idealitas) | 1.3 | — |
| `Ns` (sel/modul) | 60 | — |
| `Ns_modules` | 10 | — |
| `Np_strings` | 38 | — |
| `G_stc`, `T_stc` | 1000, 25 | W/m², °C |
| `Ki`, `Kv` | 0.0032, −0.123 | 1/°C |

### 2.3 BESS

| Parameter | Nilai | Unit |
|---|---|---|
| `E_rated_kWh` | 50 | kWh |
| `eta_ch`, `eta_dis` | 0.95, 0.95 | — |
| `SOC_min`, `SOC_max` | 0.20, 0.90 | — |
| `SOC_init` | 0.60 | — |
| `P_bess_max` | 60 | kW |

### 2.4 Inverter & PLL

| Parameter | Nilai | Unit |
|---|---|---|
| `L_filter`, `R_filter` | 0.7e-3, 0.05 | H, Ω |
| `C_dc` | 5e-3 | F |
| `Kp_idq`, `Ki_idq` | 66.58, 13316.5 | — |
| `Kp_vdc`, `Ki_vdc` | 1.5, 50.0 | — |
| `Kp_pll`, `Ki_pll` | 92.0, 4232.0 | — |
| `SCR_thr` | 2.0 | — |

### 2.5 VIC Adaptive

| Parameter | Nilai | Unit |
|---|---|---|
| `H_min`, `H_max` | 1.0, 5.0 | s |
| `D_min`, `D_max` | 12.0, 50.0 | pu |
| `gamma_J`, `delta_D` | 1.0, 1.0 | — |
| `omega_dot_ref` | 2π·1.0 | rad/s² |
| `omega_ref_vic` | 2π·0.3 | rad/s |
| `T_filter_omega` | 0.05 | s |
| `P_vic_max` | 0.5·P_rated = 62.5 | kW |

### 2.6 Adaptive Coordination

| Parameter | Nilai | Unit |
|---|---|---|
| `k_alpha`, `k_alpha_rocof` | 4.0, 1.0 | — |
| `beta_max` | 0.7 | — |
| `domega_dead` | 2π·0.02 | rad/s |

### 2.7 Grid Thevenin

| Parameter | Nilai | Unit |
|---|---|---|
| `V_grid` (L-L RMS) | 400 | V |
| `SCR` | 5.0 | — |
| `X_R` ratio | 7.0 | — |
| `R_grid` | 0.362 | Ω (computed) |
| `X_grid` | 2.534 | Ω (computed) |

### 2.8 Per-Skenario (H_sys, D_sys, P_load)

| Skenario | `H_sys` [s] | `D_sys` [pu] | `P_load_pre` [kW] | `P_load_post` [kW] | `t_event` [s] | `t_end` [s] |
|---|---|---|---|---|---|---|
| **S1** Normal load step | 4.0 | 5.0 | 123.75 | 130.00 | 2.0 | 10.0 |
| **S3** Generator loss | 4.0 | 5.0 | 118.75 | 131.25 | 2.0 | 10.0 |

### 2.9 Solver Settings

| Parameter | Nilai |
|---|---|
| `Ts_control` | 50e-6 s (Simulink fixed-step) |
| `Ts_supervisor` | 1e-3 s (BESS supervisor only) |
| `Ts_log` | 1e-3 s (output downsampling) |
| Solver tipe | `ode4` (Runge-Kutta) atau `ode23tb` (stiff) |

---

## 3. Bagian Simulink (.slx) — Plant + Grid

### 3.1 Topologi Subsystem

```
PV Array → DC link → Boost DC-DC → DC-link cap (C_dc) →
  Averaged 3φ Inverter (Vd, Vq controlled) → L_filter →
  Three-Phase RL (R_grid, X_grid) → Three-Phase Voltage Source (V_grid, f0)
```

### 3.2 Block Library Mapping

| Fungsi | Library | Block |
|---|---|---|
| PV array (38p×10s) | Simscape Electrical / Renewable | **PV Array** (set 1Soltech 1STH-215-P × 38p10s atau custom dari params) |
| Boost DC-DC | Simscape Electrical / Power Electronics | **Boost Converter** (averaged) atau IGBT + diode + L + C |
| DC-link kapasitor | Simscape Foundation / Electrical | **Capacitor** (5 mF) |
| Inverter 3φ | Simscape Electrical / Power Electronics | **Two-Level Converter** (averaged-value mode) |
| Filter LCL | Simscape Foundation / Electrical | **Series RL Branch** + **Shunt C** (opsional, untuk averaged cukup R+L) |
| Grid Thevenin | Simscape Electrical / Sources | **Three-Phase Source** (V_grid, f0) + **Three-Phase Series RLC** (R_grid, X_grid/omega0) |
| Frekuensi grid (swing eq) | Simulink / Continuous | **Integrator** dengan input dari MATLAB Function (Section 4.5) |
| Measurement | Simscape Electrical / Sensors | **Three-Phase V-I Measurement**, **DC Voltage Sensor** |

### 3.3 Catatan Implementasi Plant

- **Averaged inverter**: pakai mode "Average model (Vab, Vbc)" pada block Two-Level Converter — input langsung modulating signal (dq atau abc), tidak perlu PWM. Ini matches dengan asumsi Julia (no switching dynamics).
- **Grid frequency**: jangan pakai konstanta 50 Hz di Three-Phase Source. Grid frequency ω(t) adalah **state output** dari swing equation (Section 4.5). Implementasi:
  1. Tetap pakai Three-Phase Source dengan frekuensi 50 Hz untuk Thevenin voltage references.
  2. Sinyal frekuensi grid yang diukur (`f_meas` di output PLL) bukan langsung dari source — di-derive via swing equation external block.
  3. Atau lebih sederhana: pakai **Programmable Voltage Source** dengan ω(t) di-feed dari MATLAB Function `swing_equation.m`.
- **Load model**: pakai **Three-Phase Dynamic Load** atau resistor variabel. Untuk S1/S3, profil step di t=2s — gampang dengan Step block ke setpoint dynamic load.

### 3.4 Diagram Bus Signal (input ke .m)

Buat **Bus Creator** dengan field:

```
plant_meas.f          [Hz]      Frekuensi grid (output PLL atau swing eq)
plant_meas.rocof      [Hz/s]    Numerical derivative f(t)
plant_meas.V_dc       [V]       DC-link voltage
plant_meas.I_pv       [A]       PV array current
plant_meas.V_pv       [V]       PV terminal voltage
plant_meas.P_load     [W]       Load power demand (eksternal lookup)
plant_meas.G          [W/m²]    Irradiance (eksternal lookup)
plant_meas.T_c        [°C]      Cell temperature (eksternal lookup)
plant_meas.SOC        [pu]      BESS SOC (state, internal feedback)
```

Output dari MATLAB Function (Section 4):

```
ctrl.P_ref            [W]       Power reference inverter
ctrl.Q_ref            [VAR]     0 (unity power factor untuk S1, S3)
ctrl.V_dc_ref         [V]       1200
ctrl.P_bess_cmd       [W]       Command ke BESS converter
ctrl.alpha            [pu]      Telemetry weight α
ctrl.beta             [pu]      Telemetry weight β
ctrl.H_eff            [s]       Effective inertia H(t)
```

---

## 4. Bagian MATLAB (.m) — Control Logic

Letakkan file di [matlab/](../matlab/). Struktur folder:

```
matlab/
├── pv_bess_vic_params.m          ← parameter loader (Section 5.1)
├── control_logic.m                ← top-level MATLAB Function (orchestrator)
├── functions/
│   ├── mppt_po.m                  ← Section 4.1
│   ├── vic_adaptive.m             ← Section 4.2
│   ├── bess_supervisor.m          ← Section 4.3
│   ├── adaptive_coord.m           ← Section 4.4
│   ├── swing_equation.m           ← Section 4.5
│   └── single_diode_iv.m          ← Section 4.6 (untuk MPP search)
├── scenarios/
│   ├── run_s1.m                   ← Section 6.1
│   └── run_s3.m                   ← Section 6.2
├── postprocess/
│   └── export_to_csv.m            ← Section 7
└── pv_bess_vic_validation.slx     ← Section 3 (build manual)
```

### 4.1 MPPT P&O (`mppt_po.m`)

> Julia pakai grid search 80-point untuk MPP cache. MATLAB lebih clean pakai P&O dengan step adaptif. Hasil ekuivalen di steady-state (G konstan), bedanya saat ramp G (untuk S1/S3 G konstan jadi tidak masalah).

```matlab
function [P_mppt, V_pv_ref] = mppt_po(V_pv, I_pv, V_pv_ref_prev, P_prev, dV_step)
% P&O MPPT
% Input:
%   V_pv          : tegangan PV terukur [V]
%   I_pv          : arus PV terukur [A]
%   V_pv_ref_prev : tegangan setpoint sebelumnya [V]
%   P_prev        : power sebelumnya [W]
%   dV_step       : step perturbation [V] (default 1.0)
% Output:
%   P_mppt        : power saat ini [W]
%   V_pv_ref      : tegangan setpoint baru [V]

    P_now = V_pv * I_pv;
    dP = P_now - P_prev;
    dV = V_pv - (V_pv_ref_prev - dV_step);  % asumsi previous ref dipakai

    if dP > 0
        if dV > 0
            V_pv_ref = V_pv_ref_prev + dV_step;
        else
            V_pv_ref = V_pv_ref_prev - dV_step;
        end
    else
        if dV > 0
            V_pv_ref = V_pv_ref_prev - dV_step;
        else
            V_pv_ref = V_pv_ref_prev + dV_step;
        end
    end

    V_pv_ref = max(min(V_pv_ref, 450), 250);  % clamp [250, 450] V
    P_mppt = P_now;
end
```

**Catatan validasi:** Untuk S1/S3 (G konstan 1000 W/m², T_c 30°C), MPP analytical ≈ 124.5 kW. P&O harus settle dalam ±0.5 kW dalam 0.5 detik pertama. Compare dengan Julia `Pmppt[end]` pada steady-state.

### 4.2 VIC Adaptive (`vic_adaptive.m`)

```matlab
function [P_vic, H_t, D_t, P_filt_new] = vic_adaptive(domega, domega_dt, P_filt_prev, params)
% Adaptive Virtual Inertia Control dengan tanh saturation
% Input:
%   domega       : Δω = ω - ω0 [rad/s]
%   domega_dt    : dω/dt [rad/s²]
%   P_filt_prev  : state filter [W]
%   params       : struct dari pv_bess_vic_params.m
% Output:
%   P_vic        : virtual inertia power [W]
%   H_t          : effective inertia [s]
%   D_t          : effective damping [pu]
%   P_filt_new   : updated filter state [W]

    % Adaptive gains
    H_t = params.H_min + (params.H_max - params.H_min) * ...
          tanh(params.gamma_J * abs(domega_dt) / params.omega_dot_ref);
    D_t = params.D_min + (params.D_max - params.D_min) * ...
          tanh(params.delta_D * abs(domega) / params.omega_ref_vic);

    % Swing-form output
    P_raw = -(2 * H_t / params.omega0 * domega_dt + ...
              D_t * domega / params.omega0) * params.P_rated;

    % First-order low-pass filter (T = T_filter_omega)
    alpha_filt = params.dt / (params.T_filter_omega + params.dt);
    P_filt_new = (1 - alpha_filt) * P_filt_prev + alpha_filt * P_raw;

    % Clamp
    P_vic = max(min(P_filt_new, params.P_vic_max), -params.P_vic_max);
end
```

### 4.3 BESS Supervisor (`bess_supervisor.m`)

State machine 4-mode. Implementasi simple sebagai if-else (atau Stateflow chart kalau mau visualization).

```matlab
function [mode, P_bess_cmd] = bess_supervisor(domega, domega_dt, P_pv, P_load, SOC, params)
% Modes: 0=IDLE, 1=DISCHARGE, 2=CHARGE, 3=STANDBY

    domega_dead = 2*pi*0.02;
    rocof_dead  = 2*pi*0.05;

    % 1. STANDBY (protection)
    if (SOC <= params.SOC_min + 0.02) || ...
       (SOC >= params.SOC_max - 0.02 && P_pv > P_load)
        mode = 3;
        P_bess_cmd = 0;
        return;
    end

    % 2. Normal operation (no freq event)
    if abs(domega) < domega_dead && abs(domega_dt) < rocof_dead
        if P_pv > P_load && SOC < params.SOC_max
            mode = 2;  % CHARGE
            P_bess_cmd = -min(params.P_bess_max, P_pv - P_load);
        else
            mode = 0;  % IDLE
            P_bess_cmd = 0;
        end
        return;
    end

    % 3. Frequency event response
    sev_w = 2 * domega / (2*pi*0.5);
    sev_r = 0.5 * domega_dt / (2*pi*0.5);
    P_support = -params.P_bess_max * tanh(sev_w + sev_r);

    if P_support > 0 && SOC > params.SOC_min
        mode = 1;  % DISCHARGE
        P_bess_cmd = P_support;
    elseif P_support < 0 && SOC < params.SOC_max
        mode = 2;  % CHARGE
        P_bess_cmd = P_support;
    else
        mode = 3;  % STANDBY
        P_bess_cmd = 0;
    end
end
```

> **Penting:** Supervisor di-update setiap 1 ms (`Ts_supervisor`), bukan setiap 50 µs. Di Simulink, taruh block ini di Triggered Subsystem dengan periodic trigger 1 ms, atau pakai Sample Time = 1e-3 di MATLAB Function block.

### 4.4 Adaptive Coordination (`adaptive_coord.m`)

```matlab
function [P_ref, alpha, beta] = adaptive_coord(P_mppt, P_vic, P_bess_avail, ...
                                                domega, domega_dt, SOC, params)
% Output: combined reference, plus telemetry weights α, β

    % α weight (telemetry only; tidak menggating P_vic)
    if abs(domega) > params.domega_dead
        domega_eff = domega;
    else
        domega_eff = 0;
    end
    alpha = 1.0 / (1.0 + params.k_alpha * abs(domega_eff) + ...
                   params.k_alpha_rocof * abs(domega_dt));

    % β BESS share
    if SOC < params.SOC_min || SOC > params.SOC_max
        beta = 0;
    else
        SOC_nom = 0.5 * (params.SOC_min + params.SOC_max);
        soc_headroom = 1.0 - 2*abs(SOC - SOC_nom) / (params.SOC_max - params.SOC_min);
        sev = max(abs(domega) / params.omega_ref_vic, ...
                  abs(domega_dt) / params.omega_dot_ref);
        beta = params.beta_max * soc_headroom * tanh(sev);
    end

    % Final reference
    P_ref = P_mppt + P_vic + beta * P_bess_avail;
    P_ref = max(min(P_ref, 1.5*params.P_rated), -1.5*params.P_rated);
end
```

### 4.5 Swing Equation (`swing_equation.m`)

```matlab
function domega_dt = swing_equation(P_inj, P_load, omega, H_sys, D_sys, params)
% Single-area swing equation
% State: omega [rad/s] (integrated externally)
% Output: domega/dt [rad/s²]

    domega = omega - params.omega0;
    dP_pu = (P_inj - P_load) / params.P_rated;

    domega_dt = (dP_pu - D_sys * domega / params.omega0) * ...
                params.omega0 / (2 * H_sys);
end
```

**Wiring di Simulink:**
- Output `domega_dt` → masuk ke **Integrator** dengan IC `omega0`
- Integrator output `omega` → feed back ke `swing_equation` AND ke Programmable Voltage Source (sebagai f_grid input).
- Frekuensi terukur: `f_meas = omega / (2*pi)` → ke Bus.

### 4.6 Single-Diode I-V (`single_diode_iv.m`)

> Untuk MPP cache verification (opsional kalau pakai PV Array Simscape block).

```matlab
function I = single_diode_iv(V, G, T_c, params)
% Iterative solver for single-diode equation (per string, then ×Np_strings for array)
    T_k = T_c + 273.15;
    Iph = (params.Iph_stc + params.Ki * (T_c - params.T_stc)) * G / params.G_stc;
    Vt  = params.a * params.Ns * 1.380649e-23 * T_k / 1.602176634e-19;

    % fzero on residual: I - Iph + I0*(exp((V+I*Rs)/(Ns*Vt)) - 1) + (V+I*Rs)/(Ns*Rsh) = 0
    f = @(I) I - Iph + params.I0 * (exp((V + I*params.Rs)/(params.Ns*Vt)) - 1) ...
             + (V + I*params.Rs)/(params.Ns*params.Rsh);
    I_string = fzero(f, [0, Iph * 1.5]);
    I = I_string * params.Np_strings;  % array-level
end
```

---

## 5. Integrasi Plant + Control

### 5.1 Parameter Loader (`pv_bess_vic_params.m`)

```matlab
function params = pv_bess_vic_params()
% Mirror dari julia/src/models/params.jl
    % Ratings
    params.P_rated  = 125e3;
    params.V_dc_ref = 1200;
    params.f0       = 50;
    params.omega0   = 2*pi*50;

    % PV
    params.Iph_stc    = 8.21;
    params.I0         = 2.5e-10;
    params.Rs         = 0.221;
    params.Rsh        = 415.405;
    params.a          = 1.3;
    params.Ns         = 60;
    params.Ns_modules = 10;
    params.Np_strings = 38;
    params.G_stc      = 1000;
    params.T_stc      = 25;
    params.Ki         = 0.0032;
    params.Kv         = -0.123;

    % BESS
    params.E_rated_J   = 50 * 3.6e6;
    params.eta_ch      = 0.95;
    params.eta_dis     = 0.95;
    params.SOC_min     = 0.20;
    params.SOC_max     = 0.90;
    params.SOC_init    = 0.60;
    params.P_bess_max  = 60e3;

    % Inverter & PLL
    params.L_filter = 0.7e-3;
    params.R_filter = 0.05;
    params.C_dc     = 5e-3;
    params.Kp_pll   = 92.0;
    params.Ki_pll   = 4232.0;
    params.SCR_thr  = 2.0;

    % VIC
    params.H_min           = 1.0;
    params.H_max           = 5.0;
    params.D_min           = 12.0;
    params.D_max           = 50.0;
    params.gamma_J         = 1.0;
    params.delta_D         = 1.0;
    params.omega_dot_ref   = 2*pi*1.0;
    params.omega_ref_vic   = 2*pi*0.3;
    params.T_filter_omega  = 0.05;
    params.P_vic_max       = 0.5 * params.P_rated;

    % Coord
    params.k_alpha        = 4.0;
    params.k_alpha_rocof  = 1.0;
    params.beta_max       = 0.7;
    params.domega_dead    = 2*pi*0.02;

    % Grid
    params.V_grid = 400;
    params.SCR    = 5.0;
    params.X_R    = 7.0;
    Z_pu = 1 / params.SCR;
    X_pu = Z_pu * params.X_R / sqrt(1 + params.X_R^2);
    R_pu = X_pu / params.X_R;
    Z_base = params.V_grid^2 / params.P_rated;
    params.R_grid = R_pu * Z_base;
    params.X_grid = X_pu * Z_base;
    params.L_grid = params.X_grid / params.omega0;

    % Solver
    params.dt = 50e-6;
    params.Ts_log = 1e-3;
end
```

### 5.2 Top-level `control_logic.m` (MATLAB Function di Simulink)

```matlab
function [P_ref, Q_ref, V_dc_ref, P_bess_cmd, alpha, beta, H_eff] = ...
    control_logic(plant_meas, scenario_id)
% Persistent state untuk filters & MPPT
    persistent params P_filt P_mppt V_pv_ref P_prev SOC

    if isempty(params)
        params = pv_bess_vic_params();
        P_filt = 0; P_mppt = 0; V_pv_ref = 350; P_prev = 0;
        SOC = params.SOC_init;
    end

    % Frequency deviation
    domega    = 2*pi*plant_meas.f - params.omega0;
    domega_dt = 2*pi*plant_meas.rocof;

    % MPPT
    [P_mppt, V_pv_ref] = mppt_po(plant_meas.V_pv, plant_meas.I_pv, ...
                                  V_pv_ref, P_prev, 1.0);
    P_prev = P_mppt;

    % VIC
    [P_vic, H_eff, ~, P_filt] = vic_adaptive(domega, domega_dt, P_filt, params);

    % BESS supervisor (resampled to 1 ms via Sample Time)
    [~, P_bess_cmd] = bess_supervisor(domega, domega_dt, P_mppt, ...
                                       plant_meas.P_load, plant_meas.SOC, params);

    % Adaptive coordination
    [P_ref, alpha, beta] = adaptive_coord(P_mppt, P_vic, P_bess_cmd, ...
                                           domega, domega_dt, plant_meas.SOC, params);

    Q_ref    = 0;
    V_dc_ref = params.V_dc_ref;
end
```

### 5.3 Sample Time Tags

| Block | Sample Time | Catatan |
|---|---|---|
| `control_logic` (orchestrator) | 50e-6 | matches Julia Ts_control |
| `bess_supervisor` (di dalamnya) | 1e-3 | downsampled internally via persistent counter, atau pakai Triggered Subsystem |
| Plant Simscape | continuous | solver ode4/ode23tb |
| Output To Workspace | 1e-3 | matches Julia Ts_log |

---

## 6. Skenario S1 dan S3

### 6.1 S1 — Normal Load Step (`run_s1.m`)

```matlab
function out = run_s1()
    params = pv_bess_vic_params();

    % Skenario inputs
    params.G       = 1000;       % konstan W/m²
    params.T_c     = 30;         % konstan °C
    params.H_sys   = 4.0;        % grid inertia
    params.D_sys   = 5.0;        % grid damping
    params.t_event = 2.0;        % step di t=2s
    params.t_end   = 10.0;
    params.P_load_pre  = 0.99 * params.P_rated;   % 123.75 kW
    params.P_load_post = 1.04 * params.P_rated;   % 130.00 kW (+5%)

    % Set semua param ke base workspace agar Simulink bisa akses
    fields = fieldnames(params);
    for i = 1:numel(fields)
        assignin('base', fields{i}, params.(fields{i}));
    end

    % Run Simulink
    out = sim('pv_bess_vic_validation', ...
              'StopTime', num2str(params.t_end), ...
              'FixedStep', num2str(params.dt));
end
```

### 6.2 S3 — Generator Loss (`run_s3.m`)

Sama dengan S1, beda hanya:
```matlab
params.P_load_pre  = 0.95 * params.P_rated;   % 118.75 kW
params.P_load_post = 1.05 * params.P_rated;   % 131.25 kW (+10%, equivalent 10% gen loss)
```

---

## 7. Output Logging + CSV Export

### 7.1 Sinyal yang di-log

Pakai **To Workspace** dengan format `Timeseries`, sample time 1 ms. Variabel:

| Nama | Sumber | Unit |
|---|---|---|
| `t` | clock | s |
| `f` | swing_eq output / (2π) | Hz |
| `rocof` | numerical diff f | Hz/s |
| `V_dc` | DC voltage sensor | V |
| `P_mppt` | control_logic output | W |
| `P_vic` | (compute internally; expose via Out port) | W |
| `P_ref` | control_logic output | W |
| `P_inj` | inverter terminal power (3φ instantaneous) | W |
| `P_bess` | BESS converter terminal | W |
| `SOC` | BESS state | pu |
| `alpha`, `beta`, `H_eff` | control_logic outputs | pu, pu, s |

### 7.2 Export Script (`postprocess/export_to_csv.m`)

```matlab
function export_to_csv(out, scenario_id, output_dir)
% out          : struct dari sim()
% scenario_id  : 's1' atau 's3'
% output_dir   : path ke E:\Disertasi\pemodelan\data\simulink_ref\

    t = out.tout;
    T = table(t, ...
              out.f.Data,        ...
              out.rocof.Data,    ...
              out.V_dc.Data,     ...
              out.P_mppt.Data,   ...
              out.P_vic.Data,    ...
              out.P_ref.Data,    ...
              out.P_inj.Data,    ...
              out.P_bess.Data,   ...
              out.SOC.Data,      ...
              out.alpha.Data,    ...
              out.beta.Data,     ...
              out.H_eff.Data,    ...
              'VariableNames', ...
              {'t','f','rocof','V_dc','P_mppt','P_vic','P_ref',...
               'P_inj','P_bess','SOC','alpha','beta','H_eff'});

    fname = fullfile(output_dir, sprintf('matlab_%s_C4.csv', scenario_id));
    writetable(T, fname);
    fprintf('Saved: %s (%d rows)\n', fname, height(T));
end
```

### 7.3 Skema Kontrol yang Divalidasi

Untuk validasi Paper #1, **cukup C4 (PROPOSED)** saja. Skema C0–C3 sudah di-cover oleh Julia run; perbandingan langsung Julia vs MATLAB hanya untuk PROPOSED.

Kalau mau ekstra confidence, run juga **C0** (baseline no-VIC) untuk memastikan plant model agree saat tidak ada control aktif.

---

## 8. Acceptance Criteria

### 8.1 Window Validasi

Window post-event untuk RMSE: `t ∈ [t_event + 0.1, t_event + 5.0]` = `[2.1, 7.0]` s.
0.1 s grace period setelah event memberi waktu transient initial.

### 8.2 Sinyal Wajib Divalidasi

| Sinyal | Target RMSE | Catatan |
|---|---|---|
| `f(t)` [Hz] | < 0.01 Hz (≈2% dari Δf nadir 0.5 Hz) | Paling kritis |
| `P_inj(t)` [kW] | < 2.5 kW (2% dari P_rated 125 kW) | |
| `V_dc(t)` [V] | < 24 V (2% dari V_dc_ref 1200 V) | |
| `P_bess(t)` [kW] | informatif, tidak hard threshold | |

### 8.3 Computed Metrics Cross-Check

Setelah RMSE OK, verifikasi 3 metric (matches `scenarios_metrics.csv` row C4):

| Metric | S1 target (Julia) | S3 target (Julia) |
|---|---|---|
| RoCoF max [Hz/s] | 0.2098 | 0.3500 (estimasi) |
| \|Δf\|_max [Hz] | 0.0589 | 0.0680 |
| Settling time [s] | 0 (sudah dalam band) | 0.031 |

Toleransi ±5% untuk metric (lebih longgar dari RMSE karena metric pakai max/min).

---

## 9. Workflow Eksekusi

```
[1] Update repo: git pull origin main
[2] Buka MATLAB di E:\Disertasi\pemodelan
[3] Build Simulink model (Section 3) — manual one-time
[4] Save: matlab/pv_bess_vic_validation.slx
[5] Tulis .m functions (Section 4) — copy-paste dari SPEC ini
[6] Run scenarios:
    >> addpath(genpath('matlab'))
    >> out_s1 = run_s1();
    >> out_s3 = run_s3();
    >> export_to_csv(out_s1, 's1', 'data/simulink_ref/');
    >> export_to_csv(out_s3, 's3', 'data/simulink_ref/');
[7] Beri tahu Claude → akan run notebook overlay + RMSE
[8] Kalau RMSE > 2% → debug per-sinyal:
    a. f(t) divergence → cek H_sys, D_sys, swing equation timestep
    b. P_inj divergence → cek MPPT P&O step size, VIC tanh argumen
    c. V_dc divergence → cek C_dc, boost converter setting
[9] Kalau semua < 2% → tulis docs/validation_simulink.md → bump Paper #1 ke v1.0
```

---

## 10. Catatan Implementasi & Pitfalls

### 10.1 Sign Convention
- `P_bess > 0` = discharge (BESS injeksi power ke DC bus)
- `P_bess < 0` = charge (BESS absorb power dari DC bus)
- `P_inj > 0` = inverter inject ke grid

### 10.2 Filter Initial Condition
- `P_filt(0) = 0` (no inertia injection at start)
- `Δω_filt(0) = 0`
- `dω/dt_filt(0) = 0`
Pastikan IC di Simulink Integrator/Filter blocks di-set.

### 10.3 Numerical Differentiation untuk RoCoF
Julia: forward Euler `(omega(k) - omega(k-1)) / dt`.
MATLAB Simulink: pakai **Discrete Derivative** dengan sample time 50e-6 (sama). Atau **Filtered Derivative** dengan low-pass tau 20 ms (matches T_meas Julia).

### 10.4 PV Array Block vs Custom
Block Simscape PV Array sudah include I-V solver. Cocokkan datasheet jadi:
- `Voc_module` = 600 / 10 = 60 V (10 module series @ 60 V Voc)
- `Isc_module` = 8.21 A
- `Vmp_module` ≈ 35 V (perlu kalibrasi)
- `Imp_module` ≈ 7.5 A
Kalau PV array block bikin Pmpp tidak match Julia (off > 5%), pakai custom dari `single_diode_iv.m`.

### 10.5 Solver Pilihan
- `ode4` (RK4) fixed-step 50 µs → matches Julia explicit Euler-ish behavior, tapi lebih akurat.
- `ode23tb` adaptive stiff → cepat tapi step variable, harus interpolate ke 1 ms uniform untuk RMSE compare.
**Rekomendasi:** `ode4` fixed 50 µs.

### 10.6 Setiap Mismatch ≥ 2%
Selalu cek dulu **sign + scaling** sebelum debug control logic:
- Skala unit (rad/s vs Hz, W vs kW, pu vs absolute)
- Sign convention (P injection direction)
- Sample time block-vs-block

---

## 11. Status Tracking

| Sub-task | Owner | Status |
|---|---|---|
| SPEC dokumen ini | Claude | ✅ done |
| Regen `results/raw/*.jld2` | Claude (run julia) | ⏳ |
| MATLAB package skeleton (`.m` files) | Claude (write) | ⏳ |
| `.slx` build manual | User | ⏳ |
| Run S1, S3 di MATLAB | User | ⏳ |
| Export CSV ke `data/simulink_ref/` | User | ⏳ |
| Notebook overlay + RMSE | Claude | ⏳ |
| `docs/validation_simulink.md` | Claude (write) | ⏳ |
| Paper #1 Sec II.B/VI.D + Appendix A | Claude (edit) | ⏳ |

---

*Dokumen kerja sesi 2026-05-02. Sumber otoritatif untuk porting Julia → Simulink Paper #1.*

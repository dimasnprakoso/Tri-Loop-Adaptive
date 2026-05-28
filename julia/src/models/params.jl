@with_kw struct SystemParams
    # Ratings
    P_rated::Float64        = 125e3        # W
    V_dc_ref::Float64       = 1200.0       # V
    f0::Float64             = 50.0         # Hz
    omega0::Float64         = 2pi*50.0     # rad/s

    # PV (single-diode, equivalent module-string)
    Iph_stc::Float64        = 8.21         # A photocurrent at STC per string
    I0::Float64             = 2.5e-10      # A diode saturation
    Rs::Float64             = 0.221        # ohm
    Rsh::Float64            = 415.405      # ohm
    a::Float64              = 1.3          # diode ideality factor
    Vt_stc::Float64         = 0.02585      # kT/q at 25°C
    Ns::Float64             = 60.0         # cells in series per module
    # Calibrated 2026-05-01: 38 strings × 10 modules ≈ 125 kW @ STC
    Np_strings::Float64     = 38.0         # parallel strings
    Ns_modules::Float64     = 10.0         # modules in series per string
    G_stc::Float64          = 1000.0       # W/m2
    T_stc::Float64          = 25.0         # °C
    Ki::Float64             = 0.0032       # %/°C temp coeff Isc
    Kv::Float64             = -0.123       # %/°C temp coeff Voc

    # BESS
    E_rated_kWh::Float64    = 50.0         # kWh
    eta_ch::Float64         = 0.95
    eta_dis::Float64        = 0.95
    SOC_min::Float64        = 0.20
    SOC_max::Float64        = 0.90
    SOC_init::Float64       = 0.60
    P_bess_max::Float64     = 60e3         # W

    # Inverter (averaged, three-phase)
    L_filter::Float64       = 0.7e-3       # H
    R_filter::Float64       = 0.05         # ohm
    C_dc::Float64           = 5e-3         # F
    Kp_idq::Float64         = 66.58        # current-loop PI (from existing Simulink)
    Ki_idq::Float64         = 13316.5
    Kp_vdc::Float64         = 1.5
    Ki_vdc::Float64         = 50.0

    # PLL (SOFI / SRF-PLL)
    Kp_pll::Float64         = 92.0
    Ki_pll::Float64         = 4232.0
    omega_n_pll_max::Float64 = 2pi*50.0
    SCR_thr::Float64        = 2.0          # below this PLL is detuned

    # VIC (adaptive virtual inertia & damping)
    # Calibration round 2 (2026-05-01): adaptasi sebelumnya dinormalisasi ke ω0=314
    # rad/s sehingga argumen tanh ~0.025 untuk RoCoF 0.5 Hz/s → tanh hampir linear,
    # H_t ≈ H_min selalu (C1≈C3 di metrik). Pindah ke skala disturbance (RoCoF
    # 0.5 Hz/s, Δf 0.2 Hz) supaya tanh saturasi pada event sedang.
    H_min::Float64          = 1.0          # s
    H_max::Float64          = 5.0          # s — agresif untuk S4 high-IBR
    D_min::Float64          = 12.0
    D_max::Float64          = 50.0
    gamma_J::Float64        = 1.0          # dω/dt sensitivity (skala via ω̇_ref)
    delta_D::Float64        = 1.0          # Δω sensitivity (skala via ω_ref)
    omega_dot_ref::Float64  = 2pi*1.0      # tanh saturate at RoCoF 1.0 Hz/s
    omega_ref_vic::Float64  = 2pi*0.3      # tanh saturate at Δf 0.3 Hz
    T_filter_omega::Float64 = 0.05
    T_lead_RoCoF::Float64   = 0.05
    T_lag_droop::Float64    = 0.7
    P_vic_max::Float64      = 0.5*125e3    # W (±0.5 pu)

    # Adaptive coordination weights
    k_alpha::Float64        = 4.0
    k_alpha_rocof::Float64  = 1.0
    beta_max::Float64       = 0.7          # BESS share — naikkan untuk S2 cloud
    Δω_dead::Float64        = 2pi*0.02     # 0.02 Hz dead-band

    # Grid (Thevenin)
    V_grid::Float64         = 400.0        # V line-line RMS
    SCR::Float64            = 5.0          # short-circuit ratio
    X_R::Float64            = 7.0          # X/R ratio

    # Solver
    Ts_control::Float64     = 50e-6        # 50 µs
    Ts_supervisor::Float64  = 1e-3
end

default_params() = SystemParams()

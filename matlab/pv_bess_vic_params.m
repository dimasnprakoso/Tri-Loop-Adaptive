function params = pv_bess_vic_params()
% PV_BESS_VIC_PARAMS  Mirror dari julia/src/models/params.jl
%   Sumber otoritatif: docs/spec_simulink.md Section 2

    % --- Ratings ---
    params.P_rated  = 125e3;      % [W]
    params.V_dc_ref = 1200;       % [V]
    params.f0       = 50;         % [Hz]
    params.omega0   = 2*pi*50;    % [rad/s]

    % --- PV (38p × 10s array) ---
    params.Iph_stc    = 8.21;       % [A/string]
    params.I0         = 2.5e-10;    % [A]
    params.Rs         = 0.221;      % [Ohm]
    params.Rsh        = 415.405;    % [Ohm]
    params.a          = 1.3;        % idealitas
    params.Ns         = 60;         % sel/modul
    params.Ns_modules = 10;         % modul series per string
    params.Np_strings = 38;         % string parallel
    params.G_stc      = 1000;       % [W/m^2]
    params.T_stc      = 25;         % [degC]
    params.Ki         = 0.0032;     % [1/degC]
    params.Kv         = -0.123;     % [1/degC]

    % --- BESS ---
    params.E_rated_J   = 50 * 3.6e6;  % 50 kWh -> J
    params.eta_ch      = 0.95;
    params.eta_dis     = 0.95;
    params.SOC_min     = 0.20;
    params.SOC_max     = 0.90;
    params.SOC_init    = 0.60;
    params.P_bess_max  = 60e3;        % [W]

    % --- Inverter & PLL ---
    params.L_filter = 0.7e-3;     % [H]
    params.R_filter = 0.05;       % [Ohm]
    params.C_dc     = 5e-3;       % [F]
    params.Kp_idq   = 66.58;
    params.Ki_idq   = 13316.5;
    params.Kp_vdc   = 1.5;
    params.Ki_vdc   = 50.0;
    params.Kp_pll   = 92.0;
    params.Ki_pll   = 4232.0;
    params.SCR_thr  = 2.0;

    % --- VIC Adaptive ---
    params.H_min          = 1.0;        % [s]
    params.H_max          = 5.0;        % [s]
    params.D_min          = 12.0;       % [pu]
    params.D_max          = 50.0;       % [pu]
    params.gamma_J        = 1.0;
    params.delta_D        = 1.0;
    params.omega_dot_ref  = 2*pi*1.0;   % [rad/s^2] saturate @ 1 Hz/s
    params.omega_ref_vic  = 2*pi*0.3;   % [rad/s] saturate @ 0.3 Hz
    params.T_filter_omega = 0.05;       % [s]
    params.P_vic_max      = 0.5 * params.P_rated;  % [W]

    % --- Adaptive Coordination ---
    params.k_alpha        = 4.0;
    params.k_alpha_rocof  = 1.0;
    params.beta_max       = 0.7;
    params.domega_dead    = 2*pi*0.02;  % [rad/s] dead-band 0.02 Hz

    % --- Grid Thevenin ---
    params.V_grid = 400;          % [V] L-L RMS
    params.SCR    = 5.0;
    params.X_R    = 7.0;

    Z_pu          = 1 / params.SCR;
    X_pu          = Z_pu * params.X_R / sqrt(1 + params.X_R^2);
    R_pu          = X_pu / params.X_R;
    Z_base        = params.V_grid^2 / params.P_rated;
    params.R_grid = R_pu * Z_base;          % [Ohm]
    params.X_grid = X_pu * Z_base;          % [Ohm]
    params.L_grid = params.X_grid / params.omega0;  % [H]

    % --- Solver ---
    params.dt            = 50e-6;        % [s] control timestep
    params.Ts_supervisor = 1e-3;         % [s] BESS supervisor (20x slower)
    params.Ts_log        = 1e-3;         % [s] output downsampling
end

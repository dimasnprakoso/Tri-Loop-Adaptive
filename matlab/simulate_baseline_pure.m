function sol = simulate_baseline_pure(params, tspan, G_profile, T_profile, ...
                                       P_load_profile, H_sys, D_sys, flags)
% SIMULATE_BASELINE_PURE  Pure-MATLAB averaged-model loop
%   Mirror 1-to-1 dari julia/src/models/system_average.jl simulate_baseline().
%
%   Validasi silang pure-MATLAB vs Julia: catch numerical bugs (precision,
%   library, indexing). Switching-level Simscape Electrical bisa ditambah
%   nanti sebagai Stage-2 validation untuk paper revision.
%
% Inputs:
%   params         : pv_bess_vic_params() struct
%   tspan          : [t_start, t_end] [s]
%   G_profile      : function handle G(t) [W/m^2]
%   T_profile      : function handle T_c(t) [degC]
%   P_load_profile : function handle P_load(t) [W]
%   H_sys, D_sys   : grid inertia/damping
%   flags          : struct .use_vic, .use_adaptive_vic, .use_fuzzy_vic,
%                            .use_adaptive_coord, .use_bess
%
% Output:
%   sol            : struct with fields t, f, rocof, Pmppt, Pvic, Pref,
%                    Pgrid, Pbess, SOC, alpha, beta, H

    dt = params.dt;
    N  = round((tspan(2) - tspan(1)) / dt) + 1;
    ts = linspace(tspan(1), tspan(2), N);

    % --- State variables ---
    vic.P_filt   = 0;
    bess.SOC     = params.SOC_init;
    bess.P_bess  = 0;
    grid.omega    = params.omega0;
    grid.domegadt = 0;
    grid.P_load   = P_load_profile(0);

    % Filter states untuk frequency measurement (T_meas = 20 ms)
    Delta_omega_filt = 0;
    domega_dt_filt   = 0;
    T_meas           = 0.02;

    % MPP cache
    G_cache  = -1.0;
    Tc_cache = -1000.0;
    P_mpp_cache = 0;

    % Supervisor downsample
    sup_step = round(params.Ts_supervisor / dt);

    % --- Logs ---
    f_log     = zeros(1, N);
    rocof_log = zeros(1, N);
    Pmppt_log = zeros(1, N);
    Pvic_log  = zeros(1, N);
    Pref_log  = zeros(1, N);
    Pgrid_log = zeros(1, N);
    Pbess_log = zeros(1, N);
    SOC_log   = zeros(1, N);
    alpha_log = zeros(1, N);
    beta_log  = zeros(1, N);
    H_log     = zeros(1, N);

    P_bess = 0;

    % --- Main loop (explicit Euler, dt = Ts_control = 50 us) ---
    for k = 1:N
        tk = ts(k);
        G  = G_profile(tk);
        T_c = T_profile(tk);

        % MPP cache: recompute hanya jika ΔG > 1 W/m² atau ΔTc > 0.5 °C
        if abs(G - G_cache) > 1.0 || abs(T_c - Tc_cache) > 0.5
            P_mpp = pv_mpp(G, T_c, params);
            P_mpp_cache = max(min(P_mpp, params.P_rated * 1.1), 0);
            G_cache = G;
            Tc_cache = T_c;
        end
        P_mppt = P_mpp_cache;

        % Frequency state + measurement filter
        Delta_omega_raw = grid.omega - params.omega0;
        domega_dt_raw   = grid.domegadt;
        alpha_m = dt / (T_meas + dt);
        Delta_omega_filt = (1 - alpha_m) * Delta_omega_filt + alpha_m * Delta_omega_raw;
        domega_dt_filt   = (1 - alpha_m) * domega_dt_filt   + alpha_m * domega_dt_raw;
        Delta_omega = Delta_omega_filt;
        domega_dt   = domega_dt_filt;

        % VIC control
        if ~flags.use_vic
            P_vic = 0;
            H_eff = 0;
        elseif flags.use_adaptive_vic
            [P_vic, H_eff, ~, vic.P_filt] = vic_adaptive(Delta_omega, domega_dt, ...
                                                         vic.P_filt, params);
        else
            % Constant-gain VIC (C1)
            P_raw = -(2 * params.H_min / params.omega0 * domega_dt + ...
                      params.D_min * Delta_omega / params.omega0) * params.P_rated;
            alpha_filt = dt / (params.T_filter_omega + dt);
            vic.P_filt = (1 - alpha_filt) * vic.P_filt + alpha_filt * P_raw;
            P_vic = max(min(vic.P_filt, params.P_vic_max), -params.P_vic_max);
            H_eff = params.H_min;
        end

        % BESS supervisor (slower loop, 1 ms)
        if flags.use_bess && mod(k, sup_step) == 0
            [~, P_cmd] = bess_supervisor(Delta_omega, domega_dt, P_mppt, ...
                                          grid.P_load, bess.SOC, params);
            bess = bess_dynamics(bess, P_cmd, params, params.Ts_supervisor);
        end
        if flags.use_bess
            P_bess = bess.P_bess;
        else
            P_bess = 0;
        end

        % Adaptive coordination
        if flags.use_adaptive_coord
            [P_ref, alpha_w, beta_w] = adaptive_coord(P_mppt, P_vic, P_bess, ...
                                                      Delta_omega, domega_dt, ...
                                                      bess.SOC, params);
        else
            P_ref = P_mppt + P_vic + P_bess;
            alpha_w = 1; beta_w = 1;
        end

        % Ideal current loop
        P_inj = max(min(P_ref, 1.2 * params.P_rated), -1.2 * params.P_rated);

        % Grid swing equation
        grid = grid_step(grid, P_inj, P_load_profile(tk), H_sys, D_sys, params, dt);

        % Logs
        f_log(k)     = grid.omega / (2*pi);
        rocof_log(k) = grid.domegadt / (2*pi);
        Pmppt_log(k) = P_mppt;
        Pvic_log(k)  = P_vic;
        Pref_log(k)  = P_ref;
        Pgrid_log(k) = P_inj;
        Pbess_log(k) = P_bess;
        SOC_log(k)   = bess.SOC;
        alpha_log(k) = alpha_w;
        beta_log(k)  = beta_w;
        H_log(k)     = H_eff;
    end

    sol.t      = ts(:);
    sol.f      = f_log(:);
    sol.rocof  = rocof_log(:);
    sol.Pmppt  = Pmppt_log(:);
    sol.Pvic   = Pvic_log(:);
    sol.Pref   = Pref_log(:);
    sol.Pgrid  = Pgrid_log(:);
    sol.Pbess  = Pbess_log(:);
    sol.SOC    = SOC_log(:);
    sol.alpha  = alpha_log(:);
    sol.beta   = beta_log(:);
    sol.H      = H_log(:);
end

function [P_ref, Q_ref, V_dc_ref, P_bess_cmd, alpha, beta, H_eff, P_vic] = ...
    control_logic(f_meas, rocof_meas, V_pv, I_pv, P_load, SOC)
% CONTROL_LOGIC  Top-level orchestrator (untuk MATLAB Function block di Simulink)
%   Sumber: docs/spec_simulink.md Section 5.2
%
% Persistent state untuk MPPT P&O dan VIC filter.
%
% Inputs (semua scalar dari plant_meas bus):
%   f_meas, rocof_meas : frequency [Hz], RoCoF [Hz/s]
%   V_pv, I_pv         : PV terminal V [V], current [A]
%   P_load             : load demand [W]
%   SOC                : battery SOC [0,1]
%
% Outputs (ke plant control inputs):
%   P_ref, Q_ref       : inverter power refs [W, VAR]
%   V_dc_ref           : DC-link reference [V]
%   P_bess_cmd         : BESS converter command [W]
%   alpha, beta        : telemetry weights [pu]
%   H_eff              : effective inertia [s]
%   P_vic              : virtual inertia power [W] (untuk logging)

    %#codegen
    persistent params P_filt V_pv_ref P_prev

    if isempty(params)
        params   = pv_bess_vic_params();
        P_filt   = 0;
        V_pv_ref = 350;
        P_prev   = 0;
    end

    % Frequency deviation
    domega    = 2*pi*f_meas - params.omega0;
    domega_dt = 2*pi*rocof_meas;

    % MPPT
    [P_mppt, V_pv_ref] = mppt_po(V_pv, I_pv, V_pv_ref, P_prev, 1.0);
    P_prev = P_mppt;

    % VIC adaptive
    [P_vic, H_eff, ~, P_filt] = vic_adaptive(domega, domega_dt, P_filt, params);

    % BESS supervisor (NB: sample time block ini harus 1e-3 untuk match Julia)
    [~, P_bess_cmd] = bess_supervisor(domega, domega_dt, P_mppt, P_load, SOC, params);

    % Coordination
    [P_ref, alpha, beta] = adaptive_coord(P_mppt, P_vic, P_bess_cmd, ...
                                           domega, domega_dt, SOC, params);

    Q_ref    = 0;
    V_dc_ref = params.V_dc_ref;
end

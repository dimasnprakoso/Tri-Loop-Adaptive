function [mode, P_bess_cmd] = bess_supervisor(domega, domega_dt, P_pv, P_load, SOC, params)
% BESS_SUPERVISOR  4-mode state machine (IDLE/DISCHARGE/CHARGE/STANDBY)
%   Sumber: julia/src/models/bess_supervisor.jl
%
% Mode encoding: 0=IDLE, 1=DISCHARGE, 2=CHARGE, 3=STANDBY

    domega_dead = 2*pi*0.02;     % 0.02 Hz dead-band
    rocof_dead  = 2*pi*0.05;     % 0.05 Hz/s dead-band

    % --- 1. STANDBY (SOC limit protection) ---
    if (SOC <= params.SOC_min + 0.02) || ...
       (SOC >= params.SOC_max - 0.02 && P_pv > P_load)
        mode = 3;
        P_bess_cmd = 0;
        return;
    end

    % --- 2. Normal operation (no freq event) ---
    if abs(domega) < domega_dead && abs(domega_dt) < rocof_dead
        if P_pv > P_load && SOC < params.SOC_max
            mode = 2;  % CHARGE (absorb surplus)
            P_bess_cmd = -min(params.P_bess_max, P_pv - P_load);
        else
            mode = 0;  % IDLE
            P_bess_cmd = 0;
        end
        return;
    end

    % --- 3. Frequency event response ---
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
        mode = 3;  % STANDBY (tidak bisa support, SOC limit)
        P_bess_cmd = 0;
    end
end

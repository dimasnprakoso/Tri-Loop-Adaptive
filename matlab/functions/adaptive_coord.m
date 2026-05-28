function [P_ref, alpha, beta] = adaptive_coord(P_mppt, P_vic, P_bess_avail, ...
                                                domega, domega_dt, SOC, params)
% ADAPTIVE_COORD  Combine MPPT + VIC + BESS dengan weight α, β
%   Sumber: julia/src/models/adaptive_coord.jl
%
% α = telemetry weight (MPPT priority), tidak menggating P_vic
% β = BESS share weight (gated SOC + severity)

    % --- α (telemetry) ---
    if abs(domega) > params.domega_dead
        domega_eff = domega;
    else
        domega_eff = 0;
    end
    alpha = 1.0 / (1.0 + params.k_alpha * abs(domega_eff) + ...
                   params.k_alpha_rocof * abs(domega_dt));

    % --- β (BESS share) ---
    if SOC < params.SOC_min || SOC > params.SOC_max
        beta = 0;
    else
        SOC_nom = 0.5 * (params.SOC_min + params.SOC_max);
        soc_headroom = 1.0 - 2*abs(SOC - SOC_nom) / (params.SOC_max - params.SOC_min);
        sev = max(abs(domega) / params.omega_ref_vic, ...
                  abs(domega_dt) / params.omega_dot_ref);
        beta = params.beta_max * soc_headroom * tanh(sev);
    end

    % --- Final reference ---
    P_ref = P_mppt + P_vic + beta * P_bess_avail;
    P_ref = max(min(P_ref, 1.5*params.P_rated), -1.5*params.P_rated);
end

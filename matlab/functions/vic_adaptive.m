function [P_vic, H_t, D_t, P_filt_new] = vic_adaptive(domega, domega_dt, P_filt_prev, params)
% VIC_ADAPTIVE  Adaptive Virtual Inertia Control (tanh-saturated H, D)
%   Sumber: julia/src/models/vic_adaptive.jl
%
% Inputs:
%   domega      : Δω = ω - ω0 [rad/s]
%   domega_dt   : dω/dt        [rad/s^2]
%   P_filt_prev : filter state [W]
%   params      : struct dari pv_bess_vic_params()
%
% Outputs:
%   P_vic       : virtual inertia power [W]
%   H_t         : effective inertia    [s]
%   D_t         : effective damping    [pu]
%   P_filt_new  : updated filter state [W]

    % Adaptive gains (tanh saturation @ disturbance scale)
    H_t = params.H_min + (params.H_max - params.H_min) * ...
          tanh(params.gamma_J * abs(domega_dt) / params.omega_dot_ref);
    D_t = params.D_min + (params.D_max - params.D_min) * ...
          tanh(params.delta_D * abs(domega) / params.omega_ref_vic);

    % Swing-equation form
    P_raw = -(2 * H_t / params.omega0 * domega_dt + ...
              D_t * domega / params.omega0) * params.P_rated;

    % First-order low-pass filter (T = T_filter_omega)
    alpha_filt = params.dt / (params.T_filter_omega + params.dt);
    P_filt_new = (1 - alpha_filt) * P_filt_prev + alpha_filt * P_raw;

    % Saturate at ±P_vic_max
    P_vic = max(min(P_filt_new, params.P_vic_max), -params.P_vic_max);
end

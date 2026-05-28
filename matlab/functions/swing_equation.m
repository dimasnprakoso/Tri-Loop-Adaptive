function domega_dt = swing_equation(P_inj, P_load, omega, H_sys, D_sys, params)
% SWING_EQUATION  Single-area frequency dynamics
%   Sumber: julia/src/models/grid_thevenin.jl
%
% State: omega [rad/s] (integrated externally di Simulink)
% Output: domega/dt [rad/s^2]

    domega = omega - params.omega0;
    dP_pu  = (P_inj - P_load) / params.P_rated;

    domega_dt = (dP_pu - D_sys * domega / params.omega0) * ...
                params.omega0 / (2 * H_sys);
end

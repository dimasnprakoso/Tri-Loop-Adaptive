function I_array = single_diode_iv(V, G, T_c, params)
% SINGLE_DIODE_IV  Solve single-diode equation untuk PV array
%   Sumber: julia/src/models/pv_diode.jl
%
% Inputs:
%   V       : terminal voltage (DC-link reference) [V]
%   G       : irradiance                            [W/m^2]
%   T_c     : cell temperature                      [degC]
%   params  : struct dari pv_bess_vic_params()
%
% Output:
%   I_array : array current (positive = injection)  [A]

    if G <= 10
        I_array = 0;
        return;
    end

    T_k = T_c + 273.15;
    Iph = (params.Iph_stc + params.Ki * (T_c - params.T_stc)) * G / params.G_stc;
    Vt  = params.a * params.Ns * 1.380649e-23 * T_k / 1.602176634e-19;

    % Residual: I - Iph + I0*(exp((V+I*Rs)/(Ns*Vt)) - 1) + (V+I*Rs)/(Ns*Rsh) = 0
    f = @(I) I - Iph + ...
            params.I0 * (exp((V + I*params.Rs) / (params.Ns*Vt)) - 1) ...
            + (V + I*params.Rs) / (params.Ns*params.Rsh);

    try
        I_string = fzero(f, [0, Iph * 1.5]);
    catch
        I_string = 0;  % fallback jika no convergence
    end

    I_array = I_string * params.Np_strings;
end

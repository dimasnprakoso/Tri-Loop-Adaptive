function [P_mppt, V_pv_ref] = mppt_po(V_pv, I_pv, V_pv_ref_prev, P_prev, dV_step)
% MPPT_PO  Perturb & Observe MPPT
%   Note: Julia pakai grid-search 80-point untuk MPP cache; di MATLAB lebih
%   bersih pakai P&O. Untuk S1/S3 (G konstan), hasil ekuivalen di steady-state.
%
% Inputs:
%   V_pv          : tegangan PV terukur     [V]
%   I_pv          : arus PV terukur         [A]
%   V_pv_ref_prev : tegangan setpoint prev  [V]
%   P_prev        : power sebelumnya        [W]
%   dV_step       : step perturbation       [V]
%
% Outputs:
%   P_mppt        : power saat ini          [W]
%   V_pv_ref      : tegangan setpoint baru  [V]

    P_now = V_pv * I_pv;
    dP    = P_now - P_prev;
    dV    = V_pv - (V_pv_ref_prev - dV_step);

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

    % Clamp ke range valid (Voc array ≈ 600 V, Vmp ≈ 350 V)
    V_pv_ref = max(min(V_pv_ref, 450), 250);
    P_mppt   = P_now;
end

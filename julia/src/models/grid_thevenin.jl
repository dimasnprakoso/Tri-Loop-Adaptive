"""
Thevenin grid equivalent + simple frequency dynamics.

Frequency model (single-area, per-unit on system base):
    2H_sys * dΔω/dt = ΔP_gen - ΔP_load - D_sys*Δω

The PV-BESS injection contributes to ΔP_gen through P_inj.
Disturbances are injected via P_load (step) or P_gen_loss.
"""
@with_kw mutable struct GridState
    omega::Float64 = 2pi*50.0
    domegadt::Float64 = 0.0
    P_load::Float64 = 80e3
end

function grid_step!(s::GridState, P_inj::Float64, P_load_now::Float64,
                    H_sys::Float64, D_sys::Float64, p::SystemParams;
                    dt::Float64=p.Ts_control)
    Δω = s.omega - p.omega0
    ΔP = (P_inj - P_load_now) / p.P_rated
    s.domegadt = (ΔP - D_sys*Δω/p.omega0) * p.omega0 / (2*H_sys)
    s.omega += s.domegadt * dt
    s.P_load = P_load_now
    return s.omega, s.domegadt
end

"""Z_th from SCR and X/R ratio (per unit on rated base)."""
function thevenin_impedance(p::SystemParams)
    Z_pu = 1.0 / p.SCR
    X_pu = Z_pu * p.X_R / sqrt(1 + p.X_R^2)
    R_pu = X_pu / p.X_R
    Zbase = (p.V_grid^2)/p.P_rated
    return (R = R_pu*Zbase, X = X_pu*Zbase)
end

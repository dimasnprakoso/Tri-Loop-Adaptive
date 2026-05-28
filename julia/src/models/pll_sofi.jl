"""
SRF-PLL (Synchronous Reference Frame Phase-Locked Loop) with optional
adaptive bandwidth as a function of estimated short-circuit ratio (SCR).

States: ω_pll, θ_pll, integrator i_pll
Inputs: vd, vq (already in dq)
"""
@with_kw mutable struct PLLState
    omega_pll::Float64 = 2pi*50.0
    theta_pll::Float64 = 0.0
    i_pll::Float64     = 0.0
end

function pll_dynamics!(s::PLLState, vq::Float64, p::SystemParams,
                       SCR_est::Float64; dt::Float64=p.Ts_control)
    # adaptive bandwidth: detune in weak grids
    bw_scale = clamp(SCR_est / p.SCR_thr, 0.2, 1.0)
    Kp = p.Kp_pll * bw_scale
    Ki = p.Ki_pll * bw_scale^2

    err = -vq    # in steady state vq=0 means locked
    s.i_pll += Ki * err * dt
    s.omega_pll = p.omega0 + Kp * err + s.i_pll
    s.theta_pll += s.omega_pll * dt
    s.theta_pll = mod(s.theta_pll, 2pi)
    return s.omega_pll, s.theta_pll
end

"""
Adaptive Virtual Inertia Control.

Outputs the active-power adjustment P_vic [W] in response to frequency
deviation Δω [rad/s] and rate of change dω/dt.

Inertia and damping gains are NOT constant — they adapt to disturbance
severity (key novelty over Tian et al. 2023 which used constant-output
adaptive logic only on damping):

    H(t) = H_min + (H_max - H_min) * tanh(γ_J * |dω/dt| / ω0)
    D(t) = D_min + (D_max - D_min) * tanh(δ_D * |Δω|   / ω0)

The synchronous-machine swing-equation analogue gives:

    P_vic = -[ 2H(t)/ω0 * dω/dt + D(t) * Δω/ω0 ] * P_rated

with output filtered (Tdi lead, Tri lag) and saturated to ±P_vic_max.
"""
@with_kw mutable struct AdaptiveVICState
    P_filt::Float64 = 0.0   # post-filter output
    Δω_lp::Float64  = 0.0   # low-pass of Δω for derivative estimation
end

function vic_output(Δω::Float64, dωdt::Float64, p::SystemParams,
                    s::AdaptiveVICState; dt::Float64=p.Ts_control)
    # adaptive gains — tanh dinormalisasi ke RoCoF/Δf tipikal supaya saturasi
    # tercapai pada event sedang (bukan ke ω0 yang membuat arg<0.05 dan H_t≈H_min)
    H_t = p.H_min + (p.H_max - p.H_min) * tanh(p.gamma_J * abs(dωdt) / p.omega_dot_ref)
    D_t = p.D_min + (p.D_max - p.D_min) * tanh(p.delta_D * abs(Δω)   / p.omega_ref_vic)

    # raw VIC contribution (negative sign: counteract deviation)
    P_raw = -(2*H_t/p.omega0 * dωdt + D_t * Δω/p.omega0) * p.P_rated

    # first-order shaping filter (T_lead RoCoF + T_lag droop) approximated
    # as a single low-pass (T_filter_omega) for the explicit Euler step
    α_filt = dt / (p.T_filter_omega + dt)
    s.P_filt = (1 - α_filt) * s.P_filt + α_filt * P_raw

    # saturation
    P_out = clamp(s.P_filt, -p.P_vic_max, p.P_vic_max)
    return P_out, (H=H_t, D=D_t)
end

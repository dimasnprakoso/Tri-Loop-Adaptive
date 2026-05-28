"""
Energy-only BESS model: SOC dynamics with separate charge/discharge efficiency.

dSOC/dt = -P_bess / E_rated         (for sign convention: P_bess>0 = discharge)
with energy-aware efficiency:
    if discharging: dSOC/dt = -P_bess / (η_dis * E_rated)
    if charging:    dSOC/dt = -η_ch * P_bess / E_rated   (P_bess<0)

P_bess is hard-clipped to ±P_bess_max and gated by SOC limits.
"""
@with_kw mutable struct BessState
    SOC::Float64
    P_bess::Float64 = 0.0
end

function bess_dynamics!(s::BessState, P_cmd::Float64, p::SystemParams; dt::Float64=p.Ts_supervisor)
    # SOC limits → gate command
    P = clamp(P_cmd, -p.P_bess_max, p.P_bess_max)
    if P > 0 && s.SOC <= p.SOC_min
        P = 0.0
    elseif P < 0 && s.SOC >= p.SOC_max
        P = 0.0
    end
    s.P_bess = P
    E_J = p.E_rated_kWh * 3.6e6
    if P >= 0
        dSOC = -P / (p.eta_dis * E_J)
    else
        dSOC = -p.eta_ch * P / E_J
    end
    s.SOC = clamp(s.SOC + dSOC*dt, 0.0, 1.0)
    return s.P_bess, s.SOC
end

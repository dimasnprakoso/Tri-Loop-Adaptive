"""
Rule-based BESS supervisor with adaptive set-point.

States:
  IDLE       — within freq dead-band & SOC mid-range
  DISCHARGE  — Δω<0 (under-frequency) and SOC>SOC_min, supports inertia
  CHARGE     — Δω>0 or P_pv > P_load proxy and SOC<SOC_max
  STANDBY    — SOC at limits, command zero
"""
@enum BessMode IDLE DISCHARGE CHARGE STANDBY

function bess_supervisor(Δω::Float64, dωdt::Float64, P_pv::Float64,
                         P_load::Float64, SOC::Float64, p::SystemParams)
    if SOC <= p.SOC_min + 0.02
        return (mode=STANDBY, P_cmd=0.0)
    elseif SOC >= p.SOC_max - 0.02 && P_pv > P_load
        return (mode=STANDBY, P_cmd=0.0)
    end

    if abs(Δω) < p.Δω_dead && abs(dωdt) < 2pi*0.05
        # not a frequency event
        if P_pv > P_load && SOC < p.SOC_max
            P_cmd = -min(p.P_bess_max, P_pv - P_load)
            return (mode=CHARGE, P_cmd=P_cmd)
        else
            return (mode=IDLE, P_cmd=0.0)
        end
    end

    # frequency event → support
    P_support = -p.P_bess_max * tanh(2*Δω/(2pi*0.5) + 0.5*dωdt/(2pi*0.5))
    if P_support > 0 && SOC > p.SOC_min
        return (mode=DISCHARGE, P_cmd=P_support)
    elseif P_support < 0 && SOC < p.SOC_max
        return (mode=CHARGE, P_cmd=P_support)
    else
        return (mode=STANDBY, P_cmd=0.0)
    end
end

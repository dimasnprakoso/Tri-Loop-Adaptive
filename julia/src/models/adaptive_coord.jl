"""
Adaptive Coordination of MPPT, VIC and BESS.

Forms the final active-power reference fed to the inverter current loop:

    α = 1 / (1 + k_α |Δω| + k_α' |dω/dt|)
    β = β_max * sigmoid(SOC_dev) * sat(|RoCoF|)
    P_ref = α P_mppt + (1-α) P_vic + β P_bess_avail

Returns a NamedTuple with P_ref and the internal weights for logging.
"""
function alpha_weight(Δω::Float64, dωdt::Float64, p::SystemParams)
    # dead-band: ignore tiny deviations to avoid chattering
    Δω_eff = abs(Δω) > p.Δω_dead ? Δω : 0.0
    return 1.0 / (1.0 + p.k_alpha * abs(Δω_eff) + p.k_alpha_rocof * abs(dωdt))
end

"""
β scales BESS contribution by disturbance severity dan SOC headroom.
- Disturbance severity diukur dengan max( |Δω|/Δω_sat, |dωdt|/ω̇_sat ) sehingga
  cloud-passing (RoCoF moderate, Δω besar) sama-sama membuka β penuh, tidak
  hanya event step-loss yang RoCoF tinggi.
- SOC harus dalam [SOC_min, SOC_max]; di luar → β=0 untuk proteksi baterai.
"""
function beta_share(SOC::Float64, Δω::Float64, dωdt::Float64, p::SystemParams)
    (SOC < p.SOC_min || SOC > p.SOC_max) && return 0.0
    soc_headroom = 1.0 - 2*abs(SOC - 0.5*(p.SOC_min + p.SOC_max)) / (p.SOC_max - p.SOC_min)
    # severity index: gunakan komponen mana saja yang lebih dominan
    sev = max(abs(Δω) / p.omega_ref_vic, abs(dωdt) / p.omega_dot_ref)
    return p.beta_max * soc_headroom * tanh(sev)
end

"""
P_ref = P_mppt + P_vic + β·P_bess

VIC sudah self-gating via dead-band Δω_dead di vic_output (P_vic≈0 saat steady).
Faktor (1-α) yang lama justru meng-mute VIC selama 20 ms window kritis pasca-fault
karena α dihitung dari Δω filtered — dihilangkan untuk respons instan. α tetap
dilaporkan untuk telemetry (hubungan antara MPPT/VIC priority masih bermakna
pada fitur-fitur lain seperti curtailment headroom di Fase 6).
"""
function adaptive_coord(P_mppt::Float64, P_vic::Float64, P_bess_avail::Float64,
                        Δω::Float64, dωdt::Float64, SOC::Float64,
                        p::SystemParams)
    α = alpha_weight(Δω, dωdt, p)
    β = beta_share(SOC, Δω, dωdt, p)
    P_ref = P_mppt + P_vic + β*P_bess_avail
    P_ref = clamp(P_ref, -1.5*p.P_rated, 1.5*p.P_rated)
    return (P_ref=P_ref, alpha=α, beta=β)
end

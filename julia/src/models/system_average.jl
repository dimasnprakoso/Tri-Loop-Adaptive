"""
AGC (Automatic Generation Control) state for secondary frequency
restoration. Models a single-area integral controller that ramps a
bulk-grid resource to compensate frequency deviation, restoring f to
nominal over time constant tau_AGC. With tau_AGC = Inf, AGC is
disabled (baseline behaviour, primary droop only).

Non-ideal AGC features (defaults preserve idealised v1.0 behaviour):
  dead_band_Hz : if |Δf| ≤ dead_band_Hz, AGC integrator is frozen.
                  Models AGC dead-band per ENTSO-E LFC operational
                  guidelines (typical 10-20 mHz).
  rate_limit_pu_s : maximum |dP_AGC/dt| in per-unit/s. Models the
                    physical ramp rate of the dispatchable resource.
                    Default Inf = no limit (idealised).
  latency_s : telemetry / measurement / dispatch delay seen by AGC.
              Δf input is replaced by Δf at (t - latency_s). Default
              0.0 = no delay. The buffer is implemented as a
              FIFO of recent Δf samples sized to latency_s / dt.
"""
mutable struct AGCState
    P_AGC::Float64                # current AGC output, per-unit of P_rated
    enabled::Bool                 # AGC active flag (false until t >= t_event)
    t_event::Float64              # event time after which AGC integrates
    dead_band_Hz::Float64         # |Δf| < this → integrator frozen
    rate_limit_pu_s::Float64      # |dP_AGC/dt| upper bound (pu/s); Inf = none
    latency_s::Float64            # input Δf delayed by this; 0 = none
    Δf_buffer::Vector{Float64}    # FIFO buffer for delayed Δf
end
AGCState() = AGCState(0.0, false, 0.0, 0.0, Inf, 0.0, Float64[])
AGCState(P_AGC, enabled, t_event) =
    AGCState(P_AGC, enabled, t_event, 0.0, Inf, 0.0, Float64[])
AGCState(P_AGC, enabled, t_event, dead_band, rate_limit, latency) =
    AGCState(P_AGC, enabled, t_event, dead_band, rate_limit, latency,
             Float64[])

"""
Single AGC integration step with optional non-idealities.

Idealised path (defaults: dead-band 0, rate limit ∞, latency 0):
  dP_AGC/dt = -(1/tau) * (Δf / f0)

Non-ideal path:
  • Telemetry delay: Δf input is taken from `latency_s` ago (FIFO).
  • Dead-band: integrator frozen while |Δf_delayed| ≤ dead_band_Hz.
  • Rate limit: |dP_AGC/dt| ≤ rate_limit_pu_s.

For Δf in Hz and tau_AGC in seconds, P_AGC accumulates in per-unit of
P_rated. Returns AGC contribution in watts (positive = additional
generation, equivalently a reduction in net load seen by the grid).
"""
function agc_step!(agc::AGCState, Δf_Hz::Float64, t::Float64,
                   tau_AGC::Float64, p::SystemParams; dt::Float64=1e-3)
    if !agc.enabled || t < agc.t_event || isinf(tau_AGC)
        return 0.0
    end

    # Telemetry delay: FIFO buffer holds last ⌈latency/dt⌉ Δf samples.
    # When the buffer is full, the OLDEST sample is the delayed input.
    Δf_input = if agc.latency_s > 0.0
        n_buf = max(round(Int, agc.latency_s / dt), 1)
        push!(agc.Δf_buffer, Δf_Hz)
        if length(agc.Δf_buffer) > n_buf
            popfirst!(agc.Δf_buffer)
        end
        # If buffer not yet full, AGC has not yet seen any post-event input.
        length(agc.Δf_buffer) < n_buf ? 0.0 : agc.Δf_buffer[1]
    else
        Δf_Hz
    end

    # Dead-band: integrator frozen while |Δf_input| ≤ dead_band_Hz.
    if abs(Δf_input) <= agc.dead_band_Hz
        return agc.P_AGC * p.P_rated
    end

    # Ideal integrator increment, then rate-limit clamp on dP_AGC/dt.
    Δf_pu = Δf_input / p.f0
    dP = -(1.0 / tau_AGC) * Δf_pu * dt
    if isfinite(agc.rate_limit_pu_s)
        dP_max = agc.rate_limit_pu_s * dt
        dP = clamp(dP, -dP_max, dP_max)
    end
    agc.P_AGC += dP
    agc.P_AGC = clamp(agc.P_AGC, -0.5, 0.5)   # cap at ±50% rated
    return agc.P_AGC * p.P_rated
end

"""
Reduced-order **average** system model assembling PV+MPPT, AdaptiveVIC,
AdaptiveCoord, BESS supervisor, PLL and Thevenin grid into a single
discrete-time simulation loop. EMT switching is abstracted away — what
matters for VIC/coord research is the active/reactive power loop, which
this model captures with full fidelity.

Optional AGC layer (`tau_AGC::Float64`, `t_agc_enable::Float64`) models
secondary frequency restoration; with `tau_AGC=Inf` (default) AGC is
disabled and behaviour matches the baseline primary-droop-only model.

Returns time series suitable for `analysis/metrics.jl`.
"""
function simulate_baseline(p::SystemParams=default_params();
                            tspan=(0.0, 5.0),
                            G_profile=t->1000.0,
                            T_profile=t->25.0,
                            P_load_profile=t-> t<2.0 ? 80e3 : 95e3,   # 15 kW step at 2 s
                            H_sys::Float64=2.0,
                            D_sys::Float64=1.0,
                            use_vic::Bool=true,
                            use_adaptive_vic::Bool=true,
                            use_fuzzy_vic::Bool=false,
                            use_adaptive_coord::Bool=true,
                            use_bess::Bool=true,
                            tau_AGC::Float64=Inf,
                            t_agc_enable::Float64=2.0,
                            agc_dead_band_Hz::Float64=0.0,
                            agc_rate_limit_pu_s::Float64=Inf,
                            agc_latency_s::Float64=0.0,
                            SCR_grid::Float64=5.0,
                            SCR_ref::Float64=5.0,
                            use_thevenin_authority::Bool=false)
    dt = p.Ts_control
    N  = Int(round((tspan[2]-tspan[1])/dt)) + 1
    ts = collect(range(tspan[1], tspan[2]; length=N))

    # state
    vic   = AdaptiveVICState()
    bess  = BessState(SOC=p.SOC_init)
    pll   = PLLState()
    grid  = GridState()
    agc   = AGCState(0.0, !isinf(tau_AGC), t_agc_enable,
                     agc_dead_band_Hz, agc_rate_limit_pu_s,
                     agc_latency_s, Float64[])

    # filtered derivative of frequency for VIC/coord input — avoids
    # high-frequency numerical noise on dωdt in tight closed loop
    dωdt_filt = 0.0
    Δω_filt   = 0.0
    T_meas    = 0.02   # 20 ms measurement filter (typical PMU/PLL dynamics)

    # logs
    f_log    = zeros(N)
    rocof_log = zeros(N)
    Pmppt_log = zeros(N)
    Pvic_log  = zeros(N)
    Pref_log  = zeros(N)
    Pgrid_log = zeros(N)
    Pbess_log = zeros(N)
    SOC_log   = zeros(N)
    alpha_log = zeros(N)
    beta_log  = zeros(N)
    H_log     = zeros(N)
    Pagc_log  = zeros(N)

    # downsample supervisor at Ts_supervisor
    sup_step = Int(round(p.Ts_supervisor/dt))

    # MPP cache: pv_mpp pakai find_zero di internal yang mahal; saat G/Tc nyaris
    # konstan (skenario step-load) cukup hitung sekali. Recompute hanya jika
    # ΔG > 1 W/m² atau ΔTc > 0.5 °C — toleransi yang aman vs MPP shift physical.
    G_cache  = -1.0
    Tc_cache = -1000.0
    P_mpp_cache = 0.0

    P_bess = 0.0
    for k in 1:N
        tk = ts[k]
        G  = G_profile(tk)
        Tc = T_profile(tk)

        if abs(G - G_cache) > 1.0 || abs(Tc - Tc_cache) > 0.5
            mpp = pv_mpp(G, Tc, p)
            P_mpp_cache = clamp(mpp.P, 0.0, p.P_rated*1.1)
            G_cache = G; Tc_cache = Tc
        end
        P_mppt = P_mpp_cache

        # frequency state from grid + measurement filter
        # Filtered: dipakai untuk VIC gain (tanh) supaya noise tidak modulate H/D.
        # Raw: dipakai untuk α/β gating coord supaya respons instant tanpa
        # 20 ms delay yang bikin C4 under-respond di window kritis post-event.
        Δω_raw   = grid.omega - p.omega0
        dωdt_raw = grid.domegadt
        αm = dt / (T_meas + dt)
        Δω_filt   = (1-αm)*Δω_filt   + αm*Δω_raw
        dωdt_filt = (1-αm)*dωdt_filt + αm*dωdt_raw
        Δω   = Δω_filt
        dωdt = dωdt_filt

        # VIC — pilih skema berdasarkan flag (mutually exclusive)
        if !use_vic
            P_vic = 0.0
            H_log[k] = 0.0
        elseif use_fuzzy_vic
            P_vic, Hg = fuzzy_vic_output(Δω, dωdt, p, vic; dt=dt)
            H_log[k] = Hg.H
        elseif use_adaptive_vic
            P_vic, Hg = vic_output(Δω, dωdt, p, vic; dt=dt)
            H_log[k] = Hg.H
        else
            # Constant-gain VIC, same first-order filter for fair comparison
            P_raw = -(2*p.H_min/p.omega0 * dωdt + p.D_min * Δω/p.omega0) * p.P_rated
            α_filt = dt / (p.T_filter_omega + dt)
            vic.P_filt = (1 - α_filt) * vic.P_filt + α_filt * P_raw
            P_vic = clamp(vic.P_filt, -p.P_vic_max, p.P_vic_max)
            H_log[k] = p.H_min
        end

        # BESS supervisor (slower loop)
        if use_bess && k % sup_step == 0
            sup = bess_supervisor(Δω, dωdt, P_mppt, grid.P_load, bess.SOC, p)
            bess_dynamics!(bess, sup.P_cmd, p; dt=p.Ts_supervisor)
        end
        P_bess = use_bess ? bess.P_bess : 0.0

        # adaptive coordination
        if use_adaptive_coord
            co = adaptive_coord(P_mppt, P_vic, P_bess, Δω, dωdt, bess.SOC, p)
            P_ref = co.P_ref; α=co.alpha; β=co.beta
        else
            P_ref = P_mppt + P_vic + P_bess
            α=1.0; β=1.0
        end

        # injection assumed ideal current loop tracks P_ref
        P_inj = clamp(P_ref, -1.2*p.P_rated, 1.2*p.P_rated)

        # Thevenin authority degradation (L5''): at low SCR, the
        # Thevenin voltage drop reduces the effective bus voltage,
        # which limits the active-power that actually reaches the
        # swing-equation bus. Phenomenological model from the textbook
        # power-angle characteristic P = V²·sin(δ)/X_th: the upper
        # transferable limit is P_max ≈ SCR × P_rated (for unit V),
        # and degradation kicks in as P_inj approaches that limit.
        # For |P_inj| ≪ SCR×P_rated (our regime: 10% step), K_th ≈ 1.
        # Quadratic loss model bounded below at 0.5 to avoid runaway:
        #   K_th = clamp(1 - 0.5·(P_inj / (SCR·P_rated))^2, 0.5, 1)
        if use_thevenin_authority
            P_norm = abs(P_inj) / (SCR_grid * p.P_rated)
            K_th = clamp(1.0 - 0.5 * P_norm^2, 0.5, 1.0)
            P_inj *= K_th
        end

        # AGC layer (secondary frequency control) — sub-grid bulk-resource model.
        # Updated at supervisor cadence; positive P_AGC = additional generation,
        # equivalently a reduction in net load seen by the swing equation.
        if k % sup_step == 0
            Δf_Hz = (grid.omega - p.omega0) / (2π)
            agc_step!(agc, Δf_Hz, tk, tau_AGC, p; dt=p.Ts_supervisor)
        end
        P_AGC_W = agc.enabled ? agc.P_AGC * p.P_rated : 0.0
        P_load_eff = P_load_profile(tk) - P_AGC_W

        # grid frequency dynamics
        # Phenomenological weak-grid coupling (Kundur Ch.12 effective-damping
        # abstraction): low SCR reduces the effective damping seen by the
        # swing equation. D_eff = D_sys × min(1, SCR_grid/SCR_ref) collapses
        # to D_sys at SCR_grid ≥ SCR_ref (default 5) — preserving v1.x
        # behaviour — and reduces below that for weak-grid regimes.
        # Full Thevenin-EMT integration remains queued (Paper #1 phase-6).
        D_eff = D_sys * min(1.0, SCR_grid / SCR_ref)
        grid_step!(grid, P_inj, P_load_eff, H_sys, D_eff, p; dt=dt)
        pll_dynamics!(pll, 0.0, p, SCR_grid; dt=dt)   # placeholder vq=0

        # log
        f_log[k]    = grid.omega/(2pi)
        rocof_log[k] = grid.domegadt/(2pi)
        Pmppt_log[k] = P_mppt
        Pvic_log[k]  = P_vic
        Pref_log[k]  = P_ref
        Pgrid_log[k] = P_inj
        Pbess_log[k] = P_bess
        SOC_log[k]   = bess.SOC
        alpha_log[k] = α
        beta_log[k]  = β
        Pagc_log[k]  = P_AGC_W
    end

    return (t=ts, f=f_log, rocof=rocof_log,
            Pmppt=Pmppt_log, Pvic=Pvic_log, Pref=Pref_log,
            Pgrid=Pgrid_log, Pbess=Pbess_log, SOC=SOC_log,
            alpha=alpha_log, beta=beta_log, H=H_log,
            Pagc=Pagc_log)
end

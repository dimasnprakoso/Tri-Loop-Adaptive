using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
using Test, PVBessVIC

@testset "PV model" begin
    p = default_params()
    P0 = pv_power(0.0, 1000.0, 25.0, p)
    @test P0 ≈ 0.0 atol=1e-6
    mpp = pv_mpp(1000.0, 25.0, p)
    @test mpp.P > 50e3
end

@testset "Adaptive coord weights" begin
    p = default_params()
    @test alpha_weight(0.0, 0.0, p) ≈ 1.0
    @test alpha_weight(2pi*0.5, 0.0, p) < 1.0
    @test 0 ≤ beta_share(0.5, 0.0, 2pi*0.5, p) ≤ p.beta_max
    @test beta_share(0.05, 0.0, 0.0, p) == 0.0   # SOC below min
end

@testset "VIC adaptive output" begin
    p = default_params()
    s = AdaptiveVICState()
    P, gains = vic_output(2pi*(-0.4), 2pi*(-1.0), p, s)
    @test P > 0           # under-frequency → positive injection
    @test gains.H >= p.H_min
end

@testset "Fuzzy VIC (C2)" begin
    p = default_params()
    g0 = fuzzy_vic_gains(0.0, 0.0, p)
    @test g0.H ≈ p.H_min
    @test g0.D ≈ p.D_min
    # event besar → output mendekati level VB (≈ H_max, D_max)
    g1 = fuzzy_vic_gains(2pi*(-0.6), 2pi*(-2.5), p)
    @test g1.H > 0.7 * p.H_max
    @test g1.D > 0.7 * p.D_max
    # P_vic positif saat under-frequency
    s = AdaptiveVICState()
    P, _ = fuzzy_vic_output(2pi*(-0.4), 2pi*(-1.0), p, s)
    @test P > 0
end

@testset "Baseline simulation" begin
    p = default_params()
    sol = simulate_baseline(p; tspan=(0.0, 0.2))
    @test length(sol.t) > 100
    @test all(45.0 .< sol.f .< 55.0)
end

# =====================================================================
#  Metrics: ground-truth tests on synthetic signals
#  Closes test-coverage gap flagged in Paper #2 audit (May 2026):
#  rocof / nadir / settling were previously untested despite being
#  the headline metrics of all Paper #2 results.
# =====================================================================
@testset "rocof: linear ramp ground truth" begin
    # Synthetic: f(t) = 50 Hz for t<2, then 50+0.5*(t-2) Hz for t>=2
    # Expect: rocof = 0.5 Hz/s within numerical noise of slope_window.
    dt = 50e-6
    t = collect(0.0:dt:3.0)
    f = [tk < 2.0 ? 50.0 : 50.0 + 0.5 * (tk - 2.0) for tk in t]
    r = rocof(t, f; t_event=2.0, window=0.5, slope_window=0.1)
    @test isapprox(r, 0.5; atol=1e-6)
end

@testset "rocof: zero slope" begin
    dt = 50e-6
    t = collect(0.0:dt:3.0)
    f = fill(50.0, length(t))
    @test rocof(t, f; t_event=2.0) ≈ 0.0
end

@testset "rocof: negative ramp absolute value" begin
    dt = 50e-6
    t = collect(0.0:dt:3.0)
    f = [tk < 2.0 ? 50.0 : 50.0 - 0.3 * (tk - 2.0) for tk in t]
    @test isapprox(rocof(t, f; t_event=2.0), 0.3; atol=1e-6)
end

@testset "rocof: window selects worst slope" begin
    # f has a fast 1.0 Hz/s ramp for 200 ms followed by a slow plateau.
    # rocof scan window = 500 ms should catch the 1.0 Hz/s peak.
    dt = 50e-6
    t = collect(0.0:dt:3.0)
    f = map(t) do tk
        if tk < 2.0
            50.0
        elseif tk < 2.2
            50.0 + 1.0 * (tk - 2.0)        # fast ramp 1 Hz/s
        else
            50.2                            # plateau
        end
    end
    r = rocof(t, f; t_event=2.0, window=0.5, slope_window=0.1)
    # Slope window 100 ms inside the 200 ms ramp recovers ~1 Hz/s.
    @test 0.95 <= r <= 1.05
end

@testset "frequency_nadir: under and over-freq" begin
    dt = 1e-3
    t = collect(0.0:dt:5.0)
    # Drop to 49.5 then recover
    f_under = [tk < 2.0 ? 50.0 : 50.0 - 0.5*exp(-(tk-2.0)) for tk in t]
    @test isapprox(frequency_nadir(t, f_under; t_event=2.0), 49.5; atol=1e-3)
    # Rise to 50.4 then recover
    f_over = [tk < 2.0 ? 50.0 : 50.0 + 0.4*exp(-(tk-2.0)) for tk in t]
    @test isapprox(frequency_nadir(t, f_over; t_event=2.0), 50.4; atol=1e-3)
end

@testset "nadir_deviation: symmetric under/over" begin
    dt = 1e-3
    t = collect(0.0:dt:5.0)
    f_under = [tk < 2.0 ? 50.0 : 50.0 - 0.4*exp(-(tk-2.0)) for tk in t]
    f_over  = [tk < 2.0 ? 50.0 : 50.0 + 0.4*exp(-(tk-2.0)) for tk in t]
    d1 = nadir_deviation(t, f_under; t_event=2.0)
    d2 = nadir_deviation(t, f_over;  t_event=2.0)
    @test isapprox(d1, 0.4; atol=1e-3)
    @test isapprox(d2, 0.4; atol=1e-3)
    @test isapprox(d1, d2; atol=1e-6)   # symmetry
end

@testset "settling_time: within and never" begin
    dt = 1e-3
    t = collect(0.0:dt:5.0)
    # Exponential decay: 0.3*exp(-2(t-2)) drops below 0.05 Hz at
    # t-2 = ln(6)/2 ≈ 0.896 s.
    f_settles = [tk < 2.0 ? 50.0 : 50.0 + 0.3*exp(-2*(tk-2.0)) for tk in t]
    ts = settling_time(t, f_settles; t_event=2.0, band_Hz=0.05, dwell=0.2)
    @test 0.85 <= ts <= 1.10  # near analytical 0.896 s
    # Persistent 0.1 Hz oscillation never settles within 0.05 band
    f_osc = [tk < 2.0 ? 50.0 : 50.0 + 0.1*sin(10*(tk-2.0)) for tk in t]
    @test isnan(settling_time(t, f_osc; t_event=2.0, band_Hz=0.05))
end

@testset "metrics: cross-check Madiun-regime worst case" begin
    # Synthetic post-contingency trace mimicking H=2 s, D=3, ΔP=10%:
    # initial 1.1 Hz/s descent capped at 1.7 Hz droop steady state.
    # This regression test guards against silent metric regressions analogous
    # to the May 2026 plot_contingency_overlay.py raw-derivative bug
    # (raw df/dt at dt=50us was sample-noise contaminated, gave 1.23 Hz/s
    # instead of correct 1.10 Hz/s with 100ms IEEE 1547 sliding window).
    dt = 50e-6
    t = collect(0.0:dt:4.0)              # 2 s post-event horizon
    f = map(t) do tk
        if tk < 2.0
            50.0
        else
            50.0 - min(1.1 * (tk - 2.0), 1.7)   # ramp 1.1 Hz/s capped at 1.7 Hz droop
        end
    end
    r = rocof(t, f; t_event=2.0, window=0.5, slope_window=0.1)
    @test 1.05 <= r <= 1.15  # initial ramp ~1.1 Hz/s recovered
    nd = nadir_deviation(t, f; t_event=2.0)
    @test 1.65 <= nd <= 1.75  # droop steady state ~1.7 Hz
end

# =====================================================================
#  AGC layer (Paper #3): integral controller with restoration time
#  constant tau_AGC. Tests cover disabled, basic integration,
#  saturation clamp, and pre-event quiescence.
# =====================================================================
@testset "AGC: disabled when tau_AGC = Inf" begin
    p = default_params()
    agc = AGCState(0.0, false, 0.0)   # not enabled
    pwr = agc_step!(agc, 0.5, 1.0, Inf, p; dt=1e-3)
    @test pwr == 0.0
    @test agc.P_AGC == 0.0
end

@testset "AGC: quiescent before event" begin
    p = default_params()
    agc = AGCState(0.0, true, 2.0)
    # t < t_event → no integration
    pwr = agc_step!(agc, 0.5, 1.5, 60.0, p; dt=1e-3)
    @test pwr == 0.0
    @test agc.P_AGC == 0.0
end

@testset "AGC: integrates Δf to compensate" begin
    # With Δf = -0.4 Hz constant for tau_AGC seconds,
    # P_AGC should reach approximately -(-0.4/50) * 1 = +0.008 pu
    # after dt = tau (linear approximation of integral integration).
    p = default_params()
    agc = AGCState(0.0, true, 0.0)
    Δf = -0.4   # under-frequency
    tau_AGC = 60.0
    dt = 1e-3
    n = Int(tau_AGC / dt)   # integrate for full tau
    for _ in 1:n
        agc_step!(agc, Δf, 1.0, tau_AGC, p; dt=dt)
    end
    # ∫(-1/τ * (Δf/f0)) dt over [0, τ] = -1·(Δf/f0) = -(-0.4/50) = +0.008 pu
    @test isapprox(agc.P_AGC, 0.008; atol=2e-4)
end

@testset "AGC: saturation clamp at ±50% rated" begin
    p = default_params()
    agc = AGCState(0.0, true, 0.0)
    # Force enough accumulated error to drive past +0.5 clamp.
    # Rate = (1/tau) * |Δf|/f0 = (1/10) * (5/50) = 0.01 pu/s,
    # so reaching 0.5 takes 50 s ≈ 50,000 ms; use 80,000 for margin.
    Δf_persistent = -5.0   # extreme under-frequency
    dt = 1e-3
    for _ in 1:80_000
        agc_step!(agc, Δf_persistent, 1.0, 10.0, p; dt=dt)
    end
    @test agc.P_AGC <= 0.5 + 1e-9   # clamped from above
    @test agc.P_AGC >= 0.5 - 1e-9   # actually at clamp
end

@testset "AGC: full simulate_baseline integration smoke test" begin
    # Run a brief baseline sim with AGC enabled vs disabled.
    # AGC should reduce the steady-state |Δf| at the end of the horizon.
    p = default_params()
    sol_no_agc = simulate_baseline(p;
        tspan=(0.0, 3.0),
        P_load_profile = t -> t < 0.5 ? 80e3 : 80e3 + 0.10 * p.P_rated,
        H_sys=2.0, D_sys=3.0,
        tau_AGC=Inf)        # baseline, no AGC
    sol_with_agc = simulate_baseline(p;
        tspan=(0.0, 3.0),
        P_load_profile = t -> t < 0.5 ? 80e3 : 80e3 + 0.10 * p.P_rated,
        H_sys=2.0, D_sys=3.0,
        tau_AGC=10.0,       # aggressive AGC for short test horizon
        t_agc_enable=0.5)
    df_no_agc_end   = abs(sol_no_agc.f[end]   - 50.0)
    df_with_agc_end = abs(sol_with_agc.f[end] - 50.0)
    # AGC must shrink the steady-state |Δf| (any reduction is a pass)
    @test df_with_agc_end < df_no_agc_end
    # AGC log should track non-trivial output after enable
    @test maximum(abs.(sol_with_agc.Pagc)) > 0.0
    @test all(sol_no_agc.Pagc .== 0.0)
end

# ----------------------------------------------------------------------
#  Non-ideal AGC (Paper #3 v1.4 / Limitation L3)
#  Cover dead-band, rate limit, telemetry latency.
# ----------------------------------------------------------------------

@testset "AGC dead-band: integrator frozen below band" begin
    # Δf = 0.005 Hz with dead-band 0.01 Hz → integrator must stay at zero
    p = default_params()
    agc = AGCState(0.0, true, 0.0, 0.01, Inf, 0.0)   # dead-band 10 mHz
    dt = 1e-3
    for _ in 1:5000   # 5 seconds at dt=1ms
        agc_step!(agc, 0.005, 1.0, 30.0, p; dt=dt)
    end
    @test agc.P_AGC == 0.0   # exact zero, integrator never activated
end

@testset "AGC dead-band: integrator active above band" begin
    # Δf = 0.05 Hz with dead-band 0.01 Hz → integrator runs as if ideal
    p = default_params()
    agc_ideal = AGCState(0.0, true, 0.0, 0.0,  Inf, 0.0)
    agc_db    = AGCState(0.0, true, 0.0, 0.01, Inf, 0.0)
    dt = 1e-3
    Δf = 0.05
    for _ in 1:30_000   # 30s integration
        agc_step!(agc_ideal, Δf, 1.0, 30.0, p; dt=dt)
        agc_step!(agc_db,    Δf, 1.0, 30.0, p; dt=dt)
    end
    @test isapprox(agc_db.P_AGC, agc_ideal.P_AGC; rtol=1e-9)
end

@testset "AGC rate limit: clamps |dP_AGC/dt|" begin
    # With Δf=−0.4 Hz, ideal dP/dt = (0.4/50)/30 ≈ 2.67e−4 pu/s.
    # Rate limit set to 1.0e−4 pu/s → AGC ramps slower (~37% of ideal).
    p = default_params()
    agc_ideal = AGCState(0.0, true, 0.0, 0.0, Inf,   0.0)
    agc_rl    = AGCState(0.0, true, 0.0, 0.0, 1e-4,  0.0)
    dt = 1e-3
    Δf = -0.4
    for _ in 1:60_000   # 60s integration
        agc_step!(agc_ideal, Δf, 1.0, 30.0, p; dt=dt)
        agc_step!(agc_rl,    Δf, 1.0, 30.0, p; dt=dt)
    end
    # Rate-limited AGC must lag the ideal one by roughly
    # the ratio of the two ramp rates (ideal 2.67e−4 / limit 1e−4 ≈ 2.67×)
    ramp_ideal = abs(agc_ideal.P_AGC) / 60.0   # avg ramp rate over 60s
    ramp_rl    = abs(agc_rl.P_AGC) / 60.0
    @test ramp_rl < ramp_ideal
    @test isapprox(ramp_rl, 1e-4; rtol=0.05)   # rate-limited at the cap
end

@testset "Weak-grid SCR: SCR=∞ matches v1.x default behaviour" begin
    # SCR_grid = SCR_ref → D_eff = D_sys exactly → identical trajectory
    p = default_params()
    sol_default = simulate_baseline(p;
        tspan=(0.0, 3.0),
        P_load_profile = t -> t < 0.5 ? 80e3 : 80e3 + 0.10 * p.P_rated,
        H_sys=2.0, D_sys=3.0, tau_AGC=Inf)
    sol_strong = simulate_baseline(p;
        tspan=(0.0, 3.0),
        P_load_profile = t -> t < 0.5 ? 80e3 : 80e3 + 0.10 * p.P_rated,
        H_sys=2.0, D_sys=3.0, tau_AGC=Inf, SCR_grid=5.0, SCR_ref=5.0)
    @test isapprox(sol_default.f[end], sol_strong.f[end]; atol=1e-9)
end

@testset "Thevenin authority: disabled by default" begin
    # use_thevenin_authority=false (default) → no degradation
    p = default_params()
    sol_default = simulate_baseline(p;
        tspan=(0.0, 1.0),
        P_load_profile = t -> 80e3,
        H_sys=2.0, D_sys=3.0, tau_AGC=Inf)
    sol_no_th = simulate_baseline(p;
        tspan=(0.0, 1.0),
        P_load_profile = t -> 80e3,
        H_sys=2.0, D_sys=3.0, tau_AGC=Inf, use_thevenin_authority=false)
    @test isapprox(sol_default.f[end], sol_no_th.f[end]; atol=1e-9)
end

@testset "Thevenin authority: K_th model engages at low SCR" begin
    # When use_thevenin_authority=true at SCR=2, the K_th factor
    # reduces P_inj relative to the disabled baseline. Verify the
    # trajectories differ measurably (the K_th model does engage).
    p = default_params()
    sol_off = simulate_baseline(p;
        tspan=(0.0, 5.0),
        P_load_profile = t -> t < 1.0 ? 80e3 : 80e3 + 0.10 * p.P_rated,
        H_sys=2.0, D_sys=3.0, tau_AGC=Inf,
        use_thevenin_authority=false, SCR_grid=2.0)
    sol_on = simulate_baseline(p;
        tspan=(0.0, 5.0),
        P_load_profile = t -> t < 1.0 ? 80e3 : 80e3 + 0.10 * p.P_rated,
        H_sys=2.0, D_sys=3.0, tau_AGC=Inf,
        use_thevenin_authority=true, SCR_grid=2.0)
    diff_max = maximum(abs.(sol_off.f .- sol_on.f))
    # Trajectories must differ when K_th engages at SCR=2
    @test diff_max > 1e-3
    # And SCR=20 should give negligible difference (K_th ≈ 1)
    sol_on_strong = simulate_baseline(p;
        tspan=(0.0, 5.0),
        P_load_profile = t -> t < 1.0 ? 80e3 : 80e3 + 0.10 * p.P_rated,
        H_sys=2.0, D_sys=3.0, tau_AGC=Inf,
        use_thevenin_authority=true, SCR_grid=20.0)
    diff_strong = maximum(abs.(sol_off.f[1:length(sol_on_strong.f)] .-
                               sol_on_strong.f))
    # K_th at SCR=20 with |P_inj|≤P_rated gives ≤0.125% loss
    @test diff_strong < diff_max
end

@testset "Weak-grid SCR: SCR=2 equivalent to D_sys × 0.4" begin
    # D_eff = D_sys × min(1, 2/5) = 0.4×D_sys
    # Direct sim with D_sys = 1.2 (= 3×0.4) should match SCR=2 sim with D_sys=3
    p = default_params()
    sol_weak = simulate_baseline(p;
        tspan=(0.0, 3.0),
        P_load_profile = t -> t < 0.5 ? 80e3 : 80e3 + 0.10 * p.P_rated,
        H_sys=2.0, D_sys=3.0, tau_AGC=Inf, SCR_grid=2.0, SCR_ref=5.0)
    sol_direct = simulate_baseline(p;
        tspan=(0.0, 3.0),
        P_load_profile = t -> t < 0.5 ? 80e3 : 80e3 + 0.10 * p.P_rated,
        H_sys=2.0, D_sys=1.2, tau_AGC=Inf)
    # Frequency trajectories should agree to numerical precision
    @test isapprox(sol_weak.f[end], sol_direct.f[end]; atol=1e-6)
end

@testset "AGC telemetry latency: integrator delayed by latency_s" begin
    # latency_s = 0.5 s. Apply Δf=−0.4 Hz starting at t=0.
    # For t<0.5s, agc.P_AGC must remain zero (buffer not full yet).
    # After t≥0.5s, AGC sees the delayed input and integrates normally.
    p = default_params()
    agc = AGCState(0.0, true, 0.0, 0.0, Inf, 0.5)
    dt = 1e-3
    Δf = -0.4

    # Step through first 0.4s — AGC should not have integrated yet
    for _ in 1:400
        agc_step!(agc, Δf, 1.0, 30.0, p; dt=dt)
    end
    @test agc.P_AGC == 0.0   # buffer still filling

    # Continue past the 0.5s mark — AGC begins integrating
    for _ in 1:600   # bring total to 1.0s
        agc_step!(agc, Δf, 1.0, 30.0, p; dt=dt)
    end
    @test agc.P_AGC > 0.0   # now actively integrating
    # AGC has integrated for about 0.5s post-latency:
    # P_AGC ≈ (0.4/50)/30 × 0.5 ≈ 1.33e-4 pu, allow tolerance
    @test isapprox(agc.P_AGC, 1.33e-4; atol=2e-5)
end

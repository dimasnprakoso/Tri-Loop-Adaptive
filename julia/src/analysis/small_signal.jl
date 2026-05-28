"""
Fase 6 — Small-signal stability via numerical Jacobian.

Average-model PV-BESS-VIC kita ditulis sebagai discrete-time loop di
`system_average.jl`, bukan ODESystem MTK. Untuk small-signal:
    1. Bangun state vector reduced (n=5) yang menangkap dinamika dominan.
    2. Hitung ẋ = f(x, u, p) sebagai continuous-time approximation.
    3. Jacobian A = ∂f/∂x via finite difference forward.
    4. Eigenvalues, damping ratio, dominant mode identification.
    5. Sweep parameter (k_α, k_α_rocof, ω̇_ref, β_max) → eigenvalue locus.

State vector x (5 dim):
    1. Δω        = grid frequency deviation (rad/s)
    2. dωdt_filt = filtered RoCoF measurement
    3. Δω_filt   = filtered freq deviation
    4. P_vic_filt = VIC output filtered
    5. SOC       = BESS state-of-charge

Disturbance u: ΔP_load (1 dim) — perturbation around equilibrium.

Equilibrium: Δω=0, dωdt=0, P_inj=P_load, SOC=SOC_init. Pada equilibrium
P_vic≈0 dan β·P_bess≈0, sehingga ΔP_inj=0 → frekuensi nominal.
"""

using LinearAlgebra

"""
Compute ẋ = f(x, u; H_sys, D_sys, p, scheme).
- `x` adalah perturbasi state dari equilibrium (Δω, dωdt_filt, Δω_filt,
  P_vic_filt, ΔSOC).
- `u` adalah perturbasi load (ΔP).
- `scheme` ∈ (:C1, :C2, :C3, :C4) — pilihan kontrol.
"""
function dynamics_linearized(x::Vector{Float64}, u::Float64, p::SystemParams;
                             H_sys::Float64=2.0, D_sys::Float64=2.0,
                             scheme::Symbol=:C4)
    Δω, dωdt_filt, Δω_filt, P_vic_filt, ΔSOC = x

    SOC = p.SOC_init + ΔSOC
    T_meas = 0.02
    T_filt_ω = p.T_filter_omega

    # VIC raw output (gain depends on scheme)
    if scheme === :C1
        H_t, D_t = p.H_min, p.D_min
    elseif scheme === :C2
        # fuzzy gains evaluated at filtered Δω, dωdt
        g = fuzzy_vic_gains(Δω_filt, dωdt_filt, p)
        H_t, D_t = g.H, g.D
    elseif scheme === :C3 || scheme === :C4
        H_t = p.H_min + (p.H_max - p.H_min) * tanh(p.gamma_J * abs(dωdt_filt) / p.omega_dot_ref)
        D_t = p.D_min + (p.D_max - p.D_min) * tanh(p.delta_D * abs(Δω_filt)   / p.omega_ref_vic)
    else
        H_t, D_t = 0.0, 0.0
    end
    P_vic_raw = -(2*H_t/p.omega0 * dωdt_filt + D_t * Δω_filt/p.omega0) * p.P_rated
    P_vic_raw = clamp(P_vic_raw, -p.P_vic_max, p.P_vic_max)

    # BESS proportional response (linearized supervisor)
    # P_bess ≈ -P_bess_max · tanh(2Δω/(2π·0.5) + 0.5·dωdt/(2π·0.5))  saat |Δω|>dead
    if abs(Δω_filt) < p.Δω_dead && abs(dωdt_filt) < 2pi*0.05
        P_bess = 0.0
    else
        P_bess = -p.P_bess_max * tanh(2*Δω_filt/(2pi*0.5) + 0.5*dωdt_filt/(2pi*0.5))
    end

    # Coordination
    if scheme === :C4
        β = beta_share(SOC, Δω_filt, dωdt_filt, p)
        ΔP_inj = P_vic_filt + β * P_bess
    elseif scheme === :C0
        ΔP_inj = 0.0
    else
        ΔP_inj = P_vic_filt + P_bess
    end

    # State derivatives
    # 1. Swing equation: 2H_sys · dΔω/dt · ω0 = ΔP - D_sys·Δω·ω0
    #    Bentuk standar: 2H_sys · d(Δω/ω0)/dt = ΔP/P_rated - D_sys·(Δω/ω0)
    ΔP_pu = (ΔP_inj - u) / p.P_rated
    dΔω = (ΔP_pu - D_sys*Δω/p.omega0) * p.omega0 / (2*H_sys)

    # 2. dωdt_filt low-pass dari dΔω instan
    ddωdt_filt = (dΔω - dωdt_filt) / T_meas

    # 3. Δω_filt low-pass dari Δω
    dΔω_filt = (Δω - Δω_filt) / T_meas

    # 4. P_vic_filt low-pass dari P_vic_raw
    dP_vic_filt = (P_vic_raw - P_vic_filt) / T_filt_ω

    # 5. SOC dynamics: dSOC/dt = -P_bess / (η · E_J)
    E_J = p.E_rated_kWh * 3.6e6
    if P_bess >= 0
        dSOC = -P_bess / (p.eta_dis * E_J)
    else
        dSOC = -p.eta_ch * P_bess / E_J
    end

    return [dΔω, ddωdt_filt, dΔω_filt, dP_vic_filt, dSOC]
end

"""Numerical Jacobian A = ∂f/∂x via forward finite difference."""
function compute_A(p::SystemParams; H_sys::Float64=2.0, D_sys::Float64=2.0,
                   scheme::Symbol=:C4, eps::Float64=1e-5)
    x0 = zeros(5)
    f0 = dynamics_linearized(x0, 0.0, p; H_sys=H_sys, D_sys=D_sys, scheme=scheme)
    n = length(x0)
    A = zeros(n, n)
    for j in 1:n
        # use a state-aware perturbation step: ε * (1 + |x_j_typical|)
        scale = j == 5 ? 0.01 : 1e-3   # SOC kecil; lainnya dlm rad/s
        h = eps * scale
        xp = copy(x0); xp[j] += h
        fp = dynamics_linearized(xp, 0.0, p; H_sys=H_sys, D_sys=D_sys, scheme=scheme)
        A[:, j] = (fp - f0) / h
    end
    return A
end

"""Eigenvalues + damping ratio + natural frequency dari A."""
function modal_analysis(A::Matrix{Float64})
    λ = eigvals(A)
    out = NamedTuple[]
    for ev in λ
        ωn = abs(ev)
        ζ = ωn ≈ 0 ? 1.0 : -real(ev)/ωn
        f_n = imag(ev) / (2pi)
        push!(out, (eigenvalue=ev, omega_n=ωn, damping=ζ, freq_Hz=f_n))
    end
    return out
end

"""
Sweep one parameter, return DataFrame-ready data struct: param_value × eigenvalue.
"""
function eigenvalue_locus_sweep(param::Symbol, values::AbstractVector;
                                 base_p::SystemParams=default_params(),
                                 H_sys::Float64=2.0, D_sys::Float64=2.0,
                                 scheme::Symbol=:C4)
    rows = NamedTuple[]
    for v in values
        # build new params with overridden field
        kwargs = Dict(:p => base_p)
        # construct via type-stable copy: re-instantiate SystemParams
        nt = NamedTuple{(param,)}((float(v),))
        p_new = SystemParams(; merge(_to_named_tuple(base_p), nt)...)
        A = compute_A(p_new; H_sys=H_sys, D_sys=D_sys, scheme=scheme)
        for (k, ev) in enumerate(eigvals(A))
            ζ = abs(ev) ≈ 0 ? 1.0 : -real(ev)/abs(ev)
            push!(rows, (param=String(param), value=float(v),
                         mode_idx=k, real=real(ev), imag=imag(ev),
                         omega_n=abs(ev), damping=ζ))
        end
    end
    return rows
end

"""Convert SystemParams to NamedTuple for kwargs construction."""
function _to_named_tuple(p::SystemParams)
    nt = NamedTuple{Tuple(fieldnames(typeof(p)))}(
        ntuple(i -> getfield(p, i), fieldcount(typeof(p)))
    )
    return nt
end

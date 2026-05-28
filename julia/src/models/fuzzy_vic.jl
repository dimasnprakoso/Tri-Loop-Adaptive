"""
Fuzzy-Logic Virtual Inertia Controller (skema C2 — replikasi state-of-art).

Struktur Mamdani 5×5 dengan input magnitude |Δω|/ω_ref dan |dωdt|/ω̇_ref
(dinormalisasi ke 0..2). Output H_t dan D_t didefuzz dengan centroid weighted
average atas 5 level keluaran. Sign P_vic tetap dari formula swing-equivalent:

    P_vic = -[ 2H_t/ω0 · dωdt + D_t · Δω/ω0 ] · P_rated

Membership input (5 level segitiga simetris):
    Z  → peak 0.0   support [0, 0.5]
    S  → peak 0.5   support [0, 1.0]
    M  → peak 1.0   support [0.5, 1.5]
    B  → peak 1.5   support [1.0, 2.0]
    VB → peak 2.0   support [1.5, 2.5]   (saturasi sebelah kanan)

Rule base 5×5 → output level (Z, S, M, B, VB) untuk H_t dan D_t. Pola umum:
"output = membership level tertinggi dari kedua input" (mirroring conventional
"either input large → output large"). Standar replikasi Cheng et al. 2024,
Liu et al. 2023, dll.
"""

const _RULE_TABLE = [
    1 2 3 4 5;     # |Δω| Z   x dωdt {Z S M B VB}
    2 2 3 4 5;     # |Δω| S
    3 3 3 4 5;     # |Δω| M
    4 4 4 4 5;     # |Δω| B
    5 5 5 5 5      # |Δω| VB
]

@inline function _trimf(x, a, b, c)
    # triangular membership; peak di b, base [a, c]
    if x <= a || x >= c
        return 0.0
    elseif x <= b
        return (x - a) / (b - a)
    else
        return (c - x) / (c - b)
    end
end

@inline function _membership_5(x)
    # 5 fungsi keanggotaan triangular dinormalisasi ke 0..2
    # Z, S, M, B, VB peaks di 0.0, 0.5, 1.0, 1.5, 2.0
    return (
        _trimf(x, -0.5, 0.0, 0.5),   # Z
        _trimf(x,  0.0, 0.5, 1.0),   # S
        _trimf(x,  0.5, 1.0, 1.5),   # M
        _trimf(x,  1.0, 1.5, 2.0),   # B
        max(0.0, min(1.0, (x - 1.5)/0.5))  # VB (saturasi kanan)
    )
end

"""
Hitung H_t dan D_t via Mamdani max-min + centroid defuzz.
Inputs Δω dan dωdt dalam rad/s.
"""
function fuzzy_vic_gains(Δω::Float64, dωdt::Float64, p::SystemParams)
    # normalisasi ke skala 0..2 (saturasi di luar)
    x_w = clamp(abs(Δω)   / p.omega_ref_vic, 0.0, 2.5)
    x_r = clamp(abs(dωdt) / p.omega_dot_ref, 0.0, 2.5)

    μw = _membership_5(x_w)
    μr = _membership_5(x_r)

    # output 5 level → H, D centroids
    H_levels = (p.H_min,
                p.H_min + 0.25*(p.H_max - p.H_min),
                p.H_min + 0.50*(p.H_max - p.H_min),
                p.H_min + 0.75*(p.H_max - p.H_min),
                p.H_max)
    D_levels = (p.D_min,
                p.D_min + 0.25*(p.D_max - p.D_min),
                p.D_min + 0.50*(p.D_max - p.D_min),
                p.D_min + 0.75*(p.D_max - p.D_min),
                p.D_max)

    weights = zeros(5)
    @inbounds for i in 1:5, j in 1:5
        activation = min(μw[i], μr[j])
        activation == 0.0 && continue
        out_level = _RULE_TABLE[i, j]
        weights[out_level] = max(weights[out_level], activation)
    end

    den = sum(weights)
    if den < 1e-9
        return (H=p.H_min, D=p.D_min)
    end
    H_t = sum(weights .* H_levels) / den
    D_t = sum(weights .* D_levels) / den
    return (H=H_t, D=D_t)
end

"""
Wrapper output P_vic untuk skema C2 — formula identik dengan adaptive-VIC
namun H_t dan D_t dihitung lewat fuzzy inference, bukan tanh smooth.
Filter post-output dan saturation tetap memanfaatkan AdaptiveVICState yang sama.
"""
function fuzzy_vic_output(Δω::Float64, dωdt::Float64, p::SystemParams,
                          s::AdaptiveVICState; dt::Float64=p.Ts_control)
    g = fuzzy_vic_gains(Δω, dωdt, p)
    P_raw = -(2*g.H/p.omega0 * dωdt + g.D * Δω/p.omega0) * p.P_rated
    α_filt = dt / (p.T_filter_omega + dt)
    s.P_filt = (1 - α_filt) * s.P_filt + α_filt * P_raw
    P_out = clamp(s.P_filt, -p.P_vic_max, p.P_vic_max)
    return P_out, (H=g.H, D=g.D)
end

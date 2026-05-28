"""
Standard metrics for grid-stability evaluation.
All inputs are time series sampled at uniform Δt.
"""

"""
Maximum |df/dt| post-event, dihitung dengan **sliding window 100 ms** (sesuai
IEEE 1547 / EN 50549). Diff sample-to-sample (saat dt=50 µs) menangkap noise
diskretisasi instan, bukan RoCoF fisik — gunakan slope window yang lebih
panjang. Default: 500 ms scan window, 100 ms slope window.
"""
function rocof(t::Vector{Float64}, f::Vector{Float64};
               t_event::Float64=2.0, window::Float64=0.5,
               slope_window::Float64=0.1)
    idx_post = findall((t .>= t_event) .& (t .<= t_event+window))
    isempty(idx_post) && return 0.0
    dt = t[2] - t[1]
    nw = max(Int(round(slope_window/dt)), 2)
    rocof_max = 0.0
    for k in idx_post
        kend = k + nw
        kend > length(t) && break
        slope = (f[kend] - f[k]) / (t[kend] - t[k])
        a = abs(slope)
        a > rocof_max && (rocof_max = a)
    end
    return rocof_max
end

"""
f_nadir = post-event minimum (under-frequency).
f_zenith = post-event maximum (over-frequency).
Returns whichever is the largest |deviation| from f0 (worst-case).
"""
function frequency_nadir(t::Vector{Float64}, f::Vector{Float64};
                         t_event::Float64=2.0, f0::Float64=50.0)
    idx = t .>= t_event
    fmin = minimum(f[idx])
    fmax = maximum(f[idx])
    return abs(fmin - f0) >= abs(fmax - f0) ? fmin : fmax
end

"""Worst-case |Δf| from nominal (always positive). Symmetric for over/under-freq."""
function nadir_deviation(t::Vector{Float64}, f::Vector{Float64};
                         f0::Float64=50.0, t_event::Float64=2.0)
    fworst = frequency_nadir(t, f; t_event=t_event, f0=f0)
    return abs(fworst - f0)
end

"""
Settling time of frequency: first time after event when |f-f0| stays
within `band_Hz` for at least `dwell` seconds.

Default band = 0.05 Hz (typical primary-control criterion); previously
2e-3 (tight ±0.1 Hz at 50 Hz) was unreachable in 5 s horizon.
"""
function settling_time(t::Vector{Float64}, f::Vector{Float64};
                       t_event::Float64=2.0, band_Hz::Float64=0.05,
                       f0::Float64=50.0, dwell::Float64=0.2)
    idx0 = findfirst(t .>= t_event)
    isnothing(idx0) && return NaN
    n_dwell = Int(round(dwell / (t[2]-t[1])))
    n_dwell = max(n_dwell, 1)
    last_idx = length(t) - n_dwell
    last_idx <= idx0 && return NaN
    @inbounds for k in idx0:last_idx
        ok = true
        for j in k:k+n_dwell
            if abs(f[j] - f0) > band_Hz
                ok = false; break
            end
        end
        if ok
            return t[k] - t_event
        end
    end
    return NaN
end

"""MPPT efficiency = ∫P_mppt(t) dt / ∫P_mpp_ideal(t) dt over horizon."""
function mppt_efficiency(t::Vector{Float64}, P_track::Vector{Float64},
                         P_ideal::Vector{Float64})
    a = sum(P_track) * (t[2]-t[1])
    b = sum(P_ideal) * (t[2]-t[1])
    b ≈ 0 ? 0.0 : a/b
end

"""THD of a current waveform via FFT, fundamental at f0 [Hz]."""
function thd_current(i::Vector{Float64}, fs::Float64; f0::Float64=50.0,
                     n_harm::Int=20)
    N = length(i)
    Y = abs.(fft(i .- mean(i)))[1:N÷2]
    freqs = (0:N÷2-1) .* (fs/N)
    fund_bin = argmin(abs.(freqs .- f0))
    A1 = Y[fund_bin]
    A1 ≈ 0 && return 0.0
    Ah = 0.0
    for h in 2:n_harm
        bin = argmin(abs.(freqs .- h*f0))
        Ah += Y[bin]^2
    end
    return sqrt(Ah)/A1
end

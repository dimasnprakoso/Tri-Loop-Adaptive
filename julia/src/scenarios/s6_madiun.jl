# Scenario 6 — Madiun real-day 24-h compressed (luaran utama Paper #2 Q2).
# Profil G(t) & T_cell(t) per jam dari NASA POWER (lat -7.629, lon 111.524)
# untuk 3 hari mewakili 2025: cerah (2025-08-01), berawan (2025-06-12),
# hujan (2025-10-25). Time-compress 1 jam riil → 1 detik simulasi → 24 s total.
# Beban harian dijadwalkan mengikuti pola residensial-komersial Madiun
# (puncak siang 50%, puncak malam 100%, low-load dini hari 30%).

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))
include(joinpath(@__DIR__, "_harness.jl"))

using CSV, DataFrames

const HOUR_PER_SIM_SEC = 0.1   # 1 detik sim = 0.1 jam → 10 detik per jam → 240 s total
                                # cukup landai supaya transient load tidak artefak,
                                # masih feasible secara komputasi (4.8M steps)
const DAY_TYPES = ["cerah", "berawan", "hujan"]
const PROC_DIR = joinpath(@__DIR__, "..", "..", "..", "data", "processed")

"""Linear interpolator dari array (t_grid, y) untuk dipakai di simulate_baseline."""
function lerp_profile(t_grid::Vector{Float64}, y::Vector{Float64})
    return function (t::Float64)
        if t <= t_grid[1]
            return y[1]
        elseif t >= t_grid[end]
            return y[end]
        end
        i = searchsortedfirst(t_grid, t)
        i = clamp(i, 2, length(t_grid))
        x0, x1 = t_grid[i-1], t_grid[i]
        return y[i-1] + (y[i] - y[i-1]) * (t - x0) / (x1 - x0)
    end
end

"""Beban harian per-unit (puncak malam 100%, siang 50%, dini hari 30%)."""
function load_per_unit(jam::Float64)
    # piecewise smooth; jam dalam [0,24)
    if jam < 5.0
        return 0.30
    elseif jam < 10.0
        return 0.30 + 0.20 * (jam - 5.0) / 5.0    # naik 30→50%
    elseif jam < 17.0
        return 0.50 + 0.10 * sin((jam - 10.0)/7 * π)  # variasi siang
    elseif jam < 19.0
        return 0.60 + 0.40 * (jam - 17.0) / 2.0   # naik 60→100%
    elseif jam < 22.0
        return 1.00 - 0.10 * (jam - 19.0) / 3.0   # plateau dengan slight taper
    else
        return 0.90 - 0.60 * (jam - 22.0) / 2.0   # turun 90→30%
    end
end

function run_madiun_day(day_type::String)
    csv = CSV.read(joinpath(PROC_DIR, "madiun_profile_$(day_type).csv"), DataFrame)
    @assert nrow(csv) == 24 "expected 24 hourly samples"

    # konversi jam → detik simulasi (compress 1 jam = 1 sec)
    t_sec_real = csv.t_s ./ 3600.0     # jadi 0..23 (jam)
    t_sec_sim  = t_sec_real ./ HOUR_PER_SIM_SEC   # 0..23 dalam unit detik sim
    G_func     = lerp_profile(collect(t_sec_sim), collect(csv.G_W_m2))
    T_func     = lerp_profile(collect(t_sec_sim), collect(csv.T_cell_C))

    p = default_params()
    P_BASE = 0.85 * p.P_rated   # peak load 106.25 kW
    P_load_func = t -> P_BASE * load_per_unit(min(t * HOUR_PER_SIM_SEC, 23.99))

    sid = "s6_madiun_$(day_type)"
    desc = "Madiun 2025 hari $(day_type) (NASA POWER, 24-h → 240 s compressed)"
    t_end = 24.0 / HOUR_PER_SIM_SEC - 1.0   # 239 s
    run_scenario(sid;
        desc=desc,
        tspan=(0.0, t_end),
        G_profile=G_func, T_profile=T_func,
        P_load_profile=P_load_func,
        H_sys=2.0, D_sys=3.0, t_event=60.0)   # event reference jam 6 LST = 60 s sim
end

for dt in DAY_TYPES
    run_madiun_day(dt)
end

module PVBessVIC

using ModelingToolkit
using ModelingToolkit: t_nounits as t, D_nounits as D
using DifferentialEquations
using Parameters
using LinearAlgebra
using Statistics
using FFTW
import Roots

include("models/params.jl")
include("models/pv_diode.jl")
include("models/bess.jl")
include("models/pll_sofi.jl")
include("models/vic_adaptive.jl")
include("models/fuzzy_vic.jl")
include("models/adaptive_coord.jl")
include("models/bess_supervisor.jl")
include("models/grid_thevenin.jl")
include("models/multiarea_grid.jl")
include("models/system_average.jl")
include("models/multiarea_baseline.jl")

include("analysis/metrics.jl")
include("analysis/small_signal.jl")

export SystemParams, default_params
export pv_power, pv_current, pv_mpp, pv_iv_residual
export bess_dynamics!, BessState
export pll_dynamics!, PLLState
export vic_output, AdaptiveVICState
export fuzzy_vic_output, fuzzy_vic_gains
export adaptive_coord, alpha_weight, beta_share
export bess_supervisor, BessMode, IDLE, DISCHARGE, CHARGE, STANDBY
export GridState, grid_step!, thevenin_impedance
export MultiAreaGridState, multiarea_step!, simulate_multiarea
export ChainGridState, chain_step!
export simulate_baseline, AGCState, agc_step!
export rocof, frequency_nadir, nadir_deviation, settling_time, mppt_efficiency, thd_current
export dynamics_linearized, compute_A, modal_analysis, eigenvalue_locus_sweep

end # module

function run_pure_validation()
% RUN_PURE_VALIDATION  Run S1 + S3 pakai simulate_baseline_pure()
%   Output ke data/simulink_ref/matlab_{s1,s3}_C4.csv
%   Format match dengan julia_*_C4.csv (export_to_csv.jl).
%
% Stage-1 cross-implementation validation: pure-MATLAB averaged model
% mirroring julia/src/models/system_average.jl line-by-line. Validates
% that Julia code is bug-free at numerical/library level. Stage-2
% (Simulink + Simscape Electrical) bisa ditambah untuk switching-level
% fidelity nanti.

    addpath(genpath(fullfile(fileparts(mfilename('fullpath')))));

    params = pv_bess_vic_params();

    % C4 PROPOSED flags
    flags.use_vic            = true;
    flags.use_adaptive_vic   = true;
    flags.use_fuzzy_vic      = false;
    flags.use_adaptive_coord = true;
    flags.use_bess           = true;

    repo_root = fullfile(fileparts(mfilename('fullpath')), '..');
    out_dir = fullfile(repo_root, 'data', 'simulink_ref');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    %% --- S1: Normal load step +5% ---
    fprintf('\n>>> S1 normal load step +5%% at t=2s\n');
    P_BASE_S1 = 0.99 * params.P_rated;
    P_STEP_S1 = 0.05 * params.P_rated;
    G_profile      = @(t) 1000.0;
    T_profile      = @(t) 30.0;
    P_load_profile = @(t) (t<2.0)*P_BASE_S1 + (t>=2.0)*(P_BASE_S1 + P_STEP_S1);

    tic
    sol1 = simulate_baseline_pure(params, [0.0, 10.0], ...
                                   G_profile, T_profile, P_load_profile, ...
                                   4.0, 5.0, flags);
    fprintf('S1 simulation time: %.1f s\n', toc);

    save_csv(sol1, 's1', out_dir);
    print_metrics(sol1, 's1');

    %% --- S3: Generator loss equivalent +10% ---
    fprintf('\n>>> S3 generator loss equivalent +10%% at t=2s\n');
    P_BASE_S3 = 0.95 * params.P_rated;
    P_STEP_S3 = 0.10 * params.P_rated;
    P_load_profile = @(t) (t<2.0)*P_BASE_S3 + (t>=2.0)*(P_BASE_S3 + P_STEP_S3);

    tic
    sol3 = simulate_baseline_pure(params, [0.0, 10.0], ...
                                   G_profile, T_profile, P_load_profile, ...
                                   4.0, 5.0, flags);
    fprintf('S3 simulation time: %.1f s\n', toc);

    save_csv(sol3, 's3', out_dir);
    print_metrics(sol3, 's3');

    fprintf('\n=== DONE ===\n');
end


function save_csv(sol, scenario_id, out_dir)
% Resample ke 1 ms grid (sama dengan Julia output) lalu tulis CSV
    Ts_log = 1e-3;
    t_grid = (0:Ts_log:sol.t(end))';
    V_dc_const = 1200.0 * ones(size(t_grid));

    T = table(t_grid, ...
              interp1(sol.t, sol.f,     t_grid), ...
              interp1(sol.t, sol.rocof, t_grid), ...
              V_dc_const, ...
              interp1(sol.t, sol.Pmppt, t_grid), ...
              interp1(sol.t, sol.Pvic,  t_grid), ...
              interp1(sol.t, sol.Pref,  t_grid), ...
              interp1(sol.t, sol.Pgrid, t_grid), ...
              interp1(sol.t, sol.Pbess, t_grid), ...
              interp1(sol.t, sol.SOC,   t_grid), ...
              interp1(sol.t, sol.alpha, t_grid), ...
              interp1(sol.t, sol.beta,  t_grid), ...
              interp1(sol.t, sol.H,     t_grid), ...
              'VariableNames', ...
              {'t','f','rocof','V_dc','P_mppt','P_vic','P_ref',...
               'P_inj','P_bess','SOC','alpha','beta','H_eff'});
    fname = fullfile(out_dir, sprintf('matlab_%s_C4.csv', scenario_id));
    writetable(T, fname);
    fprintf('  CSV: %s (%d rows)\n', fname, height(T));
end


function print_metrics(sol, scenario_id)
% Print quick metrics untuk verifikasi vs Julia output
    t_event = 2.0;
    mask = sol.t >= t_event;
    f_post = sol.f(mask);
    rocof_post = sol.rocof(mask);

    f_min = min(f_post); f_max = max(f_post);
    nadir = f_min - 50.0;
    if abs(f_max - 50.0) > abs(nadir); nadir = f_max - 50.0; end

    rocof_max = max(abs(rocof_post(1:min(end, 10000))));  % first 500 ms post-event @ 50us
    fprintf('  [%s C4] RoCoF=%6.4f Hz/s  |Δf|=%7.5f Hz  SOC_end=%5.2f%%\n', ...
            scenario_id, rocof_max, abs(nadir), sol.SOC(end)*100);
end

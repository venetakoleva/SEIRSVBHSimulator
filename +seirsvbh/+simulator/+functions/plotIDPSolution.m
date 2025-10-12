% SPDX-License-Identifier: Apache-2.0
% Copyright (c) 2025 Veneta Koleva, Tsvetan Hristov
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy at http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%
% See NOTICE and CITATION.cff for attribution & citation details.

function plotIDPSolution(y)
% plotModelSEIRSVBH  Plot states and parameters from the inverse data solution.
% Uses a fixed calendar start date: 08-Jun-2020. No ODE solve here.

    
    % --- Force everything to column vectors ---
    S_mod = y.S(:); E_mod = y.E(:); I_mod = y.I(:); R_mod = y.R(:);
    V_mod = y.V(:); B_mod = y.B(:);  N_mod = y.N(:);

    % Parameters
    alpha_mod = y.alpha(:);  % vaccination parameter
    beta_mod  = y.beta(:);   % transmission
    gamma_mod = y.gamma(:);  % recovery (non-hosp)
    rho_mod   = y.rho(:);    % hospitalization
    sigma_mod = y.sigma(:);  % recovery (hosp)
    tau_mod   = y.tau(:);    % mortality

    startDate = datetime(2020,6,8);      % fixed

    %% STATES:
    K_state = min([ numel(S_mod), numel(E_mod), numel(I_mod), numel(R_mod), ...
                    numel(V_mod), numel(B_mod), numel(N_mod) ]);

    S_m = S_mod(1:K_state); E_m = E_mod(1:K_state); I_m = I_mod(1:K_state);
    R_m = R_mod(1:K_state); V_m = V_mod(1:K_state); B_m = B_mod(1:K_state);
    N_m = N_mod(1:K_state);

    t_states = startDate + days(0:K_state-1);

    set(groot, 'defaultAxesFontSize', 16);         

    %% PARAMETERS
    makeParamFig(startDate, alpha_mod, '\alpha - Vaccination parameter');
    makeParamFig(startDate, beta_mod,  '\beta - Transmission rate');
    makeParamFig(startDate, gamma_mod, '\gamma - Recovery rate of non-hospitalized individuals');
    makeParamFig(startDate, rho_mod,   '\rho - Hospitalization rate');
    makeParamFig(startDate, sigma_mod, '\sigma - Recovery rate of hospitalized individuals');
    makeParamFig(startDate, tau_mod,   '\tau - Mortality rate of infectious people');
end

% ========================= Helpers =========================

function makeParamFig(startDate, series, nameStr)
% faint daily line + small red daily dots + bold 7-day average
    series = series(:);
    K = numel(series);
    if K == 0
        warning('%s: empty series; skipping plot.', nameStr);
        return;
    end

    t = startDate + days(0:K-1);

    fig = figure('Name',nameStr,'NumberTitle','off','Position',[150 150 1000 400]);
    
    ax  = axes('Parent',fig); 
    hold(ax,'on');

    % Light grey line connecting the daily values (behind the dots)
    if K >= 2
        plot(ax, t, series, '-', 'LineWidth', 1.0, 'Color', [0.8 0.8 0.8], ...
             'HandleVisibility','off');
    end

    % Red dot at EACH daily value (smaller dots)
    scatter(ax, t, series, 5, 'filled', ...
        'MarkerFaceColor', [0.85 0 0], 'MarkerEdgeColor', 'none', ...
        'DisplayName','Daily value');

    % 7-day moving-average trend (use smaller window if K<7)
    w = 7;
    ma = movmean(series, [w-1 0], 'omitnan');
    ma(1:min(w-1,K)) = NaN;   % hide until full window exists
    plot(ax, t, ma, '-', 'LineWidth', 2.2, 'Color', [0 0.2 0.8], ...
        'DisplayName','7-day moving average');

    hold(ax,'off'); 
    grid(ax,'on'); grid(ax,'minor'); box(ax,'off');
  

    % Date axis styling
    seirsvbh.simulator.helpers.styleDateAxisHelper(ax, [startDate, startDate + days(max(K-1,1))], 'params'); %08-Jun

    title(ax, nameStr, 'FontSize', 16 ); ylabel(ax, 'Rate', 'FontSize', 16);

    % Ensure single-point plots are visible vertically
    if K == 1
        y0 = series(1); dy = max(abs(y0)*0.1, 1e-9);
        ylim(ax, [y0 - dy, y0 + dy]);
    end


    % === Legend INSIDE the plot ===
    if contains(nameStr, '\beta') || contains(nameStr,'\sigma') || contains(nameStr,'\gamma') || contains(nameStr,'\tau') 
        legend(ax, 'Location','northwest', 'FontSize',14, 'Box','on');
    else
        legend(ax, 'Location','northeast', 'FontSize',14, 'Box','on');
    end

end

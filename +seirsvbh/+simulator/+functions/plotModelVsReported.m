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

function plotModelVsReported(ODESol, reportedData)
%PLOTMODELVSREPORTED Plot model states against reported (observed) data.
%
%   plotModelVsReported(ODESol, reportedData)
%   plots time series from the ODE solution together with the corresponding
%   reported (observed) states for visual comparison.

    % Prefer provided model start date; fall back to fixed date
    defaultStart = datetime(2020,6,8);

    % ===== Model dates =====
    if isfield(ODESol,'dates')
        tModAll = ODESol.dates(:);
    else
        modLen  = numel(ODESol.S);
        modStart = defaultStart;
        if isfield(ODESol,'startDate'); modStart = ODESol.startDate; end
        tModAll = modStart + days(0:modLen-1);
    end

    % ===== Reported dates (only needed for comparisons) =====
    if isfield(reportedData,'dates')
        tRepAll = reportedData.dates(:);
    else
        if isfield(reportedData,'A')
            repLen = numel(reportedData.A);
        elseif isfield(reportedData,'Htotal')
            repLen = numel(reportedData.Htotal);
        else
            repLen = 0;
        end
        repStart = defaultStart;
        if isfield(reportedData,'startDate'); repStart = reportedData.startDate; end
        tRepAll = repStart + days(0:max(repLen-1,0));
    end

    % ===== Model series =====
    S_mod = ODESol.S(:);
    E_mod = ODESol.E(:);
    I_mod = ODESol.I(:);
    R_mod = ODESol.R(:);
    V_mod = ODESol.V(:);
    B_mod = ODESol.B(:);
    H_mod = ODESol.H(:);

    % Total population N = S+E+I+R+V+B+H
    N_mod = S_mod + E_mod + I_mod + R_mod + V_mod + B_mod + H_mod;

    % FIGURE 1: N & S (model only) 
    figure('Name','Components of model solution N and S','NumberTitle','off','Position',[150 150 1000 400]);
    plot(tModAll, N_mod, 'b', 'LineWidth',1.6, 'DisplayName','Total population N'); hold on;
    plot(tModAll, S_mod, 'm', 'LineWidth',1.6, 'DisplayName','Susceptible S'); hold off;
    grid on;
    legend('Location','west','FontSize',14,'Box','on');
    seirsvbh.simulator.helpers.styleDateAxisHelper(gca, tModAll);
    title('Component of model solution: N and S', 'FontSize',16 , 'Interpreter','tex'); %avoid override
    ylabel('Individuals', 'FontSize',16); xlabel('Time', 'FontSize',16);

    % FIGURE 2: I, V together
    figure('Name','Components of model solution I, V','NumberTitle','off','Position',[150 150 1000 400]);
    hold on;
    plot(tModAll, I_mod, 'Color', [0.55 0.37 0.67] , 'LineWidth',1.8, 'DisplayName','I (Infectious)');
    plot(tModAll, V_mod, 'Color', [0   0.39 0],'LineWidth',1.8, 'DisplayName','V (Vaccinated susceptible)');
    hold off;
    grid on;
    legend('Location','northeast','FontSize',14,'Box','on');
    seirsvbh.simulator.helpers.styleDateAxisHelper(gca, tModAll);
    title('Components of model solution: I and V', 'FontSize',16 ,'Interpreter','tex');
    ylabel('Individuals', 'FontSize',16); xlabel('Time', 'FontSize',16);

    
    % FIGURE 3: E, H together
    figure('Name','Components of model solution E, H','NumberTitle','off','Position',[150 150 1000 400]);
    hold on;
    plot(tModAll, E_mod, 'Color', [0.80 0.08 0.45], 'LineWidth',1.8, 'DisplayName','E (Exposed)');
    plot(tModAll, H_mod, 'Color', [0 0.6 0.6], 'LineWidth',1.8, 'DisplayName','H (Hospitalized)');

    hold off;
    grid on;
    legend('Location','northeast','FontSize',14,'Box','on');
    seirsvbh.simulator.helpers.styleDateAxisHelper(gca, tModAll);
    title('Components of model solution: E and H', 'FontSize',16 ,'Interpreter','tex');
    ylabel('Individuals', 'FontSize',16); xlabel('Time', 'FontSize',16);

    %  FIGURE 4: R and B together
    figure('Name','Components of model solutions R and B','NumberTitle','off','Position',[150 150 1000 400]);
    hold on;
    plot(tModAll, R_mod, 'Color', [1   0.55 0],  'LineWidth',1.8, 'DisplayName','R (Recovered)');
    plot(tModAll, B_mod, 'Color', [0.29 0   0.51], 'LineWidth',1.8, 'DisplayName','B (Vaccination-acquired immunity)');
    hold off;
    grid on;
    legend('Location','northwest','FontSize',14,'Box','on');
    seirsvbh.simulator.helpers.styleDateAxisHelper(gca, tModAll);
    title('Components of model solutions: R and B', 'FontSize', 16, 'Interpreter','tex');
    ylabel('Individuals','FontSize',16); xlabel('Time', 'FontSize',16);

    % ===================== FIGURES: Model vs Reported (A, totals) =====================
    comps = {
        'A',       'A',  'Component of model solution: A = E + I + H',          'Individuals';
        'Vtotal',  'Vt', 'Component of model solution: Vtotal',              'Individuals (cumulative)';
        'Rtotal',  'Rt', 'Component of model solution: Rtotal',              'Individuals (cumulative)';
        'Dtotal',  'Dt', 'Component of model solution: Dtotal',              'Individuals (cumulative)';
        'Htotal',  'Ht', 'Component of model solution: Htotal',              'Individuals (cumulative)'
    };

    for i = 1:size(comps,1)
        repField = comps{i,1};
        modField = comps{i,2};
        ttl      = comps{i,3};
        ylab     = comps{i,4};

        if ~isfield(reportedData, repField) || ~isfield(ODESol, modField)
            continue;
        end

        repSeries = reportedData.(repField)(:);
        modSeries = ODESol.(modField)(:);

        [tCommon, iaRep, iaMod] = intersect(tRepAll, tModAll);
        if isempty(tCommon); continue; end

        repC = repSeries(iaRep);
        modC = modSeries(iaMod);

        figure('Name',['Components of Model vs Reported:' ttl], 'NumberTitle','off','Position',[150 150 1000 400]);
        plot(tCommon, repC, 'k', 'LineWidth',1.8,'DisplayName','Reported'); hold on;
        plot(tCommon, modC, 'm', 'LineWidth',1.8, 'DisplayName','Model');
        grid on; 
        if strcmp(repField,'A')
            legend('Location','northeast','FontSize',14,'Box','on');
        else
            legend('Location','northwest','FontSize',14,'Box','on');
        end
        seirsvbh.simulator.helpers.styleDateAxisHelper(gca, tCommon);
        title(ttl, 'FontSize',16, 'Interpreter','tex'); ylabel(ylab, 'FontSize', 16); xlabel('Time','FontSize', 16);
        hold off;
    end
end

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

function runIDPandDirectDriver()
% RUNIDPANDDIRECTSOLVER
% Driver script to:
%   - load the best (xi,c) pair from results.mat (found by the error analysis),
%   - solve the Inverse Data Problem (IDP) SEIRSVBH model with best (xi, c),
%   - plot the IDP parameter time series,
%   - run the direct ODE solver with the estimated parameters,
%   - plot the direct–solver component solutions alongside reported data.
%
% This script assumes runRelativeErrorsSolver.m has already been executed
% and that results.mat exists in the working directory.

    close all; clc;
    t0 = datetime('now');
    fprintf('=== runIDPandDirectSolver started %s ===\n', string(t0,'yyyy-MM-dd HH:mm:ss'));

    %% Load data/params
    try
         reportedData = seirsvbh.simulator.helpers.loadReportedData();
    catch ME
        error("Failed to load reported data: "  + ME.message);
    end

    %% Pick (xi,c) from results, +/-5 window for c, no output in console
    matFile = 'results.mat';
    try
        [~,~,~,~,xiMinSum,cMinSum] = seirsvbh.simulator.functions.summarizeRelativeErrorsFromMat(matFile, 5, true);
    catch ME
        error("Could not read results.mat: " + ME.message);
    end

    xi = xiMinSum;  % choose which optimum you prefer
    c  = cMinSum;
    h  = 1.0;         % must be exactly 1 day
    psiFunc = @seirsvbh.simulator.helpers.psiQuadratic;

    %% Sanity check
    try
       seirsvbh.simulator.helpers.checkH(h);
    catch ME
        error("Error in h value: "  + ME.message);
    end

    %% Solve the IDP
    try
        idpSol = seirsvbh.simulator.functions.IDPSolver(xi, h, c, psiFunc, reportedData);
    catch ME
        error("Error in IDPSolver: "  + ME.message);
    end

    %% Plot IDP solution
    try
        seirsvbh.simulator.functions.plotIDPSolution(idpSol);
    catch ME
        warning("plotIDPSolution failed: " + ME.message);
    end

    %% Direct solver with IDP parameters
    try
        ODESol = seirsvbh.simulator.functions.directProblemSolver(idpSol, reportedData, h);
    catch ME
        error("Error in directProblemSolver: " + ME.message);
    end

    %% Plot model vs reported
    try
        seirsvbh.simulator.functions.plotModelVsReported(ODESol, reportedData);
    catch ME
        warning("plotModelVsReported failed:" + ME.message);
    end

    t1 = datetime('now');
    fprintf('=== Finished %s (%.2f s) ===\n', string(t1,'yyyy-MM-dd HH:mm:ss'), seconds(t1 - t0));
end

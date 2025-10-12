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


function runRelativeErrorsDriver()
% RUNRELATIVEERRORSSOLVER
% Driver script to:
%   -compute relative l2 and linf errors on a user–defined (xi, c) grid,
%   - save the error matrices to results.mat,
%   - summarise the best (xi,c) according to L2, Linf and their sum,
%   - plot the error surfaces/contours.
%
% This script only performs the parameter–sweep / error–analysis stage.
% It does not solve the IDP or run the direct ODE solver.

    close all; clc;
    t0 = datetime('now');
    fprintf('=== runRelativeErrorsSolver started %s ===\n', string(t0,'yyyy-MM-dd HH:mm:ss'));

    %% Load data/params
    try
        reportedData = seirsvbh.simulator.helpers.loadReportedData();
    catch ME
        error("Failed to load reported data: "  + ME.message);
    end

    %% Configuration
    xi_list = 0 : 0.005 : 1;
    c_list  = -0.25 : 0.005 : 0.25;

    h       = 1;                   
    psiFunc = @seirsvbh.simulator.helpers.psiQuadratic;
    matFile = 'results.mat';
    maxWorkers   = 10;
    parallelMode = 'ii';

    %% Sanity checks
    try
        seirsvbh.simulator.helpers.checkInputParams(xi_list, c_list);
    catch ME
        error("Input parameter check failed: " + ME.message);
    end
    try
        seirsvbh.simulator.helpers.checkH(h);
    catch ME
        error("Error in h value: " + ME.message);
    end

    %% Compute relative errors
    fprintf('Computing on grid %dx%d (xi x c)...\n', numel(xi_list), numel(c_list));
    try
        tComp = tic;
        [l2mat,linfmat,usedParallel,nWorkersUsed] = ...
            seirsvbh.simulator.functions.computeRelativeErrorsParallel(xi_list, c_list, h, psiFunc, reportedData, maxWorkers, parallelMode);
        fprintf('usedParallel=%d, nWorkersUsed=%d, elapsed=%.2fs\n', usedParallel, nWorkersUsed, toc(tComp));
    catch ME
        error("Error in computeRelativeErrorsParallel: " + ME.message);
    end

    %% Save results
    try
        seirsvbh.simulator.functions.saveRelativeErrors(xi_list, c_list, l2mat, linfmat, matFile);
        fprintf('Saved results to "%s".\n', matFile);
    catch ME
        error("Error saving results: "  + ME.message);
    end

    %% Summarize best (xi,c)
    try
        seirsvbh.simulator.functions.summarizeRelativeErrorsFromMat(matFile);
    catch ME
        warning("Could not summarize relative errors: " + ME.message);
    end

    %% Plot from MAT
    try
        seirsvbh.simulator.functions.plotRelativeErrorsFromMatFile(matFile);
    catch ME
        warning("Plotting relative errors failed: " + ME.message);
    end

    t1 = datetime('now');
    fprintf('=== Finished %s (%.2f s) ===\n', string(t1,'yyyy-MM-dd HH:mm:ss'), seconds(t1 - t0));
end

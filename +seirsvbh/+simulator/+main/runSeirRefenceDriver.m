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

function runSeirRefenceDriver()
%RUNSEIRREFERENCEDRIVER
% Driver script to:
%   - solve the SEIR inverse data problem (IDPSolverSeir) on the
%     reported COVID-19 data,
%   - compute relative L2 and Linf errors for the SEIR model
%     (computeRelativeErrorsAtSeir)
%   
% This code references https://doi.org/10.1063/5.0041868 
%

    close all; clc;
    t0 = datetime('now');
    fprintf('=== runSEIRReferenceDriver started %s ===\n', ...
        string(t0,'yyyy-MM-dd HH:mm:ss'));

    %% Load reported data
    try
        reportedData = seirsvbh.simulator.helpers.loadReportedData();
    catch ME
        error("Failed to load reported data: "  + ME.message);
    end

    h = 1.0;   % time step in days (SEIR is daily here)

    %% 1) Inverse step: SEIR IDP -> E, I, beta, gamma
    fprintf('Solving the SEIR Inverse Problem (IDPSolverSeir)...\n');
    try
        ySeir = seirsvbh.simulator.functions.IDPSolverSeir(reportedData);
    catch ME
        error("IDPSolverSeir failed: " + ME.message);
    end

    %% 2) Error evaluation: SEIR vs reported data
    fprintf('Computing SEIR relative errors (A, R)...\n');
    try
        [rell2_Seir, relInf_Seir] = ...
            seirsvbh.simulator.functions.computeRelativeErrorsAtSeir( ...
                ySeir, h, reportedData);
    catch ME
        error("computeRelativeErrorsAt_SEIR failed: " + ME.message);
    end

    fprintf('SEIR reference: relative l2 error  = %.6f\n', rell2_Seir);
    fprintf('SEIR reference: relative l_inf error = %.6f\n', relInf_Seir);

    t1 = datetime('now');
    fprintf('=== Finished %s (%.2f s) ===\n', ...
        string(t1,'yyyy-MM-dd HH:mm:ss'), seconds(t1 - t0));
end

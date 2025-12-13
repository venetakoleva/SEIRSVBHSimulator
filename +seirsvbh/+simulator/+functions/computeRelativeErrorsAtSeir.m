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

function [relErrL2, relErrInf] = computeRelativeErrorsAtSeir(ySeir, h, reportedData)
%COMPUTERELATIVEERRORSATSEIR
%   Compute relative l2 and linf errors for the SEIR model
%   The reported series are:
%       A_rep = reportedData.A
%       R_rep = reportedData.Rtotal + reportedData.Dtotal
%
%   Outputs:
%       relErrL2  : sum of relative l2 errors over A, R
%       relErrInf : sum of relative linf errors over A, R
%
% This code references https://doi.org/10.1063/5.0041868 
%

    % 1) Create data structure and assign model calculated data
    dataSeir = ySeir;

    dataSeir.omega  = reportedData.omega;

    % 1) Initial conditions for SEIR
    I1 = reportedData.I1;
    N1 = reportedData.N1;
    R1 = reportedData.Rtotal(1) + reportedData.Dtotal(1);

    % Active A = E + I
    A1 = reportedData.A(1);
    E1 = A1 - I1;
    if E1 < 0
        warning('computeRelativeErrorsASeir: E1 < 0 (value %.6g).', E1);
    end
    S1 = N1 - (E1 + I1 + R1);

   
    %initial conditions
    y0 = [S1; E1; I1; R1];   % SEIR state at t=0

    % ----- 2) ODE solve -> day-end states -----
    [~, Y_days] = seirsvbh.simulator.functions.cauchyProblemSolverSeir(dataSeir, y0, h);
    % Y_days columns: [S E I R]

    % ----- 3) Model series -----
    S_mod = Y_days(:,1);
    E_mod = Y_days(:,2);
    I_mod = Y_days(:,3);
    R_mod = Y_days(:,4);

    A_mod = E_mod + I_mod;     % SEIR Active = E + I

    % ----- 4) Reported series -----
    A_rep = reportedData.A(:);
    % Removed data: R = Rtotal + Dtotal
    R_rep = reportedData.Rtotal(:) + reportedData.Dtotal(:);

    % ----- 5) Align to common length -----
    m = min([numel(A_rep), numel(A_mod), numel(R_rep), numel(R_mod)]);
    if m == 0
        error('computeRelativeErrorsAtSeir: Empty alignment lengths.');
    end

    A_r = A_rep(1:m);  A_m = A_mod(1:m);
    R_r = R_rep(1:m);  R_m = R_mod(1:m);

    % ----- 6) Relative L2 error -----
    relA  = norm(A_r - A_m, 2) / norm(A_r, 2);
    relR  = norm(R_r - R_m, 2) / norm(R_r, 2);

    relErrL2 = relA + relR;

    % ----- 7) Relative Linf error -----
    relA_inf = norm(A_r - A_m, inf) / norm(A_r, inf);
    relR_inf = norm(R_r - R_m, inf) / norm(R_r, inf);

    relErrInf = relA_inf + relR_inf;
end

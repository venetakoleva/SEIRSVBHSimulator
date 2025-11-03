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

function [relErrl2, relErrInf] = computeRelativeErrorsAt(xi, c, h, psiFunc, reportedData)
%COMPUTERELATIVEERRORSAT  Compute relative l2 and linf errors for given
%(xi,c).
     

    % 1) Inverse step -> parameters
    y = seirsvbh.simulator.functions.IDPSolver(xi, h, c,  psiFunc, reportedData);

    % 2) Create data structure and assign model calculated data
    data = y;
    % add reported data to structure to pass to ODE solver later
    data.Lambda = reportedData.Lambda;
    data.theta  = reportedData.theta;
    data.omega  = reportedData.omega;
    data.lambda = reportedData.lambda;
    data.nu     = reportedData.nu;
    data.mu     = reportedData.mu;
    data.phi = reportedData.phi;

    % 3) Initial conditions
    N1 = reportedData.N1; I1 = reportedData.I1;
    R1 = reportedData.R1;
    H1 = reportedData.H(1);
    E1 = reportedData.A(1) - I1 - H1;
    V1 = reportedData.V1; 
    B1 = reportedData.B1; 
    S1 = N1 - (E1 + I1 + R1 + V1 + B1 + H1);

    Rt1 = reportedData.Rtotal(1);
    Ht1 = reportedData.Htotal(1);
    Vt1 = reportedData.Vtotal(1);
    Dt1 = reportedData.Dtotal(1);

    y0 = [S1; E1; I1; R1; V1; B1; H1; Rt1; Ht1; Vt1; Dt1];

    % 4) ODE solve -> day-end states
    [~, Y_days] = seirsvbh.simulator.functions.cauchyProblemSolver(data, y0, h);   % columns: [S E I R V B H Rt Ht Vt Dt]

    % 5) Model series
    E_mod  = Y_days(:,2); 
    I_mod  = Y_days(:,3); 
    H_mod  = Y_days(:,7);
    A_mod  = E_mod + I_mod + H_mod;
    Rt_mod = Y_days(:,8);
    Ht_mod = Y_days(:,9);
    Vt_mod = Y_days(:,10);
    Dt_mod = Y_days(:,11);

  

    % 6) Reported series
    A_rep  = reportedData.A(:);
    H_rep  = reportedData.H(:);
    Rt_rep = reportedData.Rtotal(:);
    Vt_rep = reportedData.Vtotal(:);
    Ht_rep = reportedData.Htotal(:);
    Dt_rep = reportedData.Dtotal(:);
    

    % 7) Align to common length
    m = min([numel(A_rep), numel(A_mod), numel(Rt_rep), numel(H_rep), numel(Rt_mod), ...
             numel(Vt_rep), numel(Vt_mod), numel(Ht_rep), numel(Ht_mod), ...
             numel(Dt_rep), numel(Dt_mod)]);
    if m == 0
        error('Empty alignment lengths.');
    end

    A_r  = A_rep(1:m);  A_m  = A_mod(1:m);
    H_r  = H_rep(1:m);  H_m  = H_mod(1:m);
    Rt_r = Rt_rep(1:m); Rt_m = Rt_mod(1:m);
    Vt_r = Vt_rep(1:m); Vt_m = Vt_mod(1:m);
    Ht_r = Ht_rep(1:m); Ht_m = Ht_mod(1:m);
    Dt_r = Dt_rep(1:m); Dt_m = Dt_mod(1:m);


    % % 8) Relative L2 error
    relA  = norm(A_r  - A_m , 2) / norm(A_r , 2);
    relH  = norm(H_r  - H_m , 2) / norm(H_r , 2);
    relRt = norm(Rt_r - Rt_m, 2) / norm(Rt_r, 2);
    relVt = norm(Vt_r - Vt_m, 2) / norm(Vt_r, 2);
    relHt = norm(Ht_r - Ht_m, 2) / norm(Ht_r, 2);
    relDt = norm(Dt_r - Dt_m, 2) / norm(Dt_r, 2);  

    relErrl2 = relA + relH + relRt + relVt + relHt + relDt;

    % 9) Relative L∞ error
    relA_inf  = norm(A_r  - A_m , inf) / norm(A_r , inf);
    relH_inf  = norm(H_r  - H_m , inf) / norm(H_r , inf);
    relRt_inf = norm(Rt_r - Rt_m, inf) / norm(Rt_r, inf);
    relVt_inf = norm(Vt_r - Vt_m, inf) / norm(Vt_r, inf);
    relHt_inf = norm(Ht_r - Ht_m, inf) / norm(Ht_r, inf);
    relDt_inf = norm(Dt_r - Dt_m, inf) / norm(Dt_r, inf);  

    relErrInf = relA_inf +relH_inf + relRt_inf + relVt_inf + relHt_inf + relDt_inf;

end

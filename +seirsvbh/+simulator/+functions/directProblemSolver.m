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

function ODESol = directProblemSolver(yModel, reportedData, h)

%   DIRECTPROBLEMSOLVER Solve the SEIRSVBH forward model on a daily grid.
%   runOdeWithModelParams  Build parameters from yModel + known reported parameters,
%   set initial conditions from reportedData, and solve the ODE day-ends.
%   DirectProblemSolver
%   Output ODESol has fields:
%   t, S,E,I,R,V,B,H, Rt,Ht,Vt,Dt, A

    % ---- merge parameters for ODE ----
    data = yModel;  % alpha,beta,gamma,rho,sigma,tau come from the inverse model
    % add known (time series) from data if present
    toCopy = {'Lambda','theta','omega','lambda','nu','mu','phi'};
    for k = 1:numel(toCopy)
        fn = toCopy{k};
        if isfield(reportedData, fn)
            data.(fn) = reportedData.(fn);
        end
    end

    % now we have a structure that holds the full data both from the IDP model and
    % reportedData
    fullData = data;

    % ---- initial conditions from reported data (day 1) ----
    N1  = reportedData.N1;
    I1  = reportedData.I1;
    R1  = reportedData.R1;

    H1  = reportedData.H(1);
    E1  = reportedData.A(1) - I1 - H1;
    V1  = 0;
    B1  = 0;
    S1  = N1 - (E1 + I1 + R1 + V1 + B1 + H1);

    RtTot1 = reportedData.Rtotal(1);
    HtTot1 = reportedData.Htotal(1);
    VtTot1 = reportedData.Vtotal(1);
    DtTot1 = reportedData.Dtotal(1);

    y0 = [S1; E1; I1; R1; V1; B1; H1; RtTot1; HtTot1; VtTot1; DtTot1];

    % ---- solve ODE day-by-day  ----
    [t_days, Y_days] = seirsvbh.simulator.functions.cauchyProblemSolver(fullData, y0, h);   % K×1, K×11

    % ---- unpack + derive A ----
    ODESol.t  = t_days(:);
    ODESol.S  = Y_days(:,1);
    ODESol.E  = Y_days(:,2);
    ODESol.I  = Y_days(:,3);
    ODESol.R  = Y_days(:,4);
    ODESol.V  = Y_days(:,5);
    ODESol.B  = Y_days(:,6);
    ODESol.H  = Y_days(:,7);
    ODESol.Rt = Y_days(:,8);   % Rtotal
    ODESol.Ht = Y_days(:,9);   % Htotal
    ODESol.Vt = Y_days(:,10);  % Vtotal
    ODESol.Dt = Y_days(:,11);  % Dtotal
    ODESol.A  = ODESol.E + ODESol.I + ODESol.H;
end

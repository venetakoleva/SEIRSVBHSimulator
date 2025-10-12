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

function reportedData = loadReportedData()
% LOADREPORTEDDATA  Load states data and known parameters.
%
% Returns a struct containing:
%   - known states  (A, H, Rtotal, Vtotal, Dtotal, Htotal, I1, N1, R1)
%   - known parameters (Lambda, theta, omega, lambda, nu, mu, phi)
%
% Data are loaded from:
%   BGDataKnown.mat   and
%   BGParamKnown.mat
%
% Usage:
%   reportedData = loadReportedData();

    % Load the two MAT files
    S = load(fullfile('+seirsvbh/simulator/data', 'BGDataKnown.mat'),  'A','H','Rtotal','Vtotal','Dtotal','Htotal','I1','N1','R1');
    P = load(fullfile('+seirsvbh/simulator/data', 'BGParamKnown.mat'), 'Lambda','theta','omega','lambda','nu','mu','phi');

    % Combine into a single structure
    reportedData = struct( 'Lambda', P.Lambda, 'theta', P.theta, 'omega', P.omega, 'lambda', P.lambda, 'nu', P.nu, 'mu', P.mu, 'phi', P.phi, 'A', S.A, 'H', S.H, 'Vtotal', S.Vtotal, 'Rtotal', S.Rtotal, 'Dtotal', S.Dtotal, 'Htotal', S.Htotal, 'I1', S.I1, 'N1', S.N1, 'R1', S.R1);
end

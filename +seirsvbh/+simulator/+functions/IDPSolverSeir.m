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

function y = IDPSolverSeir(reportedData)
%IDPSOLVERSEIR  Inverse data problem for a time–dependent SEIR model.
%
%   y = IDPSolverSeir(reportedData) reconstructs the SEIR parameters beta_k and gamma_k (k = 1..L-1)
%
%    SEIR model:
%       dS/dt = - beta(t) * S(t) * I(t) / N
%       dE/dt =   beta(t) * S(t) * I(t) / N - omega(t) * E(t)
%       dI/dt =   omega(t) * E(t) - gamma(t) * I(t)
%       dR/dt =   gamma(t) * I(t)
%    
%       Algorithm implementation follows https://doi.org/10.1063/5.0041868 

    L = length(reportedData.A);

    % preallocate unknowns
    I = zeros(L,1);
    Ibeta  = zeros(L-1,1);
    Igamma = zeros(L-1,1);
    beta  = zeros(L-1,1);
    gamma = zeros(L-1,1);

    % Know data and initial conditions
    A = reportedData.A;                           % active A_k
    R = reportedData.Rtotal + reportedData.Dtotal;  % removed R_k (R = Rtotal + Dtotal)
    N = reportedData.N1;
    omega = reportedData.omega;
    I(1) = reportedData.I1;
    % Susceptibles: S_k = N - A_k - R_k
    S = N - A - R;

    if numel(R) ~= L
        error('IDPSolverSeir: A and (Rtotal+Dtotal) must have the same length.');
    end


   % Implementation of the algorithm
    for k = 2:L
        % Step 5:
        if S(k-1) == 0
            warning('IDPSolverSeir: S(k-1) = 0 at k=%d; division by zero.', k);
        end

        %Step 5
        Ibeta(k-1)  = (-N * (S(k) - S(k-1))) / S(k-1);

        
        Igamma(k-1) = R(k) - R(k-1);

        % Step 6:
        I(k) = (1 - omega(k-1))*I(k-1) + omega(k-1)*A(k-1) - Igamma(k-1);

        if I(k) < 0
            warning('IDPSolver_SEIR: I(k) < 0 at k=%d (%.6g).', k, I(k));
        end
    end

    % Exposed: E_k = A_k - I_k
    E = A - I;

    % Display a warning if any calculated value is not biologically reasonable
    if any(S < 0), warning('IDPSolver_SEIR: S(k) < 0 at some k (min S = %.6g).', min(S)); end
    if any(E < 0), warning('IDPSolver_SEIR: E(k) < 0 at some k (min E = %.6g).', min(E)); end
    if any(I < 0), warning('IDPSolver_SEIR: E(k) < 0 at some k (min E = %.6g).', min(E)); end
    if any(R < 0), warning('IDPSolver_SEIR: R(k) < 0 at some k (min R = %.6g).', min(R)); end
    
    %  Step 7: Compute beta_k and gamma_k (k = 1..L-1) 
    for k = 1:L-1

        if I(k) == 0
            warning('IDPSolver_SEIR: I(k) = 0 at k=%d; beta,gamma set to NaN.', k);
            beta(k)  = NaN;
            gamma(k) = NaN;
        else
            beta(k)  = Ibeta(k)  / I(k);
            gamma(k) = Igamma(k) / I(k);
        end


        % Display a warning if any calculated value is not biologically reasonable
        if beta(k) < 0, warning('IDPSolverSeir: beta(%d) < 0 (%.6g).', k, beta(k)); end
        if gamma(k) < 0, warning('IDPSolverSeir: gamma(%d) < 0 (%.6g).', k, gamma(k)); end
    end

    % ----- Output structure -----
    y = struct( ...
        'beta',  beta, ...
        'gamma', gamma, ...
        'omega', omega, ...
        'S',     S, ...
        'E',     E, ...
        'I',     I, ...
        'R',     R, ...
        'N',     N );
end
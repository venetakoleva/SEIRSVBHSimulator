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

function [t_days, Y_days] = cauchyProblemSolverSeir(paramSEIR, y0, h)
%CAUCHYPROBLEMSOLVERSEIR
%   dS/dt = -beta(t) * S * I / N
%   dE/dt =  beta(t) * S * I / N - omega(t) * E
%   dI/dt =  omega(t) * E - gamma(t) * I
%   dR/dt =  gamma(t) * I
%
% This function mirrors the SEIRS-VBH cauchyProblemSolver.
%
% This code references https://doi.org/10.1063/5.0041868 
%

    beta  = paramSEIR.beta(:);
    gamma = paramSEIR.gamma(:);
    omega = paramSEIR.omega(:);

    K = numel(beta);
    if numel(gamma) ~= K || numel(omega) ~= K
        error('cauchyProblemSolverSeir: beta, gamma, omega must have same length.');
    end

    % Total population N: prefer paramSEIR.N if available, otherwise from y0
    if isfield(paramSEIR,'N') && ~isempty(paramSEIR.N)
        N = paramSEIR.N;
    else
        N = sum(y0);
    end

    % Preallocate (K+1) including initial state at t = 0
    t_days = zeros(K+1, 1);
    Y_days = zeros(K+1, numel(y0));

    % Place initial condition
    y_init      = y0(:);
    t_days(1)   = 0;
    Y_days(1,:) = y_init.';  

    for d = 1:K
        tspan = [(d-1)*h, d*h];

        % parameters for day d (1-based index)
        rhs = @(tt, Y) rhs_step_seir(Y, paramSEIR, d, N);

        [tt, Y] = ode45(rhs, tspan, y_init);

        % Store day-end state/time at index d+1
        t_days(d+1)   = tt(end);
        Y_days(d+1,:) = Y(end,:);

        % Next day's IC
        y_init = Y(end,:).';
    end
end

function dY = rhs_step_seir(Y, paramSEIR, idx, N)
%RHS_STEP_SEIR  Right-hand side of the SEIR ODE on day 'idx'.
%   Uses scalar parameters beta(idx), gamma(idx), omega(idx).

    S = Y(1);
    E = Y(2);
    I = Y(3);
    R = Y(4);

    beta_k  = paramSEIR.beta(idx);
    gamma_k = paramSEIR.gamma(idx);
    omega_k = paramSEIR.omega(idx);

    % SEIR dynamics with constant N
    dS = -beta_k * S * I / N;
    dE =  beta_k * S * I / N - omega_k * E;
    dI =  omega_k * E - gamma_k * I;
    dR =  gamma_k * I;

    dY = [dS; dE; dI; dR];
end

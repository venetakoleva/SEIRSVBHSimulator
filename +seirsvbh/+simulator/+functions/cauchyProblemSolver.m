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

function [t_days, Y_days] = cauchyProblemSolver(param, y0, h)
% ODESOLVER
% Piecewise-constant ODE solve over K days using parameter arrays in PARAM.
%
% Inputs
%   param : struct with 1×K arrays:
%           Lambda, theta, omega, lambda, nu, mu, alpha, beta, gamma, rho, sigma, tau
%   y0    : 11×1 initial state vector [S1; E1; I1; R1; V1; B1; H1; Rtotal; Htotal; Vtotal; Dtotal]
%   h     : step length (e.g., 1 day)
%
% Outputs
%   t_days : (K+1)×1 vector of day-end times (t = 0, h, 2h, ..., Kh)
%   Y_days : (K+1)×11 matrix of states at each day end, row 1 = initial state

    K = numel(param.beta);

   % Preallocate (K+1) to include the initial condition at t=0
    t_days = zeros(K+1, 1);
    Y_days = zeros(K+1, numel(y0));

    % Place initial condition
    y_init    = y0(:);
    t_days(1) = 0;
    Y_days(1,:) = y_init.';  

    for d = 1:K
        tspan = [(d-1)*h, d*h];
        rhs   = @(tt, Y) rhs_step(Y, param, d);  % parameters for day d
        [tt, Y] = ode45(rhs, tspan, y_init);

        % Store day-end state/time at index d+1
        t_days(d+1)   = tt(end);
        Y_days(d+1,:) = Y(end,:);

        % Next day's IC
        y_init = Y(end,:).';
    end
end
function dY = rhs_step(Y, param, t)
%RHS_STEP Right-hand side of the ODE on sub-interval t.
%   dY = RHS_STEP(Y, param, t) computes the state derivatives dY for the
%   current state Y using scalar parameters taken from param.*(t).

    S=Y(1); E=Y(2); I=Y(3); R=Y(4); V=Y(5); B=Y(6); H=Y(7);


    alpha   = param.alpha(t);
    beta   = param.beta(t);
    gamma   = param.gamma(t);
    rho  = param.rho(t);
    sigma  = param.sigma(t);
    tau = param.tau(t);
    phi = param.phi(t);
    if phi == 0
        a = 0; 
    else
        a = alpha/phi;
    end

    th  = param.theta(t);
    Lam = param.Lambda(t);
    lam = param.lambda(t);

    mu  = param.mu(t);
    nu  = param.nu(t);
    omg = param.omega(t);

    % SEIRVBH
    
    dS = - (alpha + th + (beta/(S + E + I + R + V + B + H))*I)*S + Lam*(S + E + I + R + V + B + H) + lam*R + nu*B;
    dE = - (omg + th)*E       + (beta/(S + E + I + R + V + B + H))*(S + V)*I;
    dI = - (gamma + rho + th)*I    + omg*E;
    dR = - (lam + th)*R       + gamma*I + sigma*H;
    dV = - (mu + th + (beta/(S + E + I + R + V + B + H))*I)*V + alpha*S;
    dB = - (nu + th)*B        + mu*V;
    dH = - (sigma + th + tau)*H  + rho*I;


    % Cumulative totals 
    dRtot = gamma*I + sigma*H;      
    dHtot = rho*I;            
    dVtot = a * (S + E + I + R + V + B + H);
    dDtot = tau*H;           
    dY = [dS; dE; dI; dR; dV; dB; dH; dRtot; dHtot; dVtot; dDtot];
end

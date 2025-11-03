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

function y = IDPSolver(xi, h, c, psiFunc, reportedData)
%IDPSOLVER Solve the SEIRSVBH inverse data problem (IDP).
%   y = IDPSolver(xi, h, c, psiFunc, reportedData) fits the model to the
%   reported data using the chosen psi and returns the IDP solution.
%   xi      : weight parameter
%   psiFunc : function handle to psi e.g., @seirsvbh.simulator.helpers.psiQuadratic.
%   h       : time step size
%   c       : parameter for psi, c > -1

psi_h = psiFunc(h,c);   %  evaluate ψ(h, c)


L = length(reportedData.A);

% preallocate unknowns
N = zeros(1,L); I = zeros(1,L); V = zeros(1,L); B = zeros(1,L);
R = zeros(1,L); E = zeros(1,L); S = zeros(1,L);
Htau   = zeros(1,L-1);
Irho   = zeros(1,L-1);
Hsigma = zeros(1,L-1);
Igamma = zeros(1,L-1);
alpha  = zeros(1,L-1);
Ibeta  = zeros(1,L-1);


% initial conditions 
N(1) = reportedData.N1;
I(1) = reportedData.I1;
V(1) = reportedData.V1; 
B(1) = reportedData.B1;
R(1) = reportedData.R1;
H(1) = reportedData.H(1);
E(1) = reportedData.A(1) - I(1) - reportedData.H(1);
S(1) = N(1) - E(1) - I(1) - R(1) - V(1) - B(1) - H(1);



% Implementation of the algorithm
% step 1
G = reportedData.A - reportedData.H;
H = reportedData.H;

for k = 2:L
    %step 2 
    Htau(k-1) = (reportedData.Dtotal(k) - reportedData.Dtotal(k-1)) / psi_h;

    %step 3
    Irho(k-1) = (reportedData.Htotal(k) - reportedData.Htotal(k-1)) / psi_h;

    % step 4
    Hsigma(k-1) = Irho(k-1) - (reportedData.H(k) - reportedData.H(k-1)) / psi_h  - Htau(k-1) - reportedData.theta(k-1) * reportedData.H(k-1);

    % Step 5
    % non-hospital recovery
    Igamma(k-1) = (reportedData.Rtotal(k) - reportedData.Rtotal(k-1)) / psi_h - Hsigma(k-1);
    
    % the vaccination coefficient
    alpha(k-1) = reportedData.phi(k-1) * ((reportedData.Vtotal(k) - reportedData.Vtotal(k-1)) /( psi_h* N(k-1)) ) ;

    % introduce notation
    Ibeta(k-1) = ( (G(k) - G(k-1)) / psi_h + reportedData.theta(k-1) * G(k-1) + Igamma(k-1) + Irho(k-1) )/ (S(k-1) + V(k-1));

    % check for biological reasonable property, non-negativity, up to 6digits
    if Hsigma(k-1) < 0, warning('Negative Hsigma at step %d: %.6g', k-1, Hsigma(k-1)); end
    if Igamma(k-1) < 0, warning('Negative Igamma at step %d: %.6g', k-1, Igamma(k-1)); end
    if alpha(k-1)  < 0, warning('Negative alpha at step %d: %.6g',  k-1, alpha(k-1));  end
    if Ibeta(k-1)  < 0, warning('Negative Ibeta at step %d: %.6g',  k-1, Ibeta(k-1));  end
    
    R(k) = (1 - psi_h * (reportedData.lambda(k-1) + reportedData.theta(k-1) ) ) * R(k-1)  + psi_h * ( Igamma(k-1) + Hsigma(k-1) );

    B(k) = (1 - psi_h * ( reportedData.nu(k-1) + reportedData.theta(k-1) ) )* B(k-1) + psi_h * reportedData.mu(k-1) * V(k-1);

    S(k) = (1 - psi_h * ( alpha(k-1) + reportedData.theta(k-1) +Ibeta(k-1) ) ) * S(k-1) + psi_h * (reportedData.Lambda(k-1)*N(k-1) + reportedData.lambda(k-1) * R(k-1) + reportedData.nu(k-1) * B(k-1));

    V(k) = (1 - psi_h * (reportedData.mu(k-1) + reportedData.theta(k-1) +Ibeta(k-1) ) ) * V(k-1) + psi_h * alpha(k-1) * S(k-1);

    I(k) = (1 - (reportedData.theta(k-1) + reportedData.omega(k-1))*psi_h) * I(k-1) +  psi_h * (reportedData.omega(k-1) * G(k-1) - Igamma(k-1) - Irho(k-1)) ;

    E(k) = G(k) - I(k);
    
    N(k)= S(k) + E(k) + I(k) + R(k) + V(k) + B(k) + H(k);

    % Display a warning if any calculated value is not biologically reasonable
    if S(k) < 0, warning('Negative S at step %d: %.6g', k, S(k)); end
    if E(k) < 0, warning('Negative E at step %d: %.6g', k, E(k)); end
    if I(k) < 0, warning('Negative I at step %d: %.6g', k, I(k)); end
    if R(k) < 0, warning('Negative R at step %d: %.6g', k, R(k)); end
    if V(k) < 0, warning('Negative V at step %d: %.6g', k, V(k)); end
    if B(k) < 0, warning('Negative B at step %d: %.6g', k, B(k)); end
    if N(k) < 0, warning('Negative N at step %d: %.6g', k, N(k)); end
end


% Step 6, calculate the parameters
beta  = N(1:end -1) .* Ibeta ./ ( xi * I(1:end-1) + (1 - xi) * I(2:end) );
gamma = Igamma ./ ( xi * I(1:end-1) + (1 - xi) * I(2:end) );
rho   = Irho ./ ( xi * I(1:end-1) + (1 - xi) * I(2:end) );
sigma = Hsigma ./ H(1:end-1);
tau   = Htau ./ H(1:end-1);


% Display a warning if any calculated value is not biologically reasonable
if any(beta < 0), warning('Negative beta values found.');  end
if any(gamma < 0), warning('Negative gamma values found.'); end
if any(rho < 0), warning('Negative rho values found.');   end
if any(sigma < 0), warning('Negative sigma values found.'); end
if any(tau < 0), warning('Negative tau values found.');   end



% the output structure
y = struct('alpha',alpha,'beta',beta,'gamma',gamma,'rho',rho,'sigma',sigma,'tau',tau, ...
           'S',S,'E',E,'I',I,'R',R,'V',V,'B',B, 'N',N);
end

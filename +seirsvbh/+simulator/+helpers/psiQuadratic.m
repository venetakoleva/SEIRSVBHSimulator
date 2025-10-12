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

function val = psiQuadratic(h,c)
    % psiQuadratic: 
    % We  consider the simple step function ψ(h) = h + c*h^2, for  0 < h ≤ 1, where c > −1 is a fixed constant
    % h : step size (scalar)
    % c : parameter (scalar)
    
    val = h - c*h.^2; 
end
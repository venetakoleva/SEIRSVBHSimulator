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

function checkInputParams(xi_list, c_list)
%CHECKINPUTPARAMS  Sanity checks for grids and time step.
%   - xi_list must be in [0, 1].
%   - c_list must be in [-0.25, 0.25].
%   - xi_list, c_list must have the same positive, non-zero step.
%   - Step must NOT be an integer value.
    % Basic type checks 
    if ~isnumeric(xi_list) || ~isnumeric(c_list)
        error('xi_list and c_list must be numeric vectors.');
    end
    if numel(xi_list) < 2 || numel(c_list) < 2
        error('Step size must not be an integer value.');
    end

     % ---- Range checks ----
    if any(xi_list < 0 | xi_list > 1)
        error('All elements of xi_list must be between 0 and 1.');
    end
    if any(c_list < -0.25 | c_list > 0.25)
        error('All elements of c_list must be between -0.25 and +0.25.');
    end

    % Compute step sizes 
    xi_step = mean(diff(xi_list));
    c_step  = mean(diff(c_list));
    if ~isscalar(xi_step) || ~isscalar(c_step) || ~isfinite(xi_step) || ~isfinite(c_step)
        error('Step size of xi_list or c_list is invalid.');
    end

    % Step must be positive and non-zero 
    if xi_step <= 0 || c_step <= 0
        error('Step sizes must be positive and non-zero.');
    end
end

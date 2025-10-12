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

function [l2mat, linfmat, usedParallel, nWorkersUsed] = computeRelativeErrorsParallel( ...
    xi_list, c_list, h, psiFunc, reportedData, numWorkers, mode)
%COMPUTERELATIVEERRORSPARALLEL
%  Parallel grid compute with pool management.
% - mode = 'ii'   -> parfor over rows (ii), inner for over columns (jj)
% - mode = 'jj'   -> parfor over columns (jj), inner for over rows (ii)
% - mode omitted or 'auto' -> chooses longer dimension
%
% Returns:
%   usedParallel  : true if parfor executed
%   nWorkersUsed  : number of workers used (0 if serial)
%   L2mat         : matrix of relative L2 errors
%   Linfmat       : matrix of relative Linf errors


    if nargin < 7 || isempty(mode), mode = 'auto'; end

    usedParallel = false;
    nWorkersUsed = 0;

    % --- Pool management (optional via numWorkers) ---
    if nargin >= 6 && ~isempty(numWorkers)
        try
            nWorkersUsed = ensurePoolExactly(numWorkers);
        catch E
            warning(E.identifier, '%s', E.message);
            nWorkersUsed = 0; % serial fallback if pool mgmt fails
        end
    else
        p = gcp('nocreate');
        if ~isempty(p), nWorkersUsed = p.NumWorkers; end
    end

    fprintf('[%s] computeRelativeErrorsParallel started...\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));

    % --- Grid + prealloc ---
    nXi = numel(xi_list);
    nC  = numel(c_list);
    [~, ~] = meshgrid(c_list, xi_list);  % nXi x nC
    L2mat   = nan(nXi, nC);
    Linfmat = nan(nXi, nC);

    % Decide orientation
    if strcmpi(mode, 'auto')
        runByRows = (nXi >= nC);
    else
        runByRows = strcmpi(mode, 'ii');
    end

    % --- Compute: try parallel, else serial fallback ---
    try
        if runByRows
            % parfor over rows (ii)
            parfor ii = 1:nXi
                L2row   = nan(1, nC);
                Linfrow = nan(1, nC);
                xiVal = xi_list(ii);
                for jj = 1:nC
                    cVal = c_list(jj);
                    try
                        [relL2, relInf] = seirsvbh.simulator.functions.computeRelativeErrorsAt(xiVal, cVal, h, psiFunc, reportedData);
                    catch E
                        warning(E.identifier, '%s', E.message);
                        relL2 = NaN; relInf = NaN;
                    end
                    L2row(jj)   = relL2;
                    Linfrow(jj) = relInf;
                end
                l2mat(ii, :)   = L2row;  
                linfmat(ii, :) = Linfrow;
            end
        else
            % parfor over columns (jj)
            parfor jj = 1:nC
                L2col   = nan(nXi, 1);
                Linfcol = nan(nXi, 1);
                cVal = c_list(jj);
                for ii = 1:nXi
                    xiVal = xi_list(ii);
                    try
                        [relL2, relInf] = seirsvbh.simulator.functions.computeRelativeErrorsAt(xiVal, cVal, h, psiFunc, reportedData);
                    catch E
                        warning(E.identifier, '%s', E.message);
                        relL2 = NaN; relInf = NaN;
                    end
                    L2col(ii)   = relL2;
                    Linfcol(ii) = relInf;
                end
                l2mat(:, jj)   = L2col;    
                linfmat(:, jj) = Linfcol;
            end
        end

        usedParallel = true;
        p = gcp('nocreate');
        if ~isempty(p), nWorkersUsed = p.NumWorkers; else, nWorkersUsed = 0; end

    catch E
        warning(E.identifier, '%s', E.message);
        % Serial fallback
        for ii = 1:nXi
            for jj = 1:nC
                xiVal = xi_list(ii);
                cVal  = c_list(jj);
                try
                    [relL2, relInf] = seirsvbh.simulator.functions.computeRelativeErrorsAt(xiVal, cVal, h, psiFunc, reportedData);
                catch E2
                    warning(E2.identifier, '%s', E2.message);
                    relL2 = NaN; relInf = NaN;
                end
                l2mat(ii, jj)   = relL2;
                linfmat(ii, jj) = relInf;
            end
        end
        usedParallel = false;
        nWorkersUsed = 0;
    end
end

% ================== helper ==================

function nUsed = ensurePoolExactly(nDesired)
% Start or reuse a pool targeting nDesired workers.
% Returns the number of workers actually available.

    nUsed = 0;

    if ~license('test','Distrib_Computing_Toolbox') || exist('parpool','file') ~= 2
        return;
    end

    % Hardware cap 
    try
        hw = feature('numcores');
        if ~isscalar(hw) || ~isfinite(hw) || hw < 1, hw = 1; end
    catch
        hw = 1;
    end

    target = max(1, min(nDesired, hw));

    % Prefer an existing pool if it exists.
    p = gcp('nocreate');
    if ~isempty(p)
        % If pool size matches, reuse. If it differs, prefer reuse rather than delete.
        nUsed = p.NumWorkers;
        if nUsed == target
            return;
        else
            % If the current pool is smaller, try to start a new one.
            try
                delete(p);
            catch
                % If delete fails, reuse what we have.
                nUsed = p.NumWorkers;
                return;
            end
        end
    end

    % Start pool
    try
        c = parcluster('local');
        p = parpool(c, target);
    catch
        % Fallback: generic parpool with size only.
        p = parpool(target);
    end

    nUsed = p.NumWorkers;
end


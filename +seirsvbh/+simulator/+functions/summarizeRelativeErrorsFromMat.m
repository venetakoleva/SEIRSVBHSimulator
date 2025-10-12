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

function [xiMinl2, cMinl2, xiMinlinf, cMinlinf, xiMinSum, cMinSum] = summarizeRelativeErrorsFromMat(matFile, winC, silent)
%SUMMARIZERELATIVEERRORSFROMMAT
%  • Locate the exact minima of l2, linf, and (l2+linf) in the given MAT-file.
%  • For l2 and linf only:  at the \xi where the minimum occurs, scan along c
%    ±winC columns and print the l2 and linf relative errors across that c-neighborhood.
%  • Uses actual c values as the column headers.
%
% Usage:
%   summarizeRelativeErrorsFromMat('file.mat')             % default ±5 columns, prints
%   summarizeRelativeErrorsFromMat('file.mat',3)           % custom ±3 columns, prints
%   summarizeRelativeErrorsFromMat('file.mat',5,true)      % QUIET: no console output
%
% Expects MAT to contain: l2mat, linfmat, and either (Xi,C) or (xi,c).

    if nargin < 2 || isempty(winC),   winC = 5;   end
    if nargin < 3 || isempty(silent), silent = false; end

    S = load(matFile);
    req = {'l2mat','linfmat'};
    for k = 1:numel(req)
        if ~isfield(S, req{k})
            error('printAllMinMaxFromMat:MissingVar','MAT must contain "%s".', req{k});
        end
    end

    l2 = S.l2mat;  linf = S.linfmat;

    % Prefer grids for pretty printing; else rebuild from vectors.
    if isfield(S,'Xi') && isfield(S,'C')
        Xi = S.Xi;  C = S.C;
    elseif isfield(S,'xi') && isfield(S,'c')
        [C, Xi] = meshgrid(S.c, S.xi);
    else
        Xi = []; C = [];
    end

    % We  compute the sum to find its minimum (no scan/print for it).
    SumMat = l2 + linf;

    % report all minima/maxima 
    [xiMinl2,   cMinl2,   iil2,  jjl2,  vl2]  = printAllExactExtrema(l2,   'l2  MIN',   'min', Xi, C, silent);
                                                printAllExactExtrema(l2,   'l2  MAX',   'max', Xi, C, silent);
    [xiMinlinf, cMinlinf, iiInf, jjInf, vInf] = printAllExactExtrema(linf, 'linf MIN', 'min', Xi, C, silent);
                                                printAllExactExtrema(linf, 'linf MAX', 'max', Xi, C, silent);
    [xiMinSum,  cMinSum]                       = printAllExactExtrema(SumMat,'l2+linf MIN','min', Xi, C, silent); % just to report

    % scan along c only for l2 and linf minima (skip entirely if silent) 
    if ~silent && ~isempty(iil2)
        if ~silent, fprintf('\n== Scan along c at xi where l2 minimum occurs ==\n'); end
        for k = 1:numel(iil2)
            printCScanAroundMin(l2, linf, Xi, C, iil2(k), jjl2(k), winC, 'l2', vl2);
        end
    end
    if ~silent && ~isempty(iiInf)
        if ~silent, fprintf('\n== Scan along c at xi where linf minimum occurs ==\n'); end
        for k = 1:numel(iiInf)
            printCScanAroundMin(l2, linf, Xi, C, iiInf(k), jjInf(k), winC, 'linf', vInf);
        end
    end
end

% ---- helper (exact equality, NaN-safe)
function [xiList, cList, iiList, jjList, v] = printAllExactExtrema(A, label, which, Xi, C, silent)
    if strcmpi(which,'min')
        v = min(A, [], 'all', 'omitnan');
    else
        v = max(A, [], 'all', 'omitnan');
    end
    if isempty(v) || isnan(v)
        if ~silent
            fprintf('%-9s = NaN (no finite entries)\n', label);
        end
        xiList = []; cList = []; iiList = []; jjList = [];
        return;
    end

    mask = (A == v);
    [ii, jj] = find(mask);
    linIdx   = find(mask);

    if ~silent
        fprintf('%-9s = %.10g (occurrences: %d)\n', label, v, numel(linIdx));
    end
    hasGrids = ~isempty(Xi) && ~isempty(C);
    if ~silent
        for k = 1:numel(linIdx)
            if hasGrids
                fprintf('  #%d  (ii=%d, jj=%d) -> (xi=%.10g, c=%.10g)\n', ...
                    k, ii(k), jj(k), Xi(ii(k),jj(k)), C(ii(k),jj(k)));
            else
                fprintf('  #%d  (ii=%d, jj=%d)\n', k, ii(k), jj(k));
            end
        end
    end

    iiList = ii(:); jjList = jj(:);
    if strcmpi(which,'min') && hasGrids
        xiList = Xi(sub2ind(size(Xi), ii, jj)); xiList = xiList(:);
        cList  = C( sub2ind(size(C),  ii, jj)); cList  = cList(:);
    else
        xiList = []; cList = [];
    end
end

% helper: fix row ii0 (xi) and scan columns around jj0 ± winC,
% printing actual c values along the top. Only l2 and linf are printed.
function printCScanAroundMin(l2, linf, Xi, C, ii0, jj0, winC, metricName, vMin)
    [~, nCols] = size(l2);
    jLo = max(1, jj0 - winC);
    jHi = min(nCols, jj0 + winC);

    if isempty(Xi) || isempty(C)
        error('Need c-grid (Xi,C or xi,c) to print c values.');
    end

    xi0 = Xi(ii0,jj0); c0 = C(ii0,jj0);
    fprintf('\n  @ %s minimum: value = %.10g at (xi=%.10g, c=%.10g)\n', ...
        metricName, vMin, xi0, c0);
    fprintf('  Scan along c (±%d columns) at fixed xi=%.10g\n', winC, xi0);

    % Header row: actual c values
    fprintf('    %-8s', 'c value →');
    for jj = jLo:jHi
        fprintf('  %-13.10g', C(ii0,jj));
    end
    fprintf('\n');

    % Print l2 and linf rows 
    printRow(ii0,jLo,jHi,jj0,l2,   'l2      ');
    printRow(ii0,jLo,jHi,jj0,linf, 'linf    ');
end

function printRow(ii0,jLo,jHi,jCenter,A,name)
    fprintf('    %-8s', name);
    for jj = jLo:jHi
        val = A(ii0,jj);
        if jj == jCenter
            if isnan(val), s='NaN'; else, s=sprintf('%.10g',val); end
            fprintf('  [%s]', s);
        else
            if isnan(val), fprintf('  %-13s','NaN');
            else,          fprintf('  %-13.10g',val);
            end
        end
    end
    fprintf('\n');
end

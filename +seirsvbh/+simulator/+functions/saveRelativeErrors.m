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

function saveRelativeErrors(xi, c, l2mat, linfmat, matFile)
%SAVERELATIVEERRORS
% Save xi, c (vectors), Xi, C (grids), and L2/Linf matrices to a MAT file.
% Always overwrites matFile.

    % Normalize input vectors to rows
    xi = xi(:).';
    c  = c(:).';

    % Basic size checks
    nXi = numel(xi);
    nC  = numel(c);
    if ~isequal(size(l2mat), [nXi, nC]) || ~isequal(size(linfmat), [nXi, nC])
        error('saveRelativeErrors:SizeMismatch', ...
              'Expected l2mat/linfmat size [%d x %d]. Got L2=%s, Linf=%s.', ...
              nXi, nC, mat2str(size(l2mat)), mat2str(size(linfmat)));
    end

    % Build grids nXi x nC
    [C, Xi] = meshgrid(c, xi); 

    % Overwrite the MAT file
    save(matFile, 'xi','c','Xi','C','l2mat','linfmat','-v7.3');
end

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

function plotRelativeErrorsFromMatFile(matFile)
% plotRelativeErrorsMesh(matFile)
% - Loads Xi, C, l2mat, linfmat from MAT file
% - Plots 3-D surface and 2-D contour for l2 and linf


    % Set default font sizes for all  figures
    set(groot, 'defaultAxesFontSize', 16);   % tick labels, axis labels
    set(groot, 'defaultTextFontSize', 16);   % titles and any text objects
    % Load saved matrices
    if ~isfile(matFile)
        error('File not found: %s', matFile);
    end
    S = load(matFile, 'Xi', 'C', 'l2mat', 'linfmat');

    needed = {'Xi','C','l2mat','linfmat'};
    for k = 1:numel(needed)
        if ~isfield(S, needed{k})
            error('Field "%s" not found in MAT file: %s', needed{k}, matFile);
        end
    end

    Xi      = S.Xi;        % nXi x nC
    C       = S.C;         % nXi x nC
    l2mat   = S.l2mat;     % nXi x nC
    linfmat = S.linfmat;   % nXi x nC

    % Sanity checks 
    if ~isequal(size(Xi), size(C), size(l2mat), size(linfmat))
        error('Matrix size mismatch among Xi, C, l2mat, linfmat in %s.', matFile);
    end

    %  Plot l2: surface + contour 
    figure('Name','Surface Plot of Relative l2 Error');
    surf(Xi, C, l2mat);
    shading interp;
    colorbar;
    
    xlabel('$\xi$','Interpreter','latex');
    ylabel('$c$','Interpreter','latex');
    zlabel('Error$(l_{2}, \xi, c)$','Interpreter','latex');
    title('Surface Plot of Relative Error$(l_{2}, \xi, c)$','Interpreter','latex');

   %% Relative l2 Error: 2D Contour
    figure('Name','Contour Plot of Relative l2 Error');
    contourf(Xi, C, l2mat, 30, 'LineColor','none'); 
    colorbar;
    xlabel('$\xi$','Interpreter','latex');
    ylabel('$c$','Interpreter','latex');
    title('Contour Plot of Relative Error$(l_{2}, \xi, c)$','Interpreter','latex');
    ax = gca;
    axis tight;
    
    %% Relative linf Error: Surface
    figure('Name','Surface Plot of Relative linf Error');
    surf(Xi, C, linfmat);
    shading interp; 
    colorbar;
    xlabel('$\xi$','Interpreter','latex');
    ylabel('$c$','Interpreter','latex');
      zlabel('Error$(l_{\infty}, \xi, c)$','Interpreter','latex');
    title('Surface Plot of Relative Error$(l_{\infty}, \xi, c)$','Interpreter','latex');
    
    %% Relative linf Error: 2D Contour
    figure('Name','Contour Plot of Relative linf Error');
    contourf(Xi, C, linfmat, 30, 'LineColor','none'); 
    colorbar;
    xlabel('$\xi$','Interpreter','latex');
    ylabel('$c$','Interpreter','latex');
        title('Contour Plot of Relative Error$(l_{\infty}, \xi, c)$','Interpreter','latex');

    axis tight;


    % Inform about any NaN "holes" in the grids
    holesl2   = nnz(isnan(l2mat));
    holeslinf = nnz(isnan(linfmat));
    if holesl2 || holeslinf
        fprintf('[plotRelativeErrorsMesh] Note: grid has %d NaN cells (l2) and %d NaN cells (linf).\n', ...
                holesl2, holeslinf);
    end
end

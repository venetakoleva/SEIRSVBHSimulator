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

classdef SEIRSVBHSimulator < matlab.apps.AppBase
    % SEIRSVBHSimulator
    % UI for:
    %   1) Compute & plot relative errors (l2, linf) over (xi, c)
    %   2) Solve & plot the Inverse Data Problem (IDP)
    %   3) Solve & plot the Direct problem

    %% ==== UI HANDLES ====
    properties (Access = private)
        UIFigure            matlab.ui.Figure
        RootGrid            matlab.ui.container.GridLayout

        % Left column (controls + plot)
        LeftPanel           matlab.ui.container.Panel
        LeftGrid            matlab.ui.container.GridLayout

        % Row 1: Data loading
        DataPanel           matlab.ui.container.Panel
        DataGrid            matlab.ui.container.GridLayout
        LoadStatesBtn       matlab.ui.control.Button
        LoadParamsBtn       matlab.ui.control.Button
        AutoLoadChk         matlab.ui.control.CheckBox
        DataStatusLbl       matlab.ui.control.Label

        % Row 2: Tabs
        Tabs                matlab.ui.container.TabGroup
        RelErrTab           matlab.ui.container.Tab
        IDPTab              matlab.ui.container.Tab
        DirectTab           matlab.ui.container.Tab

        % RelErr controls
        RelErrGrid          matlab.ui.container.GridLayout
        XiKnotsDrop         matlab.ui.control.DropDown
        CKnotsDrop          matlab.ui.control.DropDown
        WorkersDrop         matlab.ui.control.DropDown
        ComputeBtn          matlab.ui.control.Button
        RelPlotChoice       matlab.ui.control.DropDown
        PlotRelErrBtn       matlab.ui.control.Button
        ErrTipLbl            matlab.ui.control.Label
        selectedXiStep      double = [];
        selectedCStep       double = [];
        selectedRelPlot     string = "";
        IsInitializing      logical = true;

        % IDP controls
        IDPGrid             matlab.ui.container.GridLayout
        XiIDPField          matlab.ui.control.NumericEditField
        CIDPField           matlab.ui.control.NumericEditField
        PsiIDPDrop          matlab.ui.control.DropDown
        IDPTipLbl           matlab.ui.control.Label
        SolveIDPBtn         matlab.ui.control.Button
        ParamPlotDrop       matlab.ui.control.DropDown
        PlotParamBtn        matlab.ui.control.Button
        selectedParamPlot   string = "";

        % Direct controls
        DirectGrid          matlab.ui.container.GridLayout
        XiDirectField       matlab.ui.control.NumericEditField
        CDirectField        matlab.ui.control.NumericEditField
        PsiDirectDrop       matlab.ui.control.DropDown
        DirectTipLbl        matlab.ui.control.Label
        SolveDirectBtn      matlab.ui.control.Button
        DirectPlotDrop      matlab.ui.control.DropDown
        PlotDirectBtn       matlab.ui.control.Button
        DirectSolution      % holds ODESol from directProblemSolver
        selectedDirectPlot  string = ""

        % Row 3: Embedded plot
        PlotPanel           matlab.ui.container.Panel
        Ax                  matlab.ui.control.UIAxes

        % Right column: Logger
        LoggerPanel         matlab.ui.container.Panel
        LoggerGrid          matlab.ui.container.GridLayout
        LoggerArea          matlab.ui.control.TextArea
        CopyLogBtn          matlab.ui.control.Button
        ClearLogBtn         matlab.ui.control.Button
        HelpTipLbl          matlab.ui.control.Label
    end

    %% ==== APP STATE ====
    properties (Access = private)
        statesData  struct = struct()
        paramsData  struct = struct()
        h           double = 1.0
        psiDefault  string = "psiQuadratic"
        matFile     string = "results.mat"

        idpSol      struct = struct()
        ODESol      struct = struct()
    end
    
 

    %% ==== LIFECYCLE & UTILITIES ====
    methods (Access = private)
        function startupFcn(app, varargin)

            app.Tabs.SelectionChangedFcn = @(~,ev) app.onTabChanged(ev);

            if app.AutoLoadChk.Value
                app.tryAutoLoad();                         
            end
        end

        function safeClose(app)
            % Safe close handler
            if isvalid(app)
                delete(app);
            end
        end

        function logPlain(app,msg)
            % Log a message without a timestamp (plain text).
            prev = app.LoggerArea.Value;
            if ischar(prev), prev = cellstr(prev); end
            app.LoggerArea.Value = [prev; msg];
            drawnow limitrate;
        end
    
        function tryAutoLoad(app)
        % Auto-load
            try
                baseDir = fileparts(mfilename('fullpath'));    % ...\+seirsvbh\+simulator\+ui
                simDir  = fileparts(baseDir);                  % ...\+seirsvbh\+simulator
                dataDir = fullfile(simDir, '+data');           % ...\+seirsvbh\+simulator\+data
                stateFile = fullfile(dataDir, 'BGDataKnown.mat');
                paramFile = fullfile(dataDir, 'BGParamKnown.mat');
                
                if exist(stateFile,'file') == 2
                    app.statesData = load(stateFile);
                    app.logMsg(['Auto-loaded states: ' stateFile]);
                else
                    app.logMsg('Auto-load: states MAT not found (expected BGDataKnown.mat).');
                end
    
                if exist(paramFile,'file') == 2
                    app.paramsData = load(paramFile);
                    app.logMsg(['Auto-loaded params: ' paramFile]);
                else
                    app.logMsg('Auto-load: params MAT not found (expected BGParamKnown.mat).');
                end
        
                app.updateDataStatus();
                if ~isempty(fieldnames(app.statesData)) && ~isempty(fieldnames(app.paramsData))
                    app.logMsg('Data ready: states + params loaded.');
                else
                    app.logMsg('Hint: Use the "Load … MAT" buttons to select files manually if needed.');
                end
        
            catch ME
                app.logMsg(['Auto-load warning: ' ME.message]);
            end
        end
    

        function onTabChanged(app, ev)
        
            oldTab = ev.OldValue;
        
            % Reset defaults on the tab we are leaving
            if oldTab == app.IDPTab
                app.XiIDPField.Limits = [0 1];
                app.XiIDPField.Value  = 0.41;
                app.CIDPField.Limits  = [-0.25 0.25];
                app.CIDPField.Value   = -0.005;
                 % Reset param-plot prompt
                 if ~isempty(app.ParamPlotDrop) && isvalid(app.ParamPlotDrop)
                    app.ParamPlotDrop.Value = "";    
                end
                if isprop(app,'selectedParamPlot')
                    app.selectedParamPlot = "";      
                end
                
        
            elseif oldTab == app.DirectTab
                app.XiDirectField.Limits = [0 1];
                app.XiDirectField.Value  = 0.41;
                app.CDirectField.Limits  = [-0.25 0.25];
                app.CDirectField.Value   = -0.005;
        
                % Reset direct plot-type prompt 
                if ~isempty(app.DirectPlotDrop) && isvalid(app.DirectPlotDrop)
                    app.DirectPlotDrop.Value = "";   
                end
                if isprop(app,'selectedDirectPlot')
                    app.selectedDirectPlot = "";     
                end

            elseif oldTab == app.RelErrTab
                % Reset dropdowns to the prompt
                try
                    app.XiKnotsDrop.Value = "";     
                catch
                    app.XiKnotsDrop.Value = "Choose ξ";
                end
                try
                    app.CKnotsDrop.Value = "";       
                catch
                    app.CKnotsDrop.Value = "Choose c";
                end
        
                if isprop(app,'selectedXiStep'), app.selectedXiStep = ""; end   
                if isprop(app,'selectedCStep'),  app.selectedCStep  = ""; end  


                % Reset rel err plot-type prompt
                if ~isempty(app.RelPlotChoice) && isvalid(app.RelPlotChoice)
                    app.RelPlotChoice.Value = "";    
                end
                if isprop(app,'selectedRelPlot')
                    app.selectedRelPlot = "";       
                end
            end
            app.showDefaultEmbedded(ev.NewValue);
        end

        function updateDataStatus(app)
            sOK = ~isempty(fieldnames(app.statesData));
            pOK = ~isempty(fieldnames(app.paramsData));
            app.DataStatusLbl.Text = sprintf('States: %s | Parameters: %s', app.tfStr(sOK), app.tfStr(pOK));
        end

        function logMsg(app,msg)
            t = datestr(now,'yyyy-mm-dd HH:MM:SS');
            prev = app.LoggerArea.Value;
            if ischar(prev); prev = cellstr(prev); end
            app.LoggerArea.Value = [prev; sprintf('[%s] %s',t,msg)];
            drawnow limitrate;
        end
        function resetEmbeddedPlot(app)

            if ~isempty(app.Ax) && isvalid(app.Ax)
                cla(app.Ax,'reset');
                grid(app.Ax,'on');
                app.Ax.Box = 'on';
                app.Ax.Title.String   = '';
                app.Ax.XLabel.String  = '';
                app.Ax.YLabel.String  = '';
            end
        end
        function showDefaultEmbedded(app, tabObj)

            % Guard
            if ~isprop(app,'Ax') || isempty(app.Ax) || ~isvalid(app.Ax) || ~isgraphics(app.Ax,'axes')
                return
            end
        
            ax = app.Ax;
            cla(ax,'reset');
            ax.NextPlot = 'replacechildren';
            view(ax,2);
            grid(ax,'on'); box(ax,'on');
            ax.XLimMode = 'auto'; ax.YLimMode = 'auto';
            ax.ZLimMode = 'auto'; ax.CLimMode = 'auto';
            ax.FontSize = 10;
            title(ax,''); xlabel(ax,''); ylabel(ax,'');
            if isprop(app,'XTimeLabel') && isvalid(app.XTimeLabel)
                app.XTimeLabel.Text = '';
            end
        
            % Compose short hints
            switch string(tabObj.Title)
                case "Compute and Plot Relative Errors"
                    lines = [ ...
                        "Choose ξ and c. Then press “Compute Relative Errors“.", ...
                        "Then choose plot type and press “Plot Relative Errors”." ...
                    ];
        
                case "Solve and Plot Inverse Data Problem"
                    lines = [ ...
                        "Solve Inverse Problem.", ...
                        "Then choose a parameter and press “Plot Parameter”." ...
                    ];
        
                case "Solve and Plot Direct problem"
                    lines = [ ...
                        "Solve Direct Problem.", ...
                        "Then choose a plot option and press “Plot Selected”." ...
                    ];
        
                otherwise
                    lines = "Select a tab to begin.";
            end
        
            % Centered minimal hint text
            txt = strjoin(cellstr(lines), '\n');
            text(ax, 0.5, 0.5, txt, ...
                'Units','normalized', ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','middle', ...
                'Color',[0.35 0.35 0.35], ...
                'FontSize',12, ...
                'Interpreter','none', ...
                'HitTest','off');
        
            % Keep area tidy
            axis(ax,'tight');
        end


        function ok = haveStates(app)
            ok = ~isempty(fieldnames(app.statesData));
            if ~ok
                app.logMsg('Please load states MAT (BGDataKnownFinal.mat).');
            end
        end

        function ok = haveParams(app)
            ok = ~isempty(fieldnames(app.paramsData));
            if ~ok
                app.logMsg('Please load params MAT (BGParamKnown.mat).');
            end
        end

        function RD = getReportedData(app)
            RD = struct();
            if ~isempty(fieldnames(app.statesData))
                fn = fieldnames(app.statesData);
                for i = 1:numel(fn)
                    RD.(fn{i}) = app.statesData.(fn{i});
                end
            end
            if ~isempty(fieldnames(app.paramsData))
                fn = fieldnames(app.paramsData);
                for i = 1:numel(fn)
                    RD.(fn{i}) = app.paramsData.(fn{i});
                end
            end
        end

        function psiFunc = resolvePsi(app, val)
            if nargin < 2 || isempty(val)
                val = app.psiDefault;
            end
            try
                psiFunc = str2func("seirsvbh.simulator.helpers." + val);
            catch
                psiFunc = str2func("seirsvbh.simulator.helpers.psiQuadratic");
            end
        end

        function clearAxes(app)
            cla(app.Ax,'reset');
            grid(app.Ax,'on');
            app.Ax.Box = 'on';
            app.Ax.FontSize = 12;
        end

        function validateH(app)
            try
                seirsvbh.simulator.helpers.checkH(app.h);
            catch ME
                error("Error in h value: " + ME.message);
            end
        end

        function s = tfStr(app, b)
            if b, s = 'OK'; else, s = 'Missing'; end
        end

        function y = getFieldAny(app, S, names)
            y = [];
            for i = 1:numel(names)
                if isfield(S, names{i})
                    y = S.(names{i});
                    return
                end
            end
        end

        % ---run a function with a temporary DefaultFigurePosition ----
        function runWithFigPos(app, pos, fcn)
            % Temporarily set the default figure position, run fcn(), restore.
            g = groot;
            orig = get(g,'DefaultFigurePosition');
            cleaner = onCleanup(@() set(g,'DefaultFigurePosition',orig));
            set(g,'DefaultFigurePosition',pos);
            fcn(); 
        end
    end

    %% ==== CALLBACKS ====
    methods (Access = private)
        % Data loading
        function onLoadStates(app, varargin)
            [f,p] = uigetfile('*.mat','Select BGDataKnownFinal.mat');
            if isequal(f,0), return; end
            try
                app.statesData = load(fullfile(p,f));
                app.logMsg('Loaded states data successfully.');
                app.updateDataStatus();
            catch ME
                uialert(app.UIFigure, ME.message, 'Load Error');
                app.logMsg(['States load error: ' ME.message]);
            end
        end

        function onLoadParams(app, varargin)
            [f,p] = uigetfile('*.mat','Select BGParamKnown.mat');
            if isequal(f,0), return; end
            try
                app.paramsData = load(fullfile(p,f));
                app.logMsg('Loaded parameters data successfully.');
                app.updateDataStatus();
            catch ME
                uialert(app.UIFigure, ME.message, 'Load Error');
                app.logMsg(['Params load error: ' ME.message]);
            end
        end
        function onXiKnotsChanged(app, event)
            if isempty(event.Value), return; end
            app.selectedXiStep = event.Value;
        end
        
        function onCKnotsChanged(app, event)
            if isempty(event.Value), return; end
            app.selectedCStep = event.Value;
        end
        function onRelPlotChoiceChanged(app, event)
            if isempty(event.Value), return; end         
            app.selectedRelPlot = event.Value;          
        end
        function onParamPlotChoiceChanged(app, event)
            if isempty(event.Value), return; end         
            app.selectedParamPlot = event.Value;          
        end
        function onDirectPlotChoiceChanged(app, event)
            if isempty(event.Value), return; end         
            app.selectedDirectPlot = event.Value;          
        end

        % Relative Error 
        function onComputeRelErr(app, varargin)
            % Clear the embedded plotting area before starting a new compute

             if isempty(app.selectedXiStep) || isempty(app.selectedCStep)
                uialert(app.UIFigure,'Please choose both ξ and c step sizes.','Missing input');
                return;
             end
             if isprop(app,'selectedXiStep') && ~isempty(app.selectedXiStep)
                xiRaw = app.selectedXiStep;
            else
                xiRaw = app.XiKnotsDrop.Value;
            end
            % empty/prompt?
            if (isstring(xiRaw) && strlength(xiRaw)==0) || isempty(xiRaw)
                uialert(app.UIFigure,'Please choose ξ step size.','Missing input');
                return
            end
            % normalize to numeric
            if isstring(xiRaw) || ischar(xiRaw)
                xiStep = str2double(string(xiRaw));
            else
                xiStep = xiRaw;
            end
            if isnan(xiStep) || xiStep <= 0
                uialert(app.UIFigure,'Please choose ξ step size.','Invalid input');
                return
            end
        
            % ---- read c step ----
            if isprop(app,'selectedCStep') && ~isempty(app.selectedCStep)
                cRaw = app.selectedCStep;
            else
                cRaw = app.CKnotsDrop.Value;
            end
            if (isstring(cRaw) && strlength(cRaw)==0) || isempty(cRaw)
                uialert(app.UIFigure,'Please choose a c step size.','Missing input');
                return
            end
            if isstring(cRaw) || ischar(cRaw)
                cStep = str2double(string(cRaw));
            else
                cStep = cRaw;
            end
            if isnan(cStep) || cStep <= 0
                uialert(app.UIFigure,'Please choose c step size.','Invalid input');
                return
            end


            if ~app.haveStates() || ~app.haveParams()
                uialert(app.UIFigure,'Load both MAT files first.','Missing Data');
                return
            end
            try
                xiStep = app.selectedXiStep; 
                cStep  = app.selectedCStep;
                
                xi_list = 0      : xiStep : 1;
                c_list  = -0.25  : cStep  : 0.25;


                try
                    seirsvbh.simulator.helpers.checkInputParams(xi_list, c_list);
                catch ME
                    error("Input parameter check failed: " + ME.message);
                end

                app.validateH();
                psiFunc    = app.resolvePsi(app.PsiIDPDrop.Value); % any ψ; default ok
                maxWorkers = str2double(app.WorkersDrop.Value);
                parallelMode = 'ii';
                RD = app.getReportedData();

                app.logMsg(sprintf('Computing relative errors on grid %dx%d (ξ=%.3g, c=%.3g)...', numel(xi_list), numel(c_list), xiStep, cStep));


                tComp = tic;
                [l2mat, linfmat, usedParallel, nWorkersUsed] = ...
                    seirsvbh.simulator.functions.computeRelativeErrorsParallel(xi_list, c_list, app.h, psiFunc, RD, maxWorkers, parallelMode);
                app.logMsg(sprintf('usedParallel=%d, nWorkersUsed=%d, elapsed=%.2fs', usedParallel, nWorkersUsed, toc(tComp)));
                    
                seirsvbh.simulator.functions.saveRelativeErrors(xi_list, c_list, l2mat, linfmat, app.matFile);
                app.logMsg(sprintf('Saved results to "%s".', app.matFile));

                out = evalc('seirsvbh.simulator.functions.summarizeRelativeErrorsFromMat(app.matFile);');

                app.logMsg(sprintf('Summary of relative errors for grid %dx%d (ξ=%.3g, c=%.3g):', numel(xi_list), numel(c_list), xiStep, cStep));
                % Split the summary output into lines and log them without timestamps
                lines = regexp(out,'\r?\n','split');
                for k = 1:numel(lines)
                    L = strtrim(lines{k});
                    if ~isempty(L)
                        app.logPlain(L); %no timestamp
                    end
                end
                
                app.logMsg('Computing relative errors completed successfully.');

            
            catch ME
                uialert(app.UIFigure, ME.message, 'Compute Error');
                app.logMsg(['Compute Error: ' ME.message]);
            end
        end

        function onPlotRelErr(app, varargin)
            if ~isfile(app.matFile)
                uialert(app.UIFigure, sprintf('"%s" not found. Compute first.', app.matFile), 'Missing results.mat');
                app.logMsg('Plot aborted: results.mat not found.');
                return
            end

            % read relative-error plot choice
            if isprop(app,'selectedRelPlot') && ~isempty(app.selectedRelPlot)
                choiceRaw = app.selectedRelPlot;
            else
                choiceRaw = app.RelPlotChoice.Value;
            end
            
            % treat both ""  and [] (defensive) as "not chosen"
            if (isstring(choiceRaw) && strlength(choiceRaw)==0) || isempty(choiceRaw)
                uialert(app.UIFigure,'Choose a plot type first.','Missing choice');
                return
            end
            
            % normalize to string for switch/case
            choice = string(choiceRaw);
            
            % validate against allowed values
            validRelPlots = ["l2-contour","l2-surface","linf-contour","linf-surface"];
            if ~any(choice == validRelPlots)
                uialert(app.UIFigure,'Unsupported relative-error plot type.','Invalid choice');
                return
            end
    
            try
                S = load(app.matFile);
                if isfield(S,'Xi') && isfield(S,'C')
                    Xi = S.Xi; C = S.C;
                else
                    [Xi,C] = meshgrid(S.xi, S.c);
                end

               % Use consistent font scaling on this axes
                app.Ax.TitleFontSizeMultiplier = 1;
                app.Ax.LabelFontSizeMultiplier = 1;
                
                switch choice
                    case {'Contour Plot l2 Error', 'l2-contour'}
                        view(app.Ax, 2);                 % 2-D axes
                        app.Ax.ZLimMode = 'auto';
                        app.Ax.CLimMode = 'auto';
                        app.Ax.ZTick = [];
                        app.Ax.ZLabel.String = '';       % clear zlabel from prior 3-D plots
                        grid(app.Ax,'on'); box(app.Ax,'on');
                
                        contourf(app.Ax, Xi, C, S.l2mat, 30, 'LineColor','none');
                        cb = colorbar(app.Ax);
                        % Keep colorbar text consistent 
                        cb.TickLabelInterpreter = 'latex';
                        cb.Label.Interpreter = 'latex';
                
                        title(app.Ax,'Contour of $\ell_2$ Relative Error', ...
                            'Interpreter','latex','FontSize',16);
                        xlabel(app.Ax,'$\xi$','Interpreter','latex','FontSize',16);
                        ylabel(app.Ax,'$c$','Interpreter','latex','FontSize',16);
                
                        axis(app.Ax,'tight');
                        app.Ax.Layer = 'top';
                
                    case {'Contour Plot linf Error', 'linf-contour'}
                        view(app.Ax, 2);
                        app.Ax.ZLimMode = 'auto';
                        app.Ax.CLimMode = 'auto';
                        app.Ax.ZTick = [];
                        app.Ax.ZLabel.String = '';
                        grid(app.Ax,'on'); box(app.Ax,'on');
                
                        contourf(app.Ax, Xi, C, S.linfmat, 30, 'LineColor','none');
                        cb = colorbar(app.Ax);
                        cb.TickLabelInterpreter = 'latex';
                        cb.Label.Interpreter = 'latex';
                
                        title(app.Ax,'Contour of $\ell_\infty$ Relative Error', ...
                            'Interpreter','latex','FontSize',16);
                        xlabel(app.Ax,'$\xi$','Interpreter','latex','FontSize',16);
                        ylabel(app.Ax,'$c$','Interpreter','latex','FontSize',16);
                
                        axis(app.Ax,'tight');
                        app.Ax.Layer = 'top';
                
                    case {'Surface Plot l2 Error', 'l2-surface'}
                        Z = S.l2mat;
                
                        view(app.Ax, 3);
                        grid(app.Ax,'on'); box(app.Ax,'on');
                
                        % Restore Z axis modes in case a contour plot disabled them
                        app.Ax.ZTickMode       = 'auto';
                        app.Ax.ZTickLabelMode  = 'auto';
                        app.Ax.ZLimMode        = 'auto';
                        app.Ax.CLimMode        = 'auto';
                
                        % Z label in LaTeX, consistent size
                        app.Ax.ZLabel.Interpreter = 'latex';
                        app.Ax.ZLabel.String      = '$\ell_2$';
                        app.Ax.ZLabel.FontSize    = 16;
                
                        % Plot
                        colormap(app.Ax, parula);
                        surf(app.Ax, Xi, C, Z, 'EdgeColor','none');
                        shading(app.Ax,'interp');
                
                        % Limits from finite values only
                        finiteZ = isfinite(Z);
                        if ~any(finiteZ(:))
                            zmin = 0; zmax = 1;
                        else
                            zmin = min(Z(finiteZ)); zmax = max(Z(finiteZ));
                            if zmin == zmax, zmin = zmin - 0.5; zmax = zmax + 0.5; end
                        end
                        pad = 0.05 * max(zmax - zmin, eps);
                        app.Ax.XLim = [min(Xi(:)) max(Xi(:))];
                        app.Ax.YLim = [min(C(:))  max(C(:))];
                        app.Ax.ZLim = [zmin - pad, zmax + pad];
                        app.Ax.CLim = [zmin, zmax];
                
                        % Add colorbar (after CLim), and set the title last
                        cb = colorbar(app.Ax);
                        cb.TickLabelInterpreter = 'latex';
                        cb.Label.Interpreter = 'latex';
                
                        title(app.Ax,'Surface of $\ell_2$ Relative Error', ...
                            'Interpreter','latex','FontSize',16);
                        xlabel(app.Ax,'$\xi$','Interpreter','latex','FontSize',16);
                        ylabel(app.Ax,'$c$','Interpreter','latex','FontSize',16);
                
                    case {'Surface Plot linf Error', 'linf-surface'}
                        Z = S.linfmat;
                
                        view(app.Ax, 3);
                        grid(app.Ax,'on'); box(app.Ax,'on');
                
                        app.Ax.ZTickMode       = 'auto';
                        app.Ax.ZTickLabelMode  = 'auto';
                        app.Ax.ZLimMode        = 'auto';
                        app.Ax.CLimMode        = 'auto';
                
                        app.Ax.ZLabel.Interpreter = 'latex';
                        app.Ax.ZLabel.String      = '$\ell_\infty$';
                        app.Ax.ZLabel.FontSize    = 16;
                
                        colormap(app.Ax, parula);
                        surf(app.Ax, Xi, C, Z, 'EdgeColor','none');
                        shading(app.Ax,'interp');
                
                        finiteZ = isfinite(Z);
                        if ~any(finiteZ(:))
                            zmin = 0; zmax = 1;
                        else
                            zmin = min(Z(finiteZ)); zmax = max(Z(finiteZ));
                            if zmin == zmax, zmin = zmin - 0.5; zmax = zmax + 0.5; end
                        end
                        pad = 0.05 * max(zmax - zmin, eps);
                        app.Ax.XLim = [min(Xi(:)) max(Xi(:))];
                        app.Ax.YLim = [min(C(:))  max(C(:))];
                        app.Ax.ZLim = [zmin - pad, zmax + pad];
                        app.Ax.CLim = [zmin, zmax];
                
                        cb = colorbar(app.Ax);
                        cb.TickLabelInterpreter = 'latex';
                        cb.Label.Interpreter = 'latex';
                
                        title(app.Ax,'Surface of $\ell_\infty$ Relative Error', ...
                            'Interpreter','latex','FontSize',16);
                        xlabel(app.Ax,'$\xi$','Interpreter','latex','FontSize',16);
                        ylabel(app.Ax,'$c$','Interpreter','latex','FontSize',16);
                end
                
                grid(app.Ax,'on');
                app.logMsg(['Plotted: ' choice]);

            catch ME
                uialert(app.UIFigure, ME.message, 'Plot Error');
                app.logMsg(['Plot Error: ' ME.message]);
            end
        end

        % IDP 
        function onSolveIDP(app, varargin)
            % Ensure data
            if ~app.haveStates() || ~app.haveParams()
                uialert(app.UIFigure,'Load both MAT files first.','Missing Data');
                return
            end
        
            try
                % Read / validate xi, c
                xi = app.XiIDPField.Value;
                c  = app.CIDPField.Value;
                if ~isfinite(xi) || xi < 0 || xi > 1
                    uialert(app.UIFigure,'ξ must be a number in [0,1].','Invalid ξ'); return
                end
                if ~isfinite(c) || c < -0.25 || c > 0.25
                    uialert(app.UIFigure,'c must be a number in [-0.25,0.25].','Invalid c'); return
                end
        
                % Inputs
                app.validateH();
                psiFunc = app.resolvePsi(app.PsiIDPDrop.Value);
                RD      = app.getReportedData();
        
                % Solve only (no plotting here)
                app.logMsg(sprintf('Solving IDP with ξ=%.5g, c=%.5g, psi=%s...', xi, c, func2str(psiFunc)));
                tComp = tic;
                app.idpSol = seirsvbh.simulator.functions.IDPSolver(xi, app.h, c, psiFunc, RD);
                app.logMsg(sprintf('IDP solved in %.2f s. Use "Plot Parameter" to visualize.', toc(tComp)));
        
               % Reset embedded axes to a neutral state with a hint
                cla(app.Ax,'reset'); 
                view(app.Ax,2); grid(app.Ax,'on'); app.Ax.Box = 'on';

                app.showDefaultEmbedded(app.Tabs.SelectedTab);
                xlabel(app.Ax,''); ylabel(app.Ax,'');
        
            catch ME
                rep = getReport(ME,'extended','hyperlinks','off');
                if ismethod(app,'logPlain'), app.logPlain(rep); end
                uialert(app.UIFigure, ME.message, 'IDP Error');
                app.logMsg('IDP Error.');
            end
        end


        function onPlotIDPParam(app, varargin)
            if isempty(fieldnames(app.idpSol))
                uialert(app.UIFigure,'Press "Solve Inverse Problem" to solve the Inverse data problem first.','No IDP Solution');
                return
            end
        
            % --- read parameter choice safely ---
            if isprop(app,'selectedParamPlot') && ~isempty(app.selectedParamPlot)
                choiceRaw = app.selectedParamPlot;
            else
                choiceRaw = app.ParamPlotDrop.Value;
            end
        
            % treat both "" as "not chosen"
            if (isstring(choiceRaw) && strlength(choiceRaw)==0) || isempty(choiceRaw)
                uialert(app.UIFigure,'Choose a parameter first.','Missing choice');
                return
            end
        
            % normalize to string for switch/case
            choice = string(choiceRaw);
            % guard against unexpected values
            validParams = ["alpha-param","beta-param","gamma-param","rho-param","sigma-param","tau-param"];
            if ~any(choice == validParams)
                uialert(app.UIFigure,'Unsupported parameter selection.','Invalid choice');
                return
            end
        
            try
                % Map dropdown → field candidates + label
                switch app.ParamPlotDrop.Value
                    case {'alpha - Vaccination parameter', 'alpha-param'}
                        label = '\alpha (Vaccination parameter)'; candidates = {'alpha','Alpha','vaccination','Vaccination'};
                    case {'beta - Transmission rate', 'beta-param'}
                        label = '\beta (Transmission rate)'; candidates = {'beta','Beta','transmission','Transmission'};
                    case {'gamma - Recovery rate of non-hospitalized individuals', 'gamma-param'}
                        label = '\gamma (Recovery rate of non-hospitalized individuals)'; candidates = {'gamma','Gamma','recoveryNonHosp','recovery_non_hosp'};
                    case {'rho - Hospitalization rate', 'rho-param'}
                        label = '\rho (Hospitalization rate)'; candidates = {'rho','Rho','hospitalization','HospRate'};
                    case {'sigma - Recovery rate of hospitalized individuals', 'sigma-param'}
                        label = '\sigma (Recovery rate of hospitalized individuals)'; candidates = {'sigma','Sigma','recoveryHosp','recovery_hosp'};
                    case {'tau - Mortality rate of infectious people', 'tau-param'}
                        label = '\tau (Mortality rate of infectious people)'; candidates = {'tau','Tau','mortality','Mortality'};
                    otherwise
                        label = 'parameter'; candidates = {};
                end
        
                % Find the first matching field in idpSol
                y = [];
                for k = 1:numel(candidates)
                    if isfield(app.idpSol, candidates{k})
                        y = app.idpSol.(candidates{k});
                        break
                    end
                end
        
                if isempty(y)
                    uialert(app.UIFigure,'Selected parameter not found in IDP solution.','Missing series');
                    app.logMsg('Plot Parameter: series not found in idpSol.');
                    return
                end
        
                % --- Plot on embedded axes (2-D) ---
                series = y(:);
                K = numel(series);
                if K == 0
                    uialert(app.UIFigure,'Selected parameter series is empty.','Empty series');
                    return
                end
        
                startDate = datetime(2020,6,8);   % fixed start date
                t = startDate + days(0:K-1);
        
                % Reset axes and basic view; DO NOT touch X-axis styling here
                cla(app.Ax,'reset');
                view(app.Ax,2);
                hold(app.Ax,'on');
        
                % Light grey daily line (behind dots)
                if K >= 2
                    plot(app.Ax, t, series, '-', 'LineWidth', 1.0, 'Color', [0.8 0.8 0.8], ...
                        'HandleVisibility','off');
                end
        
                % Red daily dots
                scatter(app.Ax, t, series, 5, 'filled', ...
                    'MarkerFaceColor', [0.85 0 0], 'MarkerEdgeColor', 'none', ...
                    'DisplayName','Daily value');
        
                % 7-day moving average
                w = 7;
                ma = movmean(series, [w-1 0], 'omitnan');
                ma(1:min(w-1,K)) = NaN;     % hide until full window exists
                plot(app.Ax, t, ma, '-', 'LineWidth', 2.2, 'Color', [0 0.2 0.8], ...
                    'DisplayName','7-day moving average');
        
                hold(app.Ax,'off');
        
                % X-axis styling handled ONLY by styleDateAxisUI
                app.styleDateAxisUI(app.Ax, startDate, startDate + days(max(K-1,1)), 'params');
        
                % Titles & labels (only Y and title here; X label is hidden in styleDateAxisUI)
                title(app.Ax, ['Parameter: ' label], 'Interpreter','tex', 'FontSize',16);
                ylabel(app.Ax, 'Rate', 'FontSize',16, 'Interpreter','tex');
        
                % Ensure visibility for single-point series (Y only)
                if K == 1
                    y0 = series(1);
                    dy = max(abs(y0)*0.1, 1e-9);
                    ylim(app.Ax, [y0 - dy, y0 + dy]);
                end
        
                % Legend inside plot
                if contains(label, '\beta') || contains(label,'\sigma') || contains(label,'\gamma') || contains(label,'\tau')
                    legend(app.Ax,'show','Location','northwest','FontSize',12,'Box','on');
                else
                    legend(app.Ax,'show','Location','northeast','FontSize',12,'Box','on');
                end
        
            catch ME
                rep = getReport(ME,'extended','hyperlinks','off');
                if ismethod(app,'logPlain'), app.logPlain(rep); end
                uialert(app.UIFigure, ME.message, 'Plot Parameter Error');
                app.logMsg('Plot Parameter Error.');
            end
        end



        % Direct (show external figs at given size)
        function onSolveDirect(app)
            % Solve the Direct problem ONLY. No plotting here.
        
            try
                % Read inputs
                xi  = app.XiDirectField.Value;
                c   = app.CDirectField.Value;
                if ~(isfinite(xi) && xi>=0 && xi<=1)
                    uialert(app.UIFigure,'ξ must be in [0,1].','Invalid ξ'); return
                end
                if ~(isfinite(c) && c>=-0.25 && c<=0.25)
                    uialert(app.UIFigure,'c must be in [-0.25,0.25].','Invalid c'); return
                end
                psiFunc = str2func(app.PsiDirectDrop.Value); 
                h = 1;  % day
        
                % Reported data
                RD = app.getReportedData();   % existing helper that returns struct
        
         
                if ~isstruct(app.idpSol) || isempty(fieldnames(app.idpSol))
                    uialert(app.UIFigure, ...
                        ['The parameters from the Inverse Data Problem solution are not computed.', newline, ...
                         'Please solve the inverse data problem first in the ', ...
                         '"Solve and Plot Inverse Data Problem" tab.'], ...
                        'IDP Required', 'Icon','error');
                    app.logMsg('Cannot proceed: IDP solution missing.');
                    return;
                end



                % Direct solver
                app.logMsg('Solving Direct problem...');
                tComp = tic;
                app.ODESol = seirsvbh.simulator.functions.directProblemSolver(app.idpSol, RD, h);
                app.logMsg(sprintf('Direct problem solved in %.2f s. Use "Plot Selected" to visualize.', toc(tComp)));
        
                % Keep default axis
                 app.showDefaultEmbedded(app.Tabs.SelectedTab);
        
            catch ME
                uialert(app.UIFigure, ME.message, 'Direct Solver Error');
                app.logMsg(['Error in direct solver: ' ME.message]);
            end
        end


    
        function onPlotDirect(app, varargin)
            % Plot the selected Direct-solver view in the embedded axes (app.Ax)
            % X-axis styling is delegated EXCLUSIVELY to styleDateAxisUI(...,'states').
        
            % Guard
            if ~isstruct(app.ODESol) || isempty(fieldnames(app.ODESol))
                uialert(app.UIFigure,'Please solve the direct problem first.','No Direct Solution');
                return
            end
        
            % read direct-plot
            if isprop(app,'selectedDirectPlot') && ~isempty(app.selectedDirectPlot)
                choiceRaw = app.selectedDirectPlot;
            else
                choiceRaw = app.DirectPlotDrop.Value;
            end
        
            % treat both "" and [] as "not chosen"
            if (isstring(choiceRaw) && strlength(choiceRaw)==0) || isempty(choiceRaw)
                uialert(app.UIFigure,'Choose a plot type first.','Missing choice');
                return
            end
        
            % normalize to string for switch/case
            choice = string(choiceRaw);
        
            % validate against allowed values
            validDirect = [ ...
                "ns-model","iv-model","eh-model","rb-model", ...
                "a-vs-reported","vtotal-vs-reported","rtotal-vs-reported", ...
                "dtotal-vs-reported","htotal-vs-reported"];
            if ~any(choice == validDirect)
                uialert(app.UIFigure,'Unsupported plot selection.','Invalid choice');
                return
            end

            try
                sel = app.DirectPlotDrop.Value;
                app.clearAxes();
                ax = app.Ax; hold(ax,'on');
        
                O  = app.ODESol;
                RD = app.getReportedData();
        
                % ===== MODEL timeline =====
                defaultStart = datetime(2020,6,8);
                if isfield(O,'dates') && ~isempty(O.dates)
                    tModAll = O.dates(:);
                else
                    if isfield(O,'startDate') && ~isempty(O.startDate)
                        modStart = O.startDate;
                    else
                        modStart = defaultStart;
                    end
                    modLen = 0;
                    if isfield(O,'S') && ~isempty(O.S)
                        modLen = numel(O.S);
                    else
                        fns = fieldnames(O);
                        for ii = 1:numel(fns)
                            v = O.(fns{ii});
                            if isnumeric(v) && isvector(v)
                                modLen = numel(v);
                                break
                            end
                        end
                    end
                    tModAll = modStart + days(0:max(modLen-1,0));
                end
        
                % ===== REPORTED timeline =====
                if isstruct(RD) && isfield(RD,'dates') && ~isempty(RD.dates)
                    tRepAll = RD.dates(:);
                else
                    if isstruct(RD) && isfield(RD,'startDate') && ~isempty(RD.startDate)
                        repStart = RD.startDate;
                    else
                        repStart = defaultStart;
                    end
                    if isstruct(RD) && isfield(RD,'A') && ~isempty(RD.A)
                        repLen = numel(RD.A);
                    elseif isstruct(RD) && isfield(RD,'Htotal') && ~isempty(RD.Htotal)
                        repLen = numel(RD.Htotal);
                    else
                        repLen = 0;
                    end
                    tRepAll = repStart + days(0:max(repLen-1,0));
                end
        
                % ===== Series (safe extraction) =====
                S_mod = app.getFieldAny(O,{'S'}); if isempty(S_mod), S_mod = zeros(size(tModAll)); end; S_mod = S_mod(:);
                E_mod = app.getFieldAny(O,{'E'}); if isempty(E_mod), E_mod = zeros(size(tModAll)); end; E_mod = E_mod(:);
                I_mod = app.getFieldAny(O,{'I'}); if isempty(I_mod), I_mod = zeros(size(tModAll)); end; I_mod = I_mod(:);
                R_mod = app.getFieldAny(O,{'R'}); if isempty(R_mod), R_mod = zeros(size(tModAll)); end; R_mod = R_mod(:);
                V_mod = app.getFieldAny(O,{'V'}); if isempty(V_mod), V_mod = zeros(size(tModAll)); end; V_mod = V_mod(:);
                B_mod = app.getFieldAny(O,{'B'}); if isempty(B_mod), B_mod = zeros(size(tModAll)); end; B_mod = B_mod(:);
                H_mod = app.getFieldAny(O,{'H'}); if isempty(H_mod), H_mod = zeros(size(tModAll)); end; H_mod = H_mod(:);
        
                N_mod = S_mod + E_mod + I_mod + R_mod + V_mod + B_mod + H_mod;
        
                % ===== Plot selection =====
                switch sel
                    % -------- MODEL ONLY --------
                    case {'N & S together (computed only)', 'ns-model'}
                        plot(ax, tModAll, N_mod, 'b', 'LineWidth',1.6, 'DisplayName','Total population N');
                        plot(ax, tModAll, S_mod, 'm', 'LineWidth',1.6, 'DisplayName','Susceptible S');
                        legend(ax, 'Location','west','FontSize',12,'Box','on');
                        title(ax, 'Components of computed solution: N and S', 'FontSize',16, 'Interpreter','tex');
                        ylabel(ax,'Individuals','FontSize',16);
        
                    case {'I, V together (computed only)', 'iv-model'}
                        plot(ax, tModAll, I_mod, 'Color',[0.55 0.37 0.67], 'LineWidth',1.8, 'DisplayName','I (Infectious)');
                        plot(ax, tModAll, V_mod, 'Color',[0    0.39 0   ], 'LineWidth',1.8, 'DisplayName','V (Vaccinated susceptible)');
                        legend(ax, 'Location','northeast','FontSize',12,'Box','on');
                        title(ax, 'Components of computed solution: E, I, V and H', 'FontSize',16, 'Interpreter','tex');
                        ylabel(ax,'Individuals','FontSize',16);
        
                    case {'E, H together (computed only)', 'eh-model'}
                        plot(ax, tModAll, E_mod, 'Color',[0.80 0.08 0.45], 'LineWidth',1.8, 'DisplayName','E (Exposed)');
                        plot(ax, tModAll, H_mod, 'Color',[0    0.60 0.60], 'LineWidth',1.8, 'DisplayName','H (Hospitalized)');
                        legend(ax, 'Location','northeast','FontSize',12,'Box','on');
                        title(ax, 'Components of computed solution: E and H', 'FontSize',16, 'Interpreter','tex');
                        ylabel(ax,'Individuals','FontSize',16);
        
                    case {'R and B together (computed only)', 'rb-model'}
                        plot(ax, tModAll, R_mod, 'Color',[1    0.55 0   ], 'LineWidth',1.8, 'DisplayName','R (Recovered)');
                        plot(ax, tModAll, B_mod, 'Color',[0.29 0    0.51], 'LineWidth',1.8, 'DisplayName','B (Vaccination-acquired immunity)');
                        legend(ax, 'Location','northwest','FontSize',12,'Box','on');
                        title(ax, 'Components of computed solutions: R and B', 'FontSize',16, 'Interpreter','tex');
                        ylabel(ax,'Individuals','FontSize',16);
        
                    % -------- MODEL vs REPORTED --------
                    case {'A (computed vs. reported)', 'a-vs-reported'}
                        if isfield(O,'A') && ~isempty(O.A), A_mod = O.A(:);
                        else, A_mod = E_mod + I_mod + H_mod;
                        end
                        if isstruct(RD) && isfield(RD,'A') && ~isempty(RD.A)
                            [tCommon, iaRep, iaMod] = intersect(tRepAll, tModAll);
                            if ~isempty(tCommon)
                                plot(ax, tCommon, RD.A(iaRep), 'k', 'LineWidth',1.8, 'DisplayName','Reported');
                                plot(ax, tCommon, A_mod(iaMod), 'm', 'LineWidth',1.8, 'DisplayName','Model');
                                legend(ax, 'Location','northeast','FontSize',12,'Box','on');
                                title(ax, 'Component of computed component: A = E + I + H', 'FontSize',16, 'Interpreter','tex');
                                ylabel(ax,'Individuals','FontSize',16);
                            end
                        end
        
                    case {'Vtotal (computed vs. reported)', 'vtotal-vs-reported'}
                        if isstruct(RD) && isfield(RD,'Vtotal') && ~isempty(RD.Vtotal) ...
                                && (isfield(O,'Vt') || isfield(O,'Vtotal'))
                            tmpVt = app.getFieldAny(O,{'Vt','Vtotal'}); modelVt = tmpVt(:);
                            [tCommon, iaRep, iaMod] = intersect(tRepAll, tModAll);
                            if ~isempty(tCommon)
                                plot(ax, tCommon, RD.Vtotal(iaRep), 'k', 'LineWidth',1.8, 'DisplayName','Reported');
                                plot(ax, tCommon, modelVt(iaMod),   'm', 'LineWidth',1.8, 'DisplayName','Model');
                                legend(ax, 'Location','northwest','FontSize',12,'Box','on');
                                title(ax, 'Component of computed solution: V_{total}', 'FontSize',16, 'Interpreter','tex');
                                ylabel(ax,'Individuals (cumulative)','FontSize',16);
                            end
                        end
        
                    case {'Rtotal (computed vs. reported)', 'rtotal-vs-reported'}
                        if isstruct(RD) && isfield(RD,'Rtotal') && ~isempty(RD.Rtotal) ...
                                && (isfield(O,'Rt') || isfield(O,'Rtotal'))
                            tmpRt = app.getFieldAny(O,{'Rt','Rtotal'}); modelRt = tmpRt(:);
                            [tCommon, iaRep, iaMod] = intersect(tRepAll, tModAll);
                            if ~isempty(tCommon)
                                plot(ax, tCommon, RD.Rtotal(iaRep), 'k', 'LineWidth',1.8, 'DisplayName','Reported');
                                plot(ax, tCommon, modelRt(iaMod),   'm', 'LineWidth',1.8, 'DisplayName','Model');
                                legend(ax, 'Location','northwest','FontSize',12,'Box','on');
                                title(ax, 'Component of computed solution: R_{total}', 'FontSize',16, 'Interpreter','tex');
                                ylabel(ax,'Individuals (cumulative)','FontSize',16);
                            end
                        end
        
                    case {'Dtotal (computed vs. reported)', 'dtotal-vs-reported'}
                        if isstruct(RD) && isfield(RD,'Dtotal') && ~isempty(RD.Dtotal) ...
                                && (isfield(O,'Dt') || isfield(O,'Dtotal'))
                            tmpDt = app.getFieldAny(O,{'Dt','Dtotal'}); modelDt = tmpDt(:);
                            [tCommon, iaRep, iaMod] = intersect(tRepAll, tModAll);
                            if ~isempty(tCommon)
                                plot(ax, tCommon, RD.Dtotal(iaRep), 'k', 'LineWidth',1.8, 'DisplayName','Reported');
                                plot(ax, tCommon, modelDt(iaMod),   'm', 'LineWidth',1.8, 'DisplayName','Model');
                                legend(ax, 'Location','northwest','FontSize',12,'Box','on');
                                title(ax, 'Component of computed solution: D_{total}', 'FontSize',16, 'Interpreter','tex');
                                ylabel(ax,'Individuals (cumulative)','FontSize',16);
                            end
                        end
        
                    case {'Htotal (computed vs. reported)', 'htotal-vs-reported'}
                        if isstruct(RD) && isfield(RD,'Htotal') && ~isempty(RD.Htotal) ...
                                && (isfield(O,'Ht') || isfield(O,'Htotal'))
                            tmpHt = app.getFieldAny(O,{'Ht','Htotal'}); modelHt = tmpHt(:);
                            [tCommon, iaRep, iaMod] = intersect(tRepAll, tModAll);
                            if ~isempty(tCommon)
                                plot(ax, tCommon, RD.Htotal(iaRep), 'k', 'LineWidth',1.8, 'DisplayName','Reported');
                                plot(ax, tCommon, modelHt(iaMod),   'm', 'LineWidth',1.8, 'DisplayName','Model');
                                legend(ax, 'Location','northwest','FontSize',12,'Box','on');
                                title(ax, 'Component of computed solution: H_{total}', 'FontSize',16, 'Interpreter','tex');
                                ylabel(ax,'Individuals (cumulative)','FontSize',12);
                            end
                        end
                end
        
                hold(ax,'off');
        
                % ---- X-axis styling handled ONLY by styleDateAxisUI ----
                % Use model timeline if available; otherwise fall back to defaults.
                if ~isempty(tModAll)
                    t0 = tModAll(1); t1 = tModAll(end);
                else
                    t0 = defaultStart; t1 = defaultStart;
                end
                app.styleDateAxisUI(ax, t0, t1, 'states');   % 07-Jun/12-Mar rules
        
                % ---- Titles & Y label (no X label; helper hides external Time label) ----
                % Keep these typography choices local (does not touch X axis)
                % Title already set per-case. Ensure consistent Y label size.
                if ~isempty(ax.YLabel), ax.YLabel.FontSize = 16; end
        
            catch ME
                uialert(app.UIFigure, ME.message, 'Plot Direct Error');
                app.logMsg(['Plot Direct Error: ' ME.message]);
            end
        end


        % Logger
        function onCopyLog(app, varargin)
            clipboard('copy', strjoin(app.LoggerArea.Value, newline));
            app.logMsg('Log copied to clipboard.');
        end

        function onClearLog(app)
            app.LoggerArea.Value = "";   % or {''}
        end

    end

    %% ==== UI CONSTRUCTION ====
   
    methods (Access = private)
    
        function createComponents(app)
            % ==== Main window & root grid ====
            app.UIFigure = uifigure('Name','SEIRSVBHSimulator', ...
                                    'Position',[100 100 1100 650], ...
                                    'Resize','on');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Tag = 'SEIRSVBHSimulatorMain';
            app.UIFigure.CloseRequestFcn = @(~,~) app.safeClose();
        
            app.RootGrid = uigridlayout(app.UIFigure,[1 2]);
            app.RootGrid.RowHeight     = {'1x'};
            app.RootGrid.ColumnWidth   = {'3x','2x'};
            app.RootGrid.RowSpacing    = 6;
            app.RootGrid.ColumnSpacing = 6;
            app.RootGrid.Padding       = [6 6 6 6];
        
            % ==== Left column ====
            app.LeftPanel = uipanel(app.RootGrid,'Title','Controls & Plots','Scrollable','on'); 
            app.LeftPanel.Layout.Row = 1; app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.BackgroundColor = [0.9 0.95 1];
        
            app.LeftGrid  = uigridlayout(app.LeftPanel,[3 1]);
            app.LeftGrid.RowHeight     = {'fit','1x','1.6x'};
            app.LeftGrid.RowSpacing    = 6;
            app.LeftGrid.Padding       = [4 4 4 4];
        
            % ---- Row 1: Data Loading ----
            app.DataPanel = uipanel(app.LeftGrid,'Title','Data Loading','Scrollable','on'); 
            app.DataPanel.Layout.Row = 1; app.DataPanel.Layout.Column = 1;
            app.DataPanel.BackgroundColor = [0.9 0.95 1];
        
            app.DataGrid  = uigridlayout(app.DataPanel,[2 4]);
            app.DataGrid.RowHeight    = {'fit','fit'};
            app.DataGrid.ColumnWidth  = {'fit','fit','1x','fit'};
        
            app.LoadStatesBtn = uibutton(app.DataGrid,'Text','Load States MAT','ButtonPushedFcn',@app.onLoadStates,'Tag','LoadStatesBtn');
            app.LoadParamsBtn = uibutton(app.DataGrid,'Text','Load Params MAT','ButtonPushedFcn',@app.onLoadParams,'Tag','LoadParamsBtn');
            app.AutoLoadChk   = uicheckbox(app.DataGrid,'Text','Auto-load on start','Value',true,'Tag','AutoLoadChk');
            app.DataStatusLbl = uilabel(app.DataGrid,'Text','States: Missing | Parameters: Missing','HorizontalAlignment','left','Tag','DataStatusLbl');
        
            app.LoadStatesBtn.Layout.Row = 1; app.LoadStatesBtn.Layout.Column = 1;
            app.LoadParamsBtn.Layout.Row = 1; app.LoadParamsBtn.Layout.Column = 2;
            app.AutoLoadChk.Layout.Row   = 1; app.AutoLoadChk.Layout.Column   = 4;
            app.DataStatusLbl.Layout.Row = 2; app.DataStatusLbl.Layout.Column = [1 4];
        
            app.LoadStatesBtn.BackgroundColor = [0.9 0.95 1];
            app.LoadParamsBtn.BackgroundColor = [0.9 0.95 1];
        
            % ---- Row 2: Tabs host --
            tabsContainer = uipanel(app.LeftGrid,'BorderType','none','Scrollable','off');
            tabsContainer.Layout.Row = 2; tabsContainer.Layout.Column = 1;
        
            tabsGrid = uigridlayout(tabsContainer,[1 1], ...
                                    'Padding',[0 0 0 0], ...
                                    'RowHeight',{'1x'}, ...
                                    'ColumnWidth',{'1x'});
        
            app.Tabs = uitabgroup(tabsGrid);
            app.Tabs.Layout.Row = 1; 
            app.Tabs.Layout.Column = 1;
            app.Tabs.SelectionChangedFcn = @(~,ev) app.onTabChanged(ev);  
        
            % === Relative Errors tab ===
            app.RelErrTab  = uitab(app.Tabs,'Title','Compute and Plot Relative Errors','Scrollable','off');
            relTabGrid = uigridlayout(app.RelErrTab,[1 1],'Padding',[0 0 0 0],'RowHeight',{'1x'},'ColumnWidth',{'1x'});
            relScroll = uipanel(relTabGrid,'BorderType','none','Scrollable','on','AutoResizeChildren','off');
            relScroll.Layout.Row = 1; relScroll.Layout.Column = 1;
            relInner  = uipanel(relScroll,'BorderType','none','Units','pixels','AutoResizeChildren','off');
            relInner.Position = [0 0 relScroll.InnerPosition(3) relScroll.InnerPosition(4)];
            relScroll.SizeChangedFcn = @(src,~) app.updateScrollInner(src, relInner);
        
            app.RelErrGrid = uigridlayout(relInner,[10 8],'Tag','RelErrGrid');
            app.RelErrGrid.RowHeight     = {'fit','fit','fit', 1,1,1,1,1,1, 1};
            app.RelErrGrid.ColumnWidth   = {'fit','fit','fit','fit','fit','fit','fit','1x'};
            app.RelErrGrid.RowSpacing    = 6;
            app.RelErrGrid.ColumnSpacing = 8;
            app.RelErrGrid.Padding       = [8 6 8 8];
        
            % Row 1:
            xiLbl = uilabel(app.RelErrGrid,'Text','ξ step:','HorizontalAlignment','right','Tag','Rel_xiLbl');
            xiLbl.Layout.Row = 1; xiLbl.Layout.Column = 1;
        
            app.XiKnotsDrop = uidropdown(app.RelErrGrid, ...
                'Items',     {'Choose ξ','0.5','0.05','0.01','0.005'}, ...
                'ItemsData', {"",         0.5,  0.05,  0.01,  0.005}, ...
                'Value', "", ...
                'ValueChangedFcn', @(dd,ev) app.onXiKnotsChanged(ev), ...
                'Tag','Rel_XiKnotsDrop');
            app.XiKnotsDrop.Layout.Row = 1; 
            app.XiKnotsDrop.Layout.Column = 2;
        
            cLbl = uilabel(app.RelErrGrid,'Text','c step:','HorizontalAlignment','right','Tag','Rel_cLbl');
            cLbl.Layout.Row = 1;  cLbl.Layout.Column = 3;
        
            app.CKnotsDrop = uidropdown(app.RelErrGrid, ...
                'Items',     {'Choose c','0.25','0.1','0.05','0.005'}, ...
                'ItemsData', {"",        0.25,   0.1,   0.05,  0.005}, ...
                'Value', "", ...
                'ValueChangedFcn', @(dd,ev) app.onCKnotsChanged(ev), ...
                'Tag','Rel_CKnotsDrop');
            app.CKnotsDrop.Layout.Row = 1; 
            app.CKnotsDrop.Layout.Column = 4;
        
            wLbl = uilabel(app.RelErrGrid,'Text','Workers:','HorizontalAlignment','right','Tag','Rel_wLbl');
            wLbl.Layout.Row = 1; wLbl.Layout.Column = 5;
        
            app.WorkersDrop = uidropdown(app.RelErrGrid,'Items',{'2','5','10'},'Value','5','Tag','Rel_WorkersDrop');
            app.WorkersDrop.Layout.Row = 1; 
            app.WorkersDrop.Layout.Column = 6;
        
            app.ComputeBtn  = uibutton(app.RelErrGrid,'Text','Compute Relative Errors','ButtonPushedFcn',@app.onComputeRelErr,'Tag','Rel_ComputeBtn');
            app.ComputeBtn.Layout.Row = 1; 
            app.ComputeBtn.Layout.Column = 7;    
            app.ComputeBtn.BackgroundColor = [0.9 0.95 1];
        
            % Row 2:
            plotOptLbl = uilabel(app.RelErrGrid,'Text','Plot option:','HorizontalAlignment','right','Tag','Rel_plotOptLbl');
            plotOptLbl.Layout.Row = 2; 
            plotOptLbl.Layout.Column = 1;
        
            app.RelPlotChoice = uidropdown(app.RelErrGrid, ...
                'Items',     {'Choose plot type', ...
                              'Contour Plot l2 Error','Surface Plot l2 Error', ...
                              'Contour Plot linf Error','Surface Plot linf Error'}, ...
                'ItemsData', {"", ...
                              "l2-contour","l2-surface","linf-contour","linf-surface"}, ...
                'Value', "", ...
                'ValueChangedFcn', @(dd,ev) app.onRelPlotChoiceChanged(ev), ...
                'Tag','Rel_RelPlotChoice');
            app.RelPlotChoice.Layout.Row = 2; 
            app.RelPlotChoice.Layout.Column = [2 3];
        
            app.PlotRelErrBtn = uibutton(app.RelErrGrid,'Text','Plot Relative Errors','ButtonPushedFcn',@app.onPlotRelErr,'Tag','Rel_PlotRelErrBtn');
            app.PlotRelErrBtn.Layout.Row = 2; 
            app.PlotRelErrBtn.Layout.Column = 7;   
            app.PlotRelErrBtn.BackgroundColor = [0.9 0.95 1];
        
            % Row 3: Tip
            app.ErrTipLbl = uilabel(app.RelErrGrid, ...
                'Text','Tip: To start, choose ξ and c. Then press "Compute Relative Errors" button. ', ...
                'HorizontalAlignment','left','WordWrap','on','Tag','Rel_TipLbl');
            app.ErrTipLbl.Layout.Row = 3;  
            app.ErrTipLbl.Layout.Column = [1 8];
        
            % Spacer row anchor
            relDummy = uilabel(app.RelErrGrid,'Text','','Tag','Rel_Dummy'); 
            relDummy.Layout.Row = 10; relDummy.Layout.Column = 1;
        
            % === IDP Tab ===
            app.IDPTab  = uitab(app.Tabs,'Title','Solve and Plot Inverse Data Problem','Scrollable','off');
            idpTabGrid = uigridlayout(app.IDPTab,[1 1],'Padding',[0 0 0 0],'RowHeight',{'1x'},'ColumnWidth',{'1x'});
            idpScroll  = uipanel(idpTabGrid,'BorderType','none','Scrollable','on','AutoResizeChildren','off');
            idpScroll.Layout.Row = 1; idpScroll.Layout.Column = 1;
            idpInner   = uipanel(idpScroll,'BorderType','none','Units','pixels','AutoResizeChildren','off');
            idpInner.Position = [0 0 idpScroll.InnerPosition(3) idpScroll.InnerPosition(4)];
            idpScroll.SizeChangedFcn = @(src,~) app.updateScrollInner(src, idpInner);
        
            app.IDPGrid = uigridlayout(idpInner,[10 8],'Tag','IDPGrid');
            app.IDPGrid.RowHeight   = {'fit','fit','fit', 1,1,1,1,1,1, 1};
            app.IDPGrid.ColumnWidth = {80, 70, 90, 70, 30, 100, 130, '1x'};
            app.IDPGrid.RowSpacing    = 4;
            app.IDPGrid.ColumnSpacing = 8;
            app.IDPGrid.Padding       = [8 6 8 8];
        
            %  Row 1
            lblXi = uilabel(app.IDPGrid,'Text','ξ [0,1]:','HorizontalAlignment','right','Tag','IDP_lblXi');
            lblXi.Layout.Row = 1;  lblXi.Layout.Column = 1;
        
            app.XiIDPField = uieditfield(app.IDPGrid,'numeric','Limits',[0 1],'Value',0.41,'Tag','IDP_XiField');
            app.XiIDPField.Layout.Row = 1;  app.XiIDPField.Layout.Column = 2;
        
            lblC = uilabel(app.IDPGrid,'Text','c [-0.25,0.25]:','HorizontalAlignment','right','Tag','IDP_lblC');
            lblC.Layout.Row = 1;  lblC.Layout.Column = 3;
        
            app.CIDPField  = uieditfield(app.IDPGrid,'numeric','Limits',[-0.25 0.25],'Value',-0.005,'Tag','IDP_CField');
            app.CIDPField.Layout.Row = 1;  app.CIDPField.Layout.Column = 4;
        
            lblPsi = uilabel(app.IDPGrid,'Text','ψ:','HorizontalAlignment','right','Tag','IDP_lblPsi');
            lblPsi.Layout.Row = 1;  lblPsi.Layout.Column = 5;
        
            app.PsiIDPDrop = uidropdown(app.IDPGrid,'Items',{'psiQuadratic'},'Value',app.psiDefault,'Tag','IDP_PsiDrop');
            app.PsiIDPDrop.Layout.Row = 1;  app.PsiIDPDrop.Layout.Column = 6;   
        
            app.SolveIDPBtn = uibutton(app.IDPGrid,'Text','Solve Inverse Problem','ButtonPushedFcn',@app.onSolveIDP,'Tag','IDP_SolveBtn');
            app.SolveIDPBtn.Layout.Row = 1;  app.SolveIDPBtn.Layout.Column = 7;  
            app.SolveIDPBtn.BackgroundColor = [0.9 0.95 1];
        
            % Row 2: Parameter + Plot
            lblParam = uilabel(app.IDPGrid,'Text','Parameter:','HorizontalAlignment','right','Tag','IDP_lblParam');
            lblParam.Layout.Row = 2;  lblParam.Layout.Column = 1;
        
            app.ParamPlotDrop = uidropdown(app.IDPGrid, ...
                'Items', {'Choose parameter', ...
                          'alpha - Vaccination parameter', ...
                          'beta - Transmission rate', ...
                          'gamma - Recovery rate of non-hospitalized individuals', ...
                          'rho - Hospitalization rate', ...
                          'sigma - Recovery rate of hospitalized individuals', ...
                          'tau - Mortality rate of infectious people'}, ...
                'ItemsData', {"", ...
                              "alpha-param","beta-param","gamma-param","rho-param","sigma-param","tau-param"}, ...
                'Value', "", ...
                'ValueChangedFcn', @(dd,ev) app.onParamPlotChoiceChanged(ev), ...
                'Tag','IDP_ParamDrop');
            app.ParamPlotDrop.Layout.Row    = 2;  
            app.ParamPlotDrop.Layout.Column = [2 3];                           
        
            app.PlotParamBtn  = uibutton(app.IDPGrid,'Text','Plot Parameter','ButtonPushedFcn',@app.onPlotIDPParam,'Tag','IDP_PlotBtn');
            app.PlotParamBtn.Layout.Row  = 2;  
            app.PlotParamBtn.Layout.Column  = 7;                               
            app.PlotParamBtn.BackgroundColor = [0.9 0.95 1];
        
            % Row 3: Tip text
            app.IDPTipLbl = uilabel(app.IDPGrid, ...
                'Text', ['Tip: ξ and c here are already pre-filled from Relative Errors minima: 0.41 and -0.005. ' ...
                         'Edit ξ and c to try other values.'], ...
                'HorizontalAlignment','left','WordWrap','on','Tag','IDP_Tip');
            app.IDPTipLbl.Layout.Row = 3;  
            app.IDPTipLbl.Layout.Column = [1 8];
        
            idpDummy = uilabel(app.IDPGrid,'Text','','Tag','IDP_Dummy');
            idpDummy.Layout.Row = 10; idpDummy.Layout.Column = 1;
        
            % === Direct Tab ===
            app.DirectTab  = uitab(app.Tabs,'Title','Solve and Plot Direct problem','Scrollable','off');
            dirTabGrid = uigridlayout(app.DirectTab,[1 1],'Padding',[0 0 0 0],'RowHeight',{'1x'},'ColumnWidth',{'1x'});
            dirScroll  = uipanel(dirTabGrid,'BorderType','none','Scrollable','on','AutoResizeChildren','off');
            dirScroll.Layout.Row = 1; dirScroll.Layout.Column = 1;
            dirInner   = uipanel(dirScroll,'BorderType','none','Units','pixels','AutoResizeChildren','off');
            dirInner.Position = [0 0 dirScroll.InnerPosition(3) dirScroll.InnerPosition(4)];
            dirScroll.SizeChangedFcn = @(src,~) app.updateScrollInner(src, dirInner);
        
            app.DirectGrid = uigridlayout(dirInner,[10 8],'Tag','DirectGrid');
            app.DirectGrid.RowHeight     = {'fit','fit','fit', 1,1,1,1,1,1, 1};
            app.DirectGrid.ColumnWidth   = {80, 70, 90, 70, 30, 100, 130, '1x'};
            app.DirectGrid.RowSpacing    = 4;
            app.DirectGrid.ColumnSpacing = 8;
            app.DirectGrid.Padding       = [8 6 8 8];
        
            % Row 1 
            lblXiD = uilabel(app.DirectGrid,'Text','ξ [0,1]:','HorizontalAlignment','right','Tag','D_lblXi');
            lblXiD.Layout.Row = 1;  lblXiD.Layout.Column = 1;
        
            app.XiDirectField = uieditfield(app.DirectGrid,'numeric','Limits',[0 1],'Value',0.41,'Tag','D_XiField');
            app.XiDirectField.Layout.Row = 1;  app.XiDirectField.Layout.Column = 2;   
        
            lblCD = uilabel(app.DirectGrid,'Text','c [-0.25,0.25]:','HorizontalAlignment','right','Tag','D_lblC');
            lblCD.Layout.Row = 1;  lblCD.Layout.Column = 3;
        
            app.CDirectField  = uieditfield(app.DirectGrid,'numeric','Limits',[-0.25 0.25],'Value',-0.005,'Tag','D_CField');
            app.CDirectField.Layout.Row = 1;  app.CDirectField.Layout.Column = 4;   
        
            lblPsiD = uilabel(app.DirectGrid,'Text','ψ:','HorizontalAlignment','right','Tag','D_lblPsi');
            lblPsiD.Layout.Row = 1;  lblPsiD.Layout.Column = 5;
        
            app.PsiDirectDrop = uidropdown(app.DirectGrid,'Items',{'psiQuadratic'},'Value',app.psiDefault,'Tag','D_PsiDrop');
            app.PsiDirectDrop.Layout.Row = 1;  app.PsiDirectDrop.Layout.Column = 6;  
        
            app.SolveDirectBtn = uibutton(app.DirectGrid, 'Text','Solve Direct Problem', 'ButtonPushedFcn', @(~,~) app.onSolveDirect(),'Tag','D_SolveBtn');
            app.SolveDirectBtn.Layout.Row = 1;  app.SolveDirectBtn.Layout.Column = 7; 
            app.SolveDirectBtn.BackgroundColor = [0.9 0.95 1];
        
            % Row 2
            lblPlotOpt = uilabel(app.DirectGrid,'Text','Plot option:','HorizontalAlignment','right','Tag','D_lblPlot');
            lblPlotOpt.Layout.Row = 2;  lblPlotOpt.Layout.Column = 1;
        
            app.DirectPlotDrop = uidropdown(app.DirectGrid, ...
                'Items', { ...
                    'Choose plot', ...
                    'N & S together (computed only)', ...
                    'I & V together (computed only)', ...
                    'E & H together (computed only)', ...
                    'R & B together (computed only)', ...
                    'A (computed vs. reported)', ...
                    'Vtotal (computed vs. reported)', ...
                    'Rtotal (computed vs. reported)', ...
                    'Dtotal (computed vs. reported)', ...
                    'Htotal (computed vs. reported)'}, ...
                'ItemsData', { ...
                     "", ...
                    "ns-model","iv-model","eh-model","rb-model", ...
                    "a-vs-reported","vtotal-vs-reported","rtotal-vs-reported","dtotal-vs-reported","htotal-vs-reported"}, ...
                'Value', "", ...
                'ValueChangedFcn', @(dd,ev) app.onDirectPlotChoiceChanged(ev), ...
                'Tag','D_PlotDrop');
            app.DirectPlotDrop.Layout.Row = 2;  
            app.DirectPlotDrop.Layout.Column = [2 3];
        
            app.PlotDirectBtn  = uibutton(app.DirectGrid, 'Text','Plot Selected', 'ButtonPushedFcn', @(~,~) app.onPlotDirect(),'Tag','D_PlotBtn');
            app.PlotDirectBtn.Layout.Row  = 2;  app.PlotDirectBtn.Layout.Column  = 7;
            app.PlotDirectBtn.BackgroundColor = [0.9 0.95 1];
        
            % Row  3
            app.DirectTipLbl = uilabel(app.DirectGrid, ...
            'Text', ['Tip: The values of ξ and c are pre-filled from the Relative Errors minima (0.41 and -0.005). ' ...
                     'Edit ξ and c to try other values. The direct solver uses the parameter values calculated ' ...
                     'by the inverse problem solver in the "Solve and Plot Inverse Data Problem" tab.'], ...
            'HorizontalAlignment','left','WordWrap','on','Tag','D_Tip');
            app.DirectTipLbl.Layout.Row = 3;  app.DirectTipLbl.Layout.Column = [1 8];
        
            dirDummy = uilabel(app.DirectGrid,'Text','','Tag','D_Dummy');
            dirDummy.Layout.Row = 10; dirDummy.Layout.Column = 1;
        
            % ---- Row 3: Embedded Plot ----
            app.PlotPanel = uipanel(app.LeftGrid,'Title','Embedded Plot');
            app.PlotPanel.Layout.Row = 3; app.PlotPanel.Layout.Column = 1;
            app.PlotPanel.BackgroundColor = [0.9 0.95 1];
        
            PlotGrid = uigridlayout(app.PlotPanel,[2 1]);
            PlotGrid.RowSpacing    = 0;
            PlotGrid.ColumnSpacing = 0;
            PlotGrid.Padding       = [0 0 0 0];
            PlotGrid.RowHeight     = {'1x', 24};
            PlotGrid.ColumnWidth   = {'1x'};
        
            app.Ax = uiaxes(PlotGrid,'FontSize',12);
            app.Ax.Layout.Row = 1; 
            app.Ax.Layout.Column = 1;
            grid(app.Ax,'on'); app.Ax.Box = 'on';
        
            xLbl = uilabel(PlotGrid,'Text','', 'HorizontalAlignment','center','FontSize',16);
            xLbl.Layout.Row = 2; xLbl.Layout.Column = 1;
        
            text(app.Ax, 0.5, 0.5, ...
            {'Choose ξ and c. Then press "Compute Relative Errors".'; ...
             'Then choose plot type and press "Plot Relative Errors".'}, ...
            'Units','normalized', ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'Color',[0.35 0.35 0.35], ...
            'FontSize',12, ...
            'Interpreter','none', ...
            'HitTest','off');
        
            % ==== Right column: Logger ====
            app.LoggerPanel = uipanel(app.RootGrid,'Title','Logger','Scrollable','on');
            app.LoggerPanel.Layout.Row = 1; app.LoggerPanel.Layout.Column = 2;
            app.LoggerPanel.BackgroundColor = [0.9 0.95 1];
        
            app.LoggerGrid = uigridlayout(app.LoggerPanel,[3 1]);
            app.LoggerGrid.RowHeight   = {'1x','fit','fit'};
            app.LoggerGrid.ColumnWidth = {'1x'};
        
            app.LoggerArea = uitextarea(app.LoggerGrid,'Editable','off');
            btnRow = uigridlayout(app.LoggerGrid,[1 2]); 
            btnRow.ColumnWidth={'1x','1x'};
            app.CopyLogBtn  = uibutton(btnRow,'Text','Copy','ButtonPushedFcn',@app.onCopyLog);
            app.ClearLogBtn = uibutton(btnRow, 'Text','Clear', 'ButtonPushedFcn', @(~,~) app.onClearLog());
        
            app.CopyLogBtn.BackgroundColor = [0.9 0.95 1];
            app.ClearLogBtn.BackgroundColor = [0.9 0.95 1];
        
            app.HelpTipLbl = uilabel(app.LoggerGrid,'HorizontalAlignment','left', ...
                'Text', sprintf(['Tips:\n',...
                '• Auto-load searches the app’s folder BGDataKnown.mat and BGParamKnown.mat. \n You can also load the files manually.\n', ...
                '• "Compute Relative Error" saves %s and logs minima in the Logger view.\n', ...
                '• All plots render inside the app.'], app.matFile));
        
            % ==== Reflow on resize ====
            app.UIFigure.SizeChangedFcn = @(~,~) app.reflowUI();
            drawnow; 
            app.reflowUI();
        end
        
        function reflowUI(app)
            pos = app.UIFigure.Position;
            w = pos(3); h = pos(4);
            compact = (w < 1050) || (h < 650);
        
            % choose a spacer height big enough to force scroll when compact
            spacerPx = max(320, round(0.5*h));  
        
            % ---------- Relative Errors ----------
            G = app.RelErrGrid;
            if ~isempty(G) && isvalid(G)
               if compact
                    G.ColumnWidth = {'fit','1x'};
                    G.RowHeight   = {'fit','fit','fit','fit','fit','fit','fit'};
                    app.setCell(G,'Rel_xiLbl',         1,1);
                    app.setCell(G,'Rel_XiKnotsDrop',   1,2);
                    app.setCell(G,'Rel_cLbl',          2,1);
                    app.setCell(G,'Rel_CKnotsDrop',    2,2);
                    app.setCell(G,'Rel_wLbl',          3,1);
                    app.setCell(G,'Rel_WorkersDrop',   3,2);
                    app.setCell(G,'Rel_ComputeBtn',    4,2);  
                    app.setCell(G,'Rel_plotOptLbl',    5,1);
                    app.setCell(G,'Rel_RelPlotChoice', 5,2);
                    app.setCell(G,'Rel_PlotRelErrBtn', 6,2);
                    app.setCell(G,'Rel_TipLbl',        7,1,2);
                else
                    G.ColumnWidth = {'fit','fit','fit','fit','fit','fit','fit','1x'};
                    G.RowHeight   = {'fit','fit','fit'};
                    app.setCell(G,'Rel_xiLbl',         1,1);
                    app.setCell(G,'Rel_XiKnotsDrop',   1,2);
                    app.setCell(G,'Rel_cLbl',          1,3);
                    app.setCell(G,'Rel_CKnotsDrop',    1,4);
                    app.setCell(G,'Rel_wLbl',          1,5);
                    app.setCell(G,'Rel_WorkersDrop',   1,6);
                    app.setCell(G,'Rel_ComputeBtn',    1,7);  % unchanged in wide mode
                    app.setCell(G,'Rel_plotOptLbl',    2,1);
                    app.setCell(G,'Rel_RelPlotChoice', 2,2,3);
                    app.setCell(G,'Rel_PlotRelErrBtn', 2,7);
                    app.setCell(G,'Rel_TipLbl',        3,1,8);
               end
           end
        
            % ---------- IDP ----------
            Gi = app.IDPGrid;
            if ~isempty(Gi) && isvalid(Gi)
                if compact
                    Gi.ColumnWidth = {'fit','1x'};
                    Gi.RowHeight   = {'fit','fit','fit','fit','fit','fit','fit','fit','fit', spacerPx};
                    app.setCell(Gi,'IDP_lblXi',      1,1);
                    app.setCell(Gi,'IDP_XiField',    1,2);
                    app.setCell(Gi,'IDP_lblC',       2,1);
                    app.setCell(Gi,'IDP_CField',     2,2);
                    app.setCell(Gi,'IDP_lblPsi',     3,1);
                    app.setCell(Gi,'IDP_PsiDrop',    3,2);
                    app.setCell(Gi,'IDP_SolveBtn',   4,2);
                    app.setCell(Gi,'IDP_lblParam',   5,1);
                    app.setCell(Gi,'IDP_ParamDrop',  5,2);
                    app.setCell(Gi,'IDP_PlotBtn',    6,2);
                    app.setCell(Gi,'IDP_Tip',        7,1,2);
                else
                    Gi.ColumnWidth = {80, 70, 90, 70, 30, 100, 130, '1x'};
                    Gi.RowHeight   = {'fit','fit','fit', 1,1,1,1,1,1, 1};
                    app.setCell(Gi,'IDP_lblXi',      1,1);
                    app.setCell(Gi,'IDP_XiField',    1,2);
                    app.setCell(Gi,'IDP_lblC',       1,3);
                    app.setCell(Gi,'IDP_CField',     1,4);
                    app.setCell(Gi,'IDP_lblPsi',     1,5);
                    app.setCell(Gi,'IDP_PsiDrop',    1,6);
                    app.setCell(Gi,'IDP_SolveBtn',   1,7);
                    app.setCell(Gi,'IDP_lblParam',   2,1);
                    app.setCell(Gi,'IDP_ParamDrop',  2,2,3);
                    app.setCell(Gi,'IDP_PlotBtn',    2,7);
                    app.setCell(Gi,'IDP_Tip',        3,1,8);
                end
            end
        
            % ---------- Direct ----------
            Gd = app.DirectGrid;
            if ~isempty(Gd) && isvalid(Gd)
                if compact
                    Gd.ColumnWidth = {'fit','1x'};
                    Gd.RowHeight   = {'fit','fit','fit','fit','fit','fit','fit','fit','fit', spacerPx};
                    app.setCell(Gd,'D_lblXi',     1,1);
                    app.setCell(Gd,'D_XiField',   1,2);
                    app.setCell(Gd,'D_lblC',      2,1);
                    app.setCell(Gd,'D_CField',    2,2);
                    app.setCell(Gd,'D_lblPsi',    3,1);
                    app.setCell(Gd,'D_PsiDrop',   3,2);
                    app.setCell(Gd,'D_lblPlot',   4,1);
                    app.setCell(Gd,'D_PlotDrop',  4,2);
                    app.setCell(Gd,'D_SolveBtn',  5,2);
                    app.setCell(Gd,'D_PlotBtn',   6,2);
                    app.setCell(Gd,'D_Tip',       7,1,2);
                else
                    Gd.ColumnWidth = {80, 70, 90, 70, 30, 100, 130, '1x'};
                    Gd.RowHeight   = {'fit','fit','fit', 1,1,1,1,1,1, 1};
                    app.setCell(Gd,'D_lblXi',     1,1);
                    app.setCell(Gd,'D_XiField',   1,2);
                    app.setCell(Gd,'D_lblC',      1,3);
                    app.setCell(Gd,'D_CField',    1,4);
                    app.setCell(Gd,'D_lblPsi',    1,5);
                    app.setCell(Gd,'D_PsiDrop',   1,6);
                    app.setCell(Gd,'D_SolveBtn',  1,7);
                    app.setCell(Gd,'D_lblPlot',   2,1);
                    app.setCell(Gd,'D_PlotDrop',  2,2,3);
                    app.setCell(Gd,'D_PlotBtn',   2,7);
                    app.setCell(Gd,'D_Tip',       3,1,8);
                end
            end
        end
        
        function setCell(app, parentGrid, tag, row, col, colEnd)
            h = findobj(parentGrid, 'Tag', tag, '-not', 'Type','uipanel');
            if isempty(h), return; end
            h = h(1);
            if ~isprop(h, 'Layout'), return; end
            h.Layout.Row = row;
            if nargin < 6 || isempty(colEnd)
                h.Layout.Column = col;
            else
                h.Layout.Column = [col colEnd];
            end
        end
        function updateScrollInner(app, scrollPanel, innerPanel)
            ip = scrollPanel.InnerPosition;              % [x y w h] of the scrollable viewport
            w  = max(1, ip(3));
            h  = max(1, ip(4));
        
            figPos  = app.UIFigure.Position;
            compact = (figPos(3) < 1050) || (figPos(4) < 650);
        
            if compact
                tailPx  = 64;                          
                gutter  = 20;                            %  kill horizontal bar
                innerPanel.Position = [0 0 max(1, w - gutter)  (h + tailPx)];
            else
                innerPanel.Position = [0 0 w h];         
            end
        
            % Ensure grids expand horizontally (avoids horizontal overflow)
            grids = findall(innerPanel, 'Type', 'uigridlayout');
            for g = reshape(grids,1,[])
                try
                    if iscell(g.ColumnWidth) && ~isempty(g.ColumnWidth)
                        g.ColumnWidth{end} = '1x';
                    end
                    if compact
                        pad = g.Padding;  % [L T R B]
                        if numel(pad)==4
                            g.Padding = [max(0,pad(1)-4) pad(2) max(0,pad(3)-4) pad(4)];
                        end
                        if isprop(g,'ColumnSpacing'); g.ColumnSpacing = max(0, g.ColumnSpacing - 2); end
                    end
                catch
                end
            end
        end

       
        function styleDateAxisUI(app, ax, t0, t1, mode)
        %STYLEDATEAXISUI Style a date x-axis for Axes/UIAxes (R2020b+ compatible).
        %   - Monthly ticks "dd-mmm" (font size 10)
        %   - Year lines (Jan-01) dashed with labels that move on zoom/pan (xline)
        %   - 'params' mode: adds 08-Jun (start) and 12-Mar (end) ticks and hides 01-Mar label
        %   - Non-'params' (direct) plots: show "Time" x-label
        %
        %   styleDateAxisUI(app, ax, t0, t1)
        %   styleDateAxisUI(app, ax, t0, t1, 'params')
        
            if nargin < 5, mode = ''; end
            if t1 < t0, [t0,t1] = deal(t1,t0); end
        
            % Pad ends horizontally
            ax.XLim = [t0 - days(5), t1 + days(5)];
        
            % ----- Monthly ticks -----
            mStart = dateshift(t0,'start','month');
            mEnd   = dateshift(t1,'start','month');
            ticks  = dateshift(mStart:calmonths(1):mEnd,'start','month');
        
            isParams = ~isempty(mode) && (strcmpi(mode,'params') || isequal(mode,true));
            if isParams
                tJun = datetime(year(t0),6,8);
                tMar = datetime(year(t1),3,12);
            else
                tJun = datetime(year(t0),6,7);
                tMar = datetime(year(t1),3,12);
            end
            ticks = unique([ticks, tJun, tMar]); 
        
            % Build labels (use datestr for R2020b compatibility)
            lbl = cell(size(ticks));
            for k = 1:numel(ticks)
                lbl{k} = char(datestr(ticks(k),'dd-mmm'));  % e.g., '01-Jul'
            end
        
            % Hide 01-Mar of end year to avoid overlap
            kMar01 = find(ticks == datetime(year(t1),3,1), 1);
            if ~isempty(kMar01), lbl{kMar01} = ''; end
        
            % Ensure exact text for the special ticks
            if isParams
                kJun = find(ticks == datetime(year(t0),6,8), 1);
                if ~isempty(kJun), lbl{kJun} = '08-Jun'; end
                kMar = find(ticks == datetime(year(t1),3,12), 1);
                if ~isempty(kMar), lbl{kMar} = '12-Mar'; end
            else
                % states view already has 07-Jun / 12-Mar labels by default
            end
        
            % Slightly shift the June tick to reduce label collisions
            if isParams
                dJun = datetime(year(t0), 6, 8);
            else
                dJun = datetime(year(t0), 6, 7);
            end        
            kJun = find(ticks == dJun, 1);
            if ~isempty(kJun)
                ticks(kJun) = dJun + hours(20);  % small shift
            end
        
            % ----- Apply ticks/labels -----
            ax.XTick = ticks;
            ax.XTickLabel     = lbl;
            ax.XTickLabelMode = 'manual';
            ax.XTickLabelRotation = 45;     % adjust if your param plots use a different rotation
            ax.TickLabelInterpreter = 'none';
            ax.FontSize = 10;
        
            ax.XLabel.String  = 'Time';
            ax.XLabel.Visible = 'on';
            ax.XLabel.FontSize = 16;
        
            % ----- Year guide lines (labels move with zoom/pan) -----
            delete(findall(ax,'Type','ConstantLine','Tag','YearMarker'));
            XL = ax.XLim;
            y0 = year(XL(1)); y1 = year(XL(2));
            hold(ax,'on');
            for Y = y0:y1
                xJan = datetime(Y,1,1);
                if xJan < XL(1) || xJan > XL(2), continue; end
                xline(ax, xJan, '--', num2str(Y), ...
                    'Color',[0.3 0.3 0.3], 'LineWidth',0.9, ...
                    'LabelVerticalAlignment','bottom', ...
                    'LabelHorizontalAlignment','right', ...
                    'HandleVisibility','off', 'Tag','YearMarker');
            end
            hold(ax,'off');
        
            % ----- Title styling to match parameter plots -----
            if ~isempty(ax.Title)
                ax.Title.FontSize   = 16;
                ax.Title.FontWeight = 'bold';
                % ax.Title.Interpreter = 'none';
            end
        
            grid(ax,'on'); box(ax,'off');
        end 
    end
    %% ==== PUBLIC CTOR/DTOR ====
    methods (Access = public)
       function app = SEIRSVBHSimulator
        % --- destroy any previous instance by tag 
        oldFigs = findall(0,'Type','figure','Tag','SEIRSVBHSimulatorMain');
        if ~isempty(oldFigs)
            try
                delete(oldFigs);
            catch
                % ignore errors if the old figure is already gone
            end

        end
    
        % ---  destroy the previously stored app handle (if any)
        oldApp = getappdata(0,'SEIRSVBHSimulator_Handle');
        if ~isempty(oldApp) && isvalid(oldApp)
            try
                delete(oldApp);
            catch
                % ignore errors if the old figure is already gone
            end

        end
    
        % --- Create this instance
        createComponents(app);
        registerApp(app, app.UIFigure);
        runStartupFcn(app, @app.startupFcn);
    
        % --- Remember this instance globally for the next launch
        setappdata(0,'SEIRSVBHSimulator_Handle',app);
       end
       function delete(app)
            % Clear the global handle if it still points to me
            stored = getappdata(0,'SEIRSVBHSimulator_Handle');
            if ~isempty(stored) && isequal(stored, app)
                setappdata(0,'SEIRSVBHSimulator_Handle',[]);
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end

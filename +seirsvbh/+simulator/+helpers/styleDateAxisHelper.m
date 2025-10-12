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

function styleDateAxisHelper(ax, tvec, varargin)
% styleDateAxisHelper  Apply monthly ticks + year markers to a datetime x-axis.
%
% Special handling:
%   - 01-Jun-(start year): keep tick, HIDE label; add tick 07/08-Jun with label "07/08 Jun"
%   - 01-Mar-(end year):   keep tick, HIDE label; add tick 12-Mar with label "12 Mar"
%
% Optional 3rd arg (mode):
%   - Omit or pass false/'states'  -> use 07-Jun
%   - Pass true or 'params'        -> use 08-Jun

    % ---- guards ----
    if ~isgraphics(ax,'axes'); return; end
    ax.FontSize = 10;
    if ~isdatetime(tvec), error('tvec must be a datetime vector.'); end
    tvec = sort(tvec(:));
    if isempty(tvec), return; end
    %if numel(tvec)==1, tvec = [tvec(1) tvec(1)+days(1)]; end
    if isscalar(tvec)
        if isdatetime(tvec) || isduration(tvec)
            tvec = [tvec, tvec + days(1)];
        else
            tvec = [tvec, tvec + 1];
        end
    end

    % Determine June day (07 = states, 08 = params)
    juneDay = 7;
    if nargin >= 3 && ~isempty(varargin{1})
        mode = varargin{1};
        if (islogical(mode) || isnumeric(mode)) && logical(mode)
            juneDay = 8;            % true -> params
        elseif ischar(mode) || isstring(mode)
            if strcmpi(string(mode),'params')
                juneDay = 8;
            end
        end
    end

    % Pad limits ±5 days
    ax.XLim = [tvec(1) - days(5), tvec(end) + days(5)];

    % Store years + juneDay for callbacks
    ud = get(ax,'UserData'); if ~isstruct(ud), ud = struct(); end
    ud.startYear = year(tvec(1));
    ud.endYear   = year(tvec(end));
    ud.juneDay   = juneDay;        % 7 or 8
    set(ax,'UserData',ud);

    % Initial ticks/labels
    setMonthlyTicksWithJuneMarch(ax, ax.XLim);

    % Base format and angle
    ax.XAxis.TickLabelFormat = 'dd MMM';
    xtickangle(ax,45);

    % Year markers
    drawYearMarkers(ax, ax.XLim);

    % Callbacks
    attachTickAdjuster(ax);
    localAdjustDateTicks(ax);
end

% ================= helpers =================

function setMonthlyTicksWithJuneMarch(ax, xl)
    if ~isgraphics(ax,'axes'); return; end
    ud = get(ax,'UserData'); startY = ud.startYear; endY = ud.endYear; juneDay = ud.juneDay;

    % Base monthly ticks (1st of month in view)
    m0 = dateshift(xl(1),'start','month');
    if m0 < xl(1), m0 = dateshift(m0,'start','month','next'); end
    m1 = dateshift(xl(2),'start','month');
    monthly = m0:calmonths(1):m1;

    % Special dates
    d01Jun = datetime(startY,6,1);
    dXXJun = datetime(startY,6,juneDay); % 07 (states) or 08 (params)
    d01Mar = datetime(endY,3,1);
    d12Mar = datetime(endY,3,12);

    inView = @(d) d>=xl(1) && d<=xl(2);

    % Ensure extra ticks (we don’t remove the 1st-of-month ones; we just hide their labels)
    extra = datetime.empty(1,0);
    if inView(dXXJun), extra(end+1) = dXXJun; end 
    if inView(d12Mar), extra(end+1) = d12Mar; end 

    ax.XTick = unique([monthly extra]);

    % Labels: default 'dd MMM', then blank 01-Jun / 01-Mar and set XX-Jun / 12-Mar
    labels = cellstr(string(ax.XTick,'dd MMM'));

    if inView(d01Jun)
        i = find(ax.XTick==d01Jun,1); if ~isempty(i), labels{i} = ''; end
    end
    if inView(dXXJun)
        i = find(ax.XTick==dXXJun,1);
        if ~isempty(i), labels{i} = string(dXXJun,'dd MMM'); end   % "07 Jun" or "08 Jun"
    end
    if inView(d01Mar)
        i = find(ax.XTick==d01Mar,1); if ~isempty(i), labels{i} = ''; end
    end
    if inView(d12Mar)
        i = find(ax.XTick==d12Mar,1); if ~isempty(i), labels{i} = '12 Mar'; end
    end

    ax.XTickLabel = labels;
end

function attachTickAdjuster(ax)
    if ~isgraphics(ax,'axes'); return; end
    ud = get(ax,'UserData'); if ~isstruct(ud), ud = struct(); end
    if ~isfield(ud,'xlimListener') || ~isvalid(ud.xlimListener)
        ud.xlimListener = addlistener(ax,'XLim','PostSet', @(~,~) localAdjustDateTicks(ax));
        set(ax,'UserData',ud);
    end
    fig = ancestor(ax,'figure');
    if ~isempty(fig) && isgraphics(fig,'figure')
        z = zoom(fig); z.ActionPostCallback = @(~,ev) localAdjustDateTicks(ev.Axes);
        p = pan(fig);  p.ActionPostCallback = @(~,ev) localAdjustDateTicks(ev.Axes);
    end
end

function localAdjustDateTicks(ax)
    if ~isgraphics(ax,'axes'); return; end
    xl = ax.XLim; if ~isdatetime(xl); return; end

    spanDays = days(xl(2)-xl(1));
    if spanDays <= 45
        % Daily ticks when zoomed in
        t0 = dateshift(xl(1),'start','day');
        t1 = dateshift(xl(2),'start','day');
        ax.XTick = t0:days(1):t1;
        ax.XTickLabelMode = 'auto';
        ax.XAxis.TickLabelFormat = 'dd MMM';
    else
        % Monthly ticks with June/March rules
        setMonthlyTicksWithJuneMarch(ax, xl);
        ax.XAxis.TickLabelFormat = 'dd MMM';
    end

    drawYearMarkers(ax, xl);
    xtickangle(ax,45);
end

function drawYearMarkers(ax, xl)
    if ~isgraphics(ax,'axes'); return; end
    delete(findall(ax,'Type','ConstantLine','Tag','YearMarker'));
    y0 = year(xl(1)); y1 = year(xl(2));
    hold(ax,'on');
    xline(ax, xl(1), '--', num2str(y0), ...
        'LabelVerticalAlignment','bottom', ...
        'LabelHorizontalAlignment','right', ...
        'HandleVisibility','off', 'Tag','YearMarker',  'FontSize', 12);
    for Y = y0:y1
        xJan = datetime(Y,1,1);
        if xJan < xl(1) || xJan > xl(2), continue; end
        xline(ax, xJan, '--', num2str(Y), ...
            'LabelVerticalAlignment','bottom', ...
            'LabelHorizontalAlignment','right', ...
            'HandleVisibility','off', 'Tag','YearMarker',  'FontSize', 12);
    end
    hold(ax,'off');
end

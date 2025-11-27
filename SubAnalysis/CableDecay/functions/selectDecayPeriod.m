function [decayTime, decayData, Idx] = selectDecayPeriod(time, data)
%SELECTDECAYPERIOD Interactively select a decay period from a time signal.
%   [DECAYTIME, DECAYDATA, FIRSTIDX, LASTIDX] = SELECTDECAYPERIOD(TIME, DATA)
%   lets the user visually select a decay region:
%
%   - LEFT-CLICK twice to set [t1, t2]
%       * if t2 > t1 -> zooms/sets that interval
%       * if t2 <= t1 -> reset zoom to full signal
%   - ENTER (Return) exits and returns the current selection.
%   - Vertical lines show each click (cleared after each zoom).
%
%   A highlighted red trace shows the currently selected decay.


    if numel(time) ~= numel(data)
        error('TIME and DATA must have the same number of elements.');
    end

    time = time(:);
    data = data(:);

    fig = figure('Name','Select decay period','NumberTitle','off');
    if exist('theme','file')
        try, theme(fig,"light"); end
    end

    ax = axes('Parent',fig);
    hold(ax,'on');
    grid(ax,'on');

    hHighlight = plot(ax, time, data, 'r-', 'LineWidth', 1.5);
    xlabel(ax,'Time');
    ylabel(ax,'Amplitude');
    title(ax,{'Decay selection',...
        'LEFT-CLICK twice to zoom/select, second ≤ first resets, ENTER to end'});

    % Initial selection is entire signal
    tStart = time(1);
    tEnd   = time(end);
    firstIdx = 1;
    lastIdx  = numel(time);

    

    xlim(ax,[tStart tEnd]);

    vLines = gobjects(0);  % vertical lines, cleared on every zoom

    while true
        % Get first click
        [x1, ~, button1] = ginput(1);

        if isempty(button1) || button1 == 13   % ENTER ends selection
            break;
        end
        if button1 ~= 1     % ignore non-left-clicks
            continue;
        end

        % Plot vertical line for first click
        yl = ylim(ax);
        vLines(end+1) = plot(ax, [x1 x1], yl, 'k--');

        % Get second click
        [x2, ~, button2] = ginput(1);

        if isempty(button2) || button2 == 13
            break;
        end
        if button2 ~= 1
            continue;
        end

        % Plot vertical line for second click
        vLines(end+1) = plot(ax, [x2 x2], yl, 'k--');

        % Clip values to data range
        x1 = max(min(x1, time(end)), time(1));
        x2 = max(min(x2, time(end)), time(1));

        % Zoom logic
        if x2 > x1
            tStart = x1;
            tEnd   = x2;
        else
            % Reset zoom
            tStart = time(1);
            tEnd   = time(end);
        end

        % Compute new indices
        firstIdx = find(time >= tStart, 1, 'first');
        lastIdx  = find(time <= tEnd,   1, 'last');

        if isempty(firstIdx) || isempty(lastIdx)
            continue;
        end

        % Clear ALL vertical lines on zoom change
        if ~isempty(vLines)
            delete(vLines(isgraphics(vLines)));
        end
        vLines = gobjects(0);

        % Update highlight
        if isgraphics(hHighlight), delete(hHighlight); end
        hHighlight = plot(ax, time(firstIdx:lastIdx), ...
                               data(firstIdx:lastIdx), 'r-', 'LineWidth',1.5);

        % Apply zoom
        xlim(ax,[tStart tEnd]);

        drawnow;
    end

    % Output final selection
    decayTime = time(firstIdx:lastIdx);
    decayData = data(firstIdx:lastIdx);

    Idx = [firstIdx,lastIdx];

    % Ensure the figure is closed after selection
    close(fig);
end

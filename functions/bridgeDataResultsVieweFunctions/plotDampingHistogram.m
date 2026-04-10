function plotDampingHistogram(allStats, flagFields, options)
% plotDampingHistogram Plots interactive damping histograms for selected flag fields.
%
% Description:
%   Creates one histogram per flag field using damping ratios from the
%   selected deck direction (Conc + Steel). Default direction is Z.
%   Click inside a tile to select one bin, click again to define a bin range,
%   and press D to open a selection dashboard.

arguments
    allStats table
    flagFields
    options.flagNames = []
    options.initialDirection {mustBeTextScalar} = "Z"
    options.numBins (1,1) double {mustBeInteger, mustBePositive} = 35
    options.normalization (1,1) string {mustBeMember(options.normalization, ["count", "probability"])} = "count"
    options.frequencyFocus (1,1) string {mustBeMember(options.frequencyFocus, ["all", "target"])} = "all"
    options.limits struct = struct()
    options.targetFreqs_override double = []
    options.freqTolerance_override double = []
    options.figureFolder (1,1) string = ""
    options.showMedianLine (1,1) logical = true
    options.showBoxStats (1,1) logical = true
    options.showCdf (1,1) logical = true
    options.xAxisScale (1,1) string {mustBeMember(options.xAxisScale, ["linear", "log"])} = "linear"
end

flagFields = string(cellstr(flagFields));
if isempty(options.flagNames)
    flagNames = flagFields;
else
    flagNames = string(cellstr(options.flagNames));
end

if numel(flagNames) ~= numel(flagFields)
    error('flagNames must have the same length as flagFields.');
end

targetFreqs = iResolveTargetFreqs(options);
freqTolerance = iResolveTolerance(options);
directions = ["X", "Y", "Z"];
initialDirection = upper(string(options.initialDirection));
if ~any(initialDirection == directions)
    error('initialDirection must be X, Y, or Z.');
end

dampingByDirection = struct();
for direction = directions
    dampingByDirection.(char(direction)) = iCollectDirectionData(allStats, flagFields, direction, options.frequencyFocus, targetFreqs, freqTolerance);
end

globalMinPositiveDamping = iGetGlobalMinPositiveDamping(dampingByDirection, directions, numel(flagFields));
xLowerLog = max(globalMinPositiveDamping, 1e-4);

fig = createFigure(101, 'DampingHistogram');
currentDirection = initialDirection;
currentXAxisScale = lower(options.xAxisScale);
currentNumBins = options.numBins;
activeFlagIdx = NaN;
selectedBinStart = NaN;
selectedBinEnd = NaN;
isAwaitingSecondClick = false;

set(fig, 'KeyPressFcn', @iOnKeyPress, 'WindowButtonDownFcn', @iOnMouseClick);
iRender();

    function iOnKeyPress(~, event)
        if any(strcmp(event.Key, {'x', 'y', 'z'}))
            currentDirection = upper(string(event.Key));
            isAwaitingSecondClick = false;
            iRender();
        elseif strcmp(event.Key, 'l')
            if currentXAxisScale == "linear"
                currentXAxisScale = "log";
            else
                currentXAxisScale = "linear";
            end
            isAwaitingSecondClick = false;
            iRender();
        elseif iIsIncreaseBins(event)
            currentNumBins = currentNumBins + 10;
            if iHasSelection()
                selectedBinStart = max(1, min(selectedBinStart, currentNumBins));
                selectedBinEnd = max(selectedBinStart, min(selectedBinEnd + 10, currentNumBins));
            end
            iRender();
        elseif iIsDecreaseBins(event)
            currentNumBins = max(5, currentNumBins - 10);
            if iHasSelection()
                selectedBinStart = max(1, min(selectedBinStart, currentNumBins));
                selectedBinEnd = max(selectedBinStart, min(selectedBinEnd, currentNumBins));
            end
            iRender();
        elseif strcmp(event.Key, 'd')
            iOpenDashboard();
        elseif strcmp(event.Key, 's')
            iSaveCurrentFigure();
        end
    end

    function iOnMouseClick(~, ~)
        if ~strcmp(get(fig, 'SelectionType'), 'alt')
            return;
        end
        if ~isappdata(fig, 'HistogramContext')
            return;
        end
        histogramContext = getappdata(fig, 'HistogramContext');
        objectHandle = hittest(fig);
        if isempty(objectHandle) || ~isgraphics(objectHandle)
            return;
        end
        clickedAxis = ancestor(objectHandle, 'axes');
        if isempty(clickedAxis)
            return;
        end

        axisIdx = find(histogramContext.axesHandles == clickedAxis, 1, 'first');
        if isempty(axisIdx)
            return;
        end

        activeFlagIdx = axisIdx;
        currentPoint = clickedAxis.CurrentPoint(1, 1);
        clickedBin = iGetBinIndex(currentPoint, histogramContext.sharedBinEdges);

        if ~isAwaitingSecondClick
            selectedBinStart = clickedBin;
            selectedBinEnd = clickedBin;
            isAwaitingSecondClick = true;
        else
            selectedBinEnd = clickedBin;
            if selectedBinEnd < selectedBinStart
                tempIdx = selectedBinStart;
                selectedBinStart = selectedBinEnd;
                selectedBinEnd = tempIdx;
            end
            isAwaitingSecondClick = false;
        end

        iRender();
    end

    function iRender()
        clf(fig);
        tlo = tiledlayout(fig, 'flow', 'TileSpacing', 'compact', 'Padding', 'tight');
        firstAxis = gobjects(1,1);

        currentData = dampingByDirection.(char(currentDirection));
        currentMaxDamping = iGetCellArrayMax(currentData);
        if ~isfinite(currentMaxDamping) || currentMaxDamping <= 0
            currentMaxDamping = 0.2;
        end

        if currentXAxisScale == "linear"
            sharedBinEdges = linspace(0, currentMaxDamping, currentNumBins + 1);
            xUpperLinear = sharedBinEdges(end);
            xUpperLog = NaN;
        else
            xUpperLog = max(currentMaxDamping, xLowerLog * 10);
            sharedBinEdges = logspace(log10(xLowerLog), log10(xUpperLog), currentNumBins + 1);
            xUpperLinear = NaN;
        end

        axesHandles = gobjects(1, numel(flagFields));
        for flagIdx = 1:numel(flagFields)
            ax = nexttile(tlo);
            axesHandles(flagIdx) = ax;
            if flagIdx == 1
                firstAxis = ax;
            end
            hold(ax, 'on');
            grid(ax, 'on');
            box(ax, 'on');

            dampingValues = currentData{flagIdx};
            if isempty(dampingValues)
                if currentXAxisScale == "log"
                    set(ax, 'XScale', 'log');
                    xlim(ax, [xLowerLog xUpperLog]);
                else
                    set(ax, 'XScale', 'linear');
                    xlim(ax, [0 xUpperLinear]);
                end
                text(ax, 0.5, 0.5, 'No valid damping values', 'Units', 'normalized', 'HorizontalAlignment', 'center', 'Interpreter', 'latex');
                ylim(ax, [0 1]);
            else
                if currentXAxisScale == "log"
                    set(ax, 'XScale', 'log');
                else
                    set(ax, 'XScale', 'linear');
                end

                yyaxis(ax, 'left');
                histogram(ax, dampingValues, sharedBinEdges, 'Normalization', char(options.normalization), ...
                    'FaceColor', [0.8 0.2 0.2], 'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.6, 'FaceAlpha', 0.75);

                if currentXAxisScale == "log"
                    xlim(ax, [xLowerLog xUpperLog]);
                else
                    xlim(ax, [0 xUpperLinear]);
                end

                yLimits = ylim(ax);
                if options.showBoxStats
                    distributionStats = iComputeDistributionStats(dampingValues);
                    patch(ax, [distributionStats.q1 distributionStats.q3 distributionStats.q3 distributionStats.q1], ...
                        [0 0 yLimits(2) yLimits(2)], [0.2 0.2 0.2], 'FaceAlpha', 0.10, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                    xline(ax, distributionStats.q1, ':', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.0, 'HandleVisibility', 'off');
                    xline(ax, distributionStats.q3, ':', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.0, 'HandleVisibility', 'off');
                    xline(ax, distributionStats.lowerWhisker, '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0, 'HandleVisibility', 'off');
                    xline(ax, distributionStats.upperWhisker, '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0, 'HandleVisibility', 'off');
                    statsText = sprintf('n: %d\nmedian: %.4f\nIQR: %.4f\nmean: %.4f\nstd: %.4f', ...
                        distributionStats.count, distributionStats.medianValue, distributionStats.iqrValue, distributionStats.meanValue, distributionStats.stdValue);
                    text(ax, 0.98, 0.98, statsText, 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                        'VerticalAlignment', 'top', 'Interpreter', 'none', 'BackgroundColor', [1 1 1], ...
                        'Color', [0.1 0.1 0.1]);
                end

                if options.showMedianLine
                    xline(ax, median(dampingValues, 'omitnan'), '--k', 'LineWidth', 1.2);
                end

                if options.showCdf
                    sortedValues = sort(dampingValues, 'ascend');
                    cumulativeProbability = (1:numel(sortedValues))' ./ numel(sortedValues);
                    yyaxis(ax, 'right');
                    plot(ax, sortedValues, cumulativeProbability, '-', 'Color', [0 0 0.55], 'LineWidth', 1.1, 'HandleVisibility', 'off');
                    ylim(ax, [0 1]);
                    ax.YAxis(2).TickLabelInterpreter = 'latex';
                    if flagIdx == numel(flagFields)
                        ylabel(ax, 'CDF', 'Interpreter', 'latex');
                    end
                    yyaxis(ax, 'left');
                end
            end

            iEnsureAtLeastTwoYTicks(ax, "left");
            if options.showCdf
                iEnsureAtLeastTwoYTicks(ax, "right");
                yyaxis(ax, 'left');
            end

            title(ax, sprintf('Criteria: \\texttt{%s}', strrep(char(flagNames(flagIdx)), '_', '\\_')), 'Interpreter', 'latex');
            set(ax, 'TickLabelInterpreter', 'latex');
            iEnsureAtLeastTwoXTicks(ax);
        end

        if numel(axesHandles) > 1
            linkaxes(axesHandles, 'x');
        end

        if iHasSelection()
            activeFlagIdx = max(1, min(activeFlagIdx, numel(flagFields)));
            selectedBinStart = max(1, min(selectedBinStart, currentNumBins));
            selectedBinEnd = max(selectedBinStart, min(selectedBinEnd, currentNumBins));
        elseif isfinite(activeFlagIdx) && activeFlagIdx > numel(flagFields)
            activeFlagIdx = NaN;
        end

        histogramContext = struct('axesHandles', axesHandles, 'sharedBinEdges', sharedBinEdges, ...
            'currentData', {currentData}, 'xAxisScale', currentXAxisScale, ...
            'direction', currentDirection, 'xLowerLog', xLowerLog, ...
            'flagNames', {flagNames}, 'flagFields', {flagFields});
        setappdata(fig, 'HistogramContext', histogramContext);
        iUpdateSelectionVisuals(histogramContext);

        if isgraphics(firstAxis)
            legendHandles = gobjects(0);
            legendLabels = {};
            yyaxis(firstAxis, 'left');
            if options.showMedianLine
                legendHandles(end+1) = plot(firstAxis, NaN, NaN, '--k', 'LineWidth', 1.2);
                legendLabels{end+1} = 'Median';
            end
            if options.showBoxStats
                legendHandles(end+1) = plot(firstAxis, NaN, NaN, ':', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.0);
                legendLabels{end+1} = 'Q1 / Q3';
                legendHandles(end+1) = plot(firstAxis, NaN, NaN, '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0);
                legendLabels{end+1} = 'Whiskers (1.5 IQR)';
                legendHandles(end+1) = patch(firstAxis, NaN, NaN, [0.2 0.2 0.2], 'FaceAlpha', 0.10, 'EdgeColor', 'none');
                legendLabels{end+1} = 'IQR band';
            end
            if options.showCdf
                yyaxis(firstAxis, 'right');
                legendHandles(end+1) = plot(firstAxis, NaN, NaN, '-', 'Color', [0 0 0.55], 'LineWidth', 1.1);
                legendLabels{end+1} = 'CDF';
            end
            if ~isempty(legendHandles)
                yyaxis(firstAxis, 'left');
                legend(firstAxis, legendHandles, legendLabels, 'Location', 'east', 'Interpreter', 'latex');
            end
        end

        xlabel(tlo, 'Damping $\zeta$', 'Interpreter', 'latex');
        if options.normalization == "probability"
            ylabel(tlo, 'Probability', 'Interpreter', 'latex');
        else
            ylabel(tlo, 'Count', 'Interpreter', 'latex');
        end

        if iHasSelection()
            selectedLeft = sharedBinEdges(selectedBinStart);
            selectedRight = sharedBinEdges(selectedBinEnd + 1);
            selectionText = sprintf('[%.4f, %.4f]', selectedLeft, selectedRight);
            if isAwaitingSecondClick
                selectionText = selectionText + " (pick 2nd bin)";
            end
            activeFlagLabel = strrep(char(flagNames(activeFlagIdx)), '_', '\_');
        else
            selectionText = 'none';
            activeFlagLabel = 'none';
        end
        title(tlo, sprintf(['Damping Histograms (%s Direction, X-axis: %s, bins: %d)  ', ...
            '[Right-click bin x2 select range | D dashboard | X/Y/Z, L, +/-, S]  Active: %s  Range: %s'], ...
            char(currentDirection), char(currentXAxisScale), currentNumBins, activeFlagLabel, char(selectionText)), ...
            'Interpreter', 'latex');
        drawnow;
    end

    function iUpdateSelectionVisuals(histogramContext)
        if isempty(histogramContext.axesHandles)
            return;
        end

        for axisIdx = 1:numel(histogramContext.axesHandles)
            currentAxis = histogramContext.axesHandles(axisIdx);
            delete(findobj(currentAxis, 'Tag', 'SelectedBinPatch'));
            if iHasSelection() && axisIdx == activeFlagIdx
                currentAxis.LineWidth = 1.4;
                currentAxis.XColor = [0 0.2 0.45];
                currentAxis.YAxis(1).Color = [0 0.2 0.45];
                if numel(currentAxis.YAxis) > 1
                    currentAxis.YAxis(2).Color = [0 0.2 0.45];
                end
            else
                currentAxis.LineWidth = 0.5;
                currentAxis.XColor = [0 0 0];
                currentAxis.YAxis(1).Color = [0 0 0];
                if numel(currentAxis.YAxis) > 1
                    currentAxis.YAxis(2).Color = [0 0 0];
                end
            end
        end

        if ~iHasSelection()
            return;
        end

        selectedAxis = histogramContext.axesHandles(activeFlagIdx);
        yyaxis(selectedAxis, 'left');
        selectedLeft = histogramContext.sharedBinEdges(selectedBinStart);
        selectedRight = histogramContext.sharedBinEdges(selectedBinEnd + 1);
        yLimits = ylim(selectedAxis);
        patch(selectedAxis, [selectedLeft selectedRight selectedRight selectedLeft], ...
            [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], [0.2 0.6 0.85], ...
            'FaceAlpha', 0.12, 'EdgeColor', [0.1 0.35 0.7], 'LineWidth', 1.1, ...
            'Tag', 'SelectedBinPatch', 'HandleVisibility', 'off', 'HitTest', 'off');
    end

    function iOpenDashboard()
        histogramContext = getappdata(fig, 'HistogramContext');
        if isempty(histogramContext)
            return;
        end
        if ~iHasSelection()
            warning('No damping range selected. Right-click two bins first.');
            return;
        end
        activeFlagField = flagFields(activeFlagIdx);
        activeFlagName = flagNames(activeFlagIdx);
        selectedLeft = histogramContext.sharedBinEdges(selectedBinStart);
        selectedRight = histogramContext.sharedBinEdges(selectedBinEnd + 1);

        peakTable = extractDampingPeakTable(allStats, activeFlagField, currentDirection, ...
            frequencyFocus=options.frequencyFocus, ...
            targetFreqs=targetFreqs, ...
            freqTolerance=freqTolerance);
        if isempty(peakTable)
            warning('No peak table available for dashboard.');
            return;
        end

        selectedTable = peakTable(peakTable.damping >= selectedLeft & peakTable.damping <= selectedRight, :);
        if isempty(selectedTable)
            warning('No peaks found in selected damping range [%.5f, %.5f].', selectedLeft, selectedRight);
            return;
        end

        selectionInfo = struct('flagField', activeFlagField, 'flagName', activeFlagName, ...
            'direction', currentDirection, 'dampingMin', selectedLeft, 'dampingMax', selectedRight);
        plotDampingSelectionDashboard(selectedTable, selectionInfo, windContext="global");
    end

    function iSaveCurrentFigure()
        if strlength(options.figureFolder) == 0
            return;
        end
        saveName = sprintf('DampingHistogram_%s_%s', char(currentDirection), char(strjoin(strrep(flagFields, ' ', '_'), '_')));
        saveName = strrep(saveName, '$', '');
        saveName = strrep(saveName, '\\', '');
        saveFig(fig, options.figureFolder, saveName, 2, 1,scaleFigure=false);
    end

    function hasSelection = iHasSelection()
        hasSelection = isfinite(activeFlagIdx) && isfinite(selectedBinStart) && isfinite(selectedBinEnd);
    end

    function iEnsureAtLeastTwoYTicks(ax, axisSide)
        axisSide = lower(string(axisSide));
        if axisSide == "right" && numel(ax.YAxis) < 2
            return;
        end

        if axisSide == "right"
            axisIdx = 2;
        else
            axisIdx = 1;
        end

        yyaxis(ax, char(axisSide));
        yLimits = ylim(ax);
        yMin = yLimits(1);
        yMax = yLimits(2);
        if ~isfinite(yMin) || ~isfinite(yMax)
            return;
        end

        isLogScale = strcmp(ax.YAxis(axisIdx).Scale, 'log');
        if yMax <= yMin
            if isLogScale
                yMin = max(yMin, eps);
                yMax = yMin * 10;
            else
                yMax = yMin + 1;
            end
            ylim(ax, [yMin yMax]);
        end

        yTicks = yticks(ax);
        yTicks = yTicks(isfinite(yTicks) & yTicks >= yMin & yTicks <= yMax);
        if numel(yTicks) < 2
            yticks(ax, [yMin, yMax]);
        end
    end

    function iEnsureAtLeastTwoXTicks(ax)
        xLimits = xlim(ax);
        xMin = xLimits(1);
        xMax = xLimits(2);
        if ~isfinite(xMin) || ~isfinite(xMax)
            return;
        end

        if xMax <= xMin
            if strcmp(ax.XScale, 'log')
                xMin = max(xMin, eps);
                xMax = xMin * 10;
            else
                xMax = xMin + 1;
            end
            xlim(ax, [xMin xMax]);
        end

        xTicks = xticks(ax);
        xTicks = xTicks(isfinite(xTicks) & xTicks >= xMin & xTicks <= xMax);
        if numel(xTicks) < 2
            if strcmp(ax.XScale, 'log')
                ax.XMinorTick = 'on';
                xDecadeMin = floor(log10(xMin));
                xDecadeMax = ceil(log10(xMax));
                minorTickValues = [];
                for decade = xDecadeMin:xDecadeMax
                    minorTickValues = [minorTickValues, (2:9) * 10^decade];
                end
                minorTickValues = minorTickValues(minorTickValues > xMin & minorTickValues < xMax);
                if ~isempty(minorTickValues)
                    ax.XAxis.MinorTickValues = minorTickValues;
                end

                xTicks = xticks(ax);
                xTicks = xTicks(isfinite(xTicks) & xTicks >= xMin & xTicks <= xMax);
                if numel(xTicks) < 2
                    halfTicks = [];
                    for decade = xDecadeMin:xDecadeMax
                        halfTicks = [halfTicks, 5 * 10^decade];
                    end
                    halfTicks = halfTicks(halfTicks > xMin & halfTicks < xMax);
                    if ~isempty(halfTicks)
                        xticks(ax, unique(sort([xTicks(:); halfTicks(:)])));
                    end
                end

                xTicks = xticks(ax);
                xTicks = xTicks(isfinite(xTicks) & xTicks >= xMin & xTicks <= xMax);
                if numel(xTicks) < 2
                    xticks(ax, [xMin, xMax]);
                end
            else
                xticks(ax, [xMin, xMax]);
            end
        end
    end
end

function shouldIncrease = iIsIncreaseBins(event)
shouldIncrease = strcmp(event.Key, 'add') || strcmp(event.Key, 'plus') || strcmp(event.Key, 'equal') || strcmp(event.Character, '+');
end

function shouldDecrease = iIsDecreaseBins(event)
shouldDecrease = strcmp(event.Key, 'subtract') || strcmp(event.Key, 'minus') || strcmp(event.Key, 'hyphen') || strcmp(event.Character, '-');
end

function maxValue = iGetCellArrayMax(cellArray)
maxValue = -inf;
for idx = 1:numel(cellArray)
    currentValues = cellArray{idx};
    if ~isempty(currentValues)
        maxValue = max(maxValue, max(currentValues, [], 'omitnan'));
    end
end
if ~isfinite(maxValue)
    maxValue = NaN;
end
end

function directionData = iCollectDirectionData(allStats, flagFields, direction, frequencyFocus, targetFreqs, freqTolerance)
numFlags = numel(flagFields);
directionData = cell(1, numFlags);
sensorNames = ["Conc_" + direction, "Steel_" + direction];

for flagIdx = 1:numFlags
    flagName = flagFields(flagIdx);
    if ~ismember(flagName, string(allStats.Properties.VariableNames))
        warning('Field %s was not found in allStats.', char(flagName));
        directionData{flagIdx} = [];
        continue;
    end

    flagMask = iToLogicalColumn(allStats.(char(flagName)));
    selectedRows = find(flagMask);
    dampingValues = [];

    for rowIdx = selectedRows(:)'
        for sensorName = sensorNames
            sensorNameChar = char(sensorName);
            if ~isfield(allStats.psdPeaks, sensorNameChar)
                continue;
            end

            peakStruct = allStats.psdPeaks(rowIdx).(sensorNameChar);
            if ~isfield(peakStruct, 'locations') || ~isfield(peakStruct, 'dampingRatios')
                continue;
            end

            locations = peakStruct.locations(:);
            damping = peakStruct.dampingRatios(:);
            validMask = isfinite(locations) & isfinite(damping) & damping > 0 & damping < 1;

            if frequencyFocus == "target"
                nearTargetMask = false(size(locations));
                for targetFrequency = targetFreqs(:)'
                    nearTargetMask = nearTargetMask | abs(locations - targetFrequency) <= freqTolerance;
                end
                validMask = validMask & nearTargetMask;
            end

            dampingValues = [dampingValues; damping(validMask)];
        end
    end

    directionData{flagIdx} = dampingValues;
end
end

function binIndex = iGetBinIndex(xValue, binEdges)
if xValue <= binEdges(1)
    binIndex = 1;
    return;
end
if xValue >= binEdges(end)
    binIndex = numel(binEdges) - 1;
    return;
end
binIndex = find(binEdges <= xValue, 1, 'last');
binIndex = min(max(binIndex, 1), numel(binEdges) - 1);
end

function logicalColumn = iToLogicalColumn(flagColumn)
if iscell(flagColumn)
    logicalColumn = cellfun(@(value) logical(value(1)), flagColumn);
else
    logicalColumn = logical(flagColumn);
end
logicalColumn = logicalColumn(:);
end

function globalMinPositive = iGetGlobalMinPositiveDamping(dampingByDirection, directions, numFlags)
globalMinPositive = inf;
for direction = directions
    directionData = dampingByDirection.(char(direction));
    for flagIdx = 1:numFlags
        currentValues = directionData{flagIdx};
        currentValues = currentValues(currentValues > 0 & isfinite(currentValues));
        if ~isempty(currentValues)
            globalMinPositive = min(globalMinPositive, min(currentValues));
        end
    end
end
if ~isfinite(globalMinPositive)
    globalMinPositive = 1e-4;
end
end

function targetFreqs = iResolveTargetFreqs(options)
if options.frequencyFocus == "target"
    if ~isempty(options.targetFreqs_override)
        targetFreqs = options.targetFreqs_override;
    elseif isfield(options.limits, 'targetFreqs')
        targetFreqs = options.limits.targetFreqs;
    else
        error('limits.targetFreqs is required when frequencyFocus is "target".');
    end
else
    targetFreqs = [];
end
end

function freqTolerance = iResolveTolerance(options)
if options.frequencyFocus == "target"
    if ~isempty(options.freqTolerance_override)
        freqTolerance = options.freqTolerance_override;
    elseif isfield(options.limits, 'freqTolerance')
        freqTolerance = options.limits.freqTolerance;
    else
        error('limits.freqTolerance is required when frequencyFocus is "target".');
    end
else
    freqTolerance = NaN;
end
end

function distributionStats = iComputeDistributionStats(dampingValues)
distributionStats.count = numel(dampingValues);
distributionStats.meanValue = mean(dampingValues, 'omitnan');
distributionStats.stdValue = std(dampingValues, 'omitnan');
distributionStats.medianValue = median(dampingValues, 'omitnan');
distributionStats.q1 = prctile(dampingValues, 25);
distributionStats.q3 = prctile(dampingValues, 75);
distributionStats.iqrValue = distributionStats.q3 - distributionStats.q1;

lowerFence = distributionStats.q1 - 1.5 * distributionStats.iqrValue;
upperFence = distributionStats.q3 + 1.5 * distributionStats.iqrValue;
inWhiskerMask = dampingValues >= lowerFence & dampingValues <= upperFence;
whiskerCandidates = dampingValues(inWhiskerMask);

if isempty(whiskerCandidates)
    distributionStats.lowerWhisker = min(dampingValues, [], 'omitnan');
    distributionStats.upperWhisker = max(dampingValues, [], 'omitnan');
else
    distributionStats.lowerWhisker = min(whiskerCandidates, [], 'omitnan');
    distributionStats.upperWhisker = max(whiskerCandidates, [], 'omitnan');
end

end

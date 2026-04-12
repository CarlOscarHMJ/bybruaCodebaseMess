function plotDampingByEventType(allStats, options)
% plotDampingByEventType Plots overlapping damping histograms categorized by event type.
%
% Description:
%   Creates a single plot with three overlapping histograms showing:
%   - Gray (back): background data not matching any event flag
%   - Blue (middle): data matching blueFlagField
%   - Red (front): data matching redFlagField
%   Default direction is Z. Keyboard shortcuts: X/Y/Z for direction, L for log/linear, +/- for bins, S to save.
%
% Arguments:
%   allStats       - Table with psdPeaks and flag fields
%   options.redFlagField   - Field name for red histogram (default: 'flag_StructuralResponseMatch')
%   options.blueFlagField  - Field name for blue histogram (default: 'flag_EnvironmentalMatch')

arguments
    allStats table
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
    options.redFlagField string = 'flag_StructuralResponseMatch'
    options.blueFlagField string = 'flag_EnvironmentalMatch'
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
    dampingByDirection.(char(direction)) = iCollectDirectionData(allStats, direction, options.frequencyFocus, targetFreqs, freqTolerance, options.redFlagField, options.blueFlagField);
end

globalMinPositiveDamping = iGetGlobalMinPositiveDamping(dampingByDirection, directions);
xLowerLog = max(globalMinPositiveDamping, 1e-4);

fig = createFigure(101, 'DampingHistogram');
currentDirection = initialDirection;
currentXAxisScale = lower(options.xAxisScale);
currentNumBins = options.numBins;

set(fig, 'KeyPressFcn', @iOnKeyPress, 'WindowButtonDownFcn', @iOnMouseClick);
iRender();

    function iOnKeyPress(~, event)
        if any(strcmp(event.Key, {'x', 'y', 'z'}))
            currentDirection = upper(string(event.Key));
            iRender();
        elseif strcmp(event.Key, 'l')
            if currentXAxisScale == "linear"
                currentXAxisScale = "log";
            else
                currentXAxisScale = "linear";
            end
            iRender();
        elseif iIsIncreaseBins(event)
            currentNumBins = currentNumBins + 10;
            iRender();
        elseif iIsDecreaseBins(event)
            currentNumBins = max(5, currentNumBins - 10);
            iRender();
        elseif strcmp(event.Key, 'd')
            iOpenDashboard();
        elseif strcmp(event.Key, 's')
            iSaveCurrentFigure();
        end
    end

    function iOnMouseClick(~, ~)
    end

    function iRender()
        clf(fig);
        ax = axes(fig);
        hold(ax, 'on');
        grid(ax, 'on');
        box(ax, 'on');

        currentData = dampingByDirection.(char(currentDirection));
        grayValues = currentData.gray;
        blueValues = currentData.blue;
        redValues = currentData.red;
        
        currentMaxDamping = max(iGetStructMax(grayValues), iGetStructMax(blueValues), iGetStructMax(redValues));
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

        if currentXAxisScale == "log"
            set(ax, 'XScale', 'log');
        else
            set(ax, 'XScale', 'linear');
        end

        hGray = [];
        hBlue = [];
        hRed = [];
        
        if ~isempty(grayValues)
            yyaxis(ax, 'left');
            hGray = histogram(ax, grayValues, sharedBinEdges, 'Normalization', char(options.normalization), ...
                'FaceColor', [0.6 0.6 0.6], 'EdgeColor', [0.4 0.4 0.4], 'LineWidth', 0.6, 'FaceAlpha', 0.5);
        end
        
        if ~isempty(blueValues)
            yyaxis(ax, 'left');
            hBlue = histogram(ax, blueValues, sharedBinEdges, 'Normalization', char(options.normalization), ...
                'FaceColor', [0.2 0.4 0.8], 'EdgeColor', [0.1 0.2 0.5], 'LineWidth', 0.6, 'FaceAlpha', 0.7);
        end
        
        if ~isempty(redValues)
            yyaxis(ax, 'left');
            hRed = histogram(ax, redValues, sharedBinEdges, 'Normalization', char(options.normalization), ...
                'FaceColor', [0.8 0.2 0.2], 'EdgeColor', [0.4 0.1 0.1], 'LineWidth', 0.6, 'FaceAlpha', 0.8);
        end

        if ~isempty(hGray) && ~isempty(hBlue)
            uistack(hGray, 'bottom');
            uistack(hBlue, 'up');
            if ~isempty(hRed)
                uistack(hRed, 'top');
            end
        elseif ~isempty(hGray) && ~isempty(hRed)
            uistack(hGray, 'bottom');
            uistack(hRed, 'top');
        elseif ~isempty(hBlue) && ~isempty(hRed)
            uistack(hBlue, 'bottom');
            uistack(hRed, 'top');
        end

        if currentXAxisScale == "log"
            xlim(ax, [xLowerLog xUpperLog]);
        else
            xlim(ax, [0 xUpperLinear]);
        end

        yLimits = ylim(ax);
        if options.showBoxStats
            blueLabel = strrep(options.blueFlagField, 'flag_', '');
            redLabel = strrep(options.redFlagField, 'flag_', '');
            catLabels = {'Background', blueLabel, redLabel};
            catValues = {grayValues, blueValues, redValues};
            textOffset = 0;
            for catIdx = 1:3
                statsValues = catValues{catIdx};
                if ~isempty(statsValues)
                    distributionStats = iComputeDistributionStats(statsValues);
                    statsText = sprintf('%s: n=%d, med=%.4f, IQR=%.4f', catLabels{catIdx}, distributionStats.count, distributionStats.medianValue, distributionStats.iqrValue);
                    text(ax, 0.02, 0.98 - textOffset, statsText, 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
                        'VerticalAlignment', 'top', 'Interpreter', 'none', 'BackgroundColor', [1 1 1], ...
                        'Color', [0.1 0.1 0.1], 'FontSize', 8);
                    textOffset = textOffset + 0.02;
                end
            end
        end

        if options.showMedianLine
            if ~isempty(grayValues)
                xline(ax, median(grayValues, 'omitnan'), '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0, 'HandleVisibility', 'off');
            end
            if ~isempty(blueValues)
                xline(ax, median(blueValues, 'omitnan'), '--', 'Color', [0.2 0.4 0.8], 'LineWidth', 1.0, 'HandleVisibility', 'off');
            end
            if ~isempty(redValues)
                xline(ax, median(redValues, 'omitnan'), '--k', 'LineWidth', 1.2, 'HandleVisibility', 'off');
            end
        end

        if options.showCdf
            sortedValues = [];
            cumulativeProbability = [];
            for catValues = {grayValues, blueValues, redValues}
                if ~isempty(catValues{1})
                    sortedCat = sort(catValues{1}, 'ascend');
                    cumProb = (1:numel(sortedCat))' ./ numel(sortedCat);
                    sortedValues = [sortedValues; NaN; sortedCat];
                    cumulativeProbability = [cumulativeProbability; NaN; cumProb];
                end
            end
            if ~isempty(sortedValues)
                yyaxis(ax, 'right');
                plot(ax, sortedValues, cumulativeProbability, '-', 'Color', [0 0 0.55], 'LineWidth', 1.1, 'HandleVisibility', 'off');
                ylim(ax, [0 1]);
                ax.YAxis(2).TickLabelInterpreter = 'latex';
                ylabel(ax, 'CDF', 'Interpreter', 'latex');
                yyaxis(ax, 'left');
            end
        end

        iEnsureAtLeastTwoYTicks(ax, "left");
        if options.showCdf
            iEnsureAtLeastTwoYTicks(ax, "right");
            yyaxis(ax, 'left');
        end

        set(ax, 'TickLabelInterpreter', 'latex');
        iEnsureAtLeastTwoXTicks(ax);

        legendHandles = gobjects(0);
        legendLabels = {};
        if ~isempty(hGray)
            legendHandles(end+1) = hGray;
            legendLabels{end+1} = 'Background';
        end
        if ~isempty(hBlue)
            legendHandles(end+1) = hBlue;
            blueLabel = strrep(options.blueFlagField, 'flag_', '');
            legendLabels{end+1} = blueLabel;
        end
        if ~isempty(hRed)
            legendHandles(end+1) = hRed;
            redLabel = strrep(options.redFlagField, 'flag_', '');
            legendLabels{end+1} = redLabel;
        end
        if options.showMedianLine
            legendHandles(end+1) = plot(ax, NaN, NaN, '--k', 'LineWidth', 1.2);
            legendLabels{end+1} = 'Median';
        end
        if ~isempty(legendHandles)
            legend(ax, legendHandles, legendLabels, 'Location', 'north-east', 'Interpreter', 'latex');
        end

        xlabel(ax, 'Damping $\zeta$', 'Interpreter', 'latex');
        if options.normalization == "probability"
            ylabel(ax, 'Probability', 'Interpreter', 'latex');
        else
            ylabel(ax, 'Count', 'Interpreter', 'latex');
        end

        title(ax, sprintf(['Damping Histogram (%s Direction, X-axis: %s, bins: %d)  ', ...
            '[X/Y/Z switch direction | L toggle log/linear | +/- bins | S save]'], ...
            char(currentDirection), char(currentXAxisScale), currentNumBins), ...
            'Interpreter', 'latex');

        histogramContext = struct('ax', ax, 'sharedBinEdges', sharedBinEdges, ...
            'grayValues', grayValues, 'blueValues', blueValues, 'redValues', redValues, ...
            'xAxisScale', currentXAxisScale, 'direction', currentDirection, 'xLowerLog', xLowerLog);
        setappdata(fig, 'HistogramContext', histogramContext);

        drawnow;
    end

    function iUpdateSelectionVisuals(histogramContext)
    end

    function iOpenDashboard()
        histogramContext = getappdata(fig, 'HistogramContext');
        if isempty(histogramContext)
            return;
        end
        
        warning('Dashboard selection via right-click is no longer available. Use the separate plotDampingSelectionDashboard function to explore data.');
    end

    function iSaveCurrentFigure()
        if strlength(options.figureFolder) == 0
            return;
        end
        saveName = sprintf('DampingHistogram_%s', char(currentDirection));
        saveFig(fig, options.figureFolder, saveName, 2, 1, scaleFigure=false);
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

function directionData = iCollectDirectionData(allStats, direction, frequencyFocus, targetFreqs, freqTolerance, redFlagField, blueFlagField)
directionData = struct('gray', [], 'blue', [], 'red', []);
sensorNames = ["Conc_" + direction, "Steel_" + direction];

redFlags = false(height(allStats), 1);
if ismember(redFlagField, allStats.Properties.VariableNames)
    redFlags = iToLogicalColumn(allStats.(redFlagField));
end

blueFlags = false(height(allStats), 1);
if ismember(blueFlagField, allStats.Properties.VariableNames)
    blueFlags = iToLogicalColumn(allStats.(blueFlagField));
end

isRed = redFlags;
isBlue = ~redFlags & blueFlags;
isGray = ~redFlags & ~blueFlags;

for rowIdx = 1:height(allStats)
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

        validDamping = damping(validMask);
        
        if isRed(rowIdx)
            directionData.red = [directionData.red; validDamping];
        elseif isBlue(rowIdx)
            directionData.blue = [directionData.blue; validDamping];
        elseif isGray(rowIdx)
            directionData.gray = [directionData.gray; validDamping];
        end
    end
end
end

function logicalColumn = iToLogicalColumn(flagColumn)
if iscell(flagColumn)
    logicalColumn = cellfun(@(value) logical(value(1)), flagColumn);
else
    logicalColumn = logical(flagColumn);
end
logicalColumn = logicalColumn(:);
end

function globalMinPositive = iGetGlobalMinPositiveDamping(dampingByDirection, directions)
globalMinPositive = inf;
for direction = directions
    directionData = dampingByDirection.(char(direction));
    for catField = {'gray', 'blue', 'red'}
        currentValues = directionData.(catField{1});
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

function maxValue = iGetStructMax(structValues)
maxValue = -inf;
if ~isempty(structValues)
    validValues = structValues(isfinite(structValues));
    if ~isempty(validValues)
        maxValue = max(maxValue, max(validValues));
    end
end
if ~isfinite(maxValue)
    maxValue = NaN;
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

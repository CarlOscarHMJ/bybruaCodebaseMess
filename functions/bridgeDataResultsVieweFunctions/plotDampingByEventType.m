function plotDampingByEventType(allStats, options)
% plotDampingByEventType Plots overlapping damping histograms by event type for all sensor directions.

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
    options.verboseClicks (1,1) logical = true
    options.xAxisScale (1,1) string {mustBeMember(options.xAxisScale, ["linear", "log"])} = "linear"
    options.yAxisScale (1,1) string {mustBeMember(options.yAxisScale, ["linear", "log"])} = "linear"
    options.redFlagField string = 'flag_StructuralResponseMatch'
    options.blueFlagField string = 'flag_EnvironmentalMatch'
end

targetFreqs = iResolveTargetFreqs(options);
freqTolerance = iResolveTolerance(options);
sensorPrefixes = ["Conc", "Steel"];
directions = ["X", "Y", "Z"];

dampingBySensorDirection = struct();
for sensorPrefix = sensorPrefixes
    dampingBySensorDirection.(char(sensorPrefix)) = struct();
    for direction = directions
        sensorName = sensorPrefix + "_" + direction;
        dampingBySensorDirection.(char(sensorPrefix)).(char(direction)) = iCollectSensorDirectionData(allStats, sensorName, options.frequencyFocus, targetFreqs, freqTolerance, options.redFlagField, options.blueFlagField);
    end
end

globalMinPositiveDamping = iGetGlobalMinPositiveDamping(dampingBySensorDirection, sensorPrefixes, directions);
xLowerLog = max(globalMinPositiveDamping, 1e-4);

fig = createFigure(101, 'DampingHistogram');
currentXAxisScale = lower(options.xAxisScale);
currentNumBins = options.numBins;
selectedPanelIdx = NaN;
selectedRedBinIdx = NaN;

set(fig, 'KeyPressFcn', @iOnKeyPress, 'WindowButtonDownFcn', @iOnMouseClick);
iRender();

    function iOnKeyPress(~, event)
        if strcmp(event.Key, 'l')
            if currentXAxisScale == "linear"
                currentXAxisScale = "log";
            else
                currentXAxisScale = "linear";
            end
            iPrintVerbose('[plotDampingByEventType] Key %s: x-axis scale -> %s.', event.Key, char(currentXAxisScale));
            iRender();
        elseif iIsIncreaseBins(event)
            currentNumBins = currentNumBins + 10;
            iPrintVerbose('[plotDampingByEventType] Key %s: bins -> %d.', event.Key, currentNumBins);
            iRender();
        elseif iIsDecreaseBins(event)
            currentNumBins = max(5, currentNumBins - 10);
            iPrintVerbose('[plotDampingByEventType] Key %s: bins -> %d.', event.Key, currentNumBins);
            iRender();
        elseif strcmp(event.Key, 'd')
            iPrintVerbose('[plotDampingByEventType] Key %s: open dashboard.', event.Key);
            iOpenDashboard();
        elseif strcmp(event.Key, 's')
            iPrintVerbose('[plotDampingByEventType] Key %s: save figure.', event.Key);
            iSaveCurrentFigure();
        end
    end

    function iOnMouseClick(~, ~)
        if ~strcmp(get(fig, 'SelectionType'), 'alt')
            return;
        end
        iPrintVerbose('[plotDampingByEventType] Right-click detected.');
        if ~isappdata(fig, 'HistogramContext')
            iPrintVerbose('[plotDampingByEventType] Click ignored: no histogram context available yet.');
            return;
        end

        histogramContext = getappdata(fig, 'HistogramContext');
        clickedObject = hittest(fig);
        if isempty(clickedObject) || ~isgraphics(clickedObject)
            iPrintVerbose('[plotDampingByEventType] Click ignored: no graphics object selected.');
            return;
        end

        clickedAxis = ancestor(clickedObject, 'axes');
        if isempty(clickedAxis)
            iPrintVerbose('[plotDampingByEventType] Click ignored: target is outside damping axes.');
            return;
        end

        panelIdx = find(histogramContext.axesHandles == clickedAxis, 1, 'first');
        if isempty(panelIdx)
            iPrintVerbose('[plotDampingByEventType] Click ignored: target is outside damping axes.');
            return;
        end

        clickedX = clickedAxis.CurrentPoint(1, 1);
        clickedBinIdx = iGetBinIndex(clickedX, histogramContext.sharedBinEdges);
        redBinCounts = histogramContext.panelData(panelIdx).redBinCounts;
        if clickedBinIdx < 1 || clickedBinIdx > numel(redBinCounts)
            iPrintVerbose('[plotDampingByEventType] Click ignored: selected bin is out of range.');
            return;
        end
        if redBinCounts(clickedBinIdx) <= 0
            selectedLeft = histogramContext.sharedBinEdges(clickedBinIdx);
            selectedRight = histogramContext.sharedBinEdges(clickedBinIdx + 1);
            iPrintVerbose('[plotDampingByEventType] Bin [%.5f, %.5f] has no red events.', selectedLeft, selectedRight);
            return;
        end

        selectedLeft = histogramContext.sharedBinEdges(clickedBinIdx);
        selectedRight = histogramContext.sharedBinEdges(clickedBinIdx + 1);
        panelData = histogramContext.panelData(panelIdx);
        iPrintVerbose('[plotDampingByEventType] Red bin selected for %s %s: [%0.5f, %0.5f], count=%d.', ...
            panelData.sensorPrefix, panelData.direction, selectedLeft, selectedRight, redBinCounts(clickedBinIdx));

        selectedPanelIdx = panelIdx;
        selectedRedBinIdx = clickedBinIdx;
        iRender();
        iOpenDashboard(clickedBinIdx, panelIdx);
    end

    function iRender()
        clf(fig);
        tlo = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

        colorGray = [0.6 0.6 0.6];
        edgeGray = [0.4 0.4 0.4];
        colorBlue = [0.2 0.4 0.8];
        edgeBlue = [0.1 0.2 0.5];
        colorRed = [0.8 0.2 0.2];
        edgeRed = [0.4 0.1 0.1];

        globalMaxDamping = iGetGlobalMaxDamping(dampingBySensorDirection, sensorPrefixes, directions);
        if ~isfinite(globalMaxDamping) || globalMaxDamping <= 0
            globalMaxDamping = 0.2;
        end

        if currentXAxisScale == "linear"
            sharedBinEdges = linspace(0, globalMaxDamping, currentNumBins + 1);
            xUpperLinear = sharedBinEdges(end);
            xUpperLog = NaN;
        else
            xUpperLog = max(globalMaxDamping, xLowerLog * 10);
            sharedBinEdges = logspace(log10(xLowerLog), log10(xUpperLog), currentNumBins + 1);
            xUpperLinear = NaN;
        end

        panelCount = numel(sensorPrefixes) * numel(directions);
        axesHandles = gobjects(1, panelCount);
        panelData = repmat(struct('sensorPrefix', '', 'sensorName', '', 'direction', '', 'redBinCounts', []), 1, panelCount);

        panelIdx = 0;
        for sensorIdx = 1:numel(sensorPrefixes)
            for directionIdx = 1:numel(directions)
                panelIdx = panelIdx + 1;
                sensorPrefix = sensorPrefixes(sensorIdx);
                direction = directions(directionIdx);
                sensorName = sensorPrefix + "_" + direction;
                currentData = dampingBySensorDirection.(char(sensorPrefix)).(char(direction));

                ax = nexttile(tlo, panelIdx);
                axesHandles(panelIdx) = ax;
                hold(ax, 'on');
                grid(ax, 'on');
                box(ax, 'on');

                if currentXAxisScale == "log"
                    set(ax, 'XScale', 'log');
                else
                    set(ax, 'XScale', 'linear');
                end
                set(ax, 'YScale', options.yAxisScale);

                hGray = [];
                hBlue = [];
                hRed = [];

                if ~isempty(currentData.gray)
                    yyaxis(ax, 'left');
                    hGray = histogram(ax, currentData.gray, sharedBinEdges, 'Normalization', char(options.normalization), ...
                        'FaceColor', colorGray, 'EdgeColor', edgeGray, 'LineWidth', 0.6, 'FaceAlpha', 0.5);
                end
                if ~isempty(currentData.blue)
                    yyaxis(ax, 'left');
                    hBlue = histogram(ax, currentData.blue, sharedBinEdges, 'Normalization', char(options.normalization), ...
                        'FaceColor', colorBlue, 'EdgeColor', edgeBlue, 'LineWidth', 0.6, 'FaceAlpha', 0.7);
                end
                if ~isempty(currentData.red)
                    yyaxis(ax, 'left');
                    hRed = histogram(ax, currentData.red, sharedBinEdges, 'Normalization', char(options.normalization), ...
                        'FaceColor', colorRed, 'EdgeColor', edgeRed, 'LineWidth', 0.6, 'FaceAlpha', 0.8);
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

                if options.showMedianLine
                    if ~isempty(currentData.gray)
                        xline(ax, median(currentData.gray, 'omitnan'), '--', 'Color', colorGray, 'LineWidth', 1.0, 'HandleVisibility', 'off');
                    end
                    if ~isempty(currentData.blue)
                        xline(ax, median(currentData.blue, 'omitnan'), '--', 'Color', colorBlue, 'LineWidth', 1.0, 'HandleVisibility', 'off');
                    end
                    if ~isempty(currentData.red)
                        xline(ax, median(currentData.red, 'omitnan'), '--', 'Color', colorRed, 'LineWidth', 1.2, 'HandleVisibility', 'off');
                    end
                end

                if options.showCdf
                    yyaxis(ax, 'right');
                    if ~isempty(currentData.gray)
                        sortedGray = sort(currentData.gray, 'ascend');
                        cumGray = (1:numel(sortedGray))' ./ numel(sortedGray);
                        plot(ax, sortedGray, cumGray, '-', 'Color', colorGray, 'LineWidth', 1.1, 'HandleVisibility', 'off');
                    end
                    if ~isempty(currentData.blue)
                        sortedBlue = sort(currentData.blue, 'ascend');
                        cumBlue = (1:numel(sortedBlue))' ./ numel(sortedBlue);
                        plot(ax, sortedBlue, cumBlue, '-', 'Color', colorBlue, 'LineWidth', 1.1, 'HandleVisibility', 'off');
                    end
                    if ~isempty(currentData.red)
                        sortedRed = sort(currentData.red, 'ascend');
                        cumRed = (1:numel(sortedRed))' ./ numel(sortedRed);
                        plot(ax, sortedRed, cumRed, '-', 'Color', colorRed, 'LineWidth', 1.1, 'HandleVisibility', 'off');
                    end
                    ylim(ax, [0 1]);
                    ax.YAxis(2).TickLabelInterpreter = 'latex';
                    yyaxis(ax, 'left');
                end

                iEnsureAtLeastTwoYTicks(ax, "left");
                if options.showCdf
                    iEnsureAtLeastTwoYTicks(ax, "right");
                    yyaxis(ax, 'left');
                end

                set(ax, 'TickLabelInterpreter', 'latex');
                iEnsureAtLeastTwoXTicks(ax);
                title(ax, sprintf('%s %s', char(sensorPrefix), char(direction)), 'Interpreter', 'latex');

                if panelIdx == 1
                    legendHandles = gobjects(0);
                    legendLabels = {};
                    if ~isempty(hGray)
                        legendHandles(end+1) = hGray;
                        legendLabels{end+1} = 'Background';
                    end
                    if ~isempty(hBlue)
                        legendHandles(end+1) = hBlue;
                        legendLabels{end+1} = strrep(options.blueFlagField, 'flag_', '');
                    end
                    if ~isempty(hRed)
                        legendHandles(end+1) = hRed;
                        legendLabels{end+1} = strrep(options.redFlagField, 'flag_', '');
                    end
                    if ~isempty(legendHandles)
                        legend(ax, legendHandles, legendLabels, 'Location', 'northeast', 'Interpreter', 'latex');
                    end
                end

                panelData(panelIdx).sensorPrefix = char(sensorPrefix);
                panelData(panelIdx).sensorName = char(sensorName);
                panelData(panelIdx).direction = char(direction);
                panelData(panelIdx).redBinCounts = histcounts(currentData.red, sharedBinEdges);
            end
        end

        iSetGlobalAxisLabels(tlo);

        if isfinite(selectedPanelIdx)
            if selectedPanelIdx < 1 || selectedPanelIdx > numel(panelData)
                selectedPanelIdx = NaN;
                selectedRedBinIdx = NaN;
            else
                currentRedCounts = panelData(selectedPanelIdx).redBinCounts;
                if isempty(currentRedCounts)
                    selectedPanelIdx = NaN;
                    selectedRedBinIdx = NaN;
                else
                    selectedRedBinIdx = max(1, min(selectedRedBinIdx, numel(currentRedCounts)));
                    if currentRedCounts(selectedRedBinIdx) <= 0
                        selectedPanelIdx = NaN;
                        selectedRedBinIdx = NaN;
                    end
                end
            end
        end

        histogramContext = struct('tlo', tlo, 'axesHandles', axesHandles, 'panelData', {panelData}, 'sharedBinEdges', sharedBinEdges);
        setappdata(fig, 'HistogramContext', histogramContext);
        iSetFigureTitle(tlo, true);
        iUpdateSelectionVisuals(histogramContext);
        drawnow;
    end

    function iUpdateSelectionVisuals(histogramContext)
        for axisIdx = 1:numel(histogramContext.axesHandles)
            delete(findobj(histogramContext.axesHandles(axisIdx), 'Tag', 'SelectedRedBinPatch'));
        end

        if ~isfinite(selectedPanelIdx) || ~isfinite(selectedRedBinIdx)
            return;
        end
        if selectedPanelIdx < 1 || selectedPanelIdx > numel(histogramContext.panelData)
            return;
        end
        if selectedRedBinIdx < 1 || selectedRedBinIdx > numel(histogramContext.sharedBinEdges) - 1
            return;
        end

        selectedAxis = histogramContext.axesHandles(selectedPanelIdx);
        yyaxis(selectedAxis, 'left');
        yLimits = ylim(selectedAxis);
        selectedLeft = histogramContext.sharedBinEdges(selectedRedBinIdx);
        selectedRight = histogramContext.sharedBinEdges(selectedRedBinIdx + 1);
        patch(selectedAxis, [selectedLeft selectedRight selectedRight selectedLeft], ...
            [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], [0.9 0.2 0.2], ...
            'FaceAlpha', 0.10, 'EdgeColor', [0.65 0.1 0.1], 'LineWidth', 1.0, ...
            'Tag', 'SelectedRedBinPatch', 'HandleVisibility', 'off', 'HitTest', 'off');
    end

    function iOpenDashboard(selectedBinOverride, selectedPanelOverride)
        histogramContext = getappdata(fig, 'HistogramContext');
        if isempty(histogramContext)
            return;
        end

        if nargin >= 2 && isfinite(selectedPanelOverride)
            selectedPanel = selectedPanelOverride;
        else
            selectedPanel = selectedPanelIdx;
        end
        if nargin >= 1 && isfinite(selectedBinOverride)
            selectedBin = selectedBinOverride;
        else
            selectedBin = selectedRedBinIdx;
        end

        if ~isfinite(selectedPanel) || ~isfinite(selectedBin)
            warning('No red bin selected. Right-click a red bin first.');
            return;
        end
        selectedPanel = max(1, min(selectedPanel, numel(histogramContext.panelData)));
        selectedBin = max(1, min(selectedBin, numel(histogramContext.sharedBinEdges) - 1));

        selectedPanelData = histogramContext.panelData(selectedPanel);
        dampingMin = histogramContext.sharedBinEdges(selectedBin);
        dampingMax = histogramContext.sharedBinEdges(selectedBin + 1);

        peakTable = extractDampingPeakTable(allStats, options.redFlagField, selectedPanelData.direction, ...
            frequencyFocus=options.frequencyFocus, ...
            targetFreqs=targetFreqs, ...
            freqTolerance=freqTolerance);
        if isempty(peakTable)
            warning('No peak table available for selected red events.');
            return;
        end

        sensorMask = strcmp(string(peakTable.sensor), string(selectedPanelData.sensorName));
        selectedPeaks = peakTable(sensorMask & peakTable.damping >= dampingMin & peakTable.damping <= dampingMax, :);
        if isempty(selectedPeaks)
            warning('No red peaks found in selected damping range [%.5f, %.5f] for %s.', dampingMin, dampingMax, selectedPanelData.sensorName);
            return;
        end

        iPrintVerbose('[plotDampingByEventType] Opening dashboard for %s in bin [%.5f, %.5f] with %d peaks.', ...
            selectedPanelData.sensorName, dampingMin, dampingMax, height(selectedPeaks));

        selectionInfo = struct('flagField', options.redFlagField, 'flagName', options.redFlagField, ...
            'direction', selectedPanelData.direction, 'sensor', selectedPanelData.sensorName, ...
            'dampingMin', dampingMin, 'dampingMax', dampingMax);
        plotDampingSelectionDashboard(selectedPeaks, selectionInfo, windContext="global");
    end

    function iSaveCurrentFigure()
        if strlength(options.figureFolder) == 0
            iPrintVerbose('[plotDampingByEventType] Save skipped: figureFolder is empty.');
            return;
        end

        histogramContext = getappdata(fig, 'HistogramContext');
        if ~isempty(histogramContext) && isfield(histogramContext, 'tlo') && isgraphics(histogramContext.tlo)
            iSetFigureTitle(histogramContext.tlo, false);
        end

        saveName = sprintf('DampingHistogram_AllDirections_%s', char(currentXAxisScale));
        saveFig(fig, options.figureFolder, saveName, 2, 1, scaleFigure=false);

        if ~isempty(histogramContext) && isfield(histogramContext, 'tlo') && isgraphics(histogramContext.tlo)
            iSetFigureTitle(histogramContext.tlo, true);
        end
        iPrintVerbose('[plotDampingByEventType] Figure saved as %s.', saveName);
    end

    function iSetGlobalAxisLabels(tlo)
        xlabel(tlo, 'Damping $\zeta$', 'Interpreter', 'latex');
        if options.normalization == "probability"
            ylabel(tlo, 'Probability', 'Interpreter', 'latex');
        else
            ylabel(tlo, 'Count', 'Interpreter', 'latex');
        end

        existingRightLabel = findall(fig, 'Tag', 'GlobalRightYLabel');
        if ~isempty(existingRightLabel)
            delete(existingRightLabel);
        end
        if options.showCdf
            annotation(fig, 'textbox', [0.978, 0.44, 0.02, 0.12], ...
                'String', 'CDF', 'Interpreter', 'latex', 'EdgeColor', 'none', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'Rotation', 90, 'Tag', 'GlobalRightYLabel');
        end
    end

    function iSetFigureTitle(tlo, includeUiHints)
        if includeUiHints
            titleText = sprintf(['Damping Histograms by Sensor and Direction (X-axis: %s, bins: %d)  ', ...
                '[L toggle log/linear | +/- bins | Right-click red bin inspect | D inspect selected | S save]'], ...
                char(currentXAxisScale), currentNumBins);
        else
            titleText = sprintf('Damping Histograms by Sensor and Direction (X-axis: %s, bins: %d)', ...
                char(currentXAxisScale), currentNumBins);
        end
        title(tlo, titleText, 'Interpreter', 'latex');
    end

    function iPrintVerbose(message, varargin)
        if ~options.verboseClicks
            return;
        end
        if isempty(varargin)
            fprintf('%s\n', message);
        else
            fprintf([message '\n'], varargin{:});
        end
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

function sensorDirectionData = iCollectSensorDirectionData(allStats, sensorName, frequencyFocus, targetFreqs, freqTolerance, redFlagField, blueFlagField)
sensorName = string(sensorName);
sensorDirectionData = struct('gray', [], 'blue', [], 'red', []);

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

sensorNameChar = char(sensorName);
for rowIdx = 1:height(allStats)
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
        sensorDirectionData.red = [sensorDirectionData.red; validDamping];
    elseif isBlue(rowIdx)
        sensorDirectionData.blue = [sensorDirectionData.blue; validDamping];
    elseif isGray(rowIdx)
        sensorDirectionData.gray = [sensorDirectionData.gray; validDamping];
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

function globalMinPositive = iGetGlobalMinPositiveDamping(dampingBySensorDirection, sensorPrefixes, directions)
globalMinPositive = inf;
for sensorPrefix = sensorPrefixes
    for direction = directions
        sensorDirectionData = dampingBySensorDirection.(char(sensorPrefix)).(char(direction));
        for category = {'gray', 'blue', 'red'}
            currentValues = sensorDirectionData.(category{1});
            currentValues = currentValues(currentValues > 0 & isfinite(currentValues));
            if ~isempty(currentValues)
                globalMinPositive = min(globalMinPositive, min(currentValues));
            end
        end
    end
end
if ~isfinite(globalMinPositive)
    globalMinPositive = 1e-4;
end
end

function globalMaxValue = iGetGlobalMaxDamping(dampingBySensorDirection, sensorPrefixes, directions)
globalMaxValue = -inf;
for sensorPrefix = sensorPrefixes
    for direction = directions
        sensorDirectionData = dampingBySensorDirection.(char(sensorPrefix)).(char(direction));
        globalMaxValue = max([globalMaxValue, iGetStructMax(sensorDirectionData.gray), iGetStructMax(sensorDirectionData.blue), iGetStructMax(sensorDirectionData.red)]);
    end
end
if ~isfinite(globalMaxValue)
    globalMaxValue = NaN;
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

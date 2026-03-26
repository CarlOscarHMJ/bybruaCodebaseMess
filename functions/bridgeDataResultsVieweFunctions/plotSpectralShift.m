function plotSpectralShift(allStats, limits, options)
    % plotSpectralShift generates an interactive spectral shift scatter plot analyzing PSD peaks.
    arguments
        allStats table
        limits struct
        options.specFlagField {mustBeTextScalar} = 'flag_PSDTotal'
        options.envFlagField {mustBeTextScalar} = 'flag_EnvironmentalMatch'
        options.targetSensors string = ["Conc_Z", "Steel_Z"]
        options.windDomain string = "local"
        options.figureFolder string = ""
        options.plotBackground logical = true
        options.independentSensorScaling logical = true
    end

    figHandle = createFigure(8, 'SpectralShift');
    layoutObj = tiledlayout(length(options.targetSensors), 1, 'TileSpacing', 'compact', 'Padding', 'tight');
    coverageTable = getDataConverageTable('noplot');

    dragState = struct('isActive', false, 'startX', [], 'patchHandle', [], 'textHandle', []);
    set(figHandle, 'WindowButtonDownFcn', @onWindowButtonDown, ...
                   'WindowButtonMotionFcn', @onWindowButtonMotion, ...
                   'WindowButtonUpFcn', @onWindowButtonUp);

    extractedData = cell(length(options.targetSensors), 1);
    allIntensities = [];

    for i = 1:length(options.targetSensors)
        [peakTimes, peakFreqs, peakIntensities, specFlags, envFlags, peakDurations, rainValues] = extractSensorPeaks(allStats, options.targetSensors(i), options.specFlagField, options.envFlagField);
        
        extractedData{i} = struct('peakTimes', peakTimes, 'peakFreqs', peakFreqs, ...
                                  'peakIntensities', peakIntensities, 'specFlags', specFlags, 'envFlags', envFlags, ...
                                  'peakDurations', peakDurations, 'rainValues', rainValues);
        
        allIntensities = [allIntensities; peakIntensities];
    end
    
    [globalMin, globalMax] = getIntensityBounds(allIntensities);

    for i = 1:length(options.targetSensors)
        currentSensor = options.targetSensors(i);
        sensorData = extractedData{i};
        
        if options.independentSensorScaling
            [localMin, localMax] = getIntensityBounds(sensorData.peakIntensities);
        else
            localMin = globalMin;
            localMax = globalMax;
        end
        
        axHandle = nexttile(layoutObj);
        renderPeakScatter(sensorData.peakTimes, sensorData.peakFreqs, sensorData.peakIntensities, sensorData.specFlags, sensorData.envFlags, ...
                          sensorData.peakDurations, sensorData.rainValues, currentSensor, limits, coverageTable, localMin, localMax, globalMin, globalMax, options.plotBackground);
    end

    linkaxes(findobj(figHandle, 'Type', 'axes'), 'xy');

    if strlength(options.figureFolder) > 0
        saveName = strrep(sprintf('SpectralShift_%s_%s', options.specFlagField, options.envFlagField), '_', '');
        saveFig(figHandle, options.figureFolder, saveName, 2, 1);
    end
end

function [peakTimes, peakFreqs, peakIntensities, specFlags, envFlags, peakDurations, rainValues] = extractSensorPeaks(allStats, sensor, specFlagField, envFlagField)
    % extractSensorPeaks pulls peak information and environmental flags for a specific sensor.
    numRows = height(allStats);
    peakFreqsCell = cell(numRows, 1);
    peakIntensitiesCell = cell(numRows, 1);
    numPeaksArray = zeros(numRows, 1);

    for i = 1:numRows
        locations = allStats.psdPeaks(i).(sensor).locations(:);
        peakFreqsCell{i} = locations;
        peakIntensitiesCell{i} = allStats.psdPeaks(i).(sensor).logIntensity(:);
        numPeaksArray(i) = length(locations);
    end

    peakFreqs = vertcat(peakFreqsCell{:});
    peakIntensities = vertcat(peakIntensitiesCell{:});

    eventTimes = mean(allStats.duration, 2);
    specFlagsArray = allStats.(specFlagField);
    envFlagsArray = allStats.(envFlagField);
    rainArray = allStats.RainIntensity;

    peakTimes = repelem(eventTimes, numPeaksArray);
    specFlags = repelem(specFlagsArray, numPeaksArray);
    envFlags = repelem(envFlagsArray, numPeaksArray);
    peakDurations = repelem(allStats.duration, numPeaksArray, 1);
    rainValues = repelem(rainArray, numPeaksArray, 1);
end

function renderPeakScatter(peakTimes, peakFreqs, peakIntensities, specFlags, envFlags, peakDurations, rainValues, sensor, limits, coverageTable, localMin, localMax, globalMin, globalMax, plotBackground)
    % renderPeakScatter handles the visual rendering of the peak scatter plot for a single sensor.
    hold on;
    [minTime, maxTime] = addCoveragePatches(coverageTable, peakTimes);
    addThresholdPatches(limits, minTime, maxTime);

    markerSizes = calculateMarkerSizes(peakIntensities, localMin, localMax, globalMin, globalMax);

    isRed = specFlags;
    isBlue = ~specFlags & envFlags & (rainValues > 0);
    isGray = ~specFlags & ~envFlags | (rainValues <= 0);

    if plotBackground && any(isGray)
        sGray = scatter(peakTimes(isGray), peakFreqs(isGray), markerSizes(isGray), [0.6 0.6 0.6], 'filled', 'MarkerFaceAlpha', 0.15, 'HitTest', 'off');
        sGray.UserData = peakDurations(isGray, :);
    end

    if any(isBlue)
        sBlue = scatter(peakTimes(isBlue), peakFreqs(isBlue), markerSizes(isBlue), [0.2 0.4 0.6], 'filled', 'MarkerFaceAlpha', 0.6, 'HitTest', 'off');
        sBlue.UserData = peakDurations(isBlue, :);
    end

    if any(isRed)
        sRed = scatter(peakTimes(isRed), peakFreqs(isRed), markerSizes(isRed), [0.8 0.2 0.2], 'filled', 'MarkerFaceAlpha', 0.6, 'HitTest', 'off');
        sRed.UserData = peakDurations(isRed, :);
    end

    yline(limits.targetFreqs, '--k', 'LineWidth', 1.2, 'Alpha', 0.6, 'HitTest', 'off');

    ylim([0 10]);
    if ~isempty(minTime) && ~isempty(maxTime)
        xlim([minTime maxTime]);
    end

    grid on; box on;
    title(sprintf('Sensor: \\texttt{%s}', strrep(sensor, '_', '\_')), 'Interpreter', 'latex');
    ylabel('Frequency (Hz)', 'Interpreter', 'latex');
    set(gca, 'TickLabelInterpreter', 'latex');
end

function onPlotClick(src, ~)
    % onPlotClick identifies the closest data point and triggers a diagnostic response analysis.
    axHandle = ancestor(src, 'axes');
    clickCoords = axHandle.CurrentPoint(1, 1:2);
    clickX = clickCoords(1);
    clickY = clickCoords(2);
    
    clickTime = num2ruler(clickX, axHandle.XAxis);
    
    xLimits = axHandle.XAxis.Limits;
    yLimits = axHandle.YAxis.Limits;
    xTotalRange = days(diff(xLimits));
    yTotalRange = diff(yLimits);
    
    scatterObjects = findobj(axHandle, 'Type', 'scatter');
    minDist = inf;
    bestIdx = 0;
    bestScatter = [];
    
    for i = 1:numel(scatterObjects)
        currentScatter = scatterObjects(i);
        if isempty(currentScatter.XData), continue; end
        
        xData = currentScatter.XData;
        yData = currentScatter.YData;
        
        xDist = days(xData - clickTime);
        yDist = yData - clickY;
        
        normalizedDist = (xDist / xTotalRange).^2 + (yDist / yTotalRange).^2;
        [localMin, localIdx] = min(normalizedDist);
        
        if ~isempty(localMin) && localMin < minDist
            minDist = localMin;
            bestIdx = localIdx;
            bestScatter = currentScatter;
        end
    end
    
    if ~isempty(bestScatter) && minDist < 0.1
        segmentDurations = bestScatter.UserData;
        startTime = segmentDurations(bestIdx, 1);
        endTime = segmentDurations(bestIdx, 2);
        
        fprintf('Selected event at %s (Freq: %.2f Hz)\n', char(bestScatter.XData(bestIdx)), bestScatter.YData(bestIdx));
        inspectDayResponse(startTime, endTime,"freqMethod","burg");
    end
end

function onWindowButtonDown(~, ~)
    dragState = getDragState(gcf);
    selType = get(gcf, 'SelectionType');
    
    if strcmp(selType, 'alt')
        ax = gca;
        pt = ax.CurrentPoint(1, 1:2);
        dragState.isActive = true;
        dragState.startX = pt(1);
        
        yLim = ax.YAxis.Limits;
        dragState.patchHandle = patch([pt(1) pt(1) pt(1) pt(1)], [yLim(1) yLim(1) yLim(2) yLim(2)], ...
            [0.8 0.6 0.2], 'FaceAlpha', 0.3, 'EdgeColor', [0.6 0.4 0.1], 'LineWidth', 2, 'HandleVisibility', 'off');
        dragState.textHandle = text(pt(1), yLim(2), '', 'VerticalAlignment', 'top', ...
            'BackgroundColor', [0.9 0.8 0.6], 'FontSize', 9, 'HitTest', 'off');
        
        setDragState(gcf, dragState);
    elseif strcmp(selType, 'normal')
        ax = gca;
        clickCoords = ax.CurrentPoint(1, 1:2);
        clickX = clickCoords(1);
        clickY = clickCoords(2);
        
        clickTime = num2ruler(clickX, ax.XAxis);
        
        xLimits = ax.XAxis.Limits;
        yLimits = ax.YAxis.Limits;
        xTotalRange = days(diff(xLimits));
        yTotalRange = diff(yLimits);
        
        scatterObjects = findobj(ax, 'Type', 'scatter');
        minDist = inf;
        bestIdx = 0;
        bestScatter = [];
        
        for i = 1:numel(scatterObjects)
            currentScatter = scatterObjects(i);
            if isempty(currentScatter.XData), continue; end
            
            xData = currentScatter.XData;
            yData = currentScatter.YData;
            
            xDist = days(xData - clickTime);
            yDist = yData - clickY;
            
            normalizedDist = (xDist / xTotalRange).^2 + (yDist / yTotalRange).^2;
            [localMin, localIdx] = min(normalizedDist);
            
            if ~isempty(localMin) && localMin < minDist
                minDist = localMin;
                bestIdx = localIdx;
                bestScatter = currentScatter;
            end
        end
        
        if ~isempty(bestScatter) && minDist < 0.1
            segmentDurations = bestScatter.UserData;
            startTime = segmentDurations(bestIdx, 1);
            endTime = segmentDurations(bestIdx, 2);
            
            fprintf('Selected event at %s (Freq: %.2f Hz)\n', char(bestScatter.XData(bestIdx)), bestScatter.YData(bestIdx));
            inspectDayResponse(startTime, endTime, "freqMethod", "burg");
        end
    end
end

function onWindowButtonMotion(~, ~)
    dragState = getDragState(gcf);
    if dragState.isActive && isvalid(dragState.patchHandle)
        ax = gca;
        pt = ax.CurrentPoint(1, 1:2);
        
        startX = min(dragState.startX, pt(1));
        endX = max(dragState.startX, pt(1));
        
        yLim = ax.YAxis.Limits;
        set(dragState.patchHandle, 'XData', [startX startX endX endX]);
        set(dragState.patchHandle, 'YData', [yLim(1) yLim(2) yLim(2) yLim(1)]);
        
        startTime = num2ruler(startX, ax.XAxis);
        endTime = num2ruler(endX, ax.XAxis);
        startStr = datestr(startTime, 'mm/dd HH:MM');
        endStr = datestr(endTime, 'mm/dd HH:MM');
        set(dragState.textHandle, 'String', sprintf('%s - %s', startStr, endStr), 'Position', [startX yLim(2)]);
    end
end

function onWindowButtonUp(~, ~)
    dragState = getDragState(gcf);
    if dragState.isActive && isvalid(dragState.patchHandle)
        ax = gca;
        pt = ax.CurrentPoint(1, 1:2);
        
        startX = min(dragState.startX, pt(1));
        endX = max(dragState.startX, pt(1));
        
        startTime = num2ruler(startX, ax.XAxis);
        endTime = num2ruler(endX, ax.XAxis);
        
        durationHours = hours(endTime - startTime);
        
        if durationHours > 0.01
            fprintf('Selected time range: %s to %s (Duration: %.1f hours)\n', ...
                datestr(startTime), datestr(endTime), durationHours);
            inspectDayResponse(startTime, endTime, "freqMethod", "welch");
        end
        
        delete(dragState.patchHandle);
        if isvalid(dragState.textHandle)
            delete(dragState.textHandle);
        end
    end
    
    dragState.isActive = false;
    dragState.startX = [];
    dragState.patchHandle = [];
    dragState.textHandle = [];
    setDragState(gcf, dragState);
end

function state = getDragState(fig)
    if isappdata(fig, 'DragState')
        state = getappdata(fig, 'DragState');
    else
        state = struct('isActive', false, 'startX', [], 'patchHandle', [], 'textHandle', []);
    end
end

function setDragState(fig, state)
    setappdata(fig, 'DragState', state);
end

function [minTime, maxTime] = addCoveragePatches(coverageTable, peakTimes)
    % addCoveragePatches draws background area plots indicating data coverage availability.
    coverageTime = coverageTable.Date;
    coverageBridge = coverageTable.BridgeCoverage;
    coverageFull = coverageTable.BridgeCoverage & coverageTable.CableCoverage;
    yMaxLimit = 10;

    minTime = min(coverageTime);
    maxTime = max(coverageTime);

    if ~isempty(peakTimes)
        minTime = min([minTime; min(peakTimes)]);
        maxTime = max([maxTime; max(peakTimes)]);
    end

    if isempty(minTime) || isempty(maxTime)
        return;
    end

    [stepTime, stepBridge] = createStepVectors(coverageTime, coverageBridge);
    [~, stepFull] = createStepVectors(coverageTime, coverageFull);

    area([minTime maxTime], [yMaxLimit yMaxLimit], 'FaceColor', 'red', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off', 'HitTest', 'off');
    area(stepTime, stepBridge * yMaxLimit, 'FaceColor', 'green', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off', 'HitTest', 'off');
    area(stepTime, stepFull * yMaxLimit, 'FaceColor', 'blue', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off', 'HitTest', 'off');
end

function [stepX, stepY] = createStepVectors(xData, yData)
    % createStepVectors transforms data into a step-like format for visualization.
    stepX = repelem(xData(:), 2);
    stepX(end) = [];
    stepY = repelem(yData(:), 2);
    stepY(1) = [];
end

function [minIntensity, maxIntensity] = getIntensityBounds(intensities)
    % getIntensityBounds calculates the range of log-intensities for marker scaling.
    if isempty(intensities)
        minIntensity = 0;
        maxIntensity = 0;
        return;
    end
    
    intensitySized = (10e+05 * exp(intensities)) - 1;
    minIntensity = min(intensitySized);
    maxIntensity = max(intensitySized);
end

function markerSizes = calculateMarkerSizes(intensities, localMin, localMax, globalMin, globalMax)
    % calculateMarkerSizes computes marker areas based on relative peak log-intensities.
    if isempty(intensities)
        markerSizes = [];
        return;
    end

    intensitySized = (10e+05 * exp(intensities)) - 1;
    targetMinSize = 10;
    targetMaxSize = (globalMax - globalMin) + targetMinSize;

    if localMin == localMax
        markerSizes = repmat(targetMinSize, size(intensitySized));
    else
        markerSizes = targetMinSize + (intensitySized - localMin) * ((targetMaxSize - targetMinSize) / (localMax - localMin));
    end
end

function addThresholdPatches(limits, minTime, maxTime)
    % addThresholdPatches overlays shaded regions indicating target frequency tolerances.
    if isempty(minTime) || isempty(maxTime)
        return;
    end

    targetFreqs = limits.targetFreqs(:)';
    frequencyTolerance = limits.freqTolerance; 
    
    xVerts = repmat([minTime; maxTime; maxTime; minTime], 1, length(targetFreqs));
    yVerts = [targetFreqs - frequencyTolerance; targetFreqs - frequencyTolerance; targetFreqs + frequencyTolerance; targetFreqs + frequencyTolerance];
    
    patch(xVerts, yVerts, [0.5 0.5 0.5], 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off', 'HitTest', 'off');
end

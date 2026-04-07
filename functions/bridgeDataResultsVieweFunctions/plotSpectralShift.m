function plotSpectralShift(allStats, limits, options)
    % plotSpectralShift Generates an interactive spectral shift scatter plot analyzing PSD peaks.
    %
    % Description:
    %   Creates a time-frequency scatter plot of PSD peak frequencies, with interactive
    %   click-to-inspect functionality and optional damping ratio visualization.
    %
    % Arguments:
    %   allStats  - Table containing PSD peak data with fields:
    %               - psdPeaks: struct array with .locations, .logIntensity, .dampingRatios
    %               - duration: [startTime, endTime] for each measurement
    %               - RainIntensity.mean: average rain intensity
    %               - Spec/Env flag fields as specified by options
    %   limits    - Struct with:
    %               - targetFreqs: target frequencies (Hz)
    %               - freqTolerance: tolerance band around targets
    %
    % Options (name-value pairs):
    %   specFlagField      - Field name for spectral match flag (default: 'flag_PSDTotal')
    %   envFlagField       - Field name for environmental match flag (default: 'flag_EnvironmentalMatch')
    %   targetSensors      - Sensor names to plot (default: ["Conc_Z", "Steel_Z"])
    %   directions         - Direction suffixes for plotAllDirections mode (default: ["X", "Y", "Z"])
    %   plotAllDirections  - Plot all X/Y/Z directions separately (default: false)
    %   windDomain         - Wind domain: "local" or "global" (default: "local")
    %   figureFolder       - Folder path to save figure (default: "")
    %   plotBackground     - Show gray background points (default: true)
    %   plotBluePoints     - Show blue points (env match + rain) (default: true)
    %   independentSensorScaling - Use independent intensity scaling per sensor (default: true)
    %   plotDamping        - Show damping ratio as face color via colormap (default: true)
    %
    % Output:
    %   Interactive figure with:
    %   - Marker colors: Semantic meaning (red=spectral match, blue=env match+rain, gray=background)
    %   - Marker size: Relative peak intensity
    %   - Face color: Damping ratio (if plotDamping=true, via gray colormap)
    %   - Left-click: Inspect individual peaks
    %   - Right-drag: Select time range for inspection
    %
    % Example:
    %   plotSpectralShift(allStats, limits, 'targetSensors', ["Conc_Z", "Steel_Z"], 'plotDamping', true)
    %
    % See also: inspectDayResponse, getDataConverageTable
    
    arguments
        allStats table
        limits struct
        options.specFlagField {mustBeTextScalar} = 'flag_PSDTotal'
        options.envFlagField {mustBeTextScalar} = 'flag_EnvironmentalMatch'
        options.targetSensors string = ["Conc_Z", "Steel_Z"]
        options.directions string = ["X", "Y", "Z"]
        options.plotAllDirections logical = false
        options.windDomain string = "local"
        options.figureFolder string = ""
        options.plotBackground logical = true
        options.plotBluePoints logical = true
        options.independentSensorScaling logical = true
        options.plotDamping logical = true
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
    allDamping = [];

    for i = 1:length(options.targetSensors)
        sensorBase = options.targetSensors(i);
        
        if options.plotAllDirections
            allDirPeakTimes = [];
            allDirPeakFreqs = [];
            allDirPeakIntensities = [];
            allDirSpecFlags = [];
            allDirEnvFlags = [];
            allDirPeakDurations = [];
            allDirRainValues = [];
            allDirDirections = [];
            allDirDamping = [];
            
            for d = 1:length(options.directions)
                direction = char(options.directions(d));
                sensorPrefix = char(sensorBase);
                fullSensor = [sensorPrefix(1:end-1) direction];
                [peakTimes, peakFreqs, peakIntensities, specFlags, envFlags, peakDurations, rainValues, peakDamping] = extractSensorPeaks(allStats, fullSensor, options.specFlagField, options.envFlagField);
                
                allDirPeakTimes = [allDirPeakTimes; peakTimes];
                allDirPeakFreqs = [allDirPeakFreqs; peakFreqs];
                allDirPeakIntensities = [allDirPeakIntensities; peakIntensities];
                allDirSpecFlags = [allDirSpecFlags; specFlags];
                allDirEnvFlags = [allDirEnvFlags; envFlags];
                allDirPeakDurations = [allDirPeakDurations; peakDurations];
                allDirRainValues = [allDirRainValues; rainValues];
                allDirDirections = [allDirDirections; repmat(direction, length(peakTimes), 1)];
                allDirDamping = [allDirDamping; peakDamping];
            end
            
            extractedData{i} = struct('peakTimes', allDirPeakTimes, 'peakFreqs', allDirPeakFreqs, ...
                                      'peakIntensities', allDirPeakIntensities, 'specFlags', allDirSpecFlags, 'envFlags', allDirEnvFlags, ...
                                      'peakDurations', allDirPeakDurations, 'rainValues', allDirRainValues, 'directions', allDirDirections, ...
                                      'peakDamping', allDirDamping);
        else
            [peakTimes, peakFreqs, peakIntensities, specFlags, envFlags, peakDurations, rainValues, peakDamping] = extractSensorPeaks(allStats, sensorBase, options.specFlagField, options.envFlagField);
            
            extractedData{i} = struct('peakTimes', peakTimes, 'peakFreqs', peakFreqs, ...
                                      'peakIntensities', peakIntensities, 'specFlags', specFlags, 'envFlags', envFlags, ...
                                      'peakDurations', peakDurations, 'rainValues', rainValues, 'peakDamping', peakDamping);
        end
        
        allIntensities = [allIntensities; extractedData{i}.peakIntensities];
        allDamping = [allDamping; extractedData{i}.peakDamping];
    end
    
    [globalMin, globalMax] = getIntensityBounds(allIntensities);
    
    validDamping = allDamping(~isnan(allDamping));
    if ~isempty(validDamping)
        globalDampingMin = min(validDamping);
        globalDampingMax = max(validDamping);
    else
        globalDampingMin = 0;
        globalDampingMax = 1;
    end

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
                          sensorData.peakDurations, sensorData.rainValues, sensorData.peakDamping, currentSensor, limits, coverageTable, ...
                          localMin, localMax, globalMin, globalMax, options.plotBackground, options.plotBluePoints, options.plotAllDirections, sensorData, ...
                          globalDampingMin, globalDampingMax, options.plotDamping);
    end

    linkaxes(findobj(figHandle, 'Type', 'axes'), 'xy');

    if options.plotDamping
        colorbarHandle = colorbar();
        colorbarHandle.Layout.Tile = 'east';
        colorbarHandle.Label.String = 'Damping Ratio';
        colorbarHandle.Label.Interpreter = 'latex';
    end

    if strlength(options.figureFolder) > 0
        saveName = strrep(sprintf('SpectralShift_%s_%s', options.specFlagField, options.envFlagField), '_', '');
        saveFig(figHandle, options.figureFolder, saveName, 2, 1);
    end
end


function [peakTimes, peakFreqs, peakIntensities, specFlags, envFlags, peakDurations, rainValues, peakDamping] = extractSensorPeaks(allStats, sensor, specFlagField, envFlagField)
    % extractSensorPeaks pulls peak information and environmental flags for a specific sensor.
    sensor = char(sensor);
    numRows = height(allStats);
    peakFreqsCell = cell(numRows, 1);
    peakIntensitiesCell = cell(numRows, 1);
    peakDampingCell = cell(numRows, 1);
    numPeaksArray = zeros(numRows, 1);

    for i = 1:numRows
        locations = allStats.psdPeaks(i).(sensor).locations(:);
        peakFreqsCell{i} = locations;
        peakIntensitiesCell{i} = allStats.psdPeaks(i).(sensor).logIntensity(:);
        if isfield(allStats.psdPeaks(i).(sensor), 'dampingRatios')
            peakDampingCell{i} = allStats.psdPeaks(i).(sensor).dampingRatios(:);
        else
            peakDampingCell{i} = NaN(size(locations));
        end
        numPeaksArray(i) = length(locations);
    end

    peakFreqs = vertcat(peakFreqsCell{:});
    peakIntensities = vertcat(peakIntensitiesCell{:});
    peakDamping = vertcat(peakDampingCell{:});

    eventTimes = mean(allStats.duration, 2);
    specFlagsArray = allStats.(char(specFlagField));
    envFlagsArray = allStats.(char(envFlagField));
    rainArray = [allStats.RainIntensity.mean]';

    peakTimes = repelem(eventTimes, numPeaksArray);
    specFlags = repelem(specFlagsArray, numPeaksArray);
    envFlags = repelem(envFlagsArray, numPeaksArray);
    peakDurations = repelem(allStats.duration, numPeaksArray, 1);
    rainValues = repelem(rainArray, numPeaksArray, 1);
end


function renderPeakScatter(peakTimes, peakFreqs, peakIntensities, specFlags, envFlags, peakDurations, rainValues, peakDamping, sensor, limits, coverageTable, localMin, localMax, globalMin, globalMax, plotBackground, plotBluePoints, plotAllDirections, sensorData, dampingMin, dampingMax, plotDamping)
    % renderPeakScatter handles the visual rendering of the peak scatter plot for a single sensor.
    hold on;
    [minTime, maxTime] = addCoveragePatches(coverageTable, peakTimes);
    addThresholdPatches(limits, minTime, maxTime);

    markerSizes = calculateMarkerSizes(peakIntensities, localMin, localMax, globalMin, globalMax);

    isRed = specFlags;
    isBlue = ~specFlags & envFlags & (rainValues > 0);
    isGray = ~specFlags & ~envFlags | (rainValues <= 0);

    if plotDamping
        colormap(gca, myColorMap());
        caxis([0 1]);
    end

    if plotAllDirections && isfield(sensorData, 'directions')
        directions = sensorData.directions;
        directionMarkers = struct('X', '^', 'Y', 'square', 'Z', 'o');
        
        uniqueDirs = unique(directions);
        
        for d = 1:length(uniqueDirs)
            dirMask = directions == uniqueDirs(d);
            dirChar = char(uniqueDirs(d));
            marker = directionMarkers.(dirChar);
            
            dirRed = isRed & dirMask;
            dirBlue = isBlue & dirMask;
            dirGray = isGray & dirMask;
            
            if plotBackground && any(dirGray)
                plotScatter(peakTimes(dirGray), peakFreqs(dirGray), markerSizes(dirGray), [0.6 0.6 0.6], 0.15, peakDamping(dirGray), peakDurations(dirGray, :), marker, plotDamping);
            end
            
            if plotBluePoints && any(dirBlue)
                plotScatter(peakTimes(dirBlue), peakFreqs(dirBlue), markerSizes(dirBlue), [0.2 0.4 0.6], 0.6, peakDamping(dirBlue), peakDurations(dirBlue, :), marker, plotDamping);
            end
            
            if any(dirRed)
                plotScatter(peakTimes(dirRed), peakFreqs(dirRed), markerSizes(dirRed), [0.8 0.2 0.2], 0.6, peakDamping(dirRed), peakDurations(dirRed, :), marker, plotDamping);
            end
        end
    else
        if plotBackground && any(isGray)
            plotScatter(peakTimes(isGray), peakFreqs(isGray), markerSizes(isGray), [0.6 0.6 0.6], 0.15, peakDamping(isGray), peakDurations(isGray, :), 'o', plotDamping);
        end

        if plotBluePoints && any(isBlue)
            plotScatter(peakTimes(isBlue), peakFreqs(isBlue), markerSizes(isBlue), [0.2 0.4 0.6], 0.6, peakDamping(isBlue), peakDurations(isBlue, :), 'o', plotDamping);
        end

        if any(isRed)
            plotScatter(peakTimes(isRed), peakFreqs(isRed), markerSizes(isRed), [0.8 0.2 0.2], 0.6, peakDamping(isRed), peakDurations(isRed, :), 'o', plotDamping);
        end
    end

    yline(limits.targetFreqs, '--k', 'LineWidth', 1.2, 'Alpha', 0.6, 'HitTest', 'off');

    ylim([0 10]);
    if ~isempty(minTime) && ~isempty(maxTime)
        xlim([minTime maxTime]);
    end

    grid on; box on;
    if plotAllDirections
        title(sprintf('Sensor: \\texttt{%s} (triangle=X, square=Y, circle=Z)', strrep(sensor(1:end-1), '_', '\_')), 'Interpreter', 'latex');
    else
        title(sprintf('Sensor: \\texttt{%s}', strrep(sensor, '_', '\_')), 'Interpreter', 'latex');
    end
    ylabel('Frequency (Hz)', 'Interpreter', 'latex');
    set(gca, 'TickLabelInterpreter', 'latex');
end


function h = plotScatter(times, freqs, sizes, edgeColor, edgeAlpha, damping, durations, marker, plotDamping)
    if isempty(times)
        h = [];
        return;
    end
    
    if plotDamping
        h = scatter(times, freqs, sizes, 'Marker', marker, ...
            'MarkerFaceColor', 'flat', 'CData', damping, ...
            'MarkerFaceAlpha', edgeAlpha, ...
            'MarkerEdgeColor', edgeColor, 'LineWidth', 1.0, 'HitTest', 'off');
    else
        h = scatter(times, freqs, sizes, 'Marker', marker, ...
            'MarkerFaceColor', edgeColor, 'MarkerFaceAlpha', edgeAlpha, ...
            'MarkerEdgeColor', edgeColor, 'LineWidth', 0.5, 'HitTest', 'off');
    end
    h.UserData = struct('durations', durations, 'damping', damping);
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
        
        if ~isempty(bestScatter) && minDist < 0.05
            userData = bestScatter.UserData;
            if isstruct(userData)
                segmentDurations = userData.durations;
                damping = userData.damping(bestIdx);
            else
                segmentDurations = userData;
                damping = NaN;
            end
            startTime = segmentDurations(bestIdx, 1);
            endTime = segmentDurations(bestIdx, 2);
            
            if isnan(damping)
                fprintf('Selected event at %s (Freq: %.2f Hz)\n', char(bestScatter.XData(bestIdx)), bestScatter.YData(bestIdx));
            else
                fprintf('Selected event at %s (Freq: %.2f Hz, Damping: %.3f)\n', char(bestScatter.XData(bestIdx)), bestScatter.YData(bestIdx), damping);
            end
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

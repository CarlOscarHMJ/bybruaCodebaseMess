function plotSpectralShift(allStats, limits, options)
    % Generates a spectral shift scatter plot analyzing PSD peaks with specific flag coloring based on spectral and environmental conditions.
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

    fig = createFigure(8, 'SpectralShift');
    tiledLayoutObj = tiledlayout(length(options.targetSensors), 1, 'TileSpacing', 'compact', 'Padding', 'tight');
    coverageTable = getDataConverageTable('noplot');

    extractedData = cell(length(options.targetSensors), 1);
    allIntensities = [];

    for i = 1:length(options.targetSensors)
        [peakTimes, peakFreqs, peakIntensities, specFlags, envFlags] = extractSensorPeaks(allStats, options.targetSensors(i), options.specFlagField, options.envFlagField);
        
        extractedData{i} = struct('peakTimes', peakTimes, 'peakFreqs', peakFreqs, ...
                                  'peakIntensities', peakIntensities, 'specFlags', specFlags, 'envFlags', envFlags);
        
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
        
        ax(i) = nexttile;
        renderPeakScatter(sensorData.peakTimes, sensorData.peakFreqs, sensorData.peakIntensities, sensorData.specFlags, sensorData.envFlags, ...
                          currentSensor, limits, coverageTable, localMin, localMax, globalMin, globalMax, options.plotBackground);
    end

    linkaxes(ax, 'xy');

    if strlength(options.figureFolder) > 0
        saveName = strrep(sprintf('SpectralShift_%s_%s', options.specFlagField, options.envFlagField), '_', '');
        saveFig(fig, options.figureFolder, saveName, 2, 1);
    end
end

function [peakTimes, peakFreqs, peakIntensities, specFlags, envFlags] = extractSensorPeaks(allStats, sensor, specFlagField, envFlagField)
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

    peakTimes = repelem(eventTimes, numPeaksArray);
    specFlags = repelem(specFlagsArray, numPeaksArray);
    envFlags = repelem(envFlagsArray, numPeaksArray);
end

function renderPeakScatter(peakTimes, peakFreqs, peakIntensities, specFlags, envFlags, sensor, limits, coverageTable, localMin, localMax, globalMin, globalMax, plotBackground)
    hold on;
    [minTime, maxTime] = addCoveragePatches(coverageTable, peakTimes);
    addThresholdPatches(limits, minTime, maxTime);

    markerSizes = calculateMarkerSizes(peakIntensities, localMin, localMax, globalMin, globalMax);

    isRed = specFlags;
    isBlue = ~specFlags & envFlags;
    isGray = ~specFlags & ~envFlags;

    if plotBackground && any(isGray)
        scatter(peakTimes(isGray), peakFreqs(isGray), markerSizes(isGray), [0.6 0.6 0.6], 'filled', 'MarkerFaceAlpha', 0.15);
    end

    if any(isBlue)
        scatter(peakTimes(isBlue), peakFreqs(isBlue), markerSizes(isBlue), [0.2 0.4 0.6], 'filled', 'MarkerFaceAlpha', 0.6);
    end

    if any(isRed)
        scatter(peakTimes(isRed), peakFreqs(isRed), markerSizes(isRed), [0.8 0.2 0.2], 'filled', 'MarkerFaceAlpha', 0.6);
    end

    yline(limits.targetFreqs, '--k', 'LineWidth', 1.2, 'Alpha', 0.6);

    ylim([0 10]);
    if ~isempty(minTime) && ~isempty(maxTime)
        xlim([minTime maxTime]);
    end

    grid on; box on;
    title(sprintf('Sensor: \\texttt{%s}', strrep(sensor, '_', '\_')), 'Interpreter', 'latex');
    ylabel('Frequency (Hz)', 'Interpreter', 'latex');
    set(gca, 'TickLabelInterpreter', 'latex');
end

function [minTime, maxTime] = addCoveragePatches(coverageTable, peakTimes)
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

    area([minTime maxTime], [yMaxLimit yMaxLimit], 'FaceColor', 'red', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    area(stepTime, stepBridge * yMaxLimit, 'FaceColor', 'green', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    area(stepTime, stepFull * yMaxLimit, 'FaceColor', 'blue', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

function [stepX, stepY] = createStepVectors(xData, yData)
    stepX = repelem(xData(:), 2);
    stepX(end) = [];
    stepY = repelem(yData(:), 2);
    stepY(1) = [];
end

function [minIntensity, maxIntensity] = getIntensityBounds(intensities)
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
    if isempty(minTime) || isempty(maxTime)
        return;
    end

    targetFreqs = limits.targetFreqs(:)';
    frequencyTolerance = limits.freqTolerance; 
    
    xVerts = repmat([minTime; maxTime; maxTime; minTime], 1, length(targetFreqs));
    yVerts = [targetFreqs - frequencyTolerance; targetFreqs - frequencyTolerance; targetFreqs + frequencyTolerance; targetFreqs + frequencyTolerance];
    
    patch(xVerts, yVerts, [0.5 0.5 0.5], 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
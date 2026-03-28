function plotSpectralShiftHistogram(allStats, options)
    % plotSpectralShiftHistogram Plots layered 3D histograms of spectral shifts over time.
    arguments
        allStats
        options.targetSensors (1,:) string = ["Conc_Z", "Steel_Z"]
        options.envFlagField (1,1) string = "flag_PSDTotal_inGmm"
        options.specFlagField (1,1) string = "flag_PSDTotalAnd4Hz"
        options.numTimeChunks (1,1) double = 30
        options.numHistBins (1,1) double = 50
        options.timeField (1,1) string = "" 
        options.weightedHistogram (1,1) logical = true 
        options.intensityQuantile (1,1) double = 0 
        options.saveFigure (1,1) logical = false
        options.figureFolder (1,1) string = ""
        options.fileName (1,1) string = "SpectralShiftHistogram"
    end
    
    filteredStats = filterStatsData(allStats, options.envFlagField, options.specFlagField);
    timeLine = extractTimeLine(filteredStats, options.timeField);
    [timeIndices, timeEdges] = discretize(timeLine, options.numTimeChunks);
    
    chunkMidTimes = timeEdges(1:end-1) + diff(timeEdges)/2;
    
    figHandle = createFigure(1, 'Spectral Shift Evolution');
    layoutObj = tiledlayout(1,2, 'TileSpacing', 'compact', 'Padding', 'tight');
    
    if options.intensityQuantile > 0 && options.intensityQuantile < 1
        titleStr = sprintf('Spectral shift evolution, cases with C1 critical weather ($>%.0f^{\\mathrm{th}}$ Percentile Intensities)', ...
                    options.intensityQuantile * 100);
    else
        titleStr = 'Spectral shift evolution, cases with C1 critical weather';
    end
    title(layoutObj, titleStr, 'Interpreter', 'latex', 'FontSize', 14);
    
    axisArray = gobjects(1, length(options.targetSensors));
    
    for sensorIdx = 1:length(options.targetSensors)
        sensorName = options.targetSensors(sensorIdx);
        
        [countsMatrix, binEdges] = calculateHistograms(timeIndices, filteredStats, sensorName, ...
            options.numTimeChunks, options.numHistBins, options.weightedHistogram, options.intensityQuantile);
        
        axObj = nexttile;
        axisArray(sensorIdx) = axObj;
        
        renderLayered3DHistograms(axObj, countsMatrix, binEdges, chunkMidTimes, sensorName, options.weightedHistogram);
        clim(axObj, [min(chunkMidTimes), max(chunkMidTimes)]);
    end
    
    if length(axisArray) > 1
        syncRotationLink = linkprop(axisArray, {'View', 'XLim', 'YLim'});
        setappdata(figHandle, 'SyncRotationLink', syncRotationLink);
    end
    
    applyGlobalLegend(axisArray(1));
    applyDateColorbar(axisArray(end), chunkMidTimes);
    
    if options.saveFigure
        if strlength(options.figureFolder) == 0
            error('A valid figureFolder must be provided when saveFigure is true.');
        end
        saveFig(figHandle, options.figureFolder, options.fileName, 2,scaleFigure=false);
    end
end

function filteredStats = filterStatsData(allStats, envFlagField, specFlagField)
    % filterStatsData Filters the dataset based on the provided boolean flag fields.
    isValidData = allStats.(envFlagField) == true & allStats.(specFlagField) == true;
    filteredStats = allStats(isValidData, :);
end

function timeLine = extractTimeLine(dataTable, timeField)
    % extractTimeLine Extracts and standardizes the time vector from a table or struct.
    timeLineRaw = [];
    
    if istimetable(dataTable)
        timeLineRaw = dataTable.Properties.RowTimes;
    elseif istable(dataTable)
        vars = dataTable.Properties.VariableNames;
        if strlength(timeField) > 0 && any(strcmp(vars, timeField))
            timeLineRaw = dataTable.(timeField);
        else
            validNames = ["duration", "Time", "time", "Date", "date", "Timestamp", "timestamp", "Datetime", "datetime"];
            for name = validNames
                if any(strcmp(vars, name))
                    timeLineRaw = dataTable.(name);
                    break;
                end
            end
        end
    elseif isstruct(dataTable)
        fields = fieldnames(dataTable);
        if strlength(timeField) > 0 && any(strcmp(fields, timeField))
            timeLineRaw = [dataTable.(timeField)]';
        else
            validNames = ["duration", "Time", "time", "Date", "date", "Timestamp", "timestamp", "Datetime", "datetime"];
            for name = validNames
                if any(strcmp(fields, name))
                    timeLineRaw = [dataTable.(name)]';
                    break;
                end
            end
        end
    end
    
    if isempty(timeLineRaw)
        warning('Could not find a valid Time or Date field in allStats. Falling back to row indices.');
        if istable(dataTable)
            timeLine = (1:height(dataTable))';
        else
            timeLine = (1:length(dataTable))';
        end
        return;
    end
    
    if size(timeLineRaw, 2) > 1
        timeLineRaw = timeLineRaw(:, 1);
    end
    
    if isdatetime(timeLineRaw)
        timeLine = datenum(timeLineRaw);
    elseif isstring(timeLineRaw) || iscellstr(timeLineRaw)
        timeLine = datenum(datetime(timeLineRaw));
    else
        timeLine = timeLineRaw;
    end
end

function [countsMatrix, binEdges] = calculateHistograms(timeIndices, filteredStats, sensorName, numTimeChunks, numHistBins, useWeighted, intensityQuantile)
    % calculateHistograms Extracts locations and computes (weighted or count) histograms per time chunk.
    [globalLocations, globalIntensities] = extractLocationsFromStats(filteredStats, sensorName);
    
    if isempty(globalLocations)
        binEdges = linspace(0, 1, numHistBins + 1);
        countsMatrix = zeros(numHistBins, numTimeChunks);
        return;
    end
    
    if intensityQuantile > 0 && intensityQuantile < 1
        intensityThreshold = quantile(globalIntensities, intensityQuantile);
    else
        intensityThreshold = -Inf;
    end
    
    validGlobalMask = globalIntensities >= intensityThreshold;
    validGlobalLocations = globalLocations(validGlobalMask);
    
    if isempty(validGlobalLocations)
        binEdges = linspace(0, 1, numHistBins + 1);
        countsMatrix = zeros(numHistBins, numTimeChunks);
        return;
    end
    
    binEdges = linspace(min(validGlobalLocations), max(validGlobalLocations), numHistBins + 1);
    countsMatrix = zeros(numHistBins, numTimeChunks);
    
    for chunkIdx = 1:numTimeChunks
        chunkStats = filteredStats(timeIndices == chunkIdx, :);
        [chunkLocations, chunkIntensities] = extractLocationsFromStats(chunkStats, sensorName);
        
        if ~isempty(chunkLocations)
            [~, ~, binIdx] = histcounts(chunkLocations, binEdges);
            validMask = binIdx > 0 & binIdx <= numHistBins & chunkIntensities >= intensityThreshold;
            validBins = binIdx(validMask);
            
            if useWeighted
                validWeights = chunkIntensities(validMask);
                nanMask = isnan(validWeights);
                validBins(nanMask) = [];
                validWeights(nanMask) = [];
            else
                validWeights = ones(size(validBins));
            end
            
            if ~isempty(validBins)
                countsMatrix(:, chunkIdx) = accumarray(validBins, validWeights, [numHistBins 1]);
            end
        end
    end
end

function [extractedLocations, extractedIntensities] = extractLocationsFromStats(statsTable, sensorName)
    % extractLocationsFromStats Safely extracts the locations and true intensities from the nested psdPeaks struct.
    extractedLocations = [];
    extractedIntensities = [];
    
    if isempty(statsTable)
        return;
    end
    
    peakStructArray = [statsTable.psdPeaks];
    if isempty(peakStructArray) || ~isfield(peakStructArray, sensorName)
        return;
    end
    
    sensorPeaks = [peakStructArray.(sensorName)];
    if isempty(sensorPeaks) || ~isfield(sensorPeaks, 'locations') || ~isfield(sensorPeaks, 'logIntensity')
        return;
    end
    
    extractedLocations = vertcat(sensorPeaks.locations);
    extractedIntensities = exp(vertcat(sensorPeaks.logIntensity)); 
end

function renderLayered3DHistograms(axObj, countsMatrix, binEdges, chunkTimes, sensorName, useWeighted)
    % renderLayered3DHistograms Renders the stacked 2D histogram patches in a 3D axes along a true time axis.
    hold(axObj, 'on');
    numTimeChunks = length(chunkTimes);
    layerColors = parula(numTimeChunks);
    maxFrequencyZ = max(countsMatrix(:));
    
    if isempty(maxFrequencyZ) || maxFrequencyZ == 0
        maxFrequencyZ = 1; 
    end
    
    for chunkIdx = 1:numTimeChunks
        [xProfile, zProfile] = generateSteppedProfile(binEdges, countsMatrix(:, chunkIdx)');
        [xLine, zLine] = removeBottomLines(xProfile, zProfile);
        
        yProfile = repmat(chunkTimes(chunkIdx), 1, length(xProfile));
        yLine = repmat(chunkTimes(chunkIdx), 1, length(xLine));
        
        fill3(axObj, xProfile, yProfile, zProfile, layerColors(chunkIdx, :), ...
            'FaceAlpha', 0.85, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            
        plot3(axObj, xLine, yLine, zLine, 'k', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    end
    
    timeLimits = [chunkTimes(1), chunkTimes(end)];
    addAllCableFrequencyLines3D(axObj, timeLimits, maxFrequencyZ);
    
    view(axObj, 0, 0);
    % view(axObj, 25, 10);
    grid(axObj, 'on');
    box(axObj, 'on');
    
    zlim(axObj, [0, maxFrequencyZ * 1.05]);
    ylim(axObj, timeLimits); 
    xlim(axObj, [0 10]);

    pbaspect(axObj, [1.5, 3, 1.3]);
    
    title(axObj, strrep(sensorName, '_', '\_'), 'Interpreter', 'latex');
    xlabel(axObj, 'Frequency (Hz)', 'Interpreter', 'latex');
    ylabel(axObj, 'Time', 'Interpreter', 'latex');
    
    if useWeighted
        zlabel(axObj, 'Cumulative Intensity', 'Interpreter', 'latex');
    else
        zlabel(axObj, 'Count', 'Interpreter', 'latex');
    end
    
    yTicks = yticks(axObj);
    if max(yTicks) > 693960 
        timeSpan = timeLimits(2) - timeLimits(1);
        if timeSpan <= 5
            dateFmt = 'dd-MMM HH:mm';
        elseif timeSpan <= 90
            dateFmt = 'dd-MMM-yyyy';
        else
            dateFmt = 'MMM-yyyy';
        end
        yticklabels(axObj, string(datetime(yTicks, 'ConvertFrom', 'datenum'), dateFmt));
    end
    
    set(axObj, 'TickLabelInterpreter', 'latex', 'FontSize', 12);
    hold(axObj, 'off');
end

function addAllCableFrequencyLines3D(axObj, timeLimits, maxZ)
    % addAllCableFrequencyLines3D Renders 3D indicator lines for multiple cable and deck frequencies.
    cableFreqsC1 = [1.03, 2.08, 3.10, 4.15, 5.13, 6.16, 7.32, 8.30, 9.30];
    deckFreqsC1 = [1.83, 3.52, 5.15];
    
    targetModes = [cableFreqsC1(3), cableFreqsC1(6)];
    freqTolerance = 0.10;
    
    for fTarget = targetModes
        drawToleranceArea(axObj, fTarget, freqTolerance, timeLimits, maxZ);
    end
    
    drawFrequencyLines(axObj, cableFreqsC1, '--', [0 0 0], 0.8, timeLimits, maxZ);
    drawFrequencyLines(axObj, deckFreqsC1, '--', [0.85 0.33 0.1], 0.8, timeLimits, maxZ);
end

function drawFrequencyLines(axObj, freqs, lineStyle, color, alphaLevel, timeLimits, maxZ)
    % drawFrequencyLines Helper to draw lines along the floor and backwall for the timeline.
    tMin = timeLimits(1);
    tMax = timeLimits(2);
    
    for f = freqs
        plot3(axObj, [f, f, f], [tMin, tMax, tMax], [0, 0, maxZ], ...
             'Color', [color, alphaLevel], ...
             'LineStyle', lineStyle, ...
             'LineWidth', 1.5, ...
             'HandleVisibility', 'off');
    end
end

function drawToleranceArea(axObj, fTarget, tolerance, timeLimits, maxZ)
    % drawToleranceArea Generates semi-transparent 2D grey areas indicating the frequency tolerance bounds.
    tMin = timeLimits(1);
    tMax = timeLimits(2);
    fMin = fTarget - tolerance;
    fMax = fTarget + tolerance;
    
    patch(axObj, 'XData', [fMin, fMax, fMax, fMin], ...
                 'YData', [tMin, tMin, tMax, tMax], ...
                 'ZData', [0, 0, 0, 0], ...
                 'FaceColor', [0.85 0.85 0.85], 'FaceAlpha', 0.75, ...
                 'EdgeColor', 'none', 'HandleVisibility', 'off');
                 
    patch(axObj, 'XData', [fMin, fMax, fMax, fMin], ...
                 'YData', [tMax, tMax, tMax, tMax], ...
                 'ZData', [0, 0, maxZ, maxZ], ...
                 'FaceColor', [0.85 0.85 0.85], 'FaceAlpha', 0.75, ...
                 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

function [xProfile, zProfile] = generateSteppedProfile(binEdges, counts)
    % generateSteppedProfile Transforms bin edges and counts into coordinates for a stepped area plot.
    xProfile = repelem(binEdges, 2);
    xProfile = xProfile(2:end-1);
    zProfile = repelem(counts, 2);
    xProfile = [xProfile(1), xProfile, xProfile(end)];
    zProfile = [0, zProfile, 0];
end

function [xLine, zLine] = removeBottomLines(xProfile, zProfile)
    % removeBottomLines Breaks the outline wherever it is completely flat at Z=0.
    xLine = xProfile;
    zLine = zProfile;
    
    isBottomHoriz = (zLine(1:end-1) == 0) & (zLine(2:end) == 0) & (xLine(1:end-1) ~= xLine(2:end));
    insertPos = find(isBottomHoriz);
    
    for i = length(insertPos):-1:1
        idx = insertPos(i);
        xLine = [xLine(1:idx), NaN, xLine(idx+1:end)];
        zLine = [zLine(1:idx), NaN, zLine(idx+1:end)];
    end
end

function applyGlobalLegend(axObj)
    % applyGlobalLegend Creates a legend in the upper right corner using dummy 2D objects on an existing axis.
    hold(axObj, 'on');
    
    hTol = patch(axObj, 'XData', NaN, 'YData', NaN, 'FaceColor', [0.85 0.85 0.85], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    hC1F = plot(axObj, NaN, NaN, 'Color', [0 0 0 0.8], 'LineStyle', '--', 'LineWidth', 1.2);
    hC1D = plot(axObj, NaN, NaN, 'Color', [0.85 0.33 0.1 0.8], 'LineStyle', '--', 'LineWidth', 1.2);
    
    legend(axObj, [hTol, hC1F, hC1D], ...
        {'Tolerance Interval', 'C1 Nat. Freq.', 'C1 Deck Modes'}, ...
        'Location', 'northeast', 'Interpreter', 'latex', 'FontSize', 11);
end

function applyDateColorbar(axObj, chunkMidTimes)
    % applyDateColorbar Explicitly targets the axis to prevent the colorbar from disappearing.
    figHandle = ancestor(axObj, 'figure');
    colormap(figHandle, parula(length(chunkMidTimes)));
    
    cbHandle = colorbar(axObj);
    cbHandle.Layout.Tile = 'east';
    cbHandle.Label.String = 'Time';
    cbHandle.Label.Interpreter = 'latex';
    cbHandle.TickLabelInterpreter = 'latex';
    
    numTicks = min(length(chunkMidTimes), 8);
    tickIndices = round(linspace(1, length(chunkMidTimes), numTicks));
    tickValues = chunkMidTimes(tickIndices);
    
    cbHandle.Ticks = tickValues;
    
    if max(tickValues) < 693960 
        cbHandle.TickLabels = string(tickValues);
    else
        timeSpan = max(tickValues) - min(tickValues);
        if timeSpan <= 5
            dateFmt = 'dd-MMM HH:mm';
        elseif timeSpan <= 90
            dateFmt = 'dd-MMM-yyyy';
        else
            dateFmt = 'MMM-yyyy';
        end
        tickDates = datetime(tickValues, 'ConvertFrom', 'datenum');
        cbHandle.TickLabels = string(tickDates, dateFmt);
    end
end
function plotSpectralShiftHistogram(allStats, options)
    % plotSpectralShiftHistogram creates a 3D histogram of environmental critical peaks by quarter year.
    %
    % Environmental peaks are grouped by quarter (Q1-Q4) and displayed as stacked 2D histograms
    % on the z-axis, showing the distribution of peak frequencies over different quarters.
    arguments
        allStats table
        options.targetSensors string = ["Conc_Z", "Steel_Z"]
        options.envFlagField string = 'flag_PSDTotal_inGmm'
        options.specFlagField string = 'flag_PSDTotalAnd4Hz'
        options.figureFolder string = ""
        options.numBins double = 50
    end

    figHandle = createFigure(9, 'SpectralShift Histogram');
    
    [peakTimes, peakFreqs, ~, ~, ~, ~, rainValues] = extractSensorPeaks(allStats, options.targetSensors(1), options.specFlagField, options.envFlagField);
    
    if ismember(options.envFlagField, allStats.Properties.VariableNames)
        envFlagArray = table2array(allStats(:, options.envFlagField));
    else
        envFlagArray = false(height(allStats), 1);
    end
    if ismember('RainIntensity', allStats.Properties.VariableNames)
        rainArray = table2array(allStats(:, 'RainIntensity'));
    else
        rainArray = zeros(height(allStats), 1);
    end
    isEnvCritical = envFlagArray & [rainArray.mean]' > 0;
    envPeakTimes = allStats.duration(isEnvCritical, :);
    envPeakTimes = mean(envPeakTimes, 2);
    
    envPeakFreqs = [];
    envQuarterLabels = {};
    envQuarterIdx = [];
    
    for i = 1:height(allStats)
        if isEnvCritical(i)
            sensor = options.targetSensors(1);
            locations = allStats.psdPeaks(i).(sensor).locations(:);
            if ~isempty(locations)
                envPeakFreqs = [envPeakFreqs; locations];
                qLabel = getQuarterLabel(allStats.duration(i, 1));
                envQuarterLabels{end+1} = qLabel;
                envQuarterIdx(end+1) = getQuarterIdx(allStats.duration(i, 1));
            end
        end
    end
    
    uniqueQuarters = unique(envQuarterIdx);
    nQuarters = length(uniqueQuarters);
    quarterNames = arrayfun(@(q) sprintf('Q%d', mod(q-1, 4)+1), uniqueQuarters, 'UniformOutput', false);
    quarterColors = lines(nQuarters);
    
    freqRange = [min(envPeakFreqs) max(envPeakFreqs)];
    
    for qIdx = 1:nQuarters
        quarterNum = uniqueQuarters(qIdx);
        mask = envQuarterIdx == quarterNum;
        freqData = envPeakFreqs(mask);
        
        if ~isempty(freqData) && length(freqData) > 1
            binEdges = linspace(freqRange(1), freqRange(2), options.numBins+1);
            n = histc(freqData, binEdges);
            n = n(1:end-1);  % Remove the last element (overflow bin)
            n = n(:);
            
            binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
            barWidth = binCenters(2) - binCenters(1);
            
            verts = [];
            faces = [];
            vertOffset = 0;
            
            for b = 1:length(n)
                if n(b) > 0
                    x1 = binCenters(b) - barWidth/2;
                    x2 = binCenters(b) + barWidth/2;
                    y0 = 0;
                    y1 = n(b);
                    z0 = qIdx - 1;
                    z1 = qIdx;
                    
                    v = [x1 y0 z0; x2 y0 z0; x2 y1 z0; x1 y1 z0; x1 y0 z1; x2 y0 z1; x2 y1 z1; x1 y1 z1];
                    f = [1 2 3 4] + vertOffset;  % bottom
                    f = [f; 5 6 7 8 + vertOffset];  % top
                    f = [f; 1 2 6 5 + vertOffset];  % front
                    f = [f; 3 4 8 7 + vertOffset];  % back
                    f = [f; 1 4 8 5 + vertOffset];  % left
                    f = [f; 2 3 7 6 + vertOffset];  % right
                    
                    verts = [verts; v];
                    faces = [faces; f];
                    vertOffset = vertOffset + 8;
                end
            end
            
            if ~isempty(verts)
                patch('Vertices', verts, 'Faces', faces, 'FaceColor', quarterColors(qIdx, :), 'FaceAlpha', 0.7, 'EdgeColor', 'none');
            end
        end
        hold on;
    end
    
    view(3);
    grid on;
    xlabel('Frequency (Hz)', 'Interpreter', 'latex');
    ylabel('Count', 'Interpreter', 'latex');
    zlabel('Quarter', 'Interpreter', 'latex');
    zticks(1:nQuarters);
    zticklabels(quarterNames);
    title('Environmental Critical Peaks by Quarter', 'Interpreter', 'latex');
    set(gca, 'TickLabelInterpreter', 'latex');
    legend(quarterNames, 'Location', 'northoutside', 'Interpreter', 'latex');
    
    if strlength(options.figureFolder) > 0
        saveName = 'SpectralShiftHistogram_EnvironmentalPeaks';
        saveFig(figHandle, options.figureFolder, saveName, 2, 1);
    end
    
    function qLabel = getQuarterLabel(t)
        [y, m] = ymd(t);
        q = ceil(m / 3);
        qLabel = sprintf('%d-Q%d', y, q);
    end
    
    function qIdx = getQuarterIdx(t)
        [y, m] = ymd(t);
        q = ceil(m / 3);
        qIdx = (y - year(allStats.duration(1, 1))) * 4 + q;
    end
end

function [peakTimes, peakFreqs, peakIntensities, specFlags, envFlags, peakDurations, rainValues] = extractSensorPeaks(allStats, sensor, specFlagField, envFlagField)
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
    specFlagsArray = table2array(allStats(:, specFlagField));
    envFlagsArray = table2array(allStats(:, envFlagField));
    if ismember('RainIntensity', allStats.Properties.VariableNames)
        rainArray = table2array(allStats(:, 'RainIntensity'));
    else
        rainArray = zeros(height(allStats), 1);
    end

    peakTimes = repelem(eventTimes, numPeaksArray);
    specFlags = repelem(specFlagsArray, numPeaksArray);
    envFlags = repelem(envFlagsArray, numPeaksArray);
    peakDurations = repelem(allStats.duration, numPeaksArray, 1);
    rainValues = repelem(rainArray(:), numPeaksArray, 1);
end

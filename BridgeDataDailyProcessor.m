function allDailyResults = BridgeDataDailyProcessor(executionTime, option)
% BridgeDataDailyProcessor Processes bridge monitoring data for multiple days
%
% Description:
%   Processes bridge monitoring data to extract RWIV signatures. Supports
%   parallel processing for efficiency and optimized memory handling. Optionally
%   waits until a specified execution time before starting the data extraction.
%
% Inputs:
%   executionTime - datetime object specifying when to start processing (default: now)
%   option        - Struct with fields:
%                   .testCode (logical) - If true, runs a small subset of data for testing
%
% Outputs:
%   allDailyResults - Table containing processed daily statistics for all days
%
% Example:
%   results = BridgeDataDailyProcessor(datetime('now'), struct('testCode', true));
%
% Notes:
%   - Saves processed results to 'figures/BridgeDataProcessed/AnalysisResults_BridgeStats.mat'
%   - Uses parfor for parallel execution unless option.testCode is true
%   - Requires helper functions: waitForExecutionTime, BridgeProject, BridgeOverview, 
%     getDataConverageTable, sliceWeather, calculateSegmentStatistics, checkSpectralPeaks, 
%     checkCoherencePeaks, updateParallelProgress

arguments
    executionTime {mustBeA(executionTime, 'datetime')} = datetime('now')
    option.testCode {mustBeA(option.testCode, 'logical')} = false
    option.reRun {mustBeA(option.reRun, 'logical')} = false
    option.printProgress {mustBeA(option.printProgress, 'logical')} = true
    option.numWorkers {mustBeInteger} = feature('numcores')
end

waitForExecutionTime(executionTime);
addpath('functions');

dataRoot = 'Data';
segmentLength = minutes(10);
accelerometers = ["Conc_X","Steel_X","Conc_Y","Steel_Y","Conc_Z","Steel_Z"];

startDate = datetime(2018,1,1);
endDate = datetime(2026,1,1);

targetFreqs = [3.174, 6.32];
freqTolerance = 0.15;
targetCoherenceFreq = [3.22, 6.37];
coherenceLimit = [-0.6, 0.7];

dataCoverage = getDataConverageTable('noplot');
availableDays = dataCoverage.Date(dataCoverage.BridgeCoverage > 0);
targetDates = intersect(startDate:days(1):endDate, availableDays);

if option.reRun
    oldData = load('Data/coverageTable_old.mat');
    coverageOld = oldData.coverageTable;
    combined = innerjoin(dataCoverage, coverageOld, 'Keys', 'Date');
    changedIdx = combined.BridgeCoverage_dataCoverage ~= combined.BridgeCoverage_coverageOld;
    changedDates = combined.Date(changedIdx);
    newDates = setdiff(dataCoverage.Date(dataCoverage.BridgeCoverage > 0), coverageOld.Date);
    mustProcess = unique([changedDates; newDates]);
    targetDates = intersect(targetDates, mustProcess);
end

totalDays = numel(targetDates);
dailyResultsCell = cell(totalDays, 1);

startTime = tic;
progressQueue = parallel.pool.DataQueue();
afterEach(progressQueue, @(data) updateParallelProgress(totalDays, startTime));

if option.printProgress
    fprintf('Starting processing of %d days...\n', totalDays);
end

if option.testCode
    dayIndices = 1:min(5, totalDays);
    useParfor = false;
else
    dayIndices = 1:totalDays;
    useParfor = true;
end

processDay = @(dayIndex) processBridgeDay(dayIndex, targetDates, dataRoot, segmentLength, ...
    accelerometers, targetFreqs, freqTolerance, targetCoherenceFreq, coherenceLimit, ...
    progressQueue);

if useParfor
    createParallelPool(option.numWorkers);
    parfor i = 1:length(dayIndices)
        dailyResultsCell{i} = processDay(dayIndices(i));
    end
else
    for i = 1:length(dayIndices)
        dailyResultsCell{i} = processDay(dayIndices(i));
    end
end

if ~option.testCode
    allDailyResults = struct2table(vertcat(dailyResultsCell{:}));
    
    saveName = 'figures/BridgeDataProcessed/AnalysisResults_BridgeStats.mat';
    if option.reRun
        saveName = 'figures/BridgeDataProcessed/AnalysisResults_BridgeStats_Additional.mat';
    end
    save(saveName, 'allDailyResults', '-v7.3', '-nocompression');
end

end

function dailyResultsCell = processBridgeDay(dayIndex, targetDates, dataRoot, segmentLength, ...
    accelerometers, targetFreqs, freqTolerance, targetCoherenceFreq, coherenceLimit, ...
    progressQueue)
% processBridgeDay Processes bridge monitoring data for a single day
% Notes:
%   - Fills dailyResultsCell{dayIndex} with computed statistics
%   - Sends dayIndex to progressQueue after processing

currentDay = targetDates(dayIndex);
dayStart = currentDay;
dayEnd = currentDay + days(1) - seconds(1);

try
    project = BridgeProject(dataRoot, dayStart, dayEnd, loadCables=false);
    overview = BridgeOverview(project);
    overview = overview.fillMissingDataPoints();
    overview = overview.designFilter('butter', order=7, fLow=0.4, fHigh=15);
    overview = overview.applyFilter();

    bridgeDataFull = overview.project.bridgeData;
    weatherDataFull = overview.project.weatherData;
    timeSteps = dayStart:segmentLength:(dayEnd - segmentLength);
    numSegments = numel(timeSteps);
    dayStatsCell = cell(numSegments, 1);

    for t = 1:numSegments
        t0 = timeSteps(t);
        t1 = t0 + segmentLength;

        segmentData = bridgeDataFull(timerange(t0, t1), :);
        if isempty(segmentData) || height(segmentData) < 1000
            continue;
        end

        segmentWeatherData = sliceWeather(weatherDataFull, t0, t1);
        stats = calculateSegmentStatistics(segmentData, segmentWeatherData, t0, t1);

        fs = 1/seconds(median(diff(segmentData.Time)));
        [psdPeaks, psdFlags] = checkSpectralPeaks(segmentData, accelerometers, targetFreqs, freqTolerance, fs);
        [cohVals, coherenceFlag] = checkCoherencePeaks(segmentData, accelerometers, targetCoherenceFreq, coherenceLimit, fs);

        stats.isPotentialEvent = all(psdFlags.Conc_Z & psdFlags.Steel_Z & coherenceFlag.Z');
        stats.psdPeaks = psdPeaks;
        stats.cohVals = cohVals;

        dayStatsCell{t} = stats;
    end

    dailyResultsCell = vertcat(dayStatsCell{:});
    send(progressQueue, dayIndex);

catch
    dailyResultsCell = {};
    send(progressQueue, dayIndex);
end

end

    function updateParallelProgress(totalItems, startTime)
        % Callback function to calculate and display ETA based on multi-worker throughput.
        persistent completedCount
        if isempty(completedCount), completedCount = 0; end
        completedCount = completedCount + 1;

        elapsedSeconds = toc(startTime);
        % Calculate global processing rate (items per second) across all workers
        itemsPerSecond = completedCount / elapsedSeconds;
        remainingItems = totalItems - completedCount;
        remainingSeconds = remainingItems / itemsPerSecond;

        etaTime = datetime('now') + seconds(remainingSeconds);

        elapsedStr = string(duration(0, 0, elapsedSeconds, 'Format', 'hh:mm:ss'));
        remainStr = string(duration(0, 0, remainingSeconds, 'Format', 'hh:mm:ss'));

        fprintf('[%s] Progress: %d/%d (%.1f%%) | Elapsed: %s | Remaining: ~%s | ETA: %s\n', ...
            datestr(now, 'HH:MM:SS'), completedCount, totalItems, ...
            (completedCount/totalItems)*100, elapsedStr, remainStr, datestr(etaTime, 'HH:MM:SS'));
    end

    function stats = calculateSegmentStatistics(bridgeData, segmentWeather, t0, t1)
        % Extracts standard and directional statistics for a 10-minute segment.
        stats.duration = [t0,t1];
        accFields = ["Steel_Z","Conc_Z"];
        for field = accFields
            stats.(field) = calculateTimeHistoryStatistics(bridgeData.Time, bridgeData.(field), field);
        end

        weatherFields = string(fieldnames(segmentWeather));
        weatherFields(weatherFields == "Flag") = [];
        for field = weatherFields'
            stats.(field) = calculateTimeHistoryStatistics(segmentWeather.(field).Time, segmentWeather.(field).Data, field);
        end
    end

    function [foundPeaks, flags] = checkSpectralPeaks(data, fields, targets, tol, fs)
        % Evaluates spectral peaks and estimates damping via half-power bandwidth interpolation.
        order = 50;
        nfft = 2^15;

        for field = fields
            signal = double(data.(field));
            [psd, f] = pburg(signal, order, nfft, fs);
            logPsd = log(psd);

            relIdx = f >= 0.4 & f <= 10;
            [peaks, locs] = findpeaks(logPsd(relIdx), f(relIdx), 'MinPeakProminence', 4);

            numFound = numel(locs);
            dampingRatios = zeros(numFound, 1);
            for i = 1:numFound
                dampingRatios(i) = calculatePeakDamping(f, psd, locs(i));
            end

            foundPeaks.(field).locations = locs;
            foundPeaks.(field).logIntensity = peaks;
            foundPeaks.(field).dampingRatios = dampingRatios;
            flags.(field) = arrayfun(@(t) any(abs(locs - t) < tol), targets);
        end
    end

    function [coherenceVal, flags] = checkCoherencePeaks(data, accelerometer, freqTargets, coherenceLimits, fs)
        % Calculates co-coherence (real part of complex coherence) between sensors.
        nfft = 2^11;
        win = hanning(round(60*fs));
        overlap = round(30*fs);

        for j = 1:2:length(accelerometer)
            acc1 = accelerometer(j);
            acc2 = accelerometer(j+1);
            dir = extractAfter(acc1, '_');

            s1 = double(data.(acc1));
            s2 = double(data.(acc2));

            [pxy, f] = cpsd(s2, s1, win, overlap, nfft, fs);
            [pxx, ~] = pwelch(s2, win, overlap, nfft, fs);
            [pyy, ~] = pwelch(s1, win, overlap, nfft, fs);

            coCoherence = real(pxy ./ sqrt(pxx .* pyy));
            numFreqs = length(freqTargets);
            foundCoCoherence = zeros(numFreqs, 1);
            dirFlags = false(numFreqs, 1);

            for i = 1:numFreqs
                [~, idx] = min(abs(f - freqTargets(i)));
                val = coCoherence(idx);
                foundCoCoherence(i) = val;
                if coherenceLimits(i) > 0
                    dirFlags(i) = val > coherenceLimits(i);
                else
                    dirFlags(i) = val < coherenceLimits(i);
                end
            end

            flags.(dir) = dirFlags;
            coherenceVal.(dir) = foundCoCoherence;
        end
    end

    function device = calculateTimeHistoryStatistics(time, signal, field)
        % Computes standard statistics and stationarity metrics.
        if strcmp(field, 'Flag'); return; end

        if contains(field, 'WindSpeed') || strcmp(field, 'u') || strcmp(field, 'v')
            device.stationarityValue = calculateWindStationarityValue(time, signal);
            %signal = detrend(double(signal));
        end

        if contains(field, 'Dir') || contains(field, 'Phi')
            device = calculateCircularStatistics(signal);
        else
            device.mean = mean(signal, "all", "omitmissing");
        end

        if strcmp(field, 'RainIntensity'); return; end

        if ~isfield(device, 'median')
            device.median = median(signal, "omitmissing");
            device.std    = std(signal, [], "all", "omitmissing");
            device.max    = max(signal, [], 'omitmissing');
            device.min    = min(signal, [], 'omitmissing');
        end

        device.kurtosis = kurtosis(signal);
        device.skewness = skewness(signal);

        if strcmp(field, 'Steel_Z') || strcmp(field, 'Conc_Z')
            device.stationarityRatio = calculateStationarityRatio(time, signal);
        end
    end

    function stationarityValue = calculateWindStationarityValue(time, signal)
        % Evaluates wind stationarity by the max relative difference of 5-min local means. [cite: 995, 996]
        if isempty(time) || isempty(signal)
            stationarityValue = NaN;
            return;
        end

        globalMean = mean(signal, 'omitmissing');
        if globalMean == 0, stationarityValue = NaN; return; end

        fs = 1 / seconds(median(diff(time)));
        windowSize = round(300 * fs);
        instantaneousMeans = movmean(signal, windowSize, 'omitmissing');
        stationarityValue = max(abs(instantaneousMeans - globalMean) / globalMean);
    end

    function dampingRatio = calculatePeakDamping(f, psd, peakFreq)
        % Estimates damping using the half-power bandwidth method within local minima bounds

        [~, peakIndex] = min(abs(f - peakFreq));
        halfPowerLevel = psd(peakIndex) / 2;

        valleyIndices = find(islocalmin(psd));

        leftBoundaryIndex = max([1; valleyIndices(valleyIndices < peakIndex)]);
        rightBoundaryIndex = min([length(psd); valleyIndices(valleyIndices > peakIndex)]);

        lowerSlopePower = psd(leftBoundaryIndex:peakIndex);
        lowerSlopeFrequencies = f(leftBoundaryIndex:peakIndex);

        upperSlopePower = psd(peakIndex:rightBoundaryIndex);
        upperSlopeFrequencies = f(peakIndex:rightBoundaryIndex);

        if min(lowerSlopePower) > halfPowerLevel || min(upperSlopePower) > halfPowerLevel
            dampingRatio = NaN;
            return;
        end

        [uniqueLowerPower, uniqueLowerIndices] = unique(lowerSlopePower);
        uniqueLowerFrequencies = lowerSlopeFrequencies(uniqueLowerIndices);

        [uniqueUpperPower, uniqueUpperIndices] = unique(upperSlopePower);
        uniqueUpperFrequencies = upperSlopeFrequencies(uniqueUpperIndices);

        lowerHalfPowerFrequency = interp1(uniqueLowerPower, uniqueLowerFrequencies, halfPowerLevel);
        upperHalfPowerFrequency = interp1(uniqueUpperPower, uniqueUpperFrequencies, halfPowerLevel);

        dampingRatio = (upperHalfPowerFrequency - lowerHalfPowerFrequency) / (2 * peakFreq);
        if dampingRatio > 1
            warning('Found damping values higher than 1')
        end
    end

    function stationarityRatio = calculateStationarityRatio(time, signal)
        % Evaluates structural signal stationarity via local vs global standard deviation. [cite: 173]
        globalStd = std(signal, [], 'all', 'omitmissing');
        if isempty(time) || isempty(signal) || globalStd == 0
            stationarityRatio = NaN;
            return;
        end

        fs = 1 / seconds(median(diff(time)));
        samplesPerWindow = round(60 * fs);
        numWindows = floor(length(signal) / samplesPerWindow);

        if numWindows > 1
            localStds = zeros(numWindows, 1);
            for i = 1:numWindows
                idx = (i-1) * samplesPerWindow + 1 : i * samplesPerWindow;
                localStds(i) = std(signal(idx), [], 'all', 'omitmissing');
            end
            stationarityRatio = std(localStds) / globalStd;
        else
            stationarityRatio = 0;
        end
    end

    function device = calculateCircularStatistics(signal)
        % Handles vector averaging for wrapping angular fields.
        meanSin = mean(sind(signal), "omitmissing");
        meanCos = mean(cosd(signal), "omitmissing");

        device.mean = atan2d(meanSin, meanCos);
        if device.mean < 0, device.mean = device.mean + 360; end

        resultantLength = sqrt(meanSin^2 + meanCos^2);
        device.std = rad2deg(sqrt(-2 * log(resultantLength)));
        device.median = median(signal, "omitmissing");
        device.max = max(signal, [], 'omitmissing');
        device.min = min(signal, [], 'omitmissing');
    end

    function segmentedWeather = sliceWeather(fullWeather, t0, t1)
        % Slices weather timetable fields based on the provided time window.
        segmentedWeather = struct();
        fields = fieldnames(fullWeather);
        for i = 1:numel(fields)
            fieldName = fields{i};
            current = fullWeather.(fieldName);
            if isstruct(current) && isfield(current, 'Time')
                mask = current.Time >= t0 & current.Time < t1;
                segmentedWeather.(fieldName).Time = current.Time(mask);
                segmentedWeather.(fieldName).Data = current.Data(mask);
                if isfield(current, 'Unit'), segmentedWeather.(fieldName).Unit = current.Unit; end
            else
                segmentedWeather.(fieldName) = current;
            end
        end
    end

    function waitForExecutionTime(targetTime)
        % Halts execution until the specified target datetime is reached

        timeToWait = targetTime - datetime('now');
        delayInSeconds = seconds(timeToWait);

        if delayInSeconds > 0
            fprintf('Execution paused. Processing will begin at: %s\n', datestr(targetTime, 'yyyy-mm-dd HH:MM:SS'));
            pause(delayInSeconds);
        end
    end
%% Bridge Data Daily Processor
% This script processes daily bridge data to identify potential Rain-Wind Induced Vibration (RWIV) 
% events by analyzing bridge deck spectral peaks and deck-to-deck co-coherence.
clear all; clc;
addpath('functions');
% Configuration
dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';
segmentLength = minutes(10);
accelerometers = ["Conc_Z","Steel_Z"];

% Inspected period
startDate   = datetime(2018,1,1);
endDate     = datetime(2030,1,1);

% Data selection parameters
targetFreqs             = [3.174, 6.32]; % Found centers of deck peaks at RWIV
freqTolerance           = 0.15;          % Tolerance in Hz
targetCoherenceFreq     = [3.22, 6.37];  % Found centers of co-coherence peaks at RWIV
coherenceLimit          = [-0.6,0.7];    % coCoherence value that is the lower limits for flagging

%% Main Loop
targetDates = startDate:days(1):endDate; 
dataCoverage = getDataConverageTable('noplot');
availableDays = dataCoverage.Date(dataCoverage.BridgeCoverage > 0);
targetDates = intersect(targetDates, availableDays);
allDailyResults = struct();
totalDays = numel(targetDates);
overallTic = tic;

for i = 1:totalDays
    dayTic = tic;
    currentDay = targetDates(i);
    startTime = currentDay;
    endTime = currentDay + days(1) - seconds(1);
    
    % 1. Load data (Assuming BridgeProject updated for loadCables flag)
    try
        project = BridgeProject(dataRoot, startTime, endTime,loadCables=false);
    catch
        fprintf('Skipping %s: Data not found.\n', datestr(currentDay));
        continue;
    end
    
    % 2. Pre-processing
    overview = BridgeOverview(project);
    overview = overview.fillMissingDataPoints();
    overview = overview.designFilter('butter', order=7, fLow=0.4, fHigh=15); 
    overview = overview.applyFilter();
    
    % 3. Segmentation Loop
    timeSteps = startTime : segmentLength : (endTime - segmentLength);
    dayStats = [];
    weatherDataFull = overview.project.weatherData;
    numSegments = numel(timeSteps);
    segmentTime = zeros(numSegments,1); 
    segmentTime(:) = NaN;
    
    for t = 1:numSegments
        try
            segmentTic = tic;
            t0 = timeSteps(t);
            t1 = t0 + segmentLength;
            
            % Slice segment
            segmentData = overview.project.bridgeData(timerange(t0, t1), :);
            segmentWeatherData = sliceWeather(weatherDataFull, t0, t1);
            
            if isempty(segmentData) || height(segmentData) < 1000, continue; end
            
            % 4. Statistics
            stats = calculateSegmentStatistics(segmentData, segmentWeatherData, t0, t1);
            
            % 5 & 6. Spectral and Coherence Analysis
            bridgeSamplingFrequency = 1/seconds(median(diff(segmentData.Time)));
            [psdPeaks,psdFlags] = checkSpectralPeaks(segmentData, accelerometers, targetFreqs, freqTolerance, bridgeSamplingFrequency);
            [cohVals, coherenceFlag] = checkCoherencePeaks(segmentData, targetCoherenceFreq, coherenceLimit, bridgeSamplingFrequency);
            
            % 7. Final Flag and Storage
            stats.isPotentialEvent = all(psdFlags.Conc_Z & psdFlags.Steel_Z & coherenceFlag');
            stats.psdPeaks = psdPeaks;
            stats.cohVals = cohVals;
            
            dayStats = [dayStats; stats];
            
            segmentTime(i) = toc(segmentTic);
            avgSegmentTime = mean(segmentTime,'omitmissing');
            segmentsRemaining = numSegments - t;
            estDayRemaining = (segmentsRemaining * avgSegmentTime);
            fprintf('  Segment %d/%d processed in %.2f s. Est. day time left: %.1f seconds\n', t, numSegments, segmentTime(i), estDayRemaining);
        catch ME
            fprintf('Error processing segment at %s: %s\n', datestr(t0,'yyyy-mm-dd HH:MM:SS'), ME.message);
            continue;
        end
    end
    
    allDailyResults.(['Day_' datestr(currentDay, 'yyyymmdd')]) = dayStats;
    
    dayTime = toc(dayTic);
    daysRemaining = totalDays - i;
    avgDayTime = toc(overallTic) / i;
    estTotalRemaining = (daysRemaining * avgDayTime) / 3600;
    
    fprintf('Processed %s in %.2f min. Est. days left: %d (%.1f hours remaining)\n', datestr(currentDay), dayTime/60, daysRemaining, estTotalRemaining);
    
    if mod(i, 50) == 0
        save('BridgeDataProcessed/AnalysisResults_Checkpoint.mat', 'allDailyResults');
    end
end
save('figures/BridgeDataProcessed/AnalysisResults_BridgeStats.mat', 'allDailyResults');

%% Helper functions

function stats = calculateSegmentStatistics(bridgeData, segmentWeather, t0, t1)
    stats.duration = [t0,t1];

    % Extracts bridge acc statistics
    fields = ["Steel_Z","Conc_Z"];
    for field = fields
        stats.(field) = calculateTimeHistoryStatistics(bridgeData.Time,bridgeData.(field),accelerationStatistics=true);
    end
        
    % Extract mean values from the segmented weather struct
    fields = string(fieldnames(segmentWeather));
    for field = fields'
        signal = segmentWeather.(field).Data;
        time   = segmentWeather.(field).Time;

        if length(signal) > 1 & ~strcmpi('Flag',field)
            stats.(field) = calculateTimeHistoryStatistics(time,signal);
        elseif strcmpi('Flag',field)
            continue
        else
            stats.(field) = calculateTimeHistoryStatistics(time,signal,simpleStatistics=true);
        end
    end
end

function device = calculateTimeHistoryStatistics(time,signal,opts)
arguments
    time 
    signal 
    opts.simpleStatistics = false
    opts.accelerationStatistics = false
end

device.mean     = mean(signal,"all","omitmissing");

if opts.simpleStatistics
    return
end

device.median   = median(signal, "omitmissing");
device.std      = std(signal,[],"all","omitmissing");
device.max      = max(signal, [], 'omitmissing');
device.min      = min(signal, [], 'omitmissing');
device.kurtosis = kurtosis(signal);
device.skewness = skewness(signal);

if opts.accelerationStatistics
    device.stationarityRatio = calculateStationarityRatio(time, signal);
end
end

function stationarityRatio = calculateStationarityRatio(time, signal)
% Calculates the stationarity ratio of a signal by evaluating the variation of 1-minute local standard deviations relative to the global standard deviation.
% Reference: Bendat & Piersol (2010), "Random Data: Analysis and Measurement Procedures".
globalStandardDeviation = std(signal,[], 'all', 'omitmissing');

if isempty(time) || isempty(signal) || globalStandardDeviation == 0
    stationarityRatio = NaN;
    return;
end

timeStep = seconds(median(diff(time)));
samplingFrequency = 1 / timeStep;
samplesPerWindow = round(60 * samplingFrequency);
numberOfWindows = floor(length(signal) / samplesPerWindow);
if numberOfWindows > 1
    localStandardDeviations = zeros(numberOfWindows, 1);
    for i = 1:numberOfWindows
        windowIndex = (i-1) * samplesPerWindow + 1 : i * samplesPerWindow;
        localStandardDeviations(i) = std(signal(windowIndex),[],'all','omitmissing');
    end
    stationarityRatio = std(localStandardDeviations) / globalStandardDeviation;
else
    stationarityRatio = 0;
end
end

function segmentedWeather = sliceWeather(fullWeather, t0, t1)
    % Slices all weather fields containing a Time vector to the interval [t0, t1).
    segmentedWeather = struct();
    weatherFields = fieldnames(fullWeather);
    
    for i = 1:numel(weatherFields)
        fieldName = weatherFields{i};
        currentField = fullWeather.(fieldName);
        
        % Only slice if the field is a struct containing a Time vector
        if isstruct(currentField) && isfield(currentField, 'Time')
            timeMask = currentField.Time >= t0 & currentField.Time < t1;
            
            segmentedWeather.(fieldName).Time = currentField.Time(timeMask);
            segmentedWeather.(fieldName).Data = currentField.Data(timeMask);
            
            % Preserve Unit field if it exists
            if isfield(currentField, 'Unit')
                segmentedWeather.(fieldName).Unit = currentField.Unit;
            end
        else
            % Preserve fields without time (e.g., Flag or metadata)
            segmentedWeather.(fieldName) = currentField;
        end
    end
end

function [foundPeaks, flags] = checkSpectralPeaks(data, fields, targets, tol, fs)
    % Evaluates PSD peaks using the Burg method. 
    order = 50;
    nfft = 2^11;

    for field = fields
        [psd, f] = pburg(double(data.(field)), order, nfft, fs);
        logPsd = log(psd);
        
        % Find peaks within the 0.4-15Hz range
        relIdx = f >= 0.4 & f <= 10;
        [peaks, locs] = findpeaks(logPsd(relIdx), f(relIdx), 'MinPeakProminence', 4);
        
        foundPeaks.(field).locations = locs;
        foundPeaks.(field).logIntensity = peaks;
        flags.(field) = arrayfun(@(t) any(abs(locs - t) < tol), targets);
    end
end

function [foundCoCoherence, flags] = checkCoherencePeaks(data, freqTargets, coherenceLimits, fs)
    % Evaluates co-coherence peaks between deck sensors.
    nfft = 2^11;
    win = hanning(60*fs);
    overlap = 30*fs;

    [pxy, f] = cpsd(data.Steel_Z, data.Conc_Z, win, overlap, nfft, fs);
    [pxx, ~] = pwelch(data.Steel_Z, win, overlap, nfft, fs);
    [pyy, ~] = pwelch(data.Conc_Z, win, overlap, nfft, fs);
    
    % Real part of complex coherence
    coCoherence = real(pxy ./ sqrt(pxx .* pyy));
    
    foundCoCoherence = zeros(size(freqTargets,2),1);
    flags = zeros(size(freqTargets,2),1);

    for i = 1:length(freqTargets)
        [~,idx] = min(abs(f-freqTargets(i)));
      
        foundCoCoherence(i) = coCoherence(idx);
        if coherenceLimits(i) > 0
            flags(i) = foundCoCoherence(i) > coherenceLimits(i);
        else
            flags(i) = foundCoCoherence(i) < coherenceLimits(i);
        end
    end
end
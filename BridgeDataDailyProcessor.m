%% Bridge Data Daily Processor
% This script processes daily bridge data to identify potential Rain-Wind Induced Vibration (RWIV) 
% events by analyzing bridge deck spectral peaks and deck-to-deck co-coherence.
clear all; clc;
addpath('functions');
% Configuration
dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';
segmentLength = minutes(10);
accelerometers = ["Conc_X","Steel_X","Conc_Y","Steel_Y","Conc_Z","Steel_Z"];
reRunData = false;

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

if reRunData
    warning('Only looking at missing/changed dates!')
    oldData = load('Data/coverageData_old.mat');
    coverageOld = oldData.coverageTable;
    combined = innerjoin(dataCoverage, coverageOld, 'Keys', 'Date');
    changedIdx = combined.BridgeCoverage_dataCoverage ~= combined.BridgeCoverage_coverageOld;
    changedDates = combined.Date(changedIdx);
    newDates = setdiff(dataCoverage.Date(dataCoverage.BridgeCoverage > 0), coverageOld.Date);
    mustProcess = unique([changedDates; newDates]);
    targetDates = intersect(targetDates, mustProcess);
    fprintf('Found %d dates with changed coverage and %d brand new dates.\n', ...
            numel(changedDates), numel(newDates));
else
    availableDays = dataCoverage.Date(dataCoverage.BridgeCoverage > 0);
    targetDates = intersect(targetDates, availableDays);
end

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
        fprintf('Skipping %s: Data not found.\n', char(currentDay));
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
            [cohVals, coherenceFlag] = checkCoherencePeaks(segmentData, accelerometers, targetCoherenceFreq, coherenceLimit, bridgeSamplingFrequency);
            
            % 7. Final Flag and Storage
            stats.isPotentialEvent = all(psdFlags.Conc_Z & psdFlags.Steel_Z & coherenceFlag.Z');
            stats.psdPeaks = psdPeaks;
            stats.cohVals = cohVals;
            
            dayStats = [dayStats; stats];
            
            segmentTime(i) = toc(segmentTic);
            avgSegmentTime = mean(segmentTime,'omitmissing');
            segmentsRemaining = numSegments - t;
            estDayRemaining = (segmentsRemaining * avgSegmentTime);
            fprintf('  Segment %d/%d processed in %.2f s. Est. day time left: %.1f seconds\n', t, numSegments, segmentTime(i), estDayRemaining);
        catch ME
            fprintf('Error processing segment at %s: %s\n', char(t0,'uuuu-MM-dd HH:mm:SS'), ME.message);
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
        save('figures/BridgeDataProcessed/AnalysisResults_Checkpoint.mat', 'allDailyResults','-v7.3','-nocompression');
    end
end
allDailyResults = finalDataTransform(allDailyResults);
if ~reRunData
    save('figures/BridgeDataProcessed/AnalysisResults_BridgeStats.mat', 'allDailyResults','-v7.3','-nocompression');
else
    save('figures/BridgeDataProcessed/AnalysisResults_BridgeStats_Additional.mat', 'allDailyResults','-v7.3','-nocompression');
end
%% Helper functions
function allDailyResults = finalDataTransform(data)
    days = fieldnames(data);
    allDailyResults = [];
    transformTimer = tic;
    for d = 1:numel(days)
        allDailyResults = [allDailyResults; data.(days{d})];
        fprintf('Transformed day %d out of %d, total time: %.2f\n',d,numel(days),toc(transformTimer))
    end
    allDailyResults = struct2table(allDailyResults);
end

function stats = calculateSegmentStatistics(bridgeData, segmentWeather, t0, t1)
    stats.duration = [t0,t1];

    % Extracts bridge acc statistics
    fields = ["Steel_Z","Conc_Z"];
    for field = fields
        stats.(field) = calculateTimeHistoryStatistics(bridgeData.Time,bridgeData.(field),field);
    end
        
    % Extract mean values from the segmented weather struct
    fields = string(fieldnames(segmentWeather));fields(fields == "Flag") = [];
    for field = fields'
        signal = segmentWeather.(field).Data;
        time   = segmentWeather.(field).Time;
        
        stats.(field) = calculateTimeHistoryStatistics(time,signal,field); 
    end
end

function device = calculateTimeHistoryStatistics(time,signal,field)
%CALCULATETIMEHISTORYSTATISTICS Calculates statistical properties for bridge monitoring fields.
arguments
    time 
    signal 
    field {mustBeTextScalar}
end

if strcmp(field,'Flag');return;end

device.mean     = mean(signal,"all","omitmissing");

if contains(field, 'Dir') || contains(field, 'Phi')
    device = calculateCircularStatistics(signal);
else
    device.mean = mean(signal, "all", "omitmissing");
end

if strcmp(field,'RainIntensity');return;end

if ~isfield(device, 'median')
    device.median = median(signal, "omitmissing");
    device.std    = std(signal, [], "all", "omitmissing");
    device.max    = max(signal, [], 'omitmissing');
    device.min    = min(signal, [], 'omitmissing');
end

device.kurtosis = kurtosis(signal);
device.skewness = skewness(signal);

if strcmp(field,'Steel_Z') | strcmp(field,'Conc_Z')
    device.stationarityRatio = calculateStationarityRatio(time, signal);
end
end

function device = calculateCircularStatistics(signal)
%CALCULATECIRCULARSTATISTICS Handles wrapping for angular fields using vector averaging.
    
    sinSignal = sind(signal);
    cosSignal = cosd(signal);
    
    meanSin = mean(sinSignal, "omitmissing");
    meanCos = mean(cosSignal, "omitmissing");
    
    device.mean = atan2d(meanSin, meanCos);
    if device.mean < 0
        device.mean = device.mean + 360;
    end
    
    % Circular standard deviation
    resultantLength = sqrt(meanSin^2 + meanCos^2);
    device.std      = rad2deg(sqrt(-2 * log(resultantLength)));
    
    % Use linear stats for these as they are less meaningful for circles 
    % but kept for consistency with your device structure
    device.median = median(signal, "omitmissing");
    device.max    = max(signal, [], 'omitmissing');
    device.min    = min(signal, [], 'omitmissing');
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

function [coherenceVal, flags] = checkCoherencePeaks(data, accelerometer, freqTargets, coherenceLimits, fs)
    % Evaluates co-coherence peaks between deck sensors.
    nfft = 2^11;
    win = hanning(60*fs);
    overlap = 30*fs;
    nAccelerometers = length(accelerometer);
    
    for j = 1:2:nAccelerometers
        acc1 = accelerometer(j);
        acc2 = accelerometer(j+1);
        dir = extractAfter(acc1,'_');

        [pxy, f] = cpsd(data.(acc2), data.(acc1), win, overlap, nfft, fs);
        [pxx, ~] = pwelch(data.(acc2), win, overlap, nfft, fs);
        [pyy, ~] = pwelch(data.(acc1), win, overlap, nfft, fs);
        
        % Real part of complex coherence
        coCoherence = real(pxy ./ sqrt(pxx .* pyy));
        
        foundCoCoherence = zeros(size(freqTargets,2),1);
        dirFlags = zeros(size(freqTargets,2),1);
    
        for i = 1:length(freqTargets)
            [~,idx] = min(abs(f-freqTargets(i)));
          
            foundCoCoherence(i) = coCoherence(idx);
            if coherenceLimits(i) > 0
                dirFlags(i) = foundCoCoherence(i) > coherenceLimits(i);
            else
                dirFlags(i) = foundCoCoherence(i) < coherenceLimits(i);
            end
        end
        flags.(dir) = dirFlags;
        coherenceVal.(dir) = foundCoCoherence;
    end
end

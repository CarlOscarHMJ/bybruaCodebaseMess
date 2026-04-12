function results = DampingSensitivityTesting(startDate, endDate, options)
% DampingSensitivityTesting evaluates Burg damping sensitivity to nfft.
arguments
    startDate datetime
    endDate datetime
    options.dataRoot string = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data'
    options.sensorFields string = ["Conc_Z", "Steel_Z"]
    options.applyFilter logical = true
    options.filterType string = "butter"
    options.filterOrder (1,1) double {mustBeInteger, mustBePositive} = 7
    options.filterLowFreq (1,1) double {mustBePositive} = 0.4
    options.filterHighFreq (1,1) double {mustBePositive} = 15
    options.nffts (1,:) double {mustBeInteger, mustBePositive, iMustBePowerOfTwoVector} = 2.^(8:15)
    options.freqRange (1,2) double {mustBePositive} = [0.4, 10]
    options.burgOrder (1,1) double {mustBeInteger, mustBePositive} = 50
    options.minPeakProminence (1,1) double {mustBePositive} = 4
    options.clusterToleranceHz (1,1) double {mustBePositive} = 0.12
    options.printTimes logical = false
    options.timeRepeats (1,1) double {mustBeInteger, mustBePositive} = 7
    options.timeWarmupRuns (1,1) double {mustBeInteger, mustBeNonnegative} = 1
    options.plotResults logical = true
    options.plotTitle string = ""
    options.saveFigure logical = false
    options.figureFolder string = ""
    options.filePrefix string = "DampingSensitivity"
end

if endDate <= startDate
    error('endDate must be later than startDate.');
end

if options.freqRange(2) <= options.freqRange(1)
    error('freqRange must be [fLow, fHigh] with fHigh > fLow.');
end

overview = getBridgeData(startDate, endDate, ...
    dataRoot=options.dataRoot, ...
    applyFilter=options.applyFilter, ...
    filterType=options.filterType, ...
    filterOrder=options.filterOrder, ...
    filterLowFreq=options.filterLowFreq, ...
    filterHighFreq=options.filterHighFreq, ...
    plotFilter=false, ...
    plotTimeResponse=false);

bridgeData = overview.project.bridgeData;
availableFields = string(bridgeData.Properties.VariableNames);
validSensorMask = ismember(options.sensorFields, availableFields);
if ~all(validSensorMask)
    missingSensors = options.sensorFields(~validSensorMask);
    warning('Ignoring missing sensors: %s', strjoin(missingSensors, ', '));
end
sensors = options.sensorFields(validSensorMask);

if isempty(sensors)
    error('No valid sensors found in bridgeData for analysis.');
end

if height(bridgeData) < 1000
    error('Not enough bridge samples in selected interval to run sensitivity test.');
end

fs = 1 / seconds(median(diff(bridgeData.Time)));
if ~isfinite(fs) || fs <= 0
    error('Invalid sampling frequency inferred from bridgeData.Time.');
end

nfftCol = zeros(0, 1);
sensorCol = strings(0, 1);
peakFreqCol = zeros(0, 1);
peakLogIntensityCol = zeros(0, 1);
peakPowerCol = zeros(0, 1);
dampingCol = zeros(0, 1);
runtimeSecCol = zeros(0, 1);

timingNfft = zeros(0, 1);
timingMedianSec = zeros(0, 1);
timingMeanSec = zeros(0, 1);
timingStdSec = zeros(0, 1);
timingMinSec = zeros(0, 1);
timingMaxSec = zeros(0, 1);
timingRepeats = zeros(0, 1);
timingPeaks = zeros(0, 1);

nffts = unique(options.nffts(:), 'stable');

for iNfft = 1:numel(nffts)
    currentNfft = nffts(iNfft);
    for iWarmup = 1:options.timeWarmupRuns
        iAnalyzeSingleNfft(bridgeData, sensors, fs, currentNfft, options);
    end

    allTimings = zeros(options.timeRepeats, 1);
    cachedAnalysis = struct();
    for iRep = 1:options.timeRepeats
        tNfft = tic;
        currentAnalysis = iAnalyzeSingleNfft(bridgeData, sensors, fs, currentNfft, options);
        allTimings(iRep) = toc(tNfft);
        if iRep == 1
            cachedAnalysis = currentAnalysis;
        end
    end

    elapsedSec = median(allTimings, 'omitnan');
    nfftPeaks = cachedAnalysis.nfftPeaks;

    timingNfft = [timingNfft; currentNfft];
    timingMedianSec = [timingMedianSec; elapsedSec];
    timingMeanSec = [timingMeanSec; mean(allTimings, 'omitnan')];
    timingStdSec = [timingStdSec; std(allTimings, 'omitnan')];
    timingMinSec = [timingMinSec; min(allTimings)];
    timingMaxSec = [timingMaxSec; max(allTimings)];
    timingRepeats = [timingRepeats; options.timeRepeats];
    timingPeaks = [timingPeaks; nfftPeaks];

    if options.printTimes
        fprintf(['nfft=%d | median=%.3fs | mean=%.3fs | std=%.3fs ' ...
                 '| min=%.3fs | max=%.3fs | reps=%d | peaks=%d\n'], ...
            currentNfft, ...
            elapsedSec, ...
            mean(allTimings, 'omitnan'), ...
            std(allTimings, 'omitnan'), ...
            min(allTimings), ...
            max(allTimings), ...
            options.timeRepeats, ...
            nfftPeaks);
    end

    if isempty(cachedAnalysis.peakFreq)
        continue;
    end

    nRows = numel(cachedAnalysis.peakFreq);
    nfftCol = [nfftCol; repmat(currentNfft, nRows, 1)];
    sensorCol = [sensorCol; cachedAnalysis.sensor];
    peakFreqCol = [peakFreqCol; cachedAnalysis.peakFreq];
    peakLogIntensityCol = [peakLogIntensityCol; cachedAnalysis.peakLogIntensity];
    peakPowerCol = [peakPowerCol; cachedAnalysis.peakPower];
    dampingCol = [dampingCol; cachedAnalysis.damping];
    runtimeSecCol = [runtimeSecCol; repmat(elapsedSec, nRows, 1)];
end

rawPeaks = table(nfftCol, sensorCol, peakFreqCol, peakLogIntensityCol, peakPowerCol, dampingCol, runtimeSecCol, ...
    'VariableNames', {'nfft', 'sensor', 'peakFreq', 'peakLogIntensity', 'peakPower', 'damping', 'runtimeSec'});

if isempty(rawPeaks)
    warning('No peaks were detected for the selected interval and options.');
end

rawPeaks.clusterId = zeros(height(rawPeaks), 1);
for iSensor = 1:numel(sensors)
    sensorMask = rawPeaks.sensor == sensors(iSensor);
    if ~any(sensorMask)
        continue;
    end
    rawPeaks.clusterId(sensorMask) = iAssignFrequencyClusters(rawPeaks.peakFreq(sensorMask), options.clusterToleranceHz);
end

clusterSummary = iBuildClusterSummary(rawPeaks);
perNfftSummary = iBuildPerNfftSummary(rawPeaks);
timingSummary = table(timingNfft, timingMedianSec, timingMeanSec, timingStdSec, timingMinSec, timingMaxSec, timingRepeats, timingPeaks, ...
    'VariableNames', {'nfft', 'runtimeMedianSec', 'runtimeMeanSec', 'runtimeStdSec', 'runtimeMinSec', 'runtimeMaxSec', 'timingRepeats', 'numPeaks'});

if options.plotResults && ~isempty(rawPeaks)
    iPlotSensitivity(rawPeaks, clusterSummary, sensors, options, startDate, endDate);
end

if options.printTimes && ~isempty(clusterSummary)
    unstable = sortrows(clusterSummary, 'dampingCV', 'descend');
    nReport = min(6, height(unstable));
    fprintf('\nMost nfft-sensitive clusters (by damping CV):\n');
    for i = 1:nReport
        fprintf('  %s | cluster %d | f~%.3f Hz | CV=%.3f | range=%.4f | nfftCoverage=%d\n', ...
            unstable.sensor(i), unstable.clusterId(i), unstable.centerFreqHz(i), ...
            unstable.dampingCV(i), unstable.dampingRange(i), unstable.nfftCoverage(i));
    end
end

results = struct();
results.meta = struct( ...
    'startDate', startDate, ...
    'endDate', endDate, ...
    'samplingFrequency', fs, ...
    'options', options);
results.rawPeaks = rawPeaks;
results.perNfftSummary = perNfftSummary;
results.clusterSummary = clusterSummary;
results.timingSummary = timingSummary;
end

function analysis = iAnalyzeSingleNfft(bridgeData, sensors, fs, nfft, options)
nfftPeaks = 0;
tmpSensor = strings(0, 1);
tmpPeakFreq = zeros(0, 1);
tmpPeakLogIntensity = zeros(0, 1);
tmpPeakPower = zeros(0, 1);
tmpDamping = zeros(0, 1);

for iSensor = 1:numel(sensors)
    sensor = sensors(iSensor);
    signal = double(bridgeData.(sensor));

    [psd, f] = pburg(signal, options.burgOrder, nfft, fs);
    relMask = f >= options.freqRange(1) & f <= options.freqRange(2);
    logPsd = log(psd);

    [peaks, locs] = findpeaks(logPsd(relMask), f(relMask), ...
        'MinPeakProminence', options.minPeakProminence);

    if isempty(locs)
        continue;
    end

    nPeaks = numel(locs);
    nfftPeaks = nfftPeaks + nPeaks;

    localPeakPower = zeros(nPeaks, 1);
    localDamping = zeros(nPeaks, 1);
    for k = 1:nPeaks
        [~, peakIdx] = min(abs(f - locs(k)));
        localPeakPower(k) = psd(peakIdx);
        localDamping(k) = iCalculatePeakDamping(f, psd, locs(k));
    end

    tmpSensor = [tmpSensor; repmat(sensor, nPeaks, 1)];
    tmpPeakFreq = [tmpPeakFreq; locs(:)];
    tmpPeakLogIntensity = [tmpPeakLogIntensity; peaks(:)];
    tmpPeakPower = [tmpPeakPower; localPeakPower];
    tmpDamping = [tmpDamping; localDamping];
end

analysis = struct();
analysis.nfftPeaks = nfftPeaks;
analysis.sensor = tmpSensor;
analysis.peakFreq = tmpPeakFreq;
analysis.peakLogIntensity = tmpPeakLogIntensity;
analysis.peakPower = tmpPeakPower;
analysis.damping = tmpDamping;
end

function dampingRatio = iCalculatePeakDamping(f, psd, peakFreq)
[~, peakIndex] = min(abs(f - peakFreq));
halfPowerLevel = psd(peakIndex) / 2;

valleyIndices = find(islocalmin(psd));
leftBoundaryIndex = max([1; valleyIndices(valleyIndices < peakIndex)]);
rightBoundaryIndex = min([numel(psd); valleyIndices(valleyIndices > peakIndex)]);

lowerSlopePower = psd(leftBoundaryIndex:peakIndex);
lowerSlopeFrequencies = f(leftBoundaryIndex:peakIndex);
upperSlopePower = psd(peakIndex:rightBoundaryIndex);
upperSlopeFrequencies = f(peakIndex:rightBoundaryIndex);

if min(lowerSlopePower) > halfPowerLevel || min(upperSlopePower) > halfPowerLevel
    dampingRatio = NaN;
    return;
end

[uniqueLowerPower, uniqueLowerIdx] = unique(lowerSlopePower);
uniqueLowerFreq = lowerSlopeFrequencies(uniqueLowerIdx);
[uniqueUpperPower, uniqueUpperIdx] = unique(upperSlopePower);
uniqueUpperFreq = upperSlopeFrequencies(uniqueUpperIdx);

lowerHalfPowerFrequency = interp1(uniqueLowerPower, uniqueLowerFreq, halfPowerLevel);
upperHalfPowerFrequency = interp1(uniqueUpperPower, uniqueUpperFreq, halfPowerLevel);

dampingRatio = (upperHalfPowerFrequency - lowerHalfPowerFrequency) / (2 * peakFreq);
if dampingRatio > 1
    warning('Found damping values higher than 1');
end
end

function clusterId = iAssignFrequencyClusters(frequencies, toleranceHz)
clusterId = zeros(size(frequencies));
if isempty(frequencies)
    return;
end

[sortedFreq, sortIdx] = sort(frequencies, 'ascend');
sortedCluster = zeros(size(sortedFreq));
sortedCluster(1) = 1;

for i = 2:numel(sortedFreq)
    if abs(sortedFreq(i) - sortedFreq(i - 1)) <= toleranceHz
        sortedCluster(i) = sortedCluster(i - 1);
    else
        sortedCluster(i) = sortedCluster(i - 1) + 1;
    end
end

clusterId(sortIdx) = sortedCluster;
end

function clusterSummary = iBuildClusterSummary(rawPeaks)
clusterSummary = table();
if isempty(rawPeaks)
    return;
end

sensors = unique(rawPeaks.sensor, 'stable');
for iSensor = 1:numel(sensors)
    sensor = sensors(iSensor);
    sensorMask = rawPeaks.sensor == sensor;
    sensorData = rawPeaks(sensorMask, :);
    if isempty(sensorData)
        continue;
    end

    clusterIds = unique(sensorData.clusterId, 'stable');
    for iCluster = 1:numel(clusterIds)
        cId = clusterIds(iCluster);
        clusterData = sensorData(sensorData.clusterId == cId, :);

        uniqNfft = unique(clusterData.nfft, 'stable');
        dampingPerNfft = NaN(numel(uniqNfft), 1);
        for iNfft = 1:numel(uniqNfft)
            idxNfft = clusterData.nfft == uniqNfft(iNfft);
            d = clusterData.damping(idxNfft);
            d = d(isfinite(d) & d > 0);
            if ~isempty(d)
                dampingPerNfft(iNfft) = mean(d, 'omitnan');
            end
        end

        validDamping = dampingPerNfft(isfinite(dampingPerNfft) & dampingPerNfft > 0);
        if isempty(validDamping)
            dampingMean = NaN;
            dampingStd = NaN;
            dampingRange = NaN;
            dampingCV = NaN;
        else
            dampingMean = mean(validDamping, 'omitnan');
            dampingStd = std(validDamping, 'omitnan');
            dampingRange = max(validDamping) - min(validDamping);
            dampingCV = dampingStd / dampingMean;
        end

        newRow = table(sensor, cId, median(clusterData.peakFreq, 'omitnan'), ...
            numel(uniqNfft), height(clusterData), dampingMean, dampingStd, dampingRange, dampingCV, ...
            'VariableNames', {'sensor', 'clusterId', 'centerFreqHz', 'nfftCoverage', 'numPeaks', ...
            'dampingMean', 'dampingStd', 'dampingRange', 'dampingCV'});
        clusterSummary = [clusterSummary; newRow];
    end
end
end

function perNfftSummary = iBuildPerNfftSummary(rawPeaks)
perNfftSummary = table();
if isempty(rawPeaks)
    return;
end

sensors = unique(rawPeaks.sensor, 'stable');
nffts = unique(rawPeaks.nfft, 'stable');

for iSensor = 1:numel(sensors)
    sensor = sensors(iSensor);
    for iNfft = 1:numel(nffts)
        nfft = nffts(iNfft);
        mask = rawPeaks.sensor == sensor & rawPeaks.nfft == nfft;
        block = rawPeaks(mask, :);
        if isempty(block)
            continue;
        end

        d = block.damping;
        d = d(isfinite(d) & d > 0);
        if isempty(d)
            meanDamping = NaN;
            stdDamping = NaN;
        else
            meanDamping = mean(d, 'omitnan');
            stdDamping = std(d, 'omitnan');
        end

        newRow = table(sensor, nfft, height(block), meanDamping, stdDamping, ...
            mean(block.runtimeSec, 'omitnan'), median(block.runtimeSec, 'omitnan'), ...
            'VariableNames', {'sensor', 'nfft', 'numPeaks', 'meanDamping', 'stdDamping', 'runtimeMeanSec', 'runtimeMedianSec'});
        perNfftSummary = [perNfftSummary; newRow];
    end
end
end

function iPlotSensitivity(rawPeaks, clusterSummary, sensors, options, startDate, endDate)
if strlength(options.plotTitle) == 0
    titleText = sprintf('Damping sensitivity to nfft (%s to %s)', ...
        datestr(startDate, 'dd-mmm-yyyy HH:MM'), ...
        datestr(endDate, 'dd-mmm-yyyy HH:MM'));
else
    titleText = char(options.plotTitle);
end

figAllPeaks = createFigure(141, 'Damping Sensitivity - All Peaks');
set(figAllPeaks, 'Color', 'w');
t = tiledlayout(numel(sensors), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for iSensor = 1:numel(sensors)
    ax = nexttile;
    sMask = rawPeaks.sensor == sensors(iSensor);
    sData = rawPeaks(sMask, :);
    if isempty(sData)
        text(ax, 0.5, 0.5, 'No peaks detected', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center');
        title(ax, char(sensors(iSensor)));
        continue;
    end

    cVals = log2(sData.nfft);
    scatter(ax, sData.peakFreq, sData.damping, 22, cVals, 'filled', ...
        'MarkerFaceAlpha', 0.75, 'MarkerEdgeAlpha', 0.25);
    grid(ax, 'on');
    ylabel(ax, 'Damping ratio');
    title(ax, char(sensors(iSensor)));
    xlim(ax, options.freqRange);
end
xlabel(t, 'Frequency (Hz)');
cb = colorbar;
cb.Layout.Tile = 'east';
cb.Label.String = 'log2(nfft)';
title(t, titleText);

iMaybeSaveFigure(figAllPeaks, options.figureFolder, options.filePrefix + "_AllPeaks", options.saveFigure);

if isempty(clusterSummary)
    return;
end

figCluster = createFigure(142, 'Damping Sensitivity - Cluster Summary');
set(figCluster, 'Color', 'w');
t2 = tiledlayout(numel(sensors), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for iSensor = 1:numel(sensors)
    ax = nexttile;
    sMask = clusterSummary.sensor == sensors(iSensor);
    sData = clusterSummary(sMask, :);
    if isempty(sData)
        text(ax, 0.5, 0.5, 'No clusters available', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center');
        title(ax, char(sensors(iSensor)));
        continue;
    end

    markerSize = 12 + 4 * sData.nfftCoverage;
    scatter(ax, sData.centerFreqHz, sData.dampingCV, markerSize, sData.nfftCoverage, ...
        'filled', 'MarkerFaceAlpha', 0.8);
    grid(ax, 'on');
    ylabel(ax, 'Damping CV');
    title(ax, char(sensors(iSensor)));
    xlim(ax, options.freqRange);
end
xlabel(t2, 'Cluster center frequency (Hz)');
cb2 = colorbar;
cb2.Layout.Tile = 'east';
cb2.Label.String = 'nfft coverage';
title(t2, 'Cluster-level nfft sensitivity');

iMaybeSaveFigure(figCluster, options.figureFolder, options.filePrefix + "_ClusterSummary", options.saveFigure);
end

function iMaybeSaveFigure(figHandle, figureFolder, fileName, saveFigure)
if ~saveFigure
    return;
end

if strlength(figureFolder) == 0
    warning('saveFigure=true but no figureFolder was given. Skipping save for %s.', fileName);
    return;
end

if ~isfolder(figureFolder)
    mkdir(figureFolder);
end

saveFig(figHandle, figureFolder, fileName, 2, 1, [], scaleFigure=false);
end

function iMustBePowerOfTwoVector(values)
if any(mod(log2(values), 1) ~= 0)
    error('All nffts must be powers of 2 (e.g., 256, 1024, 2048).');
end
end

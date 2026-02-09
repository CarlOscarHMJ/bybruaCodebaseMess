function coverageTable = dataCoverage(dataRoot, startDate, endDate, saveMatFile)
%dataCoverage Estimate and visualize daily measurement coverage for bridge and cable data.
arguments
    dataRoot {mustBeTextScalar,mustBeFolder} = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data'
    startDate = '2019-01-01'
    endDate = '2025-11-30'
    saveMatFile {mustBeNumericOrLogical} = true
end

if isstring(startDate) || ischar(startDate)
    startDate = datetime(startDate, 'InputFormat', 'yyyy-MM-dd');
end
if isstring(endDate) || ischar(endDate)
    endDate = datetime(endDate, 'InputFormat', 'yyyy-MM-dd');
end
if endDate < startDate
    error("endDate must be >= startDate.")
end

allDays = (startDate:days(1):endDate).';

bridgeCoverage = computeBridgeCoverage(dataRoot, allDays);
cableCoverage = computeCableCoverage(dataRoot, allDays);

coverageTable = table(allDays, bridgeCoverage, cableCoverage);
coverageTable.Properties.VariableNames = ["Date", "BridgeCoverage", "CableCoverage"];

plotCoverage(coverageTable);

if saveMatFile
    save(fullfile(dataRoot, 'coverageData.mat'), 'coverageTable');
end
end

function bridgeCoverage = computeBridgeCoverage(dataRoot, allDays)
%computeBridgeCoverage Scans for bridge files (ignoring WSDA) and provides time-left estimates.
bridgeCoverage = zeros(size(allDays));
allFiles = dir(fullfile(dataRoot, '**', '*-*-*.mat'));

% FILTER We look for files in: /YYYY/MM/YYYY-MM-DD.mat
fullPaths = fullfile({allFiles.folder}, {allFiles.name});
pattern = '[\\/]\d{4}[\\/]\d{2}[\\/]\d{4}-\d{2}-\d{2}\.mat$';
keepIdx = ~cellfun(@isempty, regexp(fullPaths, pattern));
fileList = allFiles(keepIdx);

nFilesTotal = numel(fileList);
startTime = tic;
for k = 1:nFilesTotal
    fileName = fileList(k).name;
    if isempty(regexp(fileName, '^\d{4}-\d{2}-\d{2}\.mat$', 'once')), continue; end
    
    currentDate = datetime(fileName(1:10), 'InputFormat', 'yyyy-MM-dd');

    matPath = fullfile(fileList(k).folder,fileName);
    coverage = calculateBridgeFileCoverage(matPath, currentDate);
    dayIdx = find(currentDate == allDays);
    bridgeCoverage(dayIdx) = coverage;
    
    if mod(k, 5) == 0 || k == nFilesTotal
        elapsed = toc(startTime);
        avgTime = elapsed / k;
        estRemaining = (nFilesTotal - k) * avgTime;
        fprintf('Bridge Progress: %d/%d files. Estimated remaining: %.1f minutes.\n', k, nFilesTotal, estRemaining/60);
    end
end

% 
% validFileIdx = false(nFilesTotal, 1);
% fileDate = datetime.empty(0, 1);
% 
% for k = 1:nFilesTotal
%     fileName = fileList(k).name;
%     % Ensure filename is exactly YYYY-MM-DD.mat and does not contain WSDA
%     if isempty(regexp(fileName, '^\d{4}-\d{2}-\d{2}\.mat$', 'once')), continue; end
% 
%     currDate = datetime(fileName(1:10), 'InputFormat', 'yyyy-MM-dd');
%     if currDate >= allDays(1) && currDate <= allDays(end)
%         validFileIdx(k) = true;
%         fileDate(k) = currDate;
%     end
% end
% 
% relevantFiles = fileList(validFileIdx);
% relevantDates = fileDate(validFileIdx);
% nFiles = numel(relevantFiles);
% 
% fprintf('Starting bridge data processing (%d bridge files found)...\n', nFiles);
% startTime = tic;
% 
% for k = 1:nFiles
%     matPath = fullfile(relevantFiles(k).folder, relevantFiles(k).name);
%     dayIdx = find(allDays == relevantDates(k), 1);
% 
%     if ~isempty(dayIdx)
%         bridgeCoverage(dayIdx) = calculateBridgeFileCoverage(matPath, allDays(dayIdx));
%     end
%     %if k==189;keyboard;end
%     if mod(k, 5) == 0 || k == nFiles
%         elapsed = toc(startTime);
%         avgTime = elapsed / k;
%         estRemaining = (nFiles - k) * avgTime;
%         fprintf('Bridge Progress: %d/%d files. Estimated remaining: %.1f minutes.\n', k, nFiles, estRemaining/60);
%     end
% end
end

function coverage = calculateBridgeFileCoverage(matPath, thisDay)
%calculateBridgeFileCoverage Extracts time vectors from bridge files to estimate fractional day coverage.
s = load(matPath);
s = renameDailyData(s);
coverage = NaN;

if ~isfield(s,'DailyData') || ~isfield(s.DailyData,'Acc') || ~isfield(s.DailyData.Acc, "time")
    coverage = 0;
    return
end

try
    tStart = s.DailyData.Acc.time(1);
    tEnd = s.DailyData.Acc.time(end);
    coverage = (tEnd - tStart) / days(1);
catch ME
    fprintf('Cound not calculate Coverage for %s\n Error: %s\n',matPath,ME.message)
end
% coverage = 0;
% if isfield(s, "DailyData") && isstruct(s.DailyData) ...
%         && isfield(s.DailyData, "Acc") && isfield(s.DailyData.Acc, "time")
% 
%     timeVec = s.DailyData.Acc.time;
%     if isdatetime(timeVec) && numel(timeVec) > 1
%         dayStart = dateshift(thisDay, "start", "day");
% 
%         tDay = sort(timeVec(dateshift(timeVec, "start", "day") == dayStart));
% 
%         if numel(tDay) >= 2
%             dt = median(diff(tDay));
%             coverageSeconds = seconds(dt) * (numel(tDay) - 1);
%             coverage = min(max(coverageSeconds / (24 * 3600), 0), 1);
%         else
%             coverage = NaN;
%         end
%     else
%         coverage = NaN;
%     end
% else
%     coverage = NaN;
% end
end

function s = renameDailyData(s)
    % Normalizes any variation of dailyData to the consistent field name DailyData.

    fieldNames = fieldnames(s);
    matchIdx = find(strcmpi(fieldNames, "DailyData"), 1);

    if ~isempty(matchIdx) && ~strcmp(fieldNames{matchIdx}, "DailyData")
        s.DailyData = s.(fieldNames{matchIdx});
        s = rmfield(s, fieldNames{matchIdx});
    end
end

function cableCoverage = computeCableCoverage(dataRoot, allDays)
%computeCableCoverage Scans WSDA .mat files and provides time-left estimates.
nDays = numel(allDays);
secondsAccum = zeros(nDays, 1);
wsdaRoot = fullfile(dataRoot, "WSDA_data");

if ~isfolder(wsdaRoot)
    warning("WSDA_data folder not found: %s", wsdaRoot);
    cableCoverage = zeros(nDays, 1);
    return;
end

fileList = dir(fullfile(wsdaRoot, "**", "WSDA_*.mat"));
nFiles = numel(fileList);
fprintf('Starting cable data loading (%d files found)...\n', nFiles);
startTime = tic;

for k = 1:nFiles
    fileName = fileList(k).name;
    [tStart, tEnd] = parseCableFilename(fileName);

    if isnat(tStart) || isnat(tEnd), continue; end
    
    for i = 1:nDays
        dayStart = allDays(i);
        dayEnd = dayStart + days(1);
        overlapStart = max(tStart, dayStart);
        overlapEnd = min(tEnd, dayEnd);
        
        if overlapEnd > overlapStart
            secondsAccum(i) = secondsAccum(i) + seconds(overlapEnd - overlapStart);
        end
    end
    
    if mod(k, 5) == 0 || k == nFiles
        elapsed = toc(startTime);
        avgTime = elapsed / k;
        estRemaining = (nFiles - k) * avgTime;
        fprintf('Cable Progress: %d/%d files. Estimated remaining: %.1f seconds.\n', k, nFiles, estRemaining);
    end
end
cableCoverage = min(secondsAccum / (24 * 3600), 1);
end

function [tStart, tEnd] = parseCableFilename(fileName)
%parseCableFilename Extracts start and end datetimes from the WSDA filename format.
tStart = NaT; tEnd = NaT;
pattern = 'WSDA_(\d{4}-\d{2}-\d{2})_[ap]m_(\d{6})_to_(\d{6})';
tokens = regexp(fileName, pattern, 'tokens', 'once');
if ~isempty(tokens)
    datePart = tokens{1};
    tStart = datetime(datePart + " " + tokens{2}, 'InputFormat', 'yyyy-MM-dd HHmmss');
    tEnd = datetime(datePart + " " + tokens{3}, 'InputFormat', 'yyyy-MM-dd HHmmss');
end
end

function plotCoverage(coverageTable)
%plotCoverage Generates a two-panel visual summary of data availability.
fig = figure;
theme(fig, "light");
tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact")
nexttile
plot(coverageTable.Date, coverageTable.BridgeCoverage, "o")
ylabel("Bridge coverage")
ylim([0 1]); grid on
title(sprintf('Total bridge coverage %3.0f%%', mean(coverageTable.BridgeCoverage) * 100))
nexttile
plot(coverageTable.Date, coverageTable.CableCoverage, "o")
ylabel("Cable coverage")
xlabel("Date")
ylim([0 1]); grid on
title(sprintf('Total cable coverage %3.0f%%', mean(coverageTable.CableCoverage) * 100))
end
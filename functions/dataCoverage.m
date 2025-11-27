function coverageTable = dataCoverage(dataRoot,startDate,endDate,saveMatFile)
%dataCoverage Estimate and visualize daily measurement coverage
%   coverageTable = dataCoverage(dataRoot,startDate,endDate)
%
%   INPUTS:
%       dataRoot   - Root folder containing year folders and WSDA_data
%       startDate  - datetime scalar or string 'yyyy-MM-dd'
%       endDate    - datetime scalar or string 'yyyy-MM-dd'
%
%   OUTPUT:
%       coverageTable - table with columns:
%                       Date, BridgeCoverage, CableCoverage
%                       (coverage is fraction of day from 0 to 1)
%
%   The function scans bridge .mat files in year/month/YYYY-MM-DD.mat and
%   cable .csv files in WSDA_data/year/**/WSDA_*_YYYY-MM-DDT*.csv,
%   estimates the fraction of the day covered by data, and plots the
%   daily coverage for bridge and cable over the requested period.

if isstring(startDate) || ischar(startDate)
    startDate = datetime(startDate, 'InputFormat', 'yyyy-MM-dd');
end

if isstring(endDate) || ischar(endDate)
    endDate = datetime(endDate, 'InputFormat', 'yyyy-MM-dd');
end

if endDate < startDate
    error("endDate must be >= startDate.")
end

if ~exist('saveMatFile','var')
    saveMatFile = false;
end

%% Build day range
dayStart = dateshift(startDate,"start","day");
dayEnd   = dateshift(endDate,"start","day");
allDays  = (dayStart:caldays(1):dayEnd).';
nDays = numel(allDays);

%% Compute bridge coverage (day-by-day)
fprintf("Computing bridge coverage day-by-day...\n");
bridgeCoverage = nan(nDays,1);

for i = 1:nDays
    thisDay = allDays(i);
    fprintf("Bridge %3d/%3d  %s\n", ...
        i, nDays, datestr(thisDay,'yyyy-mm-dd'));

    bridgeCoverage(i) = dayCoverageBridge(dataRoot,thisDay);
end
bridgeCoverage(isnan(bridgeCoverage)) = 0;
%% Compute cable coverage (single-pass WSDA load)
fprintf("\nComputing cable coverage from WSDA files (single pass)...\n");
cableCoverage = computeCableCoverage(dataRoot,allDays);

%% Output table
coverageTable = table(allDays,bridgeCoverage,cableCoverage);
coverageTable.Properties.VariableNames = ["Date","BridgeCoverage","CableCoverage"];

%% Plot
fig=figure;
theme(fig,"light");
tiledlayout(2,1,"TileSpacing","compact","Padding","compact")

nexttile
plot(coverageTable.Date,coverageTable.BridgeCoverage,"o")
ylabel("Bridge coverage")
ylim([0 1]); grid on
TotalBridgeCoverage = sum(coverageTable.BridgeCoverage)/numel(coverageTable.BridgeCoverage);
title(sprintf('Total bridge coverage %3.0f%%',TotalBridgeCoverage*100))

nexttile
plot(coverageTable.Date,coverageTable.CableCoverage,"o")
ylabel("Cable coverage")
xlabel("Date")
ylim([0 1]); grid on
TotalCableCoverage = sum(coverageTable.CableCoverage)/numel(coverageTable.CableCoverage);
title(sprintf('Total cable coverage %3.0f%%',TotalCableCoverage*100))

%% Save
if saveMatFile
    save(fullfile(dataRoot, 'coverageData.mat'), 'coverageTable');
end
end


%% ------------------------------------------------------------------------
%                          BRIDGE FUNCTIONS
% -------------------------------------------------------------------------

function coverage = dayCoverageBridge(dataRoot,thisDay)
yearStr  = datestr(thisDay,"yyyy");
monthStr = datestr(thisDay,"mm");
fileName = datestr(thisDay,"yyyy-mm-dd");

matPath  = fullfile(dataRoot,yearStr,monthStr,fileName + ".mat");

if ~isfile(matPath)
    coverage = nan;
    return
end

timeVec = extractBridgeTimeVector(matPath);
coverage = coverageFromTimes(timeVec,thisDay);
end

function timeVec = extractBridgeTimeVector(matPath)
s = load(matPath);

timeVec = datetime.empty(0,1);

if ~isfield(s,"DailyData")
    return
end
dailyData = s.DailyData;
if ~isstruct(dailyData)
    return
end

if ~isfield(dailyData,"Acc")
    return
end
acc = dailyData.Acc;
if ~isstruct(acc)
    return
end

if ~isfield(acc,"time")
    return
end

t = acc.time;
if ~isdatetime(t)
    return
end

timeVec = t(:);
end



%% ------------------------------------------------------------------------
%                       CABLE COVERAGE (SINGLE PASS)
% -------------------------------------------------------------------------

function cableCoverage = computeCableCoverage(dataRoot,allDays)
nDays = numel(allDays);
cableCoverage = nan(nDays,1);
secondsPerDay = 24*60*60;

wsdaRoot = fullfile(dataRoot,"WSDA_data");
if ~isfolder(wsdaRoot)
    warning("WSDA_data folder not found: %s",wsdaRoot);
    return
end

years = unique(year(allDays));
periodStart = allDays(1);
periodEnd = allDays(end) + days(1); % end is exclusive
secondsAccum = zeros(nDays,1);

for yi = 1:numel(years)
    y = years(yi);
    yearDir = fullfile(wsdaRoot,sprintf("%04d",y));
    if ~isfolder(yearDir)
        continue
    end
    fprintf(" Year %4d: scanning WSDA files (fast span mode)...\n",y);

    fileList = dir(fullfile(yearDir,"**","WSDA_*.csv"));
    for k = 1:numel(fileList)
        fname = fileList(k).name;
        fpath = fullfile(fileList(k).folder,fname);
        fprintf(" [%4d/%4d] %s\n",k,numel(fileList),fname);

        [tStart, durationSeconds] = getCableFileSpan(fpath);
        if isnat(tStart) || durationSeconds <= 0
            continue
        end

        fileStart = tStart;
        fileEnd = tStart + seconds(durationSeconds);

        if fileEnd <= periodStart || fileStart >= periodEnd
            continue
        end

        spanStart = max(fileStart,periodStart);
        spanEnd = min(fileEnd,periodEnd);

        firstDay = dateshift(spanStart,"start","day");
        lastDay = dateshift(spanEnd - seconds(1e-3),"start","day");

        for d = firstDay:lastDay
            idx = find(allDays == d,1);
            if isempty(idx)
                continue
            end

            dayStart = d;
            dayEnd = d + days(1);

            overlapStart = max(spanStart,dayStart);
            overlapEnd = min(spanEnd,dayEnd);

            if overlapEnd > overlapStart
                secondsAccum(idx) = secondsAccum(idx) + seconds(overlapEnd - overlapStart);
            end
        end
    end
end

cableCoverage = secondsAccum ./ secondsPerDay;
cableCoverage = min(max(cableCoverage,0),1);
end


function [tStart,durationSeconds] = getCableFileSpan(csvPath)
tStart = NaT;
durationSeconds = 0;
fid = fopen(csvPath,"r");
if fid == -1
    return
end
lineIdx = 0;
fs = NaN;
dataHeaderLineIdx = [];
while true
    ln = fgetl(fid);
    if ~ischar(ln)
        break
    end
    lineIdx = lineIdx + 1;
    if contains(ln,"Channel Data") && isnan(fs)
        parts = strsplit(ln,",");
        if numel(parts) >= 3
            rateStr = strtrim(parts{3}); % e.g. '64Hz'
            numStr = regexp(rateStr,"[\d\.]+","match","once");
            fs = str2double(numStr);
        end
    end
    if strcmp(strtrim(ln),"DATA_START")
        headerLine = fgetl(fid); %#ok<NASGU>
        lineIdx = lineIdx + 1;
        firstDataLine = fgetl(fid);
        lineIdx = lineIdx + 1;
        dataHeaderLineIdx = lineIdx - 1;
        if ischar(firstDataLine)
            commaPos = find(firstDataLine == ',',1,'first');
            if ~isempty(commaPos)
                timeStr = strtrim(firstDataLine(1:commaPos-1));
                tStart = datetime(timeStr, ...
                    "InputFormat","MM/dd/yyyy HH:mm:ss.SSSSSSSSS");
            end
        end
        break
    end
end
fclose(fid);
if isnat(tStart)
    return
end
if isnan(fs) || fs <= 0
    fs = 64; % fallback if header parsing fails
end
[status,out] = system(sprintf('wc -l "%s"', csvPath));
if status ~= 0
    return
end
tokens = regexp(strtrim(out),"^(\d+)","tokens","once");
if isempty(tokens)
    return
end
totalLines = str2double(tokens{1});
if isnan(totalLines) || isempty(dataHeaderLineIdx)
    return
end
nSamples = totalLines - dataHeaderLineIdx;
if nSamples <= 1
    durationSeconds = 0;
    return
end
durationSeconds = (nSamples - 1) / fs;
end




%% ------------------------------------------------------------------------
%                              HELPERS
% -------------------------------------------------------------------------

function clampedCoverage = coverageFromTimes(timeVec,thisDay)
if isempty(timeVec)
    clampedCoverage = nan; return
end

dayStart = dateshift(thisDay,"start","day");
idx = dateshift(timeVec,"start","day") == dayStart;

tDay = timeVec(idx);
if numel(tDay) < 2
    clampedCoverage = nan; return
end

tDay = sort(tDay);
dt = median(diff(tDay));
if dt <= 0
    clampedCoverage = nan; return
end

daySeconds = 24*60*60;
coverageSeconds = seconds(dt) * (numel(tDay)-1);
clampedCoverage = min(max(coverageSeconds/daySeconds,0),1);
end


function timeVec = extractFirstDatetimeColumn(csvPath)
tbl = readtable(csvPath);
vars = tbl.Properties.VariableNames;
timeVec = datetime.empty(0,1);

for i = 1:numel(vars)
    col = tbl.(vars{i});
    if isdatetime(col)
        timeVec = col; return
    end
end
end

function dt = parseWsdaFilenameDatetime(fname)
tokens = regexp(fname, ...
    '_(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})', ...
    'tokens','once');
if isempty(tokens)
    dt = NaT; return
end

dtStr = sprintf('%s %s:%s:%s', ...
    tokens{1}, tokens{2}, tokens{3}, tokens{4});

dt = datetime(dtStr, "InputFormat","yyyy-MM-dd HH:mm:ss");
end



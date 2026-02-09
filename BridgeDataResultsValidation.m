clear all;clc
pause(3)

addpath('functions/')

load('figures/BridgeDataProcessed/potentialEvents.mat')
load('figures/BridgeDataProcessed/AnalysisResults_BridgeStats_RwivValidationCase.mat')
timeStamps = potentialEvents.duration;
[overlapIndices, bridgeCoverage] = findDataIntersection(timeStamps);
%%
plotDataAvailability(timeStamps, bridgeCoverage, overlapIndices,0)
plotDataLimitsWithinPeriod(allDailyResults,limits,...
                            datetime('2020-02-21 12:00'),...
                            datetime('2020-02-21 14:00'))

%% Plots
function plotDataAvailability(timeStamps, bridgeCoverage, overlapIndices, saveFlag)
    % Visualizes event availability and bridge data intersections on a 0-1 scale.

    fig = createFigure(1, 'Bybrua Project: Data Intersection Timeline');
    hold on;

    [timeEvents, valEvents] = generateStepVector(timeStamps);
    [timeBridge, valBridge] = generateStepVector(bridgeCoverage);

    plot(timeEvents, valEvents, 'LineWidth', 1.5, 'Color', [0 0.447 0.741], 'DisplayName', 'Potential Events');
    plot(timeBridge, valBridge, 'LineWidth', 0.8, 'Color', [0.850 0.325 0.098], 'DisplayName', 'Bridge Coverage');

    validMatches = overlapIndices(overlapIndices > 0);
    if ~isempty(validMatches)
        intersectionPoints = bridgeCoverage(validMatches, 1);
        scatter(intersectionPoints, ones(size(intersectionPoints)), 40, 'kx', ...
            'LineWidth', 1, 'DisplayName', 'Intersections');
    end

    allDates = [timeStamps(:); bridgeCoverage(:)];
    set(gca, 'YTick', [0 0.5 1], 'YTickLabel', {'None', 'Active', 'Data'}, ...
        'XLim', [min(allDates) max(allDates)], 'YLim', [-0.1 1.2], 'XGrid', 'on');

    ylabel('Availability [0-1]');
    legend('Location', 'northeast');

    if saveFlag
        figureFolder = 'figures/BridgeDataProcessed';
        if ~exist(figureFolder, 'dir'), mkdir(figureFolder); end
        saveFig(fig, figureFolder, 'DataIntersectionTimeline');
    end
end

function [timeline, values] = generateStepVector(intervals)
    % Generates coordinates for a binary step plot from time interval pairs.

    intervals = sortrows(intervals, 1);
    numIntervals = size(intervals, 1);
    timeline = NaT(numIntervals * 4, 1);
    values = zeros(numIntervals * 4, 1);

    for i = 1:numIntervals
        startIdx = (i - 1) * 4 + 1;
        timeline(startIdx : startIdx + 3) = [intervals(i, 1), intervals(i, 1), intervals(i, 2), intervals(i, 2)];
        values(startIdx : startIdx + 3) = [0, 1, 1, 0];
    end
end

function plotDataLimitsWithinPeriod(allStats, limits, startDateTime, endDateTime)
    % Plots peak and coherence values over time to diagnose RWIV detection logic.
    allStatsTime = allStats.duration(:,1);
    timeMask = (allStatsTime>= startDateTime) & (allStatsTime <= endDateTime);
    periodData = allStats(timeMask, :);
    
    fig = createFigure(2, 'RWIV Threshold Diagnostics');
    
    metrics = {'PeakX', 'PeakY', 'PeakZ', 'CohXY', 'CohYZ', 'CohXZ'};
    plotTitles = {'Peak X', 'Peak Y', 'Peak Z', 'Coherence XY', 'Coherence YZ', 'Coherence XZ'};
    thresholds = [limits.targetFreqs(1), limits.targetFreqs(2), ...
                  limits.targetFreqs(1), limits.targetFreqs(2), ...
                  limits.coherenceLimit(1), limits.coherenceLimit(2)];

    for i = 1:6
        subplot(3, 2, i);
        hold on;
        
        scatter(periodData.Time, periodData.(metrics{i}), 25, 'filled', ...
            'MarkerFaceAlpha', 0.6, 'DisplayName', 'Observed Data');
            
        yline(thresholds(i), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Limit');
        
        title(plotTitles{i});
        ylabel('Value');
        grid on;
        
        if i > 4
            xlabel('Time');
        end
    end
    
    linkaxes(findobj(fig, 'Type', 'axes'), 'x');
end
%% --- Plotting helpers ---
function fig = createFigure(figNum,title)
fig = figure(figNum); clf;
set(fig, 'Name', title, 'NumberTitle', 'off');
set(fig, 'DefaultTextInterpreter', 'latex', ...
    'DefaultAxesTickLabelInterpreter', 'latex', ...
    'DefaultLegendInterpreter', 'latex');
theme(fig, "light");
colororder(fig, 'earth');
end

function successFlag = saveFig(fig,figureFolder,fileName)
fontsize(fig, "scale",1.7);
try
    if ~isempty(figureFolder)
        exportgraphics(fig, fullfile(figureFolder, [fileName '.pdf']), 'ContentType', 'vector');
        exportgraphics(fig, fullfile(figureFolder, [fileName '.png']));
    else
        error('No save')
    end
    successFlag = true;
catch 
    successFlag = false;
end
end
%% helper functions
function [overlapIndices,bridgeCoverage] = findDataIntersection(timeStamps)
bridgeCoverage = getRealBridgeCoverage;

numStamps = size(timeStamps, 1);
overlapIndices = zeros(numStamps,1);

bridgeStarts = bridgeCoverage(:,1);
bridgeEnds = bridgeCoverage(:,2);

for i = 1:numStamps
    targetStart = timeStamps(i, 1);
    targetEnd = timeStamps(i, 2);

    matchIdx = find((bridgeStarts <= targetEnd) & (bridgeEnds >= targetStart));

    if ~isempty(matchIdx)
        overlapIndices(i) = matchIdx;
    end
end
fprintf('found a total of %d overlaps in data\n',sum(overlapIndices>0))
end

function coveragePeriod = getRealBridgeCoverage()
%getRealBridgeCoverage Scans for bridge files (ignoring WSDA) and provides time-left estimates.
dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data/WSDA_data';

fileList = dir(fullfile(dataRoot, '**', '*-*-*.mat'));
nFilesTotal = numel(fileList);
coveragePeriod = NaT(nFilesTotal,2);

for k = 1:nFilesTotal
    fileName = fileList(k).name;
    % Ensure filename is exactly YYYY-MM-DD.mat and does not contain WSDA
    if isempty(regexp(fileName,'WSDA_\d{4}-\d{2}-\d{2}_(am|pm)_\d{6}_to_\d{6}\.mat$','once')), continue; end

    currDate    = fileName(6:15);
    startTime   = fileName(20:25);
    endTime     = fileName(30:35);
    startDateTime = datetime([currDate ' ' startTime],'InputFormat','uuuu-MM-dd HHmmss');
    endDateTime   = datetime([currDate ' '   endTime],'InputFormat','uuuu-MM-dd HHmmss');
    coveragePeriod(k,:) = [startDateTime endDateTime];
end

end

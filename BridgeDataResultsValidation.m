clear all;clc
pause(3)

addpath('functions/')
resultsDir = 'figures/BridgeDataProcessed';
figuresDir = 'figures/BridgeDataProcessedResults';

load(fullfile(resultsDir,'potentialEvents.mat'))
[allStats, success] = loadProcessedData(resultsDir);
timeStamps = potentialEvents.duration;
[overlapIndices, cableCoverage] = findDataIntersection(timeStamps);
%%
% plotDataAvailability(timeStamps, cableCoverage, overlapIndices,0)
% allDeviations = findDataOverlapsDispDeviations(potentialEvents,limits,overlapIndices,cableCoverage);
peakDeviations = calculatePeakModalAmplitude(allDeviations, 3);
plotRefinedEvents(peakDeviations,figuresDir);

%% Plots
function plotDataAvailability(timeStamps, cableCoverage, overlapIndices, saveFlag)
    % Visualizes event availability and bridge data intersections on a 0-1 scale.

    fig = createFigure(1, 'Bybrua Project: Data Intersection Timeline');
    hold on;

    [timeEvents, valEvents] = generateStepVector(timeStamps);
    [timeBridge, valBridge] = generateStepVector(cableCoverage);

    plot(timeEvents, valEvents, 'LineWidth', 1.5, 'Color', [0 0.447 0.741], 'DisplayName', 'Potential Events');
    plot(timeBridge, valBridge, 'LineWidth', 0.8, 'Color', [0.850 0.325 0.098], 'DisplayName', 'Cable Coverage');

    validMatches = overlapIndices(overlapIndices > 0);
    if ~isempty(validMatches)
        intersectionPoints = cableCoverage(validMatches, 1);
        scatter(intersectionPoints, ones(size(intersectionPoints)), 40, 'kx', ...
            'LineWidth', 1, 'DisplayName', 'Intersections');
    end

    allDates = [timeStamps(:); cableCoverage(:)];
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

function allDeviations = findDataOverlapsDispDeviations(potentialEvents, limits, overlapIndices, cableCoverage)
arguments
    potentialEvents 
    limits 
    overlapIndices 
    cableCoverage 
end
    overlapIndices(overlapIndices > 0) = 1;
    overlapIndices = logical(overlapIndices);
    overlapEvents = potentialEvents(overlapIndices,:);
        
    cables = {'C1E', 'C1W', 'C2E', 'C2W'};
    axes = {'x', 'y', 'z'}; % axial, heave, sway components
    allVars = strcat(reshape(repmat(cables, 3, 1), [], 1)', '_', repmat(axes, 1, 4));
    allDeviations = timetable('Size', [height(overlapEvents), length(allVars)], ...
        'VariableTypes', repmat({'double'}, 1, length(allVars)), ...
        'VariableNames', allVars, ...
        'RowTimes', overlapEvents.duration(:, 1));
    allDeviations{:, :} = missing;


    for i = 1:height(overlapEvents)
        startTime = overlapEvents.duration(i,1);
        endTime   = overlapEvents.duration(i,2);
        
        try
            cableDisp = getCableDisp(startTime,endTime);
            %plotCables(CableDisp);
            
            range = timerange(startTime+minutes(1),...
                                endTime-minutes(1));
            cableDisp = cableDisp(range,:);
            
            devsValues = std(cableDisp{:, :}, [], 1, 'omitnan');
            activeVars = cableDisp.Properties.VariableNames;
            allDeviations(startTime, activeVars) = array2table(devsValues);
        catch ME
            fprintf('Skipped case due to error: %s',ME.identifier)
        end
    end
    
    % fig = createFigure(1,'CableDisplacementValidation');
    % plot(1:height(allDeviations),allDeviations.C1E_y,'o','MarkerFaceColor','auto')
    % hold on
    % plot(1:height(allDeviations),allDeviations.C1W_y,'di','MarkerFaceColor','auto')
    % plot(1:height(allDeviations),allDeviations.C2E_y,'^','MarkerFaceColor','auto')
    % plot(1:height(allDeviations),allDeviations.C2W_y,'sq','MarkerFaceColor','auto')
    % area(1:height(allDeviations),max(allDeviations.Variables,[],2),'FaceAlpha',0.2)
    
    function plotCables(CableDisp)
        figure(1);clf
        tiledlayout('flow')
        if any(strcmpi(CableDisp.Properties.VariableNames,'C1E_y'))
            nexttile
            plot(CableDisp.Time,CableDisp.C1E_y);title('C1E_y')
            ylim([-0.1 .1])
        end
        if any(strcmpi(CableDisp.Properties.VariableNames,'C1W_y'))
            nexttile
            plot(CableDisp.Time,CableDisp.C1W_y);title('C1W_y')
            ylim([-0.1 .1])
        end
        if any(strcmpi(CableDisp.Properties.VariableNames,'C2E_y'))
            nexttile
            plot(CableDisp.Time,CableDisp.C2E_y);title('C2E_y')
            ylim([-0.1 .1])
        end
        if any(strcmpi(CableDisp.Properties.VariableNames,'C2W_y'))
            nexttile
            plot(CableDisp.Time,CableDisp.C2W_y);title('C2W_y')
            ylim([-0.1 .1])
        end
    end
end

function fig = plotRefinedEvents(allDeviations,figureFolder)
cableDiameter = 0.079;
targetVariables = {'C1E_y', 'C1W_y', 'C2E_y', 'C2W_y'};

dataPresentMask = ~all(ismissing(allDeviations{:, targetVariables}), 2);
cleanDeviations = allDeviations(dataPresentMask, :);
cleanDeviations = sortrows(cleanDeviations, 'Time');

if isempty(cleanDeviations)
    return;
end

timeDifferences = diff(cleanDeviations.Time);
isNewEvent = [true; timeDifferences > hours(6)];
eventIdentifiers = cumsum(isNewEvent);
uniqueEventIDs = unique(eventIdentifiers);

eventDurations = zeros(length(uniqueEventIDs), 1);
validEventMask = false(length(uniqueEventIDs), 1);

for i = 1:length(uniqueEventIDs)
    eventSubset = cleanDeviations(eventIdentifiers == uniqueEventIDs(i), :);
    timeSpan = max(eventSubset.Time) - min(eventSubset.Time);

    if height(eventSubset) > 1 && timeSpan > minutes(10)
        eventDurations(i) = hours(timeSpan);
        validEventMask(i) = true;
    end
end

activeEventIDs = uniqueEventIDs(validEventMask);
activeDurations = eventDurations(validEventMask);

minimumVisualWidthHours = 2;
visualWeights = max(activeDurations, minimumVisualWidthHours);
totalWeight = sum(visualWeights);

fig = createFigure(2, 'Refined_RWIV_Events');
clf(fig);

globalMaxDisplacement = max(max(cleanDeviations{:, targetVariables}, [], 'omitnan')) / cableDiameter;
yAxisLimits = [0, ceil(globalMaxDisplacement * 1.1)];

leftMargin = 0.06;
rightMargin = 0.02;
spacing = 0.015;
usableWidth = 1 - leftMargin - rightMargin - (length(activeEventIDs) - 1) * spacing;

currentLeftPosition = leftMargin;

markers = {'o', 'd', '^', 's'};
plotColors = colororder;

for i = 1:length(activeEventIDs)
    currentEventData = cleanDeviations(eventIdentifiers == activeEventIDs(i), :);
    normalizedWidth = (visualWeights(i) / totalWeight) * usableWidth;

    ax = axes('Position', [currentLeftPosition, 0.15, normalizedWidth, 0.75]);
    hold(ax, 'on');

    normalizedDisplacement = currentEventData{:, targetVariables} / cableDiameter;
    eventTime = currentEventData.Time;

    cableDisp = getCableDisp(eventTime(1),eventTime(end));
    cableDisp = calculatePeakModalAmplitude(cableDisp, 3);

    plot(cableDisp.Time,cableDisp.C1W_y./cableDiameter,'Color',[0.9 0.9 0.9 0.05], 'LineWidth',1)
    try
       plot(cableDisp.Time,cableDisp.C1E_y./cableDiameter,'Color',[0.9 0.9 0.9 0.05], 'LineWidth',1) 
    catch exception
       3+3;
    end

    for k = 1:length(targetVariables)
        plot(ax, eventTime, normalizedDisplacement(:, k), markers{k}, ...
            'MarkerFaceColor', plotColors(k,:), ...
            'MarkerEdgeColor', 'w', ...
            'MarkerSize', 5);
    end

    ylim(ax, yAxisLimits);

    title(ax, datestr(min(eventTime), 'dd/mm/yy'), 'FontSize', 10, 'FontWeight', 'normal');

    xtickformat(ax, 'HH:mm');
    xtickangle(ax, 45);
    xsecondarylabel(Visible="off")
    % numXtickLabels = sum(string(ax.XTickLabel)=="");
    % if numXtickLabels < 2 || i==2
    %     xticks([min(eventTime) max(eventTime)])
    % end

    set(ax, 'FontSize', 10, 'Box', 'on', 'Layer', 'top');
    grid(ax, 'on');

    if i > 1
        set(ax, 'YTickLabel', []);
    else
        ylabel(ax, 'Std(Disp) / D (-)');
    end

    currentLeftPosition = currentLeftPosition + normalizedWidth + spacing;
    drawnow
end

legendEntries = strrep(targetVariables, '_y', '');
dummyAxes = axes('Position', [0.875, 0.77, 0.1, 0.05], 'Visible', 'off');
hold(dummyAxes, 'on');
for k = 1:length(targetVariables)
    plot(dummyAxes, nan, nan, markers{k}, ...
        'MarkerFaceColor', plotColors(k,:), 'MarkerEdgeColor', 'w');
end
legend(dummyAxes, legendEntries, 'Orientation', 'horizontal', 'Location', 'northoutside', 'FontSize', 10);
successFlag = saveFig(fig,figureFolder,'CableVibrationsAtFlags',1.0);
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

function successFlag = saveFig(fig,figureFolder,fileName,scale)
arguments
    fig
    figureFolder
    fileName
    scale = 1.7
end
fontsize(fig, "scale",scale);
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

function cableDisp = getCableDisp(startTime,endTime)
dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';
byBroa = BridgeProject(dataRoot, startTime, endTime,loadBridge=false);

if isempty(byBroa.cableData)
    error('No cable data')
end

byBroaOverview = BridgeOverview(byBroa);
byBroaOverview = byBroaOverview.fillMissingDataPoints;
byBroaOverview = byBroaOverview.designFilter('butter', order=7, fLow=1, fHigh=15);
byBroaOverview = byBroaOverview.applyFilter;
[~,cableDisp] = byBroaOverview.convertAcceleration([],...
    byBroaOverview.project.cableData,'displacement');
%figure(1);clf
%plot(cableDisp.Time,cableDisp.C1W_y,'Color',[0.9 0.9 0.9], 'LineWidth',1)
%plot(cableDisp.Time,cableDisp.Variables)
end

function peakDeviations = calculatePeakModalAmplitude(allDeviations, modeNumber)
    % Corrects timetable displacement deviations to anti-node peak values using taut string theory.

    arguments
        allDeviations timetable
        modeNumber (1,1) double = 3
    end

    peakDeviations = allDeviations;
    columnNames = allDeviations.Properties.VariableNames;

    for i = 1:numel(columnNames)
        currentName = columnNames{i};
        
        if startsWith(currentName, 'C1')
            cableLength = 98.3;
            cableAngle = 29.8;
        elseif startsWith(currentName, 'C2')
            cableLength = 95.6;
            cableAngle = 30.7;
        else
            continue;
        end

        sensorDistance = 4 / sin(deg2rad(cableAngle));
        sinusoidalCorrection = sin(modeNumber * pi * sensorDistance / cableLength);
        
        peakDeviations.(currentName) = allDeviations.(currentName) / sinusoidalCorrection;
    end
end
%% helper functions
function [overlapIndices,cableCoverage] = findDataIntersection(timeStamps)
cableCoverage = getRealCableCoverage;

numStamps = size(timeStamps, 1);
overlapIndices = zeros(numStamps,1);

bridgeStarts = cableCoverage(:,1);
bridgeEnds = cableCoverage(:,2);

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

function coveragePeriod = getRealCableCoverage()
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

function [allStats, success] = loadProcessedData(resultsDir)
finalFile = fullfile(resultsDir, 'AnalysisResults_BridgeStats.mat');
checkFile = fullfile(resultsDir, 'AnalysisResults_Checkpoint.mat');

success = true;
if exist(finalFile, 'file')
    fprintf('Loading: %s\n', finalFile);
    loaded = load(finalFile);
    saveName = finalFile;
elseif exist(checkFile, 'file')
    fprintf('Loading Checkpoint: %s\n', checkFile);
    loaded = load(checkFile);
    saveName = checkFile;
else
    fprintf('No data files found.\n');
    allStats = []; success = false; return;
end
data = loaded.allDailyResults;

if size(data,1) == 1
    days = fieldnames(data);
    allStats = [];
    for d = 1:numel(days)
        allStats = [allStats; data.(days{d})];
        fprintf('transfered day %d out of %d\n',d,numel(days))
    end
    allStats = struct2table(allStats);
    save(saveName,"allStats","-v7.3",'-nocompression')
else
    allStats = data;
end
end
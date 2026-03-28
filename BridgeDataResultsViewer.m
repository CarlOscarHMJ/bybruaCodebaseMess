%% RWIV Analysis Dashboard
% Loads processed bridge data and generates diagnostic visualizations.

addpath('functions/', 'functions/bridgeDataResultsVieweFunctions/')
figureFolder = 'figures/BridgeDataProcessedResults/';

% --- Main Execution ---
[allStats, status] = loadProcessedData('figures/BridgeDataProcessed/');
if ~status, return; end
%% Reorient Deck accelerometer directions
allStats = reorientDeckAccelerometers(allStats);
%% Get all flags
limits.targetFreqs         = [3.174, 4.27, 6.32]; % Found centers of deck peaks at RWIV
limits.freqTolerance       = 0.15;          % Tolerance in Hz
limits.targetCoherenceFreq = [3.22, 6.37];  % Found centers of co-coherence peaks at RWIV
limits.coherenceLimit      = [-0.6,0.7];    % coCoherence value that is the lower limits for flagging
limits.cableWindSpeed      = [8 12];
limits.cableWindDir        = [45 65];
limits.rainLowerLimit      = 0.01;

allStats = applyAnalysisFlags(allStats, limits);
%% Visualization
rng(112)
plotFlags = ["flag_StructuralResponseMatch","flag_PSDTotal","flag_CohTotal","flag_EnvironmentalMatch","flag_PSDAllDirections","flag_PSDSelectedCs"];
flagNames = ["PSD $\cap$ Coherence", "PSD", "Coherence", "Daniotti\,(2021)","PSD All Directions","PSD Selected Directions"];
% ISDAC 2026 Paper figures
% allStats = plotNidComparison(allStats,plotFlags(1:4),limits,'local',figureFolder,flagNames(1:4),false,10,1);
% plotNidComparisonPeakIntensity(allStats, plotFlags(2), limits, 'global', figureFolder,flagNames(2));
% plotWindRoses(allStats,figureFolder)
% plotRiwvWeatherScatter3D(allStats, limits, figureFolder);
% plotRwivWindSpeedVsTime(allStats,plotFlags(2),figureFolder,limits,flagNames(2));
% plotDAuteuilComparison(allStats, plotFlags(2),flagNames(2), 29.8,  figureFolder, 'Data/Misc/DAuteuil2023ReviewData.csv','violin');


% Additional analysis for eastdac
% plotSpectralShift(allStats,limits,envFlagField='flag_PSDTotal_inGmm',specFlagField='flag_PSDTotal',plotBackground=false,plotAllDirections=true)
% plotSpectralShift(allStats,'flag_EnvironmentalMatch', ["Conc_Z", "Steel_Z"], limits,'local',figureFolder)
% clc
% plotSpectralShiftHistogram(allStats, targetSensors=["Conc_Z", "Steel_Z"], ...
%                            envFlagField='flag_PSDTotal_inGmm', ...
%                            specFlagField='flag_PSDTotalAnd4Hz', ...
%                            numTimeChunks=30, numHistBins=70, ...
%                            weightedHistogram=false, ...
%                            intensityQuantile=.75, ...
%                            figureFolder=figureFolder,saveFigure=true);
plotFlags = ["flag_PSD_Any3Points","flag_PSD_Any4Points","flag_PSDTotal","flag_PSDTotalAnd4Hz"];
flagNames = ["PSD ($\ge$ 3 Peaks Any Dir.)","PSD ($\ge$ 4 Peaks Any Dir.)","PSD Total","PSD Total $\cup$ 4Hz"];
%allStats = plotNidComparison(allStats, plotFlags, limits, 'local', figureFolder, flagNames, false, 10, 1);
plotSpectralShift(allStats,limits,envFlagField='flag_PSDTotal_inGmm',specFlagField='flag_PSD_Any4Points',plotBackground=true,plotAllDirections=false)

% plotNidComparison(allStats,plotFlags(1:4),limits,'local',figureFolder,flagNames(1:4),false,10,1);
% plotNidComparison(allStats,plotFlags,limits,'global',figureFolder);
% plotFlaggedAccVsWind(allStats, plotFlags, 'global', figureFolder)
% plotPeaksDistribution(allStats, limits,figureFolder,'X');drawnow
% plotPeaksDistribution(allStats, limits,figureFolder,'Y');drawnow
% plotPeaksDistribution(allStats, limits,figureFolder,'Z');drawnow
% plotPeaksDistribution(allStats, limits,figureFolder, ["Conc_X", "Steel_X"])
% plotPeaksDistributionAllDir(allStats, limits,figureFolder)
% plotCoherenceDistribution(allStats, limits, figureFolder)
% plotNidComparisonPeakIntensity(allStats, plotFlags(2), limits, 'global', figureFolder,flagNames(2))
%plotNidComparisonPeakIntensity(allStats, plotFlags(5), limits, 'local', figureFolder,flagNames(5))
% plotNidComparison(allStats, plotFlags(5), limits, 'local', figureFolder,flagNames(5))
% plotNidComparison(allStats, plotFlags(6), limits, 'local', figureFolder,flagNames(6))
% plotNidComparisonPeakIntensity(allStats, plotFlags(1:2), limits, 'local', figureFolder)
% plotWindRoses(allStats,figureFolder)
% plotRiwvWeatherScatter3D(allStats, limits, figureFolder)

% Probability plots
% splitDate = datetime(2021, 1, 1);
% startDate = min(mean(allStats.duration,2));
% endDate = max(mean(allStats.duration,2));
% timeRanges = {[startDate, splitDate], [splitDate, endDate]};
% fields = string(fieldnames(allStats));
% allFlagFields = fields(startsWith(fields, 'flag'));
% plotRwivGlobalProbability(allStats, allFlagFields([5 5]), ...
%                           figureFolder, 'RwivProbabilityBeforeAfter2021', ...
%                           false, timeRanges);

% plotRwivWindSpeedVsTime(allStats,plotFlags(2),figureFolder,limits,flagNames(2))
% plotRwivWindSpeedVsTime(allStats,plotFlags(5),figureFolder,limits,flagNames(5))
% plotRwivWindSpeedVsTime(allStats,plotFlags(6),figureFolder,limits,flagNames(6))
% After2021Idx = allStats.duration(:,1) > datetime(2021,1,1);
% plotPeaksDistribution(allStats(After2021Idx,:), limits,figureFolder,'X');drawnow
% plotPeaksDistribution(allStats(After2021Idx,:), limits,figureFolder,'Y');drawnow
% plotPeaksDistribution(allStats(After2021Idx,:), limits,figureFolder,'Z');drawnow

%rng(10)
%plotNidComparison(allStats, plotFlags(2), limits, 'local', figureFolder,flagNames(2),true,3,3)


% plotDAuteuilComparison(allStats, plotFlags(2),flagNames(2), 29.8,  figureFolder, 'Data/Misc/DAuteuil2023ReviewData.csv','violin')

% Old functions
% plotTimeSinceRain(events, allStats);
%plotGeneralTrends(allStats)
% plotFrequencyDistribution(allStats, targetFreqs, freqTolerance)
%% Save data for validation analysis:
potentialEvents = allStats(allStats.flag_StructuralResponseMatch,:);
save('figures/BridgeDataProcessed/potentialEvents.mat','potentialEvents','limits')
%% --- Modular Functions ---

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

function statsTable = applyAnalysisFlags(statsTable, thresholds)
    % applyAnalysisFlags sets logical flags based on peak frequencies, coherence, wind and rain limits.

    psdFlags = extractPsdFlags(statsTable, thresholds.targetFreqs, thresholds.freqTolerance);
    [flagAny3Points, flagAny4Points] = calculateDirectionalFlags(psdFlags);
    
    statsTable.flag_PSD_Any3Points = flagAny3Points;
    statsTable.flag_PSD_Any4Points = flagAny4Points;

    statsTable.flag_PSD_Conc_F1 = psdFlags.Conc_Z.mode1;
    statsTable.flag_PSD_Conc_F2 = psdFlags.Conc_Z.mode2;
    statsTable.flag_PSD_Conc_F3 = psdFlags.Conc_Z.mode3;
    statsTable.flag_PSD_Steel_F1 = psdFlags.Steel_Z.mode1;
    statsTable.flag_PSD_Steel_F2 = psdFlags.Steel_Z.mode2;
    statsTable.flag_PSD_Steel_F3 = psdFlags.Steel_Z.mode3;
    
    statsTable.flag_PSDTotal = (psdFlags.Conc_Z.mode1 & psdFlags.Conc_Z.mode3) & ...
                               (psdFlags.Steel_Z.mode1 & psdFlags.Steel_Z.mode3);

    statsTable.flag_PSD4Hz = psdFlags.Conc_Z.mode2 & psdFlags.Steel_Z.mode2;
    statsTable.flag_PSDTotalAnd4Hz = statsTable.flag_PSDTotal | statsTable.flag_PSD4Hz;
    
    sampleDate = mean(statsTable.duration, 2);
    statsTable.flag_PSDTotal_Before2021 = statsTable.flag_PSDTotal & (sampleDate < datetime(2021, 1, 1));
    statsTable.flag_PSDTotal_After2021 = statsTable.flag_PSDTotal & (sampleDate > datetime(2021, 1, 1));
    
    statsTable.flag_PSDAllDirections = psdFlags.Conc_X.mode1 & psdFlags.Conc_X.mode3 & ...
                                       psdFlags.Conc_Y.mode1 & psdFlags.Conc_Y.mode3 & ...
                                       psdFlags.Conc_Z.mode1 & psdFlags.Conc_Z.mode3 & ...
                                       psdFlags.Steel_X.mode1 & psdFlags.Steel_X.mode3 & ...
                                       psdFlags.Steel_Y.mode1 & psdFlags.Steel_Y.mode3 & ...
                                       psdFlags.Steel_Z.mode1 & psdFlags.Steel_Z.mode3;
    
    statsTable.flag_PSDSelectedCs = psdFlags.Conc_X.mode1 & psdFlags.Conc_X.mode3 & ...
                                    psdFlags.Conc_Y.mode1 & psdFlags.Conc_Y.mode3 & ...
                                    psdFlags.Conc_Z.mode3 & ...
                                    psdFlags.Steel_X.mode1 & psdFlags.Steel_X.mode3 & ...
                                    psdFlags.Steel_Y.mode1;

    coherenceMatrix = [statsTable.cohVals.Z]';
    statsTable.flag_Coh_F1 = coherenceMatrix(:, 1) <= thresholds.coherenceLimit(1);
    statsTable.flag_Coh_F2 = coherenceMatrix(:, 2) >= thresholds.coherenceLimit(2);
    statsTable.flag_CohTotal = statsTable.flag_Coh_F1 & statsTable.flag_Coh_F2;
    
    windSpeedMean = [statsTable.WindSpeed.mean]';
    phiC1Mean = [statsTable.PhiC1.mean]';
    rainIntensity = [statsTable.RainIntensity.mean]';

    statsTable.flag_WindSpd = windSpeedMean >= thresholds.cableWindSpeed(1) & windSpeedMean <= thresholds.cableWindSpeed(2);
    statsTable.flag_WindAng = phiC1Mean >= thresholds.cableWindDir(1) & phiC1Mean <= thresholds.cableWindDir(2);
    statsTable.flag_Rain = rainIntensity > thresholds.rainLowerLimit;
    
    statsTable.flag_StructuralResponseMatch = statsTable.flag_PSDTotal & statsTable.flag_CohTotal;
    statsTable.flag_EnvironmentalMatch = statsTable.flag_WindSpd & statsTable.flag_WindAng & statsTable.flag_Rain;
    statsTable.flag_allFlags = statsTable.flag_StructuralResponseMatch & statsTable.flag_EnvironmentalMatch;
end

function psdFlags = extractPsdFlags(statsTable, targetFreqs, tolerance)
    % extractPsdFlags creates logical arrays indicating presence of target frequencies for all sensors.
    fields = string(fieldnames(statsTable.psdPeaks))';
    numSegments = height(statsTable);
    
    for field = fields
        psdFlags.(field).mode1 = false(numSegments, 1);
        psdFlags.(field).mode2 = false(numSegments, 1);
        psdFlags.(field).mode3 = false(numSegments, 1);
    end
    
    for i = 1:numSegments
        for field = fields
            if isstruct(statsTable.psdPeaks) && isfield(statsTable.psdPeaks, field)
                peaks = statsTable.psdPeaks(i).(field).locations;
                psdFlags.(field).mode1(i) = any(abs(peaks - targetFreqs(1)) <= tolerance);
                psdFlags.(field).mode2(i) = any(abs(peaks - targetFreqs(2)) <= tolerance);
                psdFlags.(field).mode3(i) = any(abs(peaks - targetFreqs(3)) <= tolerance);
            end
        end
    end
end

function [flag3Points, flag4Points] = calculateDirectionalFlags(psdFlags)
    % calculateDirectionalFlags computes the 3-point and 4-point directional criteria.
    directions = ["X", "Y", "Z"];
    numSegments = length(psdFlags.Conc_Z.mode1);
    
    flag3Points = false(numSegments, 1);
    flag4Points = false(numSegments, 1);
    
    for dir = directions
        concField = "Conc_" + dir;
        steelField = "Steel_" + dir;
        
        if isfield(psdFlags, concField) && isfield(psdFlags, steelField)
            totalPoints = psdFlags.(concField).mode1 + psdFlags.(concField).mode2 + psdFlags.(concField).mode3 + ...
                          psdFlags.(steelField).mode1 + psdFlags.(steelField).mode2 + psdFlags.(steelField).mode3;
            
            fourPointsCond = psdFlags.(concField).mode1 & psdFlags.(concField).mode3 & ...
                             psdFlags.(steelField).mode1 & psdFlags.(steelField).mode3;
                             
            flag3Points = flag3Points | (totalPoints >= 3);
            flag4Points = flag4Points | fourPointsCond;
        end
    end
end

function allStats = reorientDeckAccelerometers(allStats)
    % reorientDeckAccelerometers aligns accelerometer data to a global frame:
    % X: longitudinal (along-bridge)
    % Y: transversal (across-bridge)
    % Z: vertical (upwards)
    
    % Steel is already globally aligned (Z up, X longitudinal).
    % Concrete originally has X up, Y longitudinal, Z transversal.
    
    % 1. Swap the main statistics columns in the table
    if all(ismember(["Conc_X", "Conc_Y", "Conc_Z"], allStats.Properties.VariableNames))
        tempConcX = allStats.Conc_X;
        tempConcY = allStats.Conc_Y;
        tempConcZ = allStats.Conc_Z;
        
        allStats.Conc_X = tempConcY; % Global X is original Y
        allStats.Conc_Y = tempConcZ; % Global Y is original Z
        allStats.Conc_Z = tempConcX; % Global Z is original X
    end

    % 2. Swap the fields inside the nested psdPeaks structure
    if ismember('psdPeaks', allStats.Properties.VariableNames)
        for i = 1:height(allStats)
            tempPsdX = allStats.psdPeaks(i).Conc_X;
            tempPsdY = allStats.psdPeaks(i).Conc_Y;
            tempPsdZ = allStats.psdPeaks(i).Conc_Z;
            
            allStats.psdPeaks(i).Conc_X = tempPsdY;
            allStats.psdPeaks(i).Conc_Y = tempPsdZ;
            allStats.psdPeaks(i).Conc_Z = tempPsdX;
        end
    end
    
    fprintf('Deck accelerometers successfully reoriented to global coordinates (X: Long, Y: Trans, Z: Vert).\n');
end

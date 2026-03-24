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
plotSpectralShift(allStats,limits,envFlagField='flag_PSDTotal_inGmm',specFlagField='flag_PSDTotalAnd4Hz')
% plotSpectralShift(allStats,'flag_EnvironmentalMatch', ["Conc_Z", "Steel_Z"], limits,'local',figureFolder)
plotFlags = ["flag_PSDTotal","flag_PSD4Hz","flag_PSDTotalAnd4Hz","flag_CohTotal"];
flagNames = ["PSD", "PSD 4Hz peak", "PSD Total and 4Hz","Coherence"];
% allStats = plotNidComparison(allStats,plotFlags(1:4),limits,'local',figureFolder,flagNames(1:4),false,10,1);

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

function StatsTable = applyAnalysisFlags(StatsTable, Thresholds)
    NumberSegments = height(StatsTable);
    
    TargetFreq1 = Thresholds.targetFreqs(1); 
    TargetFreq2 = Thresholds.targetFreqs(2);
    TargetFreq3 = Thresholds.targetFreqs(3);
    Tolerance = Thresholds.freqTolerance;
    
    fields = string(fieldnames(StatsTable.psdPeaks))';
    for field = fields
        PsdFlag.(field).Mode1 = false(NumberSegments, 1);
        PsdFlag.(field).Mode2 = false(NumberSegments, 1);
        PsdFlag.(field).Mode3 = false(NumberSegments, 1);
    end

    for i = 1:NumberSegments
        for field = fields
            if isstruct(StatsTable.psdPeaks) && isfield(StatsTable.psdPeaks, field)
                PeakFrequencies = StatsTable.psdPeaks(i).(field).locations;
                
                if any(PeakFrequencies >= (TargetFreq1 - Tolerance) & PeakFrequencies <= (TargetFreq1 + Tolerance))
                    PsdFlag.(field).Mode1(i) = true;
                end
                
                if any(PeakFrequencies >= (TargetFreq2 - Tolerance) & PeakFrequencies <= (TargetFreq2 + Tolerance))
                    PsdFlag.(field).Mode2(i) = true;
                end

                if any(PeakFrequencies >= (TargetFreq3 - Tolerance) & PeakFrequencies <= (TargetFreq3 + Tolerance))
                    PsdFlag.(field).Mode3(i) = true;
                end
            end
        end
    end
    
    CoherenceMatrix = [StatsTable.cohVals.Z]';
    CoherenceFlagMode1 = CoherenceMatrix(:,1) <= Thresholds.coherenceLimit(1);
    CoherenceFlagMode2 = CoherenceMatrix(:,2) >= Thresholds.coherenceLimit(2);
    
    UNormalC1_mean  = [StatsTable.UNormalC1.mean];
    WindSpeed_mean  = [StatsTable.WindSpeed.mean];
    PhiC1_mean      = [StatsTable.PhiC1.mean];
    RainIntensity   = [StatsTable.RainIntensity.mean];

    % EnvironmentalWindSpeedFlag = (UNormalC1_mean >= Thresholds.cableWindSpeed(1)...
    %                             & UNormalC1_mean <= Thresholds.cableWindSpeed(2)).';
    EnvironmentalWindSpeedFlag = (WindSpeed_mean >= Thresholds.cableWindSpeed(1)...
                                & WindSpeed_mean <= Thresholds.cableWindSpeed(2)).';
    EnvironmentalWindAngleFlag = (PhiC1_mean >= Thresholds.cableWindDir(1)...
                                & PhiC1_mean <= Thresholds.cableWindDir(2)).';
    EnvironmentalRainFlag = (RainIntensity > Thresholds.rainLowerLimit).'; 
    
    sampleDate = mean(StatsTable.duration,2);
    
    StatsTable.flag_PSD_Conc_F1 = PsdFlag.Conc_Z.Mode1;
    StatsTable.flag_PSD_Conc_F2 = PsdFlag.Conc_Z.Mode2;
    StatsTable.flag_PSD_Conc_F3 = PsdFlag.Conc_Z.Mode3;
    StatsTable.flag_PSD_Steel_F1 = PsdFlag.Steel_Z.Mode1;
    StatsTable.flag_PSD_Steel_F2 = PsdFlag.Steel_Z.Mode2;
    StatsTable.flag_PSD_Steel_F3 = PsdFlag.Steel_Z.Mode3;
    StatsTable.flag_PSDTotal = (PsdFlag.Conc_Z.Mode1 & PsdFlag.Conc_Z.Mode3) & (PsdFlag.Steel_Z.Mode1 & PsdFlag.Steel_Z.Mode3);

    StatsTable.flag_PSD4Hz = PsdFlag.Conc_Z.Mode2 & PsdFlag.Steel_Z.Mode2;
    StatsTable.flag_PSDTotalAnd4Hz = StatsTable.flag_PSDTotal | StatsTable.flag_PSD4Hz;

    StatsTable.flag_PSDTotal_Before2021 = StatsTable.flag_PSDTotal & sampleDate < datetime(2021,1,1);
    StatsTable.flag_PSDTotal_After2021 = StatsTable.flag_PSDTotal & sampleDate > datetime(2021,1,1);

    StatsTable.flag_PSDAllDirections = PsdFlag.Conc_X.Mode1 & PsdFlag.Conc_X.Mode3 & ...
                                       PsdFlag.Conc_Y.Mode1 & PsdFlag.Conc_Y.Mode3 & ...
                                       PsdFlag.Conc_Z.Mode1 & PsdFlag.Conc_Z.Mode3 & ...
                                       PsdFlag.Steel_X.Mode1 & PsdFlag.Steel_X.Mode3 & ...
                                       PsdFlag.Steel_Y.Mode1 & PsdFlag.Steel_Y.Mode3 & ...
                                       PsdFlag.Steel_Z.Mode1 & PsdFlag.Steel_Z.Mode3;
    
    StatsTable.flag_PSDSelectedCs = PsdFlag.Conc_X.Mode1 & PsdFlag.Conc_X.Mode3 & ...
                                    PsdFlag.Conc_Y.Mode1 & PsdFlag.Conc_Y.Mode3 & ...
                                                           PsdFlag.Conc_Z.Mode3 & ...
                                    PsdFlag.Steel_X.Mode1 & PsdFlag.Steel_X.Mode3 & ...
                                    PsdFlag.Steel_Y.Mode1;

    StatsTable.flag_Coh_F1 = CoherenceFlagMode1;
    StatsTable.flag_Coh_F2 = CoherenceFlagMode2;
    StatsTable.flag_CohTotal = (CoherenceFlagMode1 & CoherenceFlagMode2);
    
    StatsTable.flag_WindSpd = EnvironmentalWindSpeedFlag;
    StatsTable.flag_WindAng = EnvironmentalWindAngleFlag;
    StatsTable.flag_Rain = EnvironmentalRainFlag;
    
    StatsTable.flag_StructuralResponseMatch = StatsTable.flag_PSDTotal & StatsTable.flag_CohTotal;
    StatsTable.flag_EnvironmentalMatch = EnvironmentalWindSpeedFlag & EnvironmentalWindAngleFlag & EnvironmentalRainFlag;
    
    StatsTable.flag_allFlags = StatsTable.flag_StructuralResponseMatch & StatsTable.flag_EnvironmentalMatch;
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

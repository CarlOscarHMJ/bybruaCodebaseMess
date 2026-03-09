%% RWIV Analysis Dashboard
% Loads processed bridge data and generates diagnostic visualizations.

addpath('functions/')
figureFolder = 'figures/BridgeDataProcessedResults/';

% --- Main Execution ---
[allStats, status] = loadProcessedData('figures/BridgeDataProcessed/');
if ~status, return; end
%% Reorient Deck accelerometer directions
allStats = reorientDeckAccelerometers(allStats);
%% Get all flags
limits.targetFreqs         = [3.174, 6.32]; % Found centers of deck peaks at RWIV
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
% Paper figures
% plotNidComparison(allStats,plotFlags(1:4),limits,'local',figureFolder,flagNames(1:4),false,10,1);
% plotNidComparisonPeakIntensity(allStats, plotFlags(2), limits, 'global', figureFolder,flagNames(2));
% plotWindRoses(allStats,figureFolder);
% plotRiwvWeatherScatter3D(allStats, limits, figureFolder);
plotRwivWindSpeedVsTime(allStats,plotFlags(2),figureFolder,limits,flagNames(2));
% plotDAuteuilComparison(allStats, plotFlags(2),flagNames(2), 29.8,  figureFolder, 'Data/Misc/DAuteuil2023ReviewData.csv','violin');



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
    Tolerance = Thresholds.freqTolerance;
    
    PsdFlag.Conc_X.Mode1 = false(NumberSegments, 1);
    PsdFlag.Conc_X.Mode2 = false(NumberSegments, 1);
    PsdFlag.Conc_Y.Mode1 = false(NumberSegments, 1);
    PsdFlag.Conc_Y.Mode2 = false(NumberSegments, 1);
    PsdFlag.Conc_Z.Mode1 = false(NumberSegments, 1);
    PsdFlag.Conc_Z.Mode2 = false(NumberSegments, 1);
    PsdFlag.Steel_X.Mode1 = false(NumberSegments, 1);
    PsdFlag.Steel_X.Mode2 = false(NumberSegments, 1);
    PsdFlag.Steel_Y.Mode1 = false(NumberSegments, 1);
    PsdFlag.Steel_Y.Mode2 = false(NumberSegments, 1);
    PsdFlag.Steel_Z.Mode1 = false(NumberSegments, 1);
    PsdFlag.Steel_Z.Mode2 = false(NumberSegments, 1);

    fields = string(fieldnames(StatsTable.psdPeaks))';

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
    StatsTable.flag_PSD_Steel_F1 = PsdFlag.Steel_Z.Mode1;
    StatsTable.flag_PSD_Steel_F2 = PsdFlag.Steel_Z.Mode2;
    StatsTable.flag_PSDTotal = (PsdFlag.Conc_Z.Mode1 & PsdFlag.Conc_Z.Mode2) & (PsdFlag.Steel_Z.Mode1 & PsdFlag.Steel_Z.Mode2);

    StatsTable.flag_PSDTotal_Before2021 = StatsTable.flag_PSDTotal & sampleDate < datetime(2021,1,1);
    StatsTable.flag_PSDTotal_After2021 = StatsTable.flag_PSDTotal & sampleDate > datetime(2021,1,1);

    StatsTable.flag_PSDAllDirections = PsdFlag.Conc_X.Mode1 & PsdFlag.Conc_X.Mode2 & ...
                                       PsdFlag.Conc_Y.Mode1 & PsdFlag.Conc_Y.Mode2 & ...
                                       PsdFlag.Conc_Z.Mode1 & PsdFlag.Conc_Z.Mode2 & ...
                                       PsdFlag.Steel_X.Mode1 & PsdFlag.Steel_X.Mode2 & ...
                                       PsdFlag.Steel_Y.Mode1 & PsdFlag.Steel_Y.Mode2 & ...
                                       PsdFlag.Steel_Z.Mode1 & PsdFlag.Steel_Z.Mode2;
    
    StatsTable.flag_PSDSelectedCs = PsdFlag.Conc_X.Mode1 & PsdFlag.Conc_X.Mode2 & ...
                                    PsdFlag.Conc_Y.Mode1 & PsdFlag.Conc_Y.Mode2 & ...
                                                           PsdFlag.Conc_Z.Mode2 & ...
                                    PsdFlag.Steel_X.Mode1 & PsdFlag.Steel_X.Mode2 & ...
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
%% --- Plotting Functions ---

function plotNidComparison(allStats, flagFields, limits, windDomain, figureFolder,flagNames,addDecisionBoundary,decisionBoundaryThreshold,numClusters)
    % Plots multiple RWIV parameter space validations in a tiled layout.
    arguments
        allStats 
        flagFields 
        limits 
        windDomain = 'local'
        figureFolder = ''
        flagNames = ''
        addDecisionBoundary = false
        decisionBoundaryThreshold = 2
        numClusters = 2
    end

    if ischar(flagFields) || isstring(flagFields)
        flagFields = cellstr(flagFields);
    end
    if ~length(flagNames)>0
        flagNames = flagFields;
    elseif ischar(flagNames) || isstring(flagNames)
        flagNames = cellstr(flagNames);
    end

    numPlots = length(flagFields);
    fig = createFigure(1, 'RWIV Multi-Criteria Validation');
    tlo = tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'tight');
    
    hFill = []; % Initialize to avoid errors if windDomain is not 'local'

    for i = 1:numPlots
        nexttile;
        currentFlag = flagFields{i};
        flagName = flagNames{i};
        
        rain = calculateLookbackRain(currentFlag, allStats, hours(2));
        events = allStats(allStats.(currentFlag), :);
        events = events(rain < 50, :); 
        currentRain = rain(rain < 50);

        if strcmpi(windDomain, 'local')
            %windSpeed = [events.UNormalC1.mean]';
            windSpeed = [events.WindSpeed.mean]';
            windAngle = [events.PhiC1.mean]';
        else
            windSpeed = [events.WindSpeed.mean]';
            windAngle = [events.WindDir.mean]';
        end

        acc = [events.Steel_Z.max];
        accSize = 50 / mean(acc) * acc;

        hold on;
        if strcmpi(windDomain, 'local') & ~addDecisionBoundary
            wBounds = limits.cableWindSpeed;
            pBounds = limits.cableWindDir;
            hFill = fill([pBounds(1) pBounds(2) pBounds(2) pBounds(1)], ...
                [wBounds(1) wBounds(1) wBounds(2) wBounds(2)], ...
                [0.7 0.7 0.7], 'FaceAlpha', 0.2, ...
                'EdgeColor', [0.8 0 0], 'LineWidth', 1.1);
        end
        
        noRainIdxs = currentRain == 0;
        rainIdxs = ~noRainIdxs;

        scatter(windAngle(noRainIdxs), windSpeed(noRainIdxs), ...
                accSize(noRainIdxs), 'red', 'filled', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0);
        
        scatter(windAngle(rainIdxs), windSpeed(rainIdxs), ...
                accSize(rainIdxs), currentRain(rainIdxs), 'filled', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0);
        
        colormap(myColorMap());
        clim([0 25]);
        grid on; box on;
        title(sprintf('Criteria: \\texttt{%s}', strrep(flagName, '_', '\_')), 'Interpreter', 'latex');
        set(gca, 'TickLabelInterpreter', 'latex');

        if strcmpi(windDomain, 'local')
            xlim([30 150])
            ylim([0 18])
        else
            %xlim([100 260])$\mathrm{m\,s^{-1}}$
            xlim([0 360])
            ylim([0 16])
        end
        
        if addDecisionBoundary || strcmpi(flagName,'PSD')
              windAngleGlobal = [events.WindDir.mean]';
              windAngesBelow180 = windAngleGlobal < 180;
              idxBoundary = rainIdxs & windAngesBelow180;
            plotAndWriteDecisionBoundary(windAngle(idxBoundary),windSpeed(idxBoundary));
        end
        %drawnow;
    end

    if strcmpi(windDomain, 'local')
        xlabel(tlo, '$\Phi$ (deg)', 'Interpreter', 'latex');
        %ylabel(tlo, '$U_{N}$ ($\mathrm{m\,s^{-1}}$)', 'Interpreter', 'latex');
        ylabel(tlo, '$\bar{u}$ ($\mathrm{m\,s^{-1}}$)', 'Interpreter', 'latex');
    else
        xlabel(tlo, 'Bridge axis wind (deg)', 'Interpreter', 'latex');
        ylabel(tlo, 'Wind speed ($\mathrm{m\,s^{-1}}$)', 'Interpreter', 'latex');
    end

    cb = colorbar;
    cb.Layout.Tile = 'east';
    cb.TickLabelInterpreter = 'latex';
    cb.Label.String = '$Ri_\mathrm{2h}$ ($\mathrm{mm\,h^{-1}}$)';
    cb.Label.Interpreter = 'latex';
    cb.Label.FontSize = tlo.Title.FontSize;
    clim([0 25]);

    % Fix Legend: Conditional hFill and LaTeX fixes
    hDry = scatter(NaN, NaN, 50, [1 0 0], 'filled');
    hWet = scatter(NaN, NaN, 50, [0.3 0.7 0.9], 'filled');
    hBoundary = plot(NaN, NaN, '--k','linewidth',2);
    
    if ~isempty(hFill)
        entries = [hFill, hBoundary, hDry, hWet];
        labels = {'\texttt{Daniotti\,} Region', 'Fitted Boundary','Dry Case ($0$ $\mathrm{mm\,h^{-1}}$)', 'Wet Case ($>0$ $\mathrm{mm\,h^{-1}}$)\quad'};
    else
        entries = [hBoundary, hDry, hWet];
        labels = {'Dry Case ($0$ $\mathrm{mm\,h^{-1}}$)', 'Wet Case ($>0$ $\mathrm{mm\,h^{-1}}$)\quad'};
    end

    lg = legend(entries, labels, 'Orientation', 'horizontal', 'Interpreter', 'latex');
    lg.Layout.Tile = 'north';

    if isscalar(flagNames)
        lg.Visible = "off";
        cb.Visible = "off";
        saveHeight = 4;
        saveWidth = 1/0.48;
    else
        saveHeight = 2;
        saveWidth = 1;
    end

    saveName = ['RviwFlagEvaluation' char(upper(windDomain(1))) windDomain(2:end)];
    saveName = [saveName, '_', strjoin(strrep(flagNames,' ','_'),"_")];
    saveName = strrm(saveName,["\","$","(",")",","]);
    saveFig(fig,figureFolder,saveName,saveHeight,saveWidth);
    
    function plotAndWriteDecisionBoundary(validWindAngle, validWindSpeed)
        anomalyData = [validWindAngle, validWindSpeed];
        gmmOptimizationOptions = statset('MaxIter', 1000);
        
        if false
            % BIC score testing of the ideal number of clusters
            maxClusters = 5;
            bicValues = zeros(1, maxClusters);

            for k = 1:maxClusters
                % Fit model with k clusters
                gmmTest = fitgmdist(anomalyData, k, 'Options', statset('MaxIter', 1000));
                bicValues(k) = gmmTest.BIC;
            end

            figure;
            plot(1:maxClusters, bicValues, 'b-o', 'LineWidth', 2);
            xlabel('Number of Clusters ($K$)', 'Interpreter', 'latex');
            ylabel('BIC Score', 'Interpreter', 'latex');
            title('Optimal Cluster Evaluation', 'Interpreter', 'latex');
            grid on;
            keyboard
        end

        try
            gaussianMixtureModel = fitgmdist(anomalyData, numClusters, 'Options', gmmOptimizationOptions);
            
            axisLimitsX = xlim;
            axisLimitsY = ylim;
            
            gridValuesX = linspace(axisLimitsX(1), axisLimitsX(2), 300);
            gridValuesY = linspace(axisLimitsY(1), axisLimitsY(2), 300);
            [meshGridX, meshGridY] = meshgrid(gridValuesX, gridValuesY);
            
            evaluationCoordinates = [meshGridX(:), meshGridY(:)];
            
            probabilityDensityValues = pdf(gaussianMixtureModel, evaluationCoordinates);
            probabilityDensityGrid = reshape(probabilityDensityValues, size(meshGridX));
            
            observedDensityValues = pdf(gaussianMixtureModel, anomalyData);
            contourDensityThreshold = prctile(observedDensityValues, decisionBoundaryThreshold);
            
            hold on;
            contour(meshGridX, meshGridY, probabilityDensityGrid, [contourDensityThreshold, contourDensityThreshold], 'LineColor', 'black', 'LineWidth', 1.5, 'LineStyle', '--');
            
            % --- GENERATE LATEX OUTPUT ---
            fprintf('\n%% ================= LATEX OUTPUT ================= %%\n');
            fprintf('\\begin{equation}\n');
            fprintf('    \\begin{aligned}\n');
            
            % Format tau to scientific notation (e.g., 1.08 \times 10^{-3})
            tauStr = sprintf('%0.2e', contourDensityThreshold);
            parts = strsplit(tauStr, 'e');
            baseTau = parts{1};
            expTau = num2str(str2double(parts{2})); % Removes leading zeros from exponent
            
            % Print the first line with the sum and tau
            fprintf('        p(\\mathbf{x}) &= \\sum_{k=1}^{%d} \\pi_k \\mathcal{N}(\\mathbf{x} | \\boldsymbol{\\mu}_k, \\boldsymbol{\\Sigma}_k) \\ge \\tau, \\qquad \\tau = %s \\times 10^{%s} \\\\\\\\\n', numClusters, baseTau, expTau);
            
            for k = 1:numClusters
                pi_k = gaussianMixtureModel.ComponentProportion(k);
                mu_k = gaussianMixtureModel.mu(k, :);
                sigma_k = gaussianMixtureModel.Sigma(:, :, k);
                
                % Prevent the trailing newline operator on the very last equation
                if k == numClusters
                    endLine = '\n';
                else
                    endLine = ' \\\\\\\\\n';
                end
                
                % Print Proportion, Mean Vector, and Covariance Matrix on one line
                fprintf('        \\pi_%d &= %.3f, \\quad ', k, pi_k);
                fprintf('\\boldsymbol{\\mu}_%d = \\begin{bmatrix} %.2f \\\\\\\\ %.2f \\end{bmatrix}, \\quad ', k, mu_k(1), mu_k(2));
                fprintf('\\boldsymbol{\\Sigma}_%d = \\begin{bmatrix} %.2f & %.2f \\\\\\\\ %.2f & %.2f \\end{bmatrix}%s', ...
                    k, sigma_k(1,1), sigma_k(1,2), sigma_k(2,1), sigma_k(2,2), endLine);
            end
            
            fprintf('    \\end{aligned}\n');
            fprintf('\\end{equation}\n');
            fprintf('%% ================================================ %%\n\n');
            
        catch
            fprintf('Failed to fit Gaussian Mixture Model with %d clusters.\n', numClusters);
        end
    end
end

function plotNidComparisonPeakIntensity(allStats, flagFields, limits, windDomain, figureFolder,flagNames)
    % Plots multiple RWIV parameter space validations in a tiled layout.
    arguments
        allStats 
        flagFields 
        limits 
        windDomain = 'local'
        figureFolder = ''
        flagNames = ''
    end

    if ischar(flagFields) || isstring(flagFields)
        flagFields = cellstr(flagFields);
    end
    if ~length(flagNames)>0
        flagNames = flagFields;
    elseif ischar(flagNames) || isstring(flagNames)
        flagNames = cellstr(flagNames);
    end

    numPlots = length(flagFields);
    fig = createFigure(1, 'RWIV Multi-Criteria Validation');
    tlo = tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'tight');
    
    hFill = []; % Initialize to avoid errors if windDomain is not 'local'
    bridgeFields = ["Conc_Z", "Steel_Z"];
    targetFreqs = limits.targetFreqs;

    for i = 1:numPlots
        nexttile;
        currentFlag = flagFields{i};
        flagName = flagNames{i};
        
        rain = calculateLookbackRain(currentFlag, allStats, hours(2));
        events = allStats(allStats.(currentFlag), :);
        events = events(rain < 50, :); 
        currentRain = rain(rain < 50);

        if strcmpi(windDomain, 'local')
            windSpeed = [events.UNormalC1.mean]';
            windAngle = [events.PhiC1.mean]';
        else
            windSpeed = [events.WindSpeed.mean]';
            windAngle = [events.WindDir.mean]'-18;
        end
        
        % targetF = limits.targetFreqs(2); 
        % psdData = events.psdPeaks;
        psdColumn = events.psdPeaks;
        numEvents = height(events);
        aggregateIntensity = zeros(numEvents, 1);

        for eventIdx = 1:numEvents
            currentIntensitySum = 0;
            for fldIdx = 1:length(bridgeFields)
                currentStruct = psdColumn(eventIdx).(bridgeFields(fldIdx));
                for freqTarget = targetFreqs
                    [~, closestIdx] = min(abs(currentStruct.locations - freqTarget));
                    currentIntensitySum = currentIntensitySum + exp(currentStruct.logIntensity(closestIdx));
                end
            end
            aggregateIntensity(eventIdx) = currentIntensitySum / 4;
        end

        scaleFactor = 10e+05; % based on 50 / mean(targetIntensities) of the first round.
        intensitySized = scaleFactor * aggregateIntensity;

        logIntensityFactor = 1; % 1: linear, 0 fuld log
        intensitySized = (exp(logIntensityFactor*log(intensitySized))-1)/logIntensityFactor;
        intensitySized = intensitySized - min(intensitySized)+10;

        hold on;
        if strcmpi(windDomain, 'local')
            wBounds = limits.cableWindSpeed;
            pBounds = limits.cableWindDir;
            hFill = fill([pBounds(1) pBounds(2) pBounds(2) pBounds(1)], ...
                [wBounds(1) wBounds(1) wBounds(2) wBounds(2)], ...
                [0.7 0.7 0.7], 'FaceAlpha', 0.2, ...
                'EdgeColor', [0.8 0 0], 'LineWidth', 1.1);
        end

        noRainIdxs = currentRain == 0;
        rainIdxs = ~noRainIdxs;

        scatter(windAngle(noRainIdxs), windSpeed(noRainIdxs), ...
                intensitySized(noRainIdxs), 'red', 'filled', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0);
        
        scatter(windAngle(rainIdxs), windSpeed(rainIdxs), ...
                intensitySized(rainIdxs), currentRain(rainIdxs), 'filled', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0);
        
        colormap(myColorMap());
        clim([0 25]);
        grid on; box on;
        title(sprintf('Criteria: \\texttt{%s}', strrep(flagName, '_', '\_')), 'Interpreter', 'latex');
        set(gca, 'TickLabelInterpreter', 'latex');

        if strcmpi(windDomain, 'local')
            xlim([30 150])
            ylim([0 16])
        else
            %xlim([100 260])
            xlim([0 360])
            ylim([0 16])
        end
    end
    if strcmpi(windDomain, 'local')
        xlabel(tlo, '$\Phi$ (deg)', 'Interpreter', 'latex');
        ylabel(tlo, '$U_{N}$ ($\mathrm{m\,s^{-1}}$)', 'Interpreter', 'latex');
    else
        xlabel(tlo, 'Compass wind direction (deg)', 'Interpreter', 'latex');
        ylabel(tlo, '$\bar{u}$ ($\mathrm{m\,s^{-1}}$)', 'Interpreter', 'latex');
        xlabels = cellstr(compose("$%d^\\circ$", 0:45:330));
        xlabels{1} = 'N'; xlabels{3} = '$\;$E'; xlabels{5} = 'S'; xlabels{7} = 'W';
        xticks(0:45:330)
        xticklabels(xlabels)
    end

    cb = colorbar;
    cb.Layout.Tile = 'east';
    cb.TickLabelInterpreter = 'latex';
    cb.Label.String = '$Ri_\mathrm{2h}$ ($\mathrm{mm\,h^{-1}}$)';
    cb.Label.Interpreter = 'latex';
    cb.Label.FontSize = tlo.Title.FontSize;
    clim([0 25])
    cb.Visible = "off";

    % Fix Legend: Conditional hFill and LaTeX fixes
    hDry = scatter(NaN, NaN, 50, [1 0 0], 'filled');
    hWet = scatter(NaN, NaN, 50, [0.3 0.7 0.9], 'filled');
    
    if ~isempty(hFill)
        entries = [hFill, hDry, hWet];
        xlabels = {'\texttt{Daniotti\,} Region', 'Dry Case ($0$ $\mathrm{mm\,h^{-1}}$)', 'Wet Case ($>0$ $\mathrm{mm\,h^{-1}}$)\quad'};
    else
        entries = [hDry, hWet];
        xlabels = {'Dry Case ($0$ $\mathrm{mm\,h^{-1}}$)\quad', 'Wet Case ($>0$ $\mathrm{mm\,h^{-1}}$)\quad'};
    end

    %lg = legend(entries, xlabels, 'Orientation', 'horizontal', 'Interpreter', 'latex');
    %lg.Layout.Tile = 'north';

    saveName = ['RviwFlagEvaluation_PeakIntensity' char(upper(windDomain(1))) windDomain(2:end)];
    saveName = [saveName, '_', strjoin(strrep(flagNames,' ','_'),"_")];
    saveName = strrm(saveName,["\","$","(",")",","]);
    saveFig(fig,figureFolder,saveName,4,1/0.48);

    if ~strcmpi(windDomain,'local')
        casesLowerThan150Deg = windAngle < 150;
        turb = [events.WindSpeed.std]./[events.WindSpeed.mean];
        turbLow = turb(casesLowerThan150Deg);
        turbHigh = turb(~casesLowerThan150Deg);
        % figure;
        % histogram(turbLow,20);
        % hold on
        % histogram(turbHigh,20);
        fprintf('---Turbulence intencity for events LOWER than 150 deg:---\n')
        fprintf('Mean: %2.3f, Std: %2.3f\n',mean(turbLow),std(turbLow))
        fprintf('---Turbulence intencity for events HIGHER than 150 deg:---\n')
        fprintf('Mean: %2.3f, Std: %2.3f\n',mean(turbHigh),std(turbHigh))
    end
end

function lookbackRain = calculateLookbackRain(flagField, allStats, durationLimit)
    events = allStats(allStats.(flagField),:);

    % Helper to find the maximum mean rain intensity in the preceding window
    numEvents = size(events,1);
    lookbackRain = zeros(numEvents, 1);
    
    % Extract all timestamps from the full dataset for logical indexing
    allStarts = allStats.duration(:,1);
    
    for i = 1:numEvents
        tEnd = events.duration(i,1);
        tStart = tEnd - durationLimit;
        
        % Filter allStats for segments within [tStart, tEnd]
        relevantIdx = (allStarts >= tStart) & (allStarts <= tEnd);
        relevantStats = allStats(relevantIdx,:);
        
        if ~isempty(relevantStats)
            % Extract the mean rain intensity for all segments in this window
            windowRainValues = [relevantStats.RainIntensity.mean];
            lookbackRain(i) = max(windowRainValues);
        else
            lookbackRain(i) = events.RainIntensity(i).mean;
        end
    end
end

function plotFlaggedAccVsWind(allStats, flagFields, windDomain, figureFolder)
    % Plots flagged acceleration values against wind speed in a tiled layout.
    arguments
        allStats
        flagFields
        windDomain = 'local'
        figureFolder = ''
    end

    if ischar(flagFields) || isstring(flagFields)
        flagFields = cellstr(flagFields);
    end

    numPlots = length(flagFields);
    fig = createFigure(2, 'Acceleration vs. Wind Speed Evaluation');
    tlo = tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'tight');
    fields = ["Conc_Z" "Steel_Z"];
    
    for i = 1:numPlots
        ax = nexttile;
        orderedcolors("earth");
        currentFlag = flagFields{i};
        events = allStats(allStats.(currentFlag), :);
        
        if strcmpi(windDomain, 'local')
            windSpeed = [events.UNormalC1.mean]';
        else
            windSpeed = [events.WindSpeed.mean]';
        end

        for field = fields
            hold on

            acc = abs([events.(field).max]');
            scatter(windSpeed, acc, 50, 'filled',...
                'MarkerFaceAlpha', 0.6, 'MarkerEdgeAlpha', 0,'DisplayName',field);
        end
        grid on; box on;
        
        title(sprintf('Flag: \\texttt{%s}', strrep(currentFlag, '_', '\_')), 'Interpreter', 'latex');
        set(gca, 'TickLabelInterpreter', 'latex');
        xlim([0 16])
        ylim([0 0.04])
    end

    if strcmpi(windDomain, 'local')
        xlabel(tlo, '$U_{N,C1}$ ($\mathrm{m\,s^{-1}}$)', 'Interpreter', 'latex');
    else
        xlabel(tlo, 'Mean Wind Speed ($\mathrm{m\,s^{-1}}$)', 'Interpreter', 'latex');
    end
    ylabel(tlo, 'Max Deck Acceleration ($\mathrm{m\,s^{-2}}$)', 'Interpreter', 'latex');
    legend

    fileName = ['AccVsWindEvaluation' char(upper(windDomain(1))) windDomain(2:end)];
    saveFig(fig,figureFolder,fileName);
end

function plotPeaksDistribution(allStats, limits, figureFolder,dir)
    arguments
        allStats
        limits
        figureFolder = ''
        dir = 'Z'
    end
    dir = CapitalizeText(dir);
    fields = strcat(["Conc_", "Steel_"],dir);

    scaleText = 14;
    figHandle = createFigure(3, 'Spectral Signature Distribution');
    layoutObj = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'tight');
    
    targetFrequencies = limits.targetFreqs;
    freqTolerance = limits.freqTolerance;

    for segmentIdx = 1:length(fields)
        axObj = nexttile;
        hold(axObj, 'on');
        
        peakStructArray = [allStats.psdPeaks];
        segmentPeaks = [peakStructArray.(fields(segmentIdx))];
        
        allPeakFreqs = vertcat(segmentPeaks.locations);
        allPeakSzz = exp(vertcat(segmentPeaks.logIntensity));
        
        if min(allPeakSzz) < 10^(-50)
            [~,idx] = min(allPeakSzz);
            allPeakSzz(idx) = [];
            allPeakFreqs(idx) = [];
        end

        yBins = logspace(log10(min(allPeakSzz)), log10(max(allPeakSzz)), 100);
        xBins = linspace(min(allPeakFreqs), max(allPeakFreqs), 200);

        histogram2(axObj, allPeakFreqs, allPeakSzz, xBins, yBins, ...
            'DisplayStyle', 'tile', 'ShowEmptyBins', 'off', 'EdgeColor', 'none');
        
        set(axObj, 'YScale', 'log', 'ColorScale', 'log', ...
            'FontSize', scaleText, 'TickLabelInterpreter', 'latex');
        
        for fTarget = targetFrequencies
            xline(axObj, fTarget, '--', 'Color', [0.8 0 0], 'LineWidth', 1.2, ...
                'Label', sprintf('$f_{target} = %.2f$ Hz', fTarget), ...
                'Interpreter', 'latex', 'FontSize', scaleText,'LabelOrientation','horizontal');
            
            patch(axObj, [fTarget - freqTolerance, fTarget + freqTolerance, ...
                          fTarget + freqTolerance, fTarget - freqTolerance], ...
                [min(allPeakSzz) min(allPeakSzz) max(allPeakSzz) max(allPeakSzz)], ...
                'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end

        grid(axObj, 'on'); box(axObj, 'on');
        ylabel(axObj, sprintf('%s $S_{zz}$ ($\\mathrm{m^2/s^4/Hz}$)', strrep(fields(segmentIdx), '_', '\_')), ...
            'Interpreter', 'latex', 'FontSize', scaleText);
        
        axis(axObj, 'tight');
        xlim(axObj, [0 10]);
    end
    
    xlabel(layoutObj, 'Frequency (Hz)', 'Interpreter', 'latex', 'FontSize', scaleText);
    title(layoutObj, 'Log-Density Bivariate Distribution of Identified PSD Peaks', ...
        'Interpreter', 'latex', 'FontSize', scaleText + 2);
    
    colormap(figHandle, "nebula");
    cbHandle = colorbar;
    cbHandle.Layout.Tile = 'east';
    cbHandle.TickLabelInterpreter = 'latex';
    cbHandle.FontSize = scaleText;
    cbHandle.Label.String = 'Identification Density (Log Scale)';
    cbHandle.Label.Interpreter = 'latex';
    cbHandle.Label.FontSize = scaleText;
    
    fileName = ['BridgeSpectralSignatureDistribution' dir 'Direction'];
    saveFig(figHandle,figureFolder,fileName,2)
end

function plotPeaksDistributionAllDir(allStats, limits, figureFolder)
    arguments
        allStats
        limits
        figureFolder = ''
    end
    
    scaleText = 10;
    figHandle = createFigure(3, 'Spectral Signature Distribution');
    layoutObj = tiledlayout(2, 6, 'TileSpacing', 'compact', 'Padding', 'tight');
    
    locations = ["Conc", "Steel"];
    locationNames = ["DC", "DS"];
    directions = ["X", "Y", "Z"];
    cableModeNr = [3,6];
    targetFrequencies = limits.targetFreqs;
    freqTolerance = limits.freqTolerance;
    
    zoomSpan = freqTolerance * 3; 

    for locIdx = 1:length(locations)
        loc = locations(locIdx);
        locName = locationNames(locIdx);
        
        for dirIdx = 1:length(directions)
            direction = directions(dirIdx);
            fieldName = sprintf('%s_%s', loc, direction);
            
            peakStructArray = [allStats.psdPeaks];
            if ~isfield(peakStructArray, fieldName)
                continue;
            end
            segmentPeaks = [peakStructArray.(fieldName)];
            
            allPeakFreqs = vertcat(segmentPeaks.locations);
            allPeakSzz = exp(vertcat(segmentPeaks.logIntensity));
            
            validIdx = allPeakSzz > 1e-50;
            allPeakFreqs = allPeakFreqs(validIdx);
            allPeakSzz = allPeakSzz(validIdx);
            
            if isempty(allPeakSzz)
                yMin = 1e-10; yMax = 1;
            else
                yMin = min(allPeakSzz); yMax = max(allPeakSzz);
            end
            yBins = logspace(log10(yMin), log10(yMax), 100);
            
            for fIdx = 1:length(targetFrequencies)
                fTarget = targetFrequencies(fIdx);
                
                tileNum = (locIdx - 1) * 6 + (dirIdx - 1) * 2 + fIdx;
                axObj = nexttile(tileNum);
                hold(axObj, 'on');
                
                dfBin = 0.025;
                xBins = (fTarget - zoomSpan) : dfBin : (fTarget + zoomSpan);

                histogram2(axObj, allPeakFreqs, allPeakSzz, xBins, yBins, ...
                    'DisplayStyle', 'tile', 'ShowEmptyBins', 'off', 'EdgeColor', 'none');
                
                histogram2(axObj, allPeakFreqs, allPeakSzz, xBins, yBins, ...
                    'DisplayStyle', 'tile', 'ShowEmptyBins', 'off', 'EdgeColor', 'none');
                
                set(axObj, 'YScale', 'log', 'ColorScale', 'log', ...
                    'FontSize', scaleText, 'TickLabelInterpreter', 'latex');
                
                xline(axObj, fTarget, '--', 'Color', [0.8 0 0], 'LineWidth', 1.2, ...
                    'Interpreter', 'latex');
                
                patch(axObj, [fTarget - freqTolerance, fTarget + freqTolerance, ...
                              fTarget + freqTolerance, fTarget - freqTolerance], ...
                    [yMin yMin yMax yMax], ...
                    'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                
                grid(axObj, 'on'); box(axObj, 'on');
                xlim(axObj, [fTarget - zoomSpan, fTarget + zoomSpan]);
                ylim(axObj, [yMin yMax]);
                
                if locIdx == 1
                    title(axObj, sprintf('%s-Dir -- $f_{T%d}$', direction, cableModeNr(fIdx)), ...
                        'Interpreter', 'latex', 'FontSize', scaleText);
                end
                
                if dirIdx == 1 && fIdx == 1
                    ylabel(axObj, sprintf('%s', locName), ...
                        'Interpreter', 'latex', 'FontSize', scaleText + 2);
                else
                    yticklabels(axObj, {});
                end
                
                if locIdx == 1
                    xticklabels(axObj, {});
                end
            end
        end
    end
    
    xlabel(layoutObj, 'Frequency (Hz)', 'Interpreter', 'latex', 'FontSize', scaleText);
    ylabel(layoutObj, 'Power Spectral Density $S_{zz}$ ($\mathrm{m^2/s^4/Hz}$)', ...
        'Interpreter', 'latex', 'FontSize', scaleText);
    title(layoutObj, 'Log-Density Bivariate Distribution of Identified PSD Peaks in Vicinity of Target Frequencies', ...
        'Interpreter', 'latex', 'FontSize', scaleText + 2);
    
    colormap(figHandle, "nebula");
    cbHandle = colorbar;
    cbHandle.Layout.Tile = 'east';
    cbHandle.TickLabelInterpreter = 'latex';
    cbHandle.FontSize = scaleText;
    cbHandle.Label.String = 'Identification Density (Log Scale)';
    cbHandle.Label.Interpreter = 'latex';
    cbHandle.Label.FontSize = scaleText;
    
    fileName = 'BridgeSpectralSignatureDistribution_AllDir';
    saveFig(figHandle, figureFolder, fileName, 2);
end

function plotCoherenceDistribution(allStats, limits, figureFolder)
    arguments
        allStats
        limits
        figureFolder = ''
    end
    
    scaleText = 14;
    figHandle = createFigure(4, 'Coherence Signature Distribution');
    layoutObj = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'tight');
    
    targetFreqs = limits.targetCoherenceFreq;
    cohLimits = limits.coherenceLimit;
    
    coherenceMatrix = [allStats.cohVals{:}];

    for i = 1:length(targetFreqs)
        axObj = nexttile;
        hold(axObj, 'on');
        
        currentData = coherenceMatrix(i, :);
        
        histogram(axObj, currentData, 'BinWidth', 0.01, ...
            ...%'FaceAlpha', 0.6, 'EdgeColor', 'none', ...
            'DisplayName', sprintf('Observed $\\gamma^2$ at %.2f Hz', targetFreqs(i)));
        
        xline(axObj, cohLimits(i), '--', 'Color', [0.8 0 0], 'LineWidth', 1.2, ...
            'Label', sprintf('Limit: %.2f', cohLimits(i)), ...
            'Interpreter', 'latex', 'FontSize', scaleText,'LabelOrientation','horizontal');
        
        set(axObj, 'FontSize', scaleText, 'TickLabelInterpreter', 'latex');
        grid(axObj, 'on'); box(axObj, 'on');
        
        
        title(axObj, sprintf('Coherence Distribution at $f = %.2f$ Hz', targetFreqs(i)), ...
            'Interpreter', 'latex', 'FontSize', scaleText);
        
        xlim(axObj, [-1 1]);
    end
    ylabel(layoutObj, 'Count', 'Interpreter', 'latex', 'FontSize', scaleText);
    xlabel(layoutObj, 'Coherence $\gamma$', 'Interpreter', 'latex', 'FontSize', scaleText);
    
    fileName = 'BridgeCoherenceThresholdDistribution';
    saveFig(figHandle,figureFolder,fileName)
end

function plotRwivGlobalProbability(allStats, flagFields, figureFolder, fileName, toggleTitle, timeRange)
    % plotRwivGlobalProbability Evaluates and plots the probability of given flag fields.
    % Optional timeRange parameter accepts a cell array of [startTime, endTime] datetime 
    % boundaries for each corresponding flagField to evaluate probabilities over specific periods.
    
    arguments
        allStats table
        flagFields (1,:) string
        figureFolder (1,1) string = ""
        fileName (1,1) string = "RwivGlobalProbabilityStudy"
        toggleTitle (1,1) logical = true
        timeRange cell = {}
    end

    figHandle = createFigure(4, "RWIV Global Probability Summary");
    axMain = axes(figHandle);
    hold(axMain, "on");

    [probabilities, observationCounts] = calculateProbabilities(allStats, flagFields, timeRange);

    barGroup = bar(axMain, probabilities, "FaceColor", "flat");
    
    applyBarColors(barGroup, flagFields);
    addBarLabels(axMain, probabilities);
    formatAxes(axMain, flagFields, observationCounts);

    if toggleTitle
        addPlotTitle(axMain, observationCounts);
    end

    saveFig(figHandle, figureFolder, fileName);
end

function [probabilities, observationCounts] = calculateProbabilities(allStats, flagFields, timeRange)
    numFlags = length(flagFields);
    probabilities = zeros(1, numFlags);
    observationCounts = zeros(1, numFlags);
    hasTimeRange = ~isempty(timeRange);

    for i = 1:numFlags
        currentFlagName = flagFields(i);
        currentStats = allStats;
        Time = mean(currentStats.duration,2);
        if hasTimeRange && ~isempty(timeRange{i})
            currentRange = timeRange{i};
            timeMask = Time >= currentRange(1) & Time <= currentRange(2);
            currentStats = currentStats(timeMask, :);
        end

        observationCounts(i) = height(currentStats);
        if observationCounts(i) > 0
            probabilities(i) = (sum(currentStats.(currentFlagName)) / observationCounts(i)) * 100;
        end
    end
end

function applyBarColors(barGroup, flagFields)
    blueColor = [0.2 0.4 0.6];
    redColor = [0.6 0.2 0.2];

    for i = 1:length(flagFields)
        if contains(flagFields(i), "env", "IgnoreCase", true) || ...
           contains(flagFields(i), "Wind", "IgnoreCase", true) || ...
           contains(flagFields(i), "Rain", "IgnoreCase", true)
            barGroup.CData(i, :) = redColor;
        else
            barGroup.CData(i, :) = blueColor;
        end
    end
end

function addBarLabels(axMain, probabilities)
    for i = 1:length(probabilities)
        text(axMain, i, probabilities(i), ...
            sprintf("%.2f\\%%", probabilities(i)), ...
            "VerticalAlignment", "bottom", ...
            "HorizontalAlignment", "center", ...
            "Interpreter", "latex");
    end
end

function formatAxes(axMain, flagFields, observationCounts)
    axMain.YLim(2) = axMain.YLim(2) * 1.05; 
    grid(axMain, "on"); 
    box(axMain, "on");
    
    ylabel(axMain, "Global Probability (\%)", "Interpreter", "latex");
    
    xLabels = strrep(flagFields, "_", "\_");
    set(axMain, "XTick", 1:length(flagFields), "XTickLabel", xLabels, ...
        "TickLabelInterpreter", "latex");

    if all(observationCounts == observationCounts(1)) && observationCounts(1) > 0
        totalDataHours = observationCounts(1) * (1/6);
        
        yyaxis(axMain, "right");
        ylabel(axMain, "Total Duration (Hours)", "Interpreter", "latex");
        axMain.YAxis(2).Color = [0 0 0];
        
        scalingFactor = totalDataHours / 100;
        axMain.YAxis(2).Limits = axMain.YAxis(1).Limits * scalingFactor;
    end
end

function addPlotTitle(axMain, observationCounts)
    if all(observationCounts == observationCounts(1)) && observationCounts(1) > 0
        totalDataHours = observationCounts(1) * (1/6);
        titleStr = {
            "\textbf{RWIV Detection Probability Summary}";
            sprintf("Total Dataset Duration: %.1f Hours (%d 10-min Segments)", totalDataHours, observationCounts(1))
        };
    else
        titleStr = "\textbf{RWIV Detection Probability Summary (Variable Time Ranges)}";
    end
    
    title(axMain, titleStr, "Interpreter", "latex");
end

function plotWindRoses(allStats,figureFolder,minWindSpeed,binWindSize,maxWindSpeed)
arguments
    allStats 
    figureFolder {mustBeText}
    minWindSpeed = 6;
    binWindSize = 3;
    maxWindSpeed = 22;
end

windSpeeds = [allStats.WindSpeed.mean];
windAngle = [allStats.WindDir.mean];

fig = createFigure(11, 'Wind Roses');
tlc = tiledlayout('flow','TileSpacing','compact','Padding','compact');
nt = nexttile;

idx = windSpeeds >= minWindSpeed;
filteredWindSpeeds = windSpeeds(idx);
filteredAngles = windAngle(idx) - 18;

labels = cellstr(compose("$%d^\\circ$", 0:30:330));
labels{1} = 'N'; labels{4} = '$\;$E'; labels{7} = 'S'; labels{10} = 'W';

speedBins = minWindSpeed:binWindSize:maxWindSpeed;
WindRose(filteredAngles, filteredWindSpeeds, ...
    'axes', nt, ...
    'vWinds', speedBins, ...
    'colormap', sky, ...
    'legendvariable', '\bar{u}', ...
    'freqlabelangle', 30, ...
    'facealpha', 1, ...
    'gridalpha', 0.1, ...
    'labels', labels, ...
    'legendposition', 'southeastoutside',...
    'titlestring','', ...
    'lablegend', '$\bar{u}\, \mathrm{(m\,s^{-1})}$');%, ...
    %...%'logscale', true,...
    %...%'logfactor', 100, ...
    %'freqs', [0.2, 2, 5, 15]);

legend('boxoff');
hold on;
addBridgeAxisAndCriticalRegions()

nt = nexttile;
windSpeedStd = [allStats.WindSpeed.std];
turbulenceIntensity = (windSpeedStd(idx)./filteredWindSpeeds)*100;

idx = turbulenceIntensity < 50;
filteredTis = turbulenceIntensity(idx);

labels = cellstr(compose("$%d^\\circ$", 0:30:330));
labels{1} = 'N'; labels{4} = '$\;$E'; labels{7} = 'S'; labels{10} = 'W';

speedBins = 0:10:50;

WindRose(filteredAngles(idx), filteredTis, ...
    'axes', nt, ...
    'vWinds', speedBins, ...
    'colormap', sky, ...
    'legendvariable', 'I_u (\%)', ...
    'freqlabelangle', 30, ...
    'facealpha', 1, ...
    'gridalpha', 0.1, ...
    'labels', labels, ...
    'legendposition', 'southeastoutside',...
    'titlestring','', ...
    'lablegend', '$I_u\, (\%)$', ...
    'logscale', true, ...
    'logfactor', 100, ...
    'freqs', [0.5, 1.5, 5, 15]);

legend('boxoff');
hold on;

addBridgeAxisAndCriticalRegions()

fileName = 'WindRoses';
figureHeight = 2.2;
saveFig(fig, figureFolder, fileName,figureHeight);

    function addBridgeAxisAndCriticalRegions()
        bridgeAngles = [-18, -18 + 180];
        xLine = sind(bridgeAngles);
        yLine = cosd(bridgeAngles);
        plot(xLine, yLine, 'k-', 'LineWidth', 2,'HandleVisibility','off');

        inclinationCable = 29.8; %deg
        critCableAngles = [45 60];
        critAnglesVaisala = acosd(cosd(critCableAngles)./cosd(inclinationCable));
        critAnglesCompass = [360-critAnglesVaisala+bridgeAngles(1);
                                 critAnglesVaisala+bridgeAngles(1)]+180;
        ax = gca; R = max(abs([ax.XLim, ax.YLim]));

        for i = 1:size(critAnglesCompass, 1)
            ang1 = critAnglesCompass(i, 1);
            ang2 = critAnglesCompass(i, 2);

            arcAngles = linspace(ang1, ang2, 50);

            xPatch = [0, R * sind(arcAngles), 0];
            yPatch = [0, R * cosd(arcAngles), 0];

            p = patch(xPatch, yPatch, 'red', ...
                'FaceAlpha', 0.2, ...
                'EdgeColor', 'none', ...
                'HandleVisibility', 'off');

            uistack(p, 'bottom');
        end
    end
end

function plotRiwvWeatherScatter3D(allStats, limits, figureFolder,flagName)
% Generates a 3D scatter plot to visualize meteorological conditions relative to cable geometry.
% X-axis: Time, Y-axis: Cable-Wind Angle (Phi), Z-axis: Normal Wind Speed (u_N).
% Marker shapes differentiate between rainy (diamond) and dry (circle) conditions.
arguments
    allStats
    limits
    figureFolder
    flagName = 'flag_EnvironmentalMatch'
end

if isempty(allStats)
    return;
end


timeVector = mean(allStats.duration,2);
normalWindSpeed = [allStats.UNormalC1.mean];
normalWindSpeed = [allStats.WindSpeed.mean];
cableWindAngle = [allStats.PhiC1.mean];
rainIntensity = [allStats.RainIntensity.mean];
isCritical = allStats.(flagName);

hasRain = (rainIntensity >= limits.rainLowerLimit)';
hasRainAndNonFlagged = hasRain & ~isCritical;

isDry = ~hasRain;
isDryAndNonFlagged = isDry & ~isCritical;

weatherFigure = createFigure(103, 'RWIV Weather 3D Scatter');
hold on;

coverageTable = getDataConverageTable('noplot');
coverageTime = coverageTable.Date;
coverage = coverageTable.BridgeCoverage;
area([min(timeVector) max(timeVector)],[360 360], 'FaceColor', 'red', ...
            'faceAlpha',0.1,'EdgeColor', 'none', 'HandleVisibility', 'off')
    hold on
area(coverageTime,coverage*max(normalWindSpeed),'FaceColor','green',...
    'FaceAlpha',0.1,'EdgeColor','none','HandleVisibility','off')

scatter(timeVector(isDryAndNonFlagged), normalWindSpeed(isDryAndNonFlagged), ...
    30, 'o', 'filled','MarkerFaceAlpha',0.3, 'DisplayName', 'Dry, Noncritical');

scatter(timeVector(hasRainAndNonFlagged), normalWindSpeed(hasRainAndNonFlagged), ...
    30, 'o', 'filled','MarkerFaceAlpha',0.3, 'DisplayName', 'Rainy, Noncritical');

scatter(timeVector(isCritical), normalWindSpeed(isCritical), ...
    30, 'o', 'red', 'filled','MarkerFaceAlpha',0.3, 'DisplayName', 'Daniotti (2021) Critical');

%view([-35, 25]);
grid on;
box on;
ylim([0 max(normalWindSpeed)])
xlim([min(timeVector) max(timeVector)])
ylabel('$\bar{u}$ ($\mathrm{m\,s^{-1}}$)');

%legend('Location', 'northoutside','Orientation','horizontal');
map = colororder(weatherFigure, 'earth');
hDry  = scatter(NaN, NaN, 30, 'filled');
hWet  = scatter(NaN, NaN, 30, 'filled');
hCrit = scatter(NaN, NaN, 30, 'red', 'filled');

entries = [hDry, hWet,hCrit];
labels = {'Dry, Noncritical', 'Rainy, Noncritical', '\texttt{Daniotti\,} Critical'};

legend(entries, labels, 'Orientation', 'horizontal', ...
        'Interpreter', 'latex','Location','northoutside');

saveFig(weatherFigure, figureFolder, 'Weather_RWIV_NidCritScatter',4,1/0.7);

fprintf('Ratio of critical NID cases are: %2.4f%%\n',sum(isCritical)/length(isCritical)*100)
end

function plotRwivWindSpeedVsTime(allStats,flagFields,figureFolder,limits,flagNames)
arguments
    allStats 
    flagFields 
    figureFolder 
    limits
    flagNames = ''
end

if ischar(flagFields) || isstring(flagFields)
    flagFields = cellstr(flagFields);
end
if ~length(flagNames)>0
    flagNames = flagFields;
elseif ischar(flagNames) || isstring(flagNames)
    flagNames = cellstr(flagNames);
end

numFields = length(flagFields);
windSpeed = [allStats.WindSpeed.mean];
windAngle = [allStats.WindDir.mean];
bridgeFields = ["Conc_Z", "Steel_Z"];
targetFreqs = limits.targetFreqs;

coverageTable = getDataConverageTable('noplot');
coverageTime = coverageTable.Date;
coverage = coverageTable.BridgeCoverage;

fig = createFigure(13,'Rwiv cases vs time');
tlc = tiledlayout(numFields,1,'TileSpacing','compact','Padding','compact');

for i = 1:length(flagFields)
    field    = flagFields{i};
    critName = flagNames{i};
    ax = nexttile;
    mask = allStats.(field);


    timeData = mean(allStats.duration(allStats.(field),:),2);
    speedData = windSpeed(mask);
    angleData = windAngle(mask)-18;

    psdColumn = allStats.psdPeaks(mask);
    numEvents = height(allStats(mask,:));
    aggregateIntensity = zeros(numEvents, 1);

    for eventIdx = 1:numEvents
        currentIntensitySum = 0;
        for fldIdx = 1:length(bridgeFields)
            currentStruct = psdColumn(eventIdx).(bridgeFields(fldIdx));
            for freqTarget = targetFreqs
                [~, closestIdx] = min(abs(currentStruct.locations - freqTarget));
                currentIntensitySum = currentIntensitySum + exp(currentStruct.logIntensity(closestIdx));
            end
        end
        aggregateIntensity(eventIdx) = currentIntensitySum / 4;
    end
    scaleFactor = 10e+05; % based on 50 / mean(targetIntensities) of the first round.
    intensitySized = scaleFactor * aggregateIntensity;
    
    logIntensityFactor = 1; % 1: linear, 0 fuld log
    intensitySized = (exp(logIntensityFactor*log(intensitySized))-1)/logIntensityFactor;
    intensitySized = intensitySized - min(intensitySized)+10;

    area(ax,[min(timeData) max(timeData)],[360 360], 'FaceColor', 'red', ...
            'faceAlpha',0.2,'EdgeColor', 'none', 'HandleVisibility', 'off')
    hold on
    area(ax,coverageTime,coverage*360,'FaceColor','green',...
        'FaceAlpha',0.4,'EdgeColor','none','HandleVisibility','off')
    scatter(ax, timeData, angleData, intensitySized, speedData, 'filled', 'MarkerFaceAlpha', 0.7);

    grid(ax, 'on');
    xlabel('Time','Interpreter','latex')
    ylabel(ax, 'Compass wind direction (deg)','Interpreter','latex');
    title(ax, sprintf('Criteria: $\\texttt{%s}$', strrep(critName,'_','\_')),'Interpreter','latex');

    cb = colorbar;
    ylabel(cb, '$\bar{u}$ $\mathrm{(m\,s^{-1})}$','Interpreter','latex');
    cb.TickLabelInterpreter = 'latex';
    cb.Label.Interpreter = 'latex';
    colormap(ax,nebula);
    clim(ax, [-inf, inf]);
    %ylim([100 260])
    ylim([0 360])
    xlim([min(timeData) max(timeData)])
    
    ylabels = cellstr(compose("$%d^\\circ$", 0:45:330));
    ylabels{1} = 'N'; ylabels{3} = '$\;$E'; ylabels{5} = 'S'; ylabels{7} = 'W';
    yticks(0:45:330)
    yticklabels(ylabels)

end

saveName = 'RwivCasesVSTimeOfYear';
saveName = [saveName, '_', strjoin(strrep(flagNames,' ','_'),"_")];
saveName = strrm(saveName,["\","$","(",")",","]);

saveFig(fig,figureFolder,saveName,4,1/0.48);
end

function plotDAuteuilComparison(allStats, flagField, flagName, cableInclinationAngle, figureFolder, csvFilePath, datastyle)
    arguments
        allStats
        flagField string
        flagName string
        cableInclinationAngle double
        figureFolder string = ''
        csvFilePath string = 'DAuteuil_Fig1_Data.csv'
        datastyle string = 'boxplot'
    end

    historicalDataTable = readtable(csvFilePath, 'TextType', 'string');
    comparisonFigure = createFigure(420, 'RWIV D''Auteuil Comparison');
    axesObject = axes(comparisonFigure);
    hold(axesObject, 'on');

    uniqueReferencesArray = unique(historicalDataTable.Reference);
    numberOfReferences = length(uniqueReferencesArray);
    
    legendHandlesArray = gobjects(0);
    legendLabelsArray = strings(0);

    for referenceIndex = 1:numberOfReferences
        currentReferenceName = uniqueReferencesArray(referenceIndex);
        referenceDataSubset = historicalDataTable(historicalDataTable.Reference == currentReferenceName, :);
        
        positiveObservationsSubset = referenceDataSubset(referenceDataSubset.RWIV_Observed == 1, :);
        negativeObservationsSubset = referenceDataSubset(referenceDataSubset.RWIV_Observed == 0, :);
        
        [currentMarkerStyle, currentMarkerColor] = getReferenceStyle(currentReferenceName);
        if strcmpi(currentReferenceName,'Bosdogianni and Olivari 1996')
            currentReferenceName = 'Bosdogianni and Olivari 1996\quad';
        end
        
        if height(positiveObservationsSubset) > 0
            positiveScatterHandle = scatter(axesObject, positiveObservationsSubset.Yaw_Angle_deg, positiveObservationsSubset.Inclination_Angle_deg, ...
                60, currentMarkerStyle, 'MarkerFaceColor', currentMarkerColor, 'MarkerEdgeColor', currentMarkerColor, ...
                'DisplayName', currentReferenceName);
            
            legendHandlesArray(end+1) = positiveScatterHandle;
            legendLabelsArray(end+1) = currentReferenceName;
        end
        
        if height(negativeObservationsSubset) > 0
            scatter(axesObject, negativeObservationsSubset.Yaw_Angle_deg, negativeObservationsSubset.Inclination_Angle_deg, ...
                60, currentMarkerStyle, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', currentMarkerColor, ...
                'HandleVisibility', 'off');
        end
    end

    flaggedEventsTable = allStats(allStats.(flagField), :);

    if height(flaggedEventsTable) > 0
        lookbackRainIntensityArray = calculateLookbackRain(flagField, allStats, hours(2));
        wetConditionIndicesArray = lookbackRainIntensityArray > 0;
        flaggedEventsTable = flaggedEventsTable(wetConditionIndicesArray, :);
    end

    if height(flaggedEventsTable) > 0
        % cableWindAngleMeanArray = [flaggedEventsTable.PhiC1.mean]';
        % 
        % cosineRatioArray = cosd(cableWindAngleMeanArray) ./ cosd(cableInclinationAngle);
        % cosineRatioArray = max(min(cosineRatioArray, 1), -1); 
        % calculatedYawAnglesArray = acosd(cosineRatioArray);
        
        rawYawAnglesArray = [flaggedEventsTable.WindDir.mean]';
        
        calculatedYawAnglesArray = {rawYawAnglesArray(rawYawAnglesArray < 180)-90,...
                                    (rawYawAnglesArray(rawYawAnglesArray > 180)-270)*(-1)};
        legendNames = {'Current Study ($\theta \approx 30^\circ$, SE winds)$\qquad$',...
                       'Current Study ($\theta \approx 30^\circ$, SW winds)$\qquad$'};

        studyColor = [0.55 0.77 0.94];
        lineStyles = {'--',':'};

        currentStudyGraphicsHandlesArray = gobjects(0);
        
        for i = 1:2
            if strcmpi(datastyle, 'boxplot')
                addBoxPlot(axesObject,lineStyles{i},...
                            studyColor,currentStudyGraphicsHandlesArray,...
                            cableInclinationAngle,calculatedYawAnglesArray{i},...
                            legendNames{i});
            elseif contains(datastyle, 'violin', 'IgnoreCase', true)
                addViolinPlot(axesObject,...
                                        lineStyles{i},studyColor,...
                                        currentStudyGraphicsHandlesArray,...
                                        cableInclinationAngle,...
                                        calculatedYawAnglesArray{i},...
                                        legendNames{i});
                uistack(currentStudyGraphicsHandlesArray, 'bottom');
            end
        end
    end

    grid(axesObject, 'on');
    box(axesObject, 'on');
    
    xlim(axesObject, [-50 90]);
    ylim(axesObject, [0 60]);
    set(axesObject, 'TickLabelInterpreter', 'latex');
    xlabel(axesObject, 'Yaw angle, $\beta$ (deg)', 'Interpreter', 'latex');
    ylabel(axesObject, 'Inclination angle, $\theta$ (deg)', 'Interpreter', 'latex');
    title(axesObject, sprintf('Criteria: \\texttt{%s}', strrep(flagName, '_', '\_')), 'Interpreter', 'latex');
    
    lg = legend('Interpreter', 'latex', 'Location', 'eastoutside','FontSize',8);

    figureSaveName = sprintf('DAuteuil_Comparison_%s', flagField);
    figureSaveName = strrep(figureSaveName, '\', '');
    saveFig(comparisonFigure,figureFolder,figureSaveName,2.7,1,lg)

    function addBoxPlot(axesObject,lineStyle,studyColor,...
                currentStudyGraphicsHandlesArray,cableInclinationAngle,calculatedYawAnglesArray, legendName)

        firstQuartileValue = prctile(calculatedYawAnglesArray, 25);
            thirdQuartileValue = prctile(calculatedYawAnglesArray, 75);
            medianValue = median(calculatedYawAnglesArray);
            minimumWhiskerValue = min(calculatedYawAnglesArray);
            maximumWhiskerValue = max(calculatedYawAnglesArray);
            
            boxHeightSpan = 1.5;
            lowerBoxEdgeY = cableInclinationAngle - (boxHeightSpan / 2);
            
            boxFillHandle = fill(axesObject, [firstQuartileValue thirdQuartileValue thirdQuartileValue firstQuartileValue], ...
                 [lowerBoxEdgeY lowerBoxEdgeY lowerBoxEdgeY+boxHeightSpan lowerBoxEdgeY+boxHeightSpan], ...
                 studyColor, 'FaceAlpha', 0.8, 'LineStyle',lineStyle, 'LineWidth', 1.5, ...
                 'DisplayName', legendName);
            currentStudyGraphicsHandlesArray(end+1) = boxFillHandle;
                 
            medianLineHandle = plot(axesObject, [medianValue medianValue], [lowerBoxEdgeY lowerBoxEdgeY+boxHeightSpan], ...
                 'Color', studyEdgeColor, 'LineWidth', 2.5, 'HandleVisibility', 'off');
            currentStudyGraphicsHandlesArray(end+1) = medianLineHandle;
                 
            whiskerLineOneHandle = plot(axesObject, [minimumWhiskerValue firstQuartileValue], [cableInclinationAngle cableInclinationAngle], ...
                 'Color', studyEdgeColor, 'LineWidth', 1.5, 'LineStyle', '--', 'HandleVisibility', 'off');
            currentStudyGraphicsHandlesArray(end+1) = whiskerLineOneHandle;
            
            whiskerLineTwoHandle = plot(axesObject, [thirdQuartileValue maximumWhiskerValue], [cableInclinationAngle cableInclinationAngle], ...
                 'Color', studyEdgeColor, 'LineWidth', 1.5, 'LineStyle', '--', 'HandleVisibility', 'off');
            currentStudyGraphicsHandlesArray(end+1) = whiskerLineTwoHandle;
                 
            whiskerCapOneHandle = plot(axesObject, [minimumWhiskerValue minimumWhiskerValue], [cableInclinationAngle-0.5 cableInclinationAngle+0.5], ...
                 'Color', studyEdgeColor, 'LineWidth', 1.5, 'HandleVisibility', 'off');
            currentStudyGraphicsHandlesArray(end+1) = whiskerCapOneHandle;
            
            whiskerCapTwoHandle = plot(axesObject, [maximumWhiskerValue maximumWhiskerValue], [cableInclinationAngle-0.5 cableInclinationAngle+0.5], ...
                 'Color', studyEdgeColor, 'LineWidth', 1.5, 'HandleVisibility', 'off');
            currentStudyGraphicsHandlesArray(end+1) = whiskerCapTwoHandle;
    end
    
    function addViolinPlot(axesObject,lineStyle,studyColor,...
                    currentStudyGraphicsHandlesArray,cableInclinationAngle,calculatedYawAnglesArray,legendName)
        
            [probabilityDensityArray, densityEvaluationPointsArray] = ksdensity(calculatedYawAnglesArray);
            
            maximumDensityValue = max(probabilityDensityArray);
            violinMaximumVerticalSpan = 5.0;
            scaledDensityArray = (probabilityDensityArray ./ maximumDensityValue) * (violinMaximumVerticalSpan / 2);
            
            upperViolinBoundaryY = cableInclinationAngle + scaledDensityArray;
            lowerViolinBoundaryY = cableInclinationAngle - scaledDensityArray;
            
            violinPolygonX = [densityEvaluationPointsArray, fliplr(densityEvaluationPointsArray)];
            violinPolygonY = [upperViolinBoundaryY, fliplr(lowerViolinBoundaryY)];
            
            violinFillHandle = fill(axesObject, violinPolygonX, violinPolygonY, studyColor, ...
                 'FaceAlpha', 0, 'LineWidth', 1.5, ...
                 'DisplayName', legendName,'LineStyle',lineStyle);
            currentStudyGraphicsHandlesArray(end+1) = violinFillHandle;
                 
            % firstQuartileValue = prctile(calculatedYawAnglesArray, 25);
            % thirdQuartileValue = prctile(calculatedYawAnglesArray, 75);
            % medianValue = median(calculatedYawAnglesArray);
            
            % quartileLineHandle = plot(axesObject, [firstQuartileValue thirdQuartileValue], [cableInclinationAngle cableInclinationAngle], ...
            %      'Color', studyEdgeColor, 'LineWidth', 3.0, 'HandleVisibility', 'off');
            % currentStudyGraphicsHandlesArray(end+1) = quartileLineHandle;
            % 
            % medianScatterHandle = scatter(axesObject, medianValue, cableInclinationAngle, 40, 'MarkerFaceColor', 'white', ...
            %         'MarkerEdgeColor', studyEdgeColor, 'LineWidth', 1.2, 'HandleVisibility', 'off');
            % currentStudyGraphicsHandlesArray(end+1) = medianScatterHandle;
    end

    function [markerStyle, markerColor] = getReferenceStyle(referenceName)
        switch referenceName
            case 'Bosdogianni and Olivari 1996'
                markerStyle = 'o';
                markerColor = [0.00, 0.45, 0.74];
            case 'Cosentino et al. 2013'
                markerStyle = 's';
                markerColor = [0.93, 0.69, 0.13];
            case 'Flamand 1995'
                markerStyle = '^';
                markerColor = [0.47, 0.67, 0.19];
            case 'Gao et al. 2018'
                markerStyle = 'v';
                markerColor = [0.30, 0.75, 0.93];
            case 'Ge et al. 2018'
                markerStyle = '<';
                markerColor = [0.64, 0.08, 0.18];
            case 'Georgakis et al. 2013'
                markerStyle = '>';
                markerColor = [0.85, 0.33, 0.10];
            case 'Gu and Du 2005'
                markerStyle = 'd';
                markerColor = [0.93, 0.69, 0.13];
            case 'Hikami and Shiraishi 1988'
                markerStyle = 'p';
                markerColor = [0.47, 0.67, 0.19];
            case 'Jing et al. 2018'
                markerStyle = 'o';
                markerColor = [0.64, 0.08, 0.18];
            case 'Katsuchi et al. 2017'
                markerStyle = 's';
                markerColor = [0.00, 0.45, 0.74];
            case 'Larose and Smitt 1999'
                markerStyle = '^';
                markerColor = [0.00, 0.00, 0.00];
            case 'Li et al. 2010'
                markerStyle = 'v';
                markerColor = [0.49, 0.18, 0.56];
            case 'Matsumoto et al. 1990'
                markerStyle = '<';
                markerColor = [0.50, 0.50, 0.00];
            case 'Vinayagamurthy et al. 2013'
                markerStyle = '>';
                markerColor = [0.30, 0.75, 0.93];
            case 'Zhan et al. 2018'
                markerStyle = 'd';
                markerColor = [0.00, 0.45, 0.74];
            otherwise
                markerStyle = 'o';
                markerColor = [0.50, 0.50, 0.50];
        end
    end
end



%% Old plotting routines that needs to be updated to the new way the data is stored
function plotTimeSinceRain(events, allStats)
    % Figure Setup
    fig = figure(2); clf;
    set(fig, 'Name', 'RWIV Analysis: Time Since Rain', 'NumberTitle', 'off');
    set(fig, 'DefaultTextInterpreter', 'latex', ...
             'DefaultAxesTickLabelInterpreter', 'latex', ...
             'DefaultLegendInterpreter', 'latex');
    theme(fig, "light");

    % Data Extraction
    uNormal = arrayfun(@(x) x.UNormalC1.mean, events);
    phiC1   = arrayfun(@(x) x.PhiC1.mean, events);
    
    % Calculate Time Since Last Rain (in hours)
    timeSinceRain = calculateTimeSinceRain(events, allStats);

    % Criteria Bounds (Daniotti et al., 2021)
    windBounds = [8, 12];
    phiBounds  = [45, 65];

    hold on;

    % 1. RWIV Active Region
    hFill = fill([phiBounds(1) phiBounds(2) phiBounds(2) phiBounds(1)], ...
        [windBounds(1) windBounds(1) windBounds(2) windBounds(2)], ...
        [0.7 0.7 0.7], 'FaceAlpha', 0.2, ...
        'EdgeColor', [0.8 0 0], 'LineWidth', 1.1);

    % 2. Scatter plot: Color represents hours since last rain
    hScatter = scatter(phiC1, uNormal, 55, timeSinceRain, 'filled', 'MarkerEdgeColor', [0.2 0.2 0.2]);

    % --- Colormap Selection ---
    % 'parula' or 'turbo' are clear, but 'winter' (flipped) illustrates "drying" well.
    % Here we use 'turbo' for high contrast across the 0-12 hour range.
    colormap(flipud(winter(256))); 
    
    % Formatting
    grid on; box on;
    cb = colorbar; 
    cb.Label.String = 'Time since last rain (hours)';
    clim([0, 12]); % Focusing on the first 12 hours of drying

    xlabel('$\Phi_{C1}$ (deg)'); 
    ylabel('$U_{N}$ ($\mathrm{m\,s^{-1}}$)');
    title('RWIV Persistence: Time Since Last Precipitation');

    % Legend
    legend([hFill, hScatter], {'RWIV Active Region', 'Potential Events'}, ...
        'Location', 'northwest', 'Box', 'on');

    set(gca, 'FontSize', 10);
end

function dtHours = calculateTimeSinceRain(events, allStats)
    % Calculates the time elapsed since the most recent rain event > 0.1 mm/h
    % Includes progress tracking and time estimation.
    
    numEvents = numel(events);
    dtHours = zeros(numEvents, 1);
    
    % Get all rain data and timestamps
    fprintf('Reshaping the allStats data for duration...\n');
    allTimes = arrayfun(@(x) x.duration(1), allStats);
    fprintf('Reshaping the allStats data for RainIntensity...\n');
    allRain  = arrayfun(@(x) x.RainIntensity.mean, allStats);
    
    % Indices where it actually rained
    rainyIndices = find(allRain > 0.1);
    rainyTimes = allTimes(rainyIndices);
    
    fprintf('Calculating Time Since Rain for %d events...\n', numEvents);
    progTic = tic;

    for i = 1:numEvents
        tCurrent = events(i).duration(1);
        
        % Find the most recent rainy time BEFORE or AT the current event
        pastRainyTimes = rainyTimes(rainyTimes <= tCurrent);
        
        if ~isempty(pastRainyTimes)
            lastRainTime = pastRainyTimes(end);
            dtHours(i) = hours(tCurrent - lastRainTime);
        else
            % Represents segments with no prior rain recorded in the dataset
            dtHours(i) = Inf; 
        end
        
        % Progress indication every 10%
        if mod(i, round(numEvents/10)) == 0 || i == numEvents
            elapsed = toc(progTic);
            estTotal = (elapsed / i) * numEvents;
            remTime = estTotal - elapsed;
            
            fprintf('  Progress: %3.0f%% | Elapsed: %.1fs | Est. Remaining: %.1fs\n', ...
                (i/numEvents)*100, elapsed, remTime);
        end
    end
end

function plotRwivGlobalProbability_old(events, allStats)
    % --- 1. Data Preparation ---
    totalCount = numel(allStats);
    numFlagged = numel(events);
    
    % Define Daniotti Environmental Bounds
    uBounds = [8, 12]; 
    pBounds = [45, 65];
    rLimit  = 0.1;
    
    % Evaluate ALL segments for environmental criteria
    uAll    = arrayfun(@(x) x.UNormalC1.mean, allStats);
    phiAll  = arrayfun(@(x) x.PhiC1.mean, allStats);
    rainAll = arrayfun(@(x) x.RainIntensity.mean, allStats); 

    isEnvMatchGlobal = (uAll >= uBounds(1) & uAll <= uBounds(2)) & ...
                       (phiAll >= pBounds(1) & phiAll <= pBounds(2)) & ...
                       (rainAll >= rLimit);
    numEnvMatch = sum(isEnvMatchGlobal);

    % Evaluate overlap within the structural events
    rainEvents = calculateLookbackRain(events, allStats, hours(2));
    uEvent     = arrayfun(@(x) x.UNormalC1.mean, events);
    phiEvent   = arrayfun(@(x) x.PhiC1.mean, events);
    
    criteriaOverlap = (uEvent >= uBounds(1) & uEvent <= uEvent <= uBounds(2)) & ...
                      (phiEvent >= pBounds(1) & phiEvent <= pBounds(2)) & ...
                      (rainEvents >= rLimit);

    % --- 2. Visualization ---
    fig = figure(4); clf;
    set(fig, 'Name', 'RWIV Probability Study', 'NumberTitle', 'off');
    set(fig, 'DefaultTextInterpreter', 'latex', ...
             'DefaultAxesTickLabelInterpreter', 'latex', ...
             'DefaultLegendInterpreter', 'latex');
    theme(fig, "light");

    tlo = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    %title(tlo, '\textbf{RWIV Global Probability and Criteria Overlap}', 'FontSize', 12,'Interpreter','lated');

    % Tile 1: Global Probability Comparison (Histogram/Bar)
    ax1 = nexttile;
    pFlag = (numFlagged / totalCount) * 100;
    pEnv  = (numEnvMatch / totalCount) * 100;
    
    b = bar([1, 2], [pFlag, pEnv], 'FaceColor', 'flat');
    b.CData(1,:) = [0.2 0.4 0.6]; % Structural (Blue)
    b.CData(2,:) = [0.6 0.2 0.2]; % Environmental (Red)
    grid on;
    ylabel('Global Probability (\%)');
    set(gca, 'XTick', [1, 2], 'XTickLabel', {'Structural Flag', 'Env. Criteria'});
    title('Detection vs. Susceptibility');

    % Tile 2: Reliability of Structural Flags (Overlap)
    ax2 = nexttile;
    pie([sum(criteriaOverlap), sum(~criteriaOverlap)], ...
        {sprintf('Criteria overlap(%d)', sum(criteriaOverlap)), ...
         sprintf('Flagged cases w/o overlap (%d)', sum(~criteriaOverlap))});
    title('Reliability of Flags');

    set(findall(fig, '-property', 'FontSize'), 'FontSize', 10);
end

function plotGeneralTrends(allStats)
    % Figure Setup
    fig = figure(5); clf;
    set(fig, 'Name', 'General Statistics Trends', 'NumberTitle', 'off');
    
    % Global LaTeX Formatting
    set(fig, 'DefaultTextInterpreter', 'latex', ...
             'DefaultAxesTickLabelInterpreter', 'latex', ...
             'DefaultLegendInterpreter', 'latex');
    theme(fig, "light");

    % 1. Data Extraction
    uMean    = arrayfun(@(x) x.WindSpeed.mean, allStats);
    stdSteel = arrayfun(@(x) x.Steel_Z.std, allStats);
    stdConc  = arrayfun(@(x) x.Conc_Z.std, allStats);
    windDir  = arrayfun(@(x) x.WindDir.mean, allStats);
    rain     = arrayfun(@(x) x.RainIntensity.mean, allStats);

    % --- Tiled Layout ---
    tlo = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    %title(tlo, '\textbf{General Trends in Bridge Dynamics and Environmental Loads}', 'FontSize', 12);

    % Tile 1: Wind Speed vs Steel Intensity (Colored by Phase)
    % Uses alpha transparency to handle high-density data overlaps.
    nexttile;
    scatter(uMean, stdSteel, 10, windDir, 'filled', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.4);
    grid on; cb = colorbar; cb.Label.String = 'Global Wind direction (deg)';
    xlabel('Wind speed ($\mathrm{m\,s^{-1}}$)'); ylabel('Steel\_Z Std ($\mathrm{m\,s^{-2}}$)');
    title('Steel Deck Intensity Trend');
    ylim([0 0.01])

    % Tile 2: Wind Speed vs Concrete Intensity (Colored by Phase)
    nexttile;
    scatter(uMean, stdConc, 10, windDir, 'filled', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.4);
    grid on; cb = colorbar; cb.Label.String = 'Global Wind direction (deg)';
    xlabel('Wind speed ($\mathrm{m\,s^{-1}}$)'); ylabel('Conc\_Z Std ($\mathrm{m\,s^{-2}}$)');
    title('Concrete Deck Intensity Trend');
    ylim([0 0.01])

    % Tile 3: Intensity Correlation between Decks
    % Helps identify if the vibration is localized or global.
    nexttile;
    scatter(stdSteel, stdConc, 10, uMean, 'filled', 'MarkerFaceAlpha', 0.3);
    line([0 0.05], [0 0.05], 'Color', 'r', 'LineStyle', '--', 'HandleVisibility', 'off');
    grid on; cb = colorbar; cb.Label.String = 'Wind speed ($\mathrm{m\,s^{-1}}$)';
    xlabel('Steel\_Z Std ($\mathrm{m\,s^{-2}}$)'); ylabel('Conc\_Z Std ($\mathrm{m\,s^{-2}}$)');
    title('Deck-to-Deck Synchronization');
    ylim([0 0.01])
    xlim([0 0.01])

    % Tile 4: Environmental Loading Trend
    nexttile;
    scatter(rain, stdConc, 10, 'filled', 'MarkerFaceColor', [0.2 0.6 0.8], 'MarkerFaceAlpha', 0.3);
    grid on;
    xlabel('Rain intensity ($\mathrm{mm\,h^{-1}}$)'); ylabel('Conc\_Z Std ($\mathrm{m\,s^{-2}}$)');
    title('Wind--Rain Interaction Space');
    xlim([0 20])
    ylim([0 0.01])
    % Final Formatting
    set(findall(fig, '-property', 'FontSize'), 'FontSize', 10);
end

function plotFrequencyDistribution(events, allStats, targetFreqs, freqTolerance)
    % Figure Setup
    fig = figure(7); clf;
    set(fig, 'Name', 'Modal Frequency Analysis (Log Scale)', 'NumberTitle', 'off');
    
    % Global LaTeX Formatting
    set(fig, 'DefaultTextInterpreter', 'latex', ...
             'DefaultAxesTickLabelInterpreter', 'latex', ...
             'DefaultLegendInterpreter', 'latex');
    theme(fig, "light");

    % 1. Robust Data Extraction
    freqsFlaggedConc  = extractPeakLocs(events, 'Conc_Z');
    freqsFlaggedSteel = extractPeakLocs(events, 'Steel_Z');
    freqsGlobalConc   = extractPeakLocs(allStats, 'Conc_Z');
    freqsGlobalSteel  = extractPeakLocs(allStats, 'Steel_Z');

    % --- Tiled Layout (2x2) ---
    tlo = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    % Simplified title to avoid interpreter warnings
    title(tlo, 'Spectral Peak Distribution: Flagged vs. Global Dataset', 'FontSize', 12);

    % Top Row: Flagged Events
    renderFreqPlot(nexttile, freqsFlaggedConc, targetFreqs, freqTolerance, ...
        'Flagged: Concrete Deck ($Conc\_Z$)', [0.2 0.6 0.8]);
    renderFreqPlot(nexttile, freqsFlaggedSteel, targetFreqs, freqTolerance, ...
        'Flagged: Steel Deck ($Steel\_Z$)', [0.8 0.4 0.2]);

    % Bottom Row: Global Dataset
    renderFreqPlot(nexttile, freqsGlobalConc, targetFreqs, freqTolerance, ...
        'Global: Concrete Deck ($Conc\_Z$)', [0.4 0.4 0.4]);
    renderFreqPlot(nexttile, freqsGlobalSteel, targetFreqs, freqTolerance, ...
        'Global: Steel Deck ($Steel\_Z$)', [0.5 0.5 0.5]);

    set(findall(fig, '-property', 'FontSize'), 'FontSize', 10);
end

function locs = extractPeakLocs(dataArray, sensorField)
    locs = [];
    if isempty(dataArray), return; end
    for i = 1:numel(dataArray)
        if isfield(dataArray(i), 'psdPeaks') && isstruct(dataArray(i).psdPeaks)
            if isfield(dataArray(i).psdPeaks, sensorField)
                pData = dataArray(i).psdPeaks.(sensorField);
                if isfield(pData, 'locations') && ~isempty(pData.locations)
                    locs = [locs; pData.locations(:)];
                end
            end
        end
    end
end

function renderFreqPlot(ax, data, targets, tol, sensorName, barColor)
    hold(ax, 'on');
    yMin = 0.5; yMax = 1e6; % Log scale bounds
    
    % 1. Tolerance Shading
    for f = targets
        fill(ax, [f-tol, f+tol, f+tol, f-tol], [yMin yMin yMax yMax], ...
            [0.9 0.9 0.9], 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
    
    % 2. Histogram with Log Scale
    if ~isempty(data)
        h = histogram(ax, data, 'BinWidth', 0.02, 'FaceColor', barColor, ...
            'EdgeColor', 'none', 'DisplayName', 'Detected Peaks');
        set(ax, 'YScale', 'log');
        maxCount = max(h.Values);
        if maxCount > 0
            ylim(ax, [yMin, maxCount * 2]);
        else
            ylim(ax, [yMin, 10]);
        end
    else
        text(ax, 0.5, 0.5, 'No Peaks', 'Units', 'normalized', 'HorizontalAlignment', 'center');
    end
    
    % 3. Target Centerlines
    for f = targets
        xline(ax, f, '--r', 'LineWidth', 1.2, 'DisplayName', 'Target');
    end
    
    grid(ax, 'on'); box(ax, 'on');
    title(ax, sensorName);
    ylabel(ax, 'Count (log)');
    if ax.Layout.Tile > 2, xlabel(ax, 'Freq. (Hz)'); end
    if ax.Layout.Tile == 1, legend(ax, 'Location', 'northeast', 'FontSize', 8); end
end

%% --- Plotting helpers ---
function fig = createFigure(figNum,title)
fig = figure(figNum); clf;
set(fig, 'Visible', 'off');
set(fig, 'Name', title, 'NumberTitle', 'off');
set(fig, 'DefaultTextInterpreter', 'latex', ...
    'DefaultAxesTickLabelInterpreter', 'latex', ...
    'DefaultLegendInterpreter', 'latex');
theme(fig, "light");
colororder(fig, 'earth');
end

function successFlag = saveFig(fig,figureFolder,fileName,heightScale,widthScale,leg)
arguments
    fig 
    figureFolder 
    fileName 
    heightScale = 2
    widthScale = 1
    leg = [];
end
%fontsize(fig, "scale",fontScale);
scale = 2;
fontsize(fig,9*scale,'points');
lineWidth = 506.44*scale; %cm
fig.Units = 'points';
fig.Position(3:4) = [lineWidth/widthScale lineWidth/heightScale];
fig.Renderer = 'painters';

if ~isempty(leg)
    leg.FontSize = 16;
end

try
    if ~isempty(figureFolder)
        exportgraphics(fig, fullfile(figureFolder, [fileName '.png']),'Resolution',600);
        exportgraphics(fig, fullfile(figureFolder, [fileName '.pdf']), 'ContentType', 'vector');
        
        [~,msgID] = lastwarn;
        if strcmp(msgID, 'MATLAB:print:ContentTypeImageSuggested')
            exportgraphics(fig, fullfile(figureFolder, [fileName '.pdf']), 'ContentType', 'auto');
            fprintf('Figure %s was saved in an automated .pdf way \n',fileName)
        end
    else
        error('No save')
    end
    successFlag = true;
catch ME
    successFlag = false;
    error('No save')
end
end

function categoricalMap = myColorMap()

fullMap = slanCM(188);

[uniqueColors, ~, originalIndices] = unique(fullMap, 'rows', 'stable');

numUniqueColors = size(uniqueColors, 1);
shadesPerGroup = 4;
numGroups = numUniqueColors / shadesPerGroup;

flippedUniqueColors = uniqueColors;

for groupIdx = 1:numGroups
    rowStart = (groupIdx - 1) * shadesPerGroup + 1;
    rowEnd = groupIdx * shadesPerGroup;

    groupBlock = uniqueColors(rowStart:rowEnd, :);
    flippedUniqueColors(rowStart:rowEnd, :) = flipud(groupBlock);
end

categoricalMap = flippedUniqueColors(originalIndices, :);
end

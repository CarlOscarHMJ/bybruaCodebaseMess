%% RWIV Analysis Dashboard
% Loads processed bridge data and generates diagnostic visualizations.

addpath('functions/')
figureFolder = 'figures/BridgeDataProcessedResults/';

% --- Main Execution ---
[allStats, status] = loadProcessedData('figures/BridgeDataProcessed/');
if ~status, return; end
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
plotFlags = ["flag_StructuralResponseMatch","flag_PSDTotal","flag_CohTotal",'flag_EnvironmentalMatch'];
%plotNidComparison(allStats,plotFlags,limits,'local',figureFolder);
%plotNidComparison(allStats,plotFlags,limits,'global',figureFolder);
% plotFlaggedAccVsWind(allStats, plotFlags, 'global', figureFolder)
%plotPeaksDistribution(allStats, limits,figureFolder)
% plotPeaksDistribution(allStats, limits,figureFolder, ["Conc_X", "Steel_X"])
% plotCoherenceDistribution(allStats, limits, figureFolder)
% plotNidComparisonPeakIntensity(allStats, plotFlags(1:2), limits, 'global', figureFolder)
% plotNidComparisonPeakIntensity(allStats, plotFlags(1:2), limits, 'local', figureFolder)
% plotWindRoses(allStats,figureFolder)

fields = string(fieldnames(allStats));
allFlagFields = fields(startsWith(fields,'flag'));
allFlagFieldsSorted = allFlagFields([1, 2, 3, 4, 13, 5, 6, 14, 10, 7, 8, 9, 11, 12]);
plotRwivGlobalProbability(allStats,allFlagFieldsSorted,figureFolder)

% Old functions
%plotTimeSinceRain(events, allStats);

%plotGeneralTrends(allStats)
% plotFrequencyDistribution(allStats, targetFreqs, freqTolerance)
%% Save data for validation analysis:
potentialEvents = allStats(allStats.flag_StructuralResponseMatch,:);
save('figures/BridgeDataProcessed/potentialEvents.mat')
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
    
    PsdFlag.Conc_Z.Mode1 = false(NumberSegments, 1);
    PsdFlag.Conc_Z.Mode2 = false(NumberSegments, 1);
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
    PhiC1_mean      = [StatsTable.PhiC1.mean];
    RainIntensity   = [StatsTable.RainIntensity.mean];

    EnvironmentalWindSpeedFlag = (UNormalC1_mean >= Thresholds.cableWindSpeed(1)...
                                & UNormalC1_mean <= Thresholds.cableWindSpeed(2)).';
    EnvironmentalWindAngleFlag = (PhiC1_mean >= Thresholds.cableWindDir(1)...
                                & PhiC1_mean <= Thresholds.cableWindDir(2)).';
    EnvironmentalRainFlag = (RainIntensity > Thresholds.rainLowerLimit).'; 
    
    StatsTable.flag_PSD_Conc_F1 = PsdFlag.Conc_Z.Mode1;
    StatsTable.flag_PSD_Conc_F2 = PsdFlag.Conc_Z.Mode2;
    StatsTable.flag_PSD_Steel_F1 = PsdFlag.Steel_Z.Mode1;
    StatsTable.flag_PSD_Steel_F2 = PsdFlag.Steel_Z.Mode2;
    StatsTable.flag_PSDTotal = (PsdFlag.Conc_Z.Mode1 & PsdFlag.Conc_Z.Mode2) & (PsdFlag.Steel_Z.Mode1 & PsdFlag.Steel_Z.Mode2);

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
%% --- Plotting Functions ---

function plotNidComparison(allStats, flagFields, limits, windDomain, figureFolder)
    % Plots multiple RWIV parameter space validations in a tiled layout.
    arguments
        allStats 
        flagFields 
        limits 
        windDomain = 'local'
        figureFolder = ''
    end

    if ischar(flagFields) || isstring(flagFields)
        flagFields = cellstr(flagFields);
    end

    numPlots = length(flagFields);
    fig = createFigure(1, 'RWIV Multi-Criteria Validation');
    tlo = tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'tight');
    
    hFill = []; % Initialize to avoid errors if windDomain is not 'local'

    for i = 1:numPlots
        nexttile;
        currentFlag = flagFields{i};
        
        rain = calculateLookbackRain(currentFlag, allStats, hours(2));
        events = allStats(allStats.(currentFlag), :);
        events = events(rain < 50, :); 
        currentRain = rain(rain < 50);

        if strcmpi(windDomain, 'local')
            windSpeed = [events.UNormalC1.mean]';
            windAngle = [events.PhiC1.mean]';
        else
            windSpeed = [events.WindSpeed.mean]';
            windAngle = [events.WindDir.mean]';
        end

        acc = [events.Steel_Z.max];
        accSize = 50 / mean(acc) * acc;

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
                accSize(noRainIdxs), 'red', 'filled', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0);
        
        scatter(windAngle(rainIdxs), windSpeed(rainIdxs), ...
                accSize(rainIdxs), currentRain(rainIdxs), 'filled', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0);
        
        colormap(myColorMap());
        grid on; box on;
        title(sprintf('Flag: \\texttt{%s}', strrep(currentFlag, '_', '\_')), 'Interpreter', 'latex');
        set(gca, 'TickLabelInterpreter', 'latex');

        if strcmpi(windDomain, 'local')
            xlim([30 150])
            ylim([0 16])
        else
            xlim([0 360])
            ylim([0 16])
        end
    end

    if strcmpi(windDomain, 'local')
        xlabel(tlo, '$\Phi_{C1}$ (deg)', 'Interpreter', 'latex');
        ylabel(tlo, '$U_{N,C1}$ (m/s)', 'Interpreter', 'latex');
    else
        xlabel(tlo, 'Bridge axis wind (deg)', 'Interpreter', 'latex');
        ylabel(tlo, 'Wind speed (m/s)', 'Interpreter', 'latex');
    end

    cb = colorbar;
    cb.Layout.Tile = 'east';
    cb.TickLabelInterpreter = 'latex';
    cb.Label.String = 'Highest recorded rain intensity over last two hours (mm/h)';
    cb.Label.Interpreter = 'latex';
    cb.Label.FontSize = tlo.Title.FontSize;
    clim([0, 25]);

    % Fix Legend: Conditional hFill and LaTeX fixes
    hDry = scatter(NaN, NaN, 50, [1 0 0], 'filled');
    hWet = scatter(NaN, NaN, 50, [0.3 0.7 0.9], 'filled');
    
    if ~isempty(hFill)
        entries = [hFill, hDry, hWet];
        labels = {'Daniotti (2021) Region', 'Dry Case ($0$ mm/h)', 'Wet Case ($>0$ mm/h)'};
    else
        entries = [hDry, hWet];
        labels = {'Dry Case ($0$ mm/h)', 'Wet Case ($>0$ mm/h)'};
    end

    lg = legend(entries, labels, 'Orientation', 'horizontal', 'Interpreter', 'latex');
    lg.Layout.Tile = 'north';

    saveName = ['RviwFlagEvaluation' char(upper(windDomain(1))) windDomain(2:end)];
    saveFig(fig,figureFolder,saveName);
end

function plotNidComparisonPeakIntensity(allStats, flagFields, limits, windDomain, figureFolder)
    % Plots multiple RWIV parameter space validations in a tiled layout.
    arguments
        allStats 
        flagFields 
        limits 
        windDomain = 'local'
        figureFolder = ''
    end

    if ischar(flagFields) || isstring(flagFields)
        flagFields = cellstr(flagFields);
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
        
        rain = calculateLookbackRain(currentFlag, allStats, hours(2));
        events = allStats(allStats.(currentFlag), :);
        events = events(rain < 50, :); 
        currentRain = rain(rain < 50);

        if strcmpi(windDomain, 'local')
            windSpeed = [events.UNormalC1.mean]';
            windAngle = [events.PhiC1.mean]';
        else
            windSpeed = [events.WindSpeed.mean]';
            windAngle = [events.WindDir.mean]';
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

        % field = 'Conc_Z';
        % field = 'Steel_Z';
        % targetIntensities = arrayfun(@(s) s.(field).logIntensity(find(...
        %     abs(s.(field).locations - targetF) == ...
        %     min(abs(s.(field).locations - targetF)), 1)), psdData);
        % targetIntensities = exp(targetIntensities);
        scaleFactor = 10e+05; % based on 50 / mean(targetIntensities) of the first round.
        IntensitySized = scaleFactor * aggregateIntensity;

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
                IntensitySized(noRainIdxs), 'red', 'filled', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0);
        
        scatter(windAngle(rainIdxs), windSpeed(rainIdxs), ...
                IntensitySized(rainIdxs), currentRain(rainIdxs), 'filled', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0);
        
        colormap(myColorMap());
        clim([0, 10]);
        grid on; box on;
        title(sprintf('Flag: \\texttt{%s}', strrep(currentFlag, '_', '\_')), 'Interpreter', 'latex');
        set(gca, 'TickLabelInterpreter', 'latex');

        if strcmpi(windDomain, 'local')
            xlim([30 150])
            ylim([0 16])
        else
            xlim([0 360])
            ylim([0 16])
        end
    end

    if strcmpi(windDomain, 'local')
        xlabel(tlo, '$\Phi_{C1}$ (deg)', 'Interpreter', 'latex');
        ylabel(tlo, '$U_{N,C1}$ (m/s)', 'Interpreter', 'latex');
    else
        xlabel(tlo, 'Bridge axis wind (deg)', 'Interpreter', 'latex');
        ylabel(tlo, 'Wind speed (m/s)', 'Interpreter', 'latex');
    end

    cb = colorbar;
    cb.Layout.Tile = 'east';
    cb.TickLabelInterpreter = 'latex';
    cb.Label.String = 'Highest recorded rain intensity over last two hours (mm/h)';
    cb.Label.Interpreter = 'latex';
    cb.Label.FontSize = tlo.Title.FontSize;

    % Fix Legend: Conditional hFill and LaTeX fixes
    hDry = scatter(NaN, NaN, 50, [1 0 0], 'filled');
    hWet = scatter(NaN, NaN, 50, [0.3 0.7 0.9], 'filled');
    
    if ~isempty(hFill)
        entries = [hFill, hDry, hWet];
        labels = {'Daniotti (2021) Region', 'Dry Case ($0$ mm/h)', 'Wet Case ($>0$ mm/h)'};
    else
        entries = [hDry, hWet];
        labels = {'Dry Case ($0$ mm/h)', 'Wet Case ($>0$ mm/h)'};
    end

    lg = legend(entries, labels, 'Orientation', 'horizontal', 'Interpreter', 'latex');
    lg.Layout.Tile = 'north';

    saveName = ['RviwFlagEvaluation_PeakIntensity' char(upper(windDomain(1))) windDomain(2:end)];
    saveFig(fig,figureFolder,saveName);
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
        xlabel(tlo, '$U_{N,C1}$ (m/s)', 'Interpreter', 'latex');
    else
        xlabel(tlo, 'Mean Wind Speed (m/s)', 'Interpreter', 'latex');
    end
    ylabel(tlo, 'Max Deck Acceleration ($\mathrm{m/s^2}$)', 'Interpreter', 'latex');
    legend

    fileName = ['AccVsWindEvaluation' char(upper(windDomain(1))) windDomain(2:end)];
    saveFig(fig,figureFolder,fileName);
end

function plotPeaksDistribution(allStats, limits, figureFolder,fields)
    arguments
        allStats
        limits
        figureFolder = ''
        fields {mustBeText} = ["Conc_Z", "Steel_Z"];
    end
    
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
        ylabel(axObj, sprintf('%s $S_{zz}$ ($m^2/s^4/Hz$)', strrep(fields(segmentIdx), '_', '\_')), ...
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
    
    fileName = 'BridgeSpectralSignatureDistribution_LinearY';
    saveFig(figHandle,figureFolder,fileName)
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

function plotRwivGlobalProbability(allStats, flagFields, figureFolder)
    arguments
        allStats
        flagFields
        figureFolder = ''
    end
    
    if ischar(flagFields) || isstring(flagFields)
        flagFields = cellstr(flagFields);
    end
    
    figHandle = createFigure(4, 'RWIV Global Probability Summary');
    axMain = axes(figHandle);
    hold(axMain, 'on');
    
    totalObservations = height(allStats);
    totalDataHours = totalObservations * (1/6);
    
    numFlags = length(flagFields);
    structuralProbabilities = zeros(1, numFlags);
    xLabels = strings(1, numFlags);
    
    for i = 1:numFlags
        currentFlagName = flagFields{i};
        isFlagged = allStats.(currentFlagName) == true;
        
        fullRainVector = zeros(totalObservations, 1);
        subsetRain = calculateLookbackRain(currentFlagName, allStats, hours(4));
        fullRainVector(isFlagged) = subsetRain;
        
        validIndices = isFlagged & (fullRainVector < 50);
        structuralProbabilities(i) = (sum(validIndices) / totalObservations) * 100;
        xLabels(i) = strrep(currentFlagName, '_', '\_');
    end
    
    barGroup = bar(axMain, structuralProbabilities, 'FaceColor', 'flat');
    
    blueColor = [0.2 0.4 0.6];
    redColor = [0.6 0.2 0.2];
    
    for i = 1:numFlags
        if contains(flagFields{i}, 'env', 'IgnoreCase', true) || ...
           contains(flagFields{i}, 'Wind', 'IgnoreCase', true) || ...
           contains(flagFields{i}, 'Rain', 'IgnoreCase', true)
            barGroup.CData(i, :) = redColor;
        else
            barGroup.CData(i, :) = blueColor;
        end
        
        % Place percentage label above each bar
        text(axMain, i, structuralProbabilities(i), ...
            sprintf('%.2f%%', structuralProbabilities(i)), ...
            'VerticalAlignment', 'bottom', ...
            'HorizontalAlignment', 'center', ...
            'Interpreter', 'latex');
    end
    
    grid(axMain, 'on'); box(axMain, 'on');
    ylabel(axMain, 'Global Probability (\%)', 'Interpreter', 'latex');
    set(axMain, 'XTick', 1:numFlags, 'XTickLabel', xLabels, ...
        'TickLabelInterpreter', 'latex');
    
    yyaxis(axMain, 'right');
    ylabel(axMain, 'Total Duration (Hours)', 'Interpreter', 'latex');
    axMain.YAxis(2).Color = [0 0 0];
    
    scalingFactor = totalDataHours / 100;
    axMain.YAxis(2).Limits = axMain.YAxis(1).Limits * scalingFactor;
    
    titleStr = {
        '\textbf{RWIV Detection Probability Summary}';
        sprintf('Total Dataset Duration: %.1f Hours (%d 10-min Segments)', totalDataHours, totalObservations)
    };
    title(axMain, titleStr, 'Interpreter', 'latex');
    
    fileName = 'RwivGlobalProbabilityStudy';
    saveFig(figHandle, figureFolder, fileName);
end

function plotWindRoses(allStats,figureFolder)
arguments
    allStats 
    figureFolder {mustBeText}
end

windSpeeds = [allStats.WindSpeed.mean];
windAngle = [allStats.WindDir.mean];

fig = createFigure(11, 'Wind Roses');
tlc = tiledlayout('flow');
nt = nexttile;

idx = windSpeeds >= 6;
filteredWindSpeeds = windSpeeds(idx);
filteredAngles = windAngle(idx);

labels = cellstr(compose("$%d^\\circ$", 0:30:330));
labels{1} = 'N'; labels{4} = 'E'; labels{7} = 'S'; labels{10} = 'W';

speedBins = 6:3:22;
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
    'lablegend', '$\bar{u}\, \mathrm{(m\,s^{-1})}$');

legend('boxoff');
hold on;
bridgeAngles = [-18, -18 + 180];
xLine = sind(bridgeAngles);
yLine = cosd(bridgeAngles);
plot(xLine, yLine, 'k-', 'LineWidth', 2,'HandleVisibility','off');

nt = nexttile;
windSpeedStd = [allStats.WindSpeed.std];
turbulenceIntensity = (windSpeedStd(idx)./filteredWindSpeeds)*100;

idx = turbulenceIntensity >= 0;
filteredTis = turbulenceIntensity(idx);
filteredAngles = windAngle(idx);

labels = cellstr(compose("$%d^\\circ$", 0:30:330));
labels{1} = 'N'; labels{4} = 'E'; labels{7} = 'S'; labels{10} = 'W';

WindRose(filteredAngles, filteredTis, ...
    'axes', nt, ...
    ...%'vWinds', speedBins, ...
    'colormap', sky, ...
    'legendvariable', 'I_u (\%)', ...
    'freqlabelangle', 30, ...
    'facealpha', 1, ...
    'gridalpha', 0.1, ...
    'labels', labels, ...
    'legendposition', 'southeastoutside',...
    'titlestring','', ...
    'lablegend', '$I_u\, (\%)$');

legend('boxoff');
hold on;
bridgeAngles = [-18, -18 + 180];
xLine = sind(bridgeAngles);
yLine = cosd(bridgeAngles);
plot(xLine, yLine, 'k-', 'LineWidth', 2,'HandleVisibility','off');

fileName = 'WindRoses';
fontScale = 1.4;
saveFig(fig, figureFolder, fileName,fontScale);
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
    ylabel('$U_{N}$ (m/s)');
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
    xlabel('Wind speed (m/s)'); ylabel('Steel\_Z Std (m/s$^2$)');
    title('Steel Deck Intensity Trend');
    ylim([0 0.01])

    % Tile 2: Wind Speed vs Concrete Intensity (Colored by Phase)
    nexttile;
    scatter(uMean, stdConc, 10, windDir, 'filled', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.4);
    grid on; cb = colorbar; cb.Label.String = 'Global Wind direction (deg)';
    xlabel('Wind speed (m/s)'); ylabel('Conc\_Z Std (m/s$^2$)');
    title('Concrete Deck Intensity Trend');
    ylim([0 0.01])

    % Tile 3: Intensity Correlation between Decks
    % Helps identify if the vibration is localized or global.
    nexttile;
    scatter(stdSteel, stdConc, 10, uMean, 'filled', 'MarkerFaceAlpha', 0.3);
    line([0 0.05], [0 0.05], 'Color', 'r', 'LineStyle', '--', 'HandleVisibility', 'off');
    grid on; cb = colorbar; cb.Label.String = 'Wind speed (m/s)';
    xlabel('Steel\_Z Std (m/s$^2$)'); ylabel('Conc\_Z Std (m/s$^2$)');
    title('Deck-to-Deck Synchronization');
    ylim([0 0.01])
    xlim([0 0.01])

    % Tile 4: Environmental Loading Trend
    nexttile;
    scatter(rain, stdConc, 10, 'filled', 'MarkerFaceColor', [0.2 0.6 0.8], 'MarkerFaceAlpha', 0.3);
    grid on;
    xlabel('Rain intensity (mm/h)'); ylabel('Conc\_Z Std (m/s$^2$)');
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
set(fig, 'Name', title, 'NumberTitle', 'off');
set(fig, 'DefaultTextInterpreter', 'latex', ...
    'DefaultAxesTickLabelInterpreter', 'latex', ...
    'DefaultLegendInterpreter', 'latex');
theme(fig, "light");
colororder(fig, 'earth');
end

function successFlag = saveFig(fig,figureFolder,fileName,fontScale)
arguments
    fig 
    figureFolder 
    fileName 
    fontScale = 1.7
end
fontsize(fig, "scale",fontScale);
try
    if ~isempty(figureFolder)
        exportgraphics(fig, fullfile(figureFolder, [fileName '.pdf']), 'ContentType', 'vector');
        exportgraphics(fig, fullfile(figureFolder, [fileName '.png']));
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

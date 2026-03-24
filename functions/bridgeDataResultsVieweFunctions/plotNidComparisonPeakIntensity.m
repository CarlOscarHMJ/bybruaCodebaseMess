function plotNidComparisonPeakIntensity(allStats, flagFields, limits, windDomain, figureFolder, flagNames)
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

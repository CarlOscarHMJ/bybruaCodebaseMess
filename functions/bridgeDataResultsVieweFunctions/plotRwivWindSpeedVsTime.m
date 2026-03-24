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

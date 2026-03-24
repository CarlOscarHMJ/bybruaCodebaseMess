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

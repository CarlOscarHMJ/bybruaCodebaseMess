function plotWindRoses(allStats,figureFolder,options)
arguments
    allStats 
    figureFolder {mustBeText}
    options.minWindSpeed (1,1) double = 6
    options.binWindSize (1,1) double = 3
    options.maxWindSpeed (1,1) double = 22
    options.stationarityLimit (1,1) double = inf
end

windSpeeds = [allStats.WindSpeed.mean];
windAngle = [allStats.WindDir.mean];
windStationarity = [allStats.WindSpeed.stationarityValue];

fig = createFigure(11, 'Wind Roses');
tlc = tiledlayout('flow','TileSpacing','compact','Padding','compact');
nt = nexttile;

idx = windSpeeds >= options.minWindSpeed;
if isfinite(options.stationarityLimit)
    idx = idx & ~isnan(windStationarity) & (windStationarity <= options.stationarityLimit);
end

filteredWindSpeeds = windSpeeds(idx);
filteredAngles = windAngle(idx) - 18;

labels = cellstr(compose("$%d^\\circ$", 0:30:330));
labels{1} = 'N'; labels{4} = '$\;$E'; labels{7} = 'S'; labels{10} = 'W';

speedBins = options.minWindSpeed:options.binWindSize:options.maxWindSpeed;
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

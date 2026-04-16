function allStats = plotNidComparison(allStats, flagFields, limits, windDomain, figureFolder, flagNames, addDecisionBoundary, decisionBoundaryThreshold, numClusters)
% Evaluates and plots RWIV parameter space validations, appending GMM inclusion flags to allStats.
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

flagFields = cellstr(flagFields);
if isempty(flagNames)
    flagNames = flagFields;
else
    flagNames = cellstr(flagNames);
end

allWindSpeed = [allStats.WindSpeed.mean]';

fig = createFigure(1, 'RWIV Multi-Criteria Validation');
tlo = tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'tight');
hFill = [];
set(fig, 'WindowButtonDownFcn', @onWindowButtonDown);

for i = 1:length(flagFields)
    nexttile;
    currentFlag = flagFields{i};
    flagName = flagNames{i};
    isC5Case = contains(string(currentFlag), "C5", 'IgnoreCase', true) || contains(string(flagName), "C5", 'IgnoreCase', true);
    
    rain = calculateLookbackRain(currentFlag, allStats, hours(2));
    events = allStats(allStats.(currentFlag), :);
    events = events(rain < 50, :); 
    currentRain = rain(rain < 50);
    eventDurations = events.duration;
    
    if strcmpi(windDomain, 'local')
        windSpeed = [events.WindSpeed.mean]';
        if isC5Case
            windAngle = calculateLocalCableWindAngle([events.WindDir.mean]', 51.48, 360);
            allWindAngle = calculateLocalCableWindAngle([allStats.WindDir.mean]', 51.48, 360);
        else
            windAngle = [events.PhiC1.mean]';
            allWindAngle = [allStats.PhiC1.mean]';
        end
    else
        windSpeed = [events.WindSpeed.mean]';
        windAngle = [events.WindDir.mean]';
        allWindAngle = [allStats.WindDir.mean]';
    end
    allData = [allWindAngle, allWindSpeed];
    
    acc = [events.Steel_Z.max];
    accSize = 50 / mean(acc) * acc;
    
    hold on;
    if strcmpi(windDomain, 'local') && ~addDecisionBoundary
        wBounds = limits.cableWindSpeed;
        pBounds = limits.cableWindDir;
        hFill = fill([pBounds(1) pBounds(2) pBounds(2) pBounds(1)], ...
                     [wBounds(1) wBounds(1) wBounds(2) wBounds(2)], ...
                     [0.7 0.7 0.7], 'FaceAlpha', 0.2, ...
                     'EdgeColor', [0.8 0 0], 'LineWidth', 1.1);
    end
    
    noRainIdxs = currentRain == 0;
    rainIdxs = ~noRainIdxs;
    
    hDryScatter = scatter(windAngle(noRainIdxs), windSpeed(noRainIdxs), accSize(noRainIdxs), 'red', 'filled', 'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0);
    hWetScatter = scatter(windAngle(rainIdxs), windSpeed(rainIdxs), accSize(rainIdxs), currentRain(rainIdxs), 'filled', 'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0);
    setScatterUserData(hDryScatter, eventDurations(noRainIdxs, :), currentRain(noRainIdxs), acc(noRainIdxs));
    setScatterUserData(hWetScatter, eventDurations(rainIdxs, :), currentRain(rainIdxs), acc(rainIdxs));
    
    colormap(myColorMap());
    clim([0 25]);
    grid on; box on;
    title(sprintf('Criteria: \\texttt{%s}', strrep(flagName, '_', '\_')), 'Interpreter', 'latex');
    set(gca, 'TickLabelInterpreter', 'latex');
    
    if strcmpi(windDomain, 'local')
        xlim([30 150]);
        ylim([0 18]);
    else
        xlim([0 360]);
        ylim([0 16]);
    end
    
    if addDecisionBoundary || strcmpi(flagName, 'PSD')
        windAngleGlobal = [events.WindDir.mean]';
        idxBoundary = rainIdxs & (windAngleGlobal < 180);
        trainingData = [windAngle(idxBoundary), windSpeed(idxBoundary)];
        
        try
            [isInGmm, gmmModel, gmmThreshold] = fitAndEvaluateGmm(trainingData, allData, numClusters, decisionBoundaryThreshold);
            allStats.(sprintf('%s_inGmm', currentFlag)) = isInGmm;
            
            plotGmmBoundary(gmmModel, gmmThreshold);
            printGmmLatex(gmmModel, gmmThreshold);
        catch
            fprintf('Failed to fit Gaussian Mixture Model with %d clusters.\n', numClusters);
        end
    end
end

formatFigureLayout(tlo, hFill, windDomain, flagNames, fig, figureFolder);
end

function [isInBoundary, gmmModel, densityThreshold] = fitAndEvaluateGmm(trainingData, evaluationData, numClusters, densityPercentile)
% Fits a GMM to the training data and evaluates a boolean boundary for the evaluation data
gmmOptions = statset('MaxIter', 1000);
gmmModel = fitgmdist(trainingData, numClusters, 'Options', gmmOptions);

observedDensity = pdf(gmmModel, trainingData);
densityThreshold = prctile(observedDensity, densityPercentile);

evaluationDensity = pdf(gmmModel, evaluationData);
isInBoundary = evaluationDensity >= densityThreshold;
end

function plotGmmBoundary(gmmModel, densityThreshold)
% Plots the contour boundary of the GMM on the current active axis
limitsX = xlim;
limitsY = ylim;
gridX = linspace(limitsX(1), limitsX(2), 300);
gridY = linspace(limitsY(1), limitsY(2), 300);
[meshX, meshY] = meshgrid(gridX, gridY);

evalCoords = [meshX(:), meshY(:)];
densityGrid = reshape(pdf(gmmModel, evalCoords), size(meshX));

hold on;
contour(meshX, meshY, densityGrid, [densityThreshold, densityThreshold], 'LineColor', 'black', 'LineWidth', 1.5, 'LineStyle', '--');
end

function printGmmLatex(gmmModel, densityThreshold)
% Generates and prints the LaTeX representation of the Gaussian Mixture Model
fprintf('\n%% ================= LATEX OUTPUT ================= %%\n');
fprintf('\\begin{equation}\n');
fprintf(' \\begin{aligned}\n');

tauStr = sprintf('%0.2e', densityThreshold);
parts = strsplit(tauStr, 'e');
baseTau = parts{1};
expTau = num2str(str2double(parts{2})); 

numClusters = gmmModel.NumComponents;
fprintf(' p(\\mathbf{x}) &= \\sum_{k=1}^{%d} \\pi_k \\mathcal{N}(\\mathbf{x} | \\boldsymbol{\\mu}_k, \\boldsymbol{\\Sigma}_k) \\ge \\tau, \\qquad \\tau = %s \\times 10^{%s} \\\\\\\\\n', numClusters, baseTau, expTau);

for k = 1:numClusters
    piK = gmmModel.ComponentProportion(k);
    muK = gmmModel.mu(k, :);
    sigmaK = gmmModel.Sigma(:, :, k);
    
    if k == numClusters
        endLine = '\n';
    else
        endLine = ' \\\\\\\\\n';
    end
    
    fprintf(' \\pi_%d &= %.3f, \\quad ', k, piK);
    fprintf('\\boldsymbol{\\mu}_%d = \\begin{bmatrix} %.2f \\\\\\\\ %.2f \\end{bmatrix}, \\quad ', k, muK(1), muK(2));
    fprintf('\\boldsymbol{\\Sigma}_%d = \\begin{bmatrix} %.2f & %.2f \\\\\\\\ %.2f & %.2f \\end{bmatrix}%s', ...
        k, sigmaK(1,1), sigmaK(1,2), sigmaK(2,1), sigmaK(2,2), endLine);
end
fprintf(' \\end{aligned}\n');
fprintf('\\end{equation}\n');
fprintf('%% ================================================ %%\n\n');
end

function formatFigureLayout(tlo, hFill, windDomain, flagNames, fig, figureFolder)
% Configures the tiled layout, legends, colorbars, and saves the figure
if strcmpi(windDomain, 'local')
    xlabel(tlo, '$\Phi$ (deg)', 'Interpreter', 'latex');
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

hDry = scatter(NaN, NaN, 50, [1 0 0], 'filled');
hWet = scatter(NaN, NaN, 50, [0.3 0.7 0.9], 'filled');
hBoundary = plot(NaN, NaN, '--k', 'linewidth', 2);

if ~isempty(hFill)
    entries = [hFill, hBoundary, hDry, hWet];
    labels = {'\texttt{Daniotti\,} Region', 'Fitted Boundary', 'Dry Case ($0$ $\mathrm{mm\,h^{-1}}$)', 'Wet Case ($>0$ $\mathrm{mm\,h^{-1}}$)\quad'};
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

saveName = ['RviwFlagEvaluation' char(upper(windDomain(1))) windDomain(2:end) '_' strjoin(strrep(flagNames, ' ', '_'), "_")];
saveName = strrm(saveName, ["\", "$", "(", ")", ","]);
saveFig(fig, figureFolder, saveName, saveHeight, saveWidth);
end

function setScatterUserData(scatterHandle, durations, rain, acceleration)
% Stores event metadata required for click-to-inspect behavior.
scatterHandle.UserData = struct( ...
    'durations', durations, ...
    'rain', rain, ...
    'acceleration', acceleration);
end

function onWindowButtonDown(fig, ~)
% Opens the RWIV dashboard for the nearest clicked scatter point.
if ~strcmp(get(fig, 'SelectionType'), 'normal')
    return;
end

ax = gca;
if isempty(ax) || ~isa(ax, 'matlab.graphics.axis.Axes')
    return;
end

clickCoords = ax.CurrentPoint(1, 1:2);
clickX = clickCoords(1);
clickY = clickCoords(2);

xLimits = ax.XAxis.Limits;
yLimits = ax.YAxis.Limits;
xTotalRange = diff(xLimits);
yTotalRange = diff(yLimits);

if xTotalRange <= 0 || yTotalRange <= 0
    return;
end

scatterObjects = findobj(ax, 'Type', 'scatter');
minDist = inf;
bestIdx = 0;
bestScatter = [];

for i = 1:numel(scatterObjects)
    currentScatter = scatterObjects(i);
    if isempty(currentScatter.XData) || isempty(currentScatter.UserData)
        continue;
    end

    xData = currentScatter.XData(:);
    yData = currentScatter.YData(:);
    isFinite = isfinite(xData) & isfinite(yData);
    if ~any(isFinite)
        continue;
    end

    xData = xData(isFinite);
    yData = yData(isFinite);

    normalizedDist = ((xData - clickX) / xTotalRange).^2 + ((yData - clickY) / yTotalRange).^2;
    [localMin, localIdx] = min(normalizedDist);

    if ~isempty(localMin) && localMin < minDist
        minDist = localMin;
        bestIdx = find(isFinite, localIdx, 'first');
        bestIdx = bestIdx(end);
        bestScatter = currentScatter;
    end
end

if isempty(bestScatter) || minDist >= 0.05
    return;
end

eventInfo = bestScatter.UserData;
startTime = eventInfo.durations(bestIdx, 1);
endTime = eventInfo.durations(bestIdx, 2);
fprintf('Selected event at %.2f deg, %.2f m/s (rain: %.2f mm/h, acc: %.3f)\n', ...
    bestScatter.XData(bestIdx), bestScatter.YData(bestIdx), eventInfo.rain(bestIdx), eventInfo.acceleration(bestIdx));
inspectDayResponse(startTime, endTime, "freqMethod", "burg");
end

function cableWindAngle = calculateLocalCableWindAngle(windAzimuth, inclinationAngle, bridgeAzimuth)
% Converts global wind azimuth to local cable wind angle.
yawAngle = windAzimuth - bridgeAzimuth;
yawAngle = mod(yawAngle + 180, 360);
cableWindAngle = acosd(cosd(inclinationAngle) .* cosd(yawAngle));
end

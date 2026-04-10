function plotDampingSelectionDashboard(selectedPeaks, selectionInfo, options)
% plotDampingSelectionDashboard Plots a peak-centric dashboard for selected damping bounds.

arguments
    selectedPeaks table
    selectionInfo struct
    options.windContext (1,1) string {mustBeMember(options.windContext, ["global", "local"])} = "global"
    options.topCount (1,1) double {mustBeInteger, mustBePositive} = 8
end

if isempty(selectedPeaks)
    warning('No selected peaks to display in dashboard.');
    return;
end

fig = createFigure(121, 'DampingSelectionDashboard');
tlo = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
hold(ax1, 'on');
scatter(ax1, selectedPeaks.frequency, selectedPeaks.damping, 28, selectedPeaks.windSpeed, ...
    'filled', 'MarkerFaceAlpha', 0.7, 'MarkerEdgeColor', 'none');
grid(ax1, 'on'); box(ax1, 'on');
xlabel(ax1, 'Frequency (Hz)', 'Interpreter', 'latex');
ylabel(ax1, 'Damping $\zeta$', 'Interpreter', 'latex');
title(ax1, 'Frequency vs damping', 'Interpreter', 'latex');
set(ax1, 'TickLabelInterpreter', 'latex');
cb = colorbar(ax1);
cb.Label.String = 'Wind speed (m/s)';
cb.Label.Interpreter = 'latex';

ax2 = nexttile(tlo, 2);
histogram(ax2, selectedPeaks.frequency, 25, 'FaceColor', [0.15 0.45 0.75], 'EdgeColor', [0.1 0.1 0.1]);
grid(ax2, 'on'); box(ax2, 'on');
xlabel(ax2, 'Frequency (Hz)', 'Interpreter', 'latex');
ylabel(ax2, 'Count', 'Interpreter', 'latex');
title(ax2, 'Frequency distribution', 'Interpreter', 'latex');
set(ax2, 'TickLabelInterpreter', 'latex');

ax3 = polaraxes(tlo);
ax3.Layout.Tile = 3;
if options.windContext == "global"
    windAngleRad = deg2rad(mod(selectedPeaks.windDirection, 360));
    polarhistogram(ax3, windAngleRad, 24, 'FaceColor', [0.85 0.35 0.15], 'FaceAlpha', 0.75, 'EdgeColor', 'none');
    title(ax3, 'Global wind direction', 'Interpreter', 'latex');
else
    windAngleRad = deg2rad(mod(selectedPeaks.localWindDirection, 360));
    polarhistogram(ax3, windAngleRad, 24, 'FaceColor', [0.85 0.35 0.15], 'FaceAlpha', 0.75, 'EdgeColor', 'none');
    title(ax3, 'Local wind direction', 'Interpreter', 'latex');
end

ax4 = nexttile(tlo, 4);
hold(ax4, 'on');
histogram(ax4, selectedPeaks.windSpeed, 25, 'FaceColor', [0.2 0.55 0.25], 'FaceAlpha', 0.65, 'EdgeColor', 'none');
histogram(ax4, selectedPeaks.rainIntensity, 25, 'FaceColor', [0.15 0.35 0.7], 'FaceAlpha', 0.45, 'EdgeColor', 'none');
grid(ax4, 'on'); box(ax4, 'on');
xlabel(ax4, 'Value', 'Interpreter', 'latex');
ylabel(ax4, 'Count', 'Interpreter', 'latex');
title(ax4, 'Wind speed and rain intensity', 'Interpreter', 'latex');
legend(ax4, {'Wind speed', 'Rain intensity'}, 'Location', 'best', 'Interpreter', 'latex');
set(ax4, 'TickLabelInterpreter', 'latex');

ax5 = nexttile(tlo, 5);
[sensorNames, ~, sensorGroup] = unique(selectedPeaks.sensor);
sensorCounts = accumarray(sensorGroup, 1);
bar(ax5, sensorCounts, 'FaceColor', [0.7 0.3 0.2]);
grid(ax5, 'on'); box(ax5, 'on');
set(ax5, 'XTick', 1:numel(sensorNames), 'XTickLabel', cellstr(sensorNames), 'TickLabelInterpreter', 'none');
xtickangle(ax5, 30);
ylabel(ax5, 'Peak count', 'Interpreter', 'latex');
title(ax5, 'Sensor contribution', 'Interpreter', 'latex');

ax6 = nexttile(tlo, 6);
axis(ax6, 'off');
[~, sortedIdx] = sort(selectedPeaks.damping, 'descend');
topCount = min(options.topCount, height(selectedPeaks));
topIdx = sortedIdx(1:topCount);
topTable = selectedPeaks(topIdx, :);

textLines = strings(topCount + 1, 1);
textLines(1) = "Top damping events:";
for idx = 1:topCount
    textLines(idx + 1) = sprintf('%d) zeta=%.4f | f=%.3f Hz | %s | %s', ...
        idx, topTable.damping(idx), topTable.frequency(idx), char(topTable.sensor(idx)), ...
        datestr(topTable.startTime(idx), 'yyyy-mm-dd HH:MM'));
end
text(ax6, 0.01, 0.98, strjoin(textLines, newline), 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'Interpreter', 'tex');

if isfield(selectionInfo, 'flagName')
    flagLabel = string(selectionInfo.flagName);
else
    flagLabel = string(selectionInfo.flagField);
end

header = sprintf('Damping Selection Dashboard | Flag: %s | Direction: %s | Range: [%.4f, %.4f] | Peaks: %d', ...
    char(flagLabel), char(selectionInfo.direction), selectionInfo.dampingMin, selectionInfo.dampingMax, height(selectedPeaks));
title(tlo, header, 'Interpreter', 'none');
end

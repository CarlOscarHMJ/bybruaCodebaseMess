function [coverageTable] = getDataConverageTable(mode,fignumber)
arguments
    mode {mustBeTextScalar}= 'noPlot'
    fignumber {mustBeInteger} = 999
end

pathToTable = 'Data/coverageData.mat';
coverageTable = load(pathToTable);
coverageTable = coverageTable.coverageTable;

coverageTable.BridgeCoverage(isnan(coverageTable.BridgeCoverage)) = 0;
coverageTable.CableCoverage(isnan(coverageTable.CableCoverage)) = 0;

if strcmpi(mode,'plot')
    plotSensorCoverage(fignumber,coverageTable)
end
    
end

function fig = plotSensorCoverage(figNumber, coverageTable)
% PLOTSENSORCOVERAGE creates a linked 2x1 layout of bridge and cable sensor availability.

    fig = figure(figNumber);
    theme(fig, "light");
    tiledLayout = tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");

    % Bridge Coverage Tile
    ax(1) = nexttile();
    renderCoverageTile(ax(1), coverageTable.Date, coverageTable.BridgeCoverage, "Bridge");

    % Cable Coverage Tile
    ax(2) = nexttile();
    renderCoverageTile(ax(2), coverageTable.Date, coverageTable.CableCoverage, "Cable");
    xlabel(ax(2), "Date");

    % Link the x-axes for synchronized zooming and panning
    linkaxes(ax, "x");
end

function renderCoverageTile(targetAx, dateVector, coverageVector, labelPrefix)
% RENDERCOVERAGETILE handles plotting logic and statistical titling for a single tile.

    plot(targetAx, dateVector, coverageVector, "o-");
    ylabel(targetAx, sprintf("%s coverage", labelPrefix));
    ylim(targetAx, [0 1]); 
    grid(targetAx, "on");

    measuredDays = sum(coverageVector);
    totalCoveragePercentage = (measuredDays / numel(coverageVector)) * 100;
    
    title(targetAx, sprintf("Total %s coverage %2.0f%%. Total number of measured days %3.1f", ...
          lower(labelPrefix), totalCoveragePercentage, measuredDays));
end
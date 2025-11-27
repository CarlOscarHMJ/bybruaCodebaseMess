function [coverageTable] = getDataConverageTable(mode,fignumber)

pathToTable = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data/coverageData.mat';
coverageTable = load(pathToTable);
coverageTable = coverageTable.coverageTable;

coverageTable.BridgeCoverage(isnan(coverageTable.BridgeCoverage)) = 0;
coverageTable.CableCoverage(isnan(coverageTable.CableCoverage)) = 0;

if strcmpi(mode,'plot')
    fig=figure(fignumber);
    theme(fig,"light");
    tiledlayout(2,1,"TileSpacing","compact","Padding","compact")

    nexttile
    plot(coverageTable.Date,coverageTable.BridgeCoverage,"o-")
    ylabel("Bridge coverage")
    ylim([0 1]); grid on
    MeasuredBridgeDays = sum(coverageTable.BridgeCoverage);
    TotalBridgeCoverage = MeasuredBridgeDays/numel(coverageTable.BridgeCoverage);
    title(sprintf('Total bridge coverage %2.0f%%. Total number of measured days %3.1f',...
                  TotalBridgeCoverage*100,MeasuredBridgeDays))

    nexttile
    plot(coverageTable.Date,coverageTable.CableCoverage,"o-")
    ylabel("Cable coverage")
    xlabel("Date")
    ylim([0 1]); grid on
    MeasuredCableDays = sum(coverageTable.CableCoverage);
    TotalCableCoverage = MeasuredCableDays/numel(coverageTable.CableCoverage);
    title(sprintf('Total cable coverage %2.0f%%. Total number of measured days %3.1f',...
                   TotalCableCoverage*100,MeasuredCableDays))
end
    
end
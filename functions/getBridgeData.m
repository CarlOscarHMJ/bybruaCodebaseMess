function byBroaOverview = getBridgeData(startDate, endDate, options)
% initializeBridgeData creates the bridge project object and applies signal filters.
arguments
    startDate {mustBeA(startDate, 'datetime')}
    endDate   {mustBeA(endDate, 'datetime')}
    options.dataRoot string = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data'
    options.applyFilter logical = true
    options.filterOrder double = 7
    options.filterLowFreq double = 0.4
    options.filterHighFreq double = 15
    options.filterType string = 'butter'
    options.plotFilter logical = false
    options.plotTimeResponse logical = false
end

byBroa = BridgeProject(options.dataRoot, startDate, endDate);
byBroaOverview = BridgeOverview(byBroa);
byBroaOverview = byBroaOverview.fillMissingDataPoints();

if options.applyFilter
    byBroaOverview = byBroaOverview.designFilter( ...
        options.filterType, ...
        order=options.filterOrder, ...
        fLow=options.filterLowFreq, ...
        fHigh=options.filterHighFreq,...
        plotFilter=options.plotFilter);
    byBroaOverview = byBroaOverview.applyFilter();
end

if options.plotTimeResponse
    figure
    nexttile;
    plot(byBroaOverview.project.bridgeData.Time,byBroaOverview.project.bridgeData.Steel_Z,'DisplayName','Filtered')
    hold on
    plot(byBroa.bridgeData.Time,byBroa.bridgeData.Steel_Z,'DisplayName','Raw')
    legend
    title(sprintf('%s - %s', ...
        char(byBroa.startTime), ...
        char(datetime(byBroa.endTime,'Format','HH:mm'))))
    keyboard
end
end
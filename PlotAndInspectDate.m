clear all
clc

addpath('functions')

dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';

getDataConverageTable('plot',999);
%% Load Bridge
clear Bybroa BybroaOverview
startTime = datetime('2019-8-28');
endTime   = datetime('2019-8-28 11:59:59');
ByBroa = BridgeProject(dataRoot,startTime, endTime); 
%% Filter
ByBroaOverview = BridgeOverview(ByBroa);
ByBroaOverview = ByBroaOverview.fillMissingDataPoints;
ByBroaOverview = ByBroaOverview.designFilter(plotFilter=true,figNum=999,fLow=0.5);
ByBroaOverview = ByBroaOverview.designFilter('butter',order=6,fLow=0.5);
ByBroaOverview = ByBroaOverview.applyFilter;
%% Day plot
ByBroaOverview.plotTimeHistory('displacement');
ByBroaOverview.plotEpsdHistory(10,[]);
%% Inspection Period
timeInterval = hours(1);
timeInterval = minutes(10);
InspectionTimes = startTime : timeInterval : endTime;

for ii = 1:length(InspectionTimes)
    selectedTimePeriod = [InspectionTimes(ii),...
                          InspectionTimes(ii)+timeInterval];
    ByBroaOverview.plotTimeHistory('displacement',selectedTimePeriod);
    ByBroaOverview.plotEpsdHistory(1,selectedTimePeriod);
    ByBroaOverview.plotHeaveCoherence('C1E_y', selectedTimePeriod,fLow=0.5)
    ByBroaOverview.plotCablePhaseSpace(selectedTimePeriod)
end
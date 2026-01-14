clear all; clc;
addpath('../functions');

dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';

startTime = datetime('2020-02-21 00:00:00');
endTime   = datetime('2020-02-22 23:59:59');

byBroa = BridgeProject(dataRoot, startTime, endTime);
byBroaOverview = BridgeOverview(byBroa);

byBroaOverview = byBroaOverview.fillMissingDataPoints;
byBroaOverview = byBroaOverview.designFilter('butter', order=7, fLow=0.5);
byBroaOverview = byBroaOverview.applyFilter;

byBroaOverview.plotEventValidation();
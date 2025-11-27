clearvars
clc

addpath('functions')

dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';

getDataConverageTable('plot',999);
%%
InspectPeriod = [datetime(2019,8,20),datetime(2019,9,24)];
ByBroa = BridgeProject(dataRoot,'2019-8-28', '2019-8-28'); 
% %%
% ByBroaOverview = BridgeOverview(ByBroa);
% ByBroaOverview.plotTimeHistory('acceleration');
% ByBroaOverview.plotEpsdHistory(10,[]);
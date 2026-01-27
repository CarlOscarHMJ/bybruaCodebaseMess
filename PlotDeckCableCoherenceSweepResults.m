clear all
clc

%load("Data/results/cableCoherenceResults20251217.mat")
%load("Data/results/cableCoherenceResults202512172.mat")
load("Data/results/cableCoherenceResults.mat")
%%
addpath('functions/')
PlotResults(cohResults,'C1W_y','Steel_Z',1)
PlotResults(cohResults,'C1W_y','Conc_Z',2)
PlotResults(cohResults,'C2W_y','Steel_Z',3)
PlotResults(cohResults,'C2W_y','Conc_Z',4)
PlotResults(cohResults,'C1E_y','Steel_Z',5)
PlotResults(cohResults,'C1E_y','Conc_Z',6)
PlotResults(cohResults,'C2E_y','Steel_Z',7)
PlotResults(cohResults,'C2E_y','Conc_Z',8)

function PlotResults(cohResults,cable,bridge,fignum)
cohResults = cohResults(strcmp([cohResults.cable],cable));
cohResults = cohResults(strcmp([cohResults.bridge],bridge));
[~,sortedResults] = sort([cohResults.startTime]);
cohResults = cohResults(sortedResults);

if isempty(cohResults)
    error('No results found for the specified cable and bridge.');
end

N     = length(cohResults);
NVals = 5;

time = NaT(N*NVals, 1);    % datetime
freq = zeros(N*NVals, 1); % frequency
cohe = zeros(N*NVals, 1); % coherence value
cableStd = zeros(N*NVals,1);
precipitation = zeros(N*NVals,1);

idx = 1;
for i = 1:N
    inds = idx:(idx+NVals-1);

    time(inds) = repmat(cohResults(i).startTime,NVals,1);
    freq(inds) = cohResults(i).cohPeakFreqs(1:NVals);
    cohe(inds) = cohResults(i).cohPeakVals(1:NVals);
    idx = idx + NVals;
end
%%
[~,idx] = sort(cohe);
figure(fignum);clf
tl=tiledlayout(5,1,'TileSpacing','compact');
ax(1) = nexttile([2,1]);
s = scatter(time(idx), freq(idx), 20, cohe(idx), 'filled');
cb=colorbar;
cb.Label.String = '|\gamma|^2';
% mymap = flip(slanCM('oxy'));
% colormap(mymap(55:end,:))
colormap(slanCM('GnBu'))
ylabel('Peak Frequency')
ylim([0 10])


ax(2) = nexttile;
cableStd = vertcat(cohResults.cableStd);
scatter([cohResults.startTime]',cableStd.Variables,'o','filled','MarkerFaceAlpha',0.3)
ylabel('\sigma(r_y) (m/s^2)')
ylim([0 Inf])

ax(3) = nexttile;
scatter([cohResults.startTime],[cohResults.precipitationMean],'o','filled','MarkerFaceAlpha',0.3)
ylabel('Precipitation')
ylim([0 Inf])

ax(4) = nexttile;
yyaxis left
scatter([cohResults.startTime],[cohResults.windSpeedMean],'o','filled','MarkerFaceAlpha',0.3)
ylabel('u (m/s)')
yyaxis right
scatter([cohResults.startTime],[cohResults.windDirMean],'o','filled','MarkerFaceAlpha',0.3)
ylabel('\Psi (deg)')
ylim([0 360])
yticks(0:90:360)

xlabel(tl,'Time')
title(tl,['Cable: ' cable ', Bridge: ' bridge])
linkaxes(ax,'x')
% xlim(ax(1),[datetime('2019-07-15') ...
%             datetime('2019-09-20')])
end
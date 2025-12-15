clear all
clc

load("Data/results/cableCoherenceResults.mat")

N     = length(cohResults);
NVals = 5;

x = NaT(N*NVals, 1);    % datetime
y = zeros(N*NVals, 1); % frequency
c = zeros(N*NVals, 1); % coherence value

idx = 1;

for i = 1:N
    if ~strcmpi(cohResults(i).cable,'C1W_y')
        continue
    end
    
    inds = idx:(idx+NVals-1);

    x(inds) = cohResults(i).startTime;
    y(inds) = cohResults(i).cohPeakFreqs(1:NVals);
    c(inds) = cohResults(i).cohPeakVals(1:NVals);

    idx = idx + NVals;
end

%h = scatter(x, y, 36, 'red', 'filled');
%h.AlphaData = c;
%h.MarkerFaceAlpha = "flat";
scatter(x, y, 36, c, 'filled');
colorbar
xlabel('Start Time')
ylabel('Peak Frequency')

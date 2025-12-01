clearvars
clc

addpath('functions')

dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';

queryFreqs = [6.27, 3.14, 9.40, 5.19];

coverageTable = getDataConverageTable('noPlot',999);

hasBridgeAndCable = coverageTable.BridgeCoverage > 0 & coverageTable.CableCoverage > 0;
analysisDays      = coverageTable.Date(hasBridgeAndCable);
analysisDays      = analysisDays(analysisDays~=datetime(2019,06,29));

set(groot, 'DefaultFigureVisible', 'off')

resultsRoot = fullfile(dataRoot,'results');
figRoot     = fullfile(resultsRoot,'figures','coherenceSweep');

if ~exist(resultsRoot,'dir')
    mkdir(resultsRoot)
end

if ~exist(figRoot,'dir')
    mkdir(figRoot)
end

cohResults = struct('startTime',{}, ...
    'endTime',{}, ...
    'peakFreq',{}, ...
    'coherenceVal',{}, ...
    'response',{});

idxResult = 0;

for idDay = 1:numel(analysisDays)
    for halfDay = 1:2
        if halfDay == 1
            chunkStart = analysisDays(idDay);
            chunkEnd   = chunkStart + hours(12) - seconds(1);
            halfTag = "AM";
        else
            chunkStart = analysisDays(idDay) + hours(12);
            chunkEnd   = analysisDays(idDay) + hours(24) - seconds(1);
            halfTag = "PM";
        end

        clear ByBroa ByBroaOverview
        
        ByBroa = BridgeProject(dataRoot, chunkStart, chunkEnd);

        if isempty(ByBroa.bridgeData) || isempty(ByBroa.cableData)
            fprintf("Skipping %s – %s (no data)\n", ...
                    datestr(chunkStart), datestr(chunkEnd));
            continue
        end

        ByBroaOverview = BridgeOverview(ByBroa);
        ByBroaOverview = ByBroaOverview.fillMissingDataPoints;
        %ByBroaOverview = ByBroaOverview.designFilter(plotFilter=true, figNum=999, fLow=0.2);
        ByBroaOverview = ByBroaOverview.designFilter('butter', order=7, fLow=0.2);
        ByBroaOverview = ByBroaOverview.applyFilter;

        %% Day plots (acceleration)
        ByBroaOverview.plotTimeHistory('acceleration');
        dayTag = datestr(chunkStart,'yyyymmdd');
        saveas(gcf, fullfile(figRoot, "Day_" + dayTag + halfTag + "_TimeHistory_acc.png"))

        ByBroaOverview.plotEpsdHistory(10,[]);
        saveas(gcf, fullfile(figRoot, "Day_" + dayTag + halfTag + "_EpsdHistory_acc.png"))
        %% 10-minute inspection
        timeInterval    = minutes(10);
        inspectionTimes = chunkStart:timeInterval:(chunkEnd - timeInterval);

        for ii = 1:numel(inspectionTimes)
            selectedTimePeriod = [inspectionTimes(ii), inspectionTimes(ii) + timeInterval];

            range = timerange(selectedTimePeriod(1), selectedTimePeriod(2));

            bridgeSeg = ByBroa.bridgeData(range,:);
            cableSeg  = ByBroa.cableData(range,:);

            if isempty(bridgeSeg) || isempty(cableSeg)
                fprintf("Skipping %s – %s (no data)\n", ...
                    datestr(selectedTimePeriod(1)), datestr(selectedTimePeriod(2)));
                continue
            end

            segStartTag = datestr(selectedTimePeriod(1),'yyyymmdd_HHMM');
            segEndTag   = datestr(selectedTimePeriod(2),'HHMM');
            segTag      = segStartTag + "_" + segEndTag;

            ByBroaOverview.plotTimeHistory('acceleration', selectedTimePeriod);
            saveas(gcf, fullfile(figRoot, "Seg_" + segTag + "_TimeHistory_acc.png"))

            ByBroaOverview.plotEpsdHistory(0.5, selectedTimePeriod);
            saveas(gcf, fullfile(figRoot, "Seg_" + segTag + "_EpsdHistory_30s_acc.png"))

            opts           = struct;
            opts.fLow      = 0.5;
            opts.fHigh     = 10;
            opts.Npeaks    = 5;
            opts.queryFreqs = queryFreqs;

            [peakFreq, coherenceVal, response] = ...
                ByBroaOverview.plotHeaveCoherence('C1E_y', selectedTimePeriod,...
                          fLow=0.5,fHigh=10,Npeaks=5,queryFreq=queryFreqs);
            saveas(gcf, fullfile(figRoot, "Seg_" + segTag + "_HeaveCoherence_C1E_y.png"))

            ByBroaOverview.plotCablePhaseSpace(selectedTimePeriod);
            saveas(gcf, fullfile(figRoot, "Seg_" + segTag + "_CablePhaseSpace.png"))

            idxResult = idxResult + 1;
            cohResults(idxResult).startTime     = selectedTimePeriod(1);
            cohResults(idxResult).endTime       = selectedTimePeriod(2);
            cohResults(idxResult).peakFreq      = peakFreq;
            cohResults(idxResult).coherenceVal  = coherenceVal;
            cohResults(idxResult).response      = response;
        end
    end
    save(fullfile(resultsRoot,'cableCoherenceResults.mat'), 'cohResults', 'queryFreqs')
end

save(fullfile(resultsRoot,'cableCoherenceResults.mat'), 'cohResults', 'queryFreqs')

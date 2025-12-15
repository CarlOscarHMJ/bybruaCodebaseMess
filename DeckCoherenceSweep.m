clearvars
clc

addpath('functions')

dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';
Root = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis';

queryFreqs = [6.27, 3.14, 9.40, 5.19];

coverageTable = getDataConverageTable('noPlot',999);

hasBridgeAndCable = coverageTable.BridgeCoverage > 0 & coverageTable.CableCoverage > 0;
analysisDays      = coverageTable.Date(hasBridgeAndCable);
analysisDays      = analysisDays(analysisDays~=datetime(2019,06,29));

set(groot, 'DefaultFigureVisible', 'off')
warning('off','signal:findpeaks:largeMinPeakHeight')
warning('off','MATLAB:table:ModifiedVarnames')

resultsRoot = fullfile(dataRoot,'results');
figRoot     = fullfile(resultsRoot,'figures','coherenceSweep');

if ~exist(resultsRoot,'dir')
    mkdir(resultsRoot)
end

if ~exist(figRoot,'dir')
    mkdir(figRoot)
end

cohResults = InitStruct();

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
        % ByBroaOverview.plotTimeHistory('acceleration');
        % dayTag = datestr(chunkStart,'yyyymmdd');
        % saveas(gcf, fullfile(figRoot, "Day_" + dayTag + halfTag + "_TimeHistory_acc.png"))
        % 
        % ByBroaOverview.plotEpsdHistory(10,[]);
        % saveas(gcf, fullfile(figRoot, "Day_" + dayTag + halfTag + "_EpsdHistory_acc.png"))
        %% 10-minute inspection
        timeInterval    = minutes(10);
        inspectionTimes = chunkStart:timeInterval:(chunkEnd - timeInterval);

        bridgeVars = {'Conc','Steel'};
        cableVars  = findCableGroups(ByBroa.cableData.Properties.VariableNames);

        numSegments        = numel(inspectionTimes);
        cohSegmentResults  = cell(numSegments,1);

        for ii = 1:numel(inspectionTimes)
            selectedTimePeriod = [inspectionTimes(ii), inspectionTimes(ii) + timeInterval];

            timeSegment = timerange(selectedTimePeriod(1), selectedTimePeriod(2));

            if ~hasData(ByBroa.bridgeData, selectedTimePeriod(1), selectedTimePeriod(2)) || ...
               ~hasData(ByBroa.cableData,  selectedTimePeriod(1), selectedTimePeriod(2))

                fprintf("Skipping %s – %s (no data)\n", ...
                    datestr(selectedTimePeriod(1)), datestr(selectedTimePeriod(2)));
                cohSegmentResults{ii} = InitStruct();
                continue
            end

            segStartTag = datestr(selectedTimePeriod(1),'yyyymmdd_HHMM');
            segEndTag   = datestr(selectedTimePeriod(2),'HHMM');
            segTag      = segStartTag + "_" + segEndTag;
            
            localResults = InitStruct();
            localIdx     = 0;

            for jj = 1:length(bridgeVars)
                for kk = 1:length(cableVars)
                    deckField = [bridgeVars{jj} '_Z'];
                    cableField = [cableVars{kk} '_y'];

                    printMsg = sprintf("Time: %s, Analyzing %s and %s\t during %s – %s", ...
                               string(datetime("now")), deckField, cableField,...
                               datestr(selectedTimePeriod(1)), datestr(selectedTimePeriod(2)));

                    [Cxy,f,~,~,~] = ByBroaOverview.coherence(deckField, ...
                                    cableField, selectedTimePeriod, false);
                    coherenceMagSquared = abs(Cxy).^2;
                    IntrestZone = [ByBroaOverview.filter.fLow,10];
                    
                    idx = IntrestZone(1) <= f & f <= IntrestZone(2);
                    [peakVals,peakFreqs] = findpeaks(coherenceMagSquared(idx),...
                                                f(idx),'SortStr','descend');
                    
                    if peakVals(1) < 0.5
                        fprintf("%s - Found coh < 0.5, skipping.\n",printMsg);
                        continue
                    elseif peakVals(1) > 0.95
                        fprintf("%s - Found coh > 0.95, saving and plotting.\n",printMsg);
                        plotResults(selectedTimePeriod,segTag,figRoot,ByBroaOverview,cableField)
                    else
                        fprintf("%s - Found coh > 0.5, saving.\n",printMsg);
                    end
 
                    localIdx = localIdx + 1;
                    localResults(localIdx).startTime = selectedTimePeriod(1);
                    localResults(localIdx).endTime   = selectedTimePeriod(2);
                    localResults(localIdx).cable     = cableField;
                    localResults(localIdx).bridge    = deckField;

                    cableDataVec = ByBroa.cableData.(cableField);
                    bridgeDataVec = ByBroa.bridgeData.(deckField);

                    localResults(localIdx).cableMean     = mean(cableDataVec);
                    localResults(localIdx).cableStd      = std(cableDataVec);
                    localResults(localIdx).cableSkewness = skewness(cableDataVec);
                    localResults(localIdx).cableKurtosis = kurtosis(cableDataVec);

                    localResults(localIdx).bridgeMean      = mean(bridgeDataVec);
                    localResults(localIdx).bridgeStd       = std(bridgeDataVec);
                    localResults(localIdx).bridgeSkewness  = skewness(bridgeDataVec);
                    localResults(localIdx).bridgeKurtosis  = kurtosis(bridgeDataVec);

                    localResults(localIdx).cohPeakVals  = peakVals;
                    localResults(localIdx).cohPeakFreqs = peakFreqs;

                    localResults(localIdx).windDirMean      = mean(getDataInRange(ByBroa.weatherData.WindDir,selectedTimePeriod));
                    localResults(localIdx).windDirStd       =  std(getDataInRange(ByBroa.weatherData.WindDir,selectedTimePeriod));
                    localResults(localIdx).windSpeedMean    = mean(getDataInRange(ByBroa.weatherData.WindSpeed,selectedTimePeriod));
                    localResults(localIdx).windSpeedStd     =  std(getDataInRange(ByBroa.weatherData.WindSpeed,selectedTimePeriod));
                    localResults(localIdx).precipitationMean= mean(getDataInRange(ByBroa.weatherData.Precipitation,selectedTimePeriod));
                    localResults(localIdx).precipitationStd =  std(getDataInRange(ByBroa.weatherData.Precipitation,selectedTimePeriod));
                    localResults(localIdx).airTempMean      = mean(getDataInRange(ByBroa.weatherData.AirTemp,selectedTimePeriod));
                    localResults(localIdx).airPressMean     = mean(getDataInRange(ByBroa.weatherData.AirPress,selectedTimePeriod));
                end
            end
            cohSegmentResults{ii} = localResults;
        end
    end
    chunkResults = [cohSegmentResults{:}];
    cohResults   = [cohResults, chunkResults]; %#ok<AGROW>

    save(fullfile(resultsRoot,'cableCoherenceResults.mat'), 'cohResults', 'queryFreqs')
end

save(fullfile(resultsRoot,'cableCoherenceResults.mat'), 'cohResults', 'queryFreqs')

function plotResults(selectedTimePeriod,segTag,figRoot,ByBroaOverview,cableField)
ByBroaOverview.plotTimeHistory('acceleration', selectedTimePeriod);
saveas(gcf, fullfile(figRoot, "Seg_" + segTag + "_TimeHistory_acc.png"))

ByBroaOverview.plotEpsdHistory(0.5, selectedTimePeriod);
saveas(gcf, fullfile(figRoot, "Seg_" + segTag + "_EpsdHistory_30s_acc.png"))

ByBroaOverview.plotHeaveCoherence(cableField, selectedTimePeriod,...
                          fLow=0.5,fHigh=10,Npeaks=5);
saveas(gcf, fullfile(figRoot, "Seg_" + segTag + "_HeaveCoherence_" + string(cableField) + ".png"))

ByBroaOverview.plotCablePhaseSpace(selectedTimePeriod);
saveas(gcf, fullfile(figRoot, "Seg_" + segTag + "_CablePhaseSpace.png"))

close all
end

function cohStruct = InitStruct()
cohStruct = struct('startTime',{}, ...
    'endTime',{}, ...
    'cable',{}, ...
    'bridge',{}, ...
    'cableMean',{}, ...
    'cableStd',{}, ...
    'cableSkewness',{}, ...
    'cableKurtosis',{}, ...
    'bridgeMean',{}, ...
    'bridgeStd',{}, ...
    'bridgeSkewness',{}, ...
    'bridgeKurtosis',{}, ...
    'cohPeakVals',{}, ...
    'cohPeakFreqs',{}, ...
    'windDirMean',{}, ...
    'windDirStd',{}, ...
    'windSpeedMean',{}, ...
    'windSpeedStd',{}, ...
    'precipitationMean',{}, ...
    'precipitationStd',{}, ...
    'airTempMean',{}, ...
    'airPressMean',{});
end

function tf = hasData(timetableObj, t0, t1)
tf = any(timetableObj.Time >= t0 & timetableObj.Time <= t1);
end

function dataInRange = getDataInRange(structure,timeSegment)
idx = timeSegment(1) <= structure.Time & structure.Time <= timeSegment(2);
dataInRange = structure.Data(idx);
end
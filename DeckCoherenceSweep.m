clearvars
clc

addpath('functions')

dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';
queryFreqs = [6.27, 3.14, 9.40, 5.19];
plotTrigger = false;

set(groot,'DefaultFigureVisible','off')
warning('off','signal:findpeaks:largeMinPeakHeight')
warning('off','MATLAB:table:ModifiedVarnames')

resultsRoot = fullfile(dataRoot,'results');
figRoot     = fullfile(resultsRoot,'figures','coherenceSweep');

stateRoot   = fullfile(resultsRoot,'state');
lockRoot    = fullfile(stateRoot,'locks');

ensureDir(resultsRoot)
ensureDir(figRoot)
ensureDir(stateRoot)
ensureDir(lockRoot)

taskFile = fullfile(stateRoot,'taskQueue.mat');
logFile  = fullfile(stateRoot,'workers.log');
resFile  = fullfile(resultsRoot,'cableCoherenceResults.mat');

workerId = getWorkerId();
logMessage(logFile, workerId, "START", "Worker started");

initLockName = "initQueue";

if ~exist(taskFile,'file')
    if acquireLock(lockRoot, initLockName, 0.25, 300)
        cleanupInit = onCleanup(@() safeReleaseLock(lockRoot, initLockName));
        if ~exist(taskFile,'file')
            logMessage(logFile, workerId, "INIT", "Building half-day task queue");
            buildTaskQueueHalfDay(taskFile);
        end
    else
        logMessage(logFile, workerId, "INIT_WAIT_FAIL", "Could not lock initQueue");
    end
end

if ~exist(resFile,'file')
    cohResults = initStruct();
    atomicSaveMat(resFile, struct('cohResults',cohResults,'queryFreqs',queryFreqs))
end

while true
    task = acquireNextTask(taskFile, lockRoot, workerId, logFile);
    if isempty(task)
        logMessage(logFile, workerId, "DONE", "No tasks left");
        break
    end

    logMessage(logFile, workerId, "TASK", task.tag);
    [localResults, statusMsg] = processHalfDayTask(task, dataRoot, figRoot, queryFreqs, plotTrigger);
    logMessage(logFile, workerId, "TASK_STATUS", task.tag + " | " + statusMsg);

    appendResults(resFile, lockRoot, localResults, logFile, workerId);
    completeTask(taskFile, lockRoot, workerId, task.taskId, logFile);
end

logMessage(logFile, workerId, "STOP", "Worker stopped");

function buildTaskQueueHalfDay(taskFile)
    coverageTable = getDataConverageTable('noPlot',999);

    hasBridgeAndCable = coverageTable.BridgeCoverage > 0 & coverageTable.CableCoverage > 0;
    analysisDays = coverageTable.Date(hasBridgeAndCable);
    analysisDays = analysisDays(analysisDays ~= datetime(2019,06,29));

    tasks = struct('taskId',{},'chunkStart',{},'chunkEnd',{},'halfTag',{},'tag',{},'status',{},'workerId',{},'tsStart',{},'tsEnd',{});
    taskId = 0;

    for idDay = 1:numel(analysisDays)
        for halfDay = 1:2
            if halfDay == 1
                chunkStart = analysisDays(idDay);
                chunkEnd   = chunkStart + hours(12) - seconds(1);
                halfTag    = "AM";
            else
                chunkStart = analysisDays(idDay) + hours(12);
                chunkEnd   = analysisDays(idDay) + hours(24) - seconds(1);
                halfTag    = "PM";
            end

            dayTag = datestr(chunkStart,'yyyymmdd');
            tag = "Day_" + string(dayTag) + "_" + halfTag;

            taskId = taskId + 1;
            tasks(taskId).taskId     = taskId;
            tasks(taskId).chunkStart = chunkStart;
            tasks(taskId).chunkEnd   = chunkEnd;
            tasks(taskId).halfTag    = halfTag;
            tasks(taskId).tag        = tag;
            tasks(taskId).status     = "pending";
            tasks(taskId).workerId   = "";
            tasks(taskId).tsStart    = NaT;
            tasks(taskId).tsEnd      = NaT;
            tasks(taskId).claimToken = "";
        end
    end

    atomicSaveMat(taskFile, struct('tasks',tasks))
end

function task = acquireNextTask(taskFile, lockRoot, workerId, logFile)
    lockName = "taskQueue";
    task = struct([]);

    if ~acquireLock(lockRoot, lockName, 0.05, 300)
        logMessage(logFile, workerId, "LOCK_FAIL", "Could not lock taskQueue");
        return
    end

    cleanup = onCleanup(@() safeReleaseLock(lockRoot, lockName));

    try
        s = load(taskFile,'tasks');
        tasks = s.tasks;
    catch ME
        logMessage(logFile, workerId, "TASKFILE_LOAD_FAIL", string(ME.identifier));
        return
    end

    pendingIdxs = find(strcmp(string({tasks.status}), "pending"));
    if isempty(pendingIdxs)
        return
    end

    rng(getWorkerSeed(workerId));
    pendingIdx = pendingIdxs(randi(numel(pendingIdxs)));

    claimToken = workerId + "_" + string(feature("getpid")) + "_" + string(randi(1e9));
    tasks(pendingIdx).status     = "running";
    tasks(pendingIdx).workerId   = workerId;
    tasks(pendingIdx).claimToken = claimToken;
    tasks(pendingIdx).tsStart    = datetime("now");

    try
        atomicSaveMat(taskFile, struct('tasks',tasks))
    catch ME
        logMessage(logFile, workerId, "TASKFILE_SAVE_FAIL", string(ME.identifier));
        return
    end

    try
        s2 = load(taskFile,'tasks');
        tasks2 = s2.tasks;
    catch ME
        logMessage(logFile, workerId, "TASKFILE_RELOAD_FAIL", string(ME.identifier));
        return
    end

    if ~isfield(tasks2(pendingIdx),'claimToken') || tasks2(pendingIdx).claimToken ~= claimToken
        logMessage(logFile, workerId, "CLAIM_LOST", "Lost claim for taskId=" + string(tasks(pendingIdx).taskId));
        task = struct([]);
        return
    end

    task = tasks2(pendingIdx);
end

function completeTask(taskFile, lockRoot, workerId, taskId, logFile)
    lockName = "taskQueue";

    if ~acquireLock(lockRoot, lockName, 0.25, 120)
        logMessage(logFile, workerId, "LOCK_FAIL", "Could not lock taskQueue to complete");
        return
    end

    cleanup = onCleanup(@() safeReleaseLock(lockRoot, lockName));

    try
        s = load(taskFile,'tasks');
        tasks = s.tasks;
    catch ME
        logMessage(logFile, workerId, "TASKFILE_LOAD_FAIL", string(ME.identifier));
        return
    end

    idx = find([tasks.taskId] == taskId, 1, 'first');
    if isempty(idx)
        logMessage(logFile, workerId, "TASK_MISSING", string(taskId));
        return
    end

    tasks(idx).status = "done";
    tasks(idx).claimToken = "";
    tasks(idx).tsEnd  = datetime("now");

    try
        atomicSaveMat(taskFile, struct('tasks',tasks))
    catch ME
        logMessage(logFile, workerId, "TASKFILE_SAVE_FAIL", string(ME.identifier));
    end
end

function [localResults, statusMsg] = processHalfDayTask(task, dataRoot, figRoot, queryFreqs, plotTrigger)
    localResults = initStruct();
    statusMsg = "OK";

    chunkStart = task.chunkStart;
    chunkEnd   = task.chunkEnd;

    try
        ByBroa = BridgeProject(dataRoot, chunkStart, chunkEnd);

        hasBridge = ~isempty(ByBroa.bridgeData);
        hasCable  = ~isempty(ByBroa.cableData);

        if ~hasBridge || ~hasCable
            statusMsg = "NO_DATA_CHUNK bridge=" + string(hasBridge) + " cable=" + string(hasCable);
            return
        end

        ByBroaOverview = BridgeOverview(ByBroa);
        ByBroaOverview = ByBroaOverview.fillMissingDataPoints;
        ByBroaOverview = ByBroaOverview.designFilter('butter', order=7, fLow=0.2);
        ByBroaOverview = ByBroaOverview.applyFilter;

    catch ME
        statusMsg = "CHUNK_ERROR: " + string(ME.identifier) + " | " + string(ME.message);
        localResults = initStruct();
        return
    end

    timeInterval = minutes(10);
    inspectionTimes = chunkStart:timeInterval:(chunkEnd - timeInterval);

    segPairs = 0;

    bridgeVars = {'Conc','Steel'};
    cableVars  = findCableGroups(ByBroa.cableData.Properties.VariableNames);

    totalAdded = 0;

    for ii = 1:numel(inspectionTimes)
        selectedTimePeriod = [inspectionTimes(ii), inspectionTimes(ii) + timeInterval];

        try
            if ~hasData(ByBroa.bridgeData, selectedTimePeriod(1), selectedTimePeriod(2)) || ...
               ~hasData(ByBroa.cableData,  selectedTimePeriod(1), selectedTimePeriod(2))
                continue
            end

            segStartTag = datestr(selectedTimePeriod(1),'yyyymmdd_HHMM');
            segEndTag   = datestr(selectedTimePeriod(2),'HHMM');
            segTag      = string(segStartTag) + "_" + string(segEndTag);

            for jj = 1:numel(bridgeVars)
                for kk = 1:numel(cableVars)
                    deckField  = bridgeVars{jj} + "_Z";
                    cableField = cableVars{kk} + "_y";

                    try
                        [Cxy,f,~,~,~] = ByBroaOverview.coherence(deckField, cableField, selectedTimePeriod, false);
                        coherenceMagSquared = abs(Cxy).^2;

                        interestZone = [ByBroaOverview.filter.fLow, 10];
                        idx = interestZone(1) <= f & f <= interestZone(2);
                        if ~any(idx)
                            continue
                        end

                        [peakVals, peakFreqs] = findpeaks(coherenceMagSquared(idx), f(idx), 'SortStr','descend');
                        if isempty(peakVals)
                            continue
                        end

                        if peakVals(1) > 0.95 && plotTrigger
                           try
                              plotResults(selectedTimePeriod, task.tag + "_Seg_" + segTag, figRoot, ByBroaOverview, cableField)
                           catch
                           end
                        end

                        totalAdded = totalAdded + 1;
                        segPairs = segPairs + 1;
                        localResults(totalAdded) = makeResultRow(ByBroa, selectedTimePeriod, cableField, deckField, peakVals, peakFreqs, queryFreqs);

                        logMessage( ...
                            fullfile(tempdir,'bybroa_state','workers.log'), ...
                            getWorkerId(), ...
                            "SEG", ...
                            task.tag + " " + segPairs + " pairs=" + string(segPairs) ...
                            );

                    catch
                        continue
                    end
                end
            end

        catch
            continue
        end
    end

    if isempty(localResults)
        statusMsg = "NO_RESULTS";
    else
        statusMsg = "OK n=" + string(numel(localResults));
    end
end

function row = makeResultRow(ByBroa, selectedTimePeriod, cableField, deckField, peakVals, peakFreqs, queryFreqs)
    row = initStruct();

    row(1).startTime = selectedTimePeriod(1);
    row(1).endTime   = selectedTimePeriod(2);
    row(1).cable     = cableField;
    row(1).bridge    = deckField;

    timeRange = timerange(selectedTimePeriod(1),selectedTimePeriod(2));
    cableDataVec  = ByBroa.cableData(timeRange,cableField);
    bridgeDataVec = ByBroa.bridgeData(timeRange,deckField);

    row(1).cableMean     = mean(cableDataVec,'omitmissing');
    row(1).cableStd      = std(cableDataVec,'omitmissing');
    row(1).cableSkewness = skewness(cableDataVec);
    row(1).cableKurtosis = kurtosis(cableDataVec);

    row(1).bridgeMean     = mean(bridgeDataVec,'omitmissing');
    row(1).bridgeStd      = std(bridgeDataVec,'omitmissing');
    row(1).bridgeSkewness = skewness(bridgeDataVec);
    row(1).bridgeKurtosis = kurtosis(bridgeDataVec);

    row(1).cohPeakVals  = peakVals;
    row(1).cohPeakFreqs = peakFreqs;

    row(1).windDirMean       = mean(getDataInRange(ByBroa.weatherData.WindDir,selectedTimePeriod),'omitmissing');
    row(1).windDirStd        = std(getDataInRange(ByBroa.weatherData.WindDir,selectedTimePeriod),'omitmissing');
    row(1).windSpeedMean     = mean(getDataInRange(ByBroa.weatherData.WindSpeed,selectedTimePeriod),'omitmissing');
    row(1).windSpeedStd      = std(getDataInRange(ByBroa.weatherData.WindSpeed,selectedTimePeriod),'omitmissing');
    row(1).precipitationMean = mean(getDataInRange(ByBroa.weatherData.Precipitation,selectedTimePeriod),'omitmissing');
    row(1).precipitationStd  = std(getDataInRange(ByBroa.weatherData.Precipitation,selectedTimePeriod),'omitmissing');
    row(1).airTempMean       = mean(getDataInRange(ByBroa.weatherData.AirTemp,selectedTimePeriod),'omitmissing');
    row(1).airPressMean      = mean(getDataInRange(ByBroa.weatherData.AirPress,selectedTimePeriod),'omitmissing');

    row(1).queryFreqs = queryFreqs;
end

function appendResults(resFile, lockRoot, localResults, logFile, workerId)
    if isempty(localResults)
        return
    end

    lockName = "results";
    if ~acquireLock(lockRoot, lockName, 0.25, 600)
        logMessage(logFile, workerId, "LOCK_FAIL", "Could not lock results");
        return
    end

    cleanup = onCleanup(@() safeReleaseLock(lockRoot, lockName));

    try
        s = load(resFile,'cohResults','queryFreqs');
        cohResults = s.cohResults;
        queryFreqs = s.queryFreqs;
    catch ME
        logMessage(logFile, workerId, "RESFILE_LOAD_FAIL", string(ME.identifier));
        return
    end

    cohResults = [cohResults, localResults]; %#ok<AGROW>

    try
        atomicSaveMat(resFile, struct('cohResults',cohResults,'queryFreqs',queryFreqs))
    catch ME
        logMessage(logFile, workerId, "RESFILE_SAVE_FAIL", string(ME.identifier));
    end
end

function plotResults(selectedTimePeriod, tag, figRoot, ByBroaOverview, cableField)
    ensureDir(figRoot)

    ByBroaOverview.plotTimeHistory('acceleration', selectedTimePeriod);
    saveas(gcf, fullfile(figRoot, "Seg_" + tag + "_TimeHistory_acc.png"))

    ByBroaOverview.plotEpsdHistory(0.5, selectedTimePeriod);
    saveas(gcf, fullfile(figRoot, "Seg_" + tag + "_EpsdHistory_30s_acc.png"))

    ByBroaOverview.plotHeaveCoherence(cableField, selectedTimePeriod, fLow=0.5, fHigh=10, Npeaks=5);
    saveas(gcf, fullfile(figRoot, "Seg_" + tag + "_HeaveCoherence_" + string(cableField) + ".png"))

    ByBroaOverview.plotCablePhaseSpace(selectedTimePeriod);
    saveas(gcf, fullfile(figRoot, "Seg_" + tag + "_CablePhaseSpace.png"))

    close all
end

function cohStruct = initStruct()
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
        'airPressMean',{}, ...
        'queryFreqs',{});
end

function tf = hasData(timetableObj, t0, t1)
    tf = any(timetableObj.Time >= t0 & timetableObj.Time <= t1);
end

function dataInRange = getDataInRange(structure, timeSegment)
    idx = timeSegment(1) <= structure.Time & structure.Time <= timeSegment(2);
    dataInRange = structure.Data(idx);
end

function ensureDir(pathStr)
    if ~exist(pathStr,'dir')
        mkdir(pathStr)
    end
end

function workerId = getWorkerId()
    workerId = string(getenv("WORKER_ID"));
    if strlength(workerId) == 0
        workerId = "w" + string(feature("getpid"));
    end
end

function logMessage(logFile, workerId, tag, msg)
    ts = string(datetime("now","Format","yyyy-MM-dd HH:mm:ss.SSS"));
    line = ts + " [" + workerId + "] " + tag + " " + msg;
    fid = fopen(logFile,'a');
    if fid < 0
        return
    end
    fprintf(fid,'%s\n',line);
    fclose(fid);
end

function ok = acquireLock(lockRoot, name, pollSeconds, timeoutSeconds)
    ok = false;
    lockDir = fullfile(lockRoot, name + ".lock");
    t0 = tic;

    while toc(t0) < timeoutSeconds
        [success,~,~] = mkdir(lockDir);
        if success
            ok = true;
            return
        end
        pause(pollSeconds)
    end
end

function safeReleaseLock(lockRoot, name)
    try
        releaseLock(lockRoot, name);
    catch
    end
end

function releaseLock(lockRoot, name)
    lockDir = fullfile(lockRoot, name + ".lock");
    if ~exist(lockDir,'dir')
        return
    end

    for k = 1:10
        try
            rmdir(lockDir,'s');
            return
        catch
            pause(0.1)
        end
    end
end

function atomicSaveMat(filePath, varsStruct)
    tmpPath = filePath + ".tmp_" + string(feature("getpid")) + "_" + string(randi(1e9));
    save(tmpPath, '-struct', 'varsStruct', '-v7.3')
    movefile(tmpPath, filePath, 'f')
end

function seed = getWorkerSeed(workerId)
    bytes = uint8(char(workerId));
    idx   = uint32(1:numel(bytes));
    seed  = mod(sum(uint32(bytes) .* idx), 2^32-1);
end

function [result, allStats] = optimizeCableRwivCriteria(allStats, cableConfig, options)
% optimizeCableRwivCriteria Optimizes cable RWIV criteria with mode-wise thresholds and layout constraints.
%
% Description:
%   Optimizes mode-dependent center frequency, tolerance, peak intensity and damping
%   while also optimizing directional layout rules for RWIV detection. The objective
%   maximizes selected samples while penalizing dry (2h lookback) samples, with an
%   optional hard dry enforcement mode.
%
% Inputs:
%   allStats    - Table containing psdPeaks, duration and RainIntensity fields
%   cableConfig - Struct with cable setup. Missing fields are auto-filled.
%   options     - Optimization options.
%
% Outputs:
%   result      - Struct with optimization outputs and diagnostics
%   allStats    - Input table with optional saved optimized flag

arguments
    allStats table
    cableConfig struct = struct()
    options struct = struct()
end

options = iNormalizeOptions(options);
rng(options.seed);
if options.runPrallel
    iEnsureParallelPool(options.numWorkers);
end
cableConfig = iNormalizeCableConfig(cableConfig);
problemData = iBuildProblemData(allStats, cableConfig, options);

if options.runSweep
    runResults = iRunSweep(problemData, options);
else
    runResults = iRunSingle(problemData, options, options.optimizer);
end

bestIdx = iSelectBestRun(runResults);
bestRun = runResults(bestIdx);

[~, bestEval] = iObjective(bestRun.solution, problemData, options);
bestFlag = iEvaluateCriteria(problemData, bestEval.parameters);

if options.saveFlagName ~= ""
    allStats.(char(options.saveFlagName)) = bestFlag;
end

result = struct();
result.cableConfig = cableConfig;
result.problemData = rmfield(problemData, {'allStats', 'psdPeaks', 'rainMean', 'startTime'});
result.runResults = runResults;
result.bestRun = bestRun;
result.bestParameters = bestEval.parameters;
result.bestParametersTable = iBuildModeParameterTable(bestEval.parameters, cableConfig.modeFreqs);
result.bestLayout = bestEval.parameters.layout;
result.bestFlag = bestFlag;
result.summary = iBuildSummary(bestEval, bestRun);
end

function cableConfig = iNormalizeCableConfig(cableConfig)
if ~isfield(cableConfig, 'name')
    cableConfig.name = "C1";
end

if ~isfield(cableConfig, 'modeFreqs')
    cableConfig.modeFreqs = [1.03, 2.08, 3.10, 4.15, 5.13, 6.16, 7.32, 8.30, 9.30];
end
cableConfig.modeFreqs = cableConfig.modeFreqs(:)';
numModes = numel(cableConfig.modeFreqs);

if ~isfield(cableConfig, 'sensorsByDirection')
    cableConfig.sensorsByDirection = struct( ...
        'X', ["Conc_X", "Steel_X"], ...
        'Y', ["Conc_Y", "Steel_Y"], ...
        'Z', ["Conc_Z", "Steel_Z"]);
end

if ~isfield(cableConfig, 'directionCandidates')
    cableConfig.directionCandidates = string(fieldnames(cableConfig.sensorsByDirection))';
end
cableConfig.directionCandidates = cableConfig.directionCandidates(:)';
numDirections = numel(cableConfig.directionCandidates);

if ~isfield(cableConfig, 'allowDirectionMaskOptimization')
    cableConfig.allowDirectionMaskOptimization = true;
end

if ~isfield(cableConfig, 'fixedDirectionMask')
    cableConfig.fixedDirectionMask = true(1, numDirections);
end

if ~isfield(cableConfig, 'modeFreqBounds')
    range = 0.25;
    cableConfig.modeFreqBounds = [cableConfig.modeFreqs(:) - range, cableConfig.modeFreqs(:) + range];
end

if ~isfield(cableConfig, 'freqToleranceBounds')
    cableConfig.freqToleranceBounds = repmat([0.05, 0.35], numModes, 1);
end

if ~isfield(cableConfig, 'peakIntensityBounds')
    cableConfig.peakIntensityBounds = repmat([-20, 20], numModes, 1);
end

if ~isfield(cableConfig, 'dampingBounds')
    cableConfig.dampingBounds = repmat([0.001, 0.08], numModes, 1);
end

maxPeaksPerDirection = 0;
for direction = cableConfig.directionCandidates
    sensors = string(cableConfig.sensorsByDirection.(char(direction)));
    maxPeaksPerDirection = max(maxPeaksPerDirection, numel(sensors) * numModes);
end

if ~isfield(cableConfig, 'minPeaksPerDirectionBounds')
    cableConfig.minPeaksPerDirectionBounds = [1, maxPeaksPerDirection];
end

if ~isfield(cableConfig, 'minDirectionsRequiredBounds')
    cableConfig.minDirectionsRequiredBounds = [1, numDirections];
end
end

function problemData = iBuildProblemData(allStats, cableConfig, options)
numModes = numel(cableConfig.modeFreqs);
numDirections = numel(cableConfig.directionCandidates);

lb = [cableConfig.modeFreqBounds(:,1); ...
      cableConfig.freqToleranceBounds(:,1); ...
      cableConfig.peakIntensityBounds(:,1); ...
      cableConfig.dampingBounds(:,1); ...
      zeros(numDirections, 1); ...
      cableConfig.minDirectionsRequiredBounds(1); ...
      cableConfig.minPeaksPerDirectionBounds(1)];

ub = [cableConfig.modeFreqBounds(:,2); ...
      cableConfig.freqToleranceBounds(:,2); ...
      cableConfig.peakIntensityBounds(:,2); ...
      cableConfig.dampingBounds(:,2); ...
      ones(numDirections, 1); ...
      cableConfig.minDirectionsRequiredBounds(2); ...
      cableConfig.minPeaksPerDirectionBounds(2)];

intcon = (4*numModes + 1):(4*numModes + numDirections + 2);

problemData = struct();
problemData.allStats = allStats;
problemData.psdPeaks = allStats.psdPeaks;
problemData.rainMean = [allStats.RainIntensity.mean]';
problemData.startTime = allStats.duration(:,1);
problemData.lookbackMaxRain = iComputeLookbackMaxRain(problemData.startTime, problemData.rainMean, options.lookbackDuration);
problemData.cableConfig = cableConfig;
problemData.numModes = numModes;
problemData.numDirections = numDirections;
problemData.numVars = numel(lb);
problemData.lb = lb;
problemData.ub = ub;
problemData.intcon = intcon;
problemData.lookbackDuration = options.lookbackDuration;
problemData.dryRainThreshold = options.dryRainThreshold;
end

function runResults = iRunSweep(problemData, options)
optimizerList = unique(options.optimizerList, 'stable');
runResults = repmat(struct(), numel(optimizerList), 1);

for idx = 1:numel(optimizerList)
    runResults(idx) = iRunSingle(problemData, options, optimizerList(idx));
end
end

function runResult = iRunSingle(problemData, options, optimizerName)
tic;
solverName = lower(char(optimizerName));
useParallel = options.runPrallel;

objFun = @(x) iObjectiveScalar(x, problemData, options);
x0 = iBuildInitialGuess(problemData, options);

runResult = struct('optimizer', string(optimizerName), 'success', false, 'message', "", ...
    'solution', x0, 'objective', inf, 'exitFlag', NaN, 'output', struct(), 'runtimeSec', NaN);

try
    switch solverName
        case 'surrogateopt'
            if exist('surrogateopt', 'file') ~= 2
                error('surrogateopt not available.');
            end
            solverOptions = optimoptions('surrogateopt', ...
                'Display', char(options.display), ...
                'MaxFunctionEvaluations', options.maxFunctionEvaluations, ...
                'MaxTime', seconds(options.maxTime), ...
                'UseParallel', useParallel);
            [x, fval, exitFlag, output] = surrogateopt(objFun, problemData.lb, problemData.ub, problemData.intcon, solverOptions);

        case 'ga'
            if exist('ga', 'file') ~= 2
                error('ga not available.');
            end
            solverOptions = optimoptions('ga', ...
                'Display', char(options.display), ...
                'MaxGenerations', max(40, ceil(options.maxFunctionEvaluations/60)), ...
                'MaxTime', seconds(options.maxTime), ...
                'PopulationSize', 120, ...
                'UseParallel', useParallel);
            [x, fval, exitFlag, output] = ga(objFun, problemData.numVars, [], [], [], [], ...
                problemData.lb, problemData.ub, [], problemData.intcon, solverOptions);

        case 'patternsearch'
            if exist('patternsearch', 'file') ~= 2
                error('patternsearch not available.');
            end
            solverOptions = optimoptions('patternsearch', ...
                'Display', char(options.display), ...
                'MaxFunctionEvaluations', options.maxFunctionEvaluations, ...
                'MaxTime', seconds(options.maxTime), ...
                'UseCompletePoll', true, ...
                'UseParallel', useParallel);
            [x, fval, exitFlag, output] = patternsearch(objFun, x0, [], [], [], [], ...
                problemData.lb, problemData.ub, [], solverOptions);

        case 'fmincon'
            if exist('fmincon', 'file') ~= 2
                error('fmincon not available.');
            end
            solverOptions = optimoptions('fmincon', ...
                'Display', char(options.display), ...
                'MaxFunctionEvaluations', options.maxFunctionEvaluations, ...
                'MaxIterations', max(300, ceil(options.maxFunctionEvaluations/5)), ...
                'Algorithm', 'sqp', ...
                'UseParallel', useParallel);
            [x, fval, exitFlag, output] = fmincon(objFun, x0, [], [], [], [], ...
                problemData.lb, problemData.ub, [], solverOptions);

        case 'particleswarm'
            if exist('particleswarm', 'file') ~= 2
                error('particleswarm not available.');
            end
            solverOptions = optimoptions('particleswarm', ...
                'Display', char(options.display), ...
                'MaxIterations', max(80, ceil(options.maxFunctionEvaluations/50)), ...
                'SwarmSize', 120, ...
                'UseParallel', useParallel);
            [x, fval, exitFlag, output] = particleswarm(objFun, problemData.numVars, problemData.lb, problemData.ub, solverOptions);

        case 'simulannealbnd'
            if exist('simulannealbnd', 'file') ~= 2
                error('simulannealbnd not available.');
            end
            solverOptions = optimoptions('simulannealbnd', ...
                'Display', char(options.display), ...
                'MaxFunctionEvaluations', options.maxFunctionEvaluations, ...
                'MaxIterations', max(200, ceil(options.maxFunctionEvaluations/8)), ...
                'UseParallel', useParallel);
            [x, fval, exitFlag, output] = simulannealbnd(objFun, x0, problemData.lb, problemData.ub, solverOptions);

        case 'multistart-fmincon'
            if exist('fmincon', 'file') ~= 2 || exist('MultiStart', 'class') ~= 8
                error('MultiStart/fmincon not available.');
            end
            baseOptions = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp', ...
                'MaxFunctionEvaluations', max(300, ceil(options.maxFunctionEvaluations/5)), ...
                'MaxIterations', max(150, ceil(options.maxFunctionEvaluations/8)), ...
                'UseParallel', useParallel);
            problem = createOptimProblem('fmincon', 'objective', objFun, 'x0', x0, ...
                'lb', problemData.lb, 'ub', problemData.ub, 'options', baseOptions);
            ms = MultiStart('Display', char(options.display), 'UseParallel', useParallel);
            nStarts = max(10, min(60, ceil(options.maxFunctionEvaluations/80)));
            [x, fval, exitFlag, output] = run(ms, problem, nStarts);

        case 'globalsearch-fmincon'
            if exist('fmincon', 'file') ~= 2 || exist('GlobalSearch', 'class') ~= 8
                error('GlobalSearch/fmincon not available.');
            end
            baseOptions = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp', ...
                'MaxFunctionEvaluations', max(300, ceil(options.maxFunctionEvaluations/5)), ...
                'MaxIterations', max(150, ceil(options.maxFunctionEvaluations/8)), ...
                'UseParallel', useParallel);
            problem = createOptimProblem('fmincon', 'objective', objFun, 'x0', x0, ...
                'lb', problemData.lb, 'ub', problemData.ub, 'options', baseOptions);
            gs = GlobalSearch('Display', char(options.display));
            if isprop(gs, 'UseParallel')
                gs.UseParallel = useParallel;
            end
            [x, fval, exitFlag, output] = run(gs, problem);

        otherwise
            error('Unknown optimizer: %s', optimizerName);
    end

    runResult.success = true;
    runResult.solution = x;
    runResult.objective = fval;
    runResult.exitFlag = exitFlag;
    runResult.output = output;
    runResult.message = "Completed";
catch executionError
    runResult.success = false;
    runResult.message = string(executionError.message);
end

runResult.runtimeSec = toc;
if options.verbose
    fprintf('[optimizeCableRwivCriteria] %s finished: success=%d, objective=%.3f, runtime=%.1fs\n', ...
        char(optimizerName), runResult.success, runResult.objective, runResult.runtimeSec);
end
end

function value = iObjectiveScalar(x, problemData, options)
[value, ~] = iObjective(x, problemData, options);
end

function [objectiveValue, evalInfo] = iObjective(x, problemData, options)
parameters = iDecodeParameters(x, problemData);
flag = iEvaluateCriteria(problemData, parameters);
nFlagged = sum(flag);

[nDry, dryFraction] = iCountDryCases(flag, problemData.lookbackMaxRain, problemData.dryRainThreshold);
nWet = nFlagged - nDry;

objectiveValue = -nWet + options.lambdaDry * nDry + options.lambdaDrySq * (nDry^2);
if options.enforceZeroDry && nDry > 0
    objectiveValue = objectiveValue + 1e8 + 1e6 * nDry;
end
if options.minWetSamples > 0 && nWet < options.minWetSamples
    objectiveValue = objectiveValue + 1e8 + 1e6 * (options.minWetSamples - nWet);
end

evalInfo = struct();
evalInfo.flag = flag;
evalInfo.nFlagged = nFlagged;
evalInfo.nDry = nDry;
evalInfo.nWet = nWet;
evalInfo.dryFraction = dryFraction;
evalInfo.objective = objectiveValue;
evalInfo.parameters = parameters;
end

function parameters = iDecodeParameters(x, problemData)
numModes = problemData.numModes;
numDirections = problemData.numDirections;
cursor = 0;

centerFreq = x(cursor + (1:numModes)); cursor = cursor + numModes;
freqTolerance = x(cursor + (1:numModes)); cursor = cursor + numModes;
minLogIntensity = x(cursor + (1:numModes)); cursor = cursor + numModes;
maxDamping = x(cursor + (1:numModes)); cursor = cursor + numModes;

rawDirectionMask = x(cursor + (1:numDirections)); cursor = cursor + numDirections;
minDirectionsRequired = x(cursor + 1); cursor = cursor + 1;
minPeaksPerDirection = x(cursor + 1);

if problemData.cableConfig.allowDirectionMaskOptimization
    directionMask = round(rawDirectionMask) > 0;
else
    directionMask = logical(problemData.cableConfig.fixedDirectionMask(:)');
end

if ~any(directionMask)
    directionMask(1) = true;
end

activeDirections = sum(directionMask);
minDirectionsRequired = max(1, min(activeDirections, round(minDirectionsRequired)));
minPeaksPerDirection = max(1, round(minPeaksPerDirection));

parameters = struct();
parameters.centerFreq = centerFreq(:)';
parameters.freqTolerance = freqTolerance(:)';
parameters.minLogIntensity = minLogIntensity(:)';
parameters.maxDamping = maxDamping(:)';
parameters.layout = struct();
parameters.layout.directionMask = directionMask(:)';
parameters.layout.minDirectionsRequired = minDirectionsRequired;
parameters.layout.minPeaksPerDirection = minPeaksPerDirection;
end

function flag = iEvaluateCriteria(problemData, parameters)
numSegments = height(problemData.allStats);
flag = false(numSegments, 1);

directions = problemData.cableConfig.directionCandidates;
activeMask = parameters.layout.directionMask;
minDirectionsRequired = parameters.layout.minDirectionsRequired;
minPeaksPerDirection = parameters.layout.minPeaksPerDirection;

for segmentIdx = 1:numSegments
    passedDirections = 0;

    for directionIdx = 1:numel(directions)
        if ~activeMask(directionIdx)
            continue;
        end

        sensorList = string(problemData.cableConfig.sensorsByDirection.(char(directions(directionIdx))));
        peakCount = 0;

        for sensor = sensorList
            sensorName = char(sensor);
            if ~isfield(problemData.psdPeaks(segmentIdx), sensorName)
                continue;
            end

            sensorPeaks = problemData.psdPeaks(segmentIdx).(sensorName);
            if ~isfield(sensorPeaks, 'locations') || ~isfield(sensorPeaks, 'logIntensity') || ~isfield(sensorPeaks, 'dampingRatios')
                continue;
            end

            locations = sensorPeaks.locations(:);
            logIntensity = sensorPeaks.logIntensity(:);
            damping = sensorPeaks.dampingRatios(:);
            comparableLength = min([numel(locations), numel(logIntensity), numel(damping)]);
            if comparableLength < 1
                continue;
            end

            locations = locations(1:comparableLength);
            logIntensity = logIntensity(1:comparableLength);
            damping = damping(1:comparableLength);

            validBase = isfinite(locations) & isfinite(logIntensity) & isfinite(damping) & damping > 0;
            if ~any(validBase)
                continue;
            end

            for modeIdx = 1:problemData.numModes
                modeMask = validBase & ...
                    abs(locations - parameters.centerFreq(modeIdx)) <= parameters.freqTolerance(modeIdx) & ...
                    logIntensity >= parameters.minLogIntensity(modeIdx) & ...
                    damping <= parameters.maxDamping(modeIdx);

                if any(modeMask)
                    peakCount = peakCount + 1;
                end
            end
        end

        if peakCount >= minPeaksPerDirection
            passedDirections = passedDirections + 1;
        end
    end

    flag(segmentIdx) = passedDirections >= minDirectionsRequired;
end
end

function [nDry, dryFraction] = iCountDryCases(flag, lookbackMaxRain, dryThreshold)
flagIdx = find(flag);
numFlagged = numel(flagIdx);

if numFlagged == 0
    nDry = 0;
    dryFraction = 0;
    return;
end

nDry = 0;
nDry = sum(~isfinite(lookbackMaxRain(flagIdx)) | lookbackMaxRain(flagIdx) <= dryThreshold);

dryFraction = nDry / numFlagged;
end

function lookbackMaxRain = iComputeLookbackMaxRain(startTime, rainMean, lookbackDuration)
numRows = numel(startTime);
lookbackMaxRain = NaN(numRows, 1);

if numRows == 0
    return;
end

timeSec = seconds(startTime - startTime(1));
windowSec = seconds(lookbackDuration);

windowStartIdx = 1;
deque = zeros(numRows, 1);
head = 1;
tail = 0;

for endIdx = 1:numRows
    currentTime = timeSec(endIdx);
    lowerTime = currentTime - windowSec;

    while windowStartIdx <= endIdx && timeSec(windowStartIdx) < lowerTime
        if head <= tail && deque(head) == windowStartIdx
            head = head + 1;
        end
        windowStartIdx = windowStartIdx + 1;
    end

    currentRain = rainMean(endIdx);
    if isfinite(currentRain)
        while head <= tail && rainMean(deque(tail)) <= currentRain
            tail = tail - 1;
        end
        tail = tail + 1;
        deque(tail) = endIdx;
    end

    if head <= tail
        lookbackMaxRain(endIdx) = rainMean(deque(head));
    else
        lookbackMaxRain(endIdx) = NaN;
    end
end
end

function tableOut = iBuildModeParameterTable(parameters, nominalFreqs)
modeIndex = (1:numel(nominalFreqs))';
tableOut = table(modeIndex, nominalFreqs(:), parameters.centerFreq(:), parameters.freqTolerance(:), ...
    parameters.minLogIntensity(:), parameters.maxDamping(:), ...
    'VariableNames', {'modeIndex', 'nominalFreq', 'centerFreq', 'freqTolerance', 'minLogIntensity', 'maxDamping'});
end

function summary = iBuildSummary(evalInfo, runInfo)
summary = struct();
summary.objective = evalInfo.objective;
summary.nFlagged = evalInfo.nFlagged;
summary.nDry = evalInfo.nDry;
summary.nWet = evalInfo.nWet;
summary.dryFraction = evalInfo.dryFraction;
summary.optimizer = runInfo.optimizer;
summary.success = runInfo.success;
summary.exitFlag = runInfo.exitFlag;
summary.runtimeSec = runInfo.runtimeSec;
summary.message = runInfo.message;
end

function bestIdx = iSelectBestRun(runResults)
validMask = [runResults.success];
if ~any(validMask)
    bestIdx = 1;
    return;
end

objectives = inf(numel(runResults), 1);
for idx = 1:numel(runResults)
    objectives(idx) = runResults(idx).objective;
end

objectives(~validMask) = inf;
[~, bestIdx] = min(objectives);
end

function options = iNormalizeOptions(options)
if ~isfield(options, 'optimizer'), options.optimizer = "surrogateopt"; end
if ~isfield(options, 'runSweep'), options.runSweep = false; end
if ~isfield(options, 'optimizerList'), options.optimizerList = ["surrogateopt", "ga", "patternsearch", "multistart-fmincon"]; end
if ~isfield(options, 'maxFunctionEvaluations'), options.maxFunctionEvaluations = 3000; end
if ~isfield(options, 'maxTime'), options.maxTime = hours(2); end
if ~isfield(options, 'lookbackDuration'), options.lookbackDuration = hours(2); end
if ~isfield(options, 'dryRainThreshold'), options.dryRainThreshold = 0.01; end
if ~isfield(options, 'lambdaDry'), options.lambdaDry = 50; end
if ~isfield(options, 'lambdaDrySq'), options.lambdaDrySq = 200; end
if ~isfield(options, 'enforceZeroDry'), options.enforceZeroDry = false; end
if ~isfield(options, 'saveFlagName'), options.saveFlagName = ""; end
if ~isfield(options, 'display'), options.display = "off"; end
if ~isfield(options, 'seed'), options.seed = 112; end
if ~isfield(options, 'verbose'), options.verbose = true; end
if ~isfield(options, 'runPrallel'), options.runPrallel = false; end
if ~isfield(options, 'numWorkers'), options.numWorkers = []; end
if ~isfield(options, 'useInitialGuess'), options.useInitialGuess = true; end
if ~isfield(options, 'initialFlagField'), options.initialFlagField = "flag_PSDTotal"; end
if ~isfield(options, 'initialGuessFreqTolerance'), options.initialGuessFreqTolerance = 0.15; end
if ~isfield(options, 'initialGuessIntensityQuantile'), options.initialGuessIntensityQuantile = 0.2; end
if ~isfield(options, 'initialGuessDampingQuantile'), options.initialGuessDampingQuantile = 0.8; end
if ~isfield(options, 'initialGuessMinDirectionsRequired'), options.initialGuessMinDirectionsRequired = 1; end
if ~isfield(options, 'initialGuessMinPeaksPerDirection'), options.initialGuessMinPeaksPerDirection = 2; end
if ~isfield(options, 'minWetSamples'), options.minWetSamples = 0; end

options.optimizer = string(options.optimizer);
options.optimizerList = string(options.optimizerList);
options.maxFunctionEvaluations = double(options.maxFunctionEvaluations);
if ~isduration(options.maxTime), options.maxTime = hours(double(options.maxTime)); end
if ~isduration(options.lookbackDuration), options.lookbackDuration = hours(double(options.lookbackDuration)); end
options.dryRainThreshold = double(options.dryRainThreshold);
options.lambdaDry = double(options.lambdaDry);
options.lambdaDrySq = double(options.lambdaDrySq);
options.enforceZeroDry = logical(options.enforceZeroDry);
options.saveFlagName = string(options.saveFlagName);
options.display = string(options.display);
if strcmpi(options.display, "on"), options.display = "iter"; end
options.seed = double(options.seed);
options.verbose = logical(options.verbose);
options.runPrallel = logical(options.runPrallel);
options.useInitialGuess = logical(options.useInitialGuess);
options.initialFlagField = string(options.initialFlagField);
options.initialGuessFreqTolerance = double(options.initialGuessFreqTolerance);
options.initialGuessIntensityQuantile = double(options.initialGuessIntensityQuantile);
options.initialGuessDampingQuantile = double(options.initialGuessDampingQuantile);
options.initialGuessMinDirectionsRequired = double(options.initialGuessMinDirectionsRequired);
options.initialGuessMinPeaksPerDirection = double(options.initialGuessMinPeaksPerDirection);
options.minWetSamples = double(options.minWetSamples);
if isempty(options.numWorkers)
    options.numWorkers = [];
else
    options.numWorkers = double(options.numWorkers);
end
end

function x0 = iBuildInitialGuess(problemData, options)
numModes = problemData.numModes;
numDirections = problemData.numDirections;

centerFreq = problemData.cableConfig.modeFreqs(:)';
freqTolerance = repmat(options.initialGuessFreqTolerance, 1, numModes);
minLogIntensity = problemData.cableConfig.peakIntensityBounds(:,1)' + 0.1 * ...
    (problemData.cableConfig.peakIntensityBounds(:,2)' - problemData.cableConfig.peakIntensityBounds(:,1)');
maxDamping = min(0.03, problemData.cableConfig.dampingBounds(:,2)');

directionMask = ones(1, numDirections);
minDirectionsRequired = max(1, round(options.initialGuessMinDirectionsRequired));
minPeaksPerDirection = max(1, round(options.initialGuessMinPeaksPerDirection));

if options.useInitialGuess && ismember(char(options.initialFlagField), problemData.allStats.Properties.VariableNames)
    initialFlag = iToLogicalColumn(problemData.allStats.(char(options.initialFlagField)));
    if any(initialFlag)
        flaggedIdx = find(initialFlag);

        for modeIdx = 1:numModes
            nominalFreq = centerFreq(modeIdx);
            modeLogIntensity = [];
            modeDamping = [];

            for segmentIdx = flaggedIdx'
                for direction = problemData.cableConfig.directionCandidates
                    sensors = string(problemData.cableConfig.sensorsByDirection.(char(direction)));
                    for sensor = sensors
                        sensorName = char(sensor);
                        if ~isfield(problemData.psdPeaks(segmentIdx), sensorName)
                            continue;
                        end

                        peakStruct = problemData.psdPeaks(segmentIdx).(sensorName);
                        if ~isfield(peakStruct, 'locations') || ~isfield(peakStruct, 'logIntensity') || ~isfield(peakStruct, 'dampingRatios')
                            continue;
                        end

                        locations = peakStruct.locations(:);
                        logIntensity = peakStruct.logIntensity(:);
                        damping = peakStruct.dampingRatios(:);
                        comparableLength = min([numel(locations), numel(logIntensity), numel(damping)]);
                        if comparableLength < 1
                            continue;
                        end

                        locations = locations(1:comparableLength);
                        logIntensity = logIntensity(1:comparableLength);
                        damping = damping(1:comparableLength);
                        matchMask = isfinite(locations) & isfinite(logIntensity) & isfinite(damping) & ...
                            abs(locations - nominalFreq) <= freqTolerance(modeIdx);

                        if any(matchMask)
                            modeLogIntensity = [modeLogIntensity; logIntensity(matchMask)]; %#ok<AGROW>
                            modeDamping = [modeDamping; damping(matchMask)]; %#ok<AGROW>
                        end
                    end
                end
            end

            if ~isempty(modeLogIntensity)
                minLogIntensity(modeIdx) = quantile(modeLogIntensity, options.initialGuessIntensityQuantile);
            end
            if ~isempty(modeDamping)
                maxDamping(modeIdx) = quantile(modeDamping, options.initialGuessDampingQuantile);
            end
        end
    end
end

centerFreq = iClipVector(centerFreq, problemData.cableConfig.modeFreqBounds(:,1)', problemData.cableConfig.modeFreqBounds(:,2)');
freqTolerance = iClipVector(freqTolerance, problemData.cableConfig.freqToleranceBounds(:,1)', problemData.cableConfig.freqToleranceBounds(:,2)');
minLogIntensity = iClipVector(minLogIntensity, problemData.cableConfig.peakIntensityBounds(:,1)', problemData.cableConfig.peakIntensityBounds(:,2)');
maxDamping = iClipVector(maxDamping, problemData.cableConfig.dampingBounds(:,1)', problemData.cableConfig.dampingBounds(:,2)');

activeDirections = sum(directionMask > 0);
minDirectionsRequired = min(max(1, minDirectionsRequired), activeDirections);
minPeaksPerDirection = min(max(1, minPeaksPerDirection), round(problemData.cableConfig.minPeaksPerDirectionBounds(2)));

x0 = [centerFreq(:); freqTolerance(:); minLogIntensity(:); maxDamping(:); ...
      directionMask(:); minDirectionsRequired; minPeaksPerDirection];
x0 = min(max(x0, problemData.lb), problemData.ub);
end

function out = iClipVector(values, lowerBound, upperBound)
out = min(max(values, lowerBound), upperBound);
end

function logicalColumn = iToLogicalColumn(flagColumn)
if iscell(flagColumn)
    logicalColumn = cellfun(@(value) logical(value(1)), flagColumn);
else
    logicalColumn = logical(flagColumn);
end
logicalColumn = logicalColumn(:);
end

function iEnsureParallelPool(numWorkers)
pool = gcp('nocreate');
if isempty(numWorkers)
    if isempty(pool)
        parpool('local');
    end
    return;
end

numWorkers = max(1, round(numWorkers));
if isempty(pool)
    parpool('local', numWorkers);
elseif pool.NumWorkers ~= numWorkers
    delete(pool);
    parpool('local', numWorkers);
end
end

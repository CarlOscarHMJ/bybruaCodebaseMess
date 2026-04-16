function [overnightResult, allStats] = runOvernightCableRwivOptimization(allStats, cableConfig, options)
% runOvernightCableRwivOptimization Runs a multi-setup overnight sweep for cable RWIV criteria optimization.
%
% Description:
%   Executes multiple optimization setups across optimizers and seeds,
%   stores all results and setup metadata, ranks runs by objective value,
%   and optionally writes the best flag to allStats.

arguments
    allStats table
    cableConfig struct = struct()
    options struct = struct()
end

options = iNormalizeOvernightOptions(options);
options.optimizerList = iFilterAvailableOptimizers(options.optimizerList, options.verbose);

if isempty(options.optimizerList)
    error('No available optimizers found for overnight run.');
end

setups = iBuildSetupGrid(options);
numSetups = numel(setups);
runResults = repmat(struct(), numSetups, 1);

if options.verbose
    fprintf('[runOvernightCableRwivOptimization] Starting %d setups\n', numSetups);
end

if options.parallelizeSetups
    iEnsureSetupPool(options.numSetupWorkers);
    if options.showProgressPlot && options.verbose
        fprintf('[runOvernightCableRwivOptimization] Progress plot disabled in setup-parallel mode.\n');
    end
    if options.runPrallel && options.verbose
        fprintf('[runOvernightCableRwivOptimization] Nested parallelism disabled; running each setup serially inside workers.\n');
    end

    parfor setupIdx = 1:numSetups
        runResults(setupIdx) = iRunSingleSetup(setups(setupIdx), allStats, cableConfig, options, true);
    end

    if options.verbose
        fprintf('[runOvernightCableRwivOptimization] Parallel sweep completed (%d setups).\n', numSetups);
    end
else
    progressState = iInitializeProgressState(numSetups, options);

    for setupIdx = 1:numSetups
        runResults(setupIdx) = iRunSingleSetup(setups(setupIdx), allStats, cableConfig, options, false);

        if options.showProgressPlot && (mod(setupIdx, options.progressUpdateEvery) == 0 || setupIdx == numSetups)
            progressState = iUpdateProgressState(progressState, setupIdx, runResults(setupIdx));
        end

        if options.verbose
            setup = runResults(setupIdx).setup;
            fprintf('[runOvernightCableRwivOptimization] %d/%d done (%s, seed=%d, eval=%d, lambda=%.2f, lambdaSq=%.2f, minWet=%d), objective=%.3f\n', ...
                setupIdx, numSetups, char(setup.optimizer), setup.seed, setup.maxFunctionEvaluations, ...
                setup.lambdaDry, setup.lambdaDrySq, setup.minWetSamples, runResults(setupIdx).summary.objective);
        end
    end
end

rankingTable = iBuildRankingTable(runResults);
successfulRows = rankingTable(rankingTable.success, :);
if isempty(successfulRows)
    if options.requireSuccessfulRun
        uniqueMessages = unique(string({runResults.optimizerMessage}));
        error('No successful optimization runs. First messages: %s', strjoin(uniqueMessages(1:min(5, numel(uniqueMessages))), ' | '));
    end
    bestIdx = rankingTable.runIndex(1);
else
    bestIdx = successfulRows.runIndex(1);
end
bestResult = runResults(bestIdx);

if options.saveBestFlagName ~= ""
    allStats.(char(options.saveBestFlagName)) = bestResult.bestFlag;
end

overnightResult = struct();
overnightResult.setups = setups;
overnightResult.runResults = runResults;
overnightResult.rankingTable = rankingTable;
overnightResult.bestResult = bestResult;
overnightResult.bestSetup = bestResult.setup;
overnightResult.bestSummary = bestResult.summary;
overnightResult.bestParameters = bestResult.bestParameters;
overnightResult.bestParametersTable = bestResult.bestParametersTable;
overnightResult.bestLayout = bestResult.bestLayout;
overnightResult.bestFlag = bestResult.bestFlag;
end

function setups = iBuildSetupGrid(options)
optimizerList = options.optimizerList(:);
seedList = options.seedList(:);
evalList = options.maxFunctionEvaluationsList(:);
lambdaDryList = options.lambdaDryList(:);
lambdaDrySqList = options.lambdaDrySqList(:);
minWetSamplesList = options.minWetSamplesList(:);

numSetups = numel(optimizerList) * numel(seedList) * numel(evalList) * numel(lambdaDryList) * numel(lambdaDrySqList) * numel(minWetSamplesList);
setups = repmat(struct('optimizer', "", 'seed', 0, 'maxFunctionEvaluations', 0, 'maxTime', minutes(1), ...
    'lambdaDry', 0, 'lambdaDrySq', 0, 'minWetSamples', 0), numSetups, 1);

cursor = 0;
for optimizer = optimizerList'
    for seed = seedList'
        for maxEval = evalList'
            for lambdaDry = lambdaDryList'
                for lambdaDrySq = lambdaDrySqList'
                    for minWetSamples = minWetSamplesList'
                        cursor = cursor + 1;
                        setups(cursor).optimizer = optimizer;
                        setups(cursor).seed = seed;
                        setups(cursor).maxFunctionEvaluations = maxEval;
                        setups(cursor).maxTime = options.maxTimePerRun;
                        setups(cursor).lambdaDry = lambdaDry;
                        setups(cursor).lambdaDrySq = lambdaDrySq;
                        setups(cursor).minWetSamples = minWetSamples;
                    end
                end
            end
        end
    end
end
end

function rankingTable = iBuildRankingTable(runResults)
numRuns = numel(runResults);
runIndex = (1:numRuns)';
optimizer = strings(numRuns, 1);
seed = zeros(numRuns, 1);
maxFunctionEvaluations = zeros(numRuns, 1);
success = false(numRuns, 1);
objective = inf(numRuns, 1);
lambdaDry = zeros(numRuns, 1);
lambdaDrySq = zeros(numRuns, 1);
minWetSamples = zeros(numRuns, 1);
nFlagged = zeros(numRuns, 1);
nDry = zeros(numRuns, 1);
nWet = zeros(numRuns, 1);
dryFraction = zeros(numRuns, 1);
runtimeSec = zeros(numRuns, 1);

for idx = 1:numRuns
    optimizer(idx) = runResults(idx).setup.optimizer;
    seed(idx) = runResults(idx).setup.seed;
    maxFunctionEvaluations(idx) = runResults(idx).setup.maxFunctionEvaluations;
    lambdaDry(idx) = runResults(idx).setup.lambdaDry;
    lambdaDrySq(idx) = runResults(idx).setup.lambdaDrySq;
    minWetSamples(idx) = runResults(idx).setup.minWetSamples;
    success(idx) = runResults(idx).summary.success;
    objective(idx) = runResults(idx).summary.objective;
    nFlagged(idx) = runResults(idx).summary.nFlagged;
    nDry(idx) = runResults(idx).summary.nDry;
    nWet(idx) = runResults(idx).summary.nWet;
    dryFraction(idx) = runResults(idx).summary.dryFraction;
    runtimeSec(idx) = runResults(idx).summary.runtimeSec;
end

rankingTable = table(runIndex, optimizer, seed, maxFunctionEvaluations, lambdaDry, lambdaDrySq, minWetSamples, success, objective, nFlagged, nDry, nWet, dryFraction, runtimeSec);
rankingTable = sortrows(rankingTable, {'objective', 'nDry', 'runtimeSec'}, {'ascend', 'ascend', 'ascend'});
end

function options = iNormalizeOvernightOptions(options)
if ~isfield(options, 'optimizerList'), options.optimizerList = ["surrogateopt", "ga", "patternsearch", "multistart-fmincon", "fmincon"]; end
if ~isfield(options, 'seedList'), options.seedList = [112, 221, 337]; end
if ~isfield(options, 'maxFunctionEvaluationsList'), options.maxFunctionEvaluationsList = [1500, 3000]; end
if ~isfield(options, 'maxTimePerRun'), options.maxTimePerRun = minutes(40); end
if ~isfield(options, 'lookbackDuration'), options.lookbackDuration = hours(1); end
if ~isfield(options, 'dryRainThreshold'), options.dryRainThreshold = 0; end
if ~isfield(options, 'lambdaDryList'), options.lambdaDryList = [5, 10, 20]; end
if ~isfield(options, 'lambdaDrySqList'), options.lambdaDrySqList = [20, 50, 100]; end
if ~isfield(options, 'minWetSamplesList'), options.minWetSamplesList = [25, 50, 100]; end
if ~isfield(options, 'lambdaDry'), options.lambdaDry = options.lambdaDryList(1); end
if ~isfield(options, 'lambdaDrySq'), options.lambdaDrySq = options.lambdaDrySqList(1); end
if ~isfield(options, 'enforceZeroDry'), options.enforceZeroDry = false; end
if ~isfield(options, 'display'), options.display = "off"; end
if ~isfield(options, 'verbose'), options.verbose = true; end
if ~isfield(options, 'saveBestFlagName'), options.saveBestFlagName = ""; end
if ~isfield(options, 'runPrallel'), options.runPrallel = false; end
if ~isfield(options, 'numWorkers'), options.numWorkers = []; end
if ~isfield(options, 'useInitialGuess'), options.useInitialGuess = true; end
if ~isfield(options, 'initialFlagField'), options.initialFlagField = "flag_PSDTotal"; end
if ~isfield(options, 'initialGuessFreqTolerance'), options.initialGuessFreqTolerance = 0.15; end
if ~isfield(options, 'initialGuessIntensityQuantile'), options.initialGuessIntensityQuantile = 0.2; end
if ~isfield(options, 'initialGuessDampingQuantile'), options.initialGuessDampingQuantile = 0.8; end
if ~isfield(options, 'initialGuessMinDirectionsRequired'), options.initialGuessMinDirectionsRequired = 1; end
if ~isfield(options, 'initialGuessMinPeaksPerDirection'), options.initialGuessMinPeaksPerDirection = 2; end
if ~isfield(options, 'minWetSamples'), options.minWetSamples = options.minWetSamplesList(1); end
if ~isfield(options, 'requireSuccessfulRun'), options.requireSuccessfulRun = true; end
if ~isfield(options, 'showProgressPlot'), options.showProgressPlot = true; end
if ~isfield(options, 'progressUpdateEvery'), options.progressUpdateEvery = 1; end
if ~isfield(options, 'parallelizeSetups'), options.parallelizeSetups = false; end
if ~isfield(options, 'numSetupWorkers'), options.numSetupWorkers = []; end

options.optimizerList = string(options.optimizerList);
options.seedList = double(options.seedList);
options.maxFunctionEvaluationsList = double(options.maxFunctionEvaluationsList);
options.lambdaDryList = double(options.lambdaDryList);
options.lambdaDrySqList = double(options.lambdaDrySqList);
options.minWetSamplesList = double(options.minWetSamplesList);
if ~isduration(options.maxTimePerRun), options.maxTimePerRun = minutes(double(options.maxTimePerRun)); end
if ~isduration(options.lookbackDuration), options.lookbackDuration = hours(double(options.lookbackDuration)); end
options.dryRainThreshold = double(options.dryRainThreshold);
options.lambdaDry = double(options.lambdaDry);
options.lambdaDrySq = double(options.lambdaDrySq);
options.enforceZeroDry = logical(options.enforceZeroDry);
options.display = string(options.display);
if strcmpi(options.display, "on"), options.display = "iter"; end
options.verbose = logical(options.verbose);
options.saveBestFlagName = string(options.saveBestFlagName);
options.runPrallel = logical(options.runPrallel);
options.useInitialGuess = logical(options.useInitialGuess);
options.initialFlagField = string(options.initialFlagField);
options.initialGuessFreqTolerance = double(options.initialGuessFreqTolerance);
options.initialGuessIntensityQuantile = double(options.initialGuessIntensityQuantile);
options.initialGuessDampingQuantile = double(options.initialGuessDampingQuantile);
options.initialGuessMinDirectionsRequired = double(options.initialGuessMinDirectionsRequired);
options.initialGuessMinPeaksPerDirection = double(options.initialGuessMinPeaksPerDirection);
options.minWetSamples = double(options.minWetSamples);
options.requireSuccessfulRun = logical(options.requireSuccessfulRun);
options.showProgressPlot = logical(options.showProgressPlot);
options.progressUpdateEvery = max(1, round(double(options.progressUpdateEvery)));
options.parallelizeSetups = logical(options.parallelizeSetups);
if isempty(options.numWorkers)
    options.numWorkers = [];
else
    options.numWorkers = double(options.numWorkers);
end
if isempty(options.numSetupWorkers)
    options.numSetupWorkers = [];
else
    options.numSetupWorkers = double(options.numSetupWorkers);
end
end

function runResult = iRunSingleSetup(setup, allStats, cableConfig, options, forceSerialInner)
localOptions = struct();
localOptions.optimizer = setup.optimizer;
localOptions.runSweep = false;
localOptions.maxFunctionEvaluations = setup.maxFunctionEvaluations;
localOptions.maxTime = setup.maxTime;
localOptions.lookbackDuration = options.lookbackDuration;
localOptions.dryRainThreshold = options.dryRainThreshold;
localOptions.lambdaDry = setup.lambdaDry;
localOptions.lambdaDrySq = setup.lambdaDrySq;
localOptions.enforceZeroDry = options.enforceZeroDry;
localOptions.saveFlagName = "";
localOptions.display = options.display;
localOptions.seed = setup.seed;
localOptions.verbose = false;
localOptions.runPrallel = options.runPrallel && ~forceSerialInner;
localOptions.numWorkers = options.numWorkers;
localOptions.useInitialGuess = options.useInitialGuess;
localOptions.initialFlagField = options.initialFlagField;
localOptions.initialGuessFreqTolerance = options.initialGuessFreqTolerance;
localOptions.initialGuessIntensityQuantile = options.initialGuessIntensityQuantile;
localOptions.initialGuessDampingQuantile = options.initialGuessDampingQuantile;
localOptions.initialGuessMinDirectionsRequired = options.initialGuessMinDirectionsRequired;
localOptions.initialGuessMinPeaksPerDirection = options.initialGuessMinPeaksPerDirection;
localOptions.minWetSamples = setup.minWetSamples;

[singleResult, ~] = optimizeCableRwivCriteria(allStats, cableConfig, localOptions);

runResult = struct();
runResult.setup = setup;
runResult.bestRun = singleResult.bestRun;
runResult.summary = singleResult.summary;
runResult.bestParameters = singleResult.bestParameters;
runResult.bestParametersTable = singleResult.bestParametersTable;
runResult.bestLayout = singleResult.bestLayout;
runResult.bestFlag = singleResult.bestFlag;
runResult.optimizerMessage = singleResult.bestRun.message;
end

function iEnsureSetupPool(numWorkers)
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

function state = iInitializeProgressState(numSetups, options)
state = struct();
state.numSetups = numSetups;
state.figure = [];
state.axes = [];
state.lineObjective = [];
state.lineDry = [];
state.lineWet = [];
state.successScatter = [];
state.failScatter = [];
state.tableText = [];
state.objectiveSeries = nan(numSetups, 1);
state.drySeries = nan(numSetups, 1);
state.wetSeries = nan(numSetups, 1);
state.successSeries = nan(numSetups, 1);

if ~options.showProgressPlot
    return;
end

if ~usejava('desktop')
    return;
end

state.figure = figure('Name', 'Overnight RWIV Optimization Progress', 'NumberTitle', 'off', 'Color', 'w');
tiled = tiledlayout(state.figure, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

state.axes.objective = nexttile(tiled, 1);
hold(state.axes.objective, 'on'); grid(state.axes.objective, 'on'); box(state.axes.objective, 'on');
title(state.axes.objective, 'Objective');
xlabel(state.axes.objective, 'Setup #'); ylabel(state.axes.objective, 'Objective');
state.lineObjective = plot(state.axes.objective, nan, nan, '-', 'LineWidth', 1.2, 'Color', [0.1 0.3 0.8]);

state.axes.dryWet = nexttile(tiled, 2);
hold(state.axes.dryWet, 'on'); grid(state.axes.dryWet, 'on'); box(state.axes.dryWet, 'on');
title(state.axes.dryWet, 'Dry/Wet Counts');
xlabel(state.axes.dryWet, 'Setup #'); ylabel(state.axes.dryWet, 'Count');
state.lineDry = plot(state.axes.dryWet, nan, nan, '-', 'LineWidth', 1.2, 'Color', [0.8 0.2 0.2], 'DisplayName', 'nDry');
state.lineWet = plot(state.axes.dryWet, nan, nan, '-', 'LineWidth', 1.2, 'Color', [0.2 0.6 0.2], 'DisplayName', 'nWet');
legend(state.axes.dryWet, 'Location', 'best');

state.axes.success = nexttile(tiled, 3);
hold(state.axes.success, 'on'); grid(state.axes.success, 'on'); box(state.axes.success, 'on');
title(state.axes.success, 'Run Success');
xlabel(state.axes.success, 'Setup #'); ylabel(state.axes.success, 'Success');
ylim(state.axes.success, [-0.1, 1.1]);
state.successScatter = scatter(state.axes.success, nan, nan, 22, [0.1 0.6 0.1], 'filled', 'DisplayName', 'success');
state.failScatter = scatter(state.axes.success, nan, nan, 22, [0.8 0.2 0.2], 'filled', 'DisplayName', 'fail');
legend(state.axes.success, 'Location', 'best');

state.axes.summary = nexttile(tiled, 4);
axis(state.axes.summary, 'off');
state.tableText = text(state.axes.summary, 0, 1, '', 'VerticalAlignment', 'top', 'FontName', 'Consolas', 'FontSize', 10);
end

function state = iUpdateProgressState(state, setupIdx, runResult)
if isempty(state.figure) || ~isvalid(state.figure)
    return;
end

state.objectiveSeries(setupIdx) = runResult.summary.objective;
state.drySeries(setupIdx) = runResult.summary.nDry;
state.wetSeries(setupIdx) = runResult.summary.nWet;
state.successSeries(setupIdx) = double(runResult.summary.success);

completedIdx = (1:setupIdx)';
set(state.lineObjective, 'XData', completedIdx, 'YData', state.objectiveSeries(completedIdx));
set(state.lineDry, 'XData', completedIdx, 'YData', state.drySeries(completedIdx));
set(state.lineWet, 'XData', completedIdx, 'YData', state.wetSeries(completedIdx));

successIdx = completedIdx(state.successSeries(completedIdx) > 0.5);
failIdx = completedIdx(state.successSeries(completedIdx) <= 0.5);
set(state.successScatter, 'XData', successIdx, 'YData', ones(size(successIdx)));
set(state.failScatter, 'XData', failIdx, 'YData', zeros(size(failIdx)));

bestObjective = min(state.objectiveSeries(completedIdx), [], 'omitnan');
bestDry = min(state.drySeries(completedIdx), [], 'omitnan');
completed = setupIdx;
summaryText = sprintf([ ...
    'Completed: %d / %d\n' ...
    'Current optimizer: %s\n' ...
    'Current objective: %.3f\n' ...
    'Current nDry / nWet: %d / %d\n' ...
    'Best objective so far: %.3f\n' ...
    'Best nDry so far: %d\n' ...
    'Last message: %s'], ...
    completed, state.numSetups, char(runResult.setup.optimizer), runResult.summary.objective, ...
    runResult.summary.nDry, runResult.summary.nWet, bestObjective, round(bestDry), char(runResult.optimizerMessage));
set(state.tableText, 'String', summaryText);

drawnow limitrate;
end

function available = iFilterAvailableOptimizers(optimizerList, verbose)
available = strings(0, 1);
for optimizer = optimizerList(:)'
    if iIsOptimizerAvailable(optimizer)
        available(end+1, 1) = optimizer; %#ok<AGROW>
    elseif verbose
        fprintf('[runOvernightCableRwivOptimization] Skipping unavailable optimizer: %s\n', char(optimizer));
    end
end
end

function isAvailable = iIsOptimizerAvailable(optimizer)
switch lower(char(optimizer))
    case 'surrogateopt'
        isAvailable = exist('surrogateopt', 'file') == 2;
    case 'ga'
        isAvailable = exist('ga', 'file') == 2;
    case 'patternsearch'
        isAvailable = exist('patternsearch', 'file') == 2;
    case 'fmincon'
        isAvailable = exist('fmincon', 'file') == 2;
    case 'particleswarm'
        isAvailable = exist('particleswarm', 'file') == 2;
    case 'simulannealbnd'
        isAvailable = exist('simulannealbnd', 'file') == 2;
    case 'multistart-fmincon'
        isAvailable = exist('fmincon', 'file') == 2 && exist('MultiStart', 'class') == 8;
    case 'globalsearch-fmincon'
        isAvailable = exist('fmincon', 'file') == 2 && exist('GlobalSearch', 'class') == 8;
    otherwise
        isAvailable = false;
end
end

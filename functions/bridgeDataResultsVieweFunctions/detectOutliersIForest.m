function [allStatsOut, Mdl, info] = detectOutliersIForest(allStats, opts)
%DETECTOUTLIERSIFOREST_ALLSTATS Outlier detection for "allStats" using Isolation Forest.
%
% Requirements:
%   - MATLAB R2021b+ with Statistics and Machine Learning Toolbox (for iforest/isanomaly)
%
% Inputs:
%   allStats : table (your 180626x42 table)
%   opts     : struct-like via name/value (see "arguments" block)
%
% Outputs:
%   allStatsOut : table = allStats with appended columns:
%                - iforestScore     (double, in [0,1])
%                - iforestIsAnomaly (logical)
%   Mdl        : IsolationForest model object (from iforest)
%   info       : struct with feature names, scaling params, threshold, etc.
%
% Example:
%   opts = struct;
%   opts.ContaminationFraction = 0.01;   % assume ~1% anomalies
%   opts.IncludeFlags = false;           % discover outliers beyond your flags
%   [T2, Mdl, info] = detectOutliersIForest_allStats(allStats, opts);

arguments
    allStats table
    opts.ContaminationFraction (1,1) double {mustBeGreaterThanOrEqual(opts.ContaminationFraction,0),mustBeLessThanOrEqual(opts.ContaminationFraction,1)} = 0.01
    opts.NumLearners (1,1) double {mustBeInteger,mustBePositive} = 200
    opts.NumObservationsPerLearner (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(opts.NumObservationsPerLearner,3)} = 256
    opts.UseParallel (1,1) logical = false

    opts.StructFields (1,:) string = ["mean","median","std","max","min","kurtosis","skewness","stationarityValue","stationarityRatio"]

    opts.IncludeFlags (1,1) logical = false          % include columns starting with "flag_"
    opts.IncludeLogicalNonFlags (1,1) logical = false % include other logical cols (e.g., isPotentialEvent)
    opts.AngleTransform (1,1) logical = true         % add sin/cos features for angle-like variables

    opts.MaxMissingFraction (1,1) double {mustBeGreaterThanOrEqual(opts.MaxMissingFraction,0),mustBeLessThanOrEqual(opts.MaxMissingFraction,1)} = 0.20
    opts.RobustScale (1,1) logical = true            % median/MAD scaling
    opts.ZClip (1,1) double {mustBePositive} = 20    % clipping after scaling to limit extreme leverage

    opts.RandomSeed (1,1) double {mustBeInteger} = 0
    opts.Verbose (1,1) logical = true
end

if exist("iforest","file") ~= 2
    error("detectOutliersIForest_allStats requires 'iforest' (MATLAB R2021b+ Stats and ML Toolbox).");
end

rng(opts.RandomSeed);

% 1) Build a numeric feature table from struct/logical/numeric columns
[featTblRaw, featMeta] = localFlattenAllStats(allStats, opts);

% Ensure numeric matrix for iforest
X = featTblRaw{:,:};
X = double(X);

% 2) Remove predictors with too much missingness
missingFrac = mean(isnan(X), 1);
keepCols = missingFrac <= opts.MaxMissingFraction;
dropped = featTblRaw.Properties.VariableNames(~keepCols);

X = X(:, keepCols);
featNames = featTblRaw.Properties.VariableNames(keepCols);

% 3) Impute missing values with per-column median
colMed = median(X, 1, "omitnan");
for j = 1:size(X,2)
    nanIdx = isnan(X(:,j));
    if any(nanIdx)
        X(nanIdx,j) = colMed(j);
    end
end

% 4) Robust scaling (recommended when mixing units / heavy tails)
center = zeros(1,size(X,2));
scale  = ones(1,size(X,2));

if opts.RobustScale
    center = median(X, 1);
    scale  = mad(X, 1, 1);           % median absolute deviation, unscaled
    scale(scale == 0) = 1;           % avoid divide-by-zero for constant predictors
    X = (X - center) ./ scale;
end

% Optional clipping
if ~isempty(opts.ZClip) && isfinite(opts.ZClip)
    X = max(min(X, opts.ZClip), -opts.ZClip);
end

% 5) Fit Isolation Forest and score all observations (outlier detection on the dataset)
n = size(X,1);
nPer = min(opts.NumObservationsPerLearner, n);
if nPer < 3
    error("Not enough observations to train Isolation Forest (need >= 3).");
end

[Mdl, tf, scores] = iforest( ...
    X, ...
    ContaminationFraction = opts.ContaminationFraction, ...
    NumLearners = opts.NumLearners, ...
    NumObservationsPerLearner = nPer, ...
    UseParallel = opts.UseParallel);

% 6) Append results
allStatsOut = allStats;
allStatsOut.iforestScore = scores;
allStatsOut.iforestIsAnomaly = tf;

% 7) Return metadata for reproducibility and later scoring
info = struct();
info.FeatureNames = featNames(:);
info.DroppedPredictors = dropped(:);
info.MissingFraction = missingFrac(:);
info.RobustCenter = center(:);
info.RobustScale = scale(:);
info.AngleTransform = opts.AngleTransform;
info.ModelScoreThreshold = Mdl.ScoreThreshold;
info.FlatteningMeta = featMeta;

if opts.Verbose
    fprintf("Isolation Forest trained: %d obs, %d predictors kept (%d dropped).\n", ...
        n, numel(featNames), numel(dropped));
    fprintf("ScoreThreshold = %.4f | ContaminationFraction = %.4f\n", ...
        Mdl.ScoreThreshold, opts.ContaminationFraction);
end

end

% ---------------- Local helper functions ----------------

function [featTbl, meta] = localFlattenAllStats(allStats, opts)
vars = allStats.Properties.VariableNames;
n = height(allStats);

featTbl = table();
meta = struct();
meta.SourceVariables = vars;

for k = 1:numel(vars)
    vname = vars{k};
    col = allStats.(vname);

    % Skip duration-like columns by default (commonly datetime arrays)
    if isdatetime(col) || isduration(col)
        continue;
    end

    % Skip nested spectral structs by default (often variable-length arrays)
    if strcmpi(vname, "psdPeaks") || strcmpi(vname, "cohVals")
        continue;
    end

    % Include selected logicals
    if islogical(col)
        isFlag = startsWith(vname, "flag_");
        if (isFlag && opts.IncludeFlags) || (~isFlag && opts.IncludeLogicalNonFlags)
            featTbl.(vname) = double(col);
        end
        continue;
    end

    % Numeric arrays: include scalar or vector columns as-is if they are 1-column
    if isnumeric(col)
        if isvector(col) && numel(col) == n
            featTbl.(vname) = double(col(:));
        end
        continue;
    end

    % Struct arrays: extract scalar struct fields into <var>_<field> feature columns
    if isstruct(col) && numel(col) == n
        for f = opts.StructFields
            f = char(f);
            if isfield(col, f)
                raw = [col.(f)]';
                if isnumeric(raw)
                    featName = matlab.lang.makeValidName(vname + "_" + string(f));
                    featTbl.(featName) = double(raw);
                end
            end
        end

        % Optional sin/cos expansion for angle-like variables
        if opts.AngleTransform && (contains(vname, "Dir", "IgnoreCase", true) || contains(vname, "Phi", "IgnoreCase", true))
            if isfield(col, "mean")
                ang = double([col.mean]');
                featTbl.(matlab.lang.makeValidName(vname + "_mean_sin")) = sind(ang);
                featTbl.(matlab.lang.makeValidName(vname + "_mean_cos")) = cosd(ang);
            end
        end
    end
end

end

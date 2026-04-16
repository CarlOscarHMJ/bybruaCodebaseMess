function plotTsneData(allStats, options)
    % plotTsneData Visualizes high-dimensional bridge data using dimensionality reduction (t-SNE/PCA/UMAP).
    %
    % Description:
    %   Projects bridge monitoring data into 2D space using t-SNE, PCA, or UMAP.
    %   Supports multiple feature groups and highlights flagged events.
    %
    % Arguments:
    %   allStats - Table containing bridge data with accelerometer, environmental, and peak data
    %
    % Options (name-value pairs):
    %   featureGroup     - Feature set: "all", "accelerometer", "environmental" (default: "all")
    %   method          - Dimensionality reduction: "tsne", "pca", "umap" (default: "tsne")
    %   tsnePerplexity  - t-SNE perplexity parameter (default: 30)
    %   tsneLearningRate - t-SNE learning rate (default: 'auto')
    %   tsneMaxIter    - t-SNE maximum iterations (default: 1000)
    %   umapNNeighbors - UMAP nearest neighbors (default: 15)
    %   umapMinDist    - UMAP minimum embedding distance (default: 0.1)
    %   umapNComponents - UMAP output dimensions (default: 2)
    %   umapMetric     - UMAP distance metric (default: "euclidean")
    %   umapVerbose    - UMAP verbosity flag (default: false)
    %   pcaComponents  - Number of PCA components to retain (default: 2)
    %   rwivFlag       - Field name for structural RWIV flag (default: 'flag_StructuralResponseMatch')
    %   weatherFlag    - Field name for critical weather flag (default: 'flag_EnvironmentalMatch')
    %   figureFolder   - Folder path to save figure (default: "")
    %   plotTitle       - Plot title (default: "")
    %   standardize    - Standardize features before reduction (default: true)
    %   sampleSize     - Max points to plot (random sample if larger, 0 for all) (default: 0)
    %   startDate      - Start datetime for filtering data (default: NaT = no filter)
    %   endDate        - End datetime for filtering data (default: NaT = no filter)
    %   rngSeed        - Random seed for reproducibility (default: 42)
    %
    % Example:
    %   plotTsneData(allStats, 'featureGroup', 'all', 'method', 'tsne', 'tsnePerplexity', 50)
    %   plotTsneData(allStats, 'startDate', datetime(2020,1,1), 'endDate', datetime(2020,12,31))
    %
    % See also: tsne, pca
    
    arguments
        allStats table
        options.featureGroup string = "all"
        options.method string = "tsne"
        options.tsnePerplexity {mustBePositive} = 30
        options.tsneLearningRate = 'auto'
        options.tsneMaxIter {mustBePositive} = 1000
        options.umapNNeighbors {mustBePositive} = 15
        options.umapMinDist {mustBeNonnegative} = 0.1
        options.umapNComponents {mustBePositive} = 2
        options.umapMetric string = "euclidean"
        options.umapVerbose logical = false
        options.pcaComponents {mustBePositive} = 2
        options.rwivFlag string = 'flag_StructuralResponseMatch'
        options.weatherFlag string = 'flag_EnvironmentalMatch'
        options.figureFolder string = ""
        options.plotTitle string = ""
        options.standardize logical = true
        options.sampleSize {mustBeNonnegative} = 0
        options.startDate {mustBeA(options.startDate, 'datetime')} = NaT
        options.endDate {mustBeA(options.endDate, 'datetime')} = NaT
        options.rngSeed {mustBeNonnegative} = 42
    end
    
    rng(options.rngSeed);
    
    segmentTimes = mean(allStats.duration, 2);
    fprintf('[1] Starting with %d rows\n', height(allStats));
    if ~isnat(options.startDate) || ~isnat(options.endDate)
        dateMask = true(height(allStats), 1);
        if ~isnat(options.startDate)
            dateMask = dateMask & segmentTimes >= options.startDate;
        end
        if ~isnat(options.endDate)
            dateMask = dateMask & segmentTimes <= options.endDate;
        end
        allStats = allStats(dateMask, :);
        fprintf('[2] Filtered to %d segments between %s and %s\n', height(allStats), ...
            datestr(options.startDate, 'yyyy-mm-dd'), datestr(options.endDate, 'yyyy-mm-dd'));
    end
    
    fprintf('[3] Extracting features...\n');
    features = extractFeatures(allStats, options.featureGroup);
    fprintf('[4] Features extracted: %d rows, %d features\n', size(features));
    
    validMask = all(~isnan(features), 2);
    featuresValid = features(validMask, :);
    fprintf('[5] Valid rows: %d out of %d\n', sum(validMask), height(allStats));
    
    if options.sampleSize > 0 && size(featuresValid, 1) > options.sampleSize
        rng(42);
        plotIdx = randperm(size(featuresValid, 1), options.sampleSize);
        featuresPlot = featuresValid(plotIdx, :);
        originalIdx = find(validMask);
        plotMask = false(size(validMask));
        plotMask(originalIdx(plotIdx)) = true;
    else
        featuresPlot = featuresValid;
        plotMask = validMask;
    end
    fprintf('[6] Plotting with %d points\n', sum(plotMask));
    
    if options.standardize
        fprintf('[7] Standardizing features...\n');
        featuresPlot = zscore(featuresPlot);
    end
    
    fprintf('[8] Running %s...\n', options.method);
    
    switch lower(options.method)
        case 'tsne'
            if ischar(options.tsneLearningRate) && ...
               strcmp(options.tsneLearningRate,'auto')
                options.tsneLearningRate = 500;
            end
            opts = statset('MaxIter', options.tsneMaxIter);
            Y = tsne(featuresPlot, ...
                'Perplexity', options.tsnePerplexity, ...
                'LearnRate', options.tsneLearningRate, ...
                'Algorithm', 'barneshut', ...
                'Options', opts);
        case 'pca'
            [coeff, ~, ~] = pca(featuresPlot);
            Y = featuresPlot * coeff(:, 1:options.pcaComponents);
        case 'umap'
            try
                np = py.importlib.import_module('numpy');
                umapModule = py.importlib.import_module('umap');
            catch ME
                error(['UMAP Python module not available. Configure MATLAB Python environment with pyenv and install ' ...
                       'umap-learn (pip install umap-learn). Original error: %s'], ME.message);
            end

            try
                reducer = umapModule.UMAP(pyargs( ...
                    'n_neighbors', int32(options.umapNNeighbors), ...
                    'min_dist', options.umapMinDist, ...
                    'n_components', int32(options.umapNComponents), ...
                    'metric', char(options.umapMetric), ...
                    'random_state', int32(options.rngSeed), ...
                    'n_jobs', int32(1), ...
                    'verbose', options.umapVerbose));

                Ypy = reducer.fit_transform(np.asarray(featuresPlot));
                Y = convertPythonEmbeddingToDouble(Ypy);
            catch ME
                error('UMAP execution failed via Python bridge: %s', ME.message);
            end
        otherwise
            error('Unknown method: %s. Use "tsne", "pca", or "umap".', options.method);
    end

    if size(Y, 2) < 2
        error('%s produced fewer than 2 dimensions; unable to create 2D scatter plot.', upper(options.method));
    end
    
    rwivFlagData = false(height(allStats), 1);
    weatherFlagData = false(height(allStats), 1);
    
    if ismember(options.rwivFlag, allStats.Properties.VariableNames)
        rwivFlagData = allStats.(options.rwivFlag);
    end
    
    if ismember(options.weatherFlag, allStats.Properties.VariableNames)
        weatherFlagData = allStats.(options.weatherFlag);
    end
    
    rwivMask = rwivFlagData(plotMask);
    weatherMask = weatherFlagData(plotMask);
    bothMask = rwivMask & weatherMask;
    
    fprintf('Data breakdown: Total=%d, RWIV=%d, Weather=%d, Both=%d, BG=%d\n', ...
        sum(plotMask), sum(rwivMask), sum(weatherMask), sum(bothMask), sum(~rwivMask & ~weatherMask));
    
    segmentTimesAll = mean(allStats.duration, 2);
    segmentTimesPlot = segmentTimesAll(plotMask);
    segmentDurationsPlot = allStats.duration(plotMask, :);
    
    figHandle = createFigure(6, 'TSNE');
    hold on;
    
    bgMask = ~rwivMask & ~weatherMask;
    if any(bgMask)
        hBg = scatter(Y(bgMask, 1), Y(bgMask, 2), 35,'filled','o','MarkerFaceColor',[0.6 0.6 0.6], 'MarkerFaceAlpha', 0.3);
        hBg.UserData = struct('times', segmentTimesPlot(bgMask), 'durations', segmentDurationsPlot(bgMask, :), 'category', 'bg');
    end
    
    weatherOnlyMask = ~rwivMask & weatherMask;
    if any(weatherOnlyMask)
        hWeather = scatter(Y(weatherOnlyMask, 1), Y(weatherOnlyMask, 2), 35,'o','MarkerFaceColor', [0.2 0.4 0.8], 'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor', 'none');
        hWeather.UserData = struct('times', segmentTimesPlot(weatherOnlyMask), 'durations', segmentDurationsPlot(weatherOnlyMask, :), 'category', 'weather');
    end
    
    rwivOnlyMask = rwivMask & ~weatherMask;
    if any(rwivOnlyMask)
        hRwiv = scatter(Y(rwivOnlyMask, 1), Y(rwivOnlyMask, 2), 35, 'o','MarkerFaceColor',[0.8 0.2 0.2], 'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor', 'none');
        hRwiv.UserData = struct('times', segmentTimesPlot(rwivOnlyMask), 'durations', segmentDurationsPlot(rwivOnlyMask, :), 'category', 'rwiv');
    end
    
    if any(bothMask)
        hBoth = scatter(Y(bothMask, 1), Y(bothMask, 2), 35 ,[0.8 0.3 0.3], 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1);
        hBoth.UserData = struct('times', segmentTimesPlot(bothMask), 'durations', segmentDurationsPlot(bothMask, :), 'category', 'both');
    end
    
    set(figHandle, 'WindowButtonDownFcn', @onWindowButtonDown);
    
    grid on; box on;
    xlabel(sprintf('%s Dimension 1', upper(options.method)), 'Interpreter', 'latex');
    ylabel(sprintf('%s Dimension 2', upper(options.method)), 'Interpreter', 'latex');
    
    if strlength(options.plotTitle) > 0
        title(options.plotTitle, 'Interpreter', 'latex');
    else
        featureGroupNames = struct('all', 'All Features', 'accelerometer', 'Accelerometer Only', 'environmental', 'Environmental Only');
        titleStr = sprintf('%s Projection of %s', options.method, featureGroupNames.(options.featureGroup));
        title(titleStr, 'Interpreter', 'latex');
    end
    
    legendEntries = {};
    if any(bgMask), legendEntries{end+1} = 'Background'; end
    if any(weatherOnlyMask), legendEntries{end+1} = sprintf('Critical Weather (%s)', strrep(options.weatherFlag, 'flag_', '')); end
    if any(rwivOnlyMask), legendEntries{end+1} = sprintf('RWIV Structural (%s)', strrep(options.rwivFlag, 'flag_', '')); end
    if any(bothMask), legendEntries{end+1} = 'RWIV + Critical Weather'; end
    
    if ~isempty(legendEntries)
        legend(legendEntries, 'Interpreter', 'latex', 'Location', 'best');
    end
    
    set(gca, 'TickLabelInterpreter', 'latex');
    
    if strlength(options.figureFolder) > 0
        saveName = sprintf('Embedding_%s_%s', options.featureGroup, options.method);
        saveFig(figHandle, options.figureFolder, saveName, 2, 1);
    end
end


function Y = convertPythonEmbeddingToDouble(pyEmbedding)
    np = py.importlib.import_module('numpy');
    pyArray = np.asarray(pyEmbedding, pyargs('dtype', np.float64));

    nDims = int64(py.len(pyArray.shape));
    if nDims ~= 2
        error('Expected a 2D embedding array from Python UMAP, got %dD.', nDims);
    end

    nRows = int64(pyArray.shape{1});
    nCols = int64(pyArray.shape{2});

    flatData = double(pyArray.flatten().tolist());
    Y = reshape(flatData, [nCols, nRows]).';
end


function features = extractFeatures(allStats, featureGroup)
    features = [];
    
    switch lower(featureGroup)
        case 'all'
            features = [extractAccelerometerFeatures(allStats), ...
                        extractPeakFeatures(allStats), ...
                        extractCoherenceFeatures(allStats), ...
                        extractEnvironmentalFeatures(allStats)];
        case 'accelerometer'
            features = [extractAccelerometerFeatures(allStats), ...
                        extractPeakFeatures(allStats), ...
                        extractCoherenceFeatures(allStats)];
        case 'environmental'
            features = extractEnvironmentalFeatures(allStats);
        otherwise
            error('Unknown feature group: %s', featureGroup);
    end
end


function accFeatures = extractAccelerometerFeatures(allStats)
    numRows = height(allStats);
    fields = ["Steel_Z", "Conc_Z"];
    featureNames = {'mean', 'std', 'max', 'min', 'kurtosis', 'skewness'};
    
    numFeatures = 0;
    for field = fields
        if ismember(field, allStats.Properties.VariableNames)
            for fName = featureNames
                if isfield(allStats.(field)(1), fName)
                    numFeatures = numFeatures + 1;
                end
            end
        end
    end
    
    accFeatures = zeros(numRows, numFeatures);
    colIdx = 1;
    
    for field = fields
        if ismember(field, allStats.Properties.VariableNames)
            for fName = featureNames
                if isfield(allStats.(field)(1), fName)
                    colData = zeros(numRows, 1);
                    for i = 1:numRows
                        colData(i) = allStats.(field)(i).(fName{1});
                    end
                    accFeatures(:, colIdx) = colData;
                    colIdx = colIdx + 1;
                end
            end
        end
    end
    accFeatures = accFeatures(:, 1:colIdx-1);
end


function peakFeatures = extractPeakFeatures(allStats)
    numRows = height(allStats);
    fields = ["Steel_Z", "Conc_Z"];
    peakFeatures = zeros(numRows, length(fields) * 13);
    
    for fIdx = 1:length(fields)
        field = fields(fIdx);
        colStart = (fIdx - 1) * 13 + 1;
        colEnd = fIdx * 13;
        
        for i = 1:numRows
            if isfield(allStats.psdPeaks(i), field)
                peakData = allStats.psdPeaks(i).(field);
                
                numPeaks = length(peakData.locations);
                
                if numPeaks > 0
                    peakFreqMean = mean(peakData.locations);
                    peakFreqStd = std(peakData.locations);
                    peakFreqMin = min(peakData.locations);
                    peakFreqMax = max(peakData.locations);
                    
                    peakIntMean = mean(peakData.logIntensity);
                    peakIntStd = std(peakData.logIntensity);
                else
                    peakFreqMean = NaN; peakFreqStd = NaN;
                    peakFreqMin = NaN; peakFreqMax = NaN;
                    peakIntMean = NaN; peakIntStd = NaN;
                end
                
                if isfield(peakData, 'dampingRatios') && ~isempty(peakData.dampingRatios)
                    validDamping = peakData.dampingRatios(~isnan(peakData.dampingRatios));
                    if ~isempty(validDamping)
                        dampMean = mean(validDamping);
                        dampStd = std(validDamping);
                        dampMed = median(validDamping);
                    else
                        dampMean = NaN; dampStd = NaN; dampMed = NaN;
                    end
                else
                    dampMean = NaN; dampStd = NaN; dampMed = NaN;
                end
                
                peakFeatures(i, colStart:colEnd) = [numPeaks, peakFreqMean, peakFreqStd, peakFreqMin, peakFreqMax, ...
                                                     peakIntMean, peakIntStd, dampMean, dampStd, dampMed, ...
                                                     numPeaks > 2, numPeaks > 3, numPeaks > 0];
            end
        end
    end
end


function cohFeatures = extractCoherenceFeatures(allStats)
    numRows = height(allStats);
    cohDirections = ["Z", "Y", "X"];
    cohFeatures = zeros(numRows, length(cohDirections));
    
    for dIdx = 1:length(cohDirections)
        dir = cohDirections(dIdx);
        if ismember('cohVals', allStats.Properties.VariableNames)
            colData = zeros(numRows, 1);
            for i = 1:numRows
                if isfield(allStats.cohVals(i), dir)
                    cohVals = allStats.cohVals(i).(dir);
                    if ~isempty(cohVals)
                        colData(i) = cohVals(1);
                    end
                end
            end
            cohFeatures(:, dIdx) = colData;
        end
    end
end


function envFeatures = extractEnvironmentalFeatures(allStats)
    numRows = height(allStats);
    fields = ["WindSpeed", "PhiC1", "RainIntensity"];
    featureNames = {'mean', 'std', 'max', 'min'};
    
    numFeatures = 0;
    for field = fields
        if ismember(field, allStats.Properties.VariableNames)
            for fName = featureNames
                if isfield(allStats.(field)(1), fName)
                    numFeatures = numFeatures + 1;
                end
            end
        end
    end
    
    envFeatures = zeros(numRows, numFeatures);
    colIdx = 1;
    
    for field = fields
        if ismember(field, allStats.Properties.VariableNames)
            for fName = featureNames
                if isfield(allStats.(field)(1), fName)
                    colData = zeros(numRows, 1);
                    for i = 1:numRows
                        colData(i) = allStats.(field)(i).(fName{1});
                    end
                    envFeatures(:, colIdx) = colData;
                    colIdx = colIdx + 1;
                end
            end
        end
    end
    envFeatures = envFeatures(:, 1:colIdx-1);
end


function onWindowButtonDown(~, ~)
    ax = gca;
    clickCoords = ax.CurrentPoint(1, 1:2);
    clickX = clickCoords(1);
    clickY = clickCoords(2);
    
    xLimits = ax.XAxis.Limits;
    yLimits = ax.YAxis.Limits;
    xTotalRange = diff(xLimits);
    yTotalRange = diff(yLimits);
    
    scatterObjects = findobj(ax, 'Type', 'scatter');
    minDist = inf;
    bestIdx = 0;
    bestScatter = [];
    
    for i = 1:numel(scatterObjects)
        currentScatter = scatterObjects(i);
        if isempty(currentScatter.XData), continue; end
        
        xData = currentScatter.XData;
        yData = currentScatter.YData;
        
        xDist = (xData - clickX) / xTotalRange;
        yDist = (yData - clickY) / yTotalRange;
        
        normalizedDist = xDist.^2 + yDist.^2;
        [localMin, localIdx] = min(normalizedDist);
        
        if ~isempty(localMin) && localMin < minDist
            minDist = localMin;
            bestIdx = localIdx;
            bestScatter = currentScatter;
        end
    end
    
    if ~isempty(bestScatter) && minDist < 0.01
        userData = bestScatter.UserData;
        if isfield(userData, 'durations')
            segmentDurations = userData.durations;
            category = userData.category;
            startTime = segmentDurations(bestIdx, 1);
            endTime = segmentDurations(bestIdx, 2);
            
            fprintf('Selected %s point at %s\n', category, datestr(startTime));
            inspectDayResponse(startTime, endTime, "freqMethod", "burg");
        end
    end
end

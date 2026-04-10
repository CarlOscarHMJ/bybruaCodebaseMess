function plotDampingVsFrequency(allStats, limits, options)
    % plotDampingVsFrequency Creates scatter plot of damping ratio vs peak frequency
    %
    %   Plots individual peak damping values against peak frequencies,
    %   color-coded by RWIV classification status.
    %
    % Arguments:
    %   allStats              - Table with psdPeaks, duration, and flag fields
    %   limits                - Struct with targetFreqs, freqTolerance
    %   options.specFlagField - RWIV classification flag field (default: 'flag_StructuralResponseMatch')
    %   options.envFlagField  - Environmental match flag field (default: 'flag_EnvironmentalMatch')
    %   options.frequencyFocus - 'all' (all peaks) or 'target' (only near target freqs)
    %   options.targetFreqs_override - Override target frequencies from limits
    %   options.freqTolerance_override - Override tolerance from limits
    %   options.figureFolder  - Save directory (default: '')
    %
    % Output:
    %   Figure with tiledlayout: rows = directions (X, Y, Z), columns = accelerometers (Conc, Steel)
    %
    % Example:
    %   plotDampingVsFrequency(allStats, limits, 'frequencyFocus', 'all', 'figureFolder', 'figures/');

    arguments
        allStats table
        limits struct
        options.specFlagField char = 'flag_StructuralResponseMatch'
        options.envFlagField char = 'flag_EnvironmentalMatch'
        options.frequencyFocus char = 'all'
        options.targetFreqs_override double = []
        options.freqTolerance_override double = []
        options.figureFolder char = ''
        options.yAxisScale (1,1) string {mustBeMember(options.yAxisScale, ["linear", "log"])} = "log"
        options.xAxisScale (1,1) string {mustBeMember(options.xAxisScale, ["linear", "log"])} = "linear"
    end

    targetFreqs = iResolveTargetFreqs(limits, options);
    freqTolerance = iResolveTolerance(limits, options);

    directions = {'X', 'Y', 'Z'};
    accels = {'Conc', 'Steel'};

    numRows = length(directions);
    numCols = length(accels);
    fig = createFigure(100, 'DampingVsFrequency');
    tlo = tiledlayout(numRows, numCols, 'TileSpacing', 'compact', 'Padding', 'tight');

    specCol = allStats.(options.specFlagField);
    if iscell(specCol)
        specFlags = cellfun(@(x) x{1}, specCol, 'UniformOutput', false);
        specFlags = cell2mat(specFlags);
    else
        specFlags = logical(specCol);
    end

    envCol = allStats.(options.envFlagField);
    if iscell(envCol)
        envFlags = cellfun(@(x) x{1}, envCol, 'UniformOutput', false);
        envFlags = cell2mat(envFlags);
    else
        envFlags = logical(envCol);
    end

    rainIntensity = [allStats.RainIntensity.mean]';
    isWet = rainIntensity > 0;

    allData = cell(numRows, numCols);
    for row = 1:numRows
        direction = directions{row};
        for col = 1:numCols
            accel = accels{col};
            sensor = [accel, '_', direction];
            [peakFreqs, peakDamping, segmentIndices] = extractAllPeaks(allStats, sensor, targetFreqs, freqTolerance, options.frequencyFocus);
            if ~isempty(peakFreqs)
                segSpecFlags = specFlags(segmentIndices);
                segEnvFlags = envFlags(segmentIndices);
                segIsWet = isWet(segmentIndices);
                allData{row, col} = struct('freqs', peakFreqs, 'damping', peakDamping, ...
                    'isRwiv', segSpecFlags, 'isBlue', ~segSpecFlags & segEnvFlags & segIsWet, ...
                    'isGray', ~segSpecFlags & (~segEnvFlags | ~segIsWet));
            end
        end
    end

    globalMaxDamping = 0;
    globalMinDamping = inf;
    for row = 1:numRows
        for col = 1:numCols
            if isstruct(allData{row, col})
                validDamping = allData{row, col}.damping(~isnan(allData{row, col}.damping) & allData{row, col}.damping > 0);
                if ~isempty(validDamping)
                    globalMaxDamping = max(globalMaxDamping, max(validDamping));
                    globalMinDamping = min(globalMinDamping, min(validDamping));
                end
            end
        end
    end
    yMax = max(0.05, globalMaxDamping) + 0.02;
    yMinLog = iResolveLogYMin(globalMinDamping);

    for row = 1:numRows
        direction = directions{row};
        for col = 1:numCols
            accel = accels{col};
            sensor = [accel, '_', direction];

            ax = nexttile(tlo);
            hold(ax, 'on');
            grid(ax, 'on');
            box(ax, 'on');

            if ~isstruct(allData{row, col}) || isempty(allData{row, col}.freqs)
                title(ax, sprintf('\\texttt{%s}', strrep(sensor, '_', '\_')), 'Interpreter', 'latex');
                continue;
            end

            d = allData{row, col};

            if any(d.isGray)
                scatter(ax, d.freqs(d.isGray), d.damping(d.isGray), 30, [0.6 0.6 0.6], ...
                    'filled', 'MarkerFaceAlpha', 0.25, 'MarkerEdgeColor', 'none');
            end

            if any(d.isBlue)
                scatter(ax, d.freqs(d.isBlue), d.damping(d.isBlue), 40, [0.2 0.4 0.6], ...
                    'filled', 'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor', 'none');
            end

            if any(d.isRwiv)
                scatter(ax, d.freqs(d.isRwiv), d.damping(d.isRwiv), 50, [0.8 0.2 0.2], ...
                    'filled', 'MarkerFaceAlpha', 0.7, 'MarkerEdgeColor', 'none');
            end

            for tf = targetFreqs(:)'
                xVerts = [tf - freqTolerance, tf - freqTolerance, tf + freqTolerance, tf + freqTolerance];
                yPatchMin = 0;
                if options.yAxisScale == "log"
                    yPatchMin = yMinLog;
                end
                yVerts = [yPatchMin, yMax, yMax, yPatchMin];
                patch(ax, xVerts, yVerts, [0.5 0.5 0.5], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HitTest', 'off');
                xline(ax, tf, '--k', 'LineWidth', 1.0, 'Alpha', 0.6, 'HitTest', 'off');
            end

            xlabel(ax, 'Frequency (Hz)', 'Interpreter', 'latex');
            if col == 1
                ylabel(ax, 'Damping $\zeta$', 'Interpreter', 'latex');
            end
            title(ax, sprintf('\\texttt{%s}', strrep(sensor, '_', '\_')), 'Interpreter', 'latex');
            set(ax, 'TickLabelInterpreter', 'latex');
            set(ax, 'YScale',options.yAxisScale)
            set(ax, 'XScale',options.xAxisScale)
        end
    end

    allAxes = findobj(tlo, 'Type', 'axes');
    for ax = allAxes'
        xlim(ax, [0.4 10]);
        if strcmp(ax.YScale, 'log')
            yUpper = max(yMax, yMinLog * 10);
            ylim(ax, [yMinLog yUpper]);
        else
            yUpper = max(yMax, 0.01);
            ylim(ax, [0 yUpper]);
        end
    end
    linkaxes(allAxes, 'xy');

    for ax = allAxes'
        yLimits = ylim(ax);
        iEnsureAtLeastTwoYTicks(ax, yLimits(1), yLimits(2));
        set(ax, 'YTickMode', 'manual');
        ytickformat(ax, '%.4g');
    end

    legend(ax, {'Background','Env. Match','RWIV Event'}, ...
        'Location', 'best', 'Interpreter', 'latex');

    if strlength(options.figureFolder) > 0
        saveName = sprintf('DampingVsFrequency_%s_%s', options.frequencyFocus, options.specFlagField);
        saveFig(fig, options.figureFolder, saveName, numCols/1.3, numRows/3);
    end
end

function targetFreqs = iResolveTargetFreqs(limits, options)
    if ~isempty(options.targetFreqs_override)
        targetFreqs = options.targetFreqs_override;
    else
        targetFreqs = limits.targetFreqs;
    end
end

function freqTolerance = iResolveTolerance(limits, options)
    if ~isempty(options.freqTolerance_override)
        freqTolerance = options.freqTolerance_override;
    else
        freqTolerance = limits.freqTolerance;
    end
end

function [peakFreqs, peakDamping, segmentIndices] = extractAllPeaks(allStats, sensor, targetFreqs, freqTolerance, frequencyFocus)
    numSegments = height(allStats);
    peakFreqs = [];
    peakDamping = [];
    segmentIndices = [];

    for i = 1:numSegments
        if ~isfield(allStats.psdPeaks, sensor)
            continue;
        end

        peakStruct = allStats.psdPeaks(i).(sensor);
        if ~isfield(peakStruct, 'locations') || ~isfield(peakStruct, 'dampingRatios')
            continue;
        end

        locations = peakStruct.locations(:);
        damping = peakStruct.dampingRatios(:);

        validMask = ~isnan(damping) & ~isnan(locations) & damping > 0 & damping < 1;
        locations = locations(validMask);
        damping = damping(validMask);

        if isempty(locations), continue; end

        switch frequencyFocus
            case 'target'
                for tf = targetFreqs(:)'
                    mask = abs(locations - tf) <= freqTolerance;
                    if any(mask)
                        peakFreqs = [peakFreqs; locations(mask)];
                        peakDamping = [peakDamping; damping(mask)];
                        segmentIndices = [segmentIndices; repmat(i, sum(mask), 1)];
                    end
                end

            case 'all'
                peakFreqs = [peakFreqs; locations];
                peakDamping = [peakDamping; damping];
                segmentIndices = [segmentIndices; repmat(i, length(locations), 1)];

            otherwise
                error('frequencyFocus must be ''all'' or ''target''');
        end
    end
end

function yMinLog = iResolveLogYMin(globalMinDamping)
    if isfinite(globalMinDamping) && globalMinDamping > 0
        yMinLog = 10^floor(log10(globalMinDamping));
    else
        yMinLog = 1e-3;
    end
end

function iEnsureAtLeastTwoYTicks(ax, yMin, yMax)
    if ~isfinite(yMin) || ~isfinite(yMax)
        return;
    end

    if yMax <= yMin
        if strcmp(ax.YScale, 'log')
            yMin = max(yMin, eps);
            yMax = yMin * 10;
        else
            yMax = yMin + 1;
        end
        ylim(ax, [yMin yMax]);
    end

    yTicks = yticks(ax);
    yTicks = yTicks(isfinite(yTicks) & yTicks >= yMin & yTicks <= yMax);
    if numel(yTicks) < 2
        yticks(ax, [yMin, yMax]);
    end
end

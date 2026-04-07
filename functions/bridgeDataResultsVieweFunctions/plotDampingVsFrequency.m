function plotDampingVsFrequency(allStats, limits, options)
    % plotDampingVsFrequency Creates scatter plot of damping ratio vs peak frequency
    %
    %   Plots segment-level aggregated damping values against peak frequencies,
    %   color-coded by RWIV classification status.
    %
    % Arguments:
    %   allStats              - Table with psdPeaks, duration, and flag fields
    %   limits                - Struct with targetFreqs, freqTolerance
    %   options.specFlagField - RWIV classification flag field (default: 'flag_StructuralResponseMatch')
    %   options.envFlagField  - Environmental match flag field (default: 'flag_EnvironmentalMatch')
    %   options.frequencyFocus - 'all' (mean per segment) or 'target' (only near target freqs)
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
            [segFreqs, segDamping, validIdx] = extractSegmentDamping(allStats, sensor, targetFreqs, freqTolerance, options.frequencyFocus);
            if ~isempty(segFreqs)
                segSpecFlags = specFlags(validIdx);
                segEnvFlags = envFlags(validIdx);
                segIsWet = isWet(validIdx);
                allData{row, col} = struct('freqs', segFreqs, 'damping', segDamping, ...
                    'isRwiv', segSpecFlags, 'isBlue', ~segSpecFlags & segEnvFlags & segIsWet, ...
                    'isGray', ~segSpecFlags & (~segEnvFlags | ~segIsWet));
            end
        end
    end

    globalMaxDamping = 0;
    for row = 1:numRows
        for col = 1:numCols
            if isstruct(allData{row, col})
                globalMaxDamping = max(globalMaxDamping, max(allData{row, col}.damping(~isnan(allData{row, col}.damping))));
            end
        end
    end
    yMax = max(0.05, globalMaxDamping) + 0.02;

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
                yVerts = [0, yMax, yMax, 0];
                patch(ax, xVerts, yVerts, [0.5 0.5 0.5], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HitTest', 'off');
                xline(ax, tf, '--k', 'LineWidth', 1.0, 'Alpha', 0.6, 'HitTest', 'off');
            end

            xlabel(ax, 'Frequency (Hz)', 'Interpreter', 'latex');
            if col == 1
                ylabel(ax, 'Damping $\zeta$', 'Interpreter', 'latex');
            end
            title(ax, sprintf('\\texttt{%s}', strrep(sensor, '_', '\_')), 'Interpreter', 'latex');
            set(ax, 'TickLabelInterpreter', 'latex');
            xlim(ax, [0.4 10]);
            ylim(ax, [0 yMax]);
        end
    end

    allAxes = findobj(tlo, 'Type', 'axes');
    for ax = allAxes'
        xlim(ax, [0.4 10]);
        ylim(ax, [0 yMax]);
    end
    linkaxes(allAxes, 'xy');

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

function [segFreqs, segDamping, validIdx] = extractSegmentDamping(allStats, sensor, targetFreqs, freqTolerance, frequencyFocus)
    numSegments = height(allStats);
    segFreqs = zeros(numSegments, 1);
    segDamping = zeros(numSegments, 1);
    validIdx = zeros(numSegments, 1);
    count = 0;

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
                peakFreqs = [];
                peakDamps = [];
                for tf = targetFreqs(:)'
                    mask = abs(locations - tf) <= freqTolerance;
                    if any(mask)
                        peakFreqs = [peakFreqs; tf];
                        peakDamps = [peakDamps; mean(damping(mask))];
                    end
                end
                if isempty(peakFreqs), continue; end
                count = count + 1;
                segFreqs(count) = mean(peakFreqs);
                segDamping(count) = mean(peakDamps);
                validIdx(count) = i;

            case 'all'
                count = count + 1;
                segFreqs(count) = mean(locations);
                segDamping(count) = mean(damping);
                validIdx(count) = i;

            otherwise
                error('frequencyFocus must be ''all'' or ''target''');
        end
    end

    segFreqs = segFreqs(1:count);
    segDamping = segDamping(1:count);
    validIdx = validIdx(1:count);
end

function plotRwivGlobalProbability(allStats, flagFields, figureFolder, fileName, toggleTitle, timeRange)
    % plotRwivGlobalProbability Evaluates and plots the probability of given flag fields.
    % Optional timeRange parameter accepts a cell array of [startTime, endTime] datetime 
    % boundaries for each corresponding flagField to evaluate probabilities over specific periods.
    
    arguments
        allStats table
        flagFields (1,:) string
        figureFolder (1,1) string = ""
        fileName (1,1) string = "RwivGlobalProbabilityStudy"
        toggleTitle (1,1) logical = true
        timeRange cell = {}
    end

    figHandle = createFigure(4, "RWIV Global Probability Summary");
    axMain = axes(figHandle);
    hold(axMain, "on");

    [probabilities, observationCounts] = calculateProbabilities(allStats, flagFields, timeRange);

    barGroup = bar(axMain, probabilities, "FaceColor", "flat");
    
    applyBarColors(barGroup, flagFields);
    addBarLabels(axMain, probabilities);
    formatAxes(axMain, flagFields, observationCounts);

    if toggleTitle
        addPlotTitle(axMain, observationCounts);
    end

    saveFig(figHandle, figureFolder, fileName);
end

function [probabilities, observationCounts] = calculateProbabilities(allStats, flagFields, timeRange)
    numFlags = length(flagFields);
    probabilities = zeros(1, numFlags);
    observationCounts = zeros(1, numFlags);
    hasTimeRange = ~isempty(timeRange);

    for i = 1:numFlags
        currentFlagName = flagFields(i);
        currentStats = allStats;
        Time = mean(currentStats.duration,2);
        if hasTimeRange && ~isempty(timeRange{i})
            currentRange = timeRange{i};
            timeMask = Time >= currentRange(1) & Time <= currentRange(2);
            currentStats = currentStats(timeMask, :);
        end

        observationCounts(i) = height(currentStats);
        if observationCounts(i) > 0
            probabilities(i) = (sum(currentStats.(currentFlagName)) / observationCounts(i)) * 100;
        end
    end
end

function applyBarColors(barGroup, flagFields)
    blueColor = [0.2 0.4 0.6];
    redColor = [0.6 0.2 0.2];

    for i = 1:length(flagFields)
        if contains(flagFields(i), "env", "IgnoreCase", true) || ...
           contains(flagFields(i), "Wind", "IgnoreCase", true) || ...
           contains(flagFields(i), "Rain", "IgnoreCase", true)
            barGroup.CData(i, :) = redColor;
        else
            barGroup.CData(i, :) = blueColor;
        end
    end
end

function addBarLabels(axMain, probabilities)
    for i = 1:length(probabilities)
        text(axMain, i, probabilities(i), ...
            sprintf("%.2f\\%%", probabilities(i)), ...
            "VerticalAlignment", "bottom", ...
            "HorizontalAlignment", "center", ...
            "Interpreter", "latex");
    end
end

function formatAxes(axMain, flagFields, observationCounts)
    axMain.YLim(2) = axMain.YLim(2) * 1.05; 
    grid(axMain, "on"); 
    box(axMain, "on");
    
    ylabel(axMain, "Global Probability (\%)", "Interpreter", "latex");
    
    xLabels = strrep(flagFields, "_", "\_");
    set(axMain, "XTick", 1:length(flagFields), "XTickLabel", xLabels, ...
        "TickLabelInterpreter", "latex");

    if all(observationCounts == observationCounts(1)) && observationCounts(1) > 0
        totalDataHours = observationCounts(1) * (1/6);
        
        yyaxis(axMain, "right");
        ylabel(axMain, "Total Duration (Hours)", "Interpreter", "latex");
        axMain.YAxis(2).Color = [0 0 0];
        
        scalingFactor = totalDataHours / 100;
        axMain.YAxis(2).Limits = axMain.YAxis(1).Limits * scalingFactor;
    end
end

function addPlotTitle(axMain, observationCounts)
    if all(observationCounts == observationCounts(1)) && observationCounts(1) > 0
        totalDataHours = observationCounts(1) * (1/6);
        titleStr = {
            "\textbf{RWIV Detection Probability Summary}";
            sprintf("Total Dataset Duration: %.1f Hours (%d 10-min Segments)", totalDataHours, observationCounts(1))
        };
    else
        titleStr = "\textbf{RWIV Detection Probability Summary (Variable Time Ranges)}";
    end
    
    title(axMain, titleStr, "Interpreter", "latex");
end

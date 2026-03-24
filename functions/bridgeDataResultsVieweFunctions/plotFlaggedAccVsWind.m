function plotFlaggedAccVsWind(allStats, flagFields, windDomain, figureFolder)
    % Plots flagged acceleration values against wind speed in a tiled layout.
    arguments
        allStats
        flagFields
        windDomain = 'local'
        figureFolder = ''
    end

    if ischar(flagFields) || isstring(flagFields)
        flagFields = cellstr(flagFields);
    end

    numPlots = length(flagFields);
    fig = createFigure(2, 'Acceleration vs. Wind Speed Evaluation');
    tlo = tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'tight');
    fields = ["Conc_Z" "Steel_Z"];
    
    for i = 1:numPlots
        ax = nexttile;
        orderedcolors("earth");
        currentFlag = flagFields{i};
        events = allStats(allStats.(currentFlag), :);
        
        if strcmpi(windDomain, 'local')
            windSpeed = [events.UNormalC1.mean]';
        else
            windSpeed = [events.WindSpeed.mean]';
        end

        for field = fields
            hold on

            acc = abs([events.(field).max]');
            scatter(windSpeed, acc, 50, 'filled',...
                'MarkerFaceAlpha', 0.6, 'MarkerEdgeAlpha', 0,'DisplayName',field);
        end
        grid on; box on;
        
        title(sprintf('Flag: \\texttt{%s}', strrep(currentFlag, '_', '\_')), 'Interpreter', 'latex');
        set(gca, 'TickLabelInterpreter', 'latex');
        xlim([0 16])
        ylim([0 0.04])
    end

    if strcmpi(windDomain, 'local')
        xlabel(tlo, '$U_{N,C1}$ ($\mathrm{m\,s^{-1}}$)', 'Interpreter', 'latex');
    else
        xlabel(tlo, 'Mean Wind Speed ($\mathrm{m\,s^{-1}}$)', 'Interpreter', 'latex');
    end
    ylabel(tlo, 'Max Deck Acceleration ($\mathrm{m\,s^{-2}}$)', 'Interpreter', 'latex');
    legend

    fileName = ['AccVsWindEvaluation' char(upper(windDomain(1))) windDomain(2:end)];
    saveFig(fig,figureFolder,fileName);
end

function plotCoherenceDistribution(allStats, limits, figureFolder)
    arguments
        allStats
        limits
        figureFolder = ''
    end
    
    scaleText = 14;
    figHandle = createFigure(4, 'Coherence Signature Distribution');
    layoutObj = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'tight');
    
    targetFreqs = limits.targetCoherenceFreq;
    cohLimits = limits.coherenceLimit;
    
    coherenceMatrix = [allStats.cohVals{:}];

    for i = 1:length(targetFreqs)
        axObj = nexttile;
        hold(axObj, 'on');
        
        currentData = coherenceMatrix(i, :);
        
        histogram(axObj, currentData, 'BinWidth', 0.01, ...
            ...%'FaceAlpha', 0.6, 'EdgeColor', 'none', ...
            'DisplayName', sprintf('Observed $\\gamma^2$ at %.2f Hz', targetFreqs(i)));
        
        xline(axObj, cohLimits(i), '--', 'Color', [0.8 0 0], 'LineWidth', 1.2, ...
            'Label', sprintf('Limit: %.2f', cohLimits(i)), ...
            'Interpreter', 'latex', 'FontSize', scaleText,'LabelOrientation','horizontal');
        
        set(axObj, 'FontSize', scaleText, 'TickLabelInterpreter', 'latex');
        grid(axObj, 'on'); box(axObj, 'on');
        
        
        title(axObj, sprintf('Coherence Distribution at $f = %.2f$ Hz', targetFreqs(i)), ...
            'Interpreter', 'latex', 'FontSize', scaleText);
        
        xlim(axObj, [-1 1]);
    end
    ylabel(layoutObj, 'Count', 'Interpreter', 'latex', 'FontSize', scaleText);
    xlabel(layoutObj, 'Coherence $\gamma$', 'Interpreter', 'latex', 'FontSize', scaleText);
    
    fileName = 'BridgeCoherenceThresholdDistribution';
    saveFig(figHandle,figureFolder,fileName)
end

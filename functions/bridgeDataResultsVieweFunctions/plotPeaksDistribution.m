function plotPeaksDistribution(allStats, limits, figureFolder, dir)
    arguments
        allStats
        limits
        figureFolder = ''
        dir = 'Z'
    end
    dir = CapitalizeText(dir);
    fields = strcat(["Conc_", "Steel_"],dir);

    scaleText = 14;
    figHandle = createFigure(3, 'Spectral Signature Distribution');
    layoutObj = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'tight');
    
    targetFrequencies = limits.targetFreqs;
    freqTolerance = limits.freqTolerance;

    for segmentIdx = 1:length(fields)
        axObj = nexttile;
        hold(axObj, 'on');
        
        peakStructArray = [allStats.psdPeaks];
        segmentPeaks = [peakStructArray.(fields(segmentIdx))];
        
        allPeakFreqs = vertcat(segmentPeaks.locations);
        allPeakSzz = exp(vertcat(segmentPeaks.logIntensity));
        
        if min(allPeakSzz) < 10^(-50)
            [~,idx] = min(allPeakSzz);
            allPeakSzz(idx) = [];
            allPeakFreqs(idx) = [];
        end

        yBins = logspace(log10(min(allPeakSzz)), log10(max(allPeakSzz)), 100);
        xBins = linspace(min(allPeakFreqs), max(allPeakFreqs), 200);

        histogram2(axObj, allPeakFreqs, allPeakSzz, xBins, yBins, ...
            'DisplayStyle', 'tile', 'ShowEmptyBins', 'off', 'EdgeColor', 'none');
        
        set(axObj, 'YScale', 'log', 'ColorScale', 'log', ...
            'FontSize', scaleText, 'TickLabelInterpreter', 'latex');
        
        for fTarget = targetFrequencies
            xline(axObj, fTarget, '--', 'Color', [0.8 0 0], 'LineWidth', 1.2, ...
                'Label', sprintf('$f_{target} = %.2f$ Hz', fTarget), ...
                'Interpreter', 'latex', 'FontSize', scaleText,'LabelOrientation','horizontal');
            
            patch(axObj, [fTarget - freqTolerance, fTarget + freqTolerance, ...
                          fTarget + freqTolerance, fTarget - freqTolerance], ...
                [min(allPeakSzz) min(allPeakSzz) max(allPeakSzz) max(allPeakSzz)], ...
                'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end

        grid(axObj, 'on'); box(axObj, 'on');
        ylabel(axObj, sprintf('%s $S_{zz}$ ($\\mathrm{m^2/s^4/Hz}$)', strrep(fields(segmentIdx), '_', '\_')), ...
            'Interpreter', 'latex', 'FontSize', scaleText);
        
        axis(axObj, 'tight');
        xlim(axObj, [0 10]);
    end
    
    xlabel(layoutObj, 'Frequency (Hz)', 'Interpreter', 'latex', 'FontSize', scaleText);
    title(layoutObj, 'Log-Density Bivariate Distribution of Identified PSD Peaks', ...
        'Interpreter', 'latex', 'FontSize', scaleText + 2);
    
    colormap(figHandle, "nebula");
    cbHandle = colorbar;
    cbHandle.Layout.Tile = 'east';
    cbHandle.TickLabelInterpreter = 'latex';
    cbHandle.FontSize = scaleText;
    cbHandle.Label.String = 'Identification Density (Log Scale)';
    cbHandle.Label.Interpreter = 'latex';
    cbHandle.Label.FontSize = scaleText;
    
    fileName = ['BridgeSpectralSignatureDistribution' dir 'Direction'];
    saveFig(figHandle,figureFolder,fileName,2)
end

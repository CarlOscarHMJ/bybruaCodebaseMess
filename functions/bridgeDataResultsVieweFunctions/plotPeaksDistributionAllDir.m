function plotPeaksDistributionAllDir(allStats, limits, figureFolder)
    arguments
        allStats
        limits
        figureFolder = ''
    end
    
    scaleText = 10;
    figHandle = createFigure(3, 'Spectral Signature Distribution');
    layoutObj = tiledlayout(2, 6, 'TileSpacing', 'compact', 'Padding', 'tight');
    
    locations = ["Conc", "Steel"];
    locationNames = ["DC", "DS"];
    directions = ["X", "Y", "Z"];
    cableModeNr = [3,6];
    targetFrequencies = limits.targetFreqs;
    freqTolerance = limits.freqTolerance;
    
    zoomSpan = freqTolerance * 3; 

    for locIdx = 1:length(locations)
        loc = locations(locIdx);
        locName = locationNames(locIdx);
        
        for dirIdx = 1:length(directions)
            direction = directions(dirIdx);
            fieldName = sprintf('%s_%s', loc, direction);
            
            peakStructArray = [allStats.psdPeaks];
            if ~isfield(peakStructArray, fieldName)
                continue;
            end
            segmentPeaks = [peakStructArray.(fieldName)];
            
            allPeakFreqs = vertcat(segmentPeaks.locations);
            allPeakSzz = exp(vertcat(segmentPeaks.logIntensity));
            
            validIdx = allPeakSzz > 1e-50;
            allPeakFreqs = allPeakFreqs(validIdx);
            allPeakSzz = allPeakSzz(validIdx);
            
            if isempty(allPeakSzz)
                yMin = 1e-10; yMax = 1;
            else
                yMin = min(allPeakSzz); yMax = max(allPeakSzz);
            end
            yBins = logspace(log10(yMin), log10(yMax), 100);
            
            for fIdx = 1:length(targetFrequencies)
                fTarget = targetFrequencies(fIdx);
                
                tileNum = (locIdx - 1) * 6 + (dirIdx - 1) * 2 + fIdx;
                axObj = nexttile(tileNum);
                hold(axObj, 'on');
                
                dfBin = 0.025;
                xBins = (fTarget - zoomSpan) : dfBin : (fTarget + zoomSpan);

                histogram2(axObj, allPeakFreqs, allPeakSzz, xBins, yBins, ...
                    'DisplayStyle', 'tile', 'ShowEmptyBins', 'off', 'EdgeColor', 'none');
                
                histogram2(axObj, allPeakFreqs, allPeakSzz, xBins, yBins, ...
                    'DisplayStyle', 'tile', 'ShowEmptyBins', 'off', 'EdgeColor', 'none');
                
                set(axObj, 'YScale', 'log', 'ColorScale', 'log', ...
                    'FontSize', scaleText, 'TickLabelInterpreter', 'latex');
                
                xline(axObj, fTarget, '--', 'Color', [0.8 0 0], 'LineWidth', 1.2, ...
                    'Interpreter', 'latex');
                
                patch(axObj, [fTarget - freqTolerance, fTarget + freqTolerance, ...
                              fTarget + freqTolerance, fTarget - freqTolerance], ...
                    [yMin yMin yMax yMax], ...
                    'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                
                grid(axObj, 'on'); box(axObj, 'on');
                xlim(axObj, [fTarget - zoomSpan, fTarget + zoomSpan]);
                ylim(axObj, [yMin yMax]);
                
                if locIdx == 1
                    title(axObj, sprintf('%s-Dir -- $f_{T%d}$', direction, cableModeNr(fIdx)), ...
                        'Interpreter', 'latex', 'FontSize', scaleText);
                end
                
                if dirIdx == 1 && fIdx == 1
                    ylabel(axObj, sprintf('%s', locName), ...
                        'Interpreter', 'latex', 'FontSize', scaleText + 2);
                else
                    yticklabels(axObj, {});
                end
                
                if locIdx == 1
                    xticklabels(axObj, {});
                end
            end
        end
    end
    
    xlabel(layoutObj, 'Frequency (Hz)', 'Interpreter', 'latex', 'FontSize', scaleText);
    ylabel(layoutObj, 'Power Spectral Density $S_{zz}$ ($\mathrm{m^2/s^4/Hz}$)', ...
        'Interpreter', 'latex', 'FontSize', scaleText);
    title(layoutObj, 'Log-Density Bivariate Distribution of Identified PSD Peaks in Vicinity of Target Frequencies', ...
        'Interpreter', 'latex', 'FontSize', scaleText + 2);
    
    colormap(figHandle, "nebula");
    cbHandle = colorbar;
    cbHandle.Layout.Tile = 'east';
    cbHandle.TickLabelInterpreter = 'latex';
    cbHandle.FontSize = scaleText;
    cbHandle.Label.String = 'Identification Density (Log Scale)';
    cbHandle.Label.Interpreter = 'latex';
    cbHandle.Label.FontSize = scaleText;
    
    fileName = 'BridgeSpectralSignatureDistribution_AllDir';
    saveFig(figHandle, figureFolder, fileName, 2);
end

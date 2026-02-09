%% Comparison plot of the different frequency transforms
clc
inspectionDays = {
    '2019-09-16 01:15' '2019-09-16 01:25' 'Day1: Night, Dry, No RWIV Zoom 10min case 1'
    '2019-09-16 03:15' '2019-09-16 03:25' 'Day1: Night, Dry, No RWIV Zoom 10min case 2'
    '2019-06-17 14:00' '2019-06-17 14:10' 'Day2: Day,   Dry, No RWIV Zoom 10min case 1'
    '2019-06-17 15:00' '2019-06-17 15:10' 'Day2: Day,   Dry, No RWIV Zoom 10min case 2'
    '2020-02-22 01:24' '2020-02-22 01:34' 'Day3: Night, Wet, RWIV Zoom 10min Low Vib'
    '2020-02-22 04:00' '2020-02-22 04:10' 'Day3: Night, Wet, RWIV Zoom 10min Large Vib'
    '2020-02-21 13:15' '2020-02-21 13:25' 'Day4: Day,   Wet, RWIV Zoom 10min Large Vib'
    '2020-02-21 12:14' '2020-02-21 12:24' 'Day4: Day,   Wet, RWIV Zoom 10min Low Vib'
};
inspectCases = 1:length(inspectionDays);
load('timeHist.mat')
%% PSD Estimators
Nfft = 2048;
samplingFrequency = 50;
targetColumn = 'Steel_Z'; 
comparisonFrequencies = [3.111 4.149 6.24];

windowDurationSeconds = 60;
overlapPercentage = 50;
windowSamples = windowDurationSeconds * samplingFrequency;
overlapSamples = floor(windowSamples * (overlapPercentage / 100));

burgModelOrder = 50;
yuleWalkerOrder = 50; 
musicSignalDimension = 6;
multiTaperNw = 20;
peakMinProminence = 4;

figureHandle = figure(10); clf;
set(figureHandle, 'Name', 'Response Comparison with Execution Time', 'NumberTitle', 'off', 'Color', 'w');
theme('light')

tiledLayoutHandle = tiledlayout(6, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
methodsList = {'Periodogram', 'Welch', 'Burg', 'Yule-Walker', 'Multitaper', 'MUSIC'};

for methodIdx = 1:6
    mainAxes = nexttile(tiledLayoutHandle);
    hold(mainAxes, 'on');
    
    totalTimeForMethod = 0;
    
    for caseIdx = inspectCases
        currentSignal = timeHist{caseIdx}.(targetColumn);
        caseDescription = inspectionDays{caseIdx, 3};
        lineStyle = ':';
        if ~contains(lower(caseDescription), 'no rwiv'), lineStyle = '--'; end
        
        tic;
        switch methodsList{methodIdx}
            case 'Periodogram'
                [psdEstimate, frequencyAxis] = periodogram(currentSignal, rectwin(length(currentSignal)), Nfft, samplingFrequency);
                actualDuration = length(currentSignal)/samplingFrequency;
                methodSpecificLabel = sprintf('Periodogram (Window: %.1fs)', actualDuration);
            case 'Welch'
                [psdEstimate, frequencyAxis] = pwelch(currentSignal, hanning(windowSamples), overlapSamples, Nfft, samplingFrequency);
                methodSpecificLabel = sprintf('Welch (Win: %ds, Overlap: %d%%)', windowDurationSeconds, overlapPercentage);
            case 'Burg'
                [psdEstimate, frequencyAxis] = pburg(currentSignal, burgModelOrder, Nfft, samplingFrequency);
                methodSpecificLabel = sprintf('Burg (Order: %d)', burgModelOrder);
            case 'Yule-Walker'
                [psdEstimate, frequencyAxis] = pyulear(currentSignal, yuleWalkerOrder, Nfft, samplingFrequency);
                methodSpecificLabel = sprintf('Yule-Walker (Order: %d)', yuleWalkerOrder);
            case 'Multitaper'
                [psdEstimate, frequencyAxis] = pmtm(currentSignal, multiTaperNw, Nfft, samplingFrequency);
                methodSpecificLabel = sprintf('Multitaper (NW: %d)', multiTaperNw);
            case 'MUSIC'
                [psdEstimate, frequencyAxis] = pmusic(currentSignal, musicSignalDimension, Nfft, samplingFrequency);
                methodSpecificLabel = sprintf('MUSIC (Dim: %d)', musicSignalDimension);
        end
        totalTimeForMethod = totalTimeForMethod + toc;
        
        if ~strcmp(methodsList{methodIdx}, 'MUSIC')
            displayData = 10*log10(psdEstimate);
            yLabelText = 'PSD (dB/Hz)';
        else
            displayData = psdEstimate;
            yLabelText = 'Pseudospectrum';
        end
        
        freqRangeIdx = find(0.4 <= frequencyAxis & frequencyAxis <= 15);
        relevantResponse = displayData(freqRangeIdx);
        modalIndices = ampd(relevantResponse) + freqRangeIdx(1) - 1;
        [peaks, locations] = findpeaks(relevantResponse, frequencyAxis(freqRangeIdx), 'MinPeakProminence', peakMinProminence);
        
        if caseIdx == 1
            scatter(mainAxes, frequencyAxis(modalIndices), displayData(modalIndices), 200, '_r', 'DisplayName', 'ampd', 'LineWidth', 2);
            scatter(mainAxes, locations, peaks, 200, '|b', 'DisplayName', 'findpeaks', 'LineWidth', 2);
        else
            scatter(mainAxes, frequencyAxis(modalIndices), displayData(modalIndices), 200, '_r', 'LineWidth', 2, 'HandleVisibility', 'off');
            scatter(mainAxes, locations, peaks, 200, '|b', 'LineWidth', 2, 'HandleVisibility', 'off');
        end

        plot(mainAxes, frequencyAxis, displayData, 'LineStyle', lineStyle, 'DisplayName', caseDescription);
    end
    
    avgTimeMs = (totalTimeForMethod / length(inspectCases)) * 1000;
    fullTitle = sprintf('%s | Nfft: %d | Avg Time: %.2f ms', methodSpecificLabel, Nfft, avgTimeMs);
    
    xline(mainAxes, comparisonFrequencies, '--k', 'Alpha', 0.5, 'HandleVisibility', 'off', 'LineWidth', 1.2);
    ylabel(mainAxes, yLabelText);
    title(mainAxes, fullTitle);
    grid(mainAxes, 'on');
    xlim(mainAxes, [0.5 8]);
    
    if methodIdx == 1, legend(mainAxes, 'Location', 'northwest', 'FontSize', 7); end
    
    insetOne = axes('Parent', figureHandle, 'Units', 'normalized');
    insetOne.Position = [mainAxes.Position(1)+0.14, mainAxes.Position(2)+0.015, 0.08, 0.08];
    copyobj(allchild(mainAxes), insetOne);
    xlim(insetOne, [3.1 3.25]);
    set(insetOne, 'XTick', [], 'YTick', [], 'Box', 'on', 'Color', [0.95 0.95 0.95]);

    insetTwo = axes('Parent', figureHandle, 'Units', 'normalized');
    insetTwo.Position = [mainAxes.Position(1)+0.8, mainAxes.Position(2)+0.015, 0.08, 0.08];
    copyobj(allchild(mainAxes), insetTwo);
    xlim(insetTwo, [6.1 6.5]);
    set(insetTwo, 'XTick', [], 'YTick', [], 'Box', 'on', 'Color', [0.95 0.95 0.95]);
end

xlabel(tiledLayoutHandle, 'Frequency (Hz)');

%% Plot of different AR orders of Burgs method:
samplingFrequency = 50;
targetColumn = 'Conc_Z'; 
targetColumn = 'Steel_Z'; 
comparisonFrequencies = [3.111 4.149 6.24];
peakMinProminence = 4;
arOrders = [20, 40, 50, 60, 80]; 

figureHandle = figure(11); clf;
set(figureHandle, 'Name', 'Burg Order Sensitivity Analysis', 'NumberTitle', 'off', 'Color', 'w');
theme('light')
tiledLayoutHandle = tiledlayout(5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

for orderIdx = 1:length(arOrders)
    currentOrder = arOrders(orderIdx);
    mainAxes = nexttile(tiledLayoutHandle);
    hold(mainAxes, 'on');
    
    for caseIdx = inspectCases
        currentSignal = timeHist{caseIdx}.(targetColumn);
        caseDescription = inspectionDays{caseIdx, 3};
        lineStyle = ':';
        if ~contains(lower(caseDescription), 'no rwiv'), lineStyle = '--'; end
        
        [psdEstimate, frequencyAxis] = pburg(currentSignal, currentOrder, Nfft, samplingFrequency);
        displayData = 10*log10(psdEstimate);
        
        freqRangeIdx = find(0.4 <= frequencyAxis & frequencyAxis <= 15);
        relevantResponse = displayData(freqRangeIdx);
        modalIndices = ampd(relevantResponse) + freqRangeIdx(1) - 1;
        [peaks, locations] = findpeaks(relevantResponse, frequencyAxis(freqRangeIdx), 'MinPeakProminence', peakMinProminence);
        
        if caseIdx == 1
            scatter(mainAxes, frequencyAxis(modalIndices), displayData(modalIndices), 200, '_r', 'DisplayName', 'ampd', 'LineWidth', 2);
            scatter(mainAxes, locations, peaks, 200, '|b', 'DisplayName', 'findpeaks', 'LineWidth', 2);
        else
            scatter(mainAxes, frequencyAxis(modalIndices), displayData(modalIndices), 200, '_r', 'LineWidth', 2, 'HandleVisibility', 'off');
            scatter(mainAxes, locations, peaks, 200, '|b', 'LineWidth', 2, 'HandleVisibility', 'off');
        end
        
        plot(mainAxes, frequencyAxis, displayData, 'LineStyle', lineStyle, 'DisplayName', caseDescription);
    end
    
    xline(mainAxes, comparisonFrequencies, '--k', 'Alpha', 0.5, 'HandleVisibility', 'off', 'LineWidth', 1.2);
    ylabel(mainAxes, 'PSD (dB/Hz)');
    title(mainAxes, sprintf('Burg Method: AR Order = %d (Nfft: %d)', currentOrder, Nfft));
    grid(mainAxes, 'on');
    xlim(mainAxes, [0.5 8]);
    
    if orderIdx == 1, legend(mainAxes, 'Location', 'northwest', 'FontSize', 7); end
    
    insetOne = axes('Parent', figureHandle, 'Units', 'normalized');
    insetOne.Position = [mainAxes.Position(1)+0.14, mainAxes.Position(2)+0.02, 0.1, 0.14];
    copyobj(allchild(mainAxes), insetOne);
    xlim(insetOne, [3.1 3.25]);
    set(insetOne, 'XTick', [], 'YTick', [], 'Box', 'on', 'Color', [0.95 0.95 0.95]);
    title(insetOne, '1st Mode Zoom', 'FontSize', 8);
    
    insetTwo = axes('Parent', figureHandle, 'Units', 'normalized');
    insetTwo.Position = [mainAxes.Position(1)+0.8, mainAxes.Position(2)+0.02, 0.1, 0.14];
    copyobj(allchild(mainAxes), insetTwo);
    xlim(insetTwo, [6.1 6.5]);
    set(insetTwo, 'XTick', [], 'YTick', [], 'Box', 'on', 'Color', [0.95 0.95 0.95]);
    title(insetTwo, '3rd Mode Zoom', 'FontSize', 8);
end

xlabel(tiledLayoutHandle, 'Frequency (Hz)');

%% Coherence plots
samplingFrequency = 50;
comparisonFrequencies = [3.111 4.149 6.24];
windowDurationSeconds = 30;
overlapPercentage = 50;
windowSamples = windowDurationSeconds * samplingFrequency;
overlapSamples = floor(windowSamples * (overlapPercentage / 100));
multiTaperNw = 4;
peakMinProminence = 0.8;

figureHandle = figure(12); clf;
set(figureHandle, 'Name', 'Co-Coherence: Steel_Z vs Conc_Z', 'NumberTitle', 'off', 'Color', 'w');
theme('light')
tiledLayoutHandle = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
methodsList = {'Direct', 'Welch', 'Multitaper'};

for methodIdx = 1:3
    mainAxes = nexttile(tiledLayoutHandle);
    hold(mainAxes, 'on');
    
    for caseIdx = inspectCases
        sigSteel = timeHist{caseIdx}.Steel_Z;
        sigConc = timeHist{caseIdx}.Conc_Z;
        caseDescription = inspectionDays{caseIdx, 3};
        lineStyle = ':';
        if ~contains(lower(caseDescription), 'no rwiv'), lineStyle = '--'; end
        
        switch methodsList{methodIdx}
            case 'Direct'
                [pxy, f] = cpsd(sigSteel, sigConc, rectwin(length(sigSteel)), 0, Nfft, samplingFrequency);
                pxx = periodogram(sigSteel, rectwin(length(sigSteel)), Nfft, samplingFrequency);
                pyy = periodogram(sigConc, rectwin(length(sigConc)), Nfft, samplingFrequency);
                plotTitle = sprintf('Direct Co-Coherence (Rectwin, Nfft: %d)', Nfft);
            case 'Welch'
                [pxy, f] = cpsd(sigSteel, sigConc, hanning(windowSamples), overlapSamples, Nfft, samplingFrequency);
                pxx = pwelch(sigSteel, hanning(windowSamples), overlapSamples, Nfft, samplingFrequency);
                pyy = pwelch(sigConc, hanning(windowSamples), overlapSamples, Nfft, samplingFrequency);
                plotTitle = sprintf('Welch Co-Coherence (Win: %ds, Overlap: %d%%, Nfft: %d)', windowDurationSeconds, overlapPercentage, Nfft);
            case 'Multitaper'
                tapers = dpss(length(sigSteel), multiTaperNw);
                numTapers = size(tapers, 2);
                pxyAccum = 0; pxxAccum = 0; pyyAccum = 0;
                for k = 1:numTapers
                    [tk_pxy, f] = cpsd(sigSteel, sigConc, tapers(:,k), 0, Nfft, samplingFrequency);
                    [tk_pxx, ~] = periodogram(sigSteel, tapers(:,k), Nfft, samplingFrequency);
                    [tk_pyy, ~] = periodogram(sigConc, tapers(:,k), Nfft, samplingFrequency);
                    pxyAccum = pxyAccum + tk_pxy;
                    pxxAccum = pxxAccum + tk_pxx;
                    pyyAccum = pyyAccum + tk_pyy;
                end
                pxy = pxyAccum / numTapers;
                pxx = pxxAccum / numTapers;
                pyy = pyyAccum / numTapers;
                plotTitle = sprintf('Multitaper Co-Coherence (NW: %d, Nfft: %d)', multiTaperNw, Nfft);
        end
        
        coCoherence = real(pxy ./ sqrt(pxx .* pyy));
        
        freqRangeIdx = find(0.4 <= f & f <= 15);
        relevantResponse = coCoherence(freqRangeIdx);
        absoluteResponse = abs(relevantResponse);
        
        ampdLocalIdx = ampd(absoluteResponse);
        modalIndices = freqRangeIdx(ampdLocalIdx);
        
        [~, findPeaksLocalIdx] = findpeaks(absoluteResponse, 'MinPeakProminence', peakMinProminence);
        findPeaksIndices = freqRangeIdx(findPeaksLocalIdx);
        
        if caseIdx == 1
            scatter(mainAxes, f(modalIndices), coCoherence(modalIndices), 150, '_r', 'DisplayName', 'ampd', 'LineWidth', 2);
            scatter(mainAxes, f(findPeaksIndices), coCoherence(findPeaksIndices), 150, '|b', 'DisplayName', 'findpeaks', 'LineWidth', 2);
        else
            scatter(mainAxes, f(modalIndices), coCoherence(modalIndices), 150, '_r', 'LineWidth', 2, 'HandleVisibility', 'off');
            scatter(mainAxes, f(findPeaksIndices), coCoherence(findPeaksIndices), 150, '|b', 'LineWidth', 2, 'HandleVisibility', 'off');
        end

        plot(mainAxes, f, coCoherence, 'LineStyle', lineStyle, 'DisplayName', caseDescription);
    end
    
    xline(mainAxes, comparisonFrequencies, '--k', 'Alpha', 0.5, 'HandleVisibility', 'off', 'LineWidth', 1.2);
    yline(mainAxes, 0, 'k', 'Alpha', 0.3, 'HandleVisibility', 'off');
    ylabel(mainAxes, 'Co-Coherence (Real)');
    title(mainAxes, plotTitle);
    grid(mainAxes, 'on');
    xlim(mainAxes, [0.5 8]);
    ylim(mainAxes, [-1.1 1.1]);
    
    if methodIdx == 1, legend(mainAxes, 'Location', 'northwest', 'FontSize', 7); end
end
xlabel(tiledLayoutHandle, 'Frequency (Hz)');
%% Time history
noRwivIdx = [];
rwivIdx = [];

for i = inspectCases
    caseDesc = lower(inspectionDays{i,3});
    if contains(caseDesc, 'no rwiv')
        noRwivIdx = [noRwivIdx; i];
    else
        rwivIdx = [rwivIdx; i];
    end
end

numRows = max(length(noRwivIdx), length(rwivIdx));
figureHandle = figure(13); clf;
set(figureHandle, 'Name', 'Time History Comparison', 'Color', 'w');
tiledLayoutHandle = tiledlayout(numRows, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axesList = []; 

for row = 1:numRows
    for col = 1:2
        mainAxes = nexttile;
        hold on;
        
        if col == 1
            if row <= length(noRwivIdx)
                currentCase = noRwivIdx(row);
                plotColor = [0 0.447 0.741]; 
            else
                axis off; continue;
            end
        else
            if row <= length(rwivIdx)
                currentCase = rwivIdx(row);
                plotColor = [0.85 0.325 0.098];
            else
                axis off; continue;
            end
        end
        
        axesList = [axesList, mainAxes]; 
        
        currentSignal = timeHist{currentCase}.(targetColumn);
        timeAxis = (0:length(currentSignal)-1) / samplingFrequency;
        
        plot(mainAxes, timeAxis, currentSignal, 'Color', plotColor);
        
        grid on;
        plotTitle = [inspectionDays{i,3} '-' inspectionDays{i,1} '-' inspectionDays{i,2}(end-4:end)];
        title(plotTitle, 'FontSize', 8);
        ylabel('Acc. [m/s^2]');
        if row == numRows, xlabel('Time [s]'); end
    end
end

linkaxes(axesList, 'y');
title(tiledLayoutHandle, ['Acceleration Time Histories (Shared Y-Axis): ', targetColumn]);

clear all;clc
addpath('functions');

dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';

inspectionDays = {
    '2019-09-16 01:00' '2019-09-16 02:00' 'Day1: Night, Dry, No RWIV'
    '2019-06-17 12:00' '2019-06-17 18:00' 'Day2: Day,   Dry, No RWIV'
    '2020-02-22 00:00' '2020-02-22 06:00' 'Day3: Night, Wet, RWIV'
    '2020-02-21 10:00' '2020-02-21 14:00' 'Day4: Day,   Wet, RWIV'
    '2020-02-21 13:15' '2020-02-21 13:25' 'Day4: Day,   Wet, RWIV Zoom 13151325'
    '2020-02-21 13:00' '2020-02-21 13:30' 'Day4: Day,   Wet, RWIV Zoom 13001330'
    '2020-02-21 00:00' '2020-02-21 23:59' 'Day4: Day,   Wet, RWIV ZoomOutFullDay'
    '2020-02-21 00:00' '2020-02-22 23:59' 'Day4: Day,   Wet, RWIV ZoomOutNidArt'
    '2019-09-16 00:00' '2019-09-16 06:00' 'Day1: Night, Dry, No RWIV ZoomOut'
    '2019-08-26 02:00' '2019-08-26 03:00' 'Day5: DecayTests'
    '2019-09-14 19:00' '2019-09-14 21:00' 'Day5: Day,   Wet, RWIV'
    '2020-02-29 00:00' '2020-02-29 21:00' 'Analysis of ~4Hz peak almost full day'
};
N = size(inspectionDays,1);

inspectCases = [8];
Nfft = 2^11;
for i = inspectCases
    startTime = inspectionDays{i,1};
    endTime   = inspectionDays{i,2};
    
    byBroa = BridgeProject(dataRoot, startTime, endTime);
    
    if i == 1 % filling in nan values with 0 for C1E in the first case
        byBroa.cableData.C1E_x(isnan(byBroa.cableData.C1E_x)) = 0;
        byBroa.cableData.C1E_y(isnan(byBroa.cableData.C1E_y)) = 0;
        byBroa.cableData.C1E_z(isnan(byBroa.cableData.C1E_z)) = 0;
    end
    
    byBroaOverview = BridgeOverview(byBroa);
    
    byBroaOverview = byBroaOverview.fillMissingDataPoints;
    byBroaOverview = byBroaOverview.designFilter('butter', order=7, fLow=0.4, fHigh=15);
    byBroaOverview = byBroaOverview.applyFilter;
    
    %Initial overview plots
    % byBroaOverview.plotEventValidation();
    % byBroaOverview.plotTimeHistory('acceleration',[],'Vertical');
    % byBroaOverview.plotFrequencyResponse([], 'welch', bridgeDirs="Z", cableDirs="y", fMax=20);
    if i == 1
        timeWindow = [datetime('2019-09-16 01:00','InputFormat','yyyy-MM-dd HH:mm')
                      datetime('2019-09-16 01:30','InputFormat','yyyy-MM-dd HH:mm')];
    elseif i == 3
                timeWindow = [datetime('2020-02-22 04:00','InputFormat','yyyy-MM-dd HH:mm')
                              datetime('2020-02-22 04:28','InputFormat','yyyy-MM-dd HH:mm')];
    else
        timeWindow = [];
    end
    plotTitle = [inspectionDays{i,3} '-' inspectionDays{i,1} '-' inspectionDays{i,2}(end-4:end)];
    
    cables = ["C1E_y" "C1W_y"];
    for cable = cables
        charCable = char(cable);
        try
            freqInfo{i} = byBroaOverview.plotRwivDiagnostic(cable,[],plotTitle=plotTitle,Nfft=Nfft);
            drawnow
            exportgraphics(gcf,['figures/RwivDiagnostics/RwivDiagnostics' strrm(charCable,'_') strrm(inspectionDays{i,3},[" ",":",","]) '.png'],'Resolution',300)
        catch ME
             warning('Error processing cable %s: %s', charCable, ME.message);
        end
    end
end
%% Frequency picker
interrestingCases = [1:4 11];
zoomPoints = [3.111 4.149 6.24];
zoomSpan = 0.3;
fig = figure(2); clf;
set(fig, 'Name', 'Frequency Picker', 'NumberTitle', 'off');
theme(fig,'light')
tl = tiledlayout(2, 3, 'TileSpacing', 'compact','Padding','compact');

mainAx = nexttile(tl, [1, 3]); 
hold on;

xlines = [3.111 4.149 6.24];
xline(xlines,'--k','HandleVisibility','off','LineWidth',2)
c = 0;
for i = interrestingCases
    if i > 10
        continue
    end
    fields = fieldnames(freqInfo{i}.freqResp);
    %fields = fields(2);
    for j = 1:length(fields)
        c = c +1;
        accelerometor = fields{j};
        freq = freqInfo{i}.freqResp.(accelerometor).frequency;
        resp = log(freqInfo{i}.freqResp.(accelerometor).response);

        indx = find(0.4 <= freq & freq <= 15);
        modalPeakIndices{1} = ampd(resp(indx))+indx(1)-1;
        [~,modalPeakIndices{2}] = findpeaks(resp,'MinPeakProminence',2);
        modalPeakIndices{3} = autonomousPeakPicking(resp(indx))+indx(1)-1;
        
        colors = ["_r","|b"];
        names = ["ampd","findpeaks MinPeakProminence=4"];
        for k = 1:length(modalPeakIndices)-1
            if c == 1
                scatter(freq(modalPeakIndices{k}),resp(modalPeakIndices{k}),...
                    200,colors(k),'DisplayName',names(k),'LineWidth',4)
            else
                scatter(freq(modalPeakIndices{k}),resp(modalPeakIndices{k}),...
                    200,colors(k),'HandleVisibility', 'off','LineWidth',4);
            end
        end
        if contains(inspectionDays{i,3},'no rwiv','IgnoreCase',true)
            linestyle = ':';
        else
            linestyle = '--';
        end
        semilogy(freq,resp,...
            'LineStyle',linestyle,...
            'DisplayName',[inspectionDays{i,3} ' Resp: ' accelerometor],...
            'LineWidth',1.2);
        

    end
end
axis tight
box on
xlim([0.4,8])
%set(gca,'YScale','log')
legend('Location','southeastoutside')

allChildren = findall(mainAx, 'Serializable', 'on');
objectsToCopy = allChildren(allChildren ~= mainAx);
for cp = zoomPoints
    subAx = nexttile(tl);
    hold(subAx, 'on');
    
    copyobj(objectsToCopy, subAx);
    set(subAx, 'YScale', mainAx.YScale);
    
    xlim(subAx, [cp - zoomSpan, cp + zoomSpan]);
    box(subAx, 'on');
    title(subAx, sprintf('Mode at %.2f Hz', cp));
end
xlabel(tl, 'Frequency (Hz)', 'FontSize', 12,'interpreter','latex');
ylabel(tl, '$\log$ Power Spectral Density ($\log((m/s^2)^2/Hz)$)', 'FontSize', 12, 'Interpreter', 'latex');
title(tl, 'Examples of succsesfulness in peak picking', 'FontSize', 14,'interpreter','latex');
%% Time dependency
return
titles = ["10-min","Half Hour","4 Hour" "Full Day" "2 Days"];
order = [5 6 4 7 8];
xlines = [3.14 4.30 6.30];
figure
theme('light')
tiledlayout(2,1)
k=0;
for j = order
    k = k+1;
    nexttile(1)
    f = freqInfo{j}.freqResp.Conc_Z.frequency;
    R = freqInfo{j}.freqResp.Conc_Z.response;
    semilogy(f,R,'DisplayName',titles(k))
    ylabel('Response Magnitude')
    xlabel('Frequency (Hz)')
    legend show
    grid on
    hold on
    xlim([0 10])
    
    nexttile(2)
    f = freqInfo{j}.coCoherence.Conc_Z.frequency;
    g = freqInfo{j}.coCoherence.Conc_Z.gamma;
    plot(f,g,'DisplayName',titles(k))
    grid on
    ylabel('co-coherence')
    xlabel('frequency (Hz')
    hold on
    legend show
    xlim([0 10])
end
nexttile(1)
xline(xlines,'--k','HandleVisibility','off','LineWidth',2)
nexttile(2)
xline(xlines,'--k','HandleVisibility','off','LineWidth',2)
title('C1W, Day4 different zoom levels')
exportgraphics(gcf,'figures/RwivDiagnostics/Day4Zoom.png','resolution',300)
%% Playing with Nfft
Nfft = 2.^(6:12);
consideredCases = [1,2,3,4];
fprintf('Nffts considered are: %s\n',sprintf('%d ',Nfft))

for i = consideredCases
    startTime = inspectionDays{i,1};
    endTime   = inspectionDays{i,2};
    
    byBroa = BridgeProject(dataRoot, startTime, endTime);
    
    if i == 1 % filling in nan values with 0 for C1E in the first case
        byBroa.cableData.C1E_x(isnan(byBroa.cableData.C1E_x)) = 0;
        byBroa.cableData.C1E_y(isnan(byBroa.cableData.C1E_y)) = 0;
        byBroa.cableData.C1E_z(isnan(byBroa.cableData.C1E_z)) = 0;
    end
    
    byBroaOverview = BridgeOverview(byBroa);
    
    byBroaOverview = byBroaOverview.fillMissingDataPoints;
    byBroaOverview = byBroaOverview.designFilter('butter', order=7, fLow=0.4, fHigh=15);
    byBroaOverview = byBroaOverview.applyFilter;

    for j = 1:length(Nfft)
        plotTitle = ['NFFT=' num2str(Nfft(j)) '-' inspectionDays{i,3} '-' inspectionDays{i,1} '-' inspectionDays{i,2}(end-4:end)];
        NfftInfo{i,j} = byBroaOverview.plotRwivDiagnostic("C1W_y",[],plotTitle=plotTitle,Nfft=Nfft(j));
        drawnow
    end
end
nCases = length(consideredCases);
nNfft = length(Nfft);
fig = figure(3); clf;
set(fig, 'Name', 'Frequency Picker', 'NumberTitle', 'off');
theme(fig,'light')
tl = tiledlayout(nCases,1, 'TileSpacing', 'compact','Padding','compact');

for i = 1:nCases
    nexttile(i)
    xlines = [3.111 4.149 6.24];
    xline(xlines,'--k','HandleVisibility','off','LineWidth',2)
    hold on

    if contains(inspectionDays{i,3},'no rwiv','IgnoreCase',true)
        linestyle = ':';
    else
        linestyle = '--';
    end

    for j = 1:nNfft
        f = NfftInfo{i,j}.freqResp.Conc_Z.frequency;
        r = NfftInfo{i,j}.freqResp.Conc_Z.response;
        
        plot(f,log(r),'DisplayName',['Nffts = ' num2str(Nfft(j))])
    end
    xlim([0.4,8])
end

legend

%% Looking into different transforms
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
N = size(inspectionDays,1);

inspectCases = [1:length(inspectionDays)];
Nfft = 2^11;
for i = inspectCases
    startTime = inspectionDays{i,1};
    endTime   = inspectionDays{i,2};
    
    byBroa = BridgeProject(dataRoot, startTime, endTime);
    
    % if i == 1 % filling in nan values with 0 for C1E in the first case
    %     byBroa.cableData.C1E_x(isnan(byBroa.cableData.C1E_x)) = 0;
    %     byBroa.cableData.C1E_y(isnan(byBroa.cableData.C1E_y)) = 0;
    %     byBroa.cableData.C1E_z(isnan(byBroa.cableData.C1E_z)) = 0;
    % end
    
    byBroaOverview = BridgeOverview(byBroa);
    
    byBroaOverview = byBroaOverview.fillMissingDataPoints;
    byBroaOverview = byBroaOverview.designFilter('butter', order=7, fLow=0.4, fHigh=15);
    byBroaOverview = byBroaOverview.applyFilter;
    plotTitle = [inspectionDays{i,3} '-' inspectionDays{i,1} '-' inspectionDays{i,2}(end-4:end)];
    
    % byBroaOverview.plotRwivDiagnostic('C1W_y',[],Nfft=Nfft,plotTitle=plotTitle);
    % drawnow
    % keyboard
    timeHist{i} = byBroaOverview.project.bridgeData;
end
save('figures/selectionOfFreqFunction/timeHist.mat',"timeHist")
%% Comparison plot of the different frequency transforms
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
load('figures/selectionOfFreqFunction/timeHist.mat')

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
%% Article figures: Plot Spectral Signatures of RWIV and Non-RWIV Cases
clear all;clc
load('figures/selectionOfFreqFunction/timeHist.mat');
inspectionDays = {
    '2020-02-22 01:24' '2020-02-22 01:34' 'Day3: Night, Wet, RWIV Zoom 10min Low Vib'
    '2020-02-22 04:00' '2020-02-22 04:10' 'Day3: Night, Wet, RWIV Zoom 10min Large Vib'
    '2020-02-21 13:15' '2020-02-21 13:25' 'Day4: Day,   Wet, RWIV Zoom 10min Large Vib'
    '2020-02-21 12:14' '2020-02-21 12:24' 'Day4: Day,   Wet, RWIV Zoom 10min Low Vib'
    '2019-09-16 01:15' '2019-09-16 01:25' 'Day1: Night, Dry, No RWIV Zoom 10min case 1'
    '2019-09-16 03:15' '2019-09-16 03:25' 'Day1: Night, Dry, No RWIV Zoom 10min case 2'
    '2019-06-17 14:00' '2019-06-17 14:10' 'Day2: Day,   Dry, No RWIV Zoom 10min case 1'
    '2019-06-17 15:00' '2019-06-17 15:10' 'Day2: Day,   Dry, No RWIV Zoom 10min case 2'
};

inspectionDays(:,3) = sprintfc('Case %d$\\;$', 1:8)';

samplingFrequency = 50;
fftPoints = 2^11;
burgOrder = 50;
windowSeconds = 30;
overlapFactor = 0.5;

comparisonFrequencies = [3.111, 4.149, 6.24];
comparisonFrequencies = [3.111, 6.24];
fTargets              = [3.174, 6.32]; % Found centers of deck peaks at RWIV
freqTolerance       = 0.15;
targetCoherenceFreq = [3.22, 6.37];  % Found centers of co-coherence peaks at RWIV
coherenceLimit      = [-0.6,0.7];

windowSamples = windowSeconds * samplingFrequency;
overlapSamples = floor(windowSamples * overlapFactor);

targetDeckSteel = 'Steel_Z';
targetDeckConc = 'Conc_Z';
lineWidth = 1.5;

figureHandle = createFigure(100,'Stavanger Bridge: PSD and Co-Coherence Analysis');
% mainLayout = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
% 
% % --- Power Spectral Density (Burg's Method) ---
% psdAxes = nexttile(mainLayout);
% for caseIdx = 1:length(timeHist)
%     currentSignal = timeHist{caseIdx}.(targetDeckSteel);
%     caseName = inspectionDays{caseIdx, 3};
%     lineStyle = getLineStyle(caseName);
% 
%     [psdEstimate, frequencyAxis] = pburg(currentSignal, burgOrder, fftPoints, samplingFrequency);
%     semilogy(psdAxes, frequencyAxis, psdEstimate, 'LineStyle', lineStyle, 'DisplayName', caseName);
%     hold(psdAxes, 'on');
% end
% finalizeAxes(psdAxes, comparisonFrequencies, '$S_{DS,Z}\,\mathrm{(m^2\,Hz^{-1})}$');
% 
% allPeakSzz = psdAxes.get("YLim");
% for fTarget = fTargets
%     xline(fTarget,'r:','linewidth',2)
%     p = patch(psdAxes, [fTarget - freqTolerance, fTarget + freqTolerance, ...
%                               fTarget + freqTolerance, fTarget - freqTolerance], ...
%                     [min(allPeakSzz) min(allPeakSzz) max(allPeakSzz) max(allPeakSzz)], ...
%                     'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
%     uistack(p, 'bottom');
% end
% ylim(psdAxes,allPeakSzz)
% 
% psdAxes = nexttile(mainLayout);
% for caseIdx = 1:length(timeHist)
%     currentSignal = timeHist{caseIdx}.(targetDeckConc);
%     caseName = inspectionDays{caseIdx, 3};
%     lineStyle = getLineStyle(caseName);
% 
%     [psdEstimate, frequencyAxis] = pburg(currentSignal, burgOrder, fftPoints, samplingFrequency);
%     semilogy(psdAxes, frequencyAxis, psdEstimate, 'LineStyle', lineStyle, 'DisplayName', caseName);
%     hold(psdAxes, 'on');
% end
% 
% finalizeAxes(psdAxes, comparisonFrequencies, '$S_{DC,Z}\,\mathrm{(m^2\,Hz^{-1})}$');
% allPeakSzz = psdAxes.get("YLim");
% for fTarget = fTargets
%     xline(fTarget,'r:','linewidth',2,'HandleVisibility','off')
%     p = patch(psdAxes, [fTarget - freqTolerance, fTarget + freqTolerance, ...
%                               fTarget + freqTolerance, fTarget - freqTolerance], ...
%                     [min(allPeakSzz) min(allPeakSzz) max(allPeakSzz) max(allPeakSzz)], ...
%                     'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
%     uistack(p, 'bottom');
% end
% ylim(psdAxes,allPeakSzz)
% lgd = legend(psdAxes, 'FontSize', 7, 'NumColumns', 8);
% lgd.Layout.Tile = 'north';

% --- Co-Coherence (Welch Method) ---
% cohMagneAxes = nexttile(mainLayout);
% cohAngleAxes = nexttile(mainLayout);
% 
% for caseIdx = 1:length(timeHist)
%     signalA = timeHist{caseIdx}.(targetDeckSteel);
%     signalB = timeHist{caseIdx}.(targetDeckConc);
%     caseName = inspectionDays{caseIdx, 3};
%     lineStyle = getLineStyle(caseName);
% 
%     [crossPsd, frequencyAxis] = cpsd(signalA, signalB, hanning(windowSamples), overlapSamples, fftPoints, samplingFrequency);
%     psdA = pwelch(signalA, hanning(windowSamples), overlapSamples, fftPoints, samplingFrequency);
%     psdB = pwelch(signalB, hanning(windowSamples), overlapSamples, fftPoints, samplingFrequency);
% 
%     Coherence = crossPsd ./ sqrt(psdA .* psdB);
%     cohMagnitude = abs(Coherence);
%     cohAngle = angle(Coherence)./pi*180;
% 
%     plot(cohMagneAxes, frequencyAxis, cohMagnitude, 'LineStyle', lineStyle, 'HandleVisibility', 'off');
%     hold(cohMagneAxes,'on')
%     plot(cohAngleAxes, frequencyAxis, cohAngle, 'LineStyle', lineStyle, 'HandleVisibility', 'off');
%     hold(cohAngleAxes,'on')
% end
% 
% finalizeAxes(cohMagneAxes, comparisonFrequencies, '$|\gamma_\mathrm{DC_Z,DS_Z}|\,(-)$');
% finalizeAxes(cohAngleAxes, comparisonFrequencies, '$\arg(\gamma_\mathrm{DC_Z,DS_Z})\,(\,^\circ\,)$');
% yline(cohAngleAxes, 0, 'k', 'Alpha', 0.3, 'HandleVisibility', 'off');
% ylim(cohAngleAxes, [-180 180]);
% yticks(cohAngleAxes,[-180 -90 0 90 180])
% ylim(cohMagneAxes, [0 1]);
% xlabel(mainLayout, 'Frequency (Hz)','interpreter','latex');
% xline(cohMagneAxes,targetCoherenceFreq,'r:','linewidth',2)
% xline(cohAngleAxes,targetCoherenceFreq,'r:','linewidth',2)

% Insert Start %%%%%
xAxisZoomWidth = 0.35;
mainLayout = tiledlayout(20, 42, 'TileSpacing', 'none', 'Padding', 'compact');

steelPowerSpectralDensityAxis = nexttile(mainLayout, 1, [9 19]);
for caseIndex = 1:length(timeHist)
    currentSignal = timeHist{caseIndex}.(targetDeckSteel);
    caseName = inspectionDays{caseIndex, 3};
    [plotLineStyle,lineWidth] = getLineStyle(caseName);
    
    [powerSpectralDensityEstimate, frequencyAxis] = pburg(currentSignal, burgOrder, fftPoints, samplingFrequency);
    semilogy(steelPowerSpectralDensityAxis, frequencyAxis, powerSpectralDensityEstimate, 'LineStyle', plotLineStyle, 'LineWidth', lineWidth, 'DisplayName', caseName);
    hold(steelPowerSpectralDensityAxis, 'on');
end

finalizeAxes(steelPowerSpectralDensityAxis, comparisonFrequencies, '$S_{DS,Z}\,\mathrm{(m^2\,s^{-4}\,Hz^{-1})}$');
xlim(steelPowerSpectralDensityAxis, [2.8 6.7]);
box(steelPowerSpectralDensityAxis, 'on');
%yAxisLimits = steelPowerSpectralDensityAxis.get("YLim");
yAxisLimits = [10^(-12),10^(-3)];

for targetFreq = fTargets
    xline(steelPowerSpectralDensityAxis, targetFreq, 'r:', 'linewidth', 2)
    patchPolygon = patch(steelPowerSpectralDensityAxis, ...
        [targetFreq - freqTolerance, targetFreq + freqTolerance, targetFreq + freqTolerance, targetFreq - freqTolerance], ...
        [min(yAxisLimits) min(yAxisLimits) max(yAxisLimits) max(yAxisLimits)], ...
        'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    uistack(patchPolygon, 'bottom');
end
ylim(steelPowerSpectralDensityAxis, yAxisLimits)
yAxisTicks = steelPowerSpectralDensityAxis.get('YTick');
yAxisTickLabels = steelPowerSpectralDensityAxis.get("YTickLabel");

concretePowerSpectralDensityAxis = nexttile(mainLayout, 24, [9 19]);
for caseIndex = 1:length(timeHist)
    currentSignal = timeHist{caseIndex}.(targetDeckConc);
    caseName = inspectionDays{caseIndex, 3};
    [plotLineStyle,lineWidth] = getLineStyle(caseName);
    
    [powerSpectralDensityEstimate, frequencyAxis] = pburg(currentSignal, burgOrder, fftPoints, samplingFrequency);
    semilogy(concretePowerSpectralDensityAxis, frequencyAxis, powerSpectralDensityEstimate, 'LineStyle', plotLineStyle, 'LineWidth', lineWidth, 'DisplayName', caseName);
    hold(concretePowerSpectralDensityAxis, 'on');
end

finalizeAxes(concretePowerSpectralDensityAxis, comparisonFrequencies, '$S_{DC,Z}\,\mathrm{(m^2\,s^{-4}\,Hz^{-1})}$');
xlim(concretePowerSpectralDensityAxis, [2.8 6.7]);
box(concretePowerSpectralDensityAxis, 'on');
%yAxisLimits = concretePowerSpectralDensityAxis.get("YLim");

for targetFreq = fTargets
    xline(concretePowerSpectralDensityAxis, targetFreq, 'r:', 'linewidth', 2, 'HandleVisibility', 'off')
    patchPolygon = patch(concretePowerSpectralDensityAxis, ...
        [targetFreq - freqTolerance, targetFreq + freqTolerance, targetFreq + freqTolerance, targetFreq - freqTolerance], ...
        [min(yAxisLimits) min(yAxisLimits) max(yAxisLimits) max(yAxisLimits)], ...
        'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    uistack(patchPolygon, 'bottom');
end
ylim(concretePowerSpectralDensityAxis, yAxisLimits)

figureLegend = legend(concretePowerSpectralDensityAxis, 'FontSize', 7, 'NumColumns', 8);
figureLegend.Layout.Tile = 'north';

% --- Initialize Bottom Row (Including Gap Axes) ---
coherenceMagnitudeLowFreqAxis = nexttile(mainLayout, 463, [9 9]);
hold(coherenceMagnitudeLowFreqAxis, 'on');

coherenceMagnitudeGapAxis = nexttile(mainLayout, 472, [9 1]);

coherenceMagnitudeHighFreqAxis = nexttile(mainLayout, 473, [9 9]);
hold(coherenceMagnitudeHighFreqAxis, 'on');

coherencePhaseLowFreqAxis = nexttile(mainLayout, 486, [9 9]);
hold(coherencePhaseLowFreqAxis, 'on');

coherencePhaseGapAxis = nexttile(mainLayout, 495, [9 1]);

coherencePhaseHighFreqAxis = nexttile(mainLayout, 496, [9 9]);
hold(coherencePhaseHighFreqAxis, 'on');

for caseIndex = 1:length(timeHist)
    steelDeckSignal = timeHist{caseIndex}.(targetDeckSteel);
    concreteDeckSignal = timeHist{caseIndex}.(targetDeckConc);
    inspectionCaseName = inspectionDays{caseIndex, 3};
    [plotLineStyle,lineWidth] = getLineStyle(inspectionCaseName);
    
    [crossPowerSpectralDensity, frequencyAxis] = cpsd(steelDeckSignal, concreteDeckSignal, hanning(windowSamples), overlapSamples, fftPoints, samplingFrequency);
    steelDeckPowerSpectralDensity = pwelch(steelDeckSignal, hanning(windowSamples), overlapSamples, fftPoints, samplingFrequency);
    concreteDeckPowerSpectralDensity = pwelch(concreteDeckSignal, hanning(windowSamples), overlapSamples, fftPoints, samplingFrequency);
    
    complexCoherence = crossPowerSpectralDensity ./ sqrt(steelDeckPowerSpectralDensity .* concreteDeckPowerSpectralDensity);
    coherenceMagnitude = abs(complexCoherence);
    coherencePhaseAngle = angle(complexCoherence) ./ pi * 180;
    
    plot(coherenceMagnitudeLowFreqAxis, frequencyAxis, coherenceMagnitude, 'LineStyle', plotLineStyle, 'LineWidth', lineWidth, 'HandleVisibility', 'off');
    plot(coherenceMagnitudeHighFreqAxis, frequencyAxis, coherenceMagnitude, 'LineStyle', plotLineStyle, 'LineWidth', lineWidth, 'HandleVisibility', 'off');
    
    plot(coherencePhaseLowFreqAxis, frequencyAxis, coherencePhaseAngle, 'LineStyle', plotLineStyle, 'LineWidth', lineWidth, 'HandleVisibility', 'off');
    plot(coherencePhaseHighFreqAxis, frequencyAxis, coherencePhaseAngle, 'LineStyle', plotLineStyle, 'LineWidth', lineWidth, 'HandleVisibility', 'off');
end

finalizeAxes(coherenceMagnitudeLowFreqAxis, comparisonFrequencies(1), '$|\gamma_\mathrm{DC_Z,DS_Z}|\,(-)$');
xlim(coherenceMagnitudeLowFreqAxis, [targetCoherenceFreq(1) - xAxisZoomWidth, targetCoherenceFreq(1) + xAxisZoomWidth]);
ylim(coherenceMagnitudeLowFreqAxis, [0 1]);
yticks(coherenceMagnitudeLowFreqAxis, 0:0.2:1);
box(coherenceMagnitudeLowFreqAxis, 'on');
xline(coherenceMagnitudeLowFreqAxis, targetCoherenceFreq(1), 'r:', 'linewidth', 2, 'HandleVisibility', 'off');

finalizeAxes(coherenceMagnitudeHighFreqAxis, comparisonFrequencies(2), '');
xlim(coherenceMagnitudeHighFreqAxis, [targetCoherenceFreq(2) - xAxisZoomWidth, targetCoherenceFreq(2) + xAxisZoomWidth]);
ylim(coherenceMagnitudeHighFreqAxis, [0 1]);
yticks(coherenceMagnitudeHighFreqAxis, 0:0.2:1);
yticklabels(coherenceMagnitudeHighFreqAxis, {});
box(coherenceMagnitudeHighFreqAxis, 'on');
xline(coherenceMagnitudeHighFreqAxis, targetCoherenceFreq(2), 'r:', 'linewidth', 2, 'HandleVisibility', 'off');

finalizeAxes(coherencePhaseLowFreqAxis, comparisonFrequencies(1), '$\arg(\gamma_\mathrm{DC_Z,DS_Z})\,(\,^\circ\,)$');
xlim(coherencePhaseLowFreqAxis, [targetCoherenceFreq(1) - xAxisZoomWidth, targetCoherenceFreq(1) + xAxisZoomWidth]);
ylim(coherencePhaseLowFreqAxis, [-180 180]);
yticks(coherencePhaseLowFreqAxis, [-180 -90 0 90 180]);
box(coherencePhaseLowFreqAxis, 'on');
yline(coherencePhaseLowFreqAxis, 0, 'k', 'Alpha', 0.3, 'HandleVisibility', 'off');
xline(coherencePhaseLowFreqAxis, targetCoherenceFreq(1), 'r:', 'linewidth', 2, 'HandleVisibility', 'off');

finalizeAxes(coherencePhaseHighFreqAxis, comparisonFrequencies(2), '');
xlim(coherencePhaseHighFreqAxis, [targetCoherenceFreq(2) - xAxisZoomWidth, targetCoherenceFreq(2) + xAxisZoomWidth]);
ylim(coherencePhaseHighFreqAxis, [-180 180]);
yticks(coherencePhaseHighFreqAxis, [-180 -90 0 90 180]);
yticklabels(coherencePhaseHighFreqAxis, {});
box(coherencePhaseHighFreqAxis, 'on');
yline(coherencePhaseHighFreqAxis, 0, 'k', 'Alpha', 0.3, 'HandleVisibility', 'off');
xline(coherencePhaseHighFreqAxis, targetCoherenceFreq(2), 'r:', 'linewidth', 2, 'HandleVisibility', 'off');

% --- Apply Broken Axis Visuals ---
drawBrokenAxisGap(coherenceMagnitudeGapAxis);
drawBrokenAxisGap(coherencePhaseGapAxis);

uistack(coherenceMagnitudeGapAxis,"top")
uistack(coherencePhaseGapAxis,"top")

xlabel(mainLayout, 'Frequency (Hz)', 'interpreter', 'latex');

% scaleMultiplier = 2;
% fontsize(figureHandle, 10 * scaleMultiplier-1, 'points');
% figureLineWidth = 506.44 * scaleMultiplier;
% figureHandle.Units = 'points';
% figureHandle.Position(3:4) = [figureLineWidth figureLineWidth/2];
figureFolder = 'figures/BridgeDataProcessedResults/';
saveFig(figureHandle, figureFolder, 'QuadrantSearch', 2.1,1);

% =========================================================================
% HELPER FUNCTIONS
% (Place this at the bottom of your script along with your other helpers)
% =========================================================================

function drawBrokenAxisGap(gapAxis)
    hold(gapAxis, 'on');
    gapAxis.Color = 'none';
    gapAxis.XAxis.Visible = 'off';
    gapAxis.YAxis.Visible = 'off';
    xlim(gapAxis, [0 1]);
    ylim(gapAxis, [0 1]);

    % Light grey patch bridging the gap
    patch(gapAxis, [0 1 1 0], [0 0 1 1], [1 1 1], 'EdgeColor', 'none');

    % Top and bottom horizontal connecting lines
    plot(gapAxis, [0 1], [0 0], 'k-', 'LineWidth', 0.5);
    plot(gapAxis, [0 1], [1 1], 'k-', 'LineWidth', 0.5);

    % Diagonal slashes (//) crossing the boundaries
    % Clipping is off so they extend neatly into the adjacent plots
    plot(gapAxis, [-0.5 0.5], [-0.03 0.03], '-k', 'LineWidth', 1.5, 'Clipping', 'off');
    plot(gapAxis, [0.5 1.5], [-0.03 0.03], '-k', 'LineWidth', 1.5, 'Clipping', 'off');
    
    plot(gapAxis, [-0.5 0.5], [0.97 1.03], '-k', 'LineWidth', 1.5, 'Clipping', 'off');
    plot(gapAxis, [0.5 1.5], [0.97 1.03], '-k', 'LineWidth', 1.5, 'Clipping', 'off');
end
% Insert end %%%%%
% loc1 = coherencePhaseLowFreqAxis.Position;
% loc1(3) = loc1(3)*2;
% axPhase = axes('Position',loc1);
% box on;
% xticks([])
% yticks([])
% uistack(axPhase, 'bottom'); 
% 
% loc1 = coherenceMagnitudeLowFreqAxis.Position;
% loc1(3) = loc1(3)*2;
% axMag = axes('Position',loc1);
% box on;
% xticks([])
% yticks([])
% uistack(axMag, 'bottom'); 

% scale = 2;
% fontsize(figureHandle,10*scale-1,'points');
% lineWidth = 506.44*scale; %pts
% figureHandle.Units = 'points';
% figureHandle.Position(3:4) = [lineWidth lineWidth/2];
% 
% figureFolder = 'figures/BridgeDataProcessedResults/';
% 
% saveFig(figureHandle, figureFolder, 'QuadrantSearch',1);

function [lineStyle,lineWidth] = getLineStyle(description)
    % Determines line style based on the case description
    if contains(lower(description), 'no rwiv') || str2double(description(end-4)) < 5
        lineStyle = '--';
        lineWidth = 1;
    else
        lineStyle = '-';
        lineWidth = 1.5;
    end
end

function finalizeAxes(axHandle, xLines, yLabelText)
    % Applies standard formatting to the axes
    xline(axHandle, xLines, '--k', 'LineWidth', 2, 'HandleVisibility', 'off');
    ylabel(axHandle, yLabelText,'Interpreter','latex','FontSize',10);
    grid(axHandle, 'on');
    xlim(axHandle, [2.8 6.7]);
end

function fig = createFigure(figNum,title)
fig = figure(figNum); clf;
set(fig, 'Name', title, 'NumberTitle', 'off');
set(fig, 'DefaultTextInterpreter', 'latex', ...
    'DefaultAxesTickLabelInterpreter', 'latex', ...
    'DefaultLegendInterpreter', 'latex');
theme(fig, "light");
colororder(fig, 'earth');
end

% function successFlag = saveFig(fig,figureFolder,fileName,fontScale)
% arguments
%     fig 
%     figureFolder 
%     fileName 
%     fontScale = 1.7
% end
% fontsize(fig, "scale",fontScale);
% exportgraphics(fig, fullfile(figureFolder, [fileName '.svg']), 'ContentType', 'vector');
% try
%     if ~isempty(figureFolder)
%         exportgraphics(fig, fullfile(figureFolder, [fileName '.png']));
%         exportgraphics(fig, fullfile(figureFolder, [fileName '.pdf']), 'ContentType', 'vector');
% 
%         [~,msgID] = lastwarn;
%         if strcmp(msgID, 'MATLAB:print:ContentTypeImageSuggested')
%             exportgraphics(fig, fullfile(figureFolder, [fileName '.png']),'Resolution',600);
%             fprintf('Figure %s was saved in a high .png resulotion aswell',fileName)
%         end
%     else
%         error('No save')
%     end
%     successFlag = true;
% catch ME
%     successFlag = false;
%     error('No save')
% end
% end

function successFlag = saveFig(fig,figureFolder,fileName,heightScale,widthScale)
arguments
    fig 
    figureFolder 
    fileName 
    heightScale = 2
    widthScale = 1
end
%fontsize(fig, "scale",fontScale);
scale = 2;
fontsize(fig,9*scale,'points');
lineWidth = 506.44*scale; %cm
fig.Units = 'points';
fig.Position(3:4) = [lineWidth/widthScale lineWidth/heightScale];
fig.Renderer = 'painters';

try
    if ~isempty(figureFolder)
        exportgraphics(fig, fullfile(figureFolder, [fileName '.png']),'Resolution',600);
        exportgraphics(fig, fullfile(figureFolder, [fileName '.pdf']), 'ContentType', 'vector','BackgroundColor','white');
        
        [~,msgID] = lastwarn;
        if strcmp(msgID, 'MATLAB:print:ContentTypeImageSuggested')
            exportgraphics(fig, fullfile(figureFolder, [fileName '.pdf']), 'ContentType', 'auto');
            fprintf('Figure %s was saved in an automated .pdf way \n',fileName)
        end
    else
        error('No save')
    end
    successFlag = true;
catch ME
    successFlag = false;
    error('No save')
end
end
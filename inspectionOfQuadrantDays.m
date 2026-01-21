clear all;clc
addpath('functions');

dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';

inspectionDays = {
    '2019-09-16 01:00' '2019-09-16 02:00' 'Day1: Night, Dry, No RWIV'
    '2019-06-17 12:00' '2019-06-17 18:00' 'Day2: Day,   Dry, No RWIV'
    '2020-02-22 00:00' '2020-02-22 06:00' 'Day3: Night, Wet, RWIV'
    '2020-02-21 10:00' '2020-02-21 14:00' 'Day4: Day,   Wet, RWIV'
    % '2020-02-21 13:15' '2020-02-21 13:25' 'Day4: Day,   Wet, RWIV Zoom 13151325'
    % '2020-02-21 13:00' '2020-02-21 13:30' 'Day4: Day,   Wet, RWIV Zoom 13001330'
    % '2020-02-21 00:00' '2020-02-21 23:59' 'Day4: Day,   Wet, RWIV ZoomOutFullDay'
    % '2020-02-21 00:00' '2020-02-22 23:59' 'Day4: Day,   Wet, RWIV ZoomOutNidArt'
    % '2019-09-16 00:00' '2019-09-16 06:00' 'Day1: Night, Dry, No RWIV ZoomOut'
    %'2019-08-26 02:00' '2019-08-26 03:00' 'Day5: DecayTests'
    '2019-09-14 19:00' '2019-09-14 21:00' 'Day5: Day,   Wet, RWIV'
};
N = size(inspectionDays,1);
for i = 1:size(inspectionDays,1)
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
    plotTile = [inspectionDays{i,3} '-' inspectionDays{i,1} '-' inspectionDays{i,2}(end-4:end)];
    
    cables = ["C1E_y" "C1W_y"];
    for cable = cables
        charCable = char(cable);
        try
            freqInfo{i} = byBroaOverview.plotRwivDiagnostic(cable,[],plotTitle=plotTile,windowSec=30);
            drawnow
            exportgraphics(gcf,['figures/RwivDiagnostics/RwivDiagnostics' strrm(charCable,'_') strrm(inspectionDays{i,3},[" ",":",","]) '.png'],'Resolution',300)
        catch ME
             warning('Error processing cable %s: %s', charCable, ME.message);
        end
    end
end
%% Frequency picker
interrestingCases = [1:4 6];
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
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
    '2019-08-26 02:00' '2019-08-26 03:00' 'Initial data used for damping analysis'
    '2019-09-14 19:00' '2019-09-14 21:00' 'NID Doc. Initial RWIV case'
};

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
    
    cables = ["C1W_y" "C1E_y"];
    for cable = cables
        charCable = char(cable);
        %try
            if or(i < 5, i > 10)
                freqInfo{i} = byBroaOverview.plotRwivDiagnostic(cable,[],plotTitle=plotTile);
            else
                freqInfo{i} = byBroaOverview.plotRwivDiagnostic(cable,[],plotTitle=plotTile,deckFields='Conc_Z');
            end
            drawnow
            exportgraphics(gcf,['figures/RwivDiagnostics/RwivDiagnostics' strrm(charCable,'_') strrm(inspectionDays{i,3},[" ",":",","]) '.png'],'Resolution',300)
        % catch ME
        %     warning('Error processing cable %s: %s', charCable, ME.message);
        % end
    end
end

%% 
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
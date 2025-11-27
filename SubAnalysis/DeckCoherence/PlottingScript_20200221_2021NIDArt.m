clear all;clc

addpath('/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/functions')
addpath('functions')

CableDataPath = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data/ManualDownloads/CableDataArticle';
deckDataPath = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data/';

studycase = 'NidArticle';

PlotFigures = true;
PlotTime = true;

switch studycase
    case 'NidArticle'
        CableDataFileName = 'WSDA_W020000000073189_2020-03-02T12-58-16.968000.csv';
        Period = timerange('2020-02-21','2020-02-23');
        SaveName = 'data/cabledataNIDArticle.mat';
        deckDataDates = {'2020-02-21','2020-02-22'};
    case 'SSI-COV_Article'
        CableDataFileName = 'WSDA_W020000000073189_2019-08-30T09-26-58.787000.csv';
        Period = timerange('2019-08-28','2019-08-29');
        SaveName = 'data/cabledataSSICOV_Article.mat';
        deckDataDates = {'2019-08-28'};
    otherwise
        disp('This has not been configured..')
        return
end

%% Load data in correct coords
[BridgeData,CableData] = loadBridgeNCableData(CableDataFileName,CableDataPath,Period,SaveName,deckDataDates,deckDataPath);
%% Filter And Detrend
FsCable = 1/median(diff(seconds(CableData.Time-CableData.Time(1))));
FsBridge = 1/median(diff(seconds(BridgeData.Acc.time-BridgeData.Acc.time(1))));

fLow = 1/10;
fHigh= min(FsBridge,FsCable)/2-1;
[CableData, BridgeData] = ProcessBoth(CableData,BridgeData,fLow,fHigh,FsCable,FsBridge);

if PlotFigures
    fig=figure(1);clf;
    theme(fig,"light")
    Fs = FsCable;
    N = 6;

    Wn = [fLow fHigh]/(Fs/2);
    [b, a] = butter(N, Wn, 'bandpass');

    % fvtool(b, a, 'Fs', Fs);  % Interactive frequency response viewer
    [H, f] = freqz(b, a, 2^15, Fs);
    semilogx(f, 20*log10(abs(H)));
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB)');
    grid on;
    title('Butterworth Bandpass Filter Magnitude Response');
    xlim([0.01 fHigh*2]);  % zoom to low frequency
    exportgraphics(gcf,'figures/FilterDesign.pdf','ContentType','vector')
end
%% Data plots
if or(PlotFigures,PlotTime)
    % time histories
    plotTimeHistory(BridgeData,CableData);
    exportgraphics(gcf,'figures/AccelerationSignal_FullDay.png','Resolution',300)
end

%% EPSD
% time histories
if PlotFigures
    plotEPSDHistory(BridgeData,CableData)
    exportgraphics(gcf,'figures/EPSDSignal_FullDay.png','Resolution',300)
end
%% Coherence
selectedTimePeriod = [datetime(2020,2,21,12,50,00),...
    datetime(2020,2,21,13,30,00)];

plotTimeHistory(BridgeData,CableData,selectedTimePeriod)
exportgraphics(gcf,'figures/AccelerationSignal.png','Resolution',300)
plotTimeHistory(BridgeData,CableData,selectedTimePeriod,'displacement')
exportgraphics(gcf,'figures/DisplacementSignal.png','Resolution',300)
plotEPSDHistory(BridgeData,CableData,selectedTimePeriod,1)
exportgraphics(gcf,'figures/EPSDSignal.png','Resolution',300)
%% cable y and deck z HEAVE RESPONSE
fig=figure(3);clf;
theme(fig,"light")
[t,nexttileRowCol] = tiledlayoutRowCol(2,3,"TileSpacing", "compact", "Padding", "compact");
DeckPos = {'Conc_','Steel_'};
for ii = 1:2
    [Cxy,f,Pxx,Pyy,~] = CalcCoherence(BridgeData.Acc.time,BridgeData.Acc.([DeckPos{ii} 'Z']).Data,...
        CableData.Time,CableData.C1W_y,...
        selectedTimePeriod,false);
    nexttileRowCol(ii,1,'ColSpan',2);
    yyaxis left
    semilogy(f,Pxx,'DisplayName',[DeckPos{ii}(1:end-1) '$-z$']);
    hold on
    semilogy(f,Pyy,'DisplayName','C1W$-\hat{y}$')
    ylabel('$S_{\ddot{\hat{y}}}$ or $S_{\ddot{z}}$ $\mathrm{((m/s^2)^2)/Hz}$','Interpreter','latex','FontSize',20)
    yyaxis right
    plot(f,abs(Cxy).^2,'DisplayName','$|\mathit{coh}|^2$')
    ylabel(['$|\mathit{coh}(f,\Delta Z_{\mathrm{' DeckPos{ii}(1:end-1) '}}, \Delta \hat{y}_{\mathrm{C1W}})|^2$'],'Interpreter','latex','FontSize',20)
    ylim([0 1])
    xlim([0 fHigh])
    xticks(1:fHigh)
    [peakVal,peakFreq]=findpeaks(abs(Cxy).^2,f,'MinPeakHeight',0.2);
    [peakVal,idx] = sort(peakVal,'descend');
    xl = xline(peakFreq(idx),'--k','Alpha',0.2,'LineWidth',2);
    PeakFreqLegends = arrayfun(@(x) sprintf('$f=%.2f$',x), peakFreq(idx), 'UniformOutput', false);
    set(xl,{'DisplayName'},PeakFreqLegends)
    legend('Interpreter','latex','FontSize',16)
    ax = gca;
    ax.XGrid = 'on';

    nexttileRowCol(ii,3);
    plot(f,real(Cxy),'--','DisplayName',['$\gamma_{z\hat{y}}(f,\Delta Z_{\mathrm{' DeckPos{ii}(1:end-1) '}}, \Delta \hat{Y}_{\mathrm{C1W}}$)'])
    hold on
    plot(f, imag(Cxy),'-.','DisplayName',['$\rho_{z\hat{y}}(f,\Delta Z_{\mathrm{' DeckPos{ii}(1:end-1) '}}, \Delta \hat{Y}_{\mathrm{C1W}}$)'])
    xl = xline(peakFreq(idx),'--k','Alpha',0.2,'LineWidth',2,'HandleVisibility','off');
    ylim([-1 1])
    xlim([0 fHigh])
    xticks(1:fHigh)
    legend('Interpreter','latex','FontSize',16)
    grid on
end
xlabel(t,'$f$ (Hz)','Interpreter','latex','FontSize',20)
title(t,['Coherence for deck and cable C1W between ' ...
    char(selectedTimePeriod(1)) ' and ' ...
    char(selectedTimePeriod(2),'HH:mm:SS')],...
    'Interpreter','latex','Fontsize',24)
exportgraphics(fig,'figures/CoherenceDeckNC1W.png','Resolution',300)
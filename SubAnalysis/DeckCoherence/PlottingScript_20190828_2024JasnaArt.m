clear all;clc

addpath('/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/functions')
addpath('functions')

CableDataPath = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data/ManualDownloads/CableDataArticle';
deckDataPath = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data/';

studycase = 'SSI-COV_Article';

PlotFigures = true;
PlotTime = false;

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
CableData = loadWSDACableData(CableDataPath,...
    CableDataFileName,...
    SaveName,...
    Period);

CableData = CableDataShift2GlbalCoords(CableData);

foundDeckFiles = FindLocalBridgeDataFiles(deckDataPath, deckDataDates);
BridgeData = load(foundDeckFiles.path);
if isfield(BridgeData,'data')
    conf.structtype = 'Bybroa';
    BridgeData.data.Properties.DimensionNames{1}='Time';
    BridgeData = ConvertDataTable2DataStruct(conf,BridgeData.data);
else
    BridgeData = BridgeData.DailyData;
end
%% Filter And Detrend
FsCable = 1/median(diff(seconds(CableData.Time-CableData.Time(1))));
FsBridge = 1/median(diff(seconds(BridgeData.Acc.time-BridgeData.Acc.time(1))));

fLow = 1/10;
fHigh= 20;
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
    % time historiesh
    plotTimeHistory(BridgeData,CableData);
    exportgraphics(gcf,'figures/Acceleration_2024Art.png')
    plotTimeHistory(BridgeData,CableData,[],'displacement');
    exportgraphics(gcf,'figures/Displacement_2024Art.png')
end

%% EPSD
% time histories
if PlotFigures
    fig=figure(2);clf;
    theme(fig,"light")
    tiledlayout(3, 3, "TileSpacing", "compact", "Padding", "compact")

    %cable Data
    nexttile(3)
    plot_epsd(CableData.Time, CableData.C1E_x,10,false);
    title('C1E')
    nexttile(6)
    plot_epsd(CableData.Time, CableData.C1E_y,10,false);
    nexttile(9)
    plot_epsd(CableData.Time, CableData.C1E_z,10,false);

    %Deck Data
    nexttile(2)
    plot_epsd(BridgeData.Acc.time,BridgeData.Acc.Steel_X.Data,10,false);
    title('Steel deck')
    nexttile(5)
    plot_epsd(BridgeData.Acc.time,BridgeData.Acc.Steel_Y.Data,10,false);
    nexttile(8)
    plot_epsd(BridgeData.Acc.time,BridgeData.Acc.Steel_X.Data,10,false);


    %Deck Data
    nexttile(1)
    plot_epsd(BridgeData.Acc.time,BridgeData.Acc.Conc_X.Data,10,false);
    title('Concrete deck')
    ylabel('$f$ (Hz)','Interpreter','latex')
    nexttile(4)
    plot_epsd(BridgeData.Acc.time,BridgeData.Acc.Conc_Y.Data,10,false);
    ylabel('$f$ (Hz)','Interpreter','latex')
    nexttile(7)
    plot_epsd(BridgeData.Acc.time,BridgeData.Acc.Conc_X.Data,10,false);
    ylabel('$f$ (Hz)','Interpreter','latex')

    % Shared color limits for all EPSD plots
    axesHandles = findall(fig, 'Type', 'axes');
    clims = cell2mat(get(axesHandles, 'CLim'));
    sharedClim = [min(clims(:,1)), max(clims(:,2))];
    set(axesHandles, 'CLim', sharedClim);

    % One shared colorbar on the side for the whole tiledlayout
    cb = colorbar;
    cb.Layout.Tile = 'east';
    cb.Label.String = 'log$_{10}$ PSD ((m/s$^2$)$^2$/Hz)';
    cb.Label.Interpreter = 'latex';
    exportgraphics(gcf,'figures/EPSDSignal_2024Art.png')
end
%% Coherence
selectedTimePeriod = [datetime(2019,8,28,6,30,00),...
    datetime(2019,8,28,8,00,00)];

plotTimeHistory(BridgeData,CableData,selectedTimePeriod)
plotTimeHistory(BridgeData,CableData,selectedTimePeriod,'displacement')
exportgraphics(gcf,'figures/Displacement_2024Art.png')

%Coherence between deck and C1E
fig=figure(3);clf;
theme(fig,"light")
[t,nexttileRowCol] = tiledlayoutRowCol(2,3,"TileSpacing", "compact", "Padding", "compact");
plotCoherenceInDir('x',1,nexttileRowCol,'C1E', ...
    BridgeData,CableData,selectedTimePeriod)
plotCoherenceInDir('y',2,nexttileRowCol,'C1E', ...
    BridgeData,CableData,selectedTimePeriod)
plotCoherenceInDir('z',3,nexttileRowCol,'C1E', ...
    BridgeData,CableData,selectedTimePeriod)
nexttileRowCol(1,3)
legend({'Co-coherence' 'Bridge response' 'C1E response'},'Location','best')
xlabel(t,'Frequency (Hz)','Interpreter','latex')
ylabel(t,'$\gamma^2(f)$','Interpreter','latex')
yyAxisRightGlobal('PSD ((m/s$^2$)$^2$/Hz)',[.99 .42 0.1 0.1])

%Coherence between deck and C1E
fig=figure(4);clf;
theme(fig,"light")
[t,nexttileRowCol] = tiledlayoutRowCol(2,3,"TileSpacing", "compact", "Padding", "compact");
plotCoherenceInDir('x',1,nexttileRowCol,'C2E', ...
    BridgeData,CableData,selectedTimePeriod)
plotCoherenceInDir('y',2,nexttileRowCol,'C2E', ...
    BridgeData,CableData,selectedTimePeriod)
plotCoherenceInDir('z',3,nexttileRowCol,'C2E', ...
    BridgeData,CableData,selectedTimePeriod)
nexttileRowCol(1,3)
legend({'Co-coherence' 'Bridge response' 'C2E response'},'Location','best')
xlabel(t,'Frequency (Hz)','Interpreter','latex')
ylabel(t,'$\gamma^2(f)$','Interpreter','latex')
yyAxisRightGlobal('PSD ((m/s$^2$)$^2$/Hz)',[.99 .42 0.1 0.1])

%% Recreate figure from J. B. Jakobsen et al 2024
fig=figure(5);clf;
theme(fig,"light")
[t,nexttileRowCol] = tiledlayoutRowCol(3,2,"TileSpacing", "compact", "Padding", "compact");
dirs = {'x','y','z'};
for ii = 1:3
    [Cxy,f,Pxx,Pyy,~] = CalcCoherence(BridgeData.Acc.time,BridgeData.Acc.(['Conc_' upper(dirs{ii})]).Data,...
        BridgeData.Acc.time,BridgeData.Acc.(['Steel_' upper(dirs{ii})]).Data,...
        selectedTimePeriod,false);
    nexttileRowCol(ii,1);
    maxval = max([Pxx;Pyy]);
    semilogy(f,Pxx./maxval,'DisplayName',[dirs{ii} '-conc']);
    hold on
    semilogy(f,Pyy./maxval,'DisplayName',[dirs{ii} '-steel'])
    xlim([0 20])
    if ii == 2; ylabel('Normalized acceleration spectra');end
    nexttileRowCol(ii,2);
    plot(f,real(Cxy))
    xlim([0 20])
    if ii == 2; ylabel('real(Co-coherence function)');end
end
xlabel(t,'Frequency (Hz)')
title(t,'Recreated Fig 5 from J. B. Jakobsen 2024')
exportgraphics('figures/RecreatedJasnaArtPlot.png')
%% cable y and deck z HEAVE RESPONSE
fig=figure(6);clf;
theme(fig,"light")
[t,nexttileRowCol] = tiledlayoutRowCol(2,2,"TileSpacing", "compact", "Padding", "compact");
DeckPos = {'Conc_','Steel_'};
for ii = 1:2
    [Cxy,f,Pxx,Pyy,~] = CalcCoherence(BridgeData.Acc.time,BridgeData.Acc.([DeckPos{ii} 'Z']).Data,...
        CableData.Time,CableData.C1E_y,...
        selectedTimePeriod,false);
    nexttileRowCol(ii,1);
    yyaxis left
    maxval = max([Pxx;Pyy]);
    semilogy(f,Pxx./maxval,'DisplayName',['Z-' DeckPos{ii}(1:end-1)]);
    hold on
    semilogy(f,Pyy./maxval,'DisplayName','y-C1E')
    ylabel('Normalized acceleration spectra')

    yyaxis right
    plot(f,abs(Cxy).^2,'DisplayName','Coh.')
    ylabel('Mag. Squared Coherence function')
    ylim([0 1])
    xlim([0 20])
    legend
    xline([2.05,4.12],'--k','Alpha',0.2,'LineWidth',2,'HandleVisibility','off')

    nexttileRowCol(ii,2);
    plot(f, unwrap(angle(Cxy)))
    ylabel('\angle C_{xy}(f) (deg)')
    xlim([0 20])
end
xlabel(t,'frequency (Hz)')
title(t,['Coherence for deck and cable C1W between ' ...
    char(selectedTimePeriod(1)) ' and ' ...
    char(selectedTimePeriod(2),'HH:mm:SS')],...
    'Interpreter','latex','Fontsize',24)
exportgraphics(fig,'figures/CoherenceDeckNC1W_2024Art.png','Resolution',300)
%% dummy case with coherence of sine and cos
starttime = datetime('now');
t = (1:1/50:60*60*2)'; % 2 hours of data
tdate = starttime + seconds(t);
sig1 = 2 * sin(t*5*2*pi);
sig2 = 1 * cos(t*5*2*pi);

% Adding Noise
noise = 0.5 * randn(size(sig1));
d = designfilt('lowpassiir','FilterOrder',8, ...
               'PassbandFrequency',20,'PassbandRipple',0.2, ...
               'SampleRate',50);
noiseLP = filtfilt(d, noise);
sig1 = sig1 + noiseLP;
sig2 = sig2 + 0.5*noiseLP(randperm(length(noiseLP)));

[Cxy,f,Pxx,Pyy,~] = CalcCoherence(tdate,sig1,...
                                  tdate,sig2);
fig=figure(7);clf
theme(fig,"light")
[t,nexttileRowCol] = tiledlayoutRowCol(1,2,"TileSpacing", "compact", "Padding", "compact");

nexttileRowCol(1,1);
yyaxis left
maxval = max([Pxx;Pyy]);
semilogy(f,Pxx./maxval,'--','DisplayName','2sin(t)');
hold on
semilogy(f,Pyy./maxval,'-.','DisplayName','1cos(t)')
ylabel('Normalized acceleration spectra')

yyaxis right
plot(f,abs(Cxy).^2,'DisplayName','Coh.')
ylabel('Mag. Squared Coherence function')
%ylim([0 1])
xlim([0 20])
legend
nexttileRowCol(1,2);
plot(f, unwrap(angle(Cxy)))
ylabel('\angle C_{xy}(f) (rad)')
xlim([0 20])
exportgraphics(fig,'figures/dummyCoherence.png','Resolution',300)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%            Local functions            %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function yyAxisRightGlobal(string,box)
annotation('textbox',box, ...
    'String', string, ...
    'Interpreter','latex', ...
    'VerticalAlignment','middle', ...
    'EdgeColor','none', ...
    'Rotation', 90,...
    'FitBoxToText','on');
end
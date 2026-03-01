%close all
clearvars
clc

addpath("functions/")
measurementLogFileName = "MeasurementLog.csv";
dataPath = 'SignalExpressData/';


opts = detectImportOptions(measurementLogFileName);
TestTableOriginal = readtable(measurementLogFileName,opts);
TestTable = TestTableOriginal(4,:);
NTests = height(TestTable);




for kk = 1:NTests
    [time,timeDate,data] = loadSignalExpressData(fullfile(dataPath,TestTable.Datafile{kk}));
    SampleRate = 1/median(diff(time));

    % bandpass         = [0.1,8]; % Hz
    % ButterFieldOrder = 2;
    % data = applyFilter(data,SampleRate,bandpass,ButterFieldOrder);

    if isempty(TestTable.DecayPeiod{kk})
        idxs = [];
        for i = 1:width(data)
            [~,~,idxDecay] = selectDecayPeriod(time, data(:,i));
            idxs = [idxs,idxDecay];
        end
        TestTable.DecayPeiod{kk} = num2str(idxs);
        writetable(TestTable,measurementLogFileName)
    end
    
    decayPeriod =str2num(TestTable.DecayPeiod{kk});
    idxs = decayPeriod(1):decayPeriod(2);
    %[f,P] = plotCableDecay(time,data,TestTable(kk,:));
    
    dt = median(diff(time(idxs)));
    yvals = detrend(data(:,:),'constant');
    fsNew = 50;
    yvals = resample(yvals,fsNew,round(1/dt));
    %[R,t] = NExT_modified(yvals,1/fsNew,30,2);
    %SohFindLD(time(idxs), yvals, [2.5 3.5], 1) 
   
    [fn0,zeta0,phi0,paraPlot] = SSICOV(yvals(2000:12000,:),1/fsNew,'Ts',10,'Nmin',5,'Nmax',40,'methodCOV',2);
end
%%
fig=figure(2);clf
if ~isempty(which('theme')), theme(fig,'light'); end
semilogy(f,P)
xlim([0 20])
[Ppeak,fpeak]=findpeaks(P,f,'Threshold',10^(-8),'MinPeakDistance',0.3,...
    'MinPeakHeight',1.2*10^(-7));
hold on
plot(fpeak,Ppeak,'o');

fig=figure(3);clf
if ~isempty(which('theme')), theme(fig,'light'); end
numFreqs = 9;
fpeak = fpeak(2:numFreqs+1);
plot(1:numFreqs,fpeak,'.-k','MarkerSize',15,'DisplayName','11/11/2025')
ylabel('$f_n$ (Hz)','Interpreter','latex')
xlabel('Mode number','Interpreter','latex')
axis equal
axis tight
hold on
OldData = [ 1, 1.0420168067226891
            1.9919484702093397, 2.0672268907563023
            2.996779388083736, 3.109243697478991
            4.001610305958132, 4.151260504201681
            4.993558776167472, 5.1764705882352935
            5.985507246376812, 6.235294117647058
            6.99033816425121, 7.34453781512605
            7.9951690821256065, 8.386554621848738
            9, 9.378151260504202];

plot(OldData(:,1),OldData(:,2),'.-','MarkerSize',15,'DisplayName','28/08/2019 - Data')
legend('Interpreter','latex')
title(strrep(TestTable.Channel0{1},'_',' '))
exportgraphics(fig,'C1E Old Vs New.png')
function [data] = applyFilter(data,Fs,bandpass,ButterFieldOrder)
Wn = bandpass / (Fs/2);
[b,a] = butter(ButterFieldOrder,Wn,"bandpass");
[sos,g] = tf2sos(b,a);

data = sosfilt(sos,g*data);
end

function [f1,P1] = plotCableDecay(time,data,TestTable)
fig = figure(1);clf
if ~isempty(which('theme')), theme(fig,'light'); end

ids = str2num(TestTable.DecayPeiod{1});
dt = median(diff(time));
Fs = 1/dt;

tDecay1 = time(ids(1):ids(2));tDecay1 = tDecay1-tDecay1(1);
tDecay2 = time(ids(3):ids(4));tDecay2 = tDecay2-tDecay2(1);
x1 = data(ids(1):ids(2),1);
x2 = data(ids(3):ids(4),2);

x1 = detrend(x1,'linear');
x2 = detrend(x2,'linear');

chanName1 = strrep(TestTable.Channel0{1},'_',' ');
chanName2 = strrep(TestTable.Channel1{1},'_',' ');

NWindows1   = floor(length(x1)/3);
NOverlaps1  = floor(NWindows1/2);
Nfft1       = max(2^nextpow2(NWindows1),2^12);

NWindows2 = floor(length(x2)/3);
NOverlaps2 = floor(NWindows2/2);
Nfft2 = max(2^nextpow2(NWindows2),2^14);

[P1,f1] = pwelch(x1,hamming(NWindows1),NOverlaps1,Nfft1,Fs);
[P2,f2] = pwelch(x2,hamming(NWindows2),NOverlaps2,Nfft2,Fs);

Accylabel = 'Acceleration (ms$^{-2}$)';
PSDylabel = 'PSD ((ms$^{-2}$)$^2$/Hz)';
freqlabel = 'Frequency (Hz)';
timelabel = 'Time (s)';

freqlim = 20;

subplot(2,2,1)
plot(tDecay1,x1,'b-')
grid on;axis tight
xlabel(timelabel,'Interpreter','latex')
ylabel(Accylabel,'Interpreter','latex')
title([chanName1 ' – time domain'])
ymax = max(abs(x1)); ylim([-ymax ymax])

subplot(2,2,2)
semilogy(f1,sqrt(P1),'b-')
grid on
xlabel(freqlabel,'Interpreter','latex')
ylabel(PSDylabel,'Interpreter','latex')
title([chanName1 ' – Welch spectrum'])
xlim([0 freqlim])

subplot(2,2,3)
plot(tDecay2,x2,'r-')
grid on;axis tight
xlabel(timelabel,'Interpreter','latex')
ylabel(Accylabel,'Interpreter','latex')
title([chanName2 ' – time domain'])
ymax = max(abs(x2)); ylim([-ymax ymax])

subplot(2,2,4)
semilogy(f2,sqrt(P2),'r-')
grid on
xlabel(freqlabel,'Interpreter','latex')
ylabel(PSDylabel,'Interpreter','latex')
title([chanName2 ' – Welch spectrum'])
xlim([0 freqlim])

figureName = [TestTable.Bridge{1} '_'...
              TestTable.Cable{1} '_'...
              strrep(TestTable.Date{1},'/','') '_'...
              strrep(strrep(char(TestTable.Time),':','-'),' ','-') '_'...
              ];
sgtitle(strrep(figureName,'_',' '))

exportgraphics(fig,['figures/' figureName '.png'],'Resolution',150)
exportgraphics(fig,['figures/' figureName '.pdf'],'ContentType','vector')
end

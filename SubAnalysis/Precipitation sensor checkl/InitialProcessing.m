clear all
close all
clc

addpath('../../functions')

filePath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\SubAnalysis\Precipitation sensor checkl\';
savefig.flag = true;

datafilename = 'RainFiles.mat';
datafilename = 'NID_Article_RWIV_Data_ExtractedFiles.mat';

load(datafilename)

RainFiles = sort(FileLog(FileLog~=""));

ProcessedDataFolder   = fullfile(filePath,'ProcessedData');
savefig.FiguresFolder = fullfile(filePath,'figures');

isfolder(ProcessedDataFolder) || mkdir(ProcessedDataFolder);
isfolder(savefig.FiguresFolder) || mkdir(savefig.FiguresFolder);

RainDays = groupFilesByDay(RainFiles);

N = size(RainDays,1);
rows = cell(N,1);

for kk = 1:size(RainDays,1)
    data = [];
    for jj = 1:size(RainDays{kk,2}{1},1)
        [folder,file] = fileparts(RainDays{kk,2}{1}(jj));
        T = processCompressedFile(folder, [char(file) '.gz']);
        data = [data;T];
    end
    
    datestring = datestr(data.rowTimes(1), 'yyyy-mm-dd');
    plotRain(data,savefig,datestring)
    %plot_bybroa_met_all(data)
    save(fullfile(ProcessedDataFolder,datestr(RainDays{kk,1},'yyyy-mm-dd')),'data')

    rows{kk} = summarizeWeather_row(data);
end
HistData = vertcat(rows{:});
HistData = sortrows(HistData, 'Date');
HistData.Date.Format = 'dd-MMM-uuuu';
save(['HistData' '_' datafilename],'HistData')
%% plotting
load(['HistData' '_' datafilename])
HistData = HistData(year(HistData.Date) == 2020, :);

% Load online data
opts = detectImportOptions('OnlineData2019To2025.csv', 'DecimalSeparator', ',','Delimiter',';');
onlinedata = readtable('OnlineData2019To2025.csv',opts);
[~,~,idx] = intersect(HistData.Date,onlinedata.Tid);

figure;
%tiledlayout(2,1);
%nexttile
scalefactor = 1;
bar(HistData.Date, [HistData.Weather_1*scalefactor, ...
    ...                %HistData.Weather_2*scalefactor, ...
                    onlinedata.Nedbor_dogn(idx)]);
%xlabel('Date');
ylabel('Integrated Weather Value [L/h]');
title('Weather_1 and Weather_2 by Date with Online data');
legend({'Weather_1','Weather_2','Online Data'}, 'Location','best');
grid on;
xtickangle(45);

nexttile
idx = onlinedata.Nedbor_dogn(idx) > 5;
bar(HistData.Date(idx), [HistData.Weather_1(idx)*scalefactor] ...
                        ./onlinedata.Nedbor_dogn(idx));
%xlabel('Date');
ylabel('Integrated Weather Value div by station data [-]');
legend({'Weather_1','Weather_2'}, 'Location','best');
grid on;
xtickangle(45)
%% NID recreate plots
clear all;clc;close all
data1=load(fullfile('ProcessedData','2020-02-21.mat'));
data2=load(fullfile('ProcessedData','2020-02-22.mat'));
data = [data1.data;data2.data];

% raw data plot
d = data.Weather_1;
t = datenum(data.rowTimes);
fig = figure(1);clf;fig.Theme='light';
subplot(4,1,1);
plot(t,d);grid on;datetick('x','HH:MM','keeplimits');hold on
ylim([0 5])
tb = datenum([datetime(2020,2,22,1,20,00) datetime(2020,2,22,1,29,00)]);
[p,z]=zoomPlot(t,d,tb,[0.45 0.82 0.1 0.1],[4,3]);
datetick(z,'x','HH:MM','keeplimits');
z.XTick = tb(1):datenum(minutes(5)):tb(2);
z.XLim = tb;
title('Raw data')
% Plot lowpass filtered data
samplingrate = round(1/mean(seconds(diff(data.rowTimes)))); 
newsamplerate = 10; 

d_lp = lowpass(d,1,samplingrate);
subplot(4,1,2);
plot(t,d_lp);grid on;datetick('x','HH:MM','keeplimits');hold on
ylim([0 5])
tb = datenum([datetime(2020,2,22,1,20,00) datetime(2020,2,22,1,29,00)]);
[p,z]=zoomPlot(t,d_lp,tb,[0.45 0.602 0.1 0.1],[4,3]);
datetick(z,'x','HH:MM','keeplimits');
z.XTick = tb(1):datenum(minutes(5)):tb(2);
z.XLim = tb;
title('Lowpass filtered data using 1Hz as passing and 50Hz as sampling frequency')

% Plot downsampled data
d_down = d_lp(1:samplingrate*newsamplerate:end);
t_down = t(1:samplingrate*newsamplerate:end);
subplot(4,1,3);
plot(t_down,d_down);grid on;datetick('x','HH:MM','keeplimits');hold on
ylim([0 5])
tb = datenum([datetime(2020,2,22,1,20,00) datetime(2020,2,22,1,29,00)]);
[p,z]=zoomPlot(t_down,d_down,tb,[0.45 0.384 0.1 0.1],[4,3]);
datetick(z,'x','HH:MM','keeplimits');
z.XTick = tb(1):datenum(minutes(5)):tb(2);
z.XLim = tb;
title('Downsamped data using d(1:Samplerate*RainSamplerate:end)')

% Plot 10-min-meaned
N = 6*10; % 6 samples per minute for 10 minutes
d_mean = mean(reshape(d_down, N, []), 1);
t_mean = t_down(N/2:N:end);
subplot(4,1,4);
plot(t_mean,d_mean);grid on;datetick('x','HH:MM','keeplimits');hold on
ylim([0 5])
tb = datenum([datetime(2020,2,22,1,20,00) datetime(2020,2,22,1,36,00)]);
[p,z]=zoomPlot(t_mean,d_mean,tb,[0.45 0.165 0.1 0.1],[4,3]);
datetick(z,'x','HH:MM','keeplimits');
z.XTick = tb(1):datenum(minutes(5)):tb(2);
z.XLim = tb;
title('Meaned date using 10-min mean with 60 sample width (6 samples pr minute times 10 min)')
%%


d = data.Weather_1(1:samplingrate*newsamplerate:end);
t = data.rowTimes(1:samplingrate*newsamplerate:end);
N = 6*10;
meanedData = movmean(d,N);

hold on
scatter(t(1:N:end),meanedData(1:N:end),'filled');
alpha(.5)

d_trim = d(1:floor(length(d)/N)*N);
t_trim = t(1:floor(length(t)/N)*N);

d_trim = lowpass(d_trim,0.5);

d_down = mean(reshape(d_trim, N, []), 1);
t_down = t_trim(N/2:N:end);

figure
scatter(t_down,d_down,'filled')
alpha(.5)
ylim([0,6/3])

TR = (t >= datetime('2020-02-21 06:00')) & ...
     (t <  datetime('2020-02-22 06:00'));

trapz(hours(t_down-t_down(1)),d_down*3)
trapz(hours(t(TR)-t(1)),d(TR)*3)

% d = data.Weather_1;
% t = data.rowTimes;
% plot(t,d)

%% Functions:

function plotRain(data,savefig,datestring)

t = data.rowTimes;
w1 = data.Weather_1;
w2 = data.Weather_2;

fig=figure(1);clf
fig.Theme='light';
tiledlayout(2,1)
nexttile;
plot(t,w1)
hold on
plot(t,w2)
legend('Weather1','Weather2')
title(datestring)
ylim([0 2])
ylabel('(mm)/(mm/h)?')

nexttile;
th = hours(t-t(1));
plot(t,cumtrapz(th,w1))
hold on
plot(t,cumtrapz(th,w2))
ylabel('Daily Precipitation (mm)/(mm*mm)?')
%ylim([0 10])

if savefig.flag
    exportgraphics(gcf, fullfile(savefig.FiguresFolder,[datestring '.png']))
end

end

function row = summarizeWeather_row(data)
    TimeHours = hours(data.rowTimes - data.rowTimes(1));
    d  = dateshift(data.rowTimes(1), 'start', 'day');
    w1 = trapz(TimeHours, data.Weather_1);
    w2 = trapz(TimeHours, data.Weather_2);
    row = table(d, w1, w2, 'VariableNames', {'Date','Weather_1','Weather_2'});
end
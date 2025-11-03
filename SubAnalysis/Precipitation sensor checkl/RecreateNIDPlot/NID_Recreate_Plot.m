%% NID recreate plots
clear all; clc; close all
addpath('functions')

data1 = load(fullfile('ProcessedData','2020-02-21.mat'));
data2 = load(fullfile('ProcessedData','2020-02-22.mat'));
data  = [data1.data; data2.data];

% raw data plot
d = data.Weather_1;
t = datenum(data.rowTimes);

fig = figure(1); clf
if isprop(fig,'Theme')
    fig.Theme = 'light';
end
set(fig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

subplot(4,1,1);
plot(t, d);
grid on; hold on
datetick('x', 'HH:MM', 'keeplimits');
ylim([0 5])
title('Raw data')

tb = datenum([datetime(2020,2,22,1,20,00) datetime(2020,2,22,1,29,00)]);
[~, z] = zoomPlot(t, d, tb, [0.45 0.82 0.1 0.1], [4, 3]);
datetick(z, 'x', 'HH:MM', 'keeplimits');
z.XTick = tb(1) : datenum(minutes(5)) : tb(2);
z.XLim  = tb;

% Plot lowpass filtered data
samplingrate  = round(1 / mean(seconds(diff(data.rowTimes))));
newsamplerate = 10;
d_lp          = lowpass(d, 1, samplingrate); % arbitrarily choosen cutting frequency

subplot(4,1,2);
plot(t, d_lp);
grid on; hold on
datetick('x', 'HH:MM', 'keeplimits');
ylim([0 5])
title('Lowpass filtered data using 1Hz as passing and 50Hz as sampling frequency')

tb = datenum([datetime(2020,2,22,1,20,00) datetime(2020,2,22,1,29,00)]);
[~, z] = zoomPlot(t, d_lp, tb, [0.45 0.602 0.1 0.1], [4, 3]);
datetick(z, 'x', 'HH:MM', 'keeplimits');
z.XTick = tb(1) : datenum(minutes(5)) : tb(2);
z.XLim  = tb;

% Plot downsampled data
d_down = d_lp(1 : samplingrate * newsamplerate : end);
t_down = t(    1 : samplingrate * newsamplerate : end);

subplot(4,1,3);
plot(t_down, d_down);
grid on; hold on
datetick('x', 'HH:MM', 'keeplimits');
ylim([0 5])
title('Downsamped data using d(1:Samplerate*RainSamplerate:end)')

tb = datenum([datetime(2020,2,22,1,20,00) datetime(2020,2,22,1,29,00)]);
[~, z] = zoomPlot(t_down, d_down, tb, [0.45 0.384 0.1 0.1], [4, 3]);
datetick(z, 'x', 'HH:MM', 'keeplimits');
z.XTick = tb(1) : datenum(minutes(5)) : tb(2);
z.XLim  = tb;

% Plot 10-min-meaned
N      = 10; % 6 samples per minute for 10 minutes
d_mean = mean(reshape(d_down, N, []), 1);
t_mean = t_down(N/2 : N : end);

subplot(4,1,4);
plot(t_mean, d_mean);
grid on; hold on
datetick('x', 'HH:MM', 'keeplimits');
ylim([0 5])
title('Meaned date using 10-min mean with 60 sample width (6 samples pr minute times 10 min)')

tb = datenum([datetime(2020,2,22,1,20,00) datetime(2020,2,22,1,36,00)]);
[~, z] = zoomPlot(t_mean, d_mean, tb, [0.45 0.165 0.1 0.1], [4, 3]);
datetick(z, 'x', 'HH:MM', 'keeplimits');
z.XTick = tb(1) : datenum(minutes(5)) : tb(2);
z.XLim  = tb;

% savefig(fig, 'ProcessedData/DataProcess.fig');
% print(fig, 'ProcessedData/DataProcess.png', '-dpng', '-r300');
%% Create similar plot as in report
fig = figure(2);clf
if isprop(fig,'Theme')
    fig.Theme = 'light';
end
set(fig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

ax1=subplot(2,1,1);
scatter(t_mean,d_mean,'filled','SizeData',85,'MarkerFaceColor',[0 .5 .8])
datetick('x', 'HH:MM', 'keeplimits');
alpha(.4)
ylim([0,6])
box on
ax1.Position = [0.205 0.55 0.68 0.20];
title('Plotted Data')
ylabel('Rain (mm/h??)')

subplot(2,1,2)
img=imread('NID_Precipitation.png');
imshow(img)
title('Plot from 2021 article')
savefig(fig, 'ProcessedData/Comparison.fig');
print(fig, 'ProcessedData/Comparison.png', '-dpng', '-r300');
%% Create similar plot as in report using weather 2 - Jasna Method
fig = figure(3);clf
if isprop(fig,'Theme')
    fig.Theme = 'light';
end
set(fig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

d = data.Weather_2;
t = data.rowTimes;
samplerate = 50;
for i = 1:(2*24*60/10)
    N = samplerate*60*10*(i-1)+1:samplerate*60*10*i;
    W2N = d(N);
    t_mean(i)=datenum(data.rowTimes(N(1)));
    d_mean(i)=10*mean(W2N);
end


ax1=subplot(2,1,1);
scatter(t_mean,d_mean,'filled','SizeData',85,'MarkerFaceColor',[0 .5 .8])
datetick('x', 'HH:MM', 'keeplimits');
alpha(.4)
ylim([0,6])
box on
ax1.Position = [0.205 0.55 0.68 0.20];
title('Plotted Data')
ylabel('Rain (mm/h)')

subplot(2,1,2)
img=imread('NID_Precipitation.png');
imshow(img)
title('Plot from 2021 article')
savefig(fig, 'ProcessedData/Comparison2.fig');
print(fig, 'ProcessedData/Comparison2.png', '-dpng', '-r300');

%% Create similar plot as in report using weather 1
% fig = figure(4);clf
% if isprop(fig,'Theme')
%     fig.Theme = 'light';
% end
% set(fig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);


d = data2.data.Weather_1;
t = data2.data.rowTimes;



%%
% downsample
samplingrate = 50*10;
d = d(499:samplingrate:end);
t = t(499:samplingrate:end);

plot(t,d)
hold on;

N = 6; %min
d = mean(reshape(d, N, []), 1);
t = t(N/2 : N : end);

plot(t,d)

N = 10; %min
d_mean = mean(reshape(d, N, []), 1);
t_mean = t(N/2 : N : end);

plot(t_mean,d_mean);

%%
ax1=subplot(2,1,1);
scatter(t_mean,d_mean,'filled','SizeData',85,'MarkerFaceColor',[0 .5 .8])
datetick('x', 'HH:MM', 'keeplimits');
alpha(.4)
ylim([0,6])
box on
ax1.Position = [0.205 0.55 0.68 0.20];
title('Plotted Data')
ylabel('Rain (mm/h??)')

subplot(2,1,2)
img=imread('NID_Precipitation.png');
imshow(img)
title('Plot from 2021 article')
savefig(fig, 'ProcessedData/Comparison2.fig');
print(fig, 'ProcessedData/Comparison2.png', '-dpng', '-r300');

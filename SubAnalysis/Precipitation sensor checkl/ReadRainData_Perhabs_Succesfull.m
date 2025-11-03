clear all
close all
clc
% this might give the right result?? not sure yet
figure(1)
yyaxis left
load('ProcessedData\26-Jul-2020.mat')
%plot(data.rowTimes,data.Weather_1)
hold on
plot(data.rowTimes,data.Weather_2)

yyaxis right
t = data.rowTimes;
x = data.Weather_2;

sampleRate = 50;
measurementRate = 10;

x_smooth = movsum(x,1/60*sampleRate*measurementRate);
plot(t,x_smooth)

trapz(hours(t-t(1)),x_smooth)
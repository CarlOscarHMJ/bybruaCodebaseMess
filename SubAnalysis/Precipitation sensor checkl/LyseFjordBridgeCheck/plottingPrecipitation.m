clear all
close all
clc

load("ProcessedData\Lysefjord_all_20251015_164813.mat")

% yyaxis left
% plot(data.Time,data.Ch003_VaisalaH10_Weather_A)
% yyaxis right
plot(data.Time,data.Ch003_VaisalaH10_Weather_B)

t = hours(data.Time-data.Time(1));

sum(data.Ch003_VaisalaH10_Weather_B(1:50*10:end)*10/3600)
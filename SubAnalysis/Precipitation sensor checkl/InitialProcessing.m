clear all
close all
clc

addpath('../../functions')

filePath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\SubAnalysis\Precipitation sensor checkl\';

load('RainFiles.mat')
RainFiles = sort(FileLog(FileLog~=""));

ProcessedDataFolder = fullfile(filePath,'ProcessedData');
FiguresFolder = fullfile(filePath,'figures');

isfolder(ProcessedDataFolder) || mkdir(ProcessedDataFolder);
isfolder(FiguresFolder) || mkdir(FiguresFolder);

RainDays = groupFilesByDay(RainFiles);

for kk = 1:size(RainDays,1)
    data = [];
    for jj = 1:size(RainDays{kk,2}{1},1)
        [folder,file] = fileparts(RainDays{kk,2}{1}(jj));
        T = processCompressedFile(folder, [char(file) '.gz']);
        data = [data;T];
    end

    plotRain(data)
    figure(1);
    exportgraphics(gca,fullfile(FiguresFolder,strrep(file,'csv','png')))

    %plot_bybroa_met_all(data)
    save(fullfile(ProcessedDataFolder,datestr(RainDays{kk,1})),'data')
end

function dailyTbl = groupFilesByDay(filepaths)
    fp = string(filepaths(:));
    dstr = regexp(fp, '\d{4}-\d{2}-\d{2}', 'match', 'once');
    day  = datetime(dstr, 'InputFormat','yyyy-MM-dd');
    
    [gid, keys] = findgroups(day);
    filesPerDay = splitapply(@(x){sort(x)}, fp, gid);
    
    dailyTbl = table(keys, filesPerDay, 'VariableNames', {'Date','Files'});
    dailyTbl = sortrows(dailyTbl,'Date');
end

function plotRain(data)

t = data.rowTimes;
w1 = data.Weather_1;
w2 = data.Weather_2;

figure(1);clf
tiledlayout
nexttile;
plot(t,w1)
hold on
plot(t,w2)
legend('Column1','Column2')
title(datestr(t(1)))
ylim([0 2])

nexttile;
th = hours(t-t(1));
plot(t,cumtrapz(th,w1))
hold on
plot(t,cumtrapz(th,w2))
%ylim([0 10])


end
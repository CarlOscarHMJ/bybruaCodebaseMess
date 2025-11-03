clear all
close all
clc

addpath('../../../functions')

datapath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\Data\LyseFjordPrecipitationData\';
filePath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\SubAnalysis\Precipitation sensor checkl\LyseFjordBridgeCheck';

savefig.flag = true;

ProcessedDataFolder   = fullfile(filePath,'ProcessedData');
savefig.FiguresFolder = fullfile(filePath,'figures');

isfolder(ProcessedDataFolder)   || mkdir(ProcessedDataFolder);
isfolder(savefig.FiguresFolder) || mkdir(savefig.FiguresFolder);

files = dir(fullfile(datapath, '*.gz'));
N = numel(files);

dataCells  = cell(N,1);
errorMsgs  = strings(N,1);

if isempty(gcp('nocreate')); parpool; end

parfor kk = 1:N
    file    = files(kk).name;
    folder  = files(kk).folder;
    try
        T = processCompressedFile_Lysefjord(folder, file);
        dataCells{kk} = T;
    catch ME
        errorMsgs(kk) = "Failed: " + fullfile(folder,file) + " | " + ME.message;
        dataCells{kk} = [];
    end
end

bad = errorMsgs ~= "";
if any(bad)
    disp("Errors encountered:"); disp(errorMsgs(bad));
end

valid = ~cellfun(@isempty, dataCells);
data  = vertcat(dataCells{valid});

data  = sortrows(data);

outName = fullfile(ProcessedDataFolder, "Lysefjord_all_" + string(datetime('now','Format','yyyyMMdd_HHmmss')) + ".mat");
save(outName, 'data', '-v7.3');
disp("Saved: " + outName);

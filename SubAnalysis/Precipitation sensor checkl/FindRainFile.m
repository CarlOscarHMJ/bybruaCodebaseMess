clear all
close all
clc
addpath('functions')
%datapath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\Data\Weather and Bridge deck acc data';
%datapath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\Data\NID_Article_RWIV_Data';
datapath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\Data\PrecipitationSearch';

files = dir(fullfile(datapath,'**','*.gz'));
FileLog = strings(numel(files),1);
parfor kk = 1:length(files)
    file = files(kk).name;
    filepath = files(kk).folder;
    
    try
        data = processCompressedFile(filepath, file);
    catch
        warning(['Skipped file: ' file])
        continue
    end

    if any(data.Weather_1 ~= 0) || any(data.Weather_2 ~= 0)
        FileLog(kk) = fullfile(filepath,file);
    else
        delete(fullfile(filepath,file))
        delete(fullfile(filepath,strrep(file,'.csv.gz','.xml')))
    end
end
save('PrecipitationLog','FileLog')

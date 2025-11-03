clear all
close all
clc


files = dir(fullfile(datapath,'*.gz'));

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
        keyboard
    end
end

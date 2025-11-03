clear all
close all
clc

files = dir('ProcessedData\*.mat');

for kk = 1:length(files)
    file = files(kk).name;
    foldername = files(kk).folder;
    
    filedate = strrep(file,'.mat','');
    newname = [datestr(datenum(filedate),'yyyy-mm-dd') '.mat'];
    movefile(fullfile(foldername,file),fullfile(foldername,newname));
end
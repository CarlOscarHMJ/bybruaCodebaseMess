clear all
close all
clc
addpath('functions')
datapath = 'C:\Users\CarlOscar\Documents\PhD_Stavanger\Bybrua\Data\Weather and Bridge deck acc data';

files = dir(fullfile(datapath,'*.gz'));

for kk = 1:length(files)
    file = files(kk).name;
    data = processCompressedFile(datapath, file);
    
end

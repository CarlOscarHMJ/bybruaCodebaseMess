clear all
clc

addpath('functions')

dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';

ByBroa = BridgeProject(dataRoot); 
ByBroa.separateCsvToMatFiles(fullfile(dataRoot,'WSDA_data'))

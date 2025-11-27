function [time,timeDate,data] = loadSignalExpressData(dataPath)
%LOADSIGNALEXPRESSDATA Load IEPE-formatted SignalExpress data from text file
%   [TIME, DATA] = LOADSIGNALEXPRESSDATA(DATAPATH) reads the file
%   'IEPE.txt' located in DATAPATH and extracts the start time, sampling
%   interval, and measurement data. The function returns TIME as a datetime
%   vector corresponding to each sample and DATA as a numeric array
%   containing the measurement channels. The function requires the text file
%   to contain 'start times:' and 'dt:' fields in the expected format.
% 
%   13/11/2025 COH
filename = 'IEPE.txt';
filepath = fullfile(dataPath, filename);

fileID = fopen(filepath,'r');
if fileID == -1
    error('Could not open file: %s', filepath);
end

startTime = [];
dt = [];

currentLine = fgetl(fileID);
while ischar(currentLine)
    lineStr = strtrim(currentLine);
    if strcmp(lineStr, 'start times:')
        nextLine = fgetl(fileID);
        startTimeParts = strsplit(strtrim(nextLine), sprintf('\t'));
        startTime = datetime(startTimeParts{1}, ...
            'InputFormat','dd/MM/yyyy HH:mm:ss.SSSSSS');
    elseif strcmp(lineStr, 'dt:')
        nextLine = fgetl(fileID);
        dt = str2double(strtrim(nextLine));
        break
    end
    currentLine = fgetl(fileID);
end
fclose(fileID);

data = readmatrix(filepath,"Range",8);

if isempty(startTime) || isempty(dt) || isempty(data)
    error('Failed to parse required fields from file: %s', filepath);
end

sampleCount = size(data,1);
time = (0:sampleCount-1)' * dt;
timeDate = startTime + seconds(time);
end
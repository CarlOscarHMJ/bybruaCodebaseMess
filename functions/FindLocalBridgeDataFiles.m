function foundFiles = FindLocalBridgeDataFiles(dataRoot, targetDates)
% FindLocalBridgeDataFiles searches for .mat data files corresponding to given dates in a structured data folder.
% 
% INPUTS:
%   dataRoot     - Root directory of the data (e.g., 'Analysis/Data master')
%   targetDates  - String or character array of dates (e.g., ["2020-03-02","2020-03-09"])
%
% OUTPUT:
%   foundFiles   - Struct array with fields:
%                    .date : the date string
%                    .path : full file path if found, or empty if not found
%
% The function searches all year/month folders for files named as YYYY-MM-DD.mat
% and reports missing dates.

if ischar(targetDates)
    targetDates = string(targetDates);
end

foundFiles = struct('date', cell(numel(targetDates),1), 'path', cell(numel(targetDates),1));

for i = 1:numel(targetDates)
    dateString = targetDates(i);
    dateParts = split(dateString, "-");
    if numel(dateParts) ~= 3
        warning("Invalid date format for '%s'. Expected 'YYYY-MM-DD'.", dateString);
        continue;
    end
    yearFolder = fullfile(dataRoot, dateParts{1});
    monthFolder = fullfile(yearFolder, dateParts{2});
    fileName = dateString + ".mat";
    filePath = fullfile(monthFolder, fileName);

    if isfile(filePath)
        foundFiles(i).date = dateString;
        foundFiles(i).path = filePath;
    else
        fprintf("Data not found for date: %s\n", dateString);
        foundFiles(i).date = dateString;
        foundFiles(i).path = "";
    end
end
end

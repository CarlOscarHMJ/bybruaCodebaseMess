function foundFiles = FindLocalBridgeDataFiles(dataRoot, targetDates)
% FindLocalBridgeDataFiles searches for .mat data files corresponding to given dates in a structured data folder.
%
% INPUTS:
%   dataRoot     - Root directory of the data (e.g., 'Analysis/Data master')
%   targetDates  - String or character array of dates (e.g., ["2020-03-02","2020-03-09"])
%                  'alldates' can be used to get all data files.
%
% OUTPUT:
%   foundFiles   - Struct array with fields:
%                    .date : the date string
%                    .path : full file path if found, or empty if not found
%
% The function searches all year/month folders for files named as YYYY-MM-DD.mat
% and reports missing dates.

if strcmpi(targetDates,'alldates')
    targetDates = ["2018-01-01","2030-01-01"];
    
    startDate = datetime(targetDates(1));
    endDate = datetime(targetDates(2));
    
    allDates = startDate:endDate;
    targetDates = string(allDates,'yyyy-MM-dd');
    allDaysFlag = 1;
else
    allDaysFlag = 0;
end

if ischar(targetDates)
    targetDates = string(targetDates);
end

foundFiles = struct('date', cell(numel(targetDates),1), 'path', cell(numel(targetDates),1));

ii = 0;
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
        ii = ii + 1; 
        foundFiles(ii).date = dateString;
        foundFiles(ii).path = filePath;
    else
        if allDaysFlag 
            continue
        end
        ii = ii + 1;
        fprintf("Data not found for date: %s\n", dateString);
        foundFiles(i).date = dateString;
        foundFiles(i).path = "";
    end
end

ActualFilesMask = ~strcmp([foundFiles.path],"");
foundFiles = foundFiles(ActualFilesMask);
end

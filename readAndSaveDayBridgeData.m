function processedFiles = readAndSaveDayBridgeData(rawFiles, dataDestinationDir, structType)
    % readAndSaveDayBridgeData monitors a folder for new bridge data, 
    % processes it into daily .mat files, and preserves the subfolder structure.
    arguments
        rawFiles = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data/Rawdata'
        dataDestinationDir = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data'
        structType = 'Bybroa';
    end
    addpath('functions/');
    processedFiles = string.empty;
    lastNewFileTime = datetime('now');
    timeoutMinutes = 30;
    
    conf.structtype = structType;

    while minutes(datetime('now') - lastNewFileTime) < timeoutMinutes
        allFiles = dir(fullfile(rawFiles, '**', '*.csv.gz'));
        allPaths = fullfile({allFiles.folder}, {allFiles.name})';
        newFiles = setdiff(string(allPaths), processedFiles);

        if ~isempty(newFiles)
            lastNewFileTime = datetime('now');
            processBatch(newFiles, rawFiles, dataDestinationDir, conf);
            processedFiles = [processedFiles; newFiles];
        end

        pause(60);
    end
end

function processBatch(filePaths, sourceDir, destinationDir, conf)
    % Groups files by date and manages the processing workflow for a batch.

    dailyTable = groupFilesByDay(filePaths);
    nDays = height(dailyTable);
    time = zeros(nDays,1);time(:)=NaN;

    for i = 1:nDays
        tStart = tic;
        processDailyGroup(dailyTable.Date(i), dailyTable.Files{i}, sourceDir, destinationDir, conf);
        time(i) = toc(tStart);

        daysLeft = nDays-i;
        timeLeft = mean(time,"all","omitmissing")*daysLeft;
        fprintf('\n\n\n\n')
        fprintf('********************************************************\n')
        fprintf('The day read took in total %3.1f seconds\n', time(i));
        fprintf('Estimated time left: %3.1f seconds\n', timeLeft);
        fprintf('********************************************************\n')
    end
end

function processDailyGroup(currentDate, files, sourceDir, destinationDir, conf)
    % processDailyGroup processes and saves bridge data with a retry mechanism and conditional cleanup.

    maxAttempts = 3;
    saveSuccessful = false;

    for attempt = 1:maxAttempts
        try
            dataParts = cell(size(files));
            for i = 1:length(files)
                [folder, name, ext] = fileparts(files(i));
                dataParts{i} = processCompressedFile(char(folder), [char(name), char(ext)]);
            end

            combinedTable = vertcat(dataParts{:});
            dailyData = ConvertDataTable2DataStruct(conf, combinedTable);

            savePath = calculateDestinationPath(files(1), sourceDir, destinationDir);
            if ~exist(savePath, 'dir')
                mkdir(savePath);
            end

            dateStr = datestr(currentDate, 'yyyy-mm-dd');
            save(fullfile(savePath, [dateStr, '.mat']), 'dailyData', '-v7');
            
            saveSuccessful = true;
            break;
        catch ME
            fprintf('Attempt %d failed for %s: %s\n', attempt, datestr(currentDate), ME.message);
        end
    end

    if saveSuccessful
        deleteProcessedFiles(files);
    end
end

function deleteProcessedFiles(files)
    for i = 1:length(files)
        if exist(files(i), 'file')
            delete(files(i));
        end
    end
end

function destPath = calculateDestinationPath(sampleFile, sourceDir, destinationDir)
    % Determines the destination subfolder path relative to the source directory.

    sampleFolder = fileparts(sampleFile);
    relativeFolder = extractAfter(sampleFolder, absPath(sourceDir));
    
    if isempty(relativeFolder)
        destPath = destinationDir;
    else
        % Remove leading file separators if present
        if startsWith(relativeFolder, filesep)
            relativeFolder = extractAfter(relativeFolder, 1);
        end
        destPath = fullfile(destinationDir, relativeFolder);
    end
end

function absolutePath = absPath(inputPath)
    % Returns the absolute path of a directory to ensure string comparisons work.

    currDir = pwd;
    cd(inputPath);
    absolutePath = pwd;
    cd(currDir);
end

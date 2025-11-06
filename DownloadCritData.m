function DownloadCritData()
%% Function setup
addpath('functions/')

crit.Rain       = [0    inf];   % mm/h
crit.WindSpeed  = [8    12];    % m/s
crit.CableAngle = [45   65];    % deg

server = '';
server = ConnectFtpServer('uis_bybrua_server');
cleanupObj = onCleanup(@() close(server)); % ensures close() runs on function exit

destination = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data/';

structtype = 'Bybroa';

conf.crit = crit;
conf.server = server;
conf.destination = destination;
conf.structtype = structtype;
%% Download data
try
    ProcessAllUnprocessedData(conf)
catch ME
    fprintf('Error in %s (line %d): %s\n',ME.stack(1).name,ME.stack(1).line,ME.message)
end

end

function ProcessAllUnprocessedData(conf)
server = conf.server;
cd(server,'arkiv');

allServerFiles = FindAllServerFiles(server, '.csv.gz',conf);

localMatFiles = dir(fullfile(conf.destination,'**/*.mat'));
localMatFiles = {localMatFiles.name};

Dates2Process = FindUnprocessedData(allServerFiles, localMatFiles);

for i = 1:height(Dates2Process)
    downloadPath = DownloadFiles(conf, Dates2Process.Files{i});
    ReadAndSaveDay(conf, downloadPath);
end
end

function downloadPath = DownloadFiles(conf,ServerFiles)
% Download the files described in files variable from server
for i = 1:length(ServerFiles)
    file = char(ServerFiles(i));
    file = strrm(file,'/arkiv/');
    downloadPath(i) = mget(conf.server, file, conf.destination);
end
end

function DailyData = ReadAndSaveDay(conf,LocalFiles)
% Reads and saves the daily data files in .mat format

T_all = {};
for ii = 1:length(LocalFiles)
    [path,file,att] = fileparts(LocalFiles{ii});
    shortDataTable = processCompressedFile(path,[file,att]);
    T_all{ii} = shortDataTable;
    delete(LocalFiles{ii})
end
T = vertcat(T_all{:});

DailyData = ConvertDataTable2DataStruct(conf,T);

DayStr = regexp(file,'\d{4}-\d{2}-\d{2}','match','once');
save(fullfile(path,[DayStr,'.mat']),'DailyData','-v7')
end

function Dates2Process = FindUnprocessedData(serverFiles, localMatFiles)
DaysGrouped = groupFilesByDay(serverFiles);
processedDates = cellfun(@(x) regexp(x,'\d{4}-\d{2}-\d{2}','match','once'), localMatFiles, 'UniformOutput', false);

DatesToUse = [];
FilesToUse = {};
for i = 1:height(DaysGrouped)
    DayStr = regexp(DaysGrouped.Files{i}{1},'\d{4}-\d{2}-\d{2}','match','once');
    if ~ismember(DayStr, processedDates)
        DatesToUse{end+1,1} = DayStr; %#ok<AGROW>
        FilesToUse{end+1,1} = DaysGrouped.Files{i}; %#ok<AGROW>
    end
end

Dates2Process = table(DatesToUse, FilesToUse, 'VariableNames', {'Date','Files'});
end

%% Helper functions

function allFiles = FindAllServerFiles(server, EndsWith, conf)
logFolder = fullfile(conf.destination,'log');
if ~exist(logFolder,'dir')
    mkdir(logFolder);
end
logFile = fullfile(logFolder,'ftp_file_list.mat');

updateLog = true;
if exist(logFile,'file')
    fileInfo = dir(logFile);
    fileAgeDays = days(datetime('now') - datetime(fileInfo.datenum,'ConvertFrom','datenum'));
    if fileAgeDays >= 14
        answer = questdlg('Log exists and is older than 14 days old. Re-write log?', ...
                          'Update FTP Log', ...
                          'Yes','No','No');
        if strcmp(answer,'No')
            updateLog = false;
        end
    else
        updateLog = false;
    end
end

if ~updateLog
    % Read existing log
    S = load(logFile);
    allFiles = S.allFiles;
    fprintf('Read %d files from existing log.\n', length(allFiles));
    return
end

% Otherwise, generate the file list
allFiles = {};
YearFolders = dir(server); 
YearFolders = YearFolders([YearFolders.isdir] & ~ismember({YearFolders.name},{'.','..'}) );

fprintf('Scanning %d year folders...\n', length(YearFolders));

for y = 1:length(YearFolders)
    year = YearFolders(y).name;
    folderPath = fullfile('/arkiv', year);
    months = dir(server, folderPath);
    months = {months([months.isdir]).name};

    for m = 1:length(months)
        month = months{m};
        monthFolder = fullfile('/arkiv', year, month);
        try
            files = dir(server, monthFolder);
            files = files(~[files.isdir]); % keep only files
            for f = 1:length(files)
                if endsWith(files(f).name, EndsWith)
                    allFiles{end+1,1} = fullfile(monthFolder, files(f).name); %#ok<AGROW>
                end
            end
        catch
            fprintf('  Could not list folder %s, skipping.\n', monthFolder);
            continue;
        end
    end
    fprintf('Processed year %s, total files so far: %d\n', year, length(allFiles));
end

% Save log
save(logFile,'allFiles','-v7');
fprintf('Saved FTP file list to log (%d files).\n', length(allFiles));
end

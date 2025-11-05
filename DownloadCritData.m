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
    DownLoadRightCases(conf)
catch ME
    fprintf('Error in %s (line %d): %s\n',ME.stack(1).name,ME.stack(1).line,ME.message)
end

end
%% Helper functions
function DownLoadRightCases(conf)
server = conf.server;
cd(server,'arkiv'); % All data is in arkiv
YearFolders = dir(server);
rootFolder  = server.RemoteWorkingDirectory;
tic

for yy = 1:length(YearFolders)
    year         = YearFolders(yy).name;
    MonthFolders = dir(server,fullfile(rootFolder,year));
    MonthFolders = MonthFolders([MonthFolders.isdir]);

    for mm = 1:length(MonthFolders)
        month = MonthFolders(mm).name;
        datafiles = dir(server,fullfile(rootFolder,year,month,'*csv.gz'));
        if isempty(datafiles); continue;end
        Days = groupFilesByDay({datafiles.name});

        for dd = 1:height(Days)
            DownloadPath = DownloadFiles(conf,Days.Files{dd});
            DailyData = ReadAndSaveDay(conf,DownloadPath);
        end
    end
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
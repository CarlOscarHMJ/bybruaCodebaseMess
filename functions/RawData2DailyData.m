function RawData2DailyData(datapath)

%datapath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\Data\Weather and Bridge deck acc data';
%datapath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\Data\NID_Article_RWIV_Data';
%datapath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\Data\SSICOV_Data';
%datapath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\Data\PrecipitationSearch';

files = dir(fullfile(datapath,'**','*.gz'));
dailyTbl = groupFilesByDay(string({files.name}));

ProcessedDataFolder   = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\Data\ProcessedData';
%isfolder(ProcessedDataFolder) || mkdir(ProcessedDataFolder);

if size(dailyTbl,1) < 3
    parforArg = 0; % only run parrallel if there is more than 3 days
else
    parforArg = inf;
end

parfor (kk = 1:height(dailyTbl),parforArg)
    data = [];
    for jj = 1:size(dailyTbl{kk,2}{1},1)
        file = dailyTbl{kk,2}{1}(jj);
        T = processCompressedFile(datapath, file);
        data = [data;T];
    end
    
    SaveFileParallel(fullfile(ProcessedDataFolder,datestr(dailyTbl{kk,1},'yyyy-mm-dd')),'data')
end
end

function SaveFileParallel(filepath,DataFile2Save)
    save(filepath,'DataFile2Save');
end
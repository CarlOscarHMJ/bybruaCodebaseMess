clear all;close all;clc

addpath('/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/functions')

CableDataPath = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data/ManualDownloads/CableDataArticle';
deckDataPath = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data/';

studycase = 'SSI-COV_Article';

switch studycase
    case 'NidArticle'
        CableDataFileName = 'WSDA_W020000000073189_2020-03-02T12-58-16.968000.csv';
        Period = timerange('2020-02-21','2020-02-23');
        SaveName = 'data/cabledataNIDArticle.mat';
        deckDataDates = {'2020-02-21','2020-02-22'};
    case 'SSI-COV_Article'
        CableDataFileName = 'WSDA_W020000000073189_2019-08-30T09-26-58.787000.csv';
        Period = timerange('2019-08-28','2019-08-29');
        SaveName = 'data/cabledataSSICOV_Article.mat';
        deckDataDates = {'2020-08-28'};
    otherwise
        disp('This has not been configured..')
        return
end

CableData = loadWSDACableData(CableDataPath,...
                              CableDataFileName,...
                              SaveName,...
                              Period);

CableData = CableDataVariableRenaming(CableData);

foundDeckFiles = FindLocalBridgeDataFiles(deckDataPath, deckDataDates);
BridgeData = load(foundDeckFiles.path);
if isfield(BridgeData,'data')
    conf.structtype = 'Bybroa';
    BridgeData.data.Properties.DimensionNames{1}='Time';
    BridgeData = ConvertDataTable2DataStruct(conf,BridgeData.data);
else
    BridgeData = BridgeData.BridgeData;
end


%% Data plots
figure(1);clf;

plot(CableData.Time, CableData.Data, 'LineWidth', 1.5);
xlabel('Time');
ylabel('Cable Data');
title('Cable Data Over Time');
grid on;








%% Local functions
function CableData = loadWSDACableData(CableDataPath,CableDataFileName,SaveName,Period)
% Loads Cable data from ByBroa depending on weather it has been saved or
% not...
if ~exist(SaveName,'file')
    opts = detectImportOptions(fullfile(CableDataPath,CableDataFileName));
    CableData = readtable(fullfile(CableDataPath,CableDataFileName),opts);
    
    CableData = table2timetable(CableData,"RowTimes","Time");
    CableData=CableData(Period,:);
    
    % fix headers
    VarNames = string(CableData.Properties.VariableNames);    
    VarNames = strrep(strrep(VarNames,'_',':'),'x','');

    dataNums = CableData.Variables;
    [dataNums] = calibration_glink(dataNums,VarNames);
    CableData.Variables = dataNums;
    
    save(strrep(SaveName,'.mat',''),'CableData')
else
    load(SaveName)
end
end

function CableData = CableDataVariableRenaming(CableData)


end
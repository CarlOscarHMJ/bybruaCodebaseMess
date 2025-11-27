function [BridgeData,CableData] = loadBridgeNCableData(CableDataFileName,CableDataPath,Period,SaveName,deckDataDates,deckDataPath)

CableData = loadWSDACableData(CableDataPath,...
    CableDataFileName,...
    SaveName,...
    Period);

CableData = CableDataShift2GlbalCoords(CableData);

foundDeckFiles = FindLocalBridgeDataFiles(deckDataPath, deckDataDates);
if size(foundDeckFiles,1) > 1
    BridgeData = cell(size(foundDeckFiles, 1), 1);
    for i = 1:size(foundDeckFiles, 1)
        BridgeData{i} = load(foundDeckFiles(i).path);
    end
    
    if ~isfield(BridgeData{1},'data')
        error('No data field found in BridgeData structure. The load ...function does not support this file');
    end

    dataCells = cellfun(@(s) s.data, BridgeData, 'UniformOutput', false);
    AllData   = vertcat(dataCells{:});
    BridgeData = struct;
    BridgeData.data = AllData;
else
    BridgeData = load(foundDeckFiles.path);
end
if isfield(BridgeData,'data')
    conf.structtype = 'Bybroa';
    BridgeData.data.Properties.DimensionNames{1}='Time';
    BridgeData = ConvertDataTable2DataStruct(conf,BridgeData.data);
else
    BridgeData = BridgeData.DailyData;
end
end
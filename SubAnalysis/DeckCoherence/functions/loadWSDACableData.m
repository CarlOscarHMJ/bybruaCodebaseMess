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

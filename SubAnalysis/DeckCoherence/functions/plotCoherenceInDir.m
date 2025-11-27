function plotCoherenceInDir(dir,collumn,nexttileRowCol,cable,BridgeData,CableData,selectedTimePeriod)
plotCoherence = true;
nexttileRowCol(1,collumn);
CalcCoherence(BridgeData.Acc.time,BridgeData.Acc.(['Conc_' upper(dir)]).Data,...
    CableData.Time,CableData.([cable '_' dir]),...
    selectedTimePeriod,plotCoherence);
if strcmp(dir,'x')
    ylabel('Concrete deck Vs. Cable')
end
title([dir ' direction'])
nexttileRowCol(2,collumn);
CalcCoherence(BridgeData.Acc.time,BridgeData.Acc.(['Steel_' upper(dir)]).Data,...
    CableData.Time,CableData.([cable '_' dir]),...
    selectedTimePeriod,plotCoherence);
if strcmp(dir,'x')
    ylabel('Steel deck Vs. Cable')
end
end
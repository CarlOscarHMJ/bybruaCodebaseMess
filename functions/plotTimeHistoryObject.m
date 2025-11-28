function plotTimeHistoryObject(BridgeData,CableData,TimePeriod,convert2DispOrVel)

if exist('TimePeriod','var')
    if ~isempty(TimePeriod)
        Range = timerange(TimePeriod(1),TimePeriod(2));
        CableData = CableData(Range,:);
        BridgeData = BridgeData(Range,:);
    end
end

if exist('convert2DispOrVel','var') && ~strcmpi(convert2DispOrVel,'acceleration')
    [BridgeData,CableData] = convertAcceleration(BridgeData,CableData,convert2DispOrVel);

    if strcmpi(convert2DispOrVel,'displacement')
        unitDef = '\mathrm{';
        unit = 'm';
    elseif strcmpi(convert2DispOrVel,'velocity')
        unitDef = '\dot{';
        unit = 'm/s';
    end
else
    unitDef = '\ddot{';
    unit = 'm/s$^2$';
end

CableVars = CableData.Properties.VariableNames;
cableGroups = findCableGroups(CableVars);

fig=figure(1);clf;
theme(fig,"light")
[~,nexttileRowCol] = tiledlayoutRowCol(3,2+size(cableGroups,1),"TileSpacing", "compact", "Padding", "compact");
%Deck Data - Concrete
nexttileRowCol(1,1);
plot(BridgeData.Time,BridgeData.Conc_X);
title('Concrete deck')
ylabel(['$' unitDef 'x}$ (' unit ')'],'Interpreter','latex')
axis tight
nexttileRowCol(2,1);
plot(BridgeData.Time,BridgeData.Conc_Y);
ylabel(['$' unitDef 'y}$ (' unit ')'],'Interpreter','latex')
axis tight
nexttileRowCol(3,1);
plot(BridgeData.Time,BridgeData.Conc_Z);
ylabel(['$' unitDef 'z}$ (' unit ')'],'Interpreter','latex')
axis tight

%Deck Data - Steel
nexttileRowCol(1,2);
plot(BridgeData.Time,BridgeData.Steel_X);
title('Steel deck')
axis tight
nexttileRowCol(2,2);
plot(BridgeData.Time,BridgeData.Steel_Y);
axis tight
nexttileRowCol(3,2);
plot(BridgeData.Time,BridgeData.Steel_Z);
axis tight

for ii = 1:size(cableGroups,1)
    for jj = 1:size(cableGroups{ii,2},1)
        nexttileRowCol(jj,2+ii);
        cableName = cableGroups{ii,1};
        cableDir  = char(cableGroups{ii,2}(jj));
        plot(CableData.Time, CableData.([cableName '_' cableDir]));
        axis tight
        if jj == 1
            title(cableName)
        end
    end
end

axesHandles = findall(fig,'Type','axes');
setTimeTicks(axesHandles,BridgeData.Time)
end

function [BridgeData,CableData] = convertAcceleration(BridgeData,CableData,convert2DispOrVel)
if strcmpi(convert2DispOrVel,'displacement')
    dataout_type = 1;
elseif strcmpi(convert2DispOrVel,'velocity')
    dataout_type = 2;
end

bridgeVars = BridgeData.Properties.VariableNames;
bridgeDt = median(diff(seconds((BridgeData.Time-BridgeData.Time(1)))));
for k = 1:length(bridgeVars)
    datain = BridgeData.(bridgeVars{k});
    dataout = iomega(datain,bridgeDt,3,dataout_type);
    dataout = detrend(dataout,3-dataout_type);
    BridgeData.(bridgeVars{k}) = dataout;
end

cableVars = CableData.Properties.VariableNames;
cableDt = median(diff(seconds((CableData.Time-CableData.Time(1)))));
for k = 1:length(cableVars)
    datain = CableData.(cableVars{k});
    dataout = iomega(datain,cableDt,3,dataout_type);
    dataout = detrend(dataout,3-dataout_type);
    CableData.(cableVars{k}) = dataout;
end
end
function plotEPSDHistoryObject(BridgeData,CableData,TimePeriod,segmentDurationMinutes)

if exist('TimePeriod','var')
    if ~isempty(TimePeriod)
        Range = timerange(TimePeriod(1),TimePeriod(2));
        CableData = CableData(Range,:);
        BridgeData = BridgeData(Range,:);
    end
end

if ~exist('segmentDurationMinutes','var')
    segmentDurationMinutes = 10;
end

fmax = 15;

CableVars = CableData.Properties.VariableNames;
cableGroups = findCableGroups(CableVars);

fig=figure(2);clf;
theme(fig,"light")
[t,nexttileRowCol] = tiledlayoutRowCol(3,2+size(cableGroups,1),"TileSpacing", "compact", "Padding", "compact");
%Deck Data - Concrete
nexttileRowCol(1,1);
plot_epsd(BridgeData.Time,BridgeData.Conc_X,segmentDurationMinutes,false);
title('Concrete deck')
ylabel('x direction','Interpreter','latex')
axis tight
ylim([0,fmax])
nexttileRowCol(2,1);
plot_epsd(BridgeData.Time,BridgeData.Conc_Y,segmentDurationMinutes,false);
ylabel('y direction','Interpreter','latex')
axis tight
ylim([0,fmax])
nexttileRowCol(3,1);
plot_epsd(BridgeData.Time,BridgeData.Conc_Z,segmentDurationMinutes,false);
ylabel('z direction','Interpreter','latex')
axis tight
ylim([0,fmax])
ylabel(t,'$f$ (Hz)','Interpreter','latex')

%Deck Data - Steel
nexttileRowCol(1,2);
plot_epsd(BridgeData.Time,BridgeData.Steel_X,segmentDurationMinutes,false);
title('Steel deck')
axis tight
ylim([0,fmax])
nexttileRowCol(2,2);
plot_epsd(BridgeData.Time,BridgeData.Steel_Y,segmentDurationMinutes,false);
axis tight
ylim([0,fmax])
nexttileRowCol(3,2);
plot_epsd(BridgeData.Time,BridgeData.Steel_Z,segmentDurationMinutes,false);
axis tight
ylim([0,fmax])

for ii = 1:size(cableGroups,1)
    for jj = 1:size(cableGroups{ii,2},1)
    nexttileRowCol(jj,2+ii);
    cableName = cableGroups{ii,1};
    cableDir  = char(cableGroups{ii,2}(jj));
    plot_epsd(CableData.Time, CableData.([cableName '_' cableDir]),segmentDurationMinutes,false);
    axis tight
    ylim([0,fmax])
    if jj == 1
        title(cableName)
    end
    end
end

% Shared color limits for all EPSD plots
axesHandles = findall(fig, 'Type', 'axes');
clims = cell2mat(get(axesHandles, 'CLim'));
sharedClim = [min(clims(:,1)), max(clims(:,2))];
set(axesHandles, 'CLim', sharedClim);

% One shared colorbar on the side for the whole tiledlayout
cb = colorbar;
cb.Layout.Tile = 'east';
cb.Label.String = 'log$_{10}$ PSD ((m/s$^2$)$^2$/Hz)';
cb.Label.Interpreter = 'latex';
end

function plotEPSDHistoryObject(BridgeData,CableData,TimePeriod,segmentDurationMinutes)
% plotEPSDHistoryObject Plot EPSD history for deck and cable data with shared scaling.
%   plotEPSDHistoryObject(BridgeData,CableData)
%   plotEPSDHistoryObject(BridgeData,CableData,TimePeriod)
%   plotEPSDHistoryObject(BridgeData,CableData,TimePeriod,segmentDurationMinutes)

if nargin > 2 && ~isempty(TimePeriod)
    range = timerange(TimePeriod(1),TimePeriod(2));
    CableData = CableData(range,:);
    BridgeData = BridgeData(range,:);
end

if nargin < 4 || isempty(segmentDurationMinutes)
    segmentDurationMinutes = 10;
end

fmax = 15;
cableGroups = findCableGroups(CableData.Properties.VariableNames);

fig = figure(2); clf;
theme(fig,"light")
[tiles,nexttileRowCol] = tiledlayoutRowCol(3,2+size(cableGroups,1), ...
    "TileSpacing","compact","Padding","compact");

deckTypes   = {'Conc','Steel'};
deckTitles  = {'Concrete deck','Steel deck'};
dirs        = {'X','Y','Z'};
dirLabels   = {'x direction','y direction','z direction'};

for d = 1:numel(deckTypes)
    for k = 1:numel(dirs)
        nexttileRowCol(k,d);
        varName = [deckTypes{d} '_' dirs{k}];
        plot_epsd(BridgeData.Time,BridgeData.(varName),segmentDurationMinutes,false);
        axis tight
        ylim([0,fmax])
        if d == 1
            ylabel(dirLabels{k},'Interpreter','latex')
        end
        if k == 1
            title(deckTitles{d})
        end
    end
end

ylabel(tiles,'$f$ (Hz)','Interpreter','latex')

for ii = 1:size(cableGroups,1)
    cableName = cableGroups{ii,1};
    cableDirs = cableGroups{ii,2};
    for jj = 1:numel(cableDirs)
        nexttileRowCol(jj,2+ii);
        varName = cableName + "_" + cableDirs(jj);
        plot_epsd(CableData.Time,CableData.(varName),segmentDurationMinutes,false);
        axis tight
        ylim([0,fmax])
        if jj == 1
            title(cableName)
        end
    end
end

axesHandles = findall(fig,'Type','axes');
clims = cell2mat(get(axesHandles,'CLim'));
sharedClim = [min(clims(:,1)), max(clims(:,2))];
set(axesHandles,'CLim',sharedClim);

setTimeTicks(axesHandles,BridgeData.Time)

cb = colorbar;
cb.Layout.Tile = 'east';
cb.Label.String = 'log$_{10}$ PSD ((m/s$^2$)$^2$/Hz)';
cb.Label.Interpreter = 'latex';
end

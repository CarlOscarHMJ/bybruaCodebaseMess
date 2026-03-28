function successFlag = saveFig(fig,figureFolder,fileName,heightScale,widthScale,leg,options)
arguments
    fig 
    figureFolder 
    fileName 
    heightScale = 2
    widthScale = 1
    leg = []
    options.scaleFigure (1,1) logical = true
end

if options.scaleFigure
    %fontsize(fig, "scale",fontScale);
    scale = 2;
    fontsize(fig,9*scale,'points');
    lineWidth = 506.44*scale; %cm
    fig.Units = 'points';
    fig.Position(3:4) = [lineWidth/widthScale lineWidth/heightScale];
    fig.Renderer = 'painters';
    if ~isempty(leg)
        leg.FontSize = 16;
    end
end

figureFolder = char(figureFolder);fileName = char(fileName);

try
    if ~isempty(figureFolder)
        exportgraphics(fig, fullfile(figureFolder, [fileName '.png']),'Resolution',600);
        exportgraphics(fig, fullfile(figureFolder, [fileName '.pdf']), 'ContentType', 'vector');
        
        [~,msgID] = lastwarn;
        if strcmp(msgID, 'MATLAB:print:ContentTypeImageSuggested')
            exportgraphics(fig, fullfile(figureFolder, [fileName '.pdf']), 'ContentType', 'auto');
            fprintf('Figure %s was saved in an automated .pdf way \n',fileName)
        end
    else
        error('No save')
    end
    successFlag = true;
catch ME
    successFlag = false;
    error('No save')
end
end

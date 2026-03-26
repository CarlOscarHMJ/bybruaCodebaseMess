function fig = createFigure(figNum,title)
fig = figure(figNum); clf;
%set(fig, 'Visible', 'on');
title = ['Figure: ' num2str(figNum) ' - ' char(title)];
set(fig, 'Name', title, 'NumberTitle', 'off');
set(fig, 'DefaultTextInterpreter', 'latex', ...
    'DefaultAxesTickLabelInterpreter', 'latex', ...
    'DefaultLegendInterpreter', 'latex');
try
    theme(fig, "light");
catch
end
try
    colororder(fig, 'earth');
catch
end
end

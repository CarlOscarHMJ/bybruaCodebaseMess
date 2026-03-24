function fig = createFigure(figNum,title)
fig = figure(figNum); clf;
%set(fig, 'Visible', 'off');
title = ['Figure: ' num2str(figNum) ' - ' char(title)];
set(fig, 'Name', title, 'NumberTitle', 'off');
set(fig, 'DefaultTextInterpreter', 'latex', ...
    'DefaultAxesTickLabelInterpreter', 'latex', ...
    'DefaultLegendInterpreter', 'latex');
theme(fig, "light");
colororder(fig, 'earth');
end

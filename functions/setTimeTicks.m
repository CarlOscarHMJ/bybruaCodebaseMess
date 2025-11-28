function setTimeTicks(axesHandles,timeVec)
timeStart = min(timeVec);
timeEnd   = max(timeVec);
spanHours = hours(timeEnd - timeStart);

if     spanHours <= 2
    step = minutes(10);
elseif spanHours <= 6
    step = minutes(30);
elseif spanHours <= 25
    step = hours(5);
elseif spanHours <= 72
    step = hours(10);
else
    step = days(1);
end

tickStart = dateshift(timeStart,'start','hour');
tickEnd   = dateshift(timeEnd,'start','hour');
tickTimes = tickStart:step:tickEnd;

if spanHours < 25
    tickFormat = 'HH:mm';        % no date
else
    tickFormat = 'MM-dd HH:mm';  % include date
end

for ax = reshape(axesHandles,1,[])
    xl = xlim(ax);
    if isempty(xl) || all(ismissing(xl))
        continue
    end
    if isa(ax.XAxis,'matlab.graphics.axis.decorator.DatetimeRuler')
        ax.XTick = tickTimes;
        ax.XAxis.TickLabelFormat = tickFormat;
    else
        ax.XTick = datenum(tickTimes);
        datetick(ax,'x',tickFormat,'keeplimits','keepticks');
    end

    if length(axesHandles) > 1
        % remove date in right corner
        ax.XAxis.SecondaryLabel.Visible = 'off';
    end
end
end
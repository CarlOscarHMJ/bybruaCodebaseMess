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

for ax = reshape(axesHandles,1,[])
    xl = xlim(ax);
    if isempty(xl) || all(isnan(xl))
        continue
    end
    if isnumeric(xl)
        ax.XTick = datenum(tickTimes);
        datetick(ax,'x','HH:MM','keeplimits','keepticks');
    else
        ax.XTick = tickTimes;
        ax.XAxis.TickLabelFormat = 'HH:mm';
    end
end
end
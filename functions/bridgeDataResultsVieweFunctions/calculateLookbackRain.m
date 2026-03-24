function lookbackRain = calculateLookbackRain(flagField, allStats, durationLimit)
    events = allStats(allStats.(flagField),:);

    % Helper to find the maximum mean rain intensity in the preceding window
    numEvents = size(events,1);
    lookbackRain = zeros(numEvents, 1);
    
    % Extract all timestamps from the full dataset for logical indexing
    allStarts = allStats.duration(:,1);
    
    for i = 1:numEvents
        tEnd = events.duration(i,1);
        tStart = tEnd - durationLimit;
        
        % Filter allStats for segments within [tStart, tEnd]
        relevantIdx = (allStarts >= tStart) & (allStarts <= tEnd);
        relevantStats = allStats(relevantIdx,:);
        
        if ~isempty(relevantStats)
            % Extract the mean rain intensity for all segments in this window
            windowRainValues = [relevantStats.RainIntensity.mean];
            lookbackRain(i) = max(windowRainValues);
        else
            lookbackRain(i) = events.RainIntensity(i).mean;
        end
    end
end

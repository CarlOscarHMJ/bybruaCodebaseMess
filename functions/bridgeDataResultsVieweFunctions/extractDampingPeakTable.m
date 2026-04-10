function peakTable = extractDampingPeakTable(allStats, flagField, direction, options)
% extractDampingPeakTable Builds peak-level table for damping analysis selections.

arguments
    allStats table
    flagField {mustBeTextScalar}
    direction {mustBeTextScalar}
    options.frequencyFocus (1,1) string {mustBeMember(options.frequencyFocus, ["all", "target"])} = "all"
    options.targetFreqs double = []
    options.freqTolerance double = NaN
end

direction = upper(string(direction));
sensorNames = ["Conc_" + direction, "Steel_" + direction];

if ~ismember(string(flagField), string(allStats.Properties.VariableNames))
    warning('Field %s was not found in allStats.', char(flagField));
    peakTable = table();
    return;
end

flagMask = iToLogicalColumn(allStats.(char(flagField)));
selectedRows = find(flagMask);

rainValues = iGetMeanWeather(allStats, 'RainIntensity');
windSpeedValues = iGetMeanWeather(allStats, 'WindSpeed');
windDirectionValues = iGetMeanWeather(allStats, 'WindDir');
localWindValues = iGetMeanWeather(allStats, 'PhiC1');

segmentIndex = [];
startTime = datetime.empty(0, 1);
endTime = datetime.empty(0, 1);
sensor = strings(0, 1);
frequency = [];
damping = [];
rainIntensity = [];
windSpeed = [];
windDirection = [];
localWindDirection = [];

for rowIdx = selectedRows(:)'
    for sensorName = sensorNames
        sensorNameChar = char(sensorName);
        if ~isfield(allStats.psdPeaks, sensorNameChar)
            continue;
        end

        peakStruct = allStats.psdPeaks(rowIdx).(sensorNameChar);
        if ~isfield(peakStruct, 'locations') || ~isfield(peakStruct, 'dampingRatios')
            continue;
        end

        locations = peakStruct.locations(:);
        dampingRatios = peakStruct.dampingRatios(:);
        validMask = isfinite(locations) & isfinite(dampingRatios) & dampingRatios > 0 & dampingRatios < 1;

        if options.frequencyFocus == "target"
            nearTargetMask = false(size(locations));
            for targetFrequency = options.targetFreqs(:)'
                nearTargetMask = nearTargetMask | abs(locations - targetFrequency) <= options.freqTolerance;
            end
            validMask = validMask & nearTargetMask;
        end

        selectedCount = sum(validMask);
        if selectedCount == 0
            continue;
        end

        segmentIndex = [segmentIndex; repmat(rowIdx, selectedCount, 1)];
        startTime = [startTime; repmat(allStats.duration(rowIdx, 1), selectedCount, 1)];
        endTime = [endTime; repmat(allStats.duration(rowIdx, 2), selectedCount, 1)];
        sensor = [sensor; repmat(string(sensorNameChar), selectedCount, 1)];
        frequency = [frequency; locations(validMask)];
        damping = [damping; dampingRatios(validMask)];
        rainIntensity = [rainIntensity; repmat(rainValues(rowIdx), selectedCount, 1)];
        windSpeed = [windSpeed; repmat(windSpeedValues(rowIdx), selectedCount, 1)];
        windDirection = [windDirection; repmat(windDirectionValues(rowIdx), selectedCount, 1)];
        localWindDirection = [localWindDirection; repmat(localWindValues(rowIdx), selectedCount, 1)];
    end
end

peakTable = table(segmentIndex, startTime, endTime, sensor, frequency, damping, ...
    rainIntensity, windSpeed, windDirection, localWindDirection);
end

function logicalColumn = iToLogicalColumn(flagColumn)
if iscell(flagColumn)
    logicalColumn = cellfun(@(value) logical(value(1)), flagColumn);
else
    logicalColumn = logical(flagColumn);
end
logicalColumn = logicalColumn(:);
end

function weatherMean = iGetMeanWeather(allStats, fieldName)
if ~ismember(fieldName, allStats.Properties.VariableNames)
    weatherMean = nan(height(allStats), 1);
    return;
end

weatherStruct = allStats.(fieldName);
if isstruct(weatherStruct) && isfield(weatherStruct, 'mean')
    weatherMean = [weatherStruct.mean]';
else
    weatherMean = nan(height(allStats), 1);
end
end

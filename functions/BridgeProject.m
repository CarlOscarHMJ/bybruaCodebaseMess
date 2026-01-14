classdef BridgeProject
    properties
        dataRoot char
        % Start of day is assumed with char input
        startTime datetime
        % End of day is assumed with char input
        endTime   datetime
        bridgeData timetable
        cableData  timetable
        weatherData struct
        rawFiles struct
        loadTime datetime
    end

    methods
        function self = BridgeProject(dataRoot, startTime, endTime)
            if nargin < 3
                warning('Not enough inputs')
                return
            end

            if ischar(startTime) || isstring(startTime)
                startTime = datetime(startTime,'InputFormat','yyyy-MM-dd HH:mm');
            end

            if ischar(endTime) || isstring(endTime)
                endTime = datetime(endTime, 'InputFormat', 'yyyy-MM-dd HH:mm');
            end

            self.dataRoot = dataRoot;
            self = self.loadPeriod(startTime, endTime);
        end

        function self = loadPeriod(self, startTime, endTime)
            self.startTime = startTime;
            self.endTime   = endTime;
            tic
            [self.bridgeData,self.weatherData] = self.loadBridgeData(self.startTime, self.endTime);
            fprintf('Loaded bridge data in %3.1f seconds\n',toc)
            tic
            self.cableData  = self.loadCableData(self.startTime, self.endTime);
            fprintf('Loaded cable data in %3.1f seconds\n',toc)

            self = self.transformWeatherData();
            self.loadTime = datetime('now');
        end

        function ch = getChannel(self, source, name)
            switch lower(string(source))
                case "bridge"
                    ch = self.bridgeData.(name);
                case "cable"
                    ch = self.cableData.(name);
                otherwise
                    error("BridgeProject:getChannel", "Unknown source '%s'", source);
            end
        end

        function t = getTime(self, source)
            switch lower(string(source))
                case "bridge"
                    t = self.bridgeData.Time;
                case "cable"
                    t = self.cableData.Time;
                otherwise
                    error("BridgeProject:getTime", "Unknown source '%s'", source);
            end
        end

        function Fs = getSamplingFrequency(self, source)
            t = self.getTime(source);
            dt = seconds(mode(diff(t)));
            Fs = 1 / dt;
        end

        function subProj = slice(self, t0, t1)
            if t0 < self.startTime || t1 > self.endTime
                error("BridgeProject:slice", "Slice outside loaded period");
            end

            maskBridge = self.bridgeData.Time >= t0 & self.bridgeData.Time <= t1;
            maskCable  = self.cableData.Time  >= t0 & self.cableData.Time  <= t1;

            bridgeSlice = self.bridgeData(maskBridge, :);
            cableSlice  = self.cableData(maskCable, :);

            subProj = BridgeProject(self.dataRoot,t0,t1);
            subProj.startTime  = t0;
            subProj.endTime    = t1;
            subProj.bridgeData = bridgeSlice;
            subProj.cableData  = cableSlice;
        end

        function duration = getDuration(self)
            duration = self.endTime - self.startTime;
        end

        function hasData = hasChannel(self, source, name)
            switch lower(string(source))
                case "bridge"
                    hasData = ismember(name, self.bridgeData.Properties.VariableNames);
                case "cable"
                    hasData = ismember(name, self.cableData.Properties.VariableNames);
                otherwise
                    error("BridgeProject:hasChannel", "Unknown source '%s'", source);
            end
        end

        function separateCsvToMatFiles(~, parentFolder)
            filePattern = fullfile(parentFolder, '**', 'WSDA*.csv');
            fileList = dir(filePattern);

            for k = 1:length(fileList)
                sourceFilePath = fullfile(fileList(k).folder, fileList(k).name);

                headerLineCount = BridgeProject.countHeaderLinesUntilDataStart(sourceFilePath);
                [~, fileHeader] = system(sprintf('head -n %d "%s"', headerLineCount, sourceFilePath));

                accelerationDataStore = datastore(sourceFilePath, ...
                    'ReadVariableNames', true, ...
                    'NumHeaderLines', headerLineCount);

                accumulatedData = timetable.empty();

                while hasdata(accelerationDataStore)
                    chunkTable = read(accelerationDataStore);

                    if ~isdatetime(chunkTable{:, 1})
                        chunkTable{:, 1} = datetime(chunkTable{:, 1});
                    end

                    chunkTimetable = table2timetable(chunkTable);
                    chunkTimes = chunkTimetable.Properties.RowTimes;

                    dateStrings = string(chunkTimes, 'yyyy-MM-dd');
                    periodLabels = repmat("am", height(chunkTimetable), 1);
                    periodLabels(hour(chunkTimes) >= 12) = "pm";
                    chunkKeys = dateStrings + "_" + periodLabels;

                    startIdx = 1;
                    for i = 2:height(chunkTimetable)
                        if chunkKeys(i) ~= chunkKeys(i-1)
                            processAndSave(accumulatedData, chunkTimetable(startIdx:i-1, :));
                            accumulatedData = timetable.empty();
                            startIdx = i;
                        end
                    end

                    accumulatedData = [accumulatedData; chunkTimetable(startIdx:end, :)];
                end

                if ~isempty(accumulatedData)
                    processAndSave(accumulatedData, timetable.empty());
                end
            end

            function processAndSave(existingBuffer, newSlice)
                finalTable = [existingBuffer; newSlice];
                if isempty(finalTable)
                    return;
                end

                startTime = finalTable.Properties.RowTimes(1);
                endTime = finalTable.Properties.RowTimes(end);

                if year(startTime) <= 1970
                    return;
                end

                dayString = string(startTime, 'yyyy-MM-dd');
                if hour(startTime) < 12
                    periodTag = "am";
                else
                    periodTag = "pm";
                end

                startTimeTag = string(startTime, 'HHmmss');
                endTimeTag = string(endTime, 'HHmmss');

                outputFileName = sprintf('WSDA_%s_%s_%s_to_%s.mat', ...
                    dayString, periodTag, startTimeTag, endTimeTag);
                outputFullPath = fullfile(parentFolder, outputFileName);

                sensorTimetable = finalTable;
                sensorTimetable.Properties.UserData = fileHeader;

                save(outputFullPath, 'sensorTimetable');
            end
        end
    end

    methods (Access = private) % Bridgedata Loading
        function [bridgeData, weatherData] = loadBridgeData(self, startTime, endTime)
            % loadBridgeData locates daily files and slices the resulting data to the exact interval.
            dates = allDatesBetween(startTime, endTime);
            self.rawFiles = FindLocalBridgeDataFiles(self.dataRoot, string(dates, 'yyyy-MM-dd'));

            mergedStructData = loadAndMergeBridgeData(self);
            [bridgeData, weatherData] = splitBridgeData(self, mergedStructData);

            bridgeData = bridgeData(timerange(startTime, endTime), :);

            weatherFields = fieldnames(weatherData);
            for i = 1:numel(weatherFields)
                fieldName = weatherFields{i};
                if isfield(weatherData.(fieldName), 'Time')
                    timeMask = weatherData.(fieldName).Time >= startTime & ...
                        weatherData.(fieldName).Time <= endTime;
                    weatherData.(fieldName).Time = weatherData.(fieldName).Time(timeMask);
                    weatherData.(fieldName).Data = weatherData.(fieldName).Data(timeMask);
                end
            end
        end

        function DailyData = loadAndMergeBridgeData(self)
            load(self.rawFiles(1).path);
            if ~exist("DailyData",'var')
                error(sprintf('DataLoad ERROR: format of file was wrong, DailyData was not found!\nfile is: %s', self.rawFiles(1).path))
            end
            for ii = 2:length(self.rawFiles)
                S = load(self.rawFiles(ii).path);
                if ~isfield(S,'DailyData')
                    error(sprintf('DataLoad ERROR: format for file was wrong, DailyData was not found!\nfile is: %s', self.rawFiles(ii).path))
                end
                try
                    DailyData = appendDailyData(self,DailyData,S.DailyData);
                catch exception
                    error("Failed to append DailyData: %s\n", exception.message);
                end
            end
        end

        function out = appendDailyData(~,a,b)
            out = a;
            fieldsA = fieldnames(a);

            for i = 1:numel(fieldsA)
                fn = fieldsA{i};

                if strcmp(fn,"Acc")
                    accFields = fieldnames(a.Acc);
                    for j = 1:numel(accFields)
                        af = accFields{j};

                        if strcmpi(af,'time')
                            out.Acc.(af) = [a.Acc.(af); b.Acc.(af)];
                        else
                            out.Acc.(af).Data = [a.Acc.(af).Data; b.Acc.(af).Data];
                        end
                    end
                else
                    out.(fn).Time = [a.(fn).Time; b.(fn).Time];
                    out.(fn).Data = [a.(fn).Data; b.(fn).Data];
                end
            end
        end

        function [bridgeData,weatherData] = splitBridgeData(~,MergedStructData)
            weatherData = rmfield(MergedStructData,'Acc');

            Acc = MergedStructData.Acc;
            time = Acc.time;

            fnames  = fieldnames(rmfield(Acc,'time'));
            NSamples = numel(time);
            NFields = numel(fnames);
            dataMatrix = zeros(NSamples,NFields);
            units      = strings(1,NFields);

            for i = 1:NFields
                dataMatrix(:,i) = Acc.(fnames{i}).Data;
                if isfield(Acc.(fnames{i}),'Unit')
                    units(i) = string(Acc.(fnames{i}).Unit);
                else
                    units(i) = "";
                end
            end
            bridgeData = array2timetable(dataMatrix,...
                'RowTimes',time,...
                'VariableNames',fnames);

            bridgeData.Properties.VariableUnits = cellstr(units);
        end
    end

    methods (Access = private) % Cabledata Loading
        function cableData = loadCableData(self, startTime, endTime)
            % loadCableData Loads pre-processed cable .mat files and applies calibration
            cableDataRoot = fullfile(self.dataRoot, 'WSDA_data');
            filesToLoad = self.findCableMatFiles(cableDataRoot, startTime, endTime);

            if isempty(filesToLoad)
                warning('No cable data files found for the selected period.')
                cableData = timetable();
                return
            end

            cableData = self.loadAndFilterMatFiles(filesToLoad, startTime, endTime);

            if isempty(cableData)
                warning('No cable data records overlap the specific time interval.')
                return
            end

            cableData = applyCableCalibration(self, cableData);
            cableData = CableDataShift2GlbalCoords(cableData);
            cableData = BridgeProject.RemoveDuplicates(cableData);
        end

        function files = findCableMatFiles(~, folder, t0, t1)
            % findCableMatFiles Identifies relevant .mat files based on filename timestamps
            allFiles = dir(fullfile(folder, 'WSDA_*.mat'));
            if isempty(allFiles)
                files = [];
                return
            end

            pattern = 'WSDA_(\d{4}-\d{2}-\d{2})_[ap]m_(\d{6})_to_(\d{6})\.mat';
            matches = regexp({allFiles.name}, pattern, 'tokens', 'once');
            validIdx = ~cellfun(@isempty, matches);

            allFiles = allFiles(validIdx);
            matches = matches(validIdx);

            fileStarts = NaT(1, numel(allFiles));
            fileEnds = NaT(1, numel(allFiles));

            for i = 1:numel(matches)
                dateStr = matches{i}{1};
                startStr = matches{i}{2};
                endStr = matches{i}{3};

                fileStarts(i) = datetime([dateStr, ' ', startStr], 'InputFormat', 'yyyy-MM-dd HHmmss');
                fileEnds(i) = datetime([dateStr, ' ', endStr], 'InputFormat', 'yyyy-MM-dd HHmmss');
            end

            overlapMask = (fileEnds >= t0) & (fileStarts <= t1);
            files = allFiles(overlapMask);

            [~, sortIdx] = sort(fileStarts(overlapMask));
            files = files(sortIdx);
        end

        function combinedTable = loadAndFilterMatFiles(~, fileList, t0, t1)
            % loadAndFilterMatFiles Loads timetables from files and slices to the requested interval
            tables = cell(numel(fileList), 1);

            for i = 1:numel(fileList)
                fullPath = fullfile(fileList(i).folder, fileList(i).name);
                data = load(fullPath, 'sensorTimetable');

                tt = data.sensorTimetable;
                mask = (tt.Time >= t0) & (tt.Time <= t1);

                if any(mask)
                    tables{i} = tt(mask, :);
                end
            end

            nonEmpty = ~cellfun(@isempty, tables);
            if ~any(nonEmpty)
                combinedTable = timetable();
            else
                combinedTable = vertcat(tables{nonEmpty});
            end
        end

        function tt = applyCableCalibration(~,tt)
            varNames = tt.Properties.VariableNames;
            accVars  = varNames(contains(varNames,"_ch"));

            chunk = tt(:,accVars);
            bits  = chunk.Variables;
            ch    = strrm(strrep(accVars,'_',':'),'x');

            
            acc = calibration_glink(bits,ch); 
            
            % Calibration gives a unit of g's not m/s^2!
            acc = acc * 9.81; 

            tt(:,accVars) = array2table(acc, 'VariableNames', accVars);
            tt.Properties.VariableUnits(accVars) = "m/s^2";
        end
    end

    methods (Access = private) % Weatherdata Transforms
        function self = transformWeatherData(self)
            if isempty(self.weatherData)
                return
            end

            if isfield(self.weatherData, 'WindDir')
                self.weatherData = self.calculateStayAerodynamics(self.weatherData);
            end

            if isfield(self.weatherData, 'Precipitation')
                self.weatherData = self.processRainIntensity(self.weatherData);
            end
        end

        function weatherData = calculateStayAerodynamics(self, weatherData)
            %bridgeAzimuth = 360 - 18;
            bridgeAzimuth = 360;
            c1Inclination = 29.8;
            c2Inclination = 30.7;

            timeVector = weatherData.WindDir.Time;
            windAzimuth = weatherData.WindDir.Data;
            meanWindSpeed = weatherData.WindSpeed.Data;

            phiC1Data = self.calculateCableWindAngle(windAzimuth, c1Inclination, bridgeAzimuth);
            weatherData.PhiC1 = struct('Time', timeVector, 'Data', phiC1Data, 'Unit', 'deg');
            weatherData.UNormalC1 = struct('Time', timeVector, 'Data', meanWindSpeed .* sind(phiC1Data), 'Unit', 'm/s');

            phiC2Data = self.calculateCableWindAngle(windAzimuth, c2Inclination, bridgeAzimuth);
            weatherData.PhiC2 = struct('Time', timeVector, 'Data', phiC2Data, 'Unit', 'deg');
            weatherData.UNormalC2 = struct('Time', timeVector, 'Data', meanWindSpeed .* sind(phiC2Data), 'Unit', 'm/s');
        end

        function weatherData = processRainIntensity(~, weatherData)
            % processRainIntensity calculates 10-minute average rain intensity
            precipTime = weatherData.Precipitation.Time;
            precipData = weatherData.Precipitation.Data;

            binDuration = minutes(10);
            binStart = dateshift(precipTime(1), 'start', 'minute');
            binEnd = dateshift(precipTime(end), 'end', 'minute');
            binEdges = (binStart : binDuration : binEnd)';

            [~, ~, groups] = histcounts(precipTime, binEdges);

            newTime = binEdges(1:end-1) + binDuration/2;
            newIntensity = zeros(numel(newTime), 1);

            for i = 1:numel(newTime)
                groupMask = groups == i;
                if any(groupMask)
                    % Aligning with Jasna's note: 10 * mean(W2N)
                    calculatedValue = mean(precipData(groupMask), 'omitnan') * 10;

                    % Threshold to filter piezoelectric sensor noise/drift
                    if calculatedValue < 0.01
                        newIntensity(i) = 0;
                    else
                        newIntensity(i) = calculatedValue;
                    end
                end
            end

            weatherData.RainIntensity = struct('Time', newTime, 'Data', newIntensity, 'Unit', 'mm/h');
        end

        function cableWindAngle = calculateCableWindAngle(~, windAzimuth, inclinationAngle, bridgeAzimuth)
            yawAngle = windAzimuth - bridgeAzimuth;
            yawAngle = mod(yawAngle + 180, 360);% - 180;
            cableWindAngle = acosd(cosd(inclinationAngle) * cosd(yawAngle));
        end
    end

    methods (Access=private,Static) % Helper read cable functions
        function timeTable = readCableWindow(filePath, startTime, endTime)
            warning('off','MATLAB:table:ModifiedAndSavedVarnames');

            headerLineCount = BridgeProject.countHeaderLinesUntilDataStart(filePath);

            dataDatastore = datastore(filePath, ...
                "Type",              "tabulartext", ...
                "ReadVariableNames", true, ...
                "Delimiter",         ",");

            dataDatastore.NumHeaderLines = headerLineCount;
            dataDatastore.ReadSize = 5e5;

            previewTable = preview(dataDatastore);
            timeVariableName = previewTable.Properties.VariableNames{1};

            selectedTables = {};

            while hasdata(dataDatastore)
                dataChunk = read(dataDatastore);

                if ~isdatetime(dataChunk.(timeVariableName))
                    dataChunk.(timeVariableName) = datetime( ...
                        dataChunk.(timeVariableName), ...
                        "InputFormat", "MM/dd/yyyy HH:mm:ss.SSSSSSSSS");
                end

                timeMask = dataChunk.(timeVariableName) >= startTime & dataChunk.(timeVariableName) <= endTime;

                if any(timeMask)
                    selectedTables{end+1,1} = dataChunk(timeMask, :); %#ok<AGROW>
                end
            end

            if isempty(selectedTables)
                timeTable = timetable.empty;
            else
                mergedTable = vertcat(selectedTables{:});
                timeTable = table2timetable(mergedTable);
            end

        end
        function headerLineCount = countHeaderLinesUntilDataStart(filePath)
            fileId = fopen(filePath, "r");
            if fileId == -1
                error("Could not open file: %s", filePath);
            end

            headerLineCount = 0;
            cleanupObject = onCleanup(@() fclose(fileId));

            while true
                currentLine = fgetl(fileId);
                if ~ischar(currentLine)
                    headerLineCount = 0;
                    break;
                end

                headerLineCount = headerLineCount + 1;

                if contains(currentLine, "DATA_START")
                    break;
                end
            end
        end
        function timetableData = RemoveDuplicates(timetableData)
            [~, ia] = unique(timetableData.Time, 'stable');
            timetableData = timetableData(ia,:);
        end
    end
end

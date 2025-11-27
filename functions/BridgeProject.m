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
            if ischar(startTime) || isstring(startTime)
                startTime = datetime(startTime,'InputFormat','yyyy-MM-dd');
            end

            if ischar(endTime) || isstring(endTime)
                endTime = datetime(endTime, 'InputFormat', 'yyyy-MM-dd') + days(1) - milliseconds(1);
            end

            if nargin == 0
                warning('Not enough inputs')
                return
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
    end

    methods (Access = private)
        function [bridgeData,weatherData] = loadBridgeData(self, startTime, endTime)
            dates = allDatesBetween(startTime,endTime);
            self.rawFiles = FindLocalBridgeDataFiles(self.dataRoot, string(dates,'yyyy-MM-dd'));

            MergedStructData = loadAndMergeBridgeData(self);
            [bridgeData,weatherData] = splitBridgeData(self,MergedStructData);
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

    methods (Access = private)
        function cableData = loadCableData(self, startTime, endTime)
            cableDataRoot = fullfile(self.dataRoot,'WSDA_data');
            filesToLoad = findCableFilesInPeriod(self,cableDataRoot,startTime,endTime);
            cableData = loadAndAppendCableData(self,filesToLoad,startTime,endTime);
            if isempty(cableData)
                warning('No cabledata found for this time period')
                cableData = timetable(); return
            end
            cableData = applyCableCalibration(self,cableData);
            cableData = CableDataShift2GlbalCoords(cableData);
        end

        function files = findCableFilesInPeriod(~,cableDataRoot,startTime,endTime)
            if ischar(startTime) || isstring(startTime)
                startTime = datetime(startTime,'InputFormat','yyyy-MM-dd''T''HH:mm:ss');
            end
            if ischar(endTime) || isstring(endTime)
                endTime = datetime(endTime,'InputFormat','yyyy-MM-dd''T''HH:mm:ss');
            end

            files = dir(fullfile(cableDataRoot,'**','*.csv'));
            nFiles = numel(files);

            starts = NaT(1,nFiles);
            ends   = NaT(1,nFiles);

            for k = 1:nFiles
                fpath = fullfile(files(k).folder,files(k).name);
                [tStart,tEnd] = getFileSpan(fpath);
                starts(k) = tStart;
                ends(k)   = tEnd;
            end

            valid = ~isnat(starts) & ~isnat(ends);
            files  = files(valid);
            starts = starts(valid);
            ends   = ends(valid);

            mask = startTime <= ends & starts < endTime;
            files  = files(mask);
            starts = starts(mask);

            [~,idx] = sort(starts);
            files = files(idx);

            function [tStart,tEnd] = getFileSpan(csvPath)
                tStart = NaT;
                tEnd   = NaT; 
                errormessage = sprintf('Error checking file in: %s\n Returning empty times',csvPath);

                [status,out] = system(sprintf('head -n 50 "%s"', csvPath));
                if status ~= 0
                    warning(errormessage)
                    return
                end

                lines = splitlines(string(out));
                idx = find(strtrim(lines) == "DATA_START",1);
                if isempty(idx) || idx+2 > numel(lines)
                    warning(errormessage)
                    return
                end
                
                Num2EnsureCorrectDate = 1;
                while isnat(tStart) || tStart < datetime(2018,1,1)
                    Num2EnsureCorrectDate = Num2EnsureCorrectDate + 1;
                    firstDataLine = char(lines(idx+Num2EnsureCorrectDate));
                    commaPos = find(firstDataLine == ',',1,'first');
                    if isempty(commaPos)
                        warning(errormessage)
                        return
                    end
    
                    timeStr = strtrim(extractBefore(firstDataLine,commaPos));
                    try
                        tStart = datetime(timeStr,"InputFormat","MM/dd/yyyy HH:mm:ss.SSSSSSSSS");
                    catch
                        warning(errormessage)
                        tStart = NaT;
                        tEnd   = NaT;
                        return
                    end
                end

                [status,out] = system(sprintf('tail -n 1 "%s"', csvPath));
                if status ~= 0
                    tStart = NaT;
                    tEnd   = NaT;
                    warning(errormessage)
                    return
                end

                lastLine = strtrim(out);
                commaPos = find(lastLine == ',',1,'first');
                if isempty(commaPos)
                    tStart = NaT;
                    tEnd   = NaT;
                    return
                end

                timeStr = strtrim(extractBefore(lastLine,commaPos));
                try
                    tEnd = datetime(timeStr,"InputFormat","MM/dd/yyyy HH:mm:ss.SSSSSSSSS");
                catch
                    warning(errormessage)
                    tStart = NaT;
                    tEnd   = NaT;
                end
            end
        end


        function timeTable = loadAndAppendCableData(~, fileList, startTime, endTime)
            tableChunks = cell(numel(fileList), 1);
            warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');

            for idx = 1:numel(fileList)
                filePath = fullfile(fileList(idx).folder, fileList(idx).name);
                matFileVersion = strrep(filePath,'.csv','.mat');

                if exist(matFileVersion,"file")
                    rawTable = load(matFileVersion);
                    rawTable = rawTable.rawTable;
                else
                    importOpts = detectImportOptions(filePath);
                    importOpts = setvaropts(importOpts, 1, "InputFormat", "MM/dd/yyyy HH:mm:ss.SSSSSSSSS");
                    importOpts = setvartype(importOpts, 1, "datetime");
                    importOpts.VariableNamingRule = "modify";
    
                    rawTable = readtable(filePath, importOpts);
                    save(matFileVersion,'rawTable')
                end
                
                selectionMask = rawTable.(1) >= startTime & rawTable.(1) <= endTime;
                SelectedTable = rawTable(selectionMask, :);

                tableChunks{idx} = table2timetable(SelectedTable);
            end

            timeTable = vertcat(tableChunks{:});
            timeTable = sortrows(timeTable);
        end


        function files = addCableMeasurementPeriod(~,files)
            for k = 1:numel(files)
                f = fullfile(files(k).folder, files(k).name);

                tok = regexp(files(k).name, ...
                    '(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d+)', ...
                    'tokens','once');
                files(k).startTime = datetime(tok, ...
                    'InputFormat',"yyyy-MM-dd'T'HH-mm-ss.SSSSSS");

                [~,last] = system(sprintf('tail -n 1 "%s"',f));
                t1 = extractBefore(last,',');
                files(k).endTime = datetime(strtrim(t1), ...
                    'InputFormat',"MM/dd/yyyy HH:mm:ss.SSSSSSSSS");
            end
        end
        function tt = applyCableCalibration(~,tt)
            varNames = tt.Properties.VariableNames;
            accVars  = varNames(contains(varNames,"_ch"));

            chunk = tt(:,accVars);
            bits  = chunk.Variables;
            ch    = strrm(strrep(accVars,'_',':'),'x');

            acc = calibration_glink(bits,ch);

            tt(:,accVars) = array2table(acc, 'VariableNames', accVars);
            tt.Properties.VariableUnits(accVars) = "m/s^2";
        end

    end
end

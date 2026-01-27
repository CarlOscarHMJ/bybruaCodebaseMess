function T = processCompressedFile(datapath, file_compressed)
fullpath = fullfile(datapath, file_compressed);
fprintf('Now reading: %s, starttime %s', file_compressed,datestr(now,'HH.MM:SS'));
functionTime = tic;
try 
    gunzip(fullpath);
catch ME
    fprintf(' - Could not unzip file, return empty table. Error occurred: %s\n', ME.message);
    T = timetable;
    return
end

csv_path = strrep(fullpath, '.gz', '');

tbl = readtable(csv_path, 'Delimiter','|', 'ReadVariableNames',false, 'TextType','string');
tbl = checkAndReplaceSegments(tbl);
head = tbl.Var1; seg001 = tbl.Var2; seg002 = tbl.Var3; seg003 = tbl.Var4;

headParts = split(head, ",", 3);
timeStr  = headParts(:,1);
dateStr  = headParts(:,2);
flagStr  = strtrim(headParts(:,3));
Time = datetime(dateStr + " " + timeStr, "InputFormat","dd/MM/yyyy HH:mm:ss.SSS");

weather   = parseSegmentMatrix(seg001, 7);
accConc   = parseSegmentMatrix(seg002, 3);
accSteel  = parseSegmentMatrix(seg003, 3);

accConc   = 9.81*10^(-6)*accConc; % µg -> m/s^2
accSteel  = 9.81*10^(-6)*accSteel; 

varNames = [ ...
    "Wind_mps","WindDir_deg","AirTemp_degC","AirPress_bar","RelHum_pct","Weather_1","Weather_2", ...
    "AccConc_X_m/s^2","AccConc_Y_m/s^2","AccConc_Z_m/s^2", ...
    "AccSteel_X_m/s^2","AccSteel_Y_m/s^2","AccSteel_Z_m/s^2","RecordFlag"];

T = timetable(Time, ...
    weather(:,1), weather(:,2), weather(:,3), weather(:,4), weather(:,5), weather(:,6), weather(:,7), ...
    accConc(:,1), accConc(:,2), accConc(:,3), ...
    accSteel(:,1), accSteel(:,2), accSteel(:,3), ...
    flagStr, 'VariableNames', varNames);

T.Properties.VariableUnits = ["m/s","deg","degC","bar","%","","","m/s^2","m/s^2","m/s^2","m/s^2","m/s^2","m/s^2",""];

if exist(csv_path,'file'), delete(csv_path); end
Function_timing = toc(functionTime);
fprintf(', finished in %2.2f seconds\n',Function_timing)
end

function M = parseSegmentMatrix(segStrings, ncols)
clean = regexprep(segStrings, '^\s*\d+,\s*\d+,', '');
joined = strjoin(clean, newline);
C = textscan(char(joined), repmat('%f',1,ncols), 'Delimiter',',');
M = [C{:}];
end

function decimalDegrees = dms2deg(dmsString)
t = regexp(dmsString,'(\d+)°(\d+)''([\d\.]+)"\s*([NSEW])','tokens','once');
d = str2double(t{1}); m = str2double(t{2}); s = str2double(t{3}); h = t{4};
decimalDegrees = d + m/60 + s/3600;
if any(h == ['S','W']), decimalDegrees = -decimalDegrees; end
end

function tbl = checkAndReplaceSegments(tbl)
n = height(tbl);
standardWidth = [3,9,5,5];

idx = find(~strcmp(tbl.Properties.VariableTypes,"string"));

for i = 1:length(idx)
    id = idx(i);
    stw = standardWidth(id);
    tbl.(id) = join(repmat("0",n,stw),',');
end
end
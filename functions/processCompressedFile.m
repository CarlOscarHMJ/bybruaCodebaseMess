function T = processCompressedFile(datapath, file_compressed)
fullpath = fullfile(datapath, file_compressed);
fprintf('Now reading: %s\n', file_compressed);
gunzip(fullpath);

csv_path = strrep(fullpath, '.gz', '');
xml_path = strrep(csv_path, '.csv', '.xml');

hdr_raw = readstruct(xml_path, "FileType","xml");
H = hdr_raw; if isfield(hdr_raw,'header'), H = hdr_raw.header; end
H.latitude_decimal  = dms2deg(H.latitude);
H.longitude_decimal = dms2deg(H.longitude);

tbl = readtable(csv_path, 'Delimiter','|', 'ReadVariableNames',false, 'TextType','string');
head = tbl.Var1; seg001 = tbl.Var2; seg002 = tbl.Var3; seg003 = tbl.Var4;

headParts = split(head, ",", 3);
timeStr  = headParts(:,1);
dateStr  = headParts(:,2);
flagStr  = strtrim(headParts(:,3));
rowTimes = datetime(dateStr + " " + timeStr, "InputFormat","dd/MM/yyyy HH:mm:ss.SSS");

weather   = parseSegmentMatrix(seg001, 7);
accConc   = parseSegmentMatrix(seg002, 3);
accSteel  = parseSegmentMatrix(seg003, 3);

accConc   = 9.81*10^(-6)*accConc; % µg -> m/s^2
accSteel  = 9.81*10^(-6)*accSteel; 

varNames = [ ...
    "Wind_mps","WindDir_deg","AirTemp_degC","AirPress_bar","RelHum_pct","Weather_1","Weather_2", ...
    "AccConc_X_m/s^2","AccConc_Y_m/s^2","AccConc_Z_m/s^2", ...
    "AccSteel_X_m/s^2","AccSteel_Y_m/s^2","AccSteel_Z_m/s^2","RecordFlag"];

T = timetable(rowTimes, ...
    weather(:,1), weather(:,2), weather(:,3), weather(:,4), weather(:,5), weather(:,6), weather(:,7), ...
    accConc(:,1), accConc(:,2), accConc(:,3), ...
    accSteel(:,1), accSteel(:,2), accSteel(:,3), ...
    flagStr, 'VariableNames', varNames);

T.Properties.VariableUnits = ["m/s","deg","degC","bar","%","","","m/s^2","m/s^2","m/s^2","m/s^2","m/s^2","m/s^2",""];
T.Properties.UserData.Header = H;
T.Properties.UserData.SampleRate_Hz = str2double(H.samplerate);

if exist(csv_path,'file'), delete(csv_path); end
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

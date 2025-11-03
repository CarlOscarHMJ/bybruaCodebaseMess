function T = processCompressedFile_Lysefjord(data_folder, compressed_filename)
% processCompressedFile_Lysefjord
% Reads a gzipped CUSP-M CSV+XML pair from the Lysefjord bridge, discovers all
% populated channels and components from the XML, parses every CSV segment
% (001–032), converts accelerometer signals from micro-g to m/s^2, and returns a
% timetable with clear, non-abbreviated variable names and units.
tic
fullpath = fullfile(data_folder, compressed_filename);
fprintf('Now reading: %s, starttime %s', compressed_filename,datestr(now,'HH.MM:SS'));
gunzip(fullpath);
csv_path = strrep(fullpath, '.gz', '');
xml_path = strrep(csv_path, '.csv', '.xml');

raw_header = readstruct(xml_path, "FileType", "xml");
H = raw_header; if isfield(raw_header, 'header'), H = raw_header.header; end
H.latitude_decimal  = dms2deg(getField(H,'latitude'));
H.longitude_decimal = dms2deg(getField(H,'longitude'));
H.samplerate = getField(H,'samplerate');

tbl = readtable(csv_path, 'Delimiter','|', 'ReadVariableNames', false, 'TextType', 'string');
n_rows = height(tbl);

time_date_flag = split(tbl.Var1, ",", 3);
time_str = time_date_flag(:,1);
date_str = time_date_flag(:,2);
flag_str = strtrim(time_date_flag(:,3));
row_times = datetime(date_str + " " + time_str, "InputFormat", "dd/MM/yyyy HH:mm:ss.SSS");

T = timetable('RowTimes', row_times);

sensor_list = H.sensor; if ~iscell(sensor_list), sensor_list = {sensor_list}; end
channel_map = containers.Map('KeyType','char','ValueType','any');
for k = 1:numel(sensor_list{1})
    s = sensor_list{1}(k);
    ch_id = sprintf('%03d', (getField(s,'channel')));
    loc = getField(s,'location');
    typ = getField(s,'type');
    comps = strings(0); units = strings(0); nums = [];
    if isfield(s,'component') && any(~ismissing(s.component))
        cr = s.component; %if ~iscell(cr), cr = {cr}; end
        for j = 1:numel(cr)
            %c = cr{j};
            c = cr(j);
            nums(end+1)  = c.number; %#ok<AGROW>
            units(end+1) = c.units;              %#ok<AGROW>
            if isfield(c,'seedlinkchannelid')
                comps(end+1) = string(c.seedlinkchannelid); %#ok<AGROW>
            else
                comps(end+1) = "C"+string(c.number);        %#ok<AGROW>
            end
        end
    end
    channel_map(ch_id) = struct('channel', ch_id, 'location', string(loc), 'type', string(typ), ...
                                'components', comps, 'units', units, 'numbers', nums);
end

var_units = strings(0,1);

% Build an index: segment "001".."032" -> column + metadata
seg_index = containers.Map('KeyType','char','ValueType','any');
for col = 2:width(tbl)
    seg = tbl.(col); if ~isstring(seg), seg = string(seg); end
    nonempty = find(seg ~= "" & seg ~= "NaN", 1, 'first');
    if isempty(nonempty), continue; end
    t0 = split(seg(nonempty), ",");
    if numel(t0) < 1, continue; end
    seg_id = char(strtrim(t0(1)));
    if numel(seg_id) < 3 || any(~isstrprop(seg_id(1:3),'digit')), continue; end
    key = seg_id(1:3);
    if ~isKey(channel_map, key), continue; end
    if ~isKey(seg_index, key)
        meta = channel_map(key);
        seg_index(key) = struct('col', col, ...
                                'meta', meta, ...
                                'ncols', max(1, numel(meta.components)));
    end
end

% Iterate segments in numeric order (001,002,...)
seg_keys = seg_index.keys;
ord = sort(str2double(seg_keys));
seg_keys = compose('%03d', ord);

for kk = 1:numel(seg_keys)
    key = seg_keys{kk};
    if ~isKey(seg_index, key), continue; end
    info = seg_index(key);
    seg = tbl.(info.col);
    M = parseSegmentMatrix_vectorized(seg, info.ncols, n_rows);

    comp_labels = info.meta.components;
    comp_units  = info.meta.units;

    for j = 1:info.ncols
        base = compose("%s_%s_%s", "Ch"+info.meta.channel, strrep(info.meta.location," ",""), label_from_component(comp_labels, j));
        vn = matlab.lang.makeValidName(base);
        series = M(:, j);

        unit_j = pick_unit(comp_units, j);
        is_acc = strcmpi(unit_j, "ug") || endsWith(vn, ["_Acc_X","_Acc_Y","_Acc_Z"]);
        if is_acc && strcmpi(unit_j, "ug")
            series = 9.81e-6 * series;
            unit_j = "m/s^2";
        end

        vn = matlab.lang.makeUniqueStrings(vn, string(T.Properties.VariableNames));
        T.(vn) = series;
        var_units(end+1) = string(unit_j); %#ok<AGROW>
    end
end


T.RecordFlag = flag_str;
var_units(end+1) = "";
T.Properties.VariableUnits = pad_units_to_vars(T, var_units);
T.Properties.UserData.Header = H;
T.Properties.UserData.SampleRate_Hz = str2double(string(H.samplerate));

if exist(csv_path,'file'), delete(csv_path); end
fprintf(', finished in %2.2f seconds\n',toc)
end

function M = parseSegmentMatrix_vectorized(segStrings, ncols, n_rows)
M = NaN(n_rows, ncols);
valid = segStrings ~= "" & segStrings ~= "NaN";
if ~any(valid), return; end
payload = regexprep(segStrings(valid), '^[^,]*,[^,]*,', '');
joined = strjoin(payload, newline);
fmt = repmat('%f', 1, ncols);
C = textscan(char(joined), fmt, 'Delimiter', ',', 'CollectOutput', true, 'ReturnOnError', false);
A = C{1};
if isempty(A), return; end
if size(A,2) < ncols, A(:, end+1:ncols) = NaN; end
nv = nnz(valid);
if size(A,1) < nv, A(end+1:nv, :) = NaN; end
if size(A,1) > nv, A = A(1:nv, :); end
M(valid, :) = A;
end

function M = parseSegmentMatrix_rowwise(segStrings, ncols, n_rows)
M = NaN(n_rows, ncols);
for i = 1:n_rows
    s = strtrim(segStrings(i));
    if s=="" || s=="NaN", continue; end
    parts = split(s, ",");
    if numel(parts) <= 2, continue; end
    nums = str2double(parts(3:end));
    if isempty(nums), continue; end
    take = min(ncols, numel(nums));
    M(i,1:take) = nums(1:take);
end
end

function decimalDegrees = dms2deg(x)
if isstring(x), x = char(x); end
if isempty(x), decimalDegrees = NaN; return; end
t = regexp(x,'(\d+)°(\d+)''([\d\.]+)"\s*([NSEW])','tokens','once');
if isempty(t), decimalDegrees = NaN; return; end
d = str2double(t{1}); m = str2double(t{2}); s = str2double(t{3}); h = t{4};
decimalDegrees = d + m/60 + s/3600;
if any(h == ['S','W']), decimalDegrees = -decimalDegrees; end
end

function v = getField(s, name)
if isfield(s,name), v = s.(name); else, v = ""; end
if isstruct(v) && isfield(v,'Text'), v = v.Text; end
if iscell(v) && numel(v)==1, v = v{1}; end
end

function label = label_from_component(components, idx)
if isempty(components), label = sprintf('C%d', idx); return, end
cid = char(components(min(idx,numel(components))));
switch upper(cid)
    case {'D'}, label = 'WindDirection_deg';
    case {'H'}, label = 'HorizontalWindSpeed_mps';
    case {'V'}, label = 'VerticalWindSpeed_mps';
    case {'T'}, label = 'AirTemperature_degC';
    case {'P'}, label = 'AirPressure';
    case {'B'}, label = 'RelativeHumidity_pct';
    case {'A'}, label = 'Weather_A';
    case {'R'}, label = 'Weather_B';
    case {'X'}, label = 'Acc_X';
    case {'Y'}, label = 'Acc_Y';
    case {'Z'}, label = 'Acc_Z';
    case {'E'}, label = 'Extra_E';
    case {'N'}, label = 'GNSS_North_mm';
    case {'S'}, label = 'GNSS_Status';
    otherwise,  label = sprintf('C%s', cid);
end
end

function u = pick_unit(units_array, idx)
if isempty(units_array), u = ""; else, u = string(units_array(min(idx,numel(units_array)))); end
end

function units_full = pad_units_to_vars(T, units_in)
nv = width(T); units_full = strings(1, nv);
units_full(1:min(numel(units_in),nv)) = units_in(1:min(numel(units_in),nv));
end

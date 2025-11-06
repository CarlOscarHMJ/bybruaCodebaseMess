function BridgeData = ConvertDataTable2DataStruct(conf,OriginalDataTable)
% Converts data from readin to structtype data.
switch conf.structtype
    case 'Bybroa'
        BridgeData = convert2Bybroa(conf,OriginalDataTable);
    otherwise
        error('Thist structtype has not been implemented.')
end
end

function BridgeData = convert2Bybroa(conf,OriginalDataTable)

BridgeData = struct;

RawSamplingFreq = 50;

samplingRates = {0.2    'WindSpeed'         'm/s';
                 0.2    'WindDir'           'deg';
                 1/60   'AirTemp'           'degC';
                 1/60   'AirPress'          'hPa';
                 1/60   'RelHum'            '%';
                 1/10   'Precipitation'     'mm/h 1 min avg';
                 1/10   'Precipitation'     'mm over last minute';
                 50     'Conc_X'            'm/s^2';
                 50     'Conc_Y'            'm/s^2';
                 50     'Conc_Z'            'm/s^2';
                 50     'Steel_X'           'm/s^2';
                 50     'Steel_Y'           'm/s^2';
                 50     'Steel_Z'           'm/s^2';
                 NaN    'Flag'              'None'};
                

vars = OriginalDataTable.Properties.VariableNames;

for ii = 1:numel(vars)
    t = OriginalDataTable.Time;
    x = OriginalDataTable.(vars{ii});
    
    if ~isnan(samplingRates{ii,1}) 
        % Deciminate
        fac = RawSamplingFreq/samplingRates{ii,1};
        x = x(1:fac:end);
        t = t(1:fac:end);
    end

    if samplingRates{ii,1}~=50
        BridgeData.(samplingRates{ii,2}) = struct('Time', t, ...
                                                  'Data', x, ...
                                                  'Unit', samplingRates{ii,3});
    else
        BridgeData.Acc.time = t;
        BridgeData.Acc.(samplingRates{ii,2})  = struct('Data', x, ...
                                                       'Unit', samplingRates{ii,3});
    end
end
end
function [acc] = calibration_glink(acc_bits,ch)

% Apply the calibration to the accelerometers data
% Calibration coefficients for the Int32(2 Bytes) acceleration data [slope x bits + offset]
% NODE 4251
% ch1 (-3.8382e-06 x bits)-9.0846e-04
% ch2 (-3.8257e-06 x bits)-1.1726e-04
% ch3 (3.8652e-06 x bits)+1.8764e-02
% NODE 12045
% ch1 (-3.8639e-06 x bits)+3.3317e-03
% ch2 (-3.8655e-06 x bits)-7.6121e-03
% ch3 (3.9093e-06 x bits)-2.3324e-03
% NODE 12046
% ch1 (-3.8658e-06 x bits)+1.1072e-02
% ch2 (-3.8338e-06 x bits)+4.5859e-03
% ch3 (3.8532e-06 x bits)+1.2812e-02
% NODE 12047
% ch1 (-3.8334e-06 x bits)-3.3712e-03
% ch2 (-3.8125e-06 x bits)-1.0610e-03
% ch3 (3.7869e-06 x bits)+2.6447e-02

Nch = numel(ch); % number of channels
ch_names = {'4251:ch1'	'4251:ch2'	'4251:ch3'	'12045:ch1'	'12045:ch2'	'12045:ch3'	'12046:ch1'	'12046:ch2'	'12046:ch3'	'12047:ch1'	'12047:ch2'	'12047:ch3' };
slope = [-3.8382e-06 -3.8257e-06 3.8652e-06 -3.8639e-06 -3.8655e-06 3.9093e-06 -3.8658e-06 -3.8338e-06 3.8532e-06 -3.8334e-06 -3.8125e-06 3.7869e-06];
offset = [-9.0846e-04 -1.1726e-04 +1.8764e-02 +3.3317e-03 -7.6121e-03 -2.3324e-03 +1.1072e-02 +4.5859e-03 +1.2812e-02 -3.3712e-03 -1.0610e-03 +2.6447e-02];

for jj = 1:Nch
    indx = find(strcmp(ch(jj),ch_names)); % find the index corresponding to the vector ch_names
    acc(:,jj) = slope(indx).*cast(acc_bits(:,jj),'double')+offset(indx);
end

end
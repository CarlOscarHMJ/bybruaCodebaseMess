function [CableDataOut, BridgeDataOut] = ProcessBoth(CableDataIn,BridgeDataIn,fLow,fHigh,FsCable,FsBridge)
CableDataOut = ProcessCableData(CableDataIn, fLow, fHigh, FsCable);
BridgeDataOut = ProcessBridgeData(BridgeDataIn, fLow, fHigh, FsBridge);
end

function CableDataOut = ProcessCableData(CableDataIn, fLow, fHigh, Fs)
[b, a] = butter(2, [fLow fHigh] / (Fs/2), 'bandpass');
vars = CableDataIn.Properties.VariableNames(1:end);
CableDataOut = CableDataIn;
for i = 1:numel(vars)
    x = CableDataIn.(vars{i});
    x = inpaint_nans(x,3);
    x = detrend(x,'constant');
    x = filtfilt(b, a, x);
    CableDataOut.(vars{i}) = x;
end
end

function BridgeDataOut = ProcessBridgeData(BridgeDataIn, fLow, fHigh, Fs)
[b, a] = butter(2, [fLow fHigh] / (Fs/2), 'bandpass');
dirs = fieldnames(BridgeDataIn.Acc);
BridgeDataOut = BridgeDataIn;
for i = 2:numel(dirs)
    sensor = dirs{i};
    x = BridgeDataOut.Acc.(sensor).Data;
    x = inpaint_nans(x,3);
    x = detrend(x,'constant');
    x = filtfilt(b, a, x);
    BridgeDataOut.Acc.(sensor).Data = x;
end
end

function [BridgeDataOut,CableDataOut] = getTimePeriod(BridgeDataIn,CableDataIn,TimePeriod)
% BridgeData:
BridgeDataOut = BridgeDataIn;
t = BridgeDataIn.Acc.time;
fields = fieldnames(BridgeDataIn.Acc);
for ii = 2:length(fields)
    [x,tt] = selectTimeInterval(BridgeDataIn.Acc.(fields{ii}).Data,t,TimePeriod);
    BridgeDataOut.Acc.(fields{ii}).Data = x;
end
BridgeDataOut.Acc.time = tt;

% CableData:
Range = timerange(TimePeriod(1),TimePeriod(2));
CableDataOut = CableDataIn(Range,:);
end
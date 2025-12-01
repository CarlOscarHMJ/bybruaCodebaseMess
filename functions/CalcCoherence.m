function [Cxy,f,Pxx,Pyy,Pxy] = CalcCoherence(bridgeTime,bridgeData,cableTime,cableData,timePeriod,PlotCoherence)
% Calculates the co-coherence between the two signals ensuring that the
% lowest sampling rate is used
if exist("timePeriod","var")
    [bridgeData,bridgeTime] = selectTimeInterval(bridgeData,bridgeTime,timePeriod);
    [cableData,cableTime] = selectTimeInterval(cableData,cableTime,timePeriod);
else 
    PlotCoherence = false;
end

assert(abs(seconds(bridgeData(1) - cableData(1))) < 0.1, ...
    'The signals are misaligned: the first timestamps differ by more than 0.1 seconds.');

bridgeSampleFreq = getSampleFreq(bridgeTime);
cableSampleFreq  = getSampleFreq(cableTime);

cableData = resample(cableData,bridgeSampleFreq,cableSampleFreq);
Fs   = bridgeSampleFreq;
time = bridgeTime; % Approximate

N = min(length(cableData), length(bridgeData));
cableData = cableData(1:N);
bridgeData = bridgeData(1:N);

NMinutes = minutes(time(end)-time(1));
windowLength = min(floor(N/8),floor(N/NMinutes));
windowLength = max(windowLength, 256);
windowFunc   = hamming(windowLength);
overlapLen   = floor(windowLength*0.5);
nfftSize     = max(2^nextpow2(windowLength), 2^12);

[Pxx,~] = pwelch(bridgeData, windowFunc, overlapLen, nfftSize, Fs);
[Pyy,f] = pwelch(cableData,  windowFunc, overlapLen, nfftSize, Fs);
[Pxy,~] = cpsd(  cableData,  bridgeData, windowFunc, overlapLen, nfftSize, Fs);

Cxy = Pxy ./ sqrt(Pxx.*Pyy);

if PlotCoherence
    yyaxis left
    plot(f, abs(Cxy).^2,'DisplayName','Coherence')
    xlim([0 10])
    ylim([0 1])
    yyaxis('right');
    semilogy(f,Pxx,'-.','DisplayName','Cable response'); hold on
    semilogy(f,Pyy,'--','DisplayName','Bridge deck response')
end
end

function [x,t] = selectTimeInterval(x,t,Period)
assert(length(t) == length(x),'Data and time arrays should be of same length!')
idx = t >= Period(1) & ...
    t <= Period(2);
t = t(idx);
x = x(idx);
end

function samplFreq = getSampleFreq(t)
samplFreq = 1/median(diff(seconds(t-t(1))));
samplFreq = round(samplFreq);
end

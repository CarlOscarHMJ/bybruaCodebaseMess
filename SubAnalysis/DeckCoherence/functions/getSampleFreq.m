function samplFreq = getSampleFreq(t)
samplFreq = 1/median(diff(seconds(t-t(1))));
samplFreq = round(samplFreq);
end

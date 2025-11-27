clear all;
clc
fig=figure(1);clf;
theme(fig,"light")
Fs = 2000;
fLow  = 0.1;
fHigh = 50;
N     = 2;

Wn = [fLow fHigh] / (Fs/2);
[b,a]   = butter(N, Wn, 'bandpass');
[sos,g] = tf2sos(b,a);
numpoints = 2^15;
[H,f] = freqz(sos, numpoints, Fs);
H = g * H;

HdB = 20*log10(abs(H));
HdB = HdB - max(HdB);          % optional: normalize so peak is 0 dB

figure(1); clf;
semilogx(f, HdB, 'LineWidth', 1.2);
grid on
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title(['Butterworth Bandpass ' num2str(fLow) '-' num2str(fHigh) ' Hz']);

%xlim([0.01 500]);              % now you can see below 0.5 Hz
ylim([-40 5]);
exportgraphics(gcf,'figures/FilterDesign.pdf','ContentType','vector')
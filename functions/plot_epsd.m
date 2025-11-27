function [frequencies, epsdMatrix, segmentTimes, imageHandle] = plot_epsd(t, x, segmentDurationMinutes, newPlot)
%PLOT_EPSD Compute and optionally plot the evolutionary power spectral density (EPSD)
%   [frequencies, epsdMatrix, segmentTimes, imageHandle] = plot_epsd(t, x, segmentDurationMinutes, newPlot)
%
%   This function divides a time-series signal into equal-length segments 
%   of length segmentDurationMinutes and computes the Power Spectral Density
%   (PSD) of each segment using Welch's method. The PSDs form an EPSD matrix.
%   Time is kept visually as datetime labels on the x-axis. PSD is shown in linear units (m/s^2)^2/Hz.
%
%   INPUTS:
%       t  - Datetime vector (column) with timestamps
%       x  - Signal vector (column), same length as t (units: m/s^2)
%       segmentDurationMinutes - Segment length in minutes (e.g., 10)
%       newPlot - Logical:
%                true  -> create new figure with labels and colorbar
%                false -> plot in current axes only (no new figure, no labels)
%
%   OUTPUTS:
%       frequencies   - Frequency vector (Hz)
%       epsdMatrix    - EPSD matrix [nFreq x nSegments], units: (m/s^2)^2/Hz
%       segmentTimes  - Datetime for start of each segment
%       imageHandle   - Handle to imagesc object (only if requested)
%
%   Use newPlot = false for tiledlayout/subplot workflows.

arguments
    t (:,1) datetime
    x (:,1) double
    segmentDurationMinutes (1,1) double {mustBePositive}
    newPlot (1,1) logical = true
end

if numel(t) ~= numel(x)
    error("Time vector t and signal x must have the same length.")
end

timeSeconds = seconds(t - t(1));
sampleIntervals = diff(timeSeconds);
Fs = 1 / median(sampleIntervals);

segmentSamples = floor(Fs * segmentDurationMinutes * 60);
if segmentSamples < 2
    error("Segment length is too short relative to the sampling frequency.")
end

totalSamples = numel(x);
numSegments = floor(totalSamples / segmentSamples);
if numSegments < 1
    error("Not enough data for a single segment.")
end

xTrimmed = x(1:numSegments * segmentSamples);
xSegments = reshape(xTrimmed, segmentSamples, numSegments);

for k = 1:numSegments
    [Pxx, f] = pwelch(xSegments(:, k), [], [], [], Fs);
    if k == 1
        frequencies = f;
        epsdMatrix = zeros(numel(frequencies), numSegments);
    end
    epsdMatrix(:, k) = Pxx;
end

segmentTimes = t(1) + minutes(segmentDurationMinutes) * (0:numSegments-1);

timeNumeric = datenum(segmentTimes);  % numeric representation for imagesc

if newPlot
    figure
end

imageHandle = imagesc(timeNumeric, frequencies, log10(epsdMatrix));
set(gca, 'YDir', 'normal');

if newPlot
    xlabel("Time")
    ylabel("Frequency (Hz)")
    c = colorbar;
    c.Label.String = 'log_{10} PSD ((m/s^2)^2/Hz)';
    title(sprintf("Evolutionary Power Spectral Density (%d-min segments)", segmentDurationMinutes))
end

% Adding 23:59 tick
currentTicks = get(gca,'XTick');
newTicks = unique([currentTicks, datenum(t(end))]);
set(gca,'XTick', newTicks)

datetick('x','keeplimits')  % show datetime labels on x-axis

if nargout < 4
    clear imageHandle
end
end

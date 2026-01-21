function finalModalPeaks = autonomousPeakPicking(psdSignal)
    % Page 6, Column 2, Paragraph 5: Workflow for autonomous monitoring.
    % Page 7, Figure 5: Integration of M-AMPD and MAD-BS information.

    % --- Stage 1: Modified AMPD (Periodicity/Quasi-periodicity) ---
    % Page 6, Column 2, Paragraph 5: Extract periodic peak locations.
    periodicCandidateIndices = modifiedAmpd(psdSignal);

    % --- Stage 2: MAD following Baseline-Correction (Excitation) ---
    % Page 6, Column 2, Paragraph 5: Select well-excited peaks.
    excitedCandidateIndices = madBaselineCorrection(psdSignal);

    % --- Stage 3: Information Integration ---
    % Page 6, Column 2, Paragraph 5: Peaks overlapping in both methods are selected.
    % Page 7, Figure 5 [Step 3]: Integration of periodic and excited information.
    finalModalPeaks = intersect(periodicCandidateIndices, excitedCandidateIndices);
end

function excitedIndices = madBaselineCorrection(psdSignal)
    % Page 5, Column 1, Paragraph 1: Determining well-excited peaks as outliers.
    % Page 5, Column 2, Paragraph 1: Fully automated baseline estimation.
    
    % Page 14, Appendix 1, Figure A1: Original PSD augmented by padding.
    signalLength = length(psdSignal);
    paddingSize = 200; % Page 14, Appendix 1: Illustrative padding for edge effects.
    augmentedPsd = [ones(paddingSize,1)*psdSignal(1); psdSignal(:); ones(paddingSize,1)*psdSignal(end)];
    
    % Page 5, Column 2, Paragraph 3: Iterative smoothing to find baseline.
    % Page 15, Appendix 1, Figure A2: Procedure for baseline correction.
    % Page 6, Figure 4: PSD decomposition into baseline and corrected PSD.
    estimatedBaseline = smoothdata(augmentedPsd, 'sgolay', paddingSize); 
    correctedPsd = augmentedPsd - estimatedBaseline;
    
    % Remove padding to return to original signal space
    correctedPsd = correctedPsd(paddingSize + 1 : paddingSize + signalLength);
    
    % Page 5, Column 1, Equation 6: MAD is a robust measure of variability.
    medianValue = median(correctedPsd);
    medianAbsoluteDeviation = 1.4826 * median(abs(correctedPsd - medianValue));
    
    % Page 5, Column 1, Equation 7: Decision criterion for outliers (M_i > 3).
    % Page 5, Column 1, Paragraph 3: Samples with M_i > 3 are considered outliers.
    outlierScores = abs(correctedPsd - medianValue) / medianAbsoluteDeviation;
    excitedIndices = find(outlierScores > 3);
end

function periodicIndices = modifiedAmpd(psdSignal)
    % Page 2, Column 2, Paragraph 5
    numSamples = length(psdSignal);
    maxScale = ceil(numSamples / 2) - 1; % Page 2, Column 2, Equation 1

    % Page 3, Column 2, Paragraph 3: Padding trick for edge-effect problem.
    paddingValue = mean(psdSignal);
    augmentedPsd = [ones(maxScale, 1) * paddingValue; psdSignal(:); ones(maxScale, 1) * paddingValue];
    
    % Page 2, Column 2, Equation 2: Local Maxima Scalogram (LMS).
    numAug = length(augmentedPsd);
    lms = zeros(maxScale, numAug);
    for k = 1:maxScale
        for i = (k + 1):(numAug - k)
            if (augmentedPsd(i) > augmentedPsd(i-k)) && (augmentedPsd(i) > augmentedPsd(i+k))
                lms(k, i) = 0;
            else
                lms(k, i) = rand + 1;
            end
        end
    end

    % Page 4, Column 1, Paragraph 2: Remove padding from LMS.
    lms = lms(:, maxScale + 1 : maxScale + numSamples);
    
    % Page 2, Column 2, Equation 4: Row-wise summation.
    rowSums = sum(lms, 2);
    [~, lambda] = min(rowSums); % Page 3, Column 1: Optimal scale lambda.

    % Page 3, Column 1, Equation 5: Column-wise Standard Deviation.
    rescaledLms = lms(1:lambda, :);
    columnStd = std(rescaledLms);
    periodicIndices = find(columnStd == 0); % Page 3, Column 1: Standard deviation is zero.
end
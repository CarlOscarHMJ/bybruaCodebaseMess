function modalPeakIndices = modifiedAmpd(powerSpectralDensity)
    % modifiedAmpd: Fully automated peak-picking for stay-cable monitoring.
    % This function implements the M-AMPD algorithm based on multiscale 
    % local maxima scalogram analysis with edge-effect padding.
    % All citations are to the article:
    % Jin et al. (2021): "Fully automated peak-picking method for an
    % autonomous stay-cable monitoring system in cable-stayed bridges"

    % Page 2, Column 2, Paragraph 5 [cite: 90]
    signalLength = length(powerSpectralDensity);
    
    % Page 2, Column 2, Equation 1 [cite: 92]
    maximumScale = ceil(signalLength / 2) - 1; 

    % Page 3, Column 2, Paragraph 3 [cite: 188]
    % Page 4, Column 1, Paragraph 1 [cite: 255]
    paddingValue = mean(powerSpectralDensity); 
    
    % Page 3, Column 2, Paragraph 3 [cite: 188]
    % Page 14, Appendix 1, Figure A1 [cite: 1086]
    augmentedSignal = [ones(maximumScale, 1) * paddingValue; powerSpectralDensity(:); ones(maximumScale, 1) * paddingValue];
    augmentedLength = length(augmentedSignal);

    % Page 2, Column 2, Equation 2 [cite: 97]
    % Page 3, Figure 1 (b) [cite: 176]
    localMaximaScalogram = zeros(maximumScale, augmentedLength);
    for scaleK = 1:maximumScale
        for sampleI = (scaleK + 1):(augmentedLength - scaleK)
            % Page 2, Column 2, Equation 2 [cite: 97]
            if (augmentedSignal(sampleI) > augmentedSignal(sampleI - scaleK)) && (augmentedSignal(sampleI) > augmentedSignal(sampleI + scaleK))
                localMaximaScalogram(scaleK, sampleI) = 0; 
            else
                % Page 2, Column 2, Equation 2 [cite: 97]
                localMaximaScalogram(scaleK, sampleI) = rand + 1; 
            end
        end
    end

    % Page 4, Column 1, Paragraph 2 [cite: 258]
    localMaximaScalogram = localMaximaScalogram(:, maximumScale + 1 : maximumScale + signalLength);

    % Page 2, Column 2, Equation 4 [cite: 112]
    % Page 3, Figure 1 (c) [cite: 176]
    rowWiseSummation = sum(localMaximaScalogram, 2); 
    
    % Page 2, Column 2, Paragraph 6 [cite: 115]
    % Page 3, Figure 1 (d) [cite: 176]
    [~, optimalScaleLambda] = min(rowWiseSummation); 

    % Page 3, Column 1, Paragraph 1 [cite: 177]
    % Page 3, Figure 1 (e) [cite: 176]
    rescaledScalogram = localMaximaScalogram(1:optimalScaleLambda, :); 
    
    % Page 3, Column 1, Equation 5 [cite: 179]
    % Page 3, Figure 1 (f) [cite: 176]
    columnWiseStandardDeviation = std(rescaledScalogram); 

    % Page 3, Column 1, Paragraph 2 [cite: 184]
    modalPeakIndices = find(columnWiseStandardDeviation == 0);
end
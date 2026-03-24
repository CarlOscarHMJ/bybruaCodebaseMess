function plotDAuteuilComparison(allStats, flagField, flagName, cableInclinationAngle, figureFolder, csvFilePath, datastyle)
    arguments
        allStats
        flagField string
        flagName string
        cableInclinationAngle double
        figureFolder string = ''
        csvFilePath string = 'DAuteuil_Fig1_Data.csv'
        datastyle string = 'boxplot'
    end

    historicalDataTable = readtable(csvFilePath, 'TextType', 'string');
    comparisonFigure = createFigure(420, 'RWIV D''Auteuil Comparison');
    axesObject = axes(comparisonFigure);
    hold(axesObject, 'on');

    uniqueReferencesArray = unique(historicalDataTable.Reference);
    numberOfReferences = length(uniqueReferencesArray);
    
    legendHandlesArray = gobjects(0);
    legendLabelsArray = strings(0);

    for referenceIndex = 1:numberOfReferences
        currentReferenceName = uniqueReferencesArray(referenceIndex);
        referenceDataSubset = historicalDataTable(historicalDataTable.Reference == currentReferenceName, :);
        
        positiveObservationsSubset = referenceDataSubset(referenceDataSubset.RWIV_Observed == 1, :);
        negativeObservationsSubset = referenceDataSubset(referenceDataSubset.RWIV_Observed == 0, :);
        
        [currentMarkerStyle, currentMarkerColor] = getReferenceStyle(currentReferenceName);
        if strcmpi(currentReferenceName,'Bosdogianni and Olivari 1996')
            currentReferenceName = 'Bosdogianni and Olivari 1996\quad';
        end
        
        if height(positiveObservationsSubset) > 0
            positiveScatterHandle = scatter(axesObject, positiveObservationsSubset.Yaw_Angle_deg, positiveObservationsSubset.Inclination_Angle_deg, ...
                60, currentMarkerStyle, 'MarkerFaceColor', currentMarkerColor, 'MarkerEdgeColor', currentMarkerColor, ...
                'DisplayName', currentReferenceName);
            
            legendHandlesArray(end+1) = positiveScatterHandle;
            legendLabelsArray(end+1) = currentReferenceName;
        end
        
        if height(negativeObservationsSubset) > 0
            scatter(axesObject, negativeObservationsSubset.Yaw_Angle_deg, negativeObservationsSubset.Inclination_Angle_deg, ...
                60, currentMarkerStyle, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', currentMarkerColor, ...
                'HandleVisibility', 'off');
        end
    end

    flaggedEventsTable = allStats(allStats.(flagField), :);

    if height(flaggedEventsTable) > 0
        lookbackRainIntensityArray = calculateLookbackRain(flagField, allStats, hours(2));
        wetConditionIndicesArray = lookbackRainIntensityArray > 0;
        flaggedEventsTable = flaggedEventsTable(wetConditionIndicesArray, :);
    end

    if height(flaggedEventsTable) > 0
        % cableWindAngleMeanArray = [flaggedEventsTable.PhiC1.mean]';
        % 
        % cosineRatioArray = cosd(cableWindAngleMeanArray) ./ cosd(cableInclinationAngle);
        % cosineRatioArray = max(min(cosineRatioArray, 1), -1); 
        % calculatedYawAnglesArray = acosd(cosineRatioArray);
        
        rawYawAnglesArray = [flaggedEventsTable.WindDir.mean]';
        
        calculatedYawAnglesArray = {rawYawAnglesArray(rawYawAnglesArray < 180)-90,...
                                    (rawYawAnglesArray(rawYawAnglesArray > 180)-270)*(-1)};
        legendNames = {'Current Study ($\theta \approx 30^\circ$, SE winds)$\qquad$',...
                       'Current Study ($\theta \approx 30^\circ$, SW winds)$\qquad$'};

        studyColor = [0.55 0.77 0.94];
        lineStyles = {'--',':'};

        currentStudyGraphicsHandlesArray = gobjects(0);
        
        for i = 1:2
            if strcmpi(datastyle, 'boxplot')
                addBoxPlot(axesObject,lineStyles{i},...
                            studyColor,currentStudyGraphicsHandlesArray,...
                            cableInclinationAngle,calculatedYawAnglesArray{i},...
                            legendNames{i});
            elseif contains(datastyle, 'violin', 'IgnoreCase', true)
                addViolinPlot(axesObject,...
                                        lineStyles{i},studyColor,...
                                        currentStudyGraphicsHandlesArray,...
                                        cableInclinationAngle,...
                                        calculatedYawAnglesArray{i},...
                                        legendNames{i});
                uistack(currentStudyGraphicsHandlesArray, 'bottom');
            end
        end
    end

    grid(axesObject, 'on');
    box(axesObject, 'on');
    
    xlim(axesObject, [-50 90]);
    ylim(axesObject, [0 60]);
    set(axesObject, 'TickLabelInterpreter', 'latex');
    xlabel(axesObject, 'Yaw angle, $\beta$ (deg)', 'Interpreter', 'latex');
    ylabel(axesObject, 'Inclination angle, $\theta$ (deg)', 'Interpreter', 'latex');
    title(axesObject, sprintf('Criteria: \\texttt{%s}', strrep(flagName, '_', '\_')), 'Interpreter', 'latex');
    
    lg = legend('Interpreter', 'latex', 'Location', 'eastoutside','FontSize',8);

    figureSaveName = sprintf('DAuteuil_Comparison_%s', flagField);
    figureSaveName = strrep(figureSaveName, '\', '');
    saveFig(comparisonFigure,figureFolder,figureSaveName,2.7,1,lg)

    function addBoxPlot(axesObject,lineStyle,studyColor,...
                currentStudyGraphicsHandlesArray,cableInclinationAngle,calculatedYawAnglesArray, legendName)

        firstQuartileValue = prctile(calculatedYawAnglesArray, 25);
            thirdQuartileValue = prctile(calculatedYawAnglesArray, 75);
            medianValue = median(calculatedYawAnglesArray);
            minimumWhiskerValue = min(calculatedYawAnglesArray);
            maximumWhiskerValue = max(calculatedYawAnglesArray);
            
            boxHeightSpan = 1.5;
            lowerBoxEdgeY = cableInclinationAngle - (boxHeightSpan / 2);
            
            boxFillHandle = fill(axesObject, [firstQuartileValue thirdQuartileValue thirdQuartileValue firstQuartileValue], ...
                 [lowerBoxEdgeY lowerBoxEdgeY lowerBoxEdgeY+boxHeightSpan lowerBoxEdgeY+boxHeightSpan], ...
                 studyColor, 'FaceAlpha', 0.8, 'LineStyle',lineStyle, 'LineWidth', 1.5, ...
                 'DisplayName', legendName);
            currentStudyGraphicsHandlesArray(end+1) = boxFillHandle;
                 
            medianLineHandle = plot(axesObject, [medianValue medianValue], [lowerBoxEdgeY lowerBoxEdgeY+boxHeightSpan], ...
                 'Color', studyEdgeColor, 'LineWidth', 2.5, 'HandleVisibility', 'off');
            currentStudyGraphicsHandlesArray(end+1) = medianLineHandle;
                 
            whiskerLineOneHandle = plot(axesObject, [minimumWhiskerValue firstQuartileValue], [cableInclinationAngle cableInclinationAngle], ...
                 'Color', studyEdgeColor, 'LineWidth', 1.5, 'LineStyle', '--', 'HandleVisibility', 'off');
            currentStudyGraphicsHandlesArray(end+1) = whiskerLineOneHandle;
            
            whiskerLineTwoHandle = plot(axesObject, [thirdQuartileValue maximumWhiskerValue], [cableInclinationAngle cableInclinationAngle], ...
                 'Color', studyEdgeColor, 'LineWidth', 1.5, 'LineStyle', '--', 'HandleVisibility', 'off');
            currentStudyGraphicsHandlesArray(end+1) = whiskerLineTwoHandle;
                 
            whiskerCapOneHandle = plot(axesObject, [minimumWhiskerValue minimumWhiskerValue], [cableInclinationAngle-0.5 cableInclinationAngle+0.5], ...
                 'Color', studyEdgeColor, 'LineWidth', 1.5, 'HandleVisibility', 'off');
            currentStudyGraphicsHandlesArray(end+1) = whiskerCapOneHandle;
            
            whiskerCapTwoHandle = plot(axesObject, [maximumWhiskerValue maximumWhiskerValue], [cableInclinationAngle-0.5 cableInclinationAngle+0.5], ...
                 'Color', studyEdgeColor, 'LineWidth', 1.5, 'HandleVisibility', 'off');
            currentStudyGraphicsHandlesArray(end+1) = whiskerCapTwoHandle;
    end
    
    function addViolinPlot(axesObject,lineStyle,studyColor,...
                    currentStudyGraphicsHandlesArray,cableInclinationAngle,calculatedYawAnglesArray,legendName)
        
            [probabilityDensityArray, densityEvaluationPointsArray] = ksdensity(calculatedYawAnglesArray);
            
            maximumDensityValue = max(probabilityDensityArray);
            violinMaximumVerticalSpan = 5.0;
            scaledDensityArray = (probabilityDensityArray ./ maximumDensityValue) * (violinMaximumVerticalSpan / 2);
            
            upperViolinBoundaryY = cableInclinationAngle + scaledDensityArray;
            lowerViolinBoundaryY = cableInclinationAngle - scaledDensityArray;
            
            violinPolygonX = [densityEvaluationPointsArray, fliplr(densityEvaluationPointsArray)];
            violinPolygonY = [upperViolinBoundaryY, fliplr(lowerViolinBoundaryY)];
            
            violinFillHandle = fill(axesObject, violinPolygonX, violinPolygonY, studyColor, ...
                 'FaceAlpha', 0, 'LineWidth', 1.5, ...
                 'DisplayName', legendName,'LineStyle',lineStyle);
            currentStudyGraphicsHandlesArray(end+1) = violinFillHandle;
                 
            % firstQuartileValue = prctile(calculatedYawAnglesArray, 25);
            % thirdQuartileValue = prctile(calculatedYawAnglesArray, 75);
            % medianValue = median(calculatedYawAnglesArray);
            
            % quartileLineHandle = plot(axesObject, [firstQuartileValue thirdQuartileValue], [cableInclinationAngle cableInclinationAngle], ...
            %      'Color', studyEdgeColor, 'LineWidth', 3.0, 'HandleVisibility', 'off');
            % currentStudyGraphicsHandlesArray(end+1) = quartileLineHandle;
            % 
            % medianScatterHandle = scatter(axesObject, medianValue, cableInclinationAngle, 40, 'MarkerFaceColor', 'white', ...
            %         'MarkerEdgeColor', studyEdgeColor, 'LineWidth', 1.2, 'HandleVisibility', 'off');
            % currentStudyGraphicsHandlesArray(end+1) = medianScatterHandle;
    end

    function [markerStyle, markerColor] = getReferenceStyle(referenceName)
        switch referenceName
            case 'Bosdogianni and Olivari 1996'
                markerStyle = 'o';
                markerColor = [0.00, 0.45, 0.74];
            case 'Cosentino et al. 2013'
                markerStyle = 's';
                markerColor = [0.93, 0.69, 0.13];
            case 'Flamand 1995'
                markerStyle = '^';
                markerColor = [0.47, 0.67, 0.19];
            case 'Gao et al. 2018'
                markerStyle = 'v';
                markerColor = [0.30, 0.75, 0.93];
            case 'Ge et al. 2018'
                markerStyle = '<';
                markerColor = [0.64, 0.08, 0.18];
            case 'Georgakis et al. 2013'
                markerStyle = '>';
                markerColor = [0.85, 0.33, 0.10];
            case 'Gu and Du 2005'
                markerStyle = 'd';
                markerColor = [0.93, 0.69, 0.13];
            case 'Hikami and Shiraishi 1988'
                markerStyle = 'p';
                markerColor = [0.47, 0.67, 0.19];
            case 'Jing et al. 2018'
                markerStyle = 'o';
                markerColor = [0.64, 0.08, 0.18];
            case 'Katsuchi et al. 2017'
                markerStyle = 's';
                markerColor = [0.00, 0.45, 0.74];
            case 'Larose and Smitt 1999'
                markerStyle = '^';
                markerColor = [0.00, 0.00, 0.00];
            case 'Li et al. 2010'
                markerStyle = 'v';
                markerColor = [0.49, 0.18, 0.56];
            case 'Matsumoto et al. 1990'
                markerStyle = '<';
                markerColor = [0.50, 0.50, 0.00];
            case 'Vinayagamurthy et al. 2013'
                markerStyle = '>';
                markerColor = [0.30, 0.75, 0.93];
            case 'Zhan et al. 2018'
                markerStyle = 'd';
                markerColor = [0.00, 0.45, 0.74];
            otherwise
                markerStyle = 'o';
                markerColor = [0.50, 0.50, 0.50];
        end
    end
end

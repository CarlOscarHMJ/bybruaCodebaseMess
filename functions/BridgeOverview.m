classdef BridgeOverview
    properties
        project
        filter struct
    end

    methods (Access = public)           % Creation
        function self = BridgeOverview(project)
            self.project   = project;
        end
    end
    methods (Access = public)           % Filter functions
        function self = designFilter(self,method,opts)
            arguments
                self
                method (1,1) string = "all"
                opts.fLow (1,1) double = NaN
                opts.fHigh (1,1) double = NaN
                opts.samplingRate (1,1) double = NaN
                opts.order (1,1) double {mustBeInteger,mustBePositive} = 8
                opts.figNum (1,1) double {mustBeInteger,mustBeNonnegative} = 1
                opts.signalFreq double = []
                opts.signalResponse double = []
                opts.plotFilter (1,1) logical = false
            end

            method = lower(method);

            fs = self.defaultSamplingRate(opts.samplingRate);
            [fLow,fHigh] = self.defaultBand(fs,opts.fLow,opts.fHigh);
            orderMax = opts.order;

            nFreq = 2^15;
            [~,fGrid] = freqz(1,1,nFreq,fs);
            f = fGrid(:);

            if opts.plotFilter
                fig = figure(opts.figNum); clf;
                theme(fig,"light")

                [~,nexttileRowCol] = tiledlayoutRowCol(2,2,"TileSpacing","compact","Padding","compact");

                sigMagdB = [];
                if ~isempty(opts.signalFreq) && ~isempty(opts.signalResponse)
                    sigMagdB = 20*log10(abs(opts.signalResponse));
                end

                self.plotFilterFamily(nexttileRowCol(1,1),"butter",f,fs,fLow,fHigh,orderMax,sigMagdB,opts.signalFreq);
                self.plotFilterFamily(nexttileRowCol(1,2),"cheby" ,f,fs,fLow,fHigh,orderMax,sigMagdB,opts.signalFreq);
                self.plotFilterFamily(nexttileRowCol(2,1),"fir"   ,f,fs,fLow,fHigh,orderMax,sigMagdB,opts.signalFreq);
                self.plotSquareFilter(nexttileRowCol(2,2),f,fLow,fHigh,sigMagdB,opts.signalFreq);
            end

            if method == "all"
                return
            elseif method == "square"
                self.filter = self.buildSquareFilterStruct(fLow,fHigh,fs);
                return
            end

            [bSel,aSel,labelSel] = self.filterCoeffs(method,[fLow fHigh]/(fs/2),orderMax);
            self.filter = self.buildFilterStruct(labelSel,fLow,fHigh,fs,orderMax,bSel,aSel);
        end
        function self = applyFilter(self,fieldsToFilter,func)
            arguments
                self
                fieldsToFilter (1,:) string = ["bridgeData","cableData"]
                func = []
            end

            if isempty(func)
                if ~isfield(self.filter,'func') || isempty(self.filter.func)
                    error('BridgeOverview:FilterNotDefined', ...
                        'Filter is not defined. Use designFilter first.')
                end
                func = self.filter.func;
            end

            for field = fieldsToFilter(:).'
                if ~isprop(self.project,field)
                    continue
                end

                data = self.project.(field);

                if istimetable(data) || istable(data)
                    varNames = data.Properties.VariableNames;
                    for k = 1:numel(varNames)
                        v = data.(varNames{k});
                        if isnumeric(v)
                            data.(varNames{k}) = cast(func(double(v)),'like',v);
                        end
                    end
                    self.project.(field) = data;

                elseif isnumeric(data)
                    self.project.(field) = cast(func(double(data)),'like',data);
                end
            end
        end
        function self = fillMissingDataPoints(self,fieldsToFill,nanThreshold,method)
            arguments
                self
                fieldsToFill (1,:) string = ["bridgeData","cableData"]
                nanThreshold (1,1) double = 0.02
                % methods {0,1,2} use a simple plate metaphor.
                % method  3 uses a better plate equation,
                %         but may be much slower and uses
                %         more memory.
                % method  4 uses a spring metaphor.
                % method  5 is an 8 neighbor average, with no
                %         rationale behind it compared to the
                %         other methods. I do not recommend
                %         its use.
                method = 1
            end

            interpFunc = @(x) inpaint_nans(x,method);

            for field = fieldsToFill(:).'
                if ~isprop(self.project,field)
                    continue
                end

                data = self.project.(field);

                if istimetable(data) || istable(data)
                    varNames = data.Properties.VariableNames;
                    for k = 1:numel(varNames)
                        values = data.(varNames{k});
                        if isnumeric(values)
                            nanRatio = sum(isnan(values(:))) / numel(values);
                            if nanRatio > nanThreshold
                                error('BridgeOverview:TooManyNaNs', ...
                                    '%s.%s exceeds NaN threshold (%.2f%% > %.2f%%)', ...
                                    field, varNames{k}, nanRatio*100, nanThreshold*100)
                            end
                            if any(isnan(values(:)))
                                data.(varNames{k}) = cast(interpFunc(double(values)),'like',values);
                            end
                        end
                    end
                    self.project.(field) = data;

                elseif isnumeric(data)
                    nanRatio = sum(isnan(data(:))) / numel(data);
                    if nanRatio > nanThreshold
                        error('BridgeOverview:TooManyNaNs', ...
                            '%s exceeds NaN threshold (%.2f%% > %.2f%%)', ...
                            field, nanRatio*100, nanThreshold*100)
                    end
                    if any(isnan(data(:)))
                        self.(field) = cast(interpFunc(double(data)),'like',data);
                    end
                else
                    error('Function has not been fit to work with this data type')
                end
            end
        end
    end
    methods (Access = public)           % Plotting functions
        function plotTimeHistory(self, SignalOutput, TimePeriod,plotMode)
            % SignalOutput = 'acceleration', 'velocity', 'displacement'
            arguments
                self
                SignalOutput = 'acceleration'
                TimePeriod   = []
                plotMode     = 'normal'
            end

            try
                checkForNaNs(self);
            catch ME
                warning(ME.message);
                return
            end


            if strcmpi(plotMode,'Vertical')
                BridgeOverview.plotTimeHistoryVertical(self.project.bridgeData, ...
                    self.project.cableData, ...
                    TimePeriod, SignalOutput);
            else
                BridgeOverview.plotTime(self.project.bridgeData, ...
                    self.project.cableData, ...
                    TimePeriod, SignalOutput);
            end
        end
        function plotEpsdHistory(self, segmentDurationMinutes,TimePeriod)
            if nargin < 2
                segmentDurationMinutes = 10;
            end

            if nargin < 3
                TimePeriod = [];
            end

            try
                checkForNaNs(self);
            catch ME
                warning(ME.message);
                return
            end

            BridgeOverview.plotEPSD(self.project.bridgeData, ...
                self.project.cableData, ...
                TimePeriod, segmentDurationMinutes);
        end
        function plotCablePhaseSpace(self, TimePeriod)
            if nargin < 2
                TimePeriod = [];
            end

            try
                checkForNaNs(self);
            catch ME
                warning(ME.message);
                return
            end

            BridgeOverview.plotCablePhaseSpaceStatic(self.project.bridgeData, ...
                self.project.cableData, TimePeriod);
        end
        function plotFrequencyResponse(self, TimePeriod, method, opts)
            arguments
                self
                TimePeriod = []
                method (1,1) string {mustBeMember(method, ["welch", "fft"])} = "welch"
                opts.windowSec (1,1) double = 60
                opts.overlapPct (1,1) double = 50
                opts.fMax (1,1) double = 15
                opts.bridgeDirs (1,:) string = ["X", "Y", "Z"]
                opts.cableDirs (1,:) string = ["x", "y"]
            end

            try
                self.checkForNaNs();
            catch ME
                warning(ME.message);
                return
            end

            BridgeOverview.plotFrequencyVertical(self.project.bridgeData, ...
                self.project.cableData, ...
                TimePeriod, method, opts);
        end
        function [Cxy,f,Pxx,Pyy,Pxy] = coherence(self, deckField, cableField, timePeriod, plotCoherence)
            if nargin < 5
                plotCoherence = false;
            end
            if nargin < 4
                timePeriod = [];
            end

            try
                checkForNaNs(self);
            catch ME
                warning(ME.message);
                return
            end

            bridgeTime = self.project.bridgeData.Time;
            bridgeData = self.project.bridgeData.(deckField);

            cableTime  = self.project.cableData.Time;
            cableData  = self.project.cableData.(cableField);

            [Cxy,f,Pxx,Pyy,Pxy] = CalcCoherence( ...
                bridgeTime, bridgeData, ...
                cableTime,  cableData, ...
                timePeriod, plotCoherence);
        end
        function [peakFreq,coherenceVal,response] = plotHeaveCoherence(self, cableField, selectedTimePeriod, opts)
            %plotHeaveCoherence Plot heave coherence and return peak and queried values
            arguments
                self
                cableField
                selectedTimePeriod
                opts.fLow (1,1) double = 0
                opts.fHigh (1,1) double = 10
                opts.Npeaks (1,1) double = 5
                opts.queryFreq double = []
            end

            fLow  = opts.fLow;
            fHigh = opts.fHigh;
            queryFreq = opts.queryFreq;

            fig = figure(3); clf;
            theme(fig,"light")
            [t, nexttileRowCol] = tiledlayoutRowCol(2,3,"TileSpacing","compact","Padding","compact");

            DeckPos = {'Conc_','Steel_'};

            peakFreq     = cell(1,2);
            coherenceVal = cell(1,2);

            response = struct( ...
                'deckPos',      [], ...
                'deckField',    [], ...
                'cableField',   [], ...
                'peakFreq',     [], ...
                'cohAtPeaks',   [], ...
                'queryFreq',    [], ...
                'deckAtQuery',  [], ...
                'cableAtQuery', [], ...
                'cohAtQuery',   [], ...
                'gammaAtQuery', [], ...
                'rhoAtQuery',   [] ...
                );

            for ii = 1:2
                deckField = [DeckPos{ii} 'Z'];

                [Cxy,f,Pxx,Pyy,~] = self.coherence(deckField, cableField, selectedTimePeriod, false);

                response(ii).deckPos    = DeckPos{ii}(1:end-1);
                response(ii).deckField  = deckField;
                response(ii).cableField = char(cableField);

                nexttileRowCol(ii,1,'ColSpan',2);
                yyaxis left
                semilogy(f,Pxx,'DisplayName',[DeckPos{ii}(1:end-1) '$-z$']);
                hold on
                semilogy(f,Pyy,'DisplayName',[char(cableField) '']);
                ylabel('$S_{\ddot{\hat{y}}}$ or $S_{\ddot{z}}$ $\mathrm{((m/s^2)^2)/Hz}$','Interpreter','latex','FontSize',14)

                yyaxis right
                plot(f,abs(Cxy).^2,'DisplayName','$|\mathit{coh}|^2$')
                ylabel(['$|\mathit{coh}(f,\Delta Z_{\mathrm{' DeckPos{ii}(1:end-1) '}}, \Delta \hat{y}_{\mathrm{' char(cableField) '}})|^2$'], ...
                    'Interpreter','latex','FontSize',14)
                ylim([0 1])
                xlim([fLow fHigh])
                xticks([fLow 1:fHigh])

                PeakFindingIdx = (fLow <= f) & (f <= fHigh);
                [peakVal,peakFreqTmp] = findpeaks(abs(Cxy(PeakFindingIdx)).^2, ...
                    f(PeakFindingIdx),'MinPeakHeight',0.2);

                [peakValSorted,idx] = sort(peakVal,'descend');
                nUse = min(opts.Npeaks,numel(peakValSorted));

                peakFreq{ii}     = peakFreqTmp(idx(1:nUse));
                coherenceVal{ii} = peakValSorted(1:nUse);

                response(ii).peakFreq   = peakFreq{ii};
                response(ii).cohAtPeaks = coherenceVal{ii};

                xl = xline(peakFreq{ii},'--k','Alpha',0.2,'LineWidth',2);
                PeakFreqLegends = arrayfun(@(x,y) sprintf('$|coh(%.2f)|^2=%.2f$',x,y), ...
                    peakFreq{ii},coherenceVal{ii}, 'UniformOutput', false);
                set(xl,{'DisplayName'},PeakFreqLegends(:))

                legend('Interpreter','latex','FontSize',12)
                ax = gca;
                ax.XGrid = 'on';

                nexttileRowCol(ii,3);
                plot(f,real(Cxy),'--','DisplayName',['$\gamma_{z\hat{y}}(f,\Delta Z_{\mathrm{' DeckPos{ii}(1:end-1) '}}, \Delta \hat{Y}_{\mathrm{' char(cableField) '}})$'])
                hold on
                plot(f,imag(Cxy),'-.','DisplayName',['$\rho_{z\hat{y}}(f,\Delta Z_{\mathrm{' DeckPos{ii}(1:end-1) '}}, \Delta \hat{Y}_{\mathrm{' char(cableField) '}})$'])
                xline(peakFreq{ii},'--k','Alpha',0.2,'LineWidth',2,'HandleVisibility','off');
                ylim([-1 1])
                xlim([0 fHigh])
                xticks(1:fHigh)
                legend('Interpreter','latex','FontSize',12)
                grid on

                if ~isempty(queryFreq)
                    qf = queryFreq(:);
                    idxQuery = arrayfun(@(fq) find(abs(f - fq) == min(abs(f - fq)),1,'first'), qf);

                    fqClosest   = f(idxQuery);
                    deckClosest = Pxx(idxQuery);
                    cableClosest = Pyy(idxQuery);
                    CxyClosest  = Cxy(idxQuery);

                    response(ii).queryFreq    = fqClosest(:).';
                    response(ii).deckAtQuery  = deckClosest(:).';
                    response(ii).cableAtQuery = cableClosest(:).';
                    response(ii).cohAtQuery   = abs(CxyClosest(:).').^2;
                    response(ii).gammaAtQuery = real(CxyClosest(:).');
                    response(ii).rhoAtQuery   = imag(CxyClosest(:).');
                end
            end

            xlabel(t,'$f$ (Hz)','Interpreter','latex','FontSize',14)
            title(t,['Coherence between deck and ' ...
                strrep(char(cableField),'_','\_') ...
                ' between ' ...
                char(selectedTimePeriod(1)) ' and ' ...
                char(selectedTimePeriod(2),'HH:mm:SS')],...
                'Interpreter','latex','Fontsize',16)
        end
        function plotEventValidation(self,ylimits)
            arguments
                self
                ylimits = 'off';
            end

            weather = self.project.weatherData;
            cableData = self.project.cableData;
            cableGroups = findCableGroups(cableData.Properties.VariableNames);
            cables = cableGroups(:,1);

            colorBlue = [0.45 0.55 0.95];
            colorTeal = [0.40 0.75 0.70];
            colorRain = [0.53 0.83 0.96];
            colorC1W  = [0.65 0.85 0.65];
            colorC2W  = [0.50 0.50 0.50];
            markerSize = 60;

            uTable = retime(timetable(weather.WindSpeed.Time, weather.WindSpeed.Data), 'regular', @mean, 'TimeStep', minutes(10));
            phiTable = retime(timetable(weather.PhiC1.Time, weather.PhiC1.Data), 'regular', @mean, 'TimeStep', minutes(10));

            figure(12);clf
            theme('light')
            tLayout = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

            ax1 = nexttile;
            yyaxis left
            scatter(uTable.Time, uTable.Var1, markerSize, colorBlue, 'filled', ...
                'MarkerFaceAlpha', 0.4, 'MarkerEdgeAlpha', 0.6);
            ylabel('$\bar{u}$ (m/s)', 'Interpreter', 'latex', 'Color', colorBlue);
            set(gca, 'YColor', colorBlue);
            if strcmpi(ylimits,'on')
                ylim([0 20]);
            end

            yyaxis right
            scatter(phiTable.Time, phiTable.Var1, markerSize, colorTeal, 'filled', ...
                'MarkerFaceAlpha', 0.4, 'MarkerEdgeAlpha', 0.6);
            ylabel('$\Phi$ ($^\circ$)', 'Interpreter', 'latex', 'Color', colorTeal);
            set(gca, 'YColor', colorTeal);
            grid on;

            ax2 = nexttile;
            scatter(weather.RainIntensity.Time, weather.RainIntensity.Data, markerSize, colorRain, 'filled', ...
                'MarkerFaceAlpha', 0.3, 'MarkerEdgeAlpha', 0.5);
            ylabel('Rain (mm/h)', 'Interpreter', 'latex');
            if strcmpi(ylimits,'on')
                ylim([0 6]);
            end
            grid on;

            ax3 = nexttile;
            hold on;
            for i = 1:numel(cables)
                cableName = cables{i};
                varName = [cableName, '_y'];

                if strcmp(cableName, 'C1W')
                    c = colorC1W;
                elseif strcmp(cableName, 'C2W')
                    c = colorC2W;
                else
                    c = [0.2 0.2 0.2];
                end

                heaveTable = cableData(:, varName);
                rmsTable = retime(heaveTable, 'regular', @rms, 'TimeStep', minutes(10));

                scatter(rmsTable.Time, rmsTable.(varName), markerSize, c, 'filled', ...
                    'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.7, 'DisplayName', cableName);
            end
            ylabel('$\sigma_{\ddot{r}_y}$ (m/s$^2$)', 'Interpreter', 'latex');
            legend('Location', 'northeast');
            if strcmpi(ylimits,'on')
                ylim([0 20]);
            end
            grid on;

            linkaxes([ax1, ax2, ax3], 'x');
            xtickformat('HH:mm');

            startTimeStr = char(self.project.startTime, 'yyyy-MM-dd');
            endTimeStr = char(self.project.endTime, 'yyyy-MM-dd');
            title(tLayout, ['Event Validation: ' startTimeStr ' to ' endTimeStr], ...
                'Interpreter', 'latex', 'FontSize', 12);
        end
        function freqInfo = plotRwivDiagnostic(self, cableField, timePeriod, opts)
            % plotRwivDiagnostic evaluates and plots bridge and cable response diagnostics.
            %
            % Keyboard shortcuts (when figure is active):
            %   SPACE   - Toggle between PSD (welch) and spectrogram (stft) mode
            %   X/Y/Z   - Switch to X, Y, or Z direction
            %   S       - Save figure to disk
            %
            arguments
                self
                cableField string = ""
                timePeriod = []
                opts.deckFields (1,:) string = ["Conc_Z", "Steel_Z"]
                opts.periodogramSensor (1,1) string {mustBeMember(opts.periodogramSensor, ["Conc", "Steel"])} = "Conc"
                opts.fMax (1,1) double = 10
                opts.windowSec (1,1) double = 60
                opts.overlapPct (1,1) double = 50
                opts.nfft (1,1) double = 256
                opts.stftWindowSec (1,1) double = 20
                opts.coherenceType (1,1) string {mustBeMember(opts.coherenceType, ["wavelet", "normal"])} = "normal"
                opts.freqMethod (1,1) string {mustBeMember(opts.freqMethod, ["welch", "burg", "stft"])} = "welch"
                opts.burgOrder (1,1) double = 50
                opts.plotTitle {mustBeTextScalar} = ""
                opts.figureFolder string = ""
            end

            tic

            if isempty(timePeriod)
                timePeriod = [self.project.startTime, self.project.endTime];
            end

            timeFilter = timerange(timePeriod(1), timePeriod(2));
            bridgeData = self.project.bridgeData(timeFilter, :);

            hasCableData = cableField ~= "" && ~isempty(self.project.cableData);
            if hasCableData
                cableData = self.project.cableData(timeFilter, :);
                if isempty(cableData)
                    hasCableData = false;
                end
            else
                cableData = [];
            end

            weatherData = filterWeatherData(self.project.weatherData, timePeriod);

            fig = createFigure(7, 'RWIV Dashboard');

            persistent periodogramContext displayMode windSourceGlobal;
            periodogramContext = struct( ...
                'bridgeData', bridgeData, ...
                'cableData', cableData, ...
                'cableField', cableField, ...
                'deckFields', opts.deckFields, ...
                'fMax', opts.fMax, ...
                'windowSec', opts.windowSec, ...
                'overlapPct', opts.overlapPct, ...
                'nfft', opts.nfft, ...
                'stftWindowSec', opts.stftWindowSec, ...
                'hasCable', hasCableData, ...
                'freqMethod', opts.freqMethod, ...
                'burgOrder', opts.burgOrder, ...
                'currentSensor', opts.periodogramSensor, ...
                'currentDirection', 'Z', ...
                'figureFolder', opts.figureFolder, ...
                'plotTitle', opts.plotTitle ...
            );
            displayMode = opts.freqMethod;
            windSourceGlobal = true;

            set(fig, 'KeyPressFcn', @(src, event) onKeyPress(event));

            tl = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

            plotEnvironmentalConditions(weatherData);
            plotTimeHistory(bridgeData, cableData, cableField, opts.deckFields, hasCableData);

            if strcmpi(displayMode, "stft")
                [freqInfo.freqResp,ax] = plotPeriodogram(periodogramContext.currentSensor);
                title(ax, sprintf('STFT Periodogram: %s %s (%s - SPACE:mode X/Y/Z:direction S:save)', periodogramContext.currentSensor, periodogramContext.currentDirection, displayMode), 'FontSize', 10);
            else
                [freqInfo.freqResp,ax] = plotFrequencyResponse(periodogramContext.currentSensor);
                title(ax, sprintf('Frequency Response (%s %s - SPACE:mode X/Y/Z:direction S:save)', displayMode, periodogramContext.currentDirection), 'FontSize', 10);
            end

            if strcmpi(opts.coherenceType, "wavelet")
                plotWaveletCoherence(bridgeData, cableData, cableField, opts.deckFields, opts.fMax, hasCableData);
                freqInfo.coCoherence = struct;
            else
                freqInfo.coCoherence = plotFullCoherence(bridgeData, cableData, cableField, opts.deckFields, ...
                    opts.fMax, opts.windowSec, opts.overlapPct, opts.nfft, hasCableData);
            end

            if strlength(opts.plotTitle) > 0
                title(tl, opts.plotTitle);
            end

            fprintf('Finished Diagnostics plot in %3.1f seconds\n', toc);

            bridgeTimeLimits = [bridgeData.Time(1), bridgeData.Time(end)];

            allAxes = findobj(gcf, 'Type', 'axes');
            datetimeAxes = allAxes(arrayfun(@(ax) isa(ax.XLim(1), 'datetime'), allAxes));
            if ~isempty(datetimeAxes)
                %linkaxes(flip(datetimeAxes),'x'); 
                linkprop(datetimeAxes,'XLim');
            end

            function onKeyPress(event)
                ctx = periodogramContext;
                needsUpdate = false;

                if strcmp(event.Key, 'space')
                    if strcmpi(displayMode, "stft")
                        displayMode = "welch";
                    else
                        displayMode = "stft";
                    end
                    needsUpdate = true;
                elseif any(strcmp(event.Key, {'x', 'y', 'z'}))
                    periodogramContext.currentDirection = upper(event.Key);
                    needsUpdate = true;
                elseif strcmp(event.Key, 's')
                    saveFigure(ctx);
                end

                if needsUpdate
                    ax = nexttile(4);
                    cla(ax, 'reset');
                    hold(ax, 'on');
                    if strcmpi(displayMode, "stft")
                        plotPeriodogram(ctx.currentSensor);
                    else
                        plotFrequencyResponse(ctx.currentSensor);
                    end
                    uistack(ax, 'top');
                    directionLabel = periodogramContext.currentDirection;
                    title(ax, sprintf('Frequency Response (%s %s - SPACE:mode X/Y/Z:direction S:save)', displayMode, directionLabel), 'FontSize', 10);
                    drawnow;
                end
            end

            function saveFigure(ctx)
                if strlength(ctx.figureFolder) > 0
                    if ~exist(ctx.figureFolder, 'dir')
                        mkdir(ctx.figureFolder);
                    end
                    cableStr = strrep(char(ctx.cableField), '_', '');
                    titleStr = strrep(char(ctx.plotTitle), ' ', '_');
                    titleStr = strrep(titleStr, ':', '');
                    fileName = sprintf('Rwiv_%s_%s_%s_%s.png', cableStr, ctx.currentSensor, ctx.currentDirection, titleStr);
                    savePath = fullfile(ctx.figureFolder, fileName);
                    exportgraphics(gcf, savePath, 'Resolution', 300);
                    fprintf('Saved: %s\n', savePath);
                end
            end

            function filteredWeather = filterWeatherData(weather, timeRange)
                % filterWeatherData restricts weather timetables to the specified time period.
                filteredWeather = weather;
                weatherFields = fieldnames(filteredWeather);
                for idx = 1:numel(weatherFields)
                    fieldName = weatherFields{idx};
                    currentField = filteredWeather.(fieldName);
                    if isstruct(currentField) && isfield(currentField, 'Time')
                        timeMask = currentField.Time >= timeRange(1) & currentField.Time <= timeRange(2);
                        filteredWeather.(fieldName).Time = currentField.Time(timeMask);
                        filteredWeather.(fieldName).Data = currentField.Data(timeMask);
                    end
                end
            end

            function [freqResp,ax] = plotPeriodogram(sensorName)
                % plotPeriodogram computes and visualizes the STFT spectrogram.
                persistent freqRespStore;
                ctx = periodogramContext;
                targetField = sensorName + "_" + ctx.currentDirection;

                ax = nexttile(4);
                cla(ax, 'reset');
                hold(ax, 'on');

                if ctx.hasCable
                    fs = 1 / median(diff(seconds(ctx.cableData.Time - ctx.cableData.Time(1))));
                    winSamples = round(ctx.stftWindowSec * fs);
                    overlapSamples = round(winSamples * (ctx.overlapPct / 100));

                    [~, fAxis, tAxis, pAxis] = spectrogram(double(ctx.cableData.(ctx.cableField)), hamming(winSamples), overlapSamples, ctx.nfft, fs);
                    pAxis(pAxis <= 0) = eps;
                    imagesc(ax, tAxis, fAxis, log(pAxis));
                    freqResp.(ctx.cableField).time = tAxis;
                    freqResp.(ctx.cableField).frequency = fAxis;
                    freqResp.(ctx.cableField).response = log(pAxis);
                    plotLabel = strrep(ctx.cableField, '_', ' ');
                else
                    fs = 1 / median(diff(seconds(ctx.bridgeData.Time - ctx.bridgeData.Time(1))));
                    winSamples = round(ctx.stftWindowSec * fs);
                    overlapSamples = round(winSamples * (ctx.overlapPct / 100));

                    [~, fAxis, tAxis, pAxis] = spectrogram(double(ctx.bridgeData.(targetField)), hamming(winSamples), overlapSamples, ctx.nfft, fs);
                    pAxis(pAxis <= 0) = eps;
                    imagesc(ax, tAxis, fAxis, log(pAxis));
                    freqResp.(targetField).time = tAxis;
                    freqResp.(targetField).frequency = fAxis;
                    freqResp.(targetField).response = log(pAxis);
                    plotLabel = strrep(targetField, '_', ' ');
                end

                axis(ax, 'xy');
                axis(ax, 'tight');
                ylim(ax, [0 ctx.fMax]);
                colormap(ax, jet);

                cBar = colorbar(ax);
                cBar.Label.String = 'log(m^2 s^{-4} Hz^{-1})';
                cBar.Label.Interpreter = 'tex';

                ylabel(ax, 'Frequency (Hz)', 'Interpreter', 'latex');
                xlabel(ax, 'Time (s)', 'Interpreter', 'latex');
                title(ax, sprintf('STFT Periodogram: %s', plotLabel), 'Interpreter', 'latex');

                addCableFrequencyLinesStft(ax);
                freqRespStore = freqResp;
            end

            function addCableFrequencyLinesStft(ax)
                % addCableFrequencyLinesStft overlays modal frequencies on the Y-axis for STFT.
                cableFreqsC1 = [1.03, 2.08, 3.10, 4.15, 5.13, 6.16, 7.32, 8.30, 9.30];
                deckFreqsC1 = [1.83, 3.52, 5.15];
                cableFreqsC5 = [3.00, 4.60, 5.40, 6.10, 7.60, 9.20];
                deckFreqsC5 = [1.24, 2.93, 6.03, 6.11];

                targetModes = [cableFreqsC1(3), cableFreqsC1(6)];
                freqTolerance = 0.10;

                plotFrequencyBandsStft(ax, targetModes, freqTolerance, [0.85 0.85 0.85], 0.5, 'Tolerance Interval');
                plotHorizontalLines(ax, cableFreqsC1, '--', [0 0 0], 0.3, 'C1 Nat. Freq.');
                plotHorizontalLines(ax, deckFreqsC1, '-', [0.85 0.33 0.1], 0.2, 'C1 Deck Modes');
                plotHorizontalLines(ax, cableFreqsC5, ':', [0.2 0.2 0.2], 0.5, 'C5 Nat. Freq.');
                plotHorizontalLines(ax, deckFreqsC5, '-', [0 0.447 0.741], 0.2, 'C5 Deck Modes');
            end

            function plotFrequencyBandsStft(ax, centerFreqs, tolerance, bandColor, bandAlpha, displayName)
                % plotFrequencyBandsStft adds horizontal tolerance regions.
                if isempty(centerFreqs)
                    return;
                end
                for i = 1:numel(centerFreqs)
                    yReg = yregion(ax, centerFreqs(i) - tolerance, centerFreqs(i) + tolerance, ...
                        'FaceColor', bandColor, 'FaceAlpha', bandAlpha, 'EdgeColor', 'none');
                    if i == 1
                        yReg.DisplayName = displayName;
                    else
                        yReg.HandleVisibility = 'off';
                    end
                    uistack(yReg, 'bottom');
                end
            end

            function plotHorizontalLines(ax, frequencies, lineStyle, lineColor, lineAlpha, displayName)
                % plotHorizontalLines adds horizontal reference lines.
                if isempty(frequencies)
                    return;
                end
                lineObjects = yline(ax, frequencies, lineStyle, 'Color', lineColor, 'Alpha', lineAlpha, 'LineWidth', 1.5);
                lineObjects(1).DisplayName = displayName;
                if numel(lineObjects) > 1
                    set(lineObjects(2:end), 'HandleVisibility', 'off');
                end
                uistack(lineObjects, 'bottom');
            end

            function plotEnvironmentalConditions(weather)
                plotRainAndAirDensity(nexttile(1), weather);
                plotWindSpeedAndDirection(nexttile(3), weather);
                nexttile(5);
                plotTurbulenceWindRose(weather);
            end

            function plotRainAndAirDensity(ax, weather)
                axes(ax);
                yyaxis left
                plot(weather.RainIntensity.Time, weather.RainIntensity.Data, 'o-', 'Color', [0.3 0.6 1]);
                ylabel('Rain (mm/h)');
                title('Environmental Conditions');
                grid on;
                ylim([0 inf]);

                yyaxis right
                plot(weather.AirTemp.Time, weather.AirTemp.Data, 's-', ...
                    'Color', [0.85 0.33 0.1], 'MarkerFaceColor', [0.85 0.33 0.1]);
                ylabel('Temperature ($^\circ$C)');
                axis tight;
            end

            function plotWindSpeedAndDirection(ax, weather)
                persistent windGlobal;
                axes(ax);
                
                if isempty(windGlobal)
                    windGlobal = true;
                end
                
                updateWindPlot();
                
                function updateWindPlot()
                    cla(ax, 'reset');
                    hold(ax, 'on');
                    
                    if windGlobal
                        yyaxis left
                        plot(weather.WindSpeed.Time, weather.WindSpeed.Data);
                        ylabel('Compass wind speed $U$ (m/s)', 'Interpreter', 'latex');

                        yyaxis right
                        scatter(weather.WindDir.Time, weather.WindDir.Data, 15, 'filled', 'MarkerFaceAlpha', 0.3);
                        ylabel('Compass wind direction $\Phi\, (^\circ)$', 'Interpreter', 'latex', 'FontSize', 12);
                        grid on;
                        title('Wind angle (click to toggle C1/global)');
                    else
                        yyaxis left
                        plot(weather.UNormalC1.Time, weather.UNormalC1.Data);
                        ylabel('Wind Speed $\bar{u}_N$ (m/s)', 'Interpreter', 'latex');

                        yyaxis right
                        scatter(weather.PhiC1.Time, weather.PhiC1.Data, 15, 'filled', 'MarkerFaceAlpha', 0.3);
                        ylabel('Wind Direction $\Phi\, (^\circ)$', 'Interpreter', 'latex', 'FontSize', 12);
                        grid on;
                        title('Wind angle on C1 (click to toggle C1/global)');
                    end
                    
                    axis tight;
                    set(ax, 'ButtonDownFcn', @(src,~) toggleWindSource());
                end
                
                set(ax, 'ButtonDownFcn', @(src,~) toggleWindSource());
                
                function toggleWindSource()
                    windGlobal = ~windGlobal;
                    updateWindPlot();
                end
            end

            function plotTurbulenceWindRose(weather)
                tiTable = calculateTurbulenceIntensity(weather.WindSpeed);
                windSpeedTable = retime(timetable(weather.WindSpeed.Time, weather.WindSpeed.Data), ...
                    'regular', @mean, 'TimeStep', minutes(10));
                windDirTable = retime(timetable(weather.WindDir.Time, weather.WindDir.Data), ...
                    'regular', @mean, 'TimeStep', minutes(10));

                meanWindDir = windDirTable.Var1;
                meanWindSpeed = windSpeedTable.Var1;
                turbulenceIntensity = tiTable.Var1;
                
                if isscalar(meanWindDir)
                    Ylim = [0 meanWindSpeed*1.1];
                else
                    Ylim = [0 max(meanWindSpeed)];
                end

                [~, colorBarHandle] = ScatterWindRose(meanWindDir, meanWindSpeed, ...
                    'Z', turbulenceIntensity, ...
                    'labelZ', '', ...
                    'labelY', '$\bar{u}$ (m/s)',...
                    'Ylim', Ylim);

                set(colorBarHandle, 'location', 'WestOutside', 'TickLabelInterpreter', 'latex');
                ylabel(colorBarHandle, '$I_u$ (-)', 'Interpreter', 'latex', ...
                    'Rotation', 0, 'HorizontalAlignment', 'right', 'FontSize', 12);

                bridgeHeading = 342;
                maxRadialVelocity = max(meanWindSpeed, [], 'omitnan');
                bridgeAngleRad = deg2rad(90 - bridgeHeading);
                [xAxis, yAxis] = pol2cart([bridgeAngleRad, bridgeAngleRad + pi], [maxRadialVelocity, maxRadialVelocity]);

                hold on;
                plot(xAxis, yAxis, 'k', 'LineWidth', 3, 'HandleVisibility', 'off');
            end

            function turbIntensityTable = calculateTurbulenceIntensity(windData)
                windTable = timetable(windData.Time, windData.Data);
                windowSize = minutes(10);
                meanWind = retime(windTable, 'regular', @mean, 'TimeStep', windowSize);
                stdWind = retime(windTable, 'regular', @std, 'TimeStep', windowSize);

                tiValues = stdWind.Var1 ./ meanWind.Var1;
                tiValues(meanWind.Var1 < 5) = NaN;

                turbIntensityTable = meanWind;
                turbIntensityTable.Var1 = tiValues;
            end

            function plotTimeHistory(bTable, cTable, cField, dFields, hasCable)
                ax = nexttile(2);
                hold on;
                if hasCable
                    hCable = plot(cTable.Time, cTable.(cField), 'LineWidth', 1.1, 'DisplayName', strrep(cField, '_', ' '));
                end

                titleStr = 'Time History (click sensor to update frequency plot)';
                
                stdVals = zeros(length(dFields),1);
                for k = 1:length(dFields)
                    field = dFields(k);
                    stdVals(k) = std(bTable.(field));
                end
                
                [~,idx]= sort(stdVals,'descend');

                for k = 1:length(idx)
                    field = dFields(idx(k));
                    sensorName = extractBefore(field, '_');
                    hSensor = plot(bTable.Time, bTable.(field), 'DisplayName', strrep(field, '_', ' '), ...
                        'ButtonDownFcn', @(src,~) onSensorClick(sensorName));
                    src.LineWidth = 2;
                    src.Marker = 'none';
                end

                ylabel('Acc. (m/s$^2$)');
                title(titleStr);
                grid on;
                legend('Location', 'northeast');
                axis tight;
            end

            function onSensorClick(sensorName)
                periodogramContext.currentSensor = sensorName;
                ctx = periodogramContext;
                ax = nexttile(4);
                cla(ax, 'reset');
                hold(ax, 'on');
                if strcmpi(displayMode, "stft")
                    plotPeriodogram(sensorName);
                else
                    plotFrequencyResponse(sensorName);
                end
                uistack(ax, 'top');
                directionLabel = periodogramContext.currentDirection;
                if strcmpi(displayMode, "stft")
                    title(ax, sprintf('STFT Periodogram: %s %s (%s - SPACE:mode X/Y/Z:direction S:save)', sensorName, directionLabel, displayMode), 'FontSize', 10);
                else
                    title(ax, sprintf('Frequency Response (%s %s - SPACE:mode X/Y/Z:direction S:save)', displayMode, directionLabel), 'FontSize', 10);
                end
                drawnow;
            end

            function [freqResp,ax] = plotFrequencyResponse(sensorName)
                ctx = periodogramContext;

                ax = nexttile(4);
                cla(ax, 'reset');
                hold(ax, 'on');
                freqResp = struct;

                if ctx.hasCable
                    fsC = 1 / median(diff(seconds(ctx.cableData.Time - ctx.cableData.Time(1))));
                    [pC, fC] = pwelch(double(ctx.cableData.(ctx.cableField)), hamming(round(ctx.windowSec*fsC)), round(ctx.windowSec*fsC*ctx.overlapPct/100), ctx.nfft, fsC);
                    semilogy(ax, fC, pC, 'LineWidth', 1.2, 'DisplayName', strrep(ctx.cableField, '_', ' '));
                end

                fsB = 1 / median(diff(seconds(ctx.bridgeData.Time - ctx.bridgeData.Time(1))));
                fieldsToPlot = ctx.deckFields;
                if strcmpi(displayMode, "stft")
                    fieldsToPlot = sensorName + "_" + ctx.currentDirection;
                else
                    fieldsToPlot = arrayfun(@(f) extractBefore(f, '_') + "_" + ctx.currentDirection, ctx.deckFields, 'UniformOutput', false);
                    fieldsToPlot = string(fieldsToPlot);
                end

                for k = 1:length(fieldsToPlot)
                    field = fieldsToPlot(k);
                    if strcmpi(ctx.freqMethod, "burg")
                        [pB, fB] = pburg(double(ctx.bridgeData.(field)), ctx.burgOrder, ctx.nfft, fsB);
                    else
                        [pB, fB] = pwelch(double(ctx.bridgeData.(field)), hamming(round(ctx.windowSec*fsB)), round(ctx.windowSec*fsB*ctx.overlapPct/100), ctx.nfft, fsB);
                    end

                    semilogy(ax, fB, pB, 'DisplayName', strrep(field, '_', ' '));
                    freqResp.(field).frequency = fB;
                    freqResp.(field).response = pB;

                    if strcmpi(ctx.freqMethod, "burg")
                        try
                            logPsd = log(pB);
                            relIdx = fB >= 0.4 & fB <= ctx.fMax;
                            [peaks, locs] = findpeaks(logPsd(relIdx), fB(relIdx), 'MinPeakProminence', 4);
                            if ~isempty(locs)
                                peakVals = arrayfun(@(x) pB(find(abs(fB - x) < 1e-6, 1)), locs);
                                plot(ax, locs, peakVals, '^', 'Color', 'r', 'MarkerSize', 5, 'MarkerFaceColor', 'r', ...
                                    'HandleVisibility','off');
                                freqResp.(field).peaks.locations = locs;
                                freqResp.(field).peaks.intensity = peaks;
                            end
                        catch
                            freqResp.(field).peaks = struct('locations', [], 'intensity', []);
                        end
                    else
                        freqResp.(field).peaks = struct('locations', [], 'intensity', []);
                    end
                end

                xlim([0 ctx.fMax]);
                grid on;
                ylabel('PSD ((m/s$^2$)$^2$/Hz)');
                xlabel('Freq. (Hz)');
                title(ax, sprintf('Frequency Response (%s)', ctx.freqMethod));
                legend(ax, 'Location', 'northeast');
                set(ax, 'YScale', 'log')
                addCableFrequencyLines();
            end

            function coCoherence = plotFullCoherence(deckTable, cableTable, cableField, deckFields, fLimit, windowSeconds, overlapPercent, Nfft, hasCable)
                nexttile(6);
                hold on;
                coCoherence = struct;

                % 1. Cable-Deck Coherence (Only if cable data is available)
                if hasCable
                    fsDeck = 1 / median(diff(seconds(deckTable.Time - deckTable.Time(1))));
                    fsCable = 1 / median(diff(seconds(cableTable.Time - cableTable.Time(1))));
                    commonFs = min(fsDeck, fsCable);
                    t1 = max(deckTable.Time(1), cableTable.Time(1));
                    t2 = min(deckTable.Time(end), cableTable.Time(end));
                    commonTime = (t1 : seconds(1 / commonFs) : t2)';

                    cableSub = retime(cableTable(:, cableField), commonTime, 'linear');
                    windowLength = round(windowSeconds * commonFs);
                    overlapSamples = round(windowLength * overlapPercent / 100);

                    for k = 1:length(deckFields)
                        deckField = deckFields(k);
                        deckSub = retime(deckTable(:, deckField), commonTime, 'linear');
                        [gamma, f] = calculateCoCoherence(deckSub.(deckField), cableSub.(cableField), windowLength, overlapSamples, Nfft, commonFs);
                        displayName = sprintf('\\gamma: %s - %s', strrep(cableField, '_', ' '), strrep(deckField, '_', ' '));
                        plot(f, gamma, 'LineWidth', 1.2, 'DisplayName', displayName);
                        coCoherence.(deckField).gamma = gamma;
                        coCoherence.(deckField).frequency = f;
                    end
                end

                % 2. Deck-Deck Coherence (Runs regardless of cable data availability)
                if length(deckFields) > 1
                    fsDeck = 1 / median(diff(seconds(deckTable.Time - deckTable.Time(1))));
                    windowLengthDeck = round(windowSeconds * fsDeck);
                    overlapSamplesDeck = round(windowLengthDeck * overlapPercent / 100);

                    for k = 1:length(deckFields)
                        for j = k+1:length(deckFields)
                            fieldA = deckFields(k);
                            fieldB = deckFields(j);
                            [gammaDeck, fDeck] = calculateCoCoherence(deckTable.(fieldA), deckTable.(fieldB), windowLengthDeck, overlapSamplesDeck, Nfft, fsDeck);
                            displayName = sprintf('\\gamma: %s - %s', strrep(fieldA, '_', ' '), strrep(fieldB, '_', ' '));
                            plot(fDeck, gammaDeck, '--', 'LineWidth', 1.0, 'DisplayName', displayName);
                            structName = fieldA + "2" + fieldB;
                            coCoherence.(structName).gamma = gammaDeck;
                            coCoherence.(structName).frequency = fDeck;
                        end
                    end
                end

                formatCoherencePlot(fLimit);
                addCableFrequencyLines();
            end

            function [gamma, f] = calculateCoCoherence(sigA, sigB, nWin, nOver, Nfft, fs)
                [Pxy, f] = cpsd(double(sigA), double(sigB), hamming(nWin), nOver, Nfft, fs);
                [Pxx, ~] = pwelch(double(sigA), hamming(nWin), nOver, Nfft, fs);
                [Pyy, ~] = pwelch(double(sigB), hamming(nWin), nOver, Nfft, fs);
                gamma = real(Pxy ./ sqrt(Pxx .* Pyy));
            end

            function formatCoherencePlot(fLimit)
                xlim([0 fLimit]);
                ylim([-1 1]);
                grid on;
                xlabel('Freq. (Hz)');
                ylabel('Co-coherence');
                legend('Location', 'northeast', 'Interpreter', 'tex', 'FontSize', 8);
                title('Co-coherence Analysis');
            end

            function addCableFrequencyLines()
                cableFreqsC1 = [1.03, 2.08, 3.10, 4.15, 5.13, 6.16, 7.32, 8.30, 9.30];
                deckFreqsC1 = [1.83, 3.52, 5.15];

                cableFreqsC5 = [3.00, 4.60, 5.40, 6.10, 7.60, 9.20];
                deckFreqsC5 = [1.24, 2.93, 6.03, 6.11];

                targetModes = [cableFreqsC1(3), cableFreqsC1(4) cableFreqsC1(6)];
                freqTolerance = 0.15;

                plotFrequencyBands(targetModes, freqTolerance, [0.85 0.85 0.85], 0.5, 'Tolerance Interval');

                plotVerticalLines(cableFreqsC1, '--', [0 0 0], 0.3, 'C1 Nat. Freq.');
                plotVerticalLines(deckFreqsC1, '-', [0.85 0.33 0.1], 0.2, 'C1 Deck Modes');

                plotVerticalLines(cableFreqsC5, ':', [0.2 0.2 0.2], 0.5, 'C5 Nat. Freq.');
                plotVerticalLines(deckFreqsC5, '-', [0 0.447 0.741], 0.2, 'C5 Deck Modes');
            end

            function plotFrequencyBands(centerFreqs, tolerance, bandColor, bandAlpha, displayName)
                if isempty(centerFreqs)
                    return;
                end

                for i = 1:numel(centerFreqs)
                    xReg = xregion(centerFreqs(i) - tolerance, centerFreqs(i) + tolerance, ...
                        'FaceColor', bandColor, ...
                        'FaceAlpha', bandAlpha, ...
                        'EdgeColor', 'none');

                    if i == 1
                        xReg.DisplayName = displayName;
                    else
                        xReg.HandleVisibility = 'off';
                    end
                    uistack(xReg, 'bottom');
                end
            end

            function plotVerticalLines(frequencies, lineStyle, lineColor, lineAlpha, displayName)
                if isempty(frequencies)
                    return;
                end

                lineObjects = xline(frequencies, lineStyle, ...
                    'Color', lineColor, ...
                    'Alpha', lineAlpha, ...
                    'LineWidth', 1.5);

                lineObjects(1).DisplayName = displayName;

                if numel(lineObjects) > 1
                    set(lineObjects(2:end), 'HandleVisibility', 'off');
                end

                uistack(lineObjects, 'bottom');
            end

            function plotWaveletCoherence(bTable, cTable, cField, dFields, fLimit, hasCable)
                nexttile(6);

                if hasCable
                    fsB = 1 / median(diff(seconds(bTable.Time - bTable.Time(1))));
                    fsC = 1 / median(diff(seconds(cTable.Time - cTable.Time(1))));
                    resampleFs = min(fsB, fsC);
                    t1 = max(bTable.Time(1), cTable.Time(1));
                    t2 = min(bTable.Time(end), cTable.Time(end));
                    commonTime = (t1 : seconds(1/resampleFs) : t2)';

                    sig1 = retime(bTable(:, dFields(1)), commonTime, 'linear').(dFields(1));
                    sig2 = retime(cTable(:, cField), commonTime, 'linear').(cField);
                    titleStr = sprintf('Wavelet: %s - %s', strrep(dFields(1), '_', ' '), strrep(cField, '_', ' '));
                elseif length(dFields) > 1
                    resampleFs = 1 / median(diff(seconds(bTable.Time - bTable.Time(1))));
                    commonTime = bTable.Time;
                    sig1 = bTable.(dFields(1));
                    sig2 = bTable.(dFields(2));
                    titleStr = sprintf('Wavelet: %s - %s', strrep(dFields(1), '_', ' '), strrep(dFields(2), '_', ' '));
                else
                    title('Insufficient signals for Wavelet');
                    return;
                end

                [wcoh, ~, fVec, coi] = wcoherence(sig1, sig2, resampleFs);
                imagesc(commonTime, fVec, wcoh);
                set(gca, 'YDir', 'normal');
                hold on;

                fill([commonTime(1); commonTime(:); commonTime(end)], [0; coi(:); 0], ...
                    'w', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
                plot(commonTime, coi, 'w--', 'LineWidth', 1.5);

                ylim([0 fLimit]);
                ylabel('Freq. (Hz)');
                colorbar;
                title(titleStr);
            end
        end
        function mustBePowerOfTwo(value)
            % Validates if a number is a power of 2 using bitwise comparison.
            if mod(log2(value), 1) ~= 0
                error('Input nfft must be a power of 2 (e.g., 1024, 2048, 65536).');
            end
        end
    end
    methods (Access = private)          % Filter Helpers
        function fs = defaultSamplingRate(self,fsIn)
            if ~isnan(fsIn)
                fs = fsIn;
            else
                fs = min(self.project.getSamplingFrequency("cable"), ...
                    self.project.getSamplingFrequency("bridge"));
            end
        end

        function [fLow,fHigh] = defaultBand(~,fs,fLowIn,fHighIn)
            if isnan(fLowIn)
                fLow = 0.1;
            else
                fLow = fLowIn;
            end

            if isnan(fHighIn)
                fHigh = fs/2 - 1;
            else
                fHigh = fHighIn;
            end
        end

        function [b,a,label] = filterCoeffs(~,kind,wPass,order)
            kind = lower(kind);
            switch kind
                case "butter"
                    [b,a] = butter(order,wPass,"bandpass");
                    label = "Butterworth";
                case "cheby"
                    [b,a] = cheby1(order,1,wPass,"bandpass");
                    label = "Chebyshev I";
                case "fir"
                    firOrder = 2*order;
                    b = fir1(firOrder,wPass,"bandpass",blackman(firOrder+1));
                    a = 1;
                    label = "FIR (Blackman)";
                case "square"
                    b = [];
                    a = [];
                    label = "Square";
                otherwise
                    error('BridgeOverview:UnknownFilterMethod', ...
                        'Unknown filter method "%s".',kind)
            end
        end

        function orders = getPlotOrders(~,kind,orderMax)
            kind = lower(kind);
            switch kind
                case {"butter","cheby"}
                    orders = 1:orderMax;
                case "fir"
                    orders = 1:orderMax;
                otherwise
                    orders = 1:orderMax;
            end
        end

        function plotFilterFamily(self,ax,kind,f,fs,fLow,fHigh,orderMax,sigMagdB,sigF)
            axes(ax);
            hold on

            if ~isempty(sigMagdB) && ~isempty(sigF)
                plot(sigF,sigMagdB,'DisplayName',"Signal");
            end

            wPass = [fLow fHigh]/(fs/2);
            orders = self.getPlotOrders(kind,orderMax);

            for n = orders
                [b,a,~] = self.filterCoeffs(kind,wPass,n);
                [H,ff] = freqz(b,a,numel(f),fs);
                plot(ff,20*log10(abs(H)),"DisplayName",sprintf("n=%d",n));
            end

            grid on
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            xlim([max(0.01,f(2)) fHigh*(1.2)]);
            title(sprintf('%s family',CapitalizeText(kind)));
            if strcmpi(kind,'fir');legend('Location','best');end
            ylim([-10 2]);
            set(gca,'XScale','log');
        end
        function plotSquareFilter(~,ax,f,fLow,fHigh,sigMagdB,sigF)
            axes(ax);
            hold on

            if ~isempty(sigMagdB) && ~isempty(sigF)
                semilogx(sigF,sigMagdB,'DisplayName',"Signal");
            end

            mag = eps*ones(size(f));
            mask = f >= fLow & f <= fHigh;
            mag(mask) = 1;
            semilogx(f,20*log10(mag),'DisplayName',"Square");

            grid on
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            xlim([max(0.01,f(2)) fHigh*2]);
            title('Ideal square filter');
            ylim([-10 2]);
            set(gca,'XScale','log');
        end
        function filter = buildFilterStruct(~,label,fLow,fHigh,fs,order,b,a)
            filter.type = char(label);
            filter.fLow = fLow;
            filter.fHigh = fHigh;
            filter.samplingRate = fs;
            filter.order = order;
            filter.a = a;
            filter.b = b;
            filter.func = @(x) filtfilt(b,a,x);
        end
        function filter = buildSquareFilterStruct(self,fLow,fHigh,fs)
            filter.type = "Square";
            filter.fLow = fLow;
            filter.fHigh = fHigh;
            filter.samplingRate = fs;
            filter.order = NaN;
            filter.a = [];
            filter.b = [];
            filter.func = @(x) self.squareFilter(x,fs,fLow,fHigh);
        end
        function y = squareFilter(~,x,fs,fLow,fHigh)
            N = length(x);
            X = fft(x);

            f = (0:N-1)*(fs/N);

            mask = (f >= fLow & f <= fHigh);
            mask = mask | mask(end:-1:1);

            Xf = X .* mask(:);
            y = real(ifft(Xf));
        end
    end
    methods (Access = public, Static)   % Plotting Helpers
        function setGlobalYLimits(axesHandles,manualLimits)

            if nargin >= 2 && ~isempty(manualLimits)
                for ax = reshape(axesHandles,1,[])
                    ylim(ax,manualLimits)
                end
                return
            end

            allLimits = cell2mat(get(axesHandles,'YLim'));
            ymin = min(allLimits(:,1));
            ymax = max(allLimits(:,2));
            maxabs = max(abs([ymin ymax]));
            globalLim = [-maxabs maxabs];

            for ax = reshape(axesHandles,1,[])
                ylim(ax,globalLim)
            end
        end
        function [BridgeData,CableData] = convertAcceleration(BridgeData,CableData,convert2DispOrVel)
            if strcmpi(convert2DispOrVel,'displacement')
                dataout_type = 1;
            elseif strcmpi(convert2DispOrVel,'velocity')
                dataout_type = 2;
            end

            if ~isempty(BridgeData)
                bridgeVars = BridgeData.Properties.VariableNames;
                bridgeDt = median(diff(seconds((BridgeData.Time-BridgeData.Time(1)))));
                for k = 1:length(bridgeVars)
                    datain = BridgeData.(bridgeVars{k});
                    N = length(datain);
                    datain = [flip(datain(2:end));datain;flip(datain(1:end-1))];
                    dataout = iomega(datain,bridgeDt,3,dataout_type);
                    dataout = dataout(N:N*2-1);
                    dataout = detrend(dataout,3-dataout_type);
                    BridgeData.(bridgeVars{k}) = dataout;
                end
            end

            if ~isempty(CableData)
                cableVars = CableData.Properties.VariableNames;
                cableDt = median(diff(seconds((CableData.Time-CableData.Time(1)))));
                for k = 1:length(cableVars)
                    datain = CableData.(cableVars{k});
                    N = length(datain);
                    datain = [flip(datain(2:end));datain;flip(datain(1:end-1))];
                    dataout = iomega(datain,cableDt,3,dataout_type);
                    dataout = dataout(N:N*2-1);
                    dataout = detrend(dataout,3-dataout_type);
                    CableData.(cableVars{k}) = dataout;
                end
            end
        end
    end
    methods (Access = private)          % Plotting Helpers
        function checkForNaNs(self)
            if any(isnan(self.project.bridgeData.Variables),'all') ||...
                    any(isnan(self.project.cableData.Variables),'all')
                error('NaNs was found in signal, consider using fillMissingDataPoints function! Returning empty.')
            end
        end
    end
    methods (Access = private, Static)  % Plotting Helpers
        function plotEPSD(BridgeData,CableData,TimePeriod,segmentDurationMinutes)
            if nargin > 2 && ~isempty(TimePeriod)
                range = timerange(TimePeriod(1),TimePeriod(2));
                CableData = CableData(range,:);
                BridgeData = BridgeData(range,:);
            end

            if nargin < 4 || isempty(segmentDurationMinutes)
                segmentDurationMinutes = 10;
            end

            fmax = 15;
            cableGroups = findCableGroups(CableData.Properties.VariableNames);

            fig = figure(2); clf;
            theme(fig,"light")
            [tiles,nexttileRowCol] = tiledlayoutRowCol(3,2+size(cableGroups,1), ...
                "TileSpacing","compact","Padding","compact");

            deckTypes   = {'Conc','Steel'};
            deckTitles  = {'Concrete deck','Steel deck'};
            dirs        = {'X','Y','Z'};
            dirLabels   = {'x direction','y direction','z direction'};

            for d = 1:numel(deckTypes)
                for k = 1:numel(dirs)
                    nexttileRowCol(k,d);
                    varName = [deckTypes{d} '_' dirs{k}];
                    plot_epsd(BridgeData.Time,BridgeData.(varName),segmentDurationMinutes,false);
                    axis tight
                    ylim([0,fmax])
                    if d == 1
                        ylabel(dirLabels{k},'Interpreter','latex')
                    end
                    if k == 1
                        title(deckTitles{d})
                    end
                end
            end

            ylabel(tiles,'$f$ (Hz)','Interpreter','latex')

            for ii = 1:size(cableGroups,1)
                cableName = cableGroups{ii,1};
                cableDirs = cableGroups{ii,2};
                for jj = 1:numel(cableDirs)
                    nexttileRowCol(jj,2+ii);
                    varName = cableName + "_" + cableDirs(jj);
                    plot_epsd(CableData.Time,CableData.(varName),segmentDurationMinutes,false);
                    axis tight
                    ylim([0,fmax])
                    if jj == 1
                        title(cableName)
                    end
                end
            end

            axesHandles = findall(fig,'Type','axes');
            clims = cell2mat(get(axesHandles,'CLim'));
            sharedClim = [min(clims(:,1)), max(clims(:,2))];
            set(axesHandles,'CLim',sharedClim);

            BridgeOverview.setTimeTicks(axesHandles,BridgeData.Time)

            cb = colorbar;
            cb.Layout.Tile = 'east';
            cb.Label.String = 'log$_{10}$ PSD ((m/s$^2$)$^2$/Hz)';
            cb.Label.Interpreter = 'latex';

            t1 = char(string(min(BridgeData.Time),"uuuu-MM-dd HH:mm:ss"));
            t2 = char(string(max(BridgeData.Time),"uuuu-MM-dd HH:mm:ss"));

            periodTitle = ['Plotted period: ' ...
                t1 '  $\rightarrow$  ' t2];

            title(tiles, periodTitle, 'Interpreter','latex')
        end
        function plotTime(BridgeData,CableData,TimePeriod,convert2DispOrVel)
            if nargin > 2 && ~isempty(TimePeriod)
                range = timerange(TimePeriod(1),TimePeriod(2));
                CableData  = CableData(range,:);
                BridgeData = BridgeData(range,:);
            end

            if nargin < 4 || isempty(convert2DispOrVel)
                convert2DispOrVel = 'acceleration';
            end

            if ~strcmpi(convert2DispOrVel,'acceleration')
                [BridgeData,CableData] = BridgeOverview.convertAcceleration(BridgeData,CableData,convert2DispOrVel);
                switch lower(convert2DispOrVel)
                    case 'displacement'
                        unitDef = '\mathrm{'; unit = 'm';
                    case 'velocity'
                        unitDef = '\dot{'; unit = 'm/s';
                    otherwise
                        unitDef = '\ddot{'; unit = 'm/s$^2$';
                end
            else
                unitDef = '\ddot{'; unit = 'm/s$^2$';
            end

            cableGroups = findCableGroups(CableData.Properties.VariableNames);
            numCableG   = size(cableGroups,1);
            numBridgeG  = size(BridgeData.Properties.VariableNames,2)/3;

            fig = figure(1); clf;
            theme(fig,"light")

            totalCols = numBridgeG + numCableG;
            tiles = tiledlayout(3, totalCols, 'TileSpacing', 'compact', 'Padding', 'compact');

            deckTypes  = {'Conc','Steel'};
            deckTitles = {'Concrete deck','Steel deck'};
            dirs       = {'X','Y','Z'};
            dirLatex   = {'x','y','z'};

            bridgeAxes = gobjects(0);
            for d = 1:numBridgeG
                for k = 1:3
                    ax = nexttile((k-1)*totalCols + d);
                    bridgeAxes(end+1) = ax;
                    varName = sprintf('%s_%s', deckTypes{d}, dirs{k});
                    plot(BridgeData.Time, BridgeData.(varName));
                    axis tight
                    if d == 1
                        ylabel(['$' unitDef dirLatex{k} '}$ (' unit ')'], 'Interpreter', 'latex')
                    end
                    if k == 1
                        title(deckTitles{d})
                    end
                end
            end

            cableAxes = gobjects(0);
            for ii = 1:numCableG
                cableName = cableGroups{ii,1};
                cableDirs = cableGroups{ii,2};
                colIdx = numBridgeG + ii;
                for jj = 1:numel(cableDirs)
                    ax = nexttile((jj-1)*totalCols + colIdx);
                    cableAxes(end+1) = ax;
                    varName = cableName + "_" + char(cableDirs(jj));
                    plot(CableData.Time, CableData.(varName));
                    axis tight
                    if jj == 1
                        title(cableName, 'Interpreter', 'none')
                    end
                end
            end

            allAxes = [bridgeAxes, cableAxes];
            linkaxes(allAxes, 'x');

            BridgeOverview.setTimeTicks(allAxes, BridgeData.Time)

            if ~isempty(bridgeAxes)
                BridgeOverview.setGlobalYLimits(bridgeAxes)
            end
            if ~isempty(cableAxes)
                BridgeOverview.setGlobalYLimits(cableAxes)
            end

            t1 = string(min(BridgeData.Time), "uuuu-MM-dd HH:mm:ss");
            t2 = string(max(BridgeData.Time), "uuuu-MM-dd HH:mm:ss");
            periodTitle = "Plotted period: " + t1 + " $\rightarrow$ " + t2;
            title(tiles, periodTitle, 'Interpreter', 'latex')
            xlabel(tiles, 'Time')
        end

        function setTimeTicks(axesHandles,timeVec)
            timeStart = min(timeVec);
            timeEnd   = max(timeVec);
            spanHours = hours(timeEnd - timeStart);

            if spanHours <= .5
                step = minutes(2);
            elseif spanHours <= 2
                step = minutes(10);
            elseif spanHours <= 6
                step = minutes(30);
            elseif spanHours <= 25
                step = hours(1);
            elseif spanHours <= 72
                step = hours(6);
            else
                step = days(1);
            end

            plotSpan = timeEnd - timeStart;
            if plotSpan <= hours(1)
                shiftUnit = 'minute';
            elseif plotSpan <= days(1.1)
                shiftUnit = 'hour';
            elseif plotSpan <= weeks(1)
                shiftUnit = 'day';
            else
                shiftUnit = 'month';
            end

            tickStart = dateshift(timeStart, 'start', shiftUnit);

            tickEnd = dateshift(timeEnd, 'end', shiftUnit);
            tickTimes = tickStart:step:tickEnd;

            tickTimes = tickTimes(tickTimes <= (timeEnd + step/2));

            if spanHours < 25
                tickFormatDatetime = 'HH:mm';
                tickFormatDatenum  = 'HH:MM';
            else
                tickFormatDatetime = 'MM-dd HH:mm';
                tickFormatDatenum  = 'mm-dd HH:MM';
            end

            for ax = reshape(axesHandles, 1, [])
                if ~isvalid(ax), continue; end

                if isnumeric(ax.XLim)
                    ax.XTick = datenum(tickTimes);
                    datetick(ax, 'x', tickFormatDatenum, 'keeplimits', 'keepticks');
                else
                    % For datetime rulers (standard in modern MATLAB)
                    ax.XTick = tickTimes;
                    ax.XAxis.TickLabelFormat = tickFormatDatetime;
                end

                if numel(axesHandles) > 1
                    ax.XAxis.SecondaryLabel.Visible = 'off';
                end
            end
        end
        function plotCablePhaseSpaceStatic(bridgeData, cableData, timePeriod)
            if nargin > 2 && ~isempty(timePeriod)
                tr = timerange(timePeriod(1), timePeriod(2));
                cableData  = cableData(tr,:);
                bridgeData = bridgeData(tr,:);
            end

            cableAcc  = cableData;
            [~, cableVel]  = BridgeOverview.convertAcceleration(bridgeData, cableData, 'velocity');
            [~, cableDisp] = BridgeOverview.convertAcceleration(bridgeData, cableData, 'displacement');

            unitDefs = {'\ddot{','\dot{','{'};
            units    = {'m/s$^2$','m/s','m'};

            cableGroups = findCableGroups(cableData.Properties.VariableNames);

            maxPoints = 2000;

            fig = figure(5); clf;
            theme(fig,"light")
            [tiles,nextTile] = tiledlayoutRowCol(3, size(cableGroups,1), ...
                "TileSpacing","compact","Padding","compact");

            for s = 1:3
                switch s
                    case 1
                        cableSet = cableAcc;
                    case 2
                        cableSet = cableVel;
                    case 3
                        cableSet = cableDisp;
                end

                t = cableSet.Time;
                nSamples = numel(t);
                if nSamples < 2
                    continue
                end

                dtSeconds = median(seconds(diff(t)));
                totalDurationSeconds = seconds(t(end) - t(1));

                if nSamples <= maxPoints || totalDurationSeconds <= 0 || dtSeconds <= 0
                    indexSelection = 1:nSamples;
                else
                    desiredDt = totalDurationSeconds / (maxPoints - 1);
                    sampleStep = max(1, round(desiredDt / dtSeconds));
                    indexSelection = 1:sampleStep:nSamples;
                end

                for c = 1:size(cableGroups,1)
                    cableName = cableGroups{c,1};
                    dirs      = cableGroups{c,2};

                    if ~any(dirs=="x") || ~any(dirs=="y")
                        continue
                    end

                    vx = cableName + "_x";
                    vy = cableName + "_y";

                    xAll = cableSet.(vx);
                    yAll = cableSet.(vy);

                    if numel(xAll) < 2 || numel(yAll) < 2
                        continue
                    end

                    x = xAll(indexSelection);
                    y = yAll(indexSelection);

                    nextTile(s,c);
                    plot(x,y,'.k')

                    lim = max(abs([x; y]));
                    xlim([-lim lim])
                    ylim([-lim lim])
                    axis square

                    yt = yticks;
                    xticks(yt);

                    if s == 1
                        title(cableName,'Interpreter','none')
                    end

                    if s == 3
                        xlabel(['$' unitDefs{s} 'x}$ (' units{s} ')'],'Interpreter','latex')
                    end

                    if c == 1
                        ylabel(['$' unitDefs{s} 'y}$ (' units{s} ')'],'Interpreter','latex')
                    end
                end
            end

            t1 = char(string(min(cableData.Time),"uuuu-MM-dd HH:mm:ss"));
            t2 = char(string(max(cableData.Time),"uuuu-MM-dd HH:mm:ss"));
            title(tiles, ['Cable phase space: ' t1 '  $\rightarrow$  ' t2], 'Interpreter','latex')
        end
        function plotTimeHistoryVertical(BridgeData, CableData, TimePeriod, convert2DispOrVel)
            if nargin > 2 && ~isempty(TimePeriod)
                range = timerange(TimePeriod(1),TimePeriod(2));
                CableData  = CableData(range,:);
                BridgeData = BridgeData(range,:);
            end

            if nargin < 4 || isempty(convert2DispOrVel)
                convert2DispOrVel = 'acceleration';
            end

            if ~strcmpi(convert2DispOrVel, 'acceleration')
                [BridgeData, CableData] = BridgeOverview.convertAcceleration(BridgeData, CableData, convert2DispOrVel);
                switch lower(convert2DispOrVel)
                    case 'displacement'
                        unitDef = '\mathrm{u'; unit = 'm'; labelName = 'Displacement';
                    case 'velocity'
                        unitDef = '\dot{u'; unit = 'm/s'; labelName = 'Velocity';
                    otherwise
                        unitDef = '\ddot{u'; unit = 'm/s$^2$'; labelName = 'Acceleration';
                end
            else
                unitDef = '\ddot{u'; unit = 'm/s$^2$'; labelName = 'Acceleration';
            end

            cableGroups = findCableGroups(CableData.Properties.VariableNames);
            numCableG   = size(cableGroups, 1);
            numBridgeG  = size(BridgeData.Properties.VariableNames, 2) / 3;

            deckTypes  = {'Conc', 'Steel'};
            deckTitles = {'Concrete deck', 'Steel deck'};
            dirs       = {'X', 'Y', 'Z'};
            colors     = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250];

            fig = figure(1); clf;
            theme(fig, "light")
            totalPositions = numBridgeG + numCableG;
            tiles = tiledlayout(totalPositions, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

            allAxes = gobjects(0);
            for d = 1:numBridgeG
                ax = nexttile;
                allAxes(end+1) = ax;
                hold(ax, 'on');
                amps = zeros(3,1);
                for k = 1:3
                    varName = sprintf('%s_%s', deckTypes{d}, dirs{k});
                    amps(k) = max(BridgeData.(varName)) - min(BridgeData.(varName));
                end
                [~, drawOrder] = sort(amps, 'descend');
                for idx = drawOrder'
                    varName = sprintf('%s_%s', deckTypes{d}, dirs{idx});
                    plot(BridgeData.Time, BridgeData.(varName), 'Color', colors(idx,:), 'LineWidth', 0.8);
                end
                title(deckTitles{d})
                axis tight
            end

            for ii = 1:numCableG
                ax = nexttile;
                allAxes(end+1) = ax;
                hold(ax, 'on');
                cableName = cableGroups{ii,1};
                cableDirs = cableGroups{ii,2};
                amps = zeros(numel(cableDirs), 1);
                for jj = 1:numel(cableDirs)
                    varName = cableName + "_" + char(cableDirs(jj));
                    amps(jj) = max(CableData.(varName)) - min(CableData.(varName));
                end
                [~, drawOrder] = sort(amps, 'descend');
                for idx = drawOrder'
                    dirChar = char(cableDirs(idx));
                    colorIdx = find(strcmpi(dirs, dirChar));
                    varName = cableName + "_" + dirChar;
                    plot(CableData.Time, CableData.(varName), 'Color', colors(colorIdx,:), 'LineWidth', 0.8);
                end
                title(cableName, 'Interpreter', 'none')
                axis tight
            end

            ylabel(tiles, [labelName ' $' unitDef '}$ (' unit ')'], 'Interpreter', 'latex')
            xlabel(tiles, 'Time')

            legend(allAxes(end), dirs);
            linkaxes(allAxes, 'x');
            BridgeOverview.setTimeTicks(allAxes, BridgeData.Time);

            t1 = string(min(BridgeData.Time), "uuuu-MM-dd HH:mm:ss");
            t2 = string(max(BridgeData.Time), "uuuu-MM-dd HH:mm:ss");
            title(tiles, "Plotted period: " + t1 + " $\rightarrow$ " + t2, 'Interpreter', 'latex')
        end
        function plotFrequencyVertical(BridgeData, CableData, TimePeriod, method, opts)
            if nargin > 2 && ~isempty(TimePeriod)
                range = timerange(TimePeriod(1), TimePeriod(2));
                CableData  = CableData(range,:);
                BridgeData = BridgeData(range,:);
            end

            cableGroups = findCableGroups(CableData.Properties.VariableNames);
            numCableG   = size(cableGroups, 1);
            numBridgeG  = size(BridgeData.Properties.VariableNames, 2) / 3;

            deckTypes  = {'Conc', 'Steel'};
            deckTitles = {'Concrete deck', 'Steel deck'};
            dirs       = {'X', 'Y', 'Z'}; % Master list for legend
            colors     = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250];
            fs = 1/median(diff(seconds(BridgeData.Time - BridgeData.Time(1))));

            fig = figure(6); clf;
            theme(fig, "light")
            totalPos = numBridgeG + numCableG;
            tiles = tiledlayout(totalPos, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
            allAxes = gobjects(0);

            function [f, p] = getPSD(data, fs, method, opts)
                if method == "welch"
                    wLen = round(opts.windowSec * fs);
                    nOver = round(wLen * (opts.overlapPct/100));
                    [p, f] = pwelch(double(data), hamming(wLen), nOver, [], fs);
                else
                    N = length(data);
                    xdft = fft(double(data));
                    xdft = xdft(1:floor(N/2)+1);
                    p = (1/(fs*N)) * abs(xdft).^2;
                    p(2:end-1) = 2*p(2:end-1);
                    f = 0:fs/N:fs/2;
                end
            end

            for d = 1:numBridgeG
                ax = nexttile; allAxes(end+1) = ax; hold(ax, 'on');
                set(ax, 'YScale', 'log');
                psdStore = cell(1,3); peakAmps = zeros(3,1);
                activeDirs = false(1,3);

                for k = 1:3
                    if ~any(strcmpi(dirs{k}, opts.bridgeDirs)), continue; end
                    varName = sprintf('%s_%s', deckTypes{d}, dirs{k});
                    [f, p] = getPSD(BridgeData.(varName), fs, method, opts);
                    psdStore{k} = p;
                    peakAmps(k) = max(p(f <= opts.fMax));
                    activeDirs(k) = true;
                end

                [~, drawOrder] = sort(peakAmps, 'descend');
                for idx = drawOrder'
                    if ~activeDirs(idx), continue; end
                    semilogy(f, psdStore{idx}, 'Color', colors(idx,:), 'LineWidth', 0.8, 'DisplayName', dirs{idx});
                end
                title(deckTitles{d}); grid on; xlim([0 opts.fMax]);
            end

            for ii = 1:numCableG
                ax = nexttile; allAxes(end+1) = ax; hold(ax, 'on');
                set(ax, 'YScale', 'log');
                cableName = cableGroups{ii,1};
                availCableDirs = cableGroups{ii,2};
                psdStore = cell(1, numel(availCableDirs)); peakAmps = zeros(numel(availCableDirs), 1);
                activeCableDirs = false(1, numel(availCableDirs));

                for jj = 1:numel(availCableDirs)
                    dirChar = char(availCableDirs(jj));
                    if ~any(strcmpi(dirChar, opts.cableDirs)), continue; end

                    varName = cableName + "_" + dirChar;
                    [f, p] = getPSD(CableData.(varName), fs, method, opts);
                    psdStore{jj} = p;
                    peakAmps(jj) = max(p(f <= opts.fMax));
                    activeCableDirs(jj) = true;
                end

                [~, drawOrder] = sort(peakAmps, 'descend');
                for idx = drawOrder'
                    if ~activeCableDirs(idx), continue; end
                    dirChar = char(availCableDirs(idx));
                    colorIdx = find(strcmpi(dirs, dirChar));
                    semilogy(f, psdStore{idx}, 'Color', colors(colorIdx,:), 'LineWidth', 0.8, 'DisplayName', dirChar);
                end
                title(cableName, 'Interpreter', 'none'); grid on; xlim([0 opts.fMax]);
            end

            % Link ONLY the X-axis for time/frequency synchronization
            linkaxes(allAxes, 'x');

            ylabel(tiles, 'PSD ((m/s$^2$)$^2$/Hz)', 'Interpreter', 'latex');
            xlabel(tiles, 'Frequency (Hz)', 'Interpreter', 'latex');

            % FIX: Create a dummy axis or use the last plot to force a complete legend
            % We ensure all directions from the master list 'dirs' are represented
            hold(allAxes(end), 'on');
            dummy_h = gobjects(3,1);
            for k = 1:3
                dummy_h(k) = semilogy(allAxes(end), NaN, NaN, 'Color', colors(k,:), 'LineWidth', 0.8, 'DisplayName', dirs{k});
            end
            legend(allAxes(end), dummy_h, 'Location', 'northeast', 'Interpreter', 'latex');

            t1 = string(min(BridgeData.Time), "uuuu-MM-dd HH:mm:ss");
            t2 = string(max(BridgeData.Time), "uuuu-MM-dd HH:mm:ss");
            title(tiles, "PSD via " + upper(method) + " | Period: " + t1 + " $\rightarrow$ " + t2, 'Interpreter', 'latex');
        end
    end
end

classdef BridgeOverview
    properties
        project
        filter struct
    end

    methods (Access = public) % Creation
        function self = BridgeOverview(project)
            self.project   = project;
        end
    end

    methods (Access = public) % Filter functions
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
    methods (Access = public) % Plotting functions
        function plotTimeHistory(self, SignalOutput, TimePeriod)
            % SignalOutput = 'acceleration', 'velocity', 'displacement'
            if nargin < 2
                SignalOutput = 'acceleration';
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

            plotTimeHistoryObject(self,self.project.bridgeData, ...
                self.project.cableData, ...
                TimePeriod, SignalOutput);
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

            plotEPSDHistoryObject(self,self.project.bridgeData, ...
                self.project.cableData, ...
                TimePeriod, segmentDurationMinutes);
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

        function plotHeaveCoherence(self, cableField, selectedTimePeriod, fHigh)
            if nargin < 4
                fHigh = 10;
            end

            fig = figure; clf;
            theme(fig,"light")
            [t, nexttileRowCol] = tiledlayoutRowCol(2,3,"TileSpacing","compact","Padding","compact");

            DeckPos = {'Conc_','Steel_'};
            for ii = 1:2
                deckField = [DeckPos{ii} 'Z'];

                [Cxy,f,Pxx,Pyy,~] = self.coherence(deckField, cableField, selectedTimePeriod, false);

                nexttileRowCol(ii,1,'ColSpan',2);
                yyaxis left
                semilogy(f,Pxx,'DisplayName',[DeckPos{ii}(1:end-1) '$-z$']);
                hold on
                semilogy(f,Pyy,'DisplayName',[char(cableField) '']);
                ylabel('$S_{\ddot{\hat{y}}}$ or $S_{\ddot{z}}$ $\mathrm{((m/s^2)^2)/Hz}$','Interpreter','latex','FontSize',20)

                yyaxis right
                plot(f,abs(Cxy).^2,'DisplayName','$|\mathit{coh}|^2$')
                ylabel(['$|\mathit{coh}(f,\Delta Z_{\mathrm{' DeckPos{ii}(1:end-1) '}}, \Delta \hat{y}_{\mathrm{' char(cableField) '}})|^2$'], ...
                    'Interpreter','latex','FontSize',20)
                ylim([0 1])
                xlim([0 fHigh])
                xticks(1:fHigh)

                [peakVal,peakFreq] = findpeaks(abs(Cxy).^2,f,'MinPeakHeight',0.2);
                [~,idx] = sort(peakVal,'descend');
                peakFreq = peakFreq(idx);

                xl = xline(peakFreq,'--k','Alpha',0.2,'LineWidth',2);
                PeakFreqLegends = arrayfun(@(x) sprintf('$f=%.2f$',x), peakFreq, 'UniformOutput', false);
                set(xl,{'DisplayName'},PeakFreqLegends(:))
                legend('Interpreter','latex','FontSize',16)
                ax = gca;
                ax.XGrid = 'on';

                nexttileRowCol(ii,3);
                plot(f,real(Cxy),'--','DisplayName',['$\gamma_{z\hat{y}}(f,\Delta Z_{\mathrm{' DeckPos{ii}(1:end-1) '}}, \Delta \hat{Y}_{\mathrm{' char(cableField) '}})$'])
                hold on
                plot(f,imag(Cxy),'-.','DisplayName',['$\rho_{z\hat{y}}(f,\Delta Z_{\mathrm{' DeckPos{ii}(1:end-1) '}}, \Delta \hat{Y}_{\mathrm{' char(cableField) '}})$'])
                xline(peakFreq,'--k','Alpha',0.2,'LineWidth',2,'HandleVisibility','off');
                ylim([-1 1])
                xlim([0 fHigh])
                xticks(1:fHigh)
                legend('Interpreter','latex','FontSize',16)
                grid on
            end

            xlabel(t,'$f$ (Hz)','Interpreter','latex','FontSize',20)
            title(t,['Coherence between deck and ' char(cableField) ' between ' ...
                char(selectedTimePeriod(1)) ' and ' ...
                char(selectedTimePeriod(2),'HH:mm:SS')],...
                'Interpreter','latex','Fontsize',24)
        end
    end
    methods (Access = private) % Filter Helpers
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
    methods (Access = private) % Plotting Helpers
        function checkForNaNs(self)
            if any(isnan(self.project.bridgeData.Variables),'all') ||...
                    any(isnan(self.project.cableData.Variables),'all')
                error('NaNs was found in signal, consider using fillMissingDataPoints function! Returning empty.')
            end
        end
        function plotEPSDHistoryObject(~,BridgeData,CableData,TimePeriod,segmentDurationMinutes)
            % plotEPSDHistoryObject Plot EPSD history for deck and cable data with shared scaling.
            %   plotEPSDHistoryObject(BridgeData,CableData)
            %   plotEPSDHistoryObject(BridgeData,CableData,TimePeriod)
            %   plotEPSDHistoryObject(BridgeData,CableData,TimePeriod,segmentDurationMinutes)

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

            setTimeTicks(axesHandles,BridgeData.Time)

            cb = colorbar;
            cb.Layout.Tile = 'east';
            cb.Label.String = 'log$_{10}$ PSD ((m/s$^2$)$^2$/Hz)';
            cb.Label.Interpreter = 'latex';
        end
        function plotTimeHistoryObject(~,BridgeData,CableData,TimePeriod,convert2DispOrVel)

            if exist('TimePeriod','var')
                if ~isempty(TimePeriod)
                    Range = timerange(TimePeriod(1),TimePeriod(2));
                    CableData = CableData(Range,:);
                    BridgeData = BridgeData(Range,:);
                end
            end

            if exist('convert2DispOrVel','var') && ~strcmpi(convert2DispOrVel,'acceleration')
                [BridgeData,CableData] = convertAcceleration(BridgeData,CableData,convert2DispOrVel);

                if strcmpi(convert2DispOrVel,'displacement')
                    unitDef = '\mathrm{';
                    unit = 'm';
                elseif strcmpi(convert2DispOrVel,'velocity')
                    unitDef = '\dot{';
                    unit = 'm/s';
                end
            else
                unitDef = '\ddot{';
                unit = 'm/s$^2$';
            end

            CableVars = CableData.Properties.VariableNames;
            cableGroups = findCableGroups(CableVars);

            fig=figure(1);clf;
            theme(fig,"light")
            [~,nexttileRowCol] = tiledlayoutRowCol(3,2+size(cableGroups,1),"TileSpacing", "compact", "Padding", "compact");
            %Deck Data - Concrete
            nexttileRowCol(1,1);
            plot(BridgeData.Time,BridgeData.Conc_X);
            title('Concrete deck')
            ylabel(['$' unitDef 'x}$ (' unit ')'],'Interpreter','latex')
            axis tight
            nexttileRowCol(2,1);
            plot(BridgeData.Time,BridgeData.Conc_Y);
            ylabel(['$' unitDef 'y}$ (' unit ')'],'Interpreter','latex')
            axis tight
            nexttileRowCol(3,1);
            plot(BridgeData.Time,BridgeData.Conc_Z);
            ylabel(['$' unitDef 'z}$ (' unit ')'],'Interpreter','latex')
            axis tight

            %Deck Data - Steel
            nexttileRowCol(1,2);
            plot(BridgeData.Time,BridgeData.Steel_X);
            title('Steel deck')
            axis tight
            nexttileRowCol(2,2);
            plot(BridgeData.Time,BridgeData.Steel_Y);
            axis tight
            nexttileRowCol(3,2);
            plot(BridgeData.Time,BridgeData.Steel_Z);
            axis tight

            for ii = 1:size(cableGroups,1)
                for jj = 1:size(cableGroups{ii,2},1)
                    nexttileRowCol(jj,2+ii);
                    cableName = cableGroups{ii,1};
                    cableDir  = char(cableGroups{ii,2}(jj));
                    plot(CableData.Time, CableData.([cableName '_' cableDir]));
                    axis tight
                    if jj == 1
                        title(cableName)
                    end
                end
            end

            axesHandles = findall(fig,'Type','axes');
            setTimeTicks(axesHandles,BridgeData.Time)
        end

        function [BridgeData,CableData] = convertAcceleration(BridgeData,CableData,convert2DispOrVel)
            if strcmpi(convert2DispOrVel,'displacement')
                dataout_type = 1;
            elseif strcmpi(convert2DispOrVel,'velocity')
                dataout_type = 2;
            end

            bridgeVars = BridgeData.Properties.VariableNames;
            bridgeDt = median(diff(seconds((BridgeData.Time-BridgeData.Time(1)))));
            for k = 1:length(bridgeVars)
                datain = BridgeData.(bridgeVars{k});
                dataout = iomega(datain,bridgeDt,3,dataout_type);
                dataout = detrend(dataout,3-dataout_type);
                BridgeData.(bridgeVars{k}) = dataout;
            end

            cableVars = CableData.Properties.VariableNames;
            cableDt = median(diff(seconds((CableData.Time-CableData.Time(1)))));
            for k = 1:length(cableVars)
                datain = CableData.(cableVars{k});
                dataout = iomega(datain,cableDt,3,dataout_type);
                dataout = detrend(dataout,3-dataout_type);
                CableData.(cableVars{k}) = dataout;
            end
        end
        function setTimeTicks(axesHandles,timeVec)
            timeStart = min(timeVec);
            timeEnd   = max(timeVec);
            spanHours = hours(timeEnd - timeStart);

            if     spanHours <= 2
                step = minutes(10);
            elseif spanHours <= 6
                step = minutes(30);
            elseif spanHours <= 25
                step = hours(5);
            elseif spanHours <= 72
                step = hours(10);
            else
                step = days(1);
            end

            tickStart = dateshift(timeStart,'start','hour');
            tickEnd   = dateshift(timeEnd,'start','hour');
            tickTimes = tickStart:step:tickEnd;

            if spanHours < 25
                tickFormat = 'HH:mm';        % no date
            else
                tickFormat = 'MM-dd HH:mm';  % include date
            end

            for ax = reshape(axesHandles,1,[])
                xl = xlim(ax);
                if isempty(xl) || all(ismissing(xl))
                    continue
                end
                if isa(ax.XAxis,'matlab.graphics.axis.decorator.DatetimeRuler')
                    ax.XTick = tickTimes;
                    ax.XAxis.TickLabelFormat = tickFormat;
                else
                    ax.XTick = datenum(tickTimes);
                    datetick(ax,'x',tickFormat,'keeplimits','keepticks');
                end

                if length(axesHandles) > 1
                    % remove date in right corner
                    ax.XAxis.SecondaryLabel.Visible = 'off';
                end
            end
        end
    end
end

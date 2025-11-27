classdef BridgeOverview
    properties
        project
    end
    
    methods
        function self = BridgeOverview(project)
            self.project   = project;
        end
        
        function plotTimeHistory(self, SignalOutput, TimePeriod)
            % SignalOutput = 'acceleration', 'velocity', 'displacement'
            if nargin < 2
                SignalOutput = 'acceleration';
            end
            
            if nargin < 3
                TimePeriod = [];
            end

            plotTimeHistoryObject(self.project.bridgeData, ...
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
            
            plotEPSDHistoryObject(self.project.bridgeData, ...
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
            
            bridgeTime = self.BridgeData.Acc.time;
            bridgeData = self.BridgeData.Acc.(deckField).Data;
            
            cableTime  = self.CableData.Time;
            cableData  = self.CableData.(cableField);
            
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
                [peakVal,idx] = sort(peakVal,'descend');
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
end

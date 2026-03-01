% 2012-10-01 TS
%
% SohFindLD(t, y, band, ch) determines the logarithmic decrement (LD) of
% input 'y' (matrix, with data for each channel in columns) sampled at time
% 't' (vector). A fourier band-pass filter with band 'band' is applied to
% the data. Only data in column 'ch' is considered. (Note that 'ch' is
% one-indexed). If ch is not specified, ch=1 is used. LD is determined
% using maximas and minimas. This can be overruled, see below. 
%
% NOTE: 't' may also be a string with the name of a file to be analysed. If
% so, 'y' should be a string with the path. (in the same logic as
% SohReadBin.m)
% 
% The function plots the signal in channel 'ch', and allows the used to zoom
% (using the mouse) in on sections of the signal. The shown signal
% segment is then analysed. 
%
% The TOP PLOT shows the raw signal (blue), the filtered signal (red), the
% difference between the two (green), and the identified maximas, y_max, of
% the oscillation (red 'o') versus time.
%
% The MIDDLE PLOT shows ln(y_max) versus time. Note that a linear damping
% will cause the points of ln(y_max) to fall on a straight line. LD is
% determined from the shown straight line.
%
% The BOTTOM PLOT shows each LD calculated as ln(y_N/y_{N-1}). This plot
% helps in identifying unwanted oscillation phenomena, such as coupling
% across the tunnel. Black lines show <LD> (full line), and <LD>+/-std(LD)
% (punctured lines).
%
% To zoom, the following steps MUST be done in succession:
% LEFT-CLICK on the top plot to set the lower (left) bound
% LEFT-CLICK on the top plot to set the upper (right) bound
%
% To reset zoom, EITHER double click with left mouse button, or
% left-click at times t1,t2, where t1>=t2.
%
% Additional functions:
% Button 'f'      change band-pass filter.
%
% Buttons '1..9'  (above the keyboard) is pressed, the
%                 analysis will be performed on the assigned column no.
%
% Arrow up/down   adds/subtracts an additional offset of 0.01.
%
% Button 'p'      Prints the following data is output to the workspace,
%                 in tab-separated format (to ease cut-past into excel):
%
% Button 'e'      exports current figure to the current directory. the
%                 file name is given as a timestamp
%
% Button 'z'      re-zeroes the shown signal segment using the mean of
%                 the filtered signal segment.
%
% Button 's'      fits the single-degree-of-freedom frequency-response
%                 function to the spectrum peak shown. Note: This
%                 requires a currently (20160203) non-officially released
%                 subfunction. Ask TS for details.
%
% channel no, timestamp(start), timestamp(end), No.extremes, frequency, LD, band(1), band(2)
%
% When a satisfactory analysis is done, RIGHT-CLICK, PRESS SPACE or PRESS Q
% to terminate the program.
%
% [<LD>,freq,tCut,band,N,button,tmCut,yfmCut,delCut] = SohFindLD(t, y, band,
% ch) outputs the average LD '<LD>', the average frequency 'freq', the time
% limits used for analysis 'tCut', the final band-pass limits 'band', the
% number of extremes used for <LD> 'N', and the final button pressed
% 'button'. 'yfmCut' are the extreme signal values taken at time 'tmCut',
% with associated LD's in 'delCut'.
%
% SohFindLD(t, y, band, ch,varargin) takes additional inputs:
%
% 'spectrum',[f1 f2]: rescales the frequency axis on the bottom-left plot
% to specified limits. Default is [0 100].
%
% 'onesided': perfoms analysis using maximas only. Default uses maximas
% and minimas. 
%
% 'offset',y0: uses y0 as offset. default is mean(y). If length(y0)==1,
% the same offset is applied to all columns. 
%

% REVISIONS
% ------------------------------------------------------------------
% 2012-11-05 TS removed linkaxes command to ensure backwards
%               compatibility
% 2012-11-28 TS * log dec is now based on a line fit (more robust).
%               * Manual is updated
%               * Fixed a bug in data input
%               * Works on all screen resolutions 
%               * Cleared up the code, made subfunction for plot.
% 2012-11-29 TS * Fixed minor bugs & made things look nicer
%               * Enabled script termination by pressing space
% 2013-04-29 TS * Cleared up code. 
%               * Added more outputs. Documentation will follow.
% 2013-05-13 TS * In case y is a vector, column structure is enforced.  
%               * Zero-mean is no longer enforced  
%               * Band is now indicated by grey if spectrum is shown in
%                 bottom subplot.
% 2013-05-24 TS * Out-commented line that otherwise ensures positive
%                 maximas only. This should be up to the user to identify.
% 2013-06-19 TS * Plots only real parts of y and yf.
% 2014-01-08 TS * Subplot 2 only plots real parts of ym and fitting line.
%               * The used can now specify the frequency window of the spectrum.
%               * Changed default spectrum frequency window to [0 100]Hz. 
% 2014-01-09 TS * Bug fix: only force y column, if not string.
%               * enabled 'p' button print
% 2014-01-09 TS * Plots real part of LD only in subplot 3 (if no spectrum).
% 2014-02-26 TS * legend of subfigure 2 swapped
% 2014-03-12 TS * replaced previous use of 'isfloat' (rev. 2014-01-09)
%                 with 'isstr', for compatibility with matlab 6.5.
% 2014-06-16 TS * added explanation to workspace prints
%               * added abs error as green curve in top plot
% 2014-07-02 TS * added possibility to change column no. (DAQ ch+1)
%                 during analysis.
% 2014-09-02 TS * FFT filter can be changed during analysis
%               * Arbitrary offset compensation
%               * one or twosided analysis
% 2014-09-19 TS * changed plots in the bottom windows
% 2014-09-22 TS * added offset-adjustment possibility
% 2014-09-25 TS * lists bin files in cd, in case no input is given. uses band=[0 10].
% 2014-10-27 TS * minor bug fixes in prompted text
% 2014-10-30 TS * fixed error produced if no maxima is found on a channel
% 2014-12-05 TS * Changed '&' and '|' to '&&' and '||' in if-statements
%               * Replaced 'isstr' by 'ischar' (compatibility issues)
%               * Replaced 'SohPickBinFil' with 'SohPickFile'
% 2015-04-09 TS * added yfmCut and delCut as output
% 2015-04-17 TS * minor bug: yMax shown in plot title neglected y<0.
%               * prints std(y_filtered) to workspace.
%               * added tmCut to output
% 2015-06-12 TS * minor update: changed default band to [0 5]
% 2015-10-14 TS * fixed ylim on spectrum plot
% 2015-10-15 TS * changed legend location on spectrum plot
% 2016-02-01 TS * keyboard button 'z' subtracts mean of shown signal.
%               * keyboard button 'e' exports current figure to cd
%               * keyboard button 'f' fits SDOF response to spectrum.
% 2016-02-03 TS * added 'fileName' as varargin. 
% 2016-06-17 TS * minor changes to ensure better octave compatibility
% 2018-01-08 TS * fixed wrong button reference in helt txt
% 2018-09-28 TS * part of spectrum retained by filter shown in red
% 2018-10-02 TS * enforcing temporal interpolation of input
%               * updated PSD title to reflect also bandpass filter 
% 2019-03-19 TS * changed warning threshold for non-equidistant sample to
%                 something more realistically forgiving
% 2020-02-13 TS * moved offset to lower right corner of top plot
%               * made sliding window smoothing of LD vs peak plot
%               * peak detection sub-algorithm heavily optimised
% 2023-06-08 TS * cleared up some of the code. Final commit to main branch. 
%               * added a warning if outputs are requested
%               * changed wordings on lower right plot.
%               * increased detection limit for non-uniform dt to 1e-13
%               * added 'unitTestMode' to circumvent need for user intervention 
%                 during unit-test. This is not documented in the help text.
%
% To-do         * use jtr's soh assign input format
%               * convert output to struct format instead of multiple variables that no-one probably uses
%               * possibility of changing sliding window width in lower right corner

function [LD,freq,tCut,band,N,button,tmCut,yfmCut,delCut] = SohFindLD(t, y, band, ch, varargin);

if nargout>0
  warning(sprintf('\n> TS says: Output variable format may change in a future release.\n> Do you often use output variables?\n> If so, please notify TS of this!.'))
  display('                       .-.')
  display('        .-""`""-.    |(@ @)')
  display('     _/`oOoOoOoOo`\_ \ \-/')
  display('     .-=-=-=-=-=-=-.  \/ \ ')
  display('      `-=.=-.-=.=-/    \ /\ ')
  display('         ^  ^  ^       _H_ \ ')
end


  
vararginSub = varargin;  

flagPrint = 0; % flag used for printing to workspace

% look in cd, if no input is given
if nargin==0
  y    = pwd;
  t    = SohPickFile('\','bin');
  band = [0 5];
  ch   = 1;
end

% default channel
if nargin==3
  ch=1;
end

% if t or y is vector, force column
if size(t,2)~=1  && ~ischar(t)
  t = t(:);
end
if min(size(y))==1  && ~ischar(y)
  y = y(:);
end

% input may be path to file
if ischar(t)
  if length(t)<3
    fileName = [t,'.bin'];
  elseif ~strcmp(t(end-3:end),'bin')
    fileName = [t];
  end
  [t,yIn]  = SohReadBin(t,y);
elseif any(strcmp(varargin,'fileName'))
  fileName = varargin{find(strcmp(varargin,'fileName'))+1};
  yIn = y;
else
  fileName = 'N.A.';
  yIn = y;
end

% throw warning if interpolation is needed.
if std(diff(t))>1e-13
  t = t-t(1);
  warning(sprintf(['SOH Warning: time vector is non-uniform. Enforcing ' ...
                   'input interpolation\nDetails:\n'...
                   'std(diff(t))  = %.4f (%.2f%% of mean(dt))\n'...
                   'max(diff(t))  = %.4f (%.2f%% of mean(dt))\n'...
                   'mean(diff(t)) = %.4f\n'],...
                  std((diff(t))),std((diff(t)))/mean(diff(t))*100,max(diff(t)),max((diff(t)))/mean(diff(t))*100,mean(diff(t))));  
  
  ti = (linspace(t(1),t(end),length(t)))';
  yi = interp1(t,yIn,ti,'linear');
  
  t   = ti;
  yIn = yi;
end

% if onsided analysis
if ~any(strcmp(varargin,'onesided'))
  prefactor = 0.5;
else
  prefactor = 1;
end

% subtract offset from signal
if any(strcmp(varargin,'offset'))
  offset = varargin{find(strcmp(varargin,'offset'))+1};
  if size(offset,2)==1
    y=yIn-offset;
  elseif length(offset)>1
    y=yIn-ones(size(yIn,1),1)*offset;
  else
    error(sprintf('Specified offset has wrong size.'))
  end
else
  y=yIn-ones(size(yIn,1),1)*mean(yIn);
end

% if unittest mode
if any(strcmp(varargin,'unitTestMode'))
  testMode = true;
else
  testMode = false;
end

% filter
[yf,f,P] = SohFFTFilter(t,y,band);

% determine extreme values from filtered signal
peaks = analyseDecay(t,yf,prefactor,vararginSub{:});

tm   = peaks(ch).tm';
yfm  = peaks(ch).yfm';
tdel = peaks(ch).tdel';
del  = peaks(ch).del';

% initiate outputs
tCut    = t;
yCut    = y(:,ch);
yfCut   = yf(:,ch);
tmCut   = peaks(ch).tm';;
yfmCut  = peaks(ch).yfm';
tdelCut = peaks(ch).tdel';
delCut  = peaks(ch).del';

% manual cutting of axes
t1 = t(1);
t2 = t(end);
button=0;
flagUpdatePlot=0;
cumulatedOffset=0;
logDoPSDFit=false;
stencilLength = 8;

% dont open figure if in test mode
if testMode
  fh=[];
else
  fh = figure;  
  theme('light')
end

[fh,ax,LD,N,stddev,cfs,freq] = updatePlot(fh,tCut,yCut,yfCut,tmCut,yfmCut,tdelCut,delCut,band,fileName,ch,prefactor,cumulatedOffset,logDoPSDFit,stencilLength,testMode,vararginSub{:});

% stop here, if in test mode
if testMode
  return
end

while button~=3
    
  [t0(1),y0(1),button] = ginput(1);
  if button==3 || button==32 || button==113
    break
  end

  % offset up or down in steps of .01
  if button==30
    yf = yf+.01;
    cumulatedOffset=cumulatedOffset+.01;

    % determine extreme values from filtered signal
    peaks = analyseDecay(t,yf,prefactor,vararginSub{:});
    
    flagUpdatePlot = 1;
  end
  if button==31
    yf = yf-.01;
    cumulatedOffset=cumulatedOffset-.01;
    
    % determine extreme values from filtered signal
    peaks = analyseDecay(t,yf,prefactor,vararginSub{:});
    
    flagUpdatePlot = 1;
  end

  % offset up or down in steps of .1
  if button==28
    yf = yf-.1;
    cumulatedOffset=cumulatedOffset-.1;

    % determine extreme values from filtered signal
    peaks = analyseDecay(t,yf,prefactor,vararginSub{:});
    
    flagUpdatePlot = 1;
  end
  if button==29
    yf = yf+.1;
    cumulatedOffset=cumulatedOffset+.1;
    
    % determine extreme values from filtered signal
    peaks = analyseDecay(t,yf,prefactor,vararginSub{:});
    
    flagUpdatePlot = 1;
  end

  % offset based on mean of shown signal
  if button==122 %z
    yf = yf-mean(yfCut);
    cumulatedOffset=mean(yfCut);

    % determine extreme values from filtered signal
    peaks = analyseDecay(t,yf,prefactor,vararginSub{:});

    flagUpdatePlot = 1;
  end

  % update filter
  if button==102 %f
    clear peaks
    
    % input prompt for filter width
    prompt={'Lower bound [Hz]:','Upper bound [Hz]:'};
    name='Specify FFT filter';
    numlines=1;
    defaultanswer={num2str(band(1)),num2str(band(2))};
    
    bandTemp = inputdlg(prompt,name,numlines,defaultanswer);
    if isempty(bandTemp)
      bandTemp = {num2str(band(1)),num2str(band(2))};
    end
    band     = [str2num(bandTemp{1}) str2num(bandTemp{2})];
    
    % filter data
    [yf,f,P] = SohFFTFilter(t,y,band);
    
    % determine extreme values from filtered signal
    peaks = analyseDecay(t,yf,prefactor,vararginSub{:});

    flagUpdatePlot = 1;
  end

  % update stencil length for amplitude-dependent damping
  if button==97 %a
    % input prompt for filter width
    prompt={'Set sliding window width'};
    name='Amplitude-dependent damping display';
    numlines=1;
    defaultanswer={num2str(stencilLength)};
    
    bandTemp = inputdlg(prompt,name,numlines,defaultanswer);
    if isempty(bandTemp)
      bandTemp = {num2str(9)};
    end
    stencilLength  = [str2num(bandTemp{1})];

    flagUpdatePlot = 1;
  end
  
  
  % change column
  if button>=49 && button<=57
    ch=button-48;
    while ch>size(y,2)
      warning(sprintf(['Only valid data columns is 1:%i. You asked for column %i.\nRetry.'],...
                      size(y,2),ch));
      [t0(1),y0(1),button] = ginput(1);
      ch=button-48;
    end
      
    flagUpdatePlot = 1;
  end
  
  % obtain damping from PSD fitting (button 's')
  if button==115
    logDoPSDFit    = true;
    flagUpdatePlot = 1;
  end
  
  if button==112 && ~flagPrint
    fprintf('\nConsidering file: %s\n',fileName);
    fprintf('Sample rate: %0.2f Hz\n',1/mean(diff(t)));
    fprintf('No. channels: %i\n',size(y,2));
    fprintf('Useful stats of the FILTERED signal y:\n')
    fprintf('%7s\t%7s\t%7s\t%7s\t%7s\t%10s\t%9s\t%9s\t%8s\t%7s\t%7s\n',...
            'col. no','t(1)','t(2)','n peaks','<freq>','log. decr.','Min.|yMax|','Max.|yMax|','std(y)',...
            'flim(1)','flim(2)');
    fprintf('%7s\t%7s\t%7s\t%7s\t%7s\t%10s\t%8s\t%9s\t%9s\t%7s\t%7s\n',...
            '[-] ','[s] ','[s] ','[-] ','[Hz] ','[%] ','[-] ','[-] ','[-] ','[Hz] ','[Hz] ');
    fprintf('--------------------------------------------------------------------------------------------------------\n')

    flagPrint  = 1;
    flagUpdatePlot = 0;
  end
  
  if button==112
    tmTemp  = peaks(ch).tm';
    yfmTemp = peaks(ch).yfm';
    yMax    = max(abs(yfmTemp(tmTemp>=tCut(1) & tmTemp<=tCut(end))));
    yMin    = min(abs(yfmTemp(tmTemp>=tCut(1) & tmTemp<=tCut(end))));
    yStd    = std(yfCut);
    
    fprintf('%7i\t%7.2f\t%7.2f\t%7i\t%7.4f\t%10.2f\t%9.4f\t%9.4f\t%8.4f\t%7.2f\t%7.2f\n',...
            ch,tCut(1),tCut(end),N,freq,LD,yMin,yMax,yStd,band(1),band(2))

    flagUpdatePlot = 0;
    
    clear tmTemp yfmTemp yMax yMin
  end

  if button==1
    hold on
    hl(1)=plot(gca,t0(1)*[1 1],get(gca,'ylim'),'r-');

    [t0(2),y0(2),button] = ginput(1);
    hl(2)=plot(gca,t0(2)*[1 1],get(gca,'ylim'),'r-');

    % make sure we keep in allowed interval of time
    if t0(1)<0
      t0(1)=0;
    end
    if t0(2)>t(end)
      t0(2)=t(end);
    end
    
    % if zoom should be reset
    if diff(t0)<=0
      t1 = t(1);
      t2 = t(end);
      % if zoom should be made
    elseif diff(t0)~=0 && button==1
      t1 = t0(1);
      t2 = t0(2);
    end
    
    flagUpdatePlot=1;
  end
  
  % export figure (button 'e')
  if button==101 
    SohPrint(datestr(clock,30));
  end
  
  if flagUpdatePlot
    % temporary variables, for brevity
    tm   = peaks(ch).tm';
    yfm  = peaks(ch).yfm';
    tdel = peaks(ch).tdel';
    del  = peaks(ch).del';

    % update outputs
    tCut    = t(t>t1 & t<t2);
    yCut    = y(t>t1 & t<t2,ch);
    yfCut   = yf(t>t1 & t<t2,ch);
    Indices = find(tm>t1 & tm<t2);
    tmCut   = tm(Indices);
    yfmCut  = yfm(Indices);
    tdelCut = tdel(Indices(1:end-1));
    delCut  = del(Indices(1:end-1));
    
    [fh,ax,LD,N,stddev,cfs,freq] = updatePlot(fh,tCut,yCut,yfCut,tmCut,...
                                              yfmCut,tdelCut,delCut,band,...
                                              fileName,ch,prefactor,cumulatedOffset,...
                                              logDoPSDFit,stencilLength,testMode,vararginSub{:});
    flagUpdatePlot=0;
    logDoPSDFit=false;
  end
end

close(fh);



% ----------------------------------------------------------------------------------------------------
% ----------------------------------------------------------------------------------------------------
% ----------------------------------------------------------------------------------------------------
function peaks = analyseDecay(t,yf,prefactor,varargin);

for i=1:size(yf,2)
  thisYf = yf(:,i);
  if (max(thisYf)-min(thisYf)) % prevent octave throwing errors
    thisYf = 2*thisYf/(max(thisYf)-min(thisYf)); % normalise
  end
  hest   = diff(ceil(diff(thisYf)));
  idmin  = find(hest>0)+1; % minima
  idmax  = find(hest<0)+1; % maxima
  
  if ~any(strcmp(varargin,'onesided')) % all peaks
    ids = sort([idmin;idmax]);
  else
    ids = sort(idmax);
  end
  peaks(i).tm = t(ids);
  peaks(i).yfm = yf(ids,i);

  % vectors of LD's and corresponding times
  peaks(i).del  = 100*log(abs(peaks(i).yfm(1:end-1))./abs(peaks(i).yfm(2:end)))/prefactor;
  peaks(i).tdel = (peaks(i).tm(2:end)+peaks(i).tm(1:end-1))/2;
end



% ----------------------------------------------------------------------------------------------------
% ----------------------------------------------------------------------------------------------------
% ----------------------------------------------------------------------------------------------------
function [fh,ax,LD,N,stddev,cfs,freq]=updatePlot(fh,t,y,yf,tm,yfm,tdel,del,band,fileName,ch,prefactor,cumulatedOffset,logDoPSDFit,stencilLength,testMode,varargin);
  
% find average LD from a line fit 
N    = length(tm);                               % number of y_{max}
cfs  = polyfit(tm,log(yfm),1);                   % fitting line for y_{max} vs time plot
cfs0 = polyfit(prefactor*(1:N),log(abs(yfm)),1); % new fit: one-indexed (cf definition of LD) 
LD   = -100*cfs0(1);                             % LD obtained from fitting line
freq = prefactor*(length(tm)-1)/(tm(end)-tm(1)); % frequency

% find average LD on subsets, for amplitude-dependence plot 
if length(yfm)>stencilLength
  kk=0;
  for i=((stencilLength-1)/2)+1:length(yfm)-((stencilLength-1)/2)
    kk=kk+1;
    ids     = i-((stencilLength-1)/2):i+((stencilLength-1)/2);
    thisYfm = yfm(ids); % peak values of stencil
    thisTfm = tm(ids);  % associated times 
    thisTf  = t(t>=min(thisTfm(1)) & t<=max(thisTfm)); %  associated time vector
    thisYf  = yf(t>=min(thisTfm(1)) & t<=max(thisTfm)); %  associated filtered vector
    cfsX = polyfit(prefactor*(1:stencilLength),log(abs(thisYfm)),1); % new fit: one-indexed (cf definition of LD) 
    subMax(kk)    = max(abs(thisYfm));
    subMaxmin(kk) = min(abs(thisYfm));
    subStd(kk)    = std(thisYf);
    subDel(kk)    = -100*cfsX(1);
  end
else
  subDel    = del;
  subMax    = NaN*ones(size(del));
  subMaxmin = NaN*ones(size(del));
  subStd    = NaN*ones(size(del));
end
% statistics
stddev = std(subDel);

if testMode
  ax = [];
  return
end


% initial plot: plot the entire signal
figure(fh); clf
ax(1) = subplot(3,2,[1 2]); hold on; grid on
p3=plot(t,real(y)-real(yf),'m','linewidth',1);  % error data
p2=plot(t,real(y),'b','linewidth',1);           % raw data
p1=plot(t,real(yf),'r','linewidth',2);          % filtered signal used for analysis
plot(tm,yfm,'ro','linewidth',2)                 % y_{max}
ylabel('Signal [?]')%,'rotation',0)
title(sprintf('File: %s, Number of extremes N = %4.0i, <LD> = %6.4f%%, f = %4.4fHz, std(y) = %4.2f, |y_{max}| = %4.2f',...
              fileName,...
	      length(yfm),...
	      LD,...
	      freq,...
	      std(yf),...
	      max(abs(yfm))),'interpreter','none');
text(0.8,.1,...
     sprintf('data col %i, offset %5.6f',ch,cumulatedOffset),...
     'units','normalized','fontsize',14,'color','r')
legend([p2 p1 p3],'Raw data','Filtered data','Abs. error')
hold off
ylim(2*max(abs(yf))*[-1 1])

% plot showing only maximal points
ax(2) = subplot(3,2,[3 4]); hold on; grid on
plot(tm,real(polyval(cfs,tm)),'k','linewidth',2);
plot(tm,real(log(yfm)),'r.','linewidth',2)
legend('Fitting line','ln(y_{max})');
ylabel('ln y_{max}')%,'rotation',0)
hold off

% plot showing spectrum
ax(3) = subplot(3,2,5); hold on; grid on
if std(diff(t))>0
  [f,P]=SohFFT(t,y-mean(y),[],'interpolate');
else
  [f,P]=SohFFT(t,y-mean(y),[],'interpolate');
end
h1=semilogy(f,P,'b');
lims = get(gca,'ylim');
mx = .98*lims(2);
% $$$ h2=plot([band(1) band(1) band(2) band(2)],...
% $$$         [0 mx mx 0],'r-','linewidth',2);
h2=plot(f(f>=band(1) & f<=band(2)),P(f>=band(1) & f<=band(2)),'r-','linewidth',1);
xlabel('Frequency [Hz]')
ylabel('S')
if any(strcmp(varargin,'spectrum'))
  if ~ischar(varargin{find(strcmp(varargin,'spectrum'))+1})
    xlim(varargin{find(strcmp(varargin,'spectrum'))+1})
  end
else
  xlim([0 51])
end
set(gca,'yscale','log')
xlSpec = xlim;
ylim([10^floor(log10(min(mean(P(2:end,:),2)))) 10^ceil(log10(max(mean(P(2:end,:),2))))])
title(sprintf('Spectrum in the [%i %i]Hz range. Bandpass [%.2f %.2f]Hz used.',xlSpec(1),xlSpec(2),band(1),band(2)));
legend([h1,h2],'Spectrum of shown signal segment','Frequency band used for SohFindLD','location','southeast')
if logDoPSDFit
  if exist('SohFit1DOFResponse')
    output = SohFit1DOFResponse(f,P,band);
    plot(output.frequency,output.frequencyResponseCurveFit,'m','linewidth',2);
    text(xlSpec(1)+0.1*diff(xlSpec),get(gca,'ylim')*[1 0]'+.1*diff(get(gca,'ylim')),...
         sprintf('log dec = %.2f, f_p = %.2f',...
                 output.dampingDecrement*100,...
                 output.eigenFrequency),'background','w')
  end
end
hold off

% plot showing LD vs signal
ax(4) = subplot(3,2,6); hold on; grid on
plot(abs(yfm(1:end-1)),real(del),'.','color',.8*[1 1 1])
plot(subMax,subDel,'b.')
plot(subMaxmin,subDel,'bx')
plot(subStd,subDel,'r.','markersize',15)
xl = xlim;
plot(xl,real(LD)*[1 1],'-','linewidth',2,'color',0*[1 1 1]);
plot(xl,real(LD)*[1 1]+stddev,'-','linewidth',1,'color',.5*[1 1 1]);
plot(xl,real(LD)*[1 1]-stddev,'-','linewidth',1,'color',.5*[1 1 1]);
%legend(ax(4),'LD',['<LD>'],['<LD> +/- \sigma(LD)'])
ylabel('LD [%]','rotation',0)
xlabel('Signal std or peak [?]')
title(sprintf('Colored markers use %i point sliding window estimate',stencilLength))
text(.12,.05,'DONT FORGET YOUR ENGINEERING SENSES!','units','normalized','fontweight','bold','color','red','fontsize',14)
text(xl(2),real(LD),sprintf('%.2f%%',real(LD)))
text(xl(2),real(LD)-stddev,sprintf('%.2f%%',real(LD)-stddev))
text(xl(2),real(LD)+stddev,sprintf('%.2f%%',real(LD)+stddev))
hold off

% set xlim of the last 2 plots to follow the 1st
set(ax(1),'xlim',[t(1) t(end)])
set(ax(2),'xlim',get(ax(1),'xlim'))

% set axis
set(ax(1),'position',get(ax(1),'position').*[0 1 0 0]+[.1 0 .8 .22])
set(ax(2),'position',get(ax(2),'position').*[0 1 0 0]+[.1 0 .8 .22])
set(ax(3),'position',get(ax(3),'position').*[0 1 0 0]+[.1 0 .4 .22])
if length(subDel)>1
  set(ax(4),'ylim',[min(subDel)-.1*(max(subDel)-min(subDel)) max(subDel)+.1*(max(subDel)-min(subDel))])
end
% place figure nicely on all screens
scsz = get(0,'screensize');
set(fh,'position',[.1*scsz(3) .02*scsz(4) .8*scsz(3) .9*scsz(4)]);
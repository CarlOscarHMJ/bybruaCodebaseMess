% March 2012 TS. 
%
% ********************************************
% ** Please notify TS if you find and error **
% ********************************************
%
% [f, P] = sohFFT(t,y) generates the power spectrum vector P with
% corresponding frequency vector f from input signal column vector y
% with time vector t. y can be a matrix that consists of column data,
% i.e., y=[ch1 ch2 ... chN].
%
% P has unit [y]^2*s, where [y] is the unit associated with input vector y.
%
% [f, P] = sohFFT(t,y,Nb) generates the power spectrum based on block
% length `Nb'. The script divides y into pieces of length Nb, calculates
% the power spectrum for each and outputs the block average
% spectras. In case length(y)~=integer*Nb, superfluous samples are
% discarded.
%
% If no output is specified, sohFFT plots the power spectrum
%
% sohFFT(t,y,Nb,varargin) takes additional inputs:
%
% 'interpolate' takes the signal vector y sampled on a non-equidistant
% temporal grid t and interpolates in a linear fashion to a equidistant time
% grid ti before conducting the fft. Note that length(t) = length(ti).
%
% 'xscale' and/or 'yscale' can be set to 'linear' or 'log'. This is only
% relevant when the function produces a plot.
%
% Use [] as placeholder, if no block averaging should to be done.
 
% Revisions:
% ----------
% 2012-09-20 TS  Minor bug fixes. 
% 2012-09-21 TS  Major bug fix: fft on yi NOT y. Also: ti is now column.
% 2012-10-01 TS  f is now column, and no output if nargout==0;
% 2012-10-08 TS  Minor improvement: Placement of figure is now
%                compatible with all screen resolutions.
% 2012-12-21 TS  Changed color on FFT plot, to spare printer blue :-)
% 2013-05-24 TS  Enabled possiblility to specify axis scaling in plot. 
% 2013-06-06 AHT deactivate disp('Interpolation enabled')
% 2013-12-11 TS  Added hold off on plots
% 2014-12-05 TS  Changed '&' and '|' to '&&' and '||' in if-statements
% 2015-05-04 TS  log scale on vertical axis is now default.
% 2016-06-13 TS  fixed a bug that included DC and Nyquist frequency twice
% 2016-12-20 TS  now disregards DC frequency in integration of PSD
% 2017-11-08 TS  changed ylabel on plot
% 2017-12-15 TS  corrected spectrum intrgration for variance from 'trapz'
%                to 'sum'
% 2018-01-05 TS  corrected n to f in variance integration cf. bug fix 20171215

%
% To-do:
% ------
% make possible normalization of spectrum

function [f, P] = SohFFT(t,y,Nb,varargin);

if min(size(y))==1
    y=y(:);
end

if mod(length(t),2) % an even number of data is needed.
    t = t(1:end-1);
    y = y(1:end-1,:);
end

if nargin==2 || isempty(Nb)
    Nb = length(t); % block length = signal length
end

% break down varargin
logInterpolate = 0;
xscale = 'linear';
yscale = 'log';

if length(varargin)
    for i=1:length(varargin)
        if strcmp(varargin{i},'xscale')
            xscale = varargin{i+1};
        elseif strcmp(varargin{i},'yscale')
            yscale = varargin{i+1};
        elseif strcmp(varargin{i},'interpolate')
            logInterpolate = 1;
        end
    end
end



% prepare
N    = length(t);                 % signal length, for frequency
M    = floor(length(t)/Nb);       % number of blocks

Fs   = (N-1)/(t(end)-t(1));       % (Average) sample frequency

f    = Fs/2*linspace(0,1,Nb/2+1); % frequency vector

if Nb>N
    error('Block length larger than signal length.')
end

for i=1:length(y(1,:)) % loop over no of columns
    
  if nargin==4 % interpolation
    if logInterpolate
      %       disp('Interpolation enabled')
      
      ti = linspace(t(1),t(end),length(t))'; % equidistant time
      for j=1:length(y(1,:))
        yi(:,j) = interp1(t,y(:,j),ti,'linear'); % interpolated data
      end
    else
      error('Wrong property assigned during call to sohFFT')
    end
  else
    yi=y;
  end
    
  for k=1:M % loop over blocks
    yt       = yi( ((k-1)*Nb+1):k*Nb,i ); % extract relevant data
    
    Yt       = fft(yt);                  % do fft
        
    Pt2(:,k) = abs(Yt(1:Nb/2+1)).^2;      % make power spectrum
  end
    
  P(:,i) = mean(Pt2,2); % block average
    
end

P            = P/(Fs*Nb); % bring out here, for speed.
P(2:end-1,:) = 2*P(2:end-1,:); % only consider DC and Nyquist frequency once!
f            = f(:);


if nargout==0 % make plots etc, if no output is specified
    
  fprintf('Signal variance and area(S) comparison. area(S) disregards DC frequency\n')
  for i=1:length(y(1,:))
    varY = var(y(:,i));
    intP = sum(P(2:end))*mean(diff(f));
    difP = -(varY-intP)/varY*100;
    fprintf('input channel %2.2i: var(y)=%2.4f, area(S)=%2.4f, diff=%2.4f%%\n',i,varY,intP,difP)
    legendText{i} = sprintf('ch %2i',i);
  end
    
  scrSz = get(0,'ScreenSize');
    
  figure(1000), clf
  if size(P,2)==1
    plot(f,P,'.-k'), hold on
  else
    plot(f,P), hold on
    legend(legendText)
  end
  xlabel('Frequency [Hz]')
  ylabel('Variance spectrum')
  set(gcf,'position',scrSz+[.15*scrSz(3) .15*scrSz(4) -.30*scrSz(3) -.5*scrSz(4)])
  set(gca,'position',[.05 .1 .93 .85])
  set(gca,'yscale',yscale,'xscale',xscale)
  
  if length(y(1,:))==1
    plot(f(P==max(P)),max(P),'r.','markersize',25)
    text(.8,.8,sprintf('area(S) = %2.6f\n\n   var(y) = %2.6f',trapz(f(2:end),P(2:end)),var(y)),...
         'edgecolor','k','units','normalized')
    text(f(P==max(P))+.05*(f(end)-f(1)),.9*max(P),...
         sprintf('S_{max}=%2.2f @ f=%2.2f Hz',max(P),f(P==max(P))))
  end
  hold off
  clear f P
end







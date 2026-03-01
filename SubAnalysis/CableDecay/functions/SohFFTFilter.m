% Initiated march 2012 TS
%
% ********************************************
% ** Please notify TS if you find and error **
% ********************************************
%
% [yf] = SohFFTFilter(t,y,band) is a fourier bandpass filter, which
% filters the input vector y in fourier space, using frequency bands
% specified in each row of the N-by-2 array "band". y can be a matrix
% that consists of column data, i.e., y=[ch1 ch2 ... chN].
%
% [...] = SohFFTFilter(t,y,band,'interpolate') with the option
% 'interpolate' takes the input signal y sampled irregularly and
% interpolates to an equidistant grid ti =
% linspace(t(1),t(end),length(t)), before filtering.
%
% [...] = SohFFTFilter(t,y,band,'outside') with the option 'outside'
% has the opposite effect: it filters away components INSIDE the
% specified band.
%
% [yf,f,P,Py] = sohFFTFilter(t,y,band) outputs in addition to the filtered
% signal yf, a frequency vector f and its power spectrum P. Py is the
% spectrum of y. If no band is specified, no filtering is done. In that
% case, yf=y, and P is the power spectrum of y.
%
% If no output is specified and input y is a one-column vector, the
% function generates a plot of the power spectra of the input signal
% and the filtered signal, and a plot of the unfiltered and filtered
% signal, respectively.
 

% Revisions:
% ----------
% 2012-09-20 TS  The function now handles input vectors of uneven length.
% 2012-10-09 TS  The function now allows "band" to be N-by-2. 
%                Also, argument 'outside' is enabled.
% 2012-10-09 TS  Bands are allowed to overlap
% 2013-04-11 TS  Output frequency vector is now column.
% 2013-06-19 TS  Added output Py
% 2013-12-11 TS  Added hold off on plots
% 2014-10-15 JTR Added windowing option
% 2014-12-05 TS  Changed '&' and '|' to '&&' and '||' in if-statements
% 2015-11-12 TS  Removed workspace notification that 'interpolation is enabled'
% 2016-06-13 TS  * Fixed a bug that included DC and Nyquist frequency twice
%                * Fixed a bug: Now all columns of Py are updated. 
% 2016-06-21 TS  * Now plots all columns.
% 2016-11-17 TS  Changed the plot window
% 2017-04-10 TS  fixed an issue with ||/&& in matlab's legend
% 2017-11-08 TS  changed ylabel on plot
% 2018-30-07 SHH Removed window options. (Not implemented correctly.)

function [yf,frequencies,P,Py] = SohFFTFilter(varargin);

argumentsList = [ AddArgumentDescription('interpolate','interpolates to an equidistant time axis',0,''              ,'false')
                  AddArgumentDescription('outside'    ,'inverts the window function'             ,0,''              ,'false')];
AssignInput(varargin,argumentsList,3);

time    = varargin{1};
yValues = varargin{2};
band    = varargin{3};

assert(isnumeric(time), 'SOH: time has to be a numeric')
assert(isnumeric(yValues), 'SOH: yValues has to be a numeric')
assert(isnumeric(band), 'SOH: band has to be a numeric')

if min(size(yValues))==1
  yValues=yValues(:);
end

% prepare
N           = length(time);                 % signal length, for frequency
Fs          = (N-1)/(time(end)-time(1));    % (Average) sample frequency
frequencies = Fs/2*linspace(0,1,N/2+1)';    % frequency vector


if (interpolate)
  for j=1:size(yValues,2)
    yValues(:,j) = interp1(time,yValues(:,j),linspace(time(1),time(end),length(time)));
  end
end

for i=1:length(yValues(1,:)) % loop over no of columns
  ySpectral = fft(yValues(:,i)); % do fft
  
  if nargout==0 || nargout==4  % save for plotting
    ySpectralOrig = ySpectral;
  end
  
  
  if nargin>2 % filter
    
    if (i == 1) % only create the windows once
      f = ones(size(frequencies)); % "master" index vector of
                                   % fourier-coefficients to be deleted.
      window = zeros(size(frequencies));
      
      for j=1:size(band,1) %loop over the bands
        startFrequency    = band(j,1);
        endFrequency      = band(j,2);
        frequencyInterval = endFrequency-startFrequency;
        
        if (startFrequency > endFrequency)
          error('Frequencies in specified band must be specified in increasing order.')
        end
        
        thisWindow = (frequencies >= startFrequency & frequencies <= endFrequency);        
        window = max(window,thisWindow);
      end
      
      if (outside)
        window = 1-window;
      end
      
      if (~mod(N,2)) % take into account that length(N) may be uneven
                     %             Y([window ; flipdim(window(2:end-1),1)])=0;
        window = [window ; flipdim(window(2:end-1),1)];
      else
        window = [window ; flipdim(window(2:end),1)];
      end
    end
    ySpectral = ySpectral.*window;
  else % if no filter is specified, nothing is filtered
       %         f = ~frequencies;
  end
  
  yf(:,i) = ifft(ySpectral);                          % inverse fft
  
  P(:,i)       = abs(ySpectral(1:floor(N/2)+1)).^2/(Fs*N);    % power spectrum of filtered signal
  P(2:end-1,i) = 2*P(2:end-1,i); % only consider DC and Nyquist frequency once!
  
  if nargout==0 || nargout==4
    Py(:,i)       = abs(ySpectralOrig(1:floor(N/2)+1)).^2/(Fs*N); % power spectrum of input
    Py(2:end-1,i) = 2*Py(2:end-1,i); % only consider DC and Nyquist frequency once!
  end
end

if max(max(imag(yf)))>1e-14
  warning(sprintf(['Imaginary parts of %0.2e encountered.\n',...
                   'If you are running Matlab 6.5 or older this is possibly nothing of concern.\n',...
                   'Imaginary parts are ignored in the output variable yf.\n'],...
                  max(max(imag(yf)))))
end

% get rid of imaginary part.
yf = real(yf);


% make plots etc, if no output is specified
if nargout==0 
  window = window(1:length(frequencies));
  figure(1000), clf
  subplot(2,1,1)
  semilogy(frequencies,Py,'k-'), hold on
  plot(frequencies(find(window)),P(find(window)).*window(find(window)),'r','linewidth',2), hold on
  xlabel('Frequency')
  ylabel('Variance spectrum')
  legend('Spectrum of filtered signal','PSD of input signal')
  set(gca,'position',[.05 .55 .9 .4])
  hold off
  
  subplot(2,1,2)
  p1=plot(time,(yValues-yf),'color',.8*[0 1 0]);  hold on
  p2=plot(time,yValues,'k-');
  p3=plot(time,yf,'r-','linewidth',2);
  xlabel('Time')
  ylabel('Signal')
  legend([p2,p3,p1],'Input signal','Filtered signal','Absolute error')
  set(gca,'position',[.05 .07 .9 .4],'ylim',max(max(yValues))*[-1 1])
  hold off
  
  SohMaxFigure
end

function LDdamping=fitDecay(y,t,ax1,ax2)

% find local maxima
TF = islocalmax(y);


% calculate damping for each pair of maxima
idx = find(TF);
for i=1:length(idx)-1
    dampingLocal(i) = log(y(idx(i))/y(idx(i+1)));
end
LDdamping.dampingLocal = dampingLocal;
LDdamping.dampingLocalMean = mean(dampingLocal);


% fit linear curve in semilogy
[p,S] = polyfit(t(TF),log(y(TF)),1);
logy0 = polyval(p,t(TF));
decayRate = p(1);
if not(isreal(decayRate))
    decayRate=0;
end

% HL trial
rsquared = 1 - (S.normr/norm(log(y(TF)) - mean(log(y(TF)))))^2;
S.rsquared = rsquared;

LDdamping.fittedDamping = -decayRate*mean(diff(t(TF))); % decay rate * peak time differences
LDdamping.rsquared = S.rsquared; % check here

if nargin>2
    %ax1=axes();
    hold(ax1,'on')
    plot(ax1,t,y,'k','DisplayName','signal')
    plot(ax1,t(TF),y(TF),'.r','DisplayName','local maxima');
    plot(ax1,t(TF),exp(logy0),'-b','DisplayName',sprintf('fitted curved, r^2 = %0.4f',S.rsquared));
    grid(ax1,'on')
    xlabel(ax1,'[s]')
    box(ax1,'on')
    legend(ax1,'show')
    

    %ax2= axes();
    hold(ax2,'on')
    semilogy(ax2,t(TF),y(TF),'r.','DisplayName','Local maxima')
    semilogy(ax2,t(TF),exp(logy0),'-b','DisplayName',sprintf('fitted curved, r^2 = %0.4f',S.rsquared))
    title(ax2,sprintf('LD Damping = %0.3f %%',LDdamping.fittedDamping*100))
    grid(ax2,'on')
    legend(ax2,'show')
    xlabel(ax2,'[s]')
    box(ax2,'on')
    set(ax2,'YMinorTick','on','YScale','log');
    
end
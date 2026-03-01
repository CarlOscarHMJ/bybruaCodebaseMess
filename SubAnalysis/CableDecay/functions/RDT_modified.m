function [R,t,ind] = RDT_modified(y,ys,T,dt)
%
% [R] = RDT(y,ys,T,dt) returns the free-decay response (R) by
% using the random decrement technique (RDT) to the time serie y, with a
% triggering value ys, and for a duration T
%
% INPUT:
%   y: time series of ambient vibrations: vector of size [1xN]
%   dt : Time step
%   ys: triggering values (ys < max(abs(y)) and here ys~=0)
%   T: Duration of subsegments (T<dt*(numel(y)-1))
% OUTPUT:
%   R: impusle response function
%   t: time vector asociated to R
%
% Author: E. Cheynet - UiB - last modified 14-05-2020

%%


if T>=dt*(numel(y)-1)
    error('Error: subsegment length is too large');
else
    % number of time step per block
    nT = round(T/dt); % sec
end

if ys==0
    error('Error: ys must be different from zero')
elseif or(ys >=max(y),ys <=min(y)),
    error('Error:  ys must verifiy : min(y) < ys < max(y)')
else
    % find triggering value
    ind=find(diff(y(1:end-nT)>ys)~=0)+1;

end

% construction of decay vibration
R = zeros(numel(ind),nT);
for ii=1:numel(ind)
    R(ii,:)=y(ind(ii):ind(ii)+nT-1);
end

% averaging to remove the random part
R = mean(R);
% normalize the R
R = R./R(1);
% time vector corresponding to the R
t = linspace(0,T,numel(R));

end



%
% return
%
% close all
% figure
% hold on
% plot(y,'k')
%
% TF0 = y(1:end-nT)>ys; % sel any data point that is above ys
% idx0 = find(TF0);
% plot(idx0,y(idx0),'.b','displayname','y>ys')
% TF1 = diff(TF0); % find local changes where
% idx1 = find(TF1~=0)+1 ; % sel
% plot(idx1,y(idx1),'.r','displayname','segment heads ')
%
% legend
%
% % construction of decay vibration
% R0 = zeros(numel(idx1),nT);
% for ii=1:numel(idx1)
%     R0(ii,:)=y(idx1(ii):idx1(ii)+nT-1);
% end
%
% % averaging to remove the random part
% %R1 = mean(R0);
%
% figure
%
% %plot(R0','-', 'color', [.5 .5 .5])
% %title(['time trace of ' num2str(length(idx1)) ' segments'])
%
% noavg = [1 10 50 100 400 802]
%
% for iii=1:length(noavg)
%     R1 = mean(R0(1:noavg(iii),:),1);
%     subplot(2,3,iii)
%
%     plot(R0','-', 'color', [.5 .5 .5])
%     hold on
%     plot(R1,'-b')
%     title(['no averaged segments =' num2str(noavg(iii))])
%
% end
%
%






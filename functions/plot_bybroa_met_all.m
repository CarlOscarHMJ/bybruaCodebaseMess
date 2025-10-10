function plot_bybroa_met_all(T)
if ~istimetable(T)
    t = T.Time; if ~isdatetime(t), t = datetime(string(t)); end
    T = table2timetable(T,'RowTimes',t); if any(strcmp('Time',T.Properties.VariableNames)), T.Time = []; end
end

vn = T.Properties.VariableNames;
keep = false(size(vn));
for i=1:numel(vn), keep(i) = isnumeric(T.(vn{i})) || isdatetime(T.(vn{i})) || isduration(T.(vn{i})); end
T = T(:,keep);

T = sortrows(T);
T1 = retime(T,'regular','mean','TimeStep',minutes(1));

[RainCum_mm, RainRate_mmph] = derive_precip(T1.Weather_1, T1.Weather_2);
T1.RainCum_mm = RainCum_mm;
T1.RainRate_mmph = RainRate_mmph;

T1 = renamevars(T1,vars,newNames)

figure('Name','Overview','Color','w'); tiledlayout(5,1,'Padding','compact','TileSpacing','compact')
nexttile
yyaxis left, plot(T1.Time,T1.Wind_mps,'LineWidth',1), ylabel('Wind [m/s]')
yyaxis right, plot(T1.Time,wrapTo360(T1.WindDir_deg),'.','MarkerSize',3), ylabel('Dir [deg]'); title('Wind & direction'); grid on
nexttile
bar(T1.Time,T1.RainRate_mmph,'BarWidth',1), ylabel('Rain rate [mm/h]'); yyaxis right, plot(T1.Time,T1.RainCum_mm,'k','LineWidth',1), ylabel('Cumulative [mm]'); title('Precipitation'); grid on
nexttile
plot(T1.Time,T1.Weather_1,'LineWidth',1); hold on; plot(T1.Time,T1.Weather_2,'LineWidth',1); hold off
legend('Weather\_1','Weather\_2','Location','best'); ylabel('Sensor values'); title('Weather_1 vs Weather_2'); grid on
nexttile
yyaxis left, plot(T1.Time,T1.AirTemp_degC,'LineWidth',1), ylabel('Temp [°C]'); yyaxis right, plot(T1.Time,T1.RelHum_pct,'LineWidth',1), ylabel('RH [%]'); title('Temperature & RH'); grid on
nexttile
plot(T1.Time,T1.AirPress_bar,'LineWidth',1), ylabel('Pressure [bar]'); xlabel('Time'); title('Air pressure'); grid on

W = T.Wind_mps; D = wrapTo360(T.WindDir_deg); m = isfinite(W) & isfinite(D); W = W(m); D = D(m);
figure('Name','WindRose & Joint','Color','w'); tiledlayout(1,2,'Padding','compact','TileSpacing','compact')
nexttile
dirEdges = 0:30:360; spdEdges = [0 2 5 8 12 20 40];
P = histcounts2(D,W,dirEdges,spdEdges,'Normalization','probability');
theta = deg2rad(dirEdges(1:end-1)+15); bw = deg2rad(30); hold on
ax = gca; ax.ThetaZeroLocation='top'; ax.ThetaDir='clockwise';
for k=1:numel(theta), r0=0; for b=1:size(P,2), r1=r0+P(k,b); patch(polar_sector(theta(k),bw,r0,r1),'EdgeColor','none'); r0=r1; end, end
title('Wind rose (% time)'); legend(compose('%.0f–%.0f m/s',spdEdges(1:end-1),spdEdges(2:end)),'Location','southoutside'); hold off
nexttile
dirEdges2=0:10:360; spdEdges2=0:1:40;
H = histcounts2(D,W,dirEdges2,spdEdges2,'Normalization','probability');
imagesc(dirEdges2(1:end-1)+5, spdEdges2(1:end-1)+0.5, H'), axis xy
xlabel('Direction [deg]'); ylabel('Speed [m/s]'); title('Direction–speed probability'); colorbar; grid on

figure('Name','Diurnal & Monthly','Color','w'); tiledlayout(2,2,'Padding','compact','TileSpacing','compact')
nexttile
boxchart(hour(T1.Time),T1.Wind_mps), xlim([-0.5 23.5]), xlabel('Hour'), ylabel('Wind [m/s]'); title('Diurnal wind'); grid on
nexttile
boxchart(hour(T1.Time),T1.RainRate_mmph), xlim([-0.5 23.5]), xlabel('Hour'), ylabel('Rain [mm/h]'); title('Diurnal rain'); grid on
nexttile
[Gm,~]=findgroups(dateshift(T1.Time,'start','month')); tm = splitapply(@(t) t(1), T1.Time, Gm);
bar(tm, splitapply(@mean,T1.Wind_mps,Gm)); datetick('x','yyyy-mm','keepticks'); ylabel('Mean wind [m/s]'); title('Monthly mean wind'); grid on
nexttile
dRc = [0; diff(T1.RainCum_mm)]; dRc(dRc<0)=NaN;
Rday = retime(timetable(T1.Time,dRc,'VariableNames',{'mm'}),'daily','sum');
[Gmon,~]=findgroups(dateshift(Rday.Time,'start','month')); tm2 = splitapply(@(t) t(1), Rday.Time, Gmon);
bar(tm2, splitapply(@nansum,Rday.mm,Gmon)); datetick('x','yyyy-mm','keepticks'); ylabel('Rain [mm/month]'); title('Monthly precipitation'); grid on
end

function [Rc, Ri_mmph] = derive_precip(w1, w2)
s = @(v) mean([0; diff(v)]>=-1e-9,'omitnan') - 0.2*mean(v==0 | isnan(v));
if s(w1) >= s(w2), Rc = w1; else, Rc = w2; end
d = [0; diff(Rc)]; d(d<0) = NaN; Ri_mmph = d*60;
end

function xy = polar_sector(theta,dtheta,r0,r1)
N=16; th=linspace(theta-dtheta/2,theta+dtheta/2,N);
x1=r1*cos(th); y1=r1*sin(th); x0=r0*cos(fliplr(th)); y0=r0*sin(fliplr(th));
xy=[x1(:) y1(:); x0(:) y0(:)];
end

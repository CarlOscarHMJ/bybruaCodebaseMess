function DownloadCritData()

crit.Rain       = [0    inf];   % mm/h
crit.WindSpeed  = [8    12];    % m/s
crit.CableAngle = [45   65];    % deg

server = '';
%server = ConnectFtpServer('uis_bybrua_server');
%cleanupObj = onCleanup(@() close(server)); % ensures close() runs on function exit

try
    DownLoadRightCases(server,crit)
catch ME
    fprintf('Error in %s (line %d): %s\n',ME.stack(1).name,ME.stack(1).line,ME.message)
end

end
%% Helper functions
function DownLoadRightCases(server,crit)
%cd(server,'arkiv')
%YearFolders = dir(server);
% for loop for days in months in years
% Download full day
load("C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Bybrua\SubAnalysis\Precipitation sensor checkl\RecreateNIDPlot\ProcessedData\2020-02-21.mat")



% end for loop

end
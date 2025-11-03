function h = ConnectFtpServer(siteName,xmlPath)
% 21/10/2025 COH
% Logs on to the UiS ftp server
% Inputs
% siteName:     name of the site. Could be: Bybrua_Camera,Bybrua_UiS3,
%                                           CUSP_UIS0,CUSP_UIS1,CUSP_UIS2,
%                                           CUSP_UIS3,CUSP_UIS4,CUSP_UIS5,
%                                           Macal_Data,Trimble_2_ftp,
%                                           UiS_Bybrua_Server,
%                                           UiS_Lysefjord_Server,
%                                           UiS_Lysefjord_Server 2,
%                                           UiS_zxlidars,zxlidar5055_pull,
%                                           zxlidar5080_pull
% xmlPath:      Path to Filezilla xml file with login info.
%
% SPECIAL USES
% If nargin == 1, the function assumes standard xml location for logon
% If nargin == 0, the function will list the server names from xml file

if nargin < 2
    xmlPath = 'C:\Users\CarlOscar\OneDrive - Universitetet i Stavanger\Documents\PhD_Stavanger\Diverse\Filezilla access\FileZilla.xml';
    if nargin < 1
        disp('Printing siteNames')
        ListServers(xmlPath,'Name')
    end
end

cfg = readstruct(xmlPath);
servers = cfg.Servers.Server;

serverNames = [servers.Name];
serverID = strcmpi(siteName,serverNames);
s = servers(serverID);

if isfield(s.Pass,'encodingAttribute')
    pass = native2unicode(matlab.net.base64decode(s.Pass.Text));
else
    pass = '';
end

s.Host = s.Host + ":" + num2str(s.Port);

try
    if s.Protocol == 0 % FTP
        h = ftp(s.Host,s.User,pass);
    elseif s.Protocol == 1 % SFTP
        h = sftp(s.Host,s.User,pass);
    elseif s.Protocol == 3 % FTPS
        h = ftps(s.Host,s.User,pass);
    end
catch ME
    fprintf('Error in %s (line %d): %s\n',ME.stack(1).name,ME.stack(1).line,ME.message)
    fprintf('Perhaps the ftp protocol wasn''t implemented right\n')
end
end


function ListServers(xmlPath,Kind)
cfg = readstruct(xmlPath);

fprintf('Printing out all server details of kind: %s\n',Kind)
for i = 1:length(cfg.Servers.Server)
    fprintf('%i:\t%s\n',i,getfield(cfg.Servers.Server(i),Kind))
end
end
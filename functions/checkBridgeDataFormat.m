function checkBridgeDataFormat(Period,dataRoot)

if ~exist("dataRoot",'var')
    if isunix
        dataRoot = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data';
    else
        error('dataRoot missing!')
    end
end

foundFiles = FindLocalBridgeDataFiles(dataRoot, Period);

if isempty(foundFiles)
    error('No bridge data files found for the specified period. Ensure correct formatting of Period');
end

for ii = 1:numel(foundFiles)
    date = foundFiles(ii).date;
    path = foundFiles(ii).path;

    data = load(path);
    if ~isfield(data,'DailyData') || ~isfield(data.DailyData,'Acc')
        if isfield(data,'DailyData') && isempty(fieldnames(data.DailyData))
            delete(path);
            continue
        end
        if isfield(data,'data') && istimetable(data.data)
            conf.structtype = 'Bybroa';
            data.data.Properties.DimensionNames{1} = 'Time';
            DailyData = ConvertDataTable2DataStruct(conf,data.data);
            save(path,'DailyData');
            continue
        end

        playBeep
        keyboard
    end
    fprintf('Checked for date: %s\n',date)
end
end

function playBeep
fs = 44100;
dur = 2;

t = 0:1/fs:dur;
n = numel(t);

attackTime = 0.1;
releaseTime = 1;

attackSamples = round(attackTime*fs);
releaseSamples = round(releaseTime*fs);

sustainSamples = n - attackSamples - releaseSamples;
if sustainSamples < 0
    sustainSamples = 0;
end

envAttack  = linspace(0, 1, attackSamples);
envSustain = ones(1, sustainSamples);
envRelease = linspace(1, 0, releaseSamples);

env = [envAttack envSustain envRelease];
env = env(1:n);

sweep = sin(2*pi*(300 + 900*t).*t);

toneC = sin(2*pi*523.25*t) * 0.25;
toneE = sin(2*pi*659.25*t) * 0.20;
toneG = sin(2*pi*783.99*t) * 0.20;
chord = toneC + toneE + toneG;

arpFreqs = [1200 1500 1800 2400];
arp = zeros(size(t));
for k = 1:numel(arpFreqs)
    arp = arp + 0.1*sin(2*pi*arpFreqs(k)*t .* exp(-2*t));
end

y = (0.4*sweep + chord + arp) .* env;

sound(y, fs);
end
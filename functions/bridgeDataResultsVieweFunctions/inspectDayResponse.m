function freqInfo = inspectDayResponse(startDate, endDate, options)
% inspectDayResponse evaluates bridge stay cable response for a given time window.
arguments
    startDate 
    endDate 
    options.dataRoot string = '/home/carl/OneDrive/Documents/PhD_Stavanger/ByBrua/Analysis/Data'
    %options.cables string = ["C1E_y", "C1W_y"]
    options.sensor (1,1) string {mustBeMember(options.sensor, ["Conc", "Steel"])} = "Conc"
    options.applyFilter logical = true
    options.filterOrder double = 7
    options.filterLowFreq double = 0.4
    options.filterHighFreq double = 15
    options.nfft double = 2^11
    options.freqMethod string {mustBeMember(options.freqMethod, ["welch", "burg", "stft"])} = "welch"
    options.burgOrder double = 50
    options.figureFolder string = 'figures/RwivDiagnostics'
    options.plotTitle string = ""
end

startDate = formatDatetime(startDate);
endDate = formatDatetime(endDate, startDate);

byBroaOverview = getBridgeData(startDate, endDate, ...
                        dataRoot=options.dataRoot,...
                        applyFilter=options.applyFilter, ...
                        filterType='butter',...
                        filterOrder=options.filterOrder, ...
                        filterLowFreq=options.filterLowFreq, ...
                        filterHighFreq=options.filterHighFreq, ...
                        plotFilter=false, ...
                        plotTimeResponse=false);

if strlength(options.plotTitle) == 0
    options.plotTitle = sprintf('%s to %s', datestr(startDate, 'dd-mmm-yyyy HH:MM'), datestr(endDate, 'dd-mmm-yyyy HH:MM'));
end

freqInfo = plotAndSaveDiagnostics(byBroaOverview, options);
end

function dt = formatDatetime(inputDate, referenceDate)
% formatDatetime converts string/char arrays to datetime objects. 
% Uses referenceDate for the date portion if inputDate is only a time string.
if nargin < 2
    referenceDate = datetime.empty;
end

if ischar(inputDate) || isstring(inputDate)
    inputString = string(inputDate);
    if strlength(inputString) <= 8 && ~isempty(referenceDate)
        if strlength(inputString) <= 5
            inputString = inputString + ":00";
        end
        
        timePart = duration(inputString);
        dt = dateshift(referenceDate, 'start', 'day') + timePart;
    else
        try
            dt = datetime(inputString, 'InputFormat', 'yyyy-MM-dd HH:mm');
        catch
            dt = datetime(inputString);
        end
    end
else
    dt = inputDate;
end
end

function freqInfo = plotAndSaveDiagnostics(byBroaOverview, options)
% plotAndSaveDiagnostics calculates frequency responses and exports plots.
cableString = byBroaOverview.project.cableData.Properties.VariableNames;
options.cables = cableString(contains(cableString,'y'));
freqInfo = cell(length(options.cables), 1);

if strlength(options.figureFolder) > 0 && ~exist(options.figureFolder, 'dir')
    mkdir(options.figureFolder);
end
try
    currentCable = options.cables(1);
catch 
    currentCable = {'NoCable'};
end

try
    freqInfo{1} = byBroaOverview.plotRwivDiagnostic(currentCable, [], ...
        deckFields=["Conc_Z", "Steel_Z"], ...
        periodogramSensor=options.sensor, ...
        plotTitle=options.plotTitle, ...
        nfft=options.nfft, ...
        freqMethod=options.freqMethod, ...
        burgOrder=options.burgOrder, ...
        figureFolder=options.figureFolder);
catch executionError
    warning('Error processing cable %s: %s', currentCable{1}, executionError.message);
end
end

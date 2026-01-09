function report = dedupeAndSortWsdaCableData(dataRoot)
if nargin < 1 || strlength(string(dataRoot)) == 0
    dataRoot = fullfile("Data","WSDA_data");
end

dataRoot = char(dataRoot);

fileList = [ ...
    dir(fullfile(dataRoot, "**", "WSDA_W*.csv")); ...
    dir(fullfile(dataRoot, "**", "WSDA_W*.mat"))  ...
];

fileList = fileList(~[fileList.isdir]);

fullPaths = fullfile({fileList.folder}, {fileList.name});
fileNames = string({fileList.name});
[uniqueNames, ~, nameGroupIndex] = unique(fileNames, "stable");

duplicatesFolder = fullfile(dataRoot, "Duplicates");
if ~exist(duplicatesFolder, "dir")
    mkdir(duplicatesFolder);
end

keptPaths = strings(0,1);
duplicateMoves = strings(0,3);

for i = 1:numel(uniqueNames)
    groupIdx = find(nameGroupIndex == i);
    if numel(groupIdx) == 1
        keptPaths(end+1,1) = string(fullPaths{groupIdx});
        continue
    end

    groupPaths = string(fullPaths(groupIdx));
    alreadyInYearFolder = contains(groupPaths, filesep + digitsPattern(4) + filesep);
    keepCandidates = groupPaths(alreadyInYearFolder);

    if isempty(keepCandidates)
        keepPath = groupPaths(1);
        dupPaths = groupPaths(2:end);
    else
        keepPath = keepCandidates(1);
        dupPaths = groupPaths(groupPaths ~= keepPath);
    end

    keptPaths(end+1,1) = keepPath;

    for k = 1:numel(dupPaths)
        sourcePath = char(dupPaths(k));
        [~, baseName, ext] = fileparts(sourcePath);
        targetPath = fullfile(duplicatesFolder, [baseName '__dup' num2str(k) ext]);

        if exist(sourcePath, "file")
            movefile(sourcePath, targetPath, "f");
            duplicateMoves(end+1,:) = [string(sourcePath), string(targetPath), uniqueNames(i)];
        end
    end
end

sortedMoves = strings(0,3);
skipped = strings(0,2);

for i = 1:numel(keptPaths)
    sourcePath = char(keptPaths(i));
    if ~exist(sourcePath, "file")
        continue
    end

    [~, baseName, ext] = fileparts(sourcePath);
    token = regexp(baseName, "_(\d{4})-", "tokens", "once");

    if isempty(token)
        skipped(end+1,:) = [string(sourcePath), "noYearInFilename"];
        continue
    end

    yearStr = token{1};
    targetFolder = fullfile(dataRoot, yearStr);
    if ~exist(targetFolder, "dir")
        mkdir(targetFolder);
    end

    targetName = [baseName ext];
    targetPath = fullfile(targetFolder, targetName);

    if strcmp(sourcePath, targetPath)
        continue
    end

    if exist(targetPath, "file")
        skipped(end+1,:) = [string(sourcePath), "targetAlreadyExists"];
        continue
    end

    movefile(sourcePath, targetPath, "f");
    sortedMoves(end+1,:) = [string(sourcePath), string(targetPath), string(yearStr)];
end

report = struct();
report.dataRoot = string(dataRoot);
report.duplicatesMoved = duplicateMoves;
report.sortedMoved = sortedMoves;
report.skipped = skipped;
report.summary = struct( ...
    "foundFiles", numel(fullPaths), ...
    "uniqueNames", numel(uniqueNames), ...
    "duplicatesMoved", size(duplicateMoves,1), ...
    "sortedMoved", size(sortedMoves,1), ...
    "skipped", size(skipped,1) ...
);
end
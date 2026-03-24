function categoricalMap = myColorMap()

fullMap = slanCM(188);

[uniqueColors, ~, originalIndices] = unique(fullMap, 'rows', 'stable');

numUniqueColors = size(uniqueColors, 1);
shadesPerGroup = 4;
numGroups = numUniqueColors / shadesPerGroup;

flippedUniqueColors = uniqueColors;

for groupIdx = 1:numGroups
    rowStart = (groupIdx - 1) * shadesPerGroup + 1;
    rowEnd = groupIdx * shadesPerGroup;

    groupBlock = uniqueColors(rowStart:rowEnd, :);
    flippedUniqueColors(rowStart:rowEnd, :) = flipud(groupBlock);
end

categoricalMap = flippedUniqueColors(originalIndices, :);
end

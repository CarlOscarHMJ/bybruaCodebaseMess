function cleanString = strrm(targetInput, stringsToRemove)
% Sequentially removes multiple substrings from a string or character array
arguments
    targetInput
    stringsToRemove
end

cleanString = string(targetInput);
items = string(stringsToRemove);

for i = 1:numel(items)
    cleanString = strrep(cleanString, items(i), "");
end

if ischar(targetInput)
    cleanString = char(cleanString);
end
end
function cableList = findCableGroups(varNames)
% findCableGroups  Group cable IDs and their available directions
%   cableList = findCableGroups(varNames)
%   varNames -> cell/string array of names like 'C1W_x'
%   cableList -> cell array: {cableId, [dirs]; ...}
    
    if isempty(varNames)
        cableList = {};
        return
    end

    varNames = string(varNames);
    parts = split(varNames, "_");

    cableIds = parts(:,:,1);
    dirs     = parts(:,:,2);

    uniqueCables = unique(cableIds);
    cableList = cell(numel(uniqueCables), 2);

    for k = 1:numel(uniqueCables)
        id = uniqueCables(k);
        cableList{k,1} = char(id);
        cableList{k,2} = dirs(cableIds == id).';
    end
end

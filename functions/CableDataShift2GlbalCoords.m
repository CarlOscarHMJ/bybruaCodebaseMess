function CableData = CableDataShift2GlbalCoords(CableData)
% Changes the names from acc names to general cabel names
% Also changes the coordinate system to global coordinates
%
% Requires check of drawing!
% COH Nov. 2025
vars = CableData.Properties.VariableNames;
%warning('Check this with J+J+NID!')  % Validated 10/1/2025

% see data/misc/accelerometers_*.pdf
mapAcc = ["C2W" "4251"
            "C1W" "12047"
            "C1E" "12046"
            "C2E" "12045"];

% Rename CableData variables based on the mapping
for i = 1:length(vars)
    [sId,eId] = regexp(vars{i}, '(?<=x)\d+(?=_)');
    AccModel = vars{i}(sId:eId);
    AccInd   = contains(mapAcc(:,2),AccModel);

    CableData.Properties.VariableNames{i} = ...
        [mapAcc{AccInd, 1} vars{i}(eId+1:end)];

end

% Bridge coord - Etiene thesis fig 2.1
% x across
% y along
% z up

%             Pos   x       y       z
mapAccXYZ = ["C2W"  "ch2"   "ch3"   "ch1" % Validated 10/1/2025 against NID article
             "C1W"  "ch2"   "ch3"   "ch1" % Validated 10/1/2025 against NID article
             "C2E"  "ch2"   "ch3"   "ch1" % Validated 10/1/2025 against NID document
             "C1E"  "ch2"   "ch3"   "ch1"]; % Validated 10/1/2025 against NID document
dirs = '0xyz';

for i = 1:width(CableData)
    var = CableData.Properties.VariableNames{i};
    Acc = var(1:3);
    ch  = var(5:end);

    idcol = strcmp(mapAccXYZ(:,1),Acc);
    iddir = contains(mapAccXYZ(idcol,:),ch);

    CableData.Properties.VariableNames{i} = [Acc '_' dirs(iddir)];

    if contains(cd,'-') %flip the data
        CableData{:,i} = CableData{:,i} * (-1);
    end
end

% Sort table variable names
[~,idx] = sort(CableData.Properties.VariableNames);
CableData = CableData(:,idx);
end
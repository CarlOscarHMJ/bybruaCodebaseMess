% status = AssignInput(input, argumentList [nIgnore])
% - Evaluates (variable) 'magic keyword' input to a user function according 
% to a list of  argument descriptions and assigns values in the function 
% workspace accordingly. 
% - The first nIgnore input is disregarded by the function and is therefore
% left for the calling function to handle manually.
% - If 'help' is specified AssignInput outputs a description of the
% available options.
% - the optional status output is equal to 0 unless the 'help' input has
% been specified in which case the status output is equal to 1. This can be
% used to stop the calling function gently
%
% The arguments list should be constructed using 
% AddArgumentDescription with the arguments
% AddArgumentDescription(name,description,nFields,field1,default1 [,field2,default2,....])
% name        - The name of the argument / magic keyword
% description - The help text of the argument
% nFields     - The number of fields to follow the argument. Se the note *)
% field1      - The variable that will be initialised for the first field
% default1    - The default value of the first value (when not specified)
%
% *) If the number of fields is 0 the argument is a flag but field1 and 
% default1 still have to be specified. If the end user calls a magic 
% keyword with 0 fields, the field1 variable is set equal to the name of 
% the magic keyword. If no field name in the arguments list is specified a 
% variable named as the magic keyword is set true when specified, or
% otherwise false.
%
% Example:
% --
% function MyFun(varargin)
% %                          argument, description,number of fields, field1,default1,field2,default2,...
% argumentsList = [
%     AddArgumentDescription('lineColor' , 'Specifies the line color'      ,1 ,'color'    ,'black'         )
%     AddArgumentDescription('dimensions', 'Specifies the shape dimensions',2 ,'xDim'     ,4      ,'yDim',2)
%     AddArgumentDescription('dashed'    , 'Specifies the line style'      ,0 ,'lineStyle','solid'         )
%     ];
% % An error in the following line can be caused by a missing varargin function input:
% status = AssignInput(varargin,argumentsList);
% if (status == 1)
%     return
% end
% --
% A call to MyFun() with no arguments will set 
% color='black', xDim=4, yDim = 2, lineStyle='solid'.
% The call MyFun('dimensions',3,1) will set
% color='black', xDim=3, yDim = 1, lineStyle='solid'.
% The call MyFun('dimensions',3,1,'dashed') will set
% color='black', xDim=3, yDim = 1, lineStyle='dashed'.

% TODO: Warn on unrecognised input
function [varargout] = AssignInput(input, argumentsList,ignore)

argumentsListLength = length(argumentsList);
returnCode = 0;

% -----------------------------------
% Here the 'help' response
% -----------------------------------
printHelp = false;
for i = 1:size(input,2)
    if (strcmp(input{i},'help'))
        printHelp = true;
    end
end
if (printHelp)
    fprintf('Below follows the available optional input. Each input is magic keywords \n')
    fprintf('followed by its description and a line with the required input fields to follow\n')
    fprintf('the keyword. The defaults are shown in angle brackets.\n\n')

    maxNameLength = 0;
    for a = 1:argumentsListLength
        maxNameLength = max(maxNameLength,length(argumentsList(a).name));
    end
    indentation = sprintf(sprintf('%%%ds   %%s\\n',maxNameLength),' ');
    for a = 1:argumentsListLength
        fprintf(sprintf('%%%ds - %%s',maxNameLength),argumentsList(a).name,argumentsList(a).helpText)
        if (argumentsList(a).nFields)
            fprintf('\n')
            fprintf(indentation);
            fprintf('Required arguments:\n');
        else
            fprintf('\n')
            fprintf(indentation);
            fprintf('No arguments required.\n')
        end
        for f = 1:argumentsList(a).nFields
            fprintf(indentation);
            if (ischar(argumentsList(a).fieldDefault{f}))
                fprintf('%s <%s>, ',argumentsList(a).fieldName{f},argumentsList(a).fieldDefault{f})
            else
                fprintf('%s <%s>, ',argumentsList(a).fieldName{f},num2str(argumentsList(a).fieldDefault{f}))
            end
            fprintf('\n')
        end
    end
    if (nargout == 1)
        varargout{1} = 1;
        error('SOH: There was an error in the input arguments.')
    end
    return
end


% -----------------------------------
% Ignore arguments
% -----------------------------------
if (nargin > 2)
    thisIgnore = min(ignore,length(input));
    input(1:thisIgnore) = [];
end

% Using the assignmentDictionary to build a list of all the things that can be assigned, and only assigning in the end.
% This has some advantages:
%   Simplifies code (avoinding assignin in many places, consistently collects {name, value}-pairs)
%   Is more forgiving on variable names: assignin cannot assign to aStruct.afield, but can assign a struct containing aField. This can now be handled in one place.
%   Defaults get updated in the dictionary before assignment, so values are only assigned once.
assignmentDictionary = {};
% -----------------------------------
% Assign default values
% -----------------------------------
for a = 1:argumentsListLength
    % assign all values/fields
    for f = 1:max(1,argumentsList(a).nFields)
        if (isempty(argumentsList(a).fieldName{f}))
            varName = argumentsList(a).name;
            varValue = false;
        else
            varName = argumentsList(a).fieldName{f};
            varValue = argumentsList(a).fieldDefault{f};
        end
        assignmentDictionary = updateDictionary(assignmentDictionary, varName, varValue);
    end
end


% -----------------------------------
% Identify input
% -----------------------------------
nInput = 0;
iInput = [];
for i = 1:size(input,2)
    for a = 1:argumentsListLength
        if (strcmp(input{i},argumentsList(a).name))
            nInput = nInput+1;  %number of input arguments
            iInput(nInput) = i; %index of input
            aInput(nInput) = a; %corresponding entry in arguments list
        end
    end
end
iInput(nInput+1) = size(input,2)+1; %for the nArguments evaluation later

% If the first input is not a valid keyword return status 2 but continue
if (iInput(1) ~= 1)
    returnCode = 2;
    error('SOH: the first input is not a valid keyword')
end

% -----------------------------------
% Assign input values
% -----------------------------------

for i = 1:nInput
    nArguments = iInput(i+1)-iInput(i)-1;
    if ( nArguments ~= argumentsList(aInput(i)).nFields)
        error('AssignInput:nInput','Wrong number of arguments for ''%s''. %d found, %d expected',argumentsList(aInput(i)).name, nArguments, argumentsList(aInput(i)).nFields);
    end
    if (argumentsList(aInput(i)).nFields == 0)
        if (isempty(argumentsList(aInput(i)).fieldName{1}))
            varName  = argumentsList(aInput(i)).name;
            varValue = true;

        else
            varName  = argumentsList(aInput(i)).fieldName{1};
            varValue = input{iInput(i)};

        end
        assignmentDictionary = updateDictionary(assignmentDictionary, varName, varValue);
        
    else
        for f = 1:max(1,argumentsList(aInput(i)).nFields)
            varName              = argumentsList(aInput(i)).fieldName{f};
            varValue             = input{iInput(i)+f};
            assignmentDictionary = updateDictionary(assignmentDictionary, varName, varValue);
        end
    end

end


% build structure of assignees
% Assignees = struct();
Assignees.dummy = 0; % these two lines are matlab 6.5 compatible
Assignees       = rmfield(Assignees,'dummy');
for iInput = 1:size(assignmentDictionary,1)
    varString = assignmentDictionary{iInput,1};
    varValue  = assignmentDictionary{iInput,2};
%     nameParts = structParseVarName(varString);
%     Assignees = setfield(Assignees, nameParts{:}, varValue); % expands nameParts to list, which setfield uses for depth indexing to Assignees
    Assignees = setfield(Assignees, varString, varValue); % this prohibits the use of structs in AssignInput but is necessary for matlab 6.5 to work
end

% assign all 1st level fields in Assingees. This way, variables with names input as ex. 'str.x', will be able to generate 'str' in the caller.
varNames = fieldnames(Assignees);
for iVar = 1:length(varNames)
    varName = varNames{iVar};
    assignin('caller', varName, Assignees.(varName) );
end

if (nargout == 1)
    varargout{1} = returnCode;
end

if returnCode ~= 0
  error('SOH: There was an error in the input arguments.')
end

end

function nameParts =  structParseVarName(varName)
    nameParts = aal_strsplit(varName,'.');  % strsplit is not available in older Matlab
    areValid  = cellfun(@isvarname, nameParts);
    isStruct = (length(nameParts)>1);
    if ~all(areValid), error('Invalid variable name'); end
end

% strsplit is not available in older Matlab
function C = aal_strsplit(str, dlm)
        dlmIndex = strfind(str,dlm);
        prevIndex = 0;
        iDlm      = 0;
        for iDlm = 1:length(dlmIndex)
            index    = dlmIndex(iDlm);
            subStr = str(prevIndex+1:index-1);
            C{iDlm} = subStr;
            prevIndex = index;
        end
        if (isempty(iDlm))
            iDlm = 0;
        end
        C{iDlm+1} = str(prevIndex+1:end);
end




function dictionary = updateDictionary(dictionary, keyString, value)
    % dictionaries do not exist in Matlab. Using a cell array instead, it is up to the programmer to not input duplivate keys.
    % Use this function always, when updating the dictionary, to avoid duplicate keys.
    % containers.Map has been available for this exact purpose since Matlab 2008b, but we have older versions in-house.
    if isempty(dictionary)
        dictionary = {keyString, value};
        return
    end
    keys = dictionary(:,1);
    keyFoundAt = strcmp(keyString, keys);
    if ~any(keyFoundAt)
        dictionary = [dictionary; {keyString, value}];
    else
        dictionary(keyFoundAt,2) = {value};
        if sum(keyFoundAt)>1
            warning('Key was found multiple times. All corresponding values have been overwriten');
        end
    end
end

function argument = AddArgumentDescription(varargin)

argument.name     = varargin{1};
argument.helpText = varargin{2};
argument.nFields  = varargin{3};
for f = 1:max(1,argument.nFields)
    
    argument.fieldName{f}    = varargin{3+(f-1)*2+1};
    argument.fieldDefault{f} = varargin{3+(f-1)*2+2};
end


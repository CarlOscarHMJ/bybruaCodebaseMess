function newstring = strrm(oldstring,string2remove)
%remove a part of a string
newstring = strrep(oldstring,string2remove,'');
end
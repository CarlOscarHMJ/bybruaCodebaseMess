function dailyTbl = groupFilesByDay(filepaths)
    fp = string(filepaths(:));
    dstr = regexp(fp, '\d{4}-\d{2}-\d{2}', 'match', 'once');
    day  = datetime(dstr, 'InputFormat','yyyy-MM-dd');
    
    [gid, keys] = findgroups(day);
    filesPerDay = splitapply(@(x){sort(x)}, fp, gid);
    
    dailyTbl = table(keys, filesPerDay, 'VariableNames', {'Date','Files'});
    dailyTbl = sortrows(dailyTbl,'Date');
end
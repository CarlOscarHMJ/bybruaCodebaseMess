function T = processCompressedFile(datapath, file_compressed)
    fullpath_compressed = fullfile(datapath, file_compressed);
    fprintf(['Now reading:' file_compressed '\n']);
    
    gunzip(fullpath_compressed);
    
    file = strrep(file_compressed,'.gz','');
    fullpath = strrep(fullpath_compressed,'.gz','');
    
    T = readtable(fullpath);
    delete(fullpath);

    
end

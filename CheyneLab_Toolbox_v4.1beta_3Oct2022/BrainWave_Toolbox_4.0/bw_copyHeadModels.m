% D. Cheyne 3.4 copy any head models from the first
% dataset to the combined dataset, assuming these are always same subject. 
% Updated (BW v3.5): Windows operation updated to xcopy - did not recognise cp 

function bw_copyHeadModels(dsName1,dsName2)

    if ~exist(dsName1,'file') 
        fprintf('file %s not found\n', dsName1);
        return;
    end
    if ~exist(dsName2,'file') 
        fprintf('file %s not found\n',dsName2);
        return;
    end
    s1 = sprintf('%s%s%s',dsName1,filesep,'*.hdm');
    
    dirlist = dir(s1);
    for k=1:size(dirlist,1)
        if ispc
            cmd = sprintf('xcopy %s%s%s %s%s',dsName1,filesep,dirlist(k).name, dsName2,filesep);
        else
            cmd = sprintf('cp %s%s%s %s%s',dsName1,filesep,dirlist(k).name, dsName2,filesep);
        end
        fprintf('copying head model %s ...\n',dirlist(k).name);
        system(cmd);
    end
end
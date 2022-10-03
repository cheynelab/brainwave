% function [isWriteable] = bw_isWriteable(dsName)
% 
% Utility function to make sure we can write to both the datset folder and
% the ANALYSIS folder if it already exists.

function [isWriteable] = bw_isWriteable(dsName)

    tempDirName = 'bw_tmp_dir';
    
    % check write permission for the .ds folder first
    isWriteable = false;

    if exist(dsName,'dir') ~= 7 
        fprintf('Failed to find the dataset directory %s.\n', dsName);
        return;
    end

    % check that we can create a new directory there
    testDir = fullfile(dsName,tempDirName);
    [isWriteable,message,messageid] = mkdir(dsName,tempDirName);
    if (isWriteable)
        rmdir(testDir);
    else
        fprintf('You do not have write permission to write to the directory %s. No files created.\n', dsName);
        return;
    end

    
    % now check if ANALYSIS already exisits that it is also writeable by
    % creating the test directory there
    analysisDir = fullfile(dsName,'ANALYSIS');
    if exist(analysisDir,'dir') == 7 
        testDir = fullfile(analysisDir,tempDirName);
        [isWriteable,message,messageid] = mkdir(analysisDir,tempDirName);
        if (isWriteable)
            rmdir(testDir);
            return;
        else
            isWriteable = false;
            fprintf('You do not have write permission to write to the directory %s. No files created.\n', analysisDir);
            return;
        end
    end
end

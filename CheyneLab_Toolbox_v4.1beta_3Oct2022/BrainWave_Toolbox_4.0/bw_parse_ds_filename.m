function [ds_path, ds_name, subject_ID, mri_path, mri_filename] = bw_parse_ds_filename(fullname)
%       BW_PARSE_DS_FILENAME
%
%   [ds_path, ds_name, subject_ID, mri_path, mri_filename] = bw_parse_ds_filename(fullname)
%
%   DESCRIPTION: From a dataset name will identify and return (seperately) 
%   the names and paths of the dataset, the corresponding MRI and the 
%   subject's ID.
%
%   Feb 2012 - modified to look for .nii file, then .mri
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

    ds_path = [];
    ds_name = [];
    mri_path = [];
    subject_ID = [];
    mri_filename = [];
    
    a = strfind(fullname, filesep);
    
    if isempty(a)
        ds_path = [];
        dirPath = [];
        ds_name = fullname;
    else
        ds_path = fullname(1:a(end)-1);
        dirPath = strcat(ds_path, filesep);       
        ds_name = fullname(a(end)+1:end);
    end

    a = strfind(ds_name,'_');
    if isempty(a)
        subject_ID = ds_name(1:2);  % default is 1st two chars
    else
        % else take everything before the first underscore
        subject_ID = ds_name(1:a(1)-1);
    end
    
    % look for MRI file for this dataset in default locations
    
    foundMRI = true;
    mri_filename = sprintf('%s%s_MRI%s%s.nii', dirPath, subject_ID, filesep, subject_ID);
    if ~exist(mri_filename,'file')
        % try one dir up
        mri_filename = sprintf('%s%s.nii', dirPath, subject_ID);
        if ~exist(mri_filename,'file')
           foundMRI = false;
        end
    end
    
    % if no .nii file was found, look for a .mri
    if ~foundMRI
        foundMRI = true;
        mri_filename = sprintf('%s%s_MRI%s%s.mri', dirPath, subject_ID, filesep, subject_ID);
        if ~exist(mri_filename,'file')
            % try one dir up
            mri_filename = sprintf('%s%s.mri', dirPath, subject_ID);
            if ~exist(mri_filename,'file')
               foundMRI = false;
            end
        end
    end

    if ~foundMRI
        mri_filename = [];
        mri_path = [];
    else
        a = strfind(mri_filename,filesep);
        mri_path = mri_filename(1:a(end)-1);
    end
    
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bw_convertTal2MEG 
%
%   script to unwarp from Talairach to MEG coordinates
%
% function [ctf_coords] = bw_convertTal2MEG( dsName, tal_coords, search_radius )
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use. 

function [ctf_coords] = bw_convertTal2MEG( dsName, tal_coords, search_radius )
    
    ctf_coords = [];
    
    if ~exist(dsName,'dir')
        fprintf('cannot locate %s - check path and current working directory\n', dsName)
        return;
    end
    
    [ds_path, ds_name, subject_ID, mri_path, mri_filename] = bw_parse_ds_filename(dsName);

    if isempty(mri_filename) || isempty(subject_ID)
        fprintf('Could not get MRI directory or subject ID for this subject\n');
        return;
    end
    
    bb = beamformer_parameters.boundingBox;
    sn3matname = sprintf('%s%s%s_resl_%g_%g_%g_%g_%g_%g_sn3d.mat',...
            mri_path, filesep, subject_ID, bb(1), bb(2),bb(3),bb(4),bb(5),bb(6))       

    % compute image with current params without display            
    tParams = beamformer_parameters;

    if tParams.beam.use == 'ERB' 
        t_start = vs_parameters.searchLatency * 0.001;
        t_end = t_start;
    else
        tParams.beam.no_step = 0;
        t_start = lat_start;
        t_end = lat_end;
    end
    
    [listFile fulllist] = bw_make_beamformer(dsName,t_start,t_end,tParams,false);
    [ds_path, ds_name, subject_ID, mri_path, mri_filename] = bw_parse_ds_filename(dsName);

    if isempty(mri_filename)
        [fname, fPath, junk] = uigetfile('*.mri', 'Please locate a CTF .mri file for this subject');
        if (fname == 0)  % user pressed cancel
            mri_filename = '';
        else
            mri_filename = fullfile(fPath, fname);
        end
    end

    if (~isempty(listFile) && ~isempty(mri_filename) )
        [normalized_listFile fulllist bb] = bw_normalize_images(mri_filename, listFile, spmVersion);
    end
    [fPath fname ext] = bw_fileparts(fulllist);
    imageFile = fullfile(fPath, fname(2:end));   % get unnormalized - drop 'w'
    imageFile = strcat(imageFile,ext);

    ctf_coords = bw_unwarpTal(tal_coords,sn3matname,imageFile, search_radius);   
    
end




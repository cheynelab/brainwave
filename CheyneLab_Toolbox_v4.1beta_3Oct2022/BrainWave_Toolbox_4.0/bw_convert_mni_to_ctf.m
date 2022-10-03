%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [ctf_coords] = bw_convert_mni_to_ctf( dsName, mni_coord, params, [verbose])
%
%
% (c) D. Cheyne, 2015. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%
% Nov, 2015 - replaces bw_unwarp_mni_coord - just unwarps mni voxels without search radius.  Also modified to handle multiple voxels
%           - can be simplified by storing name of sn3D mat file and svl resolution in imageset?
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [ctf_coords] = bw_convert_mni_to_ctf( dsName, mni_coords, params, verbose)
        
    ctf_coords = [];
    numCoords = size(mni_coords,1);
        
    if ~exist(dsName,'dir')
        fprintf('cannot locate %s - check path and current working directory\n', dsName)
        return;
    end
    
    if ~exist('verbose','var')
        verbose = 0;
    end
    
    [ds_path, ds_name, subject_ID, mri_path, mri_filename] = bw_parse_ds_filename(dsName);

    if isempty(mri_filename) || isempty(subject_ID)
        fprintf('Could not get MRI directory containing sn3d.mat file for this subject\n');
        return;
    end
               
    bb = params.boundingBox;        
    sn3dmat_file = sprintf('%s%s%s_resl_%g_%g_%g_%g_%g_%g_sn3d.mat',...
            mri_path,filesep, subject_ID, bb(1), bb(2),bb(3),bb(4),bb(5),bb(6));
      
    if verbose
        fprintf('Converting MNI coordinates to CTF using warping parameters in %s (nvoxels = %d)\n',sn3dmat_file, numCoords);
    end
    
    % New method.  June 9, 2012

    % Get exact coordinate using passed parameters to estimate the unwarped
    % origin, rather than getting it from the image.  
    % 
    svlResolution = params.stepSize * 10.0;
    bb = params.boundingBox * 10.0;        
    dims(1) = size(bb(3):svlResolution:bb(4),2); % left -> right (sagittal - LAS )
    dims(2) = size(bb(1):svlResolution:bb(2),2); % posterior -> anterior (coronal) 
    dims(3) = size(bb(5):svlResolution:bb(6),2); % bottom -> top (axial)

    % origin is set to center of image by svl2nifti.m
    origin = [round(dims(1)/2) round(dims(2)/2) round(dims(3)/2)];
    % save_nii saves origin in mm
    unwarped_origin_mm = -(origin-1) * svlResolution;
   
    VU_mat = diag([svlResolution svlResolution svlResolution 1]);
    VU_mat(1:3,4) = unwarped_origin_mm;
        
    % Get coord in mm relative to unwarped origin
    orig_coord_mm = bw_get_orig_coord(mni_coords, sn3dmat_file);
    
    % Convert to RAS voxel coordinates
    UV_mat = inv(VU_mat);             
    orig_coord_vox =  UV_mat * [orig_coord_mm ones(numCoords,1) ]';
    orig_coord_vox = round(orig_coord_vox(1:3,:))';
    
    % translate into CTF space and convert to cm
  
    % subtract one to get to svl indices
    bb_origin_vox = ([bb(4) -bb(1) -bb(5)] / svlResolution);
    
    for j=1:numCoords
        coord(j,:) = ((orig_coord_vox(j,:) - bb_origin_vox)) * svlResolution;
        ctf_coords(j,:) = [coord(j,2) -coord(j,1) coord(j,3)] * 0.1;
        if verbose
            fprintf('%g %g %g (MNI) --> %g %g %g (CTF)\n', mni_coords(j,:),ctf_coords(j,:));
        end
    end
    
end

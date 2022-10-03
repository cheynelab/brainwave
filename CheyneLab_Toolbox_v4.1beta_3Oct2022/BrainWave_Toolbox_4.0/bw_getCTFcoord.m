function ctf_coord = bw_getCTFcoord(mni_coord, sn3dmat_file, unwarpedFile )
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function ctf_coord = bw_getCTFcoord(mni_coord, sn3dmat_file, unwarpedFile )
% 
% converts MNI coordinate in mm to ctf (MEG) coordinate in cm.
%
% mni_coord:       coordinate to convert in MNI space (in mm)
% sn3dmat_file:    SPM2 mat file created by spm_normalize
% unwarpedFile:    original unwarped image in .img or .nii
%
% D. Cheyne, September, 2008
%
% Revisions:
%               Ver 1.1  Oct 1, 2008
%               - changed search behaviour so that if it exceeds
%                 the specified search radius it takes the original
%                 coordinate instead of the last voxel found at the
%                 boundary.  Also, now prints out max. value at voxel.
%
%               March, 2011 
%
%               - updated to use SPM8 (D. Cheyne)
%               - removed search radius to simplify (use bw_unwarpTal for this instead...)
%
%               June, 2012
%               - new version - gets origin from file and uses bw_get_orig_coord
%                 function to unwarp point without passing image
%
% (c) D. Cheyne, 2011. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    ctf_coord = [0 0 0];

    [path,name,file_ext] = bw_fileparts(unwarpedFile);

    nii = load_nii(unwarpedFile);

    % NOTE ON UNWARPING SPM COORDINATES:
    
    % We can get the unwarped MNI point in mm relative to the image origin from
    % John Ashburner's script without passing it the original image
    
    % However, we need to do the conversion to MEG coordinates in voxels so
    % that we duplicate the same precision as the original coordinates which are
    % always in steps equal to the svlResolution and get the point relative
    % to the RAS origin instead of the image origin. (This is actualy the 
    % same thing that get_orig_coord function does if you pass it the image)
    
    % To do this we need the voxel to mm transform matrix from the original image.
    % Once we have this, we can just use the inverse to go from mm back to voxels,
    % then transform that back to CTF voxels using the bounding box
    % origin and scale to cm using  svlResolution. 
    
    % Get units (mm) to voxel transformation matrix
    svlResolution = double(nii.hdr.dime.pixdim(2));
    unwarped_origin_mm = [nii.hdr.hist.srow_x(4) nii.hdr.hist.srow_y(4) nii.hdr.hist.srow_z(4)];
   
    VU_mat = diag([svlResolution svlResolution svlResolution 1]);
    VU_mat(1:3,4) = unwarped_origin_mm;
        
    % Get coord in mm relative to unwarped origin
    orig_coord_mm = bw_get_orig_coord(mni_coord, sn3dmat_file);
    
    % Convert to RAS voxel coordinates
    UV_mat = inv(VU_mat);             
    orig_coord_vox =  UV_mat * [orig_coord_mm 1]';
    orig_coord_vox = round(orig_coord_vox(1:3))';
    
    % we now get CTF origin from bounding box which is stored in the .mat file
    t = load(sn3dmat_file);
    bb = t.ctf_bb*10;

    % subtract one to get to svl indices
    bb_origin_vox = ([bb(4) -bb(1) -bb(5)] / svlResolution);
    coord = ((orig_coord_vox - bb_origin_vox)) * svlResolution;
    ctf_coord = [coord(2) -coord(1) coord(3)] * 0.1;

end

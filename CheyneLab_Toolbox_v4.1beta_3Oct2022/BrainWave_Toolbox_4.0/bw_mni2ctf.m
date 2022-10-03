% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %  
% Stand-alone script to convert one or more MNI voxels to CTF (MEG)
% coordinates based on an SPM normalization file created with BrainWave
% 
% D. Cheyne, Feb3, 2022
% 
% input:
% sn3dmat_file:     normalization file created in BrainWave using SPM8/SPM12
%                   (e.g., '<SUBJ_ID>_MRI/<SUBJ_ID>_resl_-12_12_-9_9_-2_14_sn3d.mat')
% mni_coords:       n x 3 array of mni coordinates to convert (in mm)
% verbose:          set to false to run in silent mode
%
% returns:          n x 3 array of CTF coordinates in cm 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %  

function ctf_coords = bw_mni2ctf(sn3dmat_file, mni_coords, verbose)

    ctf_coords = [];
    
    if size(mni_coords,2) ~= 3
        fprintf('Input must be n x 3 array of MNI coordinates in mm\n');
        return;
    end
    
    if ~exist('verbose','var')
        verbose = 1;
    end
    
    numCoords = size(mni_coords,1);
    
    if isempty(sn3dmat_file)
        return;
    end

    if verbose
        fprintf('bw_mni2ctf:\nConverting MNI coordinates to CTF using warping parameters in %s\n',sn3dmat_file);
    end

    % here resolution doesn't have to match a warped image, 
    % set to 1 mm MRI resolution for MNI template
    svlResolution = 1.0;
    % bounding box must be same as used to create the sn3d file! 
    % - fortunately I save this in the sn3d.mat file (in cm)            
    t = load(sn3dmat_file);
    bb = t.ctf_bb * 10.0;
    clear t;

    % origin is set to center of bounding box when warping
    dims(1) = size(bb(3):svlResolution:bb(4),2) ; % left -> right (sagittal - LAS )
    dims(2) = size(bb(1):svlResolution:bb(2),2); % posterior -> anterior (coronal) 
    dims(3) = size(bb(5):svlResolution:bb(6),2); % bottom -> top (axial)
    origin = [round(dims(1)/2) round(dims(2)/2) round(dims(3)/2)];
    % save_nii saves origin in mm
    unwarped_origin_mm = -(origin-1) * svlResolution;
  
    % Get original coord in mm relative to the unwarped origin using John Ashburner's script
    orig_coord_mm = bw_get_orig_coord(mni_coords, sn3dmat_file);

    % Convert to voxel coordinates in the original resliced MRI (.svl)
    % bounding box: note for 1 mm res this just adds the bb origin.
    
    VU_mat = diag([svlResolution svlResolution svlResolution 1]);  
    VU_mat(1:3,4) = unwarped_origin_mm;  % voxel to mm conversion
    orig_coord_vox =  inv(VU_mat) * [orig_coord_mm ones(numCoords,1) ]';
    orig_coord_vox = round(orig_coord_vox(1:3,:))';

    % rotate into svl space and convert to CTF coordinates in cm

    bb_origin_vox = [bb(4) -bb(1) -bb(5)] / svlResolution;

    coord = (orig_coord_vox - bb_origin_vox) * svlResolution;
    ctf_coords = [coord(2) -coord(1) coord(3)] * 0.1;
    
    for j=1:numCoords
        coord(j,:) = ((orig_coord_vox(j,:) - bb_origin_vox)) * svlResolution;
        ctf_coords(j,:) = [coord(j,2) -coord(j,1) coord(j,3)] * 0.1;
        if verbose
            fprintf('%g %g %g (MNI) --> %g %g %g (CTF)\n', mni_coords(j,:),ctf_coords(j,:));
        end
    end       
end
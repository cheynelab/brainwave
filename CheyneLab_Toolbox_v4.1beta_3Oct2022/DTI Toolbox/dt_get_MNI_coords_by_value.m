%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function mni_voxels = dt_get_MNI_coords_by_value(niiFile, value)
%
% function to get mni coordinates from a SPM normalized 
% nifti file based on voxel value
% 
% D. Cheyne, Oct, 2021
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function mni_voxels = dt_get_MNI_coords_by_value(niiFile, value)

    mni_voxels = [];

    nii = load_nii(niiFile);
    dims = nii.hdr.dime.dim(2:4);   
    pixdim = nii.hdr.dime.pixdim(2:4);
   
    origin = [ nii.hdr.hist.srow_x(4) nii.hdr.hist.srow_y(4) nii.hdr.hist.srow_z(4) ];
     
    % check for flipped axes and compute negative (RAS) origin. 
    if origin(1) > 0
        origin(1) = origin(1) - (dims(1)-1) * pixdim(1); % subtract one for zero voxel
    end
    if origin(2) > 0
        origin(2) = origin(2) - (dims(2)-1) * pixdim(2);
    end
    if origin(3) > 0
        origin(3) = origin(3) - (dims(3)-1) * pixdim(3);
    end
   
    fprintf('scanning NIfTI image %s for values = %d \n',niiFile, value);
    idx = find(nii.img == value);  % returns linear index 
    
    if ~isempty(idx)
        [x, y, z] = ind2sub(dims,idx);  
        voxelArray = [x y z];     
        % convert to MNI coordinates MNI = (voxel-1) * voxelSize + origin
        % where voxels go from 0 to dims-1
        mni_voxels(:,1) = (voxelArray(:,1)-1) * pixdim(1);  
        mni_voxels(:,2) = (voxelArray(:,2)-1) * pixdim(2);
        mni_voxels(:,3) = (voxelArray(:,3)-1) * pixdim(3);
        mni_voxels = mni_voxels + repmat(origin,size(mni_voxels,1),1);

        % round to mm and remove duplicates
        mni_voxels = round(mni_voxels);
        mni_voxels = unique(mni_voxels,'rows');
    end   
    
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function dt_make_MNI_mask(filename, mni_voxels, [maskValue], [voxelSize])
%
% make a NIfTI volume mask using passed MNI voxels
% requires NIfTI toolbox https://github.com/isnardo/matlab
%
% D. Cheyne Oct 2021.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dt_make_MNI_mask(filename, voxel_array, maskValue, voxelSize)
   
    % by default use RAS with BB large enough for most atlases
    % origin should be even numbers to match 2mm atlases
    
    if iscell(voxel_array)
        mni_voxels = cell2mat(voxel_array);
    else
        mni_voxels = voxel_array;
    end

    origin = [-90 -126 -90];   
    
    if ~exist('voxelSize','var')
        voxelSize = 2;
    end

    if ~exist('maskValue','var')
        maskValue = 255;
    end
    
    % create symmetric volume, add one voxel for zero 
    xdim = round( (abs(origin(1)) * 2) / voxelSize) + 1;
    ydim = round( (abs(origin(2)) * 2) / voxelSize) + 1;
    zdim = round( (abs(origin(3)) * 2) / voxelSize) + 1; 
    
    % create standard RAS NIfTI volume of zeros
    Img = zeros(xdim, ydim, zdim);     
    dataType = 8;  % signed int

    fprintf('writing mask image [%s] (resolution = %dmm, ROI size = %d voxels) \n', filename, voxelSize, length(mni_voxels) );

    % convert to voxels coordinates voxel = (MNI - origin) / voxelSize + 1
    % where voxels go from 1 to dims
    v = (mni_voxels - repmat(origin,size(mni_voxels,1),1));
    voxels = round( v / voxelSize) + 1;  % add one to save in matlab array
    
    % set voxels to mask value
    idx = sub2ind(size(Img),voxels(:,1), voxels(:,2), voxels(:,3));
    
    % write to image if in range
    outofbounds = find(idx < 1);
    idx(outofbounds) = [];
    outofbounds =find(idx > xdim * ydim * zdim);
    idx(outofbounds) = [];
    Img(idx) = maskValue;
    

    % save smatrix in header
    % create MNI(mm) to voxel conversion (smatrix form)
    % to transform coordinates and save in .nii header.
    smatrix = diag([voxelSize voxelSize voxelSize 1]);
    smatrix(1:3,4) = origin(1:3);
    
    nii = make_nii(Img, voxelSize, origin, dataType);
    nii.hdr.hist.sform_code = 1;
    nii.hdr.hist.srow_x = smatrix(1,:);        
    nii.hdr.hist.srow_y = smatrix(2,:);
    nii.hdr.hist.srow_z = smatrix(3,:);
 
    save_nii(nii, filename);
        
end
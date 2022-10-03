%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function dt_make_RAS_mask(filename, ras_voxels, [maskValue], [voxelSize])
%
% make a NIfTI volume mask using passed MNI voxels
% requires NIfTI toolbox https://github.com/isnardo/matlab
%
% D. Cheyne June 2022.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dt_make_RAS_mask(filename, ras_voxels, maskValue, voxelSize, imageSize)
   
    origin = [1 1 1];   

    if ~exist('maskValue','var')
        maskValue = 1;
    end
        
    if ~exist('voxelSize','var')
        voxelSize = 1;
    end
        
    if ~exist('imageSize','var')
        % create symmetric volume, add one voxel for zero 
        xdim = 256;
        ydim = 256;
        zdim = 256;
    else
        xdim = imageSize(1);
        ydim = imageSize(2);
        zdim = imageSize(3); 
    end
    
    % create standard RAS NIfTI volume of zeros
    Img = zeros(xdim, ydim, zdim);     
    dataType = 8;  % signed int

    fprintf('writing mask image [%s] (resolution = %dmm, ROI size = %d voxels) \n', filename, voxelSize, length(ras_voxels) );
    
    % set voxels to mask value
    idx = sub2ind(size(Img),ras_voxels(:,1), ras_voxels(:,2), ras_voxels(:,3));
    
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
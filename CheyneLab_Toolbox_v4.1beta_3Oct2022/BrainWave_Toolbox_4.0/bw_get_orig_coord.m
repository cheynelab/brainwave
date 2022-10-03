function orig_coord = bw_get_orig_coord(coord, matname,PU)
% John AshBurner's get_orig_coord2 run in silent mode. 
% Added some comments to interpret what script is doing
% D. Cheyne, June, 2012

    %     
    % Determine corresponding co-ordinate in un-normalised image.
    % FORMAT orig_coord = get_orig_coord2(coord, matname,PU)
    % coord      - [x1 y1 z1 ; x2 y2 z2 ; etc] in MNI space (mm).
    % matname    - File containing transformation information (_sn.mat).
    % PU         - Name of un-normalised image
    % orig_coord - Co-ordinate in un-normalised image (voxel).
    %
    % FORMAT orig_coord = get_orig_coord2(coord, matname)
    % coord      - [x1 y1 z1 ; x2 y2 z2 ; etc] in MNI space (mm).
    % matname    - File containing transformation information (_sn.mat).
    % orig_coord - Original co-ordinate (mm).
    %
    % For SPM2 only...
    %
    %_______________________________________________________________________
    % %W% John Ashburner %E%

    t  = load(matname);
    if size(coord,2)~=3, error('coord must be an N x 3 matrix'); end;
    coord = coord';

    % VG.mat is the voxel to mm transform for the template MRI
    % so Mat is mm to voxels in template image
    Mat = inv(t.VG.mat);
    
    % xyz is MNI coord in template voxel coordinates  
    xyz = Mat(1:3,:)*[coord ; ones(1,size(coord,2))];  
    Tr  = t.Tr;
    Affine = t.Affine;
    d   = t.VG.dim(1:3);

    % if returning in voxels of original image need to multiply coord by 
    % inverse of voxel to mm transformation matrix (VU.mat) which is
    % equivalent to the sform matrix in the NIfTI image 
    % VF.mat is the vox to mm transform for the original structural image 
    % used to generate the warping parameters.    
        
    if nargin>2,
     	VU   = spm_vol(PU); 
        Mult = VU.mat\t.VF.mat*Affine;
%         disp('Output co-ordinates are in voxels');
    else
        % This returns coord in mm relative to unwarped image.   
        % However, if we don't provide this it assumes 
        % image being warped must have to have origin in
        % same location as original structural, although w.r.t
        % different coordinates systems.  In our case it is the center of the
        % volume (bounding box).        
        
        Mult = t.VF.mat*Affine;  
%         disp('Output co-ordinates are in mm');
    end;

    if (prod(size(Tr)) == 0),
            affine_only = 1;
            basX = 0; tx = 0;
            basY = 0; ty = 0;
            basZ = 0; tz = 0;
    else
            affine_only = 0;
            basX = spm_dctmtx(d(1),size(Tr,1),xyz(1,:)-1);
            basY = spm_dctmtx(d(2),size(Tr,2),xyz(2,:)-1);
            basZ = spm_dctmtx(d(3),size(Tr,3),xyz(3,:)-1);
    end;

    if affine_only,
        xyz2 = Mult(1:3,:)*[xyz ; ones(1,size(xyz,2))];
    else
        for i=1:size(xyz,2),
            bx = basX(i,:);
            by = basY(i,:);
            bz = basZ(i,:);
            tx = reshape(...
                reshape(Tr(:,:,:,1),size(Tr,1)*size(Tr,2),size(Tr,3))...
                *bz', size(Tr,1), size(Tr,2) );
            ty = reshape(...
                reshape(Tr(:,:,:,2),size(Tr,1)*size(Tr,2),size(Tr,3))...
                *bz', size(Tr,1), size(Tr,2) );
            tz =  reshape(...
                reshape(Tr(:,:,:,3),size(Tr,1)*size(Tr,2),size(Tr,3))...
                *bz', size(Tr,1), size(Tr,2) );
            xyz2(:,i) = Mult(1:3,:)*[xyz(:,i) + [bx*tx*by' ; bx*ty*by' ; bx*tz*by']; 1];
        end;
    end;
    orig_coord = xyz2';

end


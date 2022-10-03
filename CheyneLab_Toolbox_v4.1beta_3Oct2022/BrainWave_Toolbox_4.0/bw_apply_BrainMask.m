function newImageList  = bw_apply_BrainMask(dsName, imageList, maskFile )
%   %   function imageList  = bw_apply_BrainMask( imageList, maskFile )
%
%   DESCRIPTION: stand-alone routine to apply a binary mask to a list of 
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

    newImageList = [];
    
     % create binary mask voxel list (same for all images)

    [ds_path, ds_name, subject_ID, mriDir, mri_filename] = bw_parse_ds_filename(dsName);
     
    mri_nii = load_nii(maskFile);
    fprintf('Reading MRI mask file %s, Voxel dimensions: %g %g %g\n',...
        maskFile, mri_nii.hdr.dime.pixdim(2), mri_nii.hdr.dime.pixdim(3), mri_nii.hdr.dime.pixdim(4));   

    fprintf('Computing binary mask for imaging volume\n');
    % need MEG to RAS transformation matrix
    matt = strrep(mri_filename,'.nii','.mat');
    t = load(matt);
    M = bw_getAffineVox2CTF(t.na, t.le, t.re, t.mmPerVoxel );
    meg2ras = inv(M);

    % generate the image voxel list and convert to RAS voxels
    xVoxels = params.boundingBox(1):params.stepSize:params.boundingBox(2);
    yVoxels = params.boundingBox(3):params.stepSize:params.boundingBox(4);
    zVoxels = params.boundingBox(5):params.stepSize:params.boundingBox(6);
    nVoxels = size(xVoxels,2) * size(yVoxels,2) * size(zVoxels,2); 
    n = 1;
    voxelMask = zeros(1,nVoxels);
    maskCount = 0;
    for i=1:size(xVoxels,2)
        for j=1:size(yVoxels,2)
            for k=1:size(zVoxels,2)
                p = [xVoxels(i) yVoxels(j) zVoxels(k)] * 10.0;
                v = round( [p 1] * meg2ras);
%                     fprintf('head coord, voxel %d %d %d, %g %g %g\n', p(1:3), v(1:3));
                if any(v < 1) || any(v > 256) 
                    % skip voxel
                else
                    maskval = mri_nii.img(v(1), v(2), v(3));
                    if maskval > 0 
                        voxelMask(n) = 1;
                        maskCount = maskCount + 1;                        
                    end        
                end
                n = n+1;
            end
        end
    end
    fprintf('Mask contains %d non-zero values ...\n', maskCount);

    for k=1:size(imageList,1)    
        svlFile = deblank(char(imageList(k,:)));    
        % apply mask and save file. need to modify filename to avoid 
        % overwriting by non-masked imageset 
        idx = strfind(svlFile,'Hz'); % find end of basename = last instance of Hz
        newSvl = strcat(svlFile(1:idx(end)+1),'_bMask',svlFile(idx(end)+2:end) );
        fprintf('applying brain mask to %s, saving as %s...\n', svlFile, newSvl);

        svlImg = bw_readSvlFile(svlFile);     
        maskedImg = double(svlImg.Img(:));
        maskedImg = voxelMask' .* maskedImg;            
        new_imageList{k} = newSvl;  % update imageList

        bw_writeSvlFile(newSvl, params.boundingBox,  params.stepSize, samUnits, maskedImg);
    end

    % need to replace imageList with modified file names...
    newImageList = char(new_imageList);

end


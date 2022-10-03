function niiFile = bw_convertCTF_MRI(mrifilename)
% function to convert .mri to BW .nii format (replaces bw_mri2nii.m)
% D. Cheyne, August, 2022

    niiFile = [];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % read CTF mri file using EEGLAB routine

    mri = ctf_read_mri(mrifilename); 

    if isempty(mri)
        return;
    end

    % create folder with .mri root name for BW format
    [~,mriDir,~] = fileparts(mrifilename);
    
    if exist(mriDir,'dir')
        s = sprintf('Directory %s already exists. Overwrite?', mriDir);
        r = questdlg(s,'Convert MRI', 'Yes', 'No', 'No');
        if strcmp(r,'No')
            return;
        end
    end
    [success, ~,~] = mkdir(mriDir);
    
    if success == 0
        fprintf('Could not create directory %s\n', name)
        return;
    end
    
    niiFile = strcat(mriDir, filesep, mriDir, '.nii');
    matFile = strcat(mriDir, filesep, mriDir, '.mat');

    % note ctf_read_mri seems to return image data as doubles 
    img = round(mri.img);

    % reorient from RPI to RAS
    % flip y direction RPI -> RAI
    img2 = flipdim(img,2);
    % flip z direction RAI -> RAS
    img = flipdim(img2,3);

    % get header information 
    hmi = mri.hdr.HeadModel_Info;
    na = [hmi.Nasion_Sag hmi.Nasion_Cor hmi.Nasion_Axi];
    le = [hmi.LeftEar_Sag hmi.LeftEar_Cor hmi.LeftEar_Axi];
    re = [hmi.RightEar_Sag hmi.RightEar_Cor hmi.RightEar_Axi];
    mmPerVoxel = mri.hdr.mmPerPixel_sagittal;  % .mri files are always istropic

    % create and write the .nii file 
    origin = [1 1 1];
    nii = make_nii(img, mmPerVoxel, origin, 4);  % save as datatype 4 (int16) to prevent truncation !!

    fprintf('Saving MRI data in file %s\n', niiFile);

    % passing .nii extension tells save_nii() to use .nii format
    save_nii(nii, niiFile);

    % make CTF fiducials relative to RAS origin instead of RPI origin. 
    na(2) = 257 - na(2); na(3) = 257 - na(3);
    le(2) = 257 - le(2); le(3) = 257 - le(3);
    re(2) = 257 - re(2); re(3) = 257 - re(3);    

    % change voxel indexing from 1 to 256 to 0 to 255.
    na = na-1;        
    le = le-1;
    re = re-1;
    M = bw_getAffineVox2CTF(na, le, re, mmPerVoxel);
    fprintf('Saving Voxel to MEG coordinate transformation matrix and fiducials in %s\n', matFile);
    save(matFile, 'M', 'na','le','re','mmPerVoxel');

end
function bw_mri2nii(mrifilename, writeMatFile)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% function [na le re mmPerVoxel] = bw_mri2nii(mrifilename, [writeMatFile])
%%
%%  written by D. Cheyne, Jan 2007
%%  script to read CTF .mri file and save as .nii format
%%
%%  Input:  
%%  mrifilename:            -name of CTF format .mri file
%%
%%  Options:
%%  writeMatFile            - write the voxel to MEG transformation matrix and fiducial locations to a .mat file with same name (default = false)                          
%%   
%%  Version 2.0   July, 2009
%%                - new version w/ option to save nii to MEG coordinate
%%                  transformation matrix in the sform matrix or as a
%%                  separate .mat file.
%%          2.1   Nov, 2009
%%                - save left right flipped option
%%
%%          2.2   Dec 2011 D. Cheyne
%%                - renamed with bw_ syntax for use with BrainWave
%%                - removed writeTransform and write LAS options
%% 
%%          May, 2012  D. Cheyne - removed attempt to set sform matrix to ones 
%%                               - should now be set to correct scaling factor w/ origin volume center
%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

vers = 2.1;
fprintf('mri2nii\n (c) D. Cheyne, Hospital for Sick Children, 2007\n\n');
fprintf('version %.1f\n', vers);

if ~exist('writeMatFile','var') 
    writeMatFile = false;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read CTF mri file using EEGLAB routine
mri = ctf_read_mri(mrifilename); 

% Alternate routine to read version 4 MRI file from Suresh / Paul
% this does not seem to work too reliably - recommended to convert to
% version 2
% mri = bw_ctf_read_mri_v42(mrifilename);   

hmi = mri.hdr.HeadModel_Info;
na = [hmi.Nasion_Sag hmi.Nasion_Cor hmi.Nasion_Axi];
le = [hmi.LeftEar_Sag hmi.LeftEar_Cor hmi.LeftEar_Axi];
re = [hmi.RightEar_Sag hmi.RightEar_Cor hmi.RightEar_Axi];
mmPerVoxel = mri.hdr.mmPerPixel_sagittal;  % .mri files are always istropic

% if original .mri was 16 bit, scale to 8 bit using full dynamic range 
if (mri.hdr.dataSize == 2)
    fprintf('scaling to 8 bit..\n');
    maxVal = max(max(max(mri.img)));
    scaleTo8bit = 255/maxVal;
    img = scaleTo8bit* mri.img;
else
    img = mri.img;
end

% finished with CTF mri data, free up some memory
clear mri;  

if (all(na) == 0 || all(le) == 0 || all(re) == 0)
    fprintf('**WARNING: %s appears to have non initialized fiducials... - not saving transformation matrix***\n', mrifilename);
    writeMatFile = false;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ctf_read_mri reads data into (x,y,z) array in RPI orientation
% need to convert to standard (RAS) orientation for NIfti file format
% just need to flip y and z axis to go from CTF(RPI) to RAS  

% flip y direction RPI -> RAI
img2 = flipdim(img,2);
% flip z direction RAI -> RAS
img = flipdim(img2,3);
clear img2;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save RAS formatted image in NIfti format 
fprintf('Saving MRI data in NIfTI (.nii) format.\n');

% ** new ** to be consistent with bw_svl2nifti make origin the center of image
dims = size(img);
origin = [round(dims(1)/2) round(dims(2)/2) round(dims(3)/2)];
nii = make_nii(img, mmPerVoxel, origin, 4);                     % save as 4 (int16) to prevent truncation !!

% get transformation matrix that will convert from CTF head coordinates
% to RAS voxels. 

if writeMatFile   
    % make CTF fiducials relative to RAS origin instead of RPI origin. 
    na(2) = 257 - na(2); na(3) = 257 - na(3);
    le(2) = 257 - le(2); le(3) = 257 - le(3);
    re(2) = 257 - re(2); re(3) = 257 - re(3);    

    % change voxel indexing from 1 to 256 to 0 to 255.
    na = na-1;        
    le = le-1;
    re = re-1;
    fprintf('Voxel (RAS) to MEG coordinate transformation matrix: \n');
    fprintf('Voxel origin (0,0,0) is left, posterior, inferior corner of volume\n');
    M = bw_getAffineVox2CTF(na, le, re, mmPerVoxel);
end

% passing .nii extension tells save_nii() to use .nii format
filename = strrep(mrifilename, '.mri', '.nii');  
save_nii(nii, filename);

clear img;

if writeMatFile    
    matFileName = strrep(mrifilename, '.mri', '.mat');  
    fprintf('Saving Voxel to MEG coordinate transformation matrix and fiducials in %s\n', matFileName);
    save(matFileName, 'M', 'na','le','re','mmPerVoxel');
end

clear;
return;
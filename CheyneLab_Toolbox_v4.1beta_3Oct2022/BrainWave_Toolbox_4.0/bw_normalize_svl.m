function [normalized_svlFile] = bw_normalize_svl(mriFile, svlFile, spm_options, noSPMWindows)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%       BW_NORMALIZE_SVL
%
%   function [normalized_svlFile] = bw_normalize_svl(mriFile, svlFile, [noSPMWindows] )
%
%   DESCRIPTION: Using the structural MRI file specified by mriFile this function will
%   normalize the svl image to MNI template space using linear and non-linear warping with SPM8
%
%   Input:  
%           mriFile:    Structural MRI file - can be CTF .mri file or an .nii file created with BrainWave
%                       .mri files will be converted to .nii files using the fiducials stored in the file    
%
%           svlFile:    a CTF format SAM volume (.svl) file. Note that the
%                       bounding box of the svl volume should cover the entire brain
%                           
%   Returns:            name of normalized file (in NIfTI format)
%
% 
%
%      Revision:
%
%      Version 2.0      D. Cheyne, Oct 28, 2012
%      bssed on previous version of bw_normalize_images to normalize just one svl
%      file at a time. Also added checks for dependencies on SPM8 and NIfTI
%      so it can be called independently from BrainWave.
%
%      Also added option to run w/o opening SPM windows
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

global SPM_VERSION

if ~exist('noSPMWindows','var')
    noSPMWindows = false;
end    

% fprintf('\nbw_normalize_svl Version %.1f (c) D. Cheyne, Hospital for Sick Children, 2011\n', version);

if SPM_VERSION == 0
    fprintf('ERROR:  bw_normalize_svl requires a copy of SPM8 or SPM12 installed and in your Matlab path...\n'); 
    return;
end


if exist('save_nii','file') ~= 2   
    fprintf('ERROR:  bw_normalize_svl requires a copy of the NIfTI tools folder in your Matlab path...\n');
    return;
end    

% defs = spm_get_defaults('normalise');
% write_flags = defs.write;    
% since call to get defaults differs for SPM8 and SPM12 (and estimate
% struct is missing in SPM12 hard code for SPM8 images

write_flags.prefix = 'w';
write_flags.preserve = 0;
write_flags.bb = [-78 -112 -50; 78 76 85];
write_flags.vox = [2 2 2];
write_flags.interp = 1;
write_flags.wrap = [0 0 0];

normalized_svlFile = [];  
[bb, ~] = bw_get_svl_dims(svlFile);

% now calls this routine from separate .m file 
% - routine only needs bounding box of image it is normalizing
snMatFile = bw_get_SPM_normalization_file(mriFile, bb, spm_options, noSPMWindows);

if isempty(snMatFile)
    fprintf('Could not get spatial normalization matfile\n');
    return;
end

nonNormalizedFile = bw_svl2nifti(svlFile);                   % convert to NIfTI

% set normalized file to be same resolution as svl file...
[~, svlResolution] = bw_get_svl_dims(svlFile);   
imageResolution = [svlResolution svlResolution svlResolution];
write_flags.vox = imageResolution;

% do normalization ....
% fprintf('Normalizing %s ... \n', nonNormalizedFile);
spm_write_sn(nonNormalizedFile, snMatFile, write_flags);   

% return full name of normalized NIfTI file
[path, filename, ~] = bw_fileparts(nonNormalizedFile);
w_filename = sprintf('%s%s.nii', write_flags.prefix, filename);
normalized_svlFile = fullfile(path,w_filename); 

end



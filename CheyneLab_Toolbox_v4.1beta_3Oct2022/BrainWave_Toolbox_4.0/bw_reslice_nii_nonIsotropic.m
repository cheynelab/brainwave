function bw_reslice_nii(mriFile, boundingBox, resolution)
%       BW_RESLICE_NII
%
%   function bw_reslice_nii(mriFile, boundingBox, resolution)
%
%   DESCRIPTION: Taking the .nii MRI file specified by mriFile and using
%   the specified bounding box (boundingBox) and resolution, reslices it
%   into a new .nii file.
%
% (c) D. Cheyne, 2011. All rights reserved. Based off code by A. Bostan. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  function bw_reslice_mri(mriFile, boundingBox, resolution)
%
%  Simplified version of routine to reslice the .mri file into a bounding
%  box defined in MEG coordinates.  
%
%  Version 1.0.  D. Cheyne Sept 2008 
%     based on ctf_svl_mriReslice.m written by Andreea Bostan. 
%
%
%  input:
%  mriFile         must be CTF .mri format (version 2.2, 4.0 or 4.2).
%  boundingBox:    bounding box in cm = [xmin xmax ymin ymax zmin zmax]
%  resolution:     resolution of the functional image
%
%  Notes:  
%  only does trilinear interpolation but tries to use the compiled
%  mex version if it is in the Matlab path
%     
%
%  Revisions:
%           - D.Cheyne, Feb 2012, replaces bw_reslice_mri, SPM8 only
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



version = 1.0;

fprintf('bw_reslice_nii version %.1f\n\n', version);

matFile = strrep(mriFile, '.nii','.mat');
fprintf('reading MRI to head coordinates transformation matrix from \n', matFile);
t = load(matFile);

% note t.M is the MRI (vox) to head transformation, whereas .mri stores the
% head to MRI matrix which is what is used when reading .mri files
M = inv(t.M);
RMat = M(1:3, 1:3)';
headOrigin = M(4, 1:3);

% get MRI image data
nii = load_nii(mriFile);
if nii.hdr.dime.bitpix == 8
    dataSize = 1;
elseif nii.hdr.dime.bitpix == 16
    dataSize = 2;
end
imageData = double(nii.img);
   

% all values in mm
% we need to reslice mri.img in analyze orientation
% make 256 x 256 axial slices from inferior to superior at 1 mm resolution

xmin = boundingBox(1) * 10;  % convert to mm
xmax = boundingBox(2) * 10;  
ymin = boundingBox(3) * 10;
ymax = boundingBox(4) * 10; 
zmin = boundingBox(5) * 10;
zmax = boundingBox(6) * 10; 

% get correct resolution for resliced image - this requires knowing how
% many voxels in size the functional image will be.  This seems to only
% work correctly if in fractional units

xVoxels = size(xmin*0.001:resolution*0.001:xmax*0.001,2); % posterior -> anterior (coronal) 
yVoxels = size(ymin*0.001:resolution*0.001:ymax*0.001,2); % right -> left (saggital)
zVoxels = size(zmin*0.001:resolution*0.001:zmax*0.001,2); % bottom -> top (axial)

sagRes = (yVoxels * resolution) / 256.0;
corRes = (xVoxels * resolution) / 256.0;

numSlices = round(zVoxels * resolution);

% build head location matrix (3x(256*256*numSlices) array)
fprintf('Building head location matrix ...\n');
tic
y = ymax - (0:255) .* sagRes;
x = xmin + (0:255) .* corRes; % X values
xy = [reshape(repmat(x, 256, 1), 1, 256*256); repmat(y, 1, 256)]; % tile and reshape XY values
clear x y;
z = zmin + (0:(numSlices-1)); % Z values

HeadLoc = [repmat(xy, 1, numSlices); reshape(repmat(z, 256*256, 1), 1, 256*256*numSlices)]; 

clear z;
clear xy;
toc


% rotate and scale
fprintf('Converting into MR space ...\n');
tic

MriLoc = RMat * HeadLoc; % same size as HeadLoc
MriVox = MriLoc + repmat(headOrigin', 1, 256*256*numSlices); % no rounding
clear MriLoc;
toc

% create final image - use mex version of interp3 if possible.
fprintf('Interpolating image ...\n');
tic
if (exist('trilinear') == 3)
    Img = trilinear(imageData, reshape(MriVox(2, :), 256, 256, numSlices), reshape(MriVox(1, :), 256, 256, numSlices), reshape(MriVox(3, :), 256, 256, numSlices));
else
    Img = interp3(imageData, reshape(MriVox(2, :), 256, 256, numSlices), reshape(MriVox(1, :), 256, 256, numSlices), reshape(MriVox(3, :), 256, 256, numSlices), 'linear',0);
end

% save as 8 bit using full dynamic range
maxval = max(max(max(Img)));
Img = double(Img) ./ maxval;
saveImg = round(Img * 256);
clear Img
 
toc

% save the image in requested format...

appendStr = sprintf('_resl_%g_%g_%g_%g_%g_%g', boundingBox(1), boundingBox(2),boundingBox(3),boundingBox(4),boundingBox(5),boundingBox(6));
savePath = strrep(mriFile, '.nii', appendStr);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save in NIfTI format (  RAS ! )

filename = strcat(savePath,'.nii');
fprintf('Saving resliced MRI as: %s\n', filename);
voxelSize = [sagRes corRes 1];

% for SPM - normalization works better if origin is centered in image
% ** note that this origin must match that for any image that gets warped
% **
origin = [128 128 round(numSlices/2) ];

nii = make_nii(saveImg, voxelSize, origin, 2);  
% important - don't set the sform matrix or else spm normalization will
% generate strange offset etc.
nii.hdr.hist.sform_code = 0;

save_nii(nii, filename);


return


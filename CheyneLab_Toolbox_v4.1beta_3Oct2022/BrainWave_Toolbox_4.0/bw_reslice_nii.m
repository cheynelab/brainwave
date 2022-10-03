function bw_reslice_nii(mriFile, boundingBox)
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
%           - D. Cheyne - revised May, 2015 - resolution parameter was not 
%                         needed and was incorrectly changing dimensions of 
%                       bounding box. Also, now saves fids and transform for 
%                       resliced image in .mat file
%                       
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

version = 2.0;

fprintf('bw_reslice_nii version %.1f\n\n', version);

matFile = strrep(mriFile, '.nii','.mat');
fprintf('reading MRI to head coordinates transformation matrix from \n', matFile);
t = load(matFile);

% note t.M is the MRI (vox) to head transformation, whereas .mri stores the
% head to MRI matrix which is what is used when reading .mri files
M = inv(t.M);
RMat = M(1:3, 1:3)';   % inverse rotation
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

xmin = boundingBox(1) * 10;  % convert BB to mm
xmax = boundingBox(2) * 10;  
ymin = boundingBox(3) * 10;
ymax = boundingBox(4) * 10; 
zmin = boundingBox(5) * 10;
zmax = boundingBox(6) * 10; 

% make resliced image isotropic with 1 mm resolution.  
% bug in old version: number of slices is simply resolution * dimension
% (add one for zero) and does not depend on resolution of svl image
% however old code did result in some small rounding error.

numXSlices = round(xmax - xmin) + 1;
numYSlices = round(ymax - ymin) + 1;
numZSlices = round(zmax - zmin) + 1;
resliced_resolution = 1.0;

% build head coordinates grid matrix 3x numXSlices * numYSlices *
% numZslices) corresponding to the image volume
fprintf('Building head location matrix ...\n');
tic

x = xmin + (0:(numXSlices-1)); % X values
y = ymax - (0:(numYSlices-1)); % Y values

t1 = repmat(x, numYSlices, 1);  % tile X values
t1 = reshape(t1, 1, numXSlices*numYSlices);
t2 = repmat(y, 1, numXSlices);  % linear array of 

xy = [t1; t2]; % tile and reshape XY values
clear x y;

z = zmin + (0:(numZSlices-1)); % Z values

HeadLoc = [repmat(xy, 1, numZSlices); reshape(repmat(z, numXSlices*numYSlices, 1), 1, numXSlices*numYSlices*numZSlices)]; 
clear z;
clear xy;
toc

% convert HeadLoc (MEG) coordinates of bounding box to MRI (voxel) coordinates

fprintf('Converting into MR space ...\n');
tic

MriLoc = RMat * HeadLoc; % same size as HeadLoc
MriVox = MriLoc + repmat(headOrigin', 1, numXSlices*numYSlices*numZSlices); % no rounding

clear MriLoc;
toc

% Use trilinear interpolation to get resliced image data 
% uses the compiled mex version of interp3 if possible.

fprintf('Interpolating image ...\n');
tic
if (exist('trilinear') == 3)
    Img = trilinear(imageData, reshape(MriVox(2, :), numYSlices, numXSlices, numZSlices), reshape(MriVox(1, :), ...
        numYSlices, numXSlices, numZSlices), reshape(MriVox(3, :), numYSlices, numXSlices, numZSlices));
else
    fprintf('trilinear mex function not found. Using Matlab interp3 builtin function\n');
    Img = interp3(imageData, reshape(MriVox(2, :), numYSlices, numXSlices, numZSlices), reshape(MriVox(1, :),...
        numYSlices, numXSlices, numZSlices), reshape(MriVox(3, :), numYSlices, numXSlices, numZSlices), 'linear',0);
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
voxelSize = [resliced_resolution resliced_resolution resliced_resolution];

% for SPM - normalization works better if origin is centered in image
% ** note that this origin must match that for any image that gets warped
% **
origin = [round(numYSlices/2) round(numXSlices/2) round(numZSlices/2) ];

nii = make_nii(saveImg, voxelSize, origin, 2);  
% important - don't set the sform matrix or else spm normalization will
% generate strange offset etc.
nii.hdr.hist.sform_code = 0;

save_nii(nii, filename);

% ** new - save a mat file with fidicials and transformation matrix
% for the resliced MRI. This makes unwarping to MEG
% coordinates easier (e.g., for template warping)

% we need fiducials relative to new RAS origin which is left corner of BB
% just subtract this from original fiducials in head coordinates

% mat file stores fids in voxels - need to convert to head coordinates
M = bw_getAffineVox2CTF(t.na, t.le, t.re, t.mmPerVoxel);
x = [t.na 1] * M;   
y = [t.le 1] * M;
z = [t.re 1] * M;
new_origin = [xmin ymin zmin];   % new RAS origin in head coordinates 

% fids relative to new RAS origin
na = round(x(1:3) - new_origin);
le = round(y(1:3) - new_origin);  
re = round(z(1:3) - new_origin);

% need fids relative to LEFT bb origin in head coords
na(2) = numYSlices - na(2);
le(2) = numYSlices - le(2);
re(2) = numYSlices - re(2);

% need to swap x and y axis to convert to RAS voxels
na(:,[1 2 3]) = na(:,[2 1 3]);
le(:,[1 2 3]) = le(:,[2 1 3]);
re(:,[1 2 3]) = re(:,[2 1 3]);
mmPerVoxel = resliced_resolution;
M = bw_getAffineVox2CTF(na, le, re, mmPerVoxel);

matFileName = strrep(filename,'.nii','.mat');
fprintf('Saving Voxel to MEG coordinate transformation matrix and fiducials in %s\n', matFileName);
save(matFileName, 'M', 'na','le','re','mmPerVoxel');



return


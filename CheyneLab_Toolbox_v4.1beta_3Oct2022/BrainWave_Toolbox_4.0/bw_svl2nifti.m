function [niftiFile] = bw_svl2nifti(svlFile)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   function bw_svl2nifti(svlFile)
%
%   DESCRIPTION: Taking the .svl CTF SAM file specified by svlFile, the
%   function will convert it and save it as a NIfTI .nii file under the
%   same name. Latest version also returns name
%
%   Dependencies:
%   Requires the a copy of the NIfTI toolbox from Jimmy Shen in the Matlab
%   path
%  
%   written by D. Cheyne, Mar, 2011
%   converts .svl file to NIfTI format for spatial normalization
%
%  (c) D. Cheyne, 2011. All rights reserved. 
%  This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


version = 1.0;

niftiFile = '';

% fprintf('bw_svl2nifti version %.1f\n\n', version);

fid = fopen(svlFile, 'r', 'b','latin1');

%%  read .svl header
identity = transpose(fread(fid,8,'*char'));
if(~strcmp(identity,'SAMIMAGE'))
    error('This doesn''t look like a SAM IMAGE file.');
end % if SAM image
vers = fread(fid,1,'int32'); % SAM file version
setname = fread(fid,256,'*char');
numchans = fread(fid,1,'int32');
numweights = fread(fid,1,'int32');
if(numweights ~= 0)
    warning('... numweights ~= 0');
end

padbytes1 = fread(fid,1,'int32');

XStart = fread(fid,1,'double');
XEnd = fread(fid,1,'double');
YStart = fread(fid,1,'double');
YEnd = fread(fid,1,'double');
ZStart = fread(fid,1,'double');
ZEnd = fread(fid,1,'double');
StepSize = fread(fid,1,'double');

hpFreq = fread(fid,1,'double');
lpFreq = fread(fid,1,'double');
bwFreq = fread(fid,1,'double');
meanNoise = fread(fid,1,'double');

MRIname = transpose(fread(fid,256,'*char'));
nasion = fread(fid,3,'int32');
rightPA = fread(fid,3,'int32');
leftPA = fread(fid,3,'int32');

SAMtype = fread(fid,1,'int32');
SAMunit = fread(fid,1,'int32');
 
padbytes2 = fread(fid,1,'int32');

if ( vers > 1 )
    nasion_meg = fread(fid,3,'double');
    rightPA_meg = fread(fid,3,'double');
    leftPA_meg = fread(fid,3,'double');
    SAMunitname = fread(fid,32,'*char');
end % version 2 has extra fields

SAMimage = fread(fid,inf,'double'); % 1-d array of voxel values

fclose(fid);

%  .svl file is a stack of coronal slices
xVoxels = size(XStart:StepSize:XEnd,2); % posterior -> anterior (coronal) 
yVoxels = size(YStart:StepSize:YEnd,2); % right -> left (saggital)
zVoxels = size(ZStart:StepSize:ZEnd,2); % bottom -> top (axial)

numImageVoxels = xVoxels * yVoxels * zVoxels;
svlResolution = StepSize * 1000.0;
xmin = XStart * 1000.0;
ymin = YStart * 1000.0;
zmin = ZStart * 1000.0;
xmax = XEnd * 1000.0;
ymax = YEnd * 1000.0;
zmax = ZEnd * 1000.0;

% transpose image data to RAS
Img = reshape(SAMimage, zVoxels, yVoxels, xVoxels); % reshape 1-d array to 3-d
Img = permute(Img, [2 3 1]); % Analyze format
Img = flipdim(Img, 1); % left -> right

niftiFile = strrep(svlFile,'.svl','.nii');
fprintf('[%s]\n', niftiFile);

fprintf('[%s]\n  --> [%s]\n', svlFile, niftiFile);
voxelSize = [svlResolution svlResolution svlResolution];

% for spatial normalization, origin has to match that in the resliced
% anatomical nii file that was used to generate sn3d.mat
dims = size(Img);
origin = [round(dims(1)/2) round(dims(2)/2) round(dims(3)/2)];

dataType = 64;  % DOUBLE
nii = make_nii(Img, voxelSize, origin, dataType);

% important - don't set the sform matrix or else spm normalization will
% generate strange offset etc.
nii.hdr.hist.sform_code = 0;

save_nii(nii, niftiFile);


return


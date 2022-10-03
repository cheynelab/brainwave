function [bb svlResolution] = bw_svl2spm(svlFile)
%       BW_SVL2SPM
%
%   function [bb svlResolution] = bw_svl2spm(svlFile)
%
%   DESCRIPTION: Reading the .svl CTF SAM file given by svlFile, this
%   function will convert it to SPM Analyze format (.img) and return the
%   corresponding bounding box (bb) and resolution (svlResolution).
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  
% function [bb svlResolution) = bw_svl2spm(svlFile)
%
%  reads and converts CTF SAM (.svl) files to Analyze (.img) format for SPM
%  returns the bounding box and resolution of the svl file
%  
%
%  based on ctf_svl2spm.m
%
%  D. Cheyne, Sept, 2008
%  - Dec, 2010 - renamed bw_svl2spm for BrainWave toolbox
%
%  D. Cheyne, Sept, 2008
%  - Mar, 2011 - removed return argument - replaced within local function..
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

version = 2.4;

fprintf('bw_svl2spm version %.1f\n\n', version);

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

%%  .svl file is a stack of coronal slices
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

% return bounding box in cm
bb = [xmin xmax ymin ymax zmin zmax] .* 0.1;

% fprintf('svl dimesions: %d (cor) x %d (sag) x %d (axi) (res = %g mm)\n', xVoxels, yVoxels, zVoxels, svlResolution);
% fprintf('bounding box: [%g %g %g %g %g %g]\n', bb(1), bb(2), bb(3), bb(4), bb(5), bb(6));

%% create Analyze header and update relevant fields

svlImg.hdr = bw_create_spm_header; % creates default header structure

svlImg.fileprefix = strrep(svlFile, '.svl', ''); % file prefix

%% dimensions and resolution
svlImg.hdr.dime.dim(2) = yVoxels; 
svlImg.hdr.dime.dim(3) = xVoxels;
svlImg.hdr.dime.dim(4) = zVoxels;
svlImg.hdr.dime.pixdim(2) = svlResolution;
svlImg.hdr.dime.pixdim(3) = svlResolution;
svlImg.hdr.dime.pixdim(4) = svlResolution;
svlImg.hdr.dime.pixdim(5:8) = [0 0 0 0];

%%  format (Analyze) SAM image for writing
%%  .svl array is [posterior -> anterior (coronal) slices] [right -> left ]
%%  [bottom -> top]
%%  Analyze default axial orientation is actually radiological, but we want
%%  neurological orientation to be compatible to how mri3dX reads in
%%  normalized images [left -> right]
%%  we want [axial slices (slowest)] [posterior -> anterior] [left -> right
%%  (fastest)]
Img = reshape(SAMimage, zVoxels, yVoxels, xVoxels); % reshape 1-d array to 3-d
Img = permute(Img, [2 3 1]); % Analyze format
Img = flipdim(Img, 1); % left -> right
svlImg.img = Img;

%%  get min max values of voxel values; these are re-calculated by avw_write
peakNegValue = min(SAMimage);
peakPosValue = max(SAMimage);

svlImg.hdr.dime.glmax = peakPosValue;
svlImg.hdr.dime.glmax = peakNegValue;

%%  datatype ('DOUBLE')
svlImg.hdr.dime.datatype = 64;
svlImg.hdr.dime.bitpix = 64;

% set origin to zero so that SPM normalization works properly
% Note that SPM2 defines originator field as 5 two-byte integers
% this is because originator field in analyze header is 10 bytes
% write_spm_analyze has been modfied to write it out this way
%
svlImg.hdr.hist.originator = [0 0 0   0 0];

fprintf('writing analyze file %s\n', strcat(svlImg.fileprefix,'.img'));
bw_write_spm_analyze(svlImg, svlImg.fileprefix);












return


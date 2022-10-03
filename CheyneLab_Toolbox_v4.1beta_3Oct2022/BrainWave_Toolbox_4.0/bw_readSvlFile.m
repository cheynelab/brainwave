function svlImg = bw_readSvlFile(svlFile) 
%       BW_READSVLFILE
%
%   function svlImg = bw_readSvlFile(svlFile) 
%
%   DESCRIPTION: Reads the specified .svl SAM file such that MATLAb may use
%   it.
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%
%   --VERSION 1.2--
% Last Revised by N.v.L. on 23/06/2010
% Major Changes: Edited the help file.
%
% Revised by N.v.L. on 17/05/2010
% Major Changes: Created a help section.
%
% Written by D. Cheyne on --/--/---- for the Hospital for Sick Children.

%fprintf('reading svl image file <%s>\n', svlFile);
fid = fopen(svlFile, 'r', 'b','latin1');

%  read .svl header
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

%  .svl file is a stack of coronal slices
xVoxels = size(XStart:StepSize:XEnd,2); % posterior -> anterior (coronal) 
yVoxels = size(YStart:StepSize:YEnd,2); % right -> left (saggital)
zVoxels = size(ZStart:StepSize:ZEnd,2); % bottom -> top (axial)

svlImg.mmPerVoxel = StepSize * 1000.0;

xmin = XStart * 1000.0;
ymin = YStart * 1000.0;
zmin = ZStart * 1000.0;
xmax = XEnd * 1000.0;
ymax = YEnd * 1000.0;
zmax = ZEnd * 1000.0;
svlImg.bb = [xmin xmax ymin ymax zmin zmax] .* 0.1;

% .svl data is stored as coronal slices in MEG frame of reference ie., Z by Y by X  
% where origin is lower right posterior corner and y is RT-LT axis and x is posterior-anterior
% i.e., format is SLA

svlImg.Img = reshape(SAMimage, zVoxels, yVoxels, xVoxels); % reshape 1-d array to 3-d


fclose(fid);
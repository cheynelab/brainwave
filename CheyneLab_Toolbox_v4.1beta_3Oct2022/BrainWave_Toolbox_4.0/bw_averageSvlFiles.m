%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% function bw_averageSvlFiles(listFile, outfilename) 
%
% DESCRIPTION: create a grand average of images in CTF .svl format
%
% input:
% listFile        - text file containing list of files to average
% outfilename     - name for output (average) file. 
%
% (c) D. Cheyne, 2013. All rights reserved. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function bw_averageSvlFiles(listFile, outfilename) 

% read contents of the first file to get the header parameters
% these will be same for the average

filelist = bw_read_list_file(listFile);

numSubjects = size(filelist,1);

svlFile = char( filelist(1,:) );

% read header values only
fprintf('Getting image parameters from <%s>\n', svlFile);
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

% get image dimensions from first file
xVoxels = size(XStart:StepSize:XEnd,2); % posterior -> anterior (coronal) 
yVoxels = size(YStart:StepSize:YEnd,2); % right -> left (saggital)
zVoxels = size(ZStart:StepSize:ZEnd,2); % bottom -> top (axial)


fclose(fid);


img = zeros(zVoxels,yVoxels,xVoxels);

% read all images and compute average...
for j=1:numSubjects
    file = char( filelist(j,:) );
    fprintf('reading file %s...\n', file);
    svlImg = bw_readSvlFile(file);   
    if size(svlImg.Img) ~= size(img)
        fprintf('Error: image %s appear to have different bounding box dimensions...\n', file);
        return;
    end
    img = img + svlImg.Img;             
end

img = img ./ numSubjects;

% write new file using params from first image in list
% note: CTF files are always written out in big-endian 

fprintf('Saving average in file %s\n', outfilename);

fid = fopen(outfilename, 'w', 'b','latin1');

fwrite(fid,'SAMIMAGE','uchar');
fwrite(fid,1,'int32',0,'ieee-be');
fwrite(fid,setname,'uchar');
fwrite(fid,numchans,'int32',0,'ieee-be');
fwrite(fid,numweights,'int32',0,'ieee-be');

fwrite(fid,0,'int32',0,'ieee-be');           % pad bytes

fwrite(fid,XStart,'double',0,'ieee-be');
fwrite(fid,XEnd,'double',0,'ieee-be');
fwrite(fid,YStart,'double',0,'ieee-be');
fwrite(fid,YEnd,'double',0,'ieee-be');
fwrite(fid,ZStart,'double',0,'ieee-be');
fwrite(fid,ZEnd,'double',0,'ieee-be');
fwrite(fid,StepSize,'double',0,'ieee-be');

fwrite(fid,hpFreq,'double',0,'ieee-be');
fwrite(fid,lpFreq,'double',0,'ieee-be');
fwrite(fid,bwFreq,'double',0,'ieee-be');
fwrite(fid,meanNoise,'double',0,'ieee-be');

fwrite(fid,MRIname,'uchar');

fwrite(fid,nasion(1),'int32');
fwrite(fid,nasion(2),'int32');
fwrite(fid,nasion(3),'int32');
fwrite(fid,rightPA(1),'int32');
fwrite(fid,rightPA(2),'int32');
fwrite(fid,rightPA(3),'int32');
fwrite(fid,leftPA(1),'int32');
fwrite(fid,leftPA(2),'int32');
fwrite(fid,leftPA(3),'int32');

fwrite(fid,SAMtype,'int32');

fwrite(fid,padbytes2,'int32');

fwrite(fid,0,'int32',0,'ieee-be');           % pad bytes

if ( vers > 1 )
    fwrite(fid,nasion_meg(1),'double',0,'ieee-be');
    fwrite(fid,nasion_meg(2),'double',0,'ieee-be');
    fwrite(fid,nasion_meg(3),'double',0,'ieee-be');
    fwrite(fid,rightPA_meg(1),'double',0,'ieee-be');
    fwrite(fid,rightPA_meg(2),'double',0,'ieee-be');
    fwrite(fid,rightPA_meg(3),'double',0,'ieee-be');
    fwrite(fid,leftPA_meg(1),'double',0,'ieee-be');
    fwrite(fid,leftPA_meg(2),'double',0,'ieee-be');
    fwrite(fid,leftPA_meg(3),'double',0,'ieee-be');
    fwrite(fid,SAMunitname,'uchar',0,'ieee-be');
end

SAMimage = img(:);

fwrite(fid,SAMimage,'double',0,'ieee-be');

fclose(fid);


end







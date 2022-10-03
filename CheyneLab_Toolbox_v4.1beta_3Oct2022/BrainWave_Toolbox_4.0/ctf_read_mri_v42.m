function mri = bw_ctf_read_mri_v42(file) 
%       BW_CTF_READ_MRI_V42
%
%   function mri = bw_ctf_read_mri_v42(file)
%
%   DESCRIPTION: Taking the CTF version 4.0 or 4.1 .mri file specified by 
%   file this function will read the file and output the information in the
%   structure mri.
%
% (c) D. Cheyne, 2011. All rights reserved. Written by P. Ferrari.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.


%%Function to read in CTF Version 4 .mri files written by SD Muthukumaraswamy
% CUBRIC Aug 2006
%Some of this codewas written by Darren Weber and is an adaption of his
%ctf_read_mri function. I have attempted to keep the Header field naming
%as similar as possible but the file format has changed considerably. This
%is done so software can use the functions interchangeably/invisibly. I have slightly
%modifier Darren's orginal function so that this one is called if a V4
%file is detected
%  Revision notes:
%
%  ** Modified by D. Cheyne Oct 12 / 2007
% renamed to read_ctf_mri to avoid need to change calling function
% also included change to fread statement for compatibility with Matlab release 20007x
% -
% - PFerrari- modified to read either 4.0 or 4.1 ctf mri data
%% ***************************************************************************************

fprintf('Calling function to read Version 4 .mri file');

mri.file = file;

% open file
[fid,message] = fopen(mri.file, 'rb', 's', 'latin1');  %%  added latin1 flag for Matlab 2007x 
if fid < 0, error('cannot open file'); end

fseek(fid, 0, -1);

checkstart = char(fread(fid, [1,4], 'char'));

mri.hdr.other.identifierstring = readCPersist(fid);
mri.hdr.other.UniqueID = readCPersist(fid);

%Get Head model information
temp = ctf2num(readCPersist(fid));
mri.hdr.HeadModel_Info.Nasion_Sag = temp(1); 
mri.hdr.HeadModel_Info.Nasion_Cor = temp(2);
mri.hdr.HeadModel_Info.Nasion_Axi = temp(3);
temp = ctf2num(readCPersist(fid));
mri.hdr.HeadModel_Info.LeftEar_Sag = temp(1);
mri.hdr.HeadModel_Info.LeftEar_Cor = temp(2);
mri.hdr.HeadModel_Info.LeftEar_Axi = temp(3);
temp = ctf2num(readCPersist(fid));
mri.hdr.HeadModel_Info.RightEar_Sag = temp(1);
mri.hdr.HeadModel_Info.RightEar_Cor = temp(2);
mri.hdr.HeadModel_Info.RightEar_Axi = temp(3);
temp = ctf2num(readCPersist(fid));
mri.hdr.HeadModel_Info.defaultSphereX = temp(1);
mri.hdr.HeadModel_Info.defaultSphereY = temp(2);
mri.hdr.HeadModel_Info.defaultSphereZ = temp(3);
mri.hdr.HeadModel_Info.defaultSphereRadius = temp(4);

%Rotational angles
temp = ctf2num(readCPersist(fid));
mri.hdr.rotate_coronal = temp(1);
mri.hdr.rotate_sagittal = temp(1);
mri.hdr.rotate_axial = temp(1);



mri.hdr.imageSize = readCPersist(fid);
mri.hdr.dataSize = readCPersist(fid); 

%Voxel sixes
temp = ctf2num(readCPersist(fid));
mri.hdr.mmPerPixel_sagittal = temp(1); 
mri.hdr.mmPerPixel_coronal = temp(2);
mri.hdr.mmPerPixel_axial = temp(3);

%Head origin
temp = ctf2num(readCPersist(fid));
mri.hdr.headOrigin_sagittal = temp(1);
mri.hdr.headOrigin_coronal = temp(2);
mri.hdr.headOrigin_axial = temp(3);

mri.hdr.orthogonalFlag = readCPersist(fid);
mri.hdr.interpolatedFlag = readCPersist(fid);

temp = ctf2num(readCPersist(fid));
mri.hdr.transformMatrixHead2MRI = reshape(temp,4,4)';

mri.hdr.transformMatrixMRI2Head = inv(mri.hdr.transformMatrixHead2MRI);

%Other junk
mri.hdr.Image_Info.commentString = readCPersist(fid);
mri.hdr.Image_Info.patientID = readCPersist(fid);
mri.hdr.other.patientID = readCPersist(fid);
mri.hdr.other.birthday = readCPersist(fid);
mri.hdr.other.sex = readCPersist(fid);
mri.hdr.other.studyid = readCPersist(fid);
mri.hdr.Image_Info.dateAndTime = readCPersist(fid);
mri.hdr.other.studydate = readCPersist(fid);
mri.hdr.other.studytime = readCPersist(fid);
mri.hdr.other.description = readCPersist(fid);
mri.hdr.other.comments = readCPersist(fid);
mri.hdr.other.accessionnumber = readCPersist(fid);
mri.hdr.Image_Info.modality = readCPersist(fid);
mri.hdr.other.seriesdate = readCPersist(fid);
mri.hdr.other.seriestime  = readCPersist(fid);
mri.hdr.other.seriesdescription = readCPersist(fid);
mri.hdr.Image_Info.manufacturerName = readCPersist(fid);
mri.hdr.other.equipmodel = readCPersist(fid);
mri.hdr.Image_Info.instituteName = readCPersist(fid);
mri.hdr.other.imagereferenceid = readCPersist(fid);
mri.hdr.other.refernceid = readCPersist(fid);
mri.hdr.other.refernceindicator = readCPersist(fid);
mri.hdr.other.location = readCPersist(fid);
mri.hdr.imageOrientation = readCPersist(fid);
mri.hdr.other.imagepixelinterpolation = readCPersist(fid);
mri.hdr.other.sequencename = readCPersist(fid);
mri.hdr.other.scanningsequence = readCPersist(fid);
mri.hdr.other.sequencevariant = readCPersist(fid);
mri.hdr.Image_Info.RepetitionTime = readCPersist(fid);
mri.hdr.Image_Info.EchoTime = readCPersist(fid);
mri.hdr.Image_Info.InversionTime = readCPersist(fid);
mri.hdr.other.averages = readCPersist(fid);
mri.hdr.Image_Info.Frequency = readCPersist(fid);
mri.hdr.Image_Info.imagedNucleus = readCPersist(fid);
mri.hdr.Image_Info.Fieldstrength = readCPersist(fid);
mri.hdr.Image_Info.FlipAngle = readCPersist(fid);
mri.hdr.other.rescaleintercept = readCPersist(fid);
mri.hdr.other.rescaleslop = readCPersist(fid);
mri.hdr.other.voilutwindowwidth = readCPersist(fid);
mri.hdr.other.voilutwindowcenter = readCPersist(fid);
mri.hdr.other.specificcharset = readCPersist(fid);
%made up values so as to be closer to version 2 of mri files -Nat.
mri.hdr.clippingRange=mri.hdr.imageSize-1;
mri.hdr.transformMatrix=mri.hdr.transformMatrixHead2MRI;
mri.hdr.Image_Info.dateAndTime=['Date:',mri.hdr.other.seriesdate,' Time:',mri.hdr.other.seriestime];
scantypeinfo=find(mri.hdr.other.seriesdescription==' ');
%mri.hdr.Image_Info.scanType=mri.hdr.other.seriesdescription(scantypeinfo(end):end);
mri.hdr.Image_Info.contrastAgent='NONE';
mri.her.Image_Info.NoExcitations=0;
mri.hdr.Image_Info.NoAcquisitions=1;
mri.hdr.Image_Info.forFutureUse='';

%pferrari
% check for v4.1 by checking next entry
% if next tag label refers to the newer DICOM info in v4.1 then read the next 13 tags
% before continuing on to the image data, else just proceed as normal
check_length = fread(fid, 1, 'int32');
check_label = char(fread(fid, [1,check_length],'char'));
if strncmp(check_label,'_DICOMSOURCE_HASVALIDIMAGE',26)
    fseek(fid,-(check_length+4),0); %go back and start over
    mri.hdr.dicom.dicom_hasvailidimage = readCPersist(fid);
    mri.hdr.dicom.dicom_number_slices = readCPersist(fid);
    mri.hdr.dicom.dicom_number_rows = readCPersist(fid);
    mri.hdr.dicom.dicom_number_columns = readCPersist(fid);
    mri.hdr.dicom.dicom_slice_spacing = readCPersist(fid);
    mri.hdr.dicom.dicom_slice_thickness = readCPersist(fid);
    mri.hdr.dicom.dicom_row_spacing = readCPersist(fid);
    mri.hdr.dicom.dicom_column_spacing = readCPersist(fid);
    mri.hdr.dicom.dicom_row_orientation = readCPersist(fid);
    mri.hdr.dicom.dicom_column_orientation = readCPersist(fid);
    mri.hdr.dicom.dicom_location_gap = readCPersist(fid);
    for i=1:mri.hdr.dicom.dicom_number_slices;
        mri.hdr.dicom.dicom_slice_location{i} = readCPersist(fid);
    end
    for i=1:mri.hdr.dicom.dicom_number_slices;
        mri.hdr.dicom.dicom_ctf_to_source_slice{i} = readCPersist(fid);
    end
else
    fseek(fid,-(check_length+4),0); %rewind before proceeding for v4.0
end


%%%Header is now read in so now read in the data. We wont use a CPersist call for
%%%this though because the data is read straight into the final data
%%%structure in 8 or 16 bit

PixelDim = 256;
RowDim   = 256;
SliceDim = 256;

% check if the data is 8 or 16 bits (Darren Weber)
switch mri.hdr.dataSize,
  case 1, % we have 8 bit data
    fprintf('...reading 8 bit image data\n');
    precision = 'uchar';
  case 2, % we have 16 bit data
    fprintf('...reading 16 bit image data\n');
    precision = 'int16';
  otherwise,
    msg = sprintf('unknown mri.hdr.dataSize: %g',mri.hdr.dataSize);
    error(msg);
end

mri.img = zeros(SliceDim,PixelDim,RowDim);

for i = 1 : SliceDim
    %read the header tag
    length1 = fread(fid, 1, 'int32');
    label = char(fread(fid, [1,length1] , 'char'));
    type = fread(fid, 1, 'int32');
    length2 = fread(fid, 1, 'int32');
    %read the data
    mri.img(i,:,:) = fread(fid, [SliceDim, RowDim], precision);
   
end    


%End of file

len = fread(fid, 1, 'int32');
checkend = char(fread(fid, [1,len], 'char'));
if checkend ~= 'EndOfParameters'
     fprintf('Uh oh didnt end up at the end of the file..possible error\n');
end

fclose(fid);
   
%%Other fields from version 2 header I couldnt match to V4 header...hmm

%clippingRange = max value of data .. could obtain this
%imageOrientation eg., 0 = left on left, 1 = left on right vs
%imageplaneorientation??


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%Tag Reader
%Note: the no support tags shouldn't matter  - at least not for reading
%the .mri file

function value = readCPersist(fid); 

length1 = fread(fid, 1, 'int32');
label = char(fread(fid, [1,length1] , 'char'));
type = fread(fid, 1, 'int32');
if type == 10 
   length2 = fread(fid, 1, 'int32');
   value = char(fread(fid, [1,length2], 'char'));
elseif type == 3 
   fprintf('No support- posible error\n');   
elseif type == 1
    fprintf('No support- posible error\n');
elseif type == 2    
    fprintf('No support- posible error\n');
elseif type == 4
    value = fread(fid, 1, 'double');
elseif type == 5
    value = fread(fid, 1, 'int32');
elseif type == 6
    value = fread(fid, 1, 'int16');
elseif type == 7
    value = fread(fid, 1, 'uint16');
elseif type == 8
    value = fread(fid, 1, 'char');
elseif type == 9
    value = fread(fid, 32, 'char');
elseif type == 11
    fprintf('No support- posible error\n');
elseif type == 12    
     fprintf('No support- posible error\n');
elseif type ==  13     
     fprintf('No support- posible error\n');
elseif type == 14
   value = fread(fid, 1, 'char');
elseif type == 15
   value = fread(fid, 1, 'int64'); %Little confused by the CTF manual here but think this is right 
elseif type == 16
    value = fread(fid, 1, 'uint64');
elseif type == 17    
    value = fread(fid, 1, 'int32');
end  

return

%%%%%%%%%%%%%%%%%%

function Numbers = ctf2num(String);
%This function parses one of those silly CTF strings into a numeric array
  position = findstr('\', String);
  ind = 1;
  for i = 1 : (length(position) + 1)
      if i <= length(position)
       temp = String(ind : position(i) - 1  );
       ind = position(i) + 1;
      else
       temp = String(position(i - 1) + 1:end);
      end
      Numbers(i) = str2num(temp) ;
   end    

return
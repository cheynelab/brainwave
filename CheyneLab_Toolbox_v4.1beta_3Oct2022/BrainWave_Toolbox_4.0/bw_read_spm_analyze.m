function [avw] = bw_read_spm_analyze(fileprefix)
%       BW_READ_SPM_ANALYZE
%
%   function [avw] = bw_read_spm_analyze(fileprefix)
%
%   DESCRIPTION: A collection of functions that reads analyze files so as 
%   to allow for modification without creating conflicts with the original 
%   copies of the avw routines. It will output a single MATLAB readable 
%   matrix containing the analysis image's data (avw).
%
% Based off code by D. Weber. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%   --VERSION 1.2--
% Last Revised by N.v.L. on 23/06/2010
% Major Changes: Changed the help file.
%
% Revised by N.v.L. on 17/05/2010
% Major Changes: Edited the help file.
%
% D. Cheyne, Sept 2008
%
% NOTE: this is a striped down and renamed version of avw routines to read
% analyze files that will allow modification without creating conflicts
% with original copies of the avw routines. This will just read  a 
% single analyze image
%
% Also, packed everything into one file for easier maintenance 
%
% The original header:
%
% $Revision: 1.1 $ $Date: 2004/11/12 01:30:25 $

% Licence:  GNU GPL, no express or implied warranties
% History:  07/2003, Darren.Weber_at_radiology.ucsf.edu
%                    The Analyze format is copyright 
%                    (c) Copyright, 1986-1995
%                    Biomedical Imaging Resource, Mayo Foundation
%                    - created this wrapper for avw_img_read, see
%                      that function for extensive comments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%------------------------------------------------------------------------


% defaults for avw routines - don't seem to matter?
machine = 'ieee-le';
verbose = false;
IMGorient = '';

% Read the file header

% first get fileprefix from .img or .hdr name 
%
if findstr('.hdr',fileprefix),
    fileprefix = strrep(fileprefix,'.hdr','');
end
if findstr('.img',fileprefix),
    fileprefix = strrep(fileprefix,'.img','');
end

file = sprintf('%s.hdr',fileprefix);

if exist(file)
    if verbose,
        fprintf('...reading %s Analyze format',machine);
    end
    fid = fopen(file,'r',machine);
    avw.hdr = read_header(fid,verbose);
    avw.fileprefix = fileprefix;
    fclose(fid);
    
    if ~isequal(avw.hdr.hk.sizeof_hdr,348),
        if verbose, fprintf('...failed.\n'); end
        % first try reading the opposite endian to 'machine'
        switch machine,
        case 'ieee-le', machine = 'ieee-be';
        case 'ieee-be', machine = 'ieee-le';
        end
        if verbose, fprintf('...reading %s Analyze format',machine); end
        fid = fopen(file,'r',machine);
        avw.hdr = read_header(fid,verbose);
        avw.fileprefix = fileprefix;
        fclose(fid);
    end
    
    if ~isequal(avw.hdr.hk.sizeof_hdr,348),
        % Now throw an error
        if verbose, fprintf('...failed.\n'); end
        msg = sprintf('...size of header not equal to 348 bytes!\n\n');
        error(msg);
    end
else
    msg = sprintf('...cannot find file %s.hdr\n\n',file);
    error(msg);
end

% read .img file part
avw = read_image(avw,IMGorient,machine,verbose);



return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [ dsr ] = read_header(fid,verbose)
    
    % Original header structures - ANALYZE 7.5
	%struct dsr
	%       { 
	%       struct header_key hk;            /*   0 +  40       */
	%       struct image_dimension dime;     /*  40 + 108       */
	%       struct data_history hist;        /* 148 + 200       */
	%       };                               /* total= 348 bytes*/
    dsr.hk   = header_key(fid);
    dsr.dime = image_dimension(fid,verbose);
    dsr.hist = data_history(fid);
    
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [hk] = header_key(fid)
    
    % The required elements in the header_key substructure are: 
    %
	% int sizeof_header   Must indicate the byte size of the header file. 
	% int extents         Should be 16384, the image file is created as 
	%                     contiguous with a minimum extent size. 
	% char regular        Must be 'r' to indicate that all images and 
	%                     volumes are the same size. 
	
	% Original header structures - ANALYZE 7.5
	% struct header_key                      /* header key      */ 
	%       {                                /* off + size      */
	%       int sizeof_hdr                   /*  0 +  4         */
	%       char data_type[10];              /*  4 + 10         */
	%       char db_name[18];                /* 14 + 18         */
	%       int extents;                     /* 32 +  4         */
	%       short int session_error;         /* 36 +  2         */
	%       char regular;                    /* 38 +  1         */
	%       char hkey_un0;                   /* 39 +  1         */
	%       };                               /* total=40 bytes  */
    
    fseek(fid,0,'bof');
    
    hk.sizeof_hdr    = fread(fid, 1,'*int32');  % should be 348!
    hk.data_type     = fread(fid,10,'*char')';
    hk.db_name       = fread(fid,18,'*char')';
    hk.extents       = fread(fid, 1,'*int32');
    hk.session_error = fread(fid, 1,'*int16');
    hk.regular       = fread(fid, 1,'*char')'; % might be uint8
    hk.hkey_un0      = fread(fid, 1,'*uint8')';
    
    % check if this value was a char zero
    if hk.hkey_un0 == 48,
        hk.hkey_un0 = 0;
    end
    
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [ dime ] = image_dimension(fid,verbose)
    
	%struct image_dimension
	%       {                                /* off + size      */
	%       short int dim[8];                /* 0 + 16          */
    %           /*
    %           dim[0]      Number of dimensions in database; usually 4. 
    %           dim[1]      Image X dimension;  number of *pixels* in an image row. 
    %           dim[2]      Image Y dimension;  number of *pixel rows* in slice. 
    %           dim[3]      Volume Z dimension; number of *slices* in a volume. 
    %           dim[4]      Time points; number of volumes in database
    %           */
	%       char vox_units[4];               /* 16 + 4          */
	%       char cal_units[8];               /* 20 + 8          */
	%       short int unused1;               /* 28 + 2          */
	%       short int datatype;              /* 30 + 2          */
	%       short int bitpix;                /* 32 + 2          */
	%       short int dim_un0;               /* 34 + 2          */
	%       float pixdim[8];                 /* 36 + 32         */
	%			/*
	%				pixdim[] specifies the voxel dimensions:
	%				pixdim[1] - voxel width, mm
	%				pixdim[2] - voxel height, mm
	%				pixdim[3] - slice thickness, mm
    %               pixdim[4] - volume timing, in msec
	%					..etc
	%			*/
	%       float vox_offset;                /* 68 + 4          */
	%       float roi_scale;                 /* 72 + 4          */
	%       float funused1;                  /* 76 + 4          */
	%       float funused2;                  /* 80 + 4          */
	%       float cal_max;                   /* 84 + 4          */
	%       float cal_min;                   /* 88 + 4          */
	%       int compressed;                  /* 92 + 4          */
	%       int verified;                    /* 96 + 4          */
	%       int glmax;                       /* 100 + 4         */
	%       int glmin;                       /* 104 + 4         */
	%       };                               /* total=108 bytes */
    
	dime.dim        = fread(fid,8,'*int16')';
	dime.vox_units  = fread(fid,4,'*char')';
	dime.cal_units  = fread(fid,8,'*char')';
	dime.unused1    = fread(fid,1,'*int16');
	dime.datatype   = fread(fid,1,'*int16');
	dime.bitpix     = fread(fid,1,'*int16');
	dime.dim_un0    = fread(fid,1,'*int16');
	dime.pixdim     = fread(fid,8,'*float')';
	dime.vox_offset = fread(fid,1,'*float');
	dime.roi_scale  = fread(fid,1,'*float');
	dime.funused1   = fread(fid,1,'*float');
	dime.funused2   = fread(fid,1,'*float');
	dime.cal_max    = fread(fid,1,'*float');
	dime.cal_min    = fread(fid,1,'*float');
	dime.compressed = fread(fid,1,'*int32');
	dime.verified   = fread(fid,1,'*int32');
	dime.glmax      = fread(fid,1,'*int32');
	dime.glmin      = fread(fid,1,'*int32');
	
    if dime.dim(1) < 4, % Number of dimensions in database; usually 4.
        if verbose,
            fprintf('...ensuring 4 dimensions in avw.hdr.dime.dim\n');
        end
        dime.dim(1) = int16(4);
    end
    if dime.dim(5) < 1, % Time points; number of volumes in database
        if verbose,
            fprintf('...ensuring at least 1 volume in avw.hdr.dime.dim(5)\n');
        end
        dime.dim(5) = int16(1);
    end
    
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [ hist ] = data_history(fid)
    
	% Original header structures - ANALYZE 7.5
	%struct data_history       
	%       {                                /* off + size      */
	%       char descrip[80];                /* 0 + 80          */
	%       char aux_file[24];               /* 80 + 24         */
	%       char orient;                     /* 104 + 1         */
	%       char originator[10];             /* 105 + 10        */
	%       char generated[10];              /* 115 + 10        */
	%       char scannum[10];                /* 125 + 10        */
	%       char patient_id[10];             /* 135 + 10        */
	%       char exp_date[10];               /* 145 + 10        */
	%       char exp_time[10];               /* 155 + 10        */
	%       char hist_un0[3];                /* 165 + 3         */
	%       int views                        /* 168 + 4         */
	%       int vols_added;                  /* 172 + 4         */
	%       int start_field;                 /* 176 + 4         */
	%       int field_skip;                  /* 180 + 4         */
	%       int omax;                        /* 184 + 4         */
	%       int omin;                        /* 188 + 4         */
	%       int smax;                        /* 192 + 4         */
	%       int smin;                        /* 196 + 4         */
	%       };                               /* total=200 bytes */
	
	hist.descrip     = fread(fid,80,'*char')';
	hist.aux_file    = fread(fid,24,'*char')';
	hist.orient      = fread(fid, 1,'*uint8');  % see note below on char
    
	%hist.originator  = fread(fid,10,'*char')';
	% read SPM2 origin field 
    hist.originator  = fread(fid,5,'int16')';
    
	hist.generated   = fread(fid,10,'*char')';
	hist.scannum     = fread(fid,10,'*char')';
	hist.patient_id  = fread(fid,10,'*char')';
	hist.exp_date    = fread(fid,10,'*char')';
	hist.exp_time    = fread(fid,10,'*char')';
	hist.hist_un0    = fread(fid, 3,'*char')';
	hist.views       = fread(fid, 1,'*int32');
	hist.vols_added  = fread(fid, 1,'*int32');
	hist.start_field = fread(fid, 1,'*int32');
	hist.field_skip  = fread(fid, 1,'*int32');
	hist.omax        = fread(fid, 1,'*int32');
	hist.omin        = fread(fid, 1,'*int32');
	hist.smax        = fread(fid, 1,'*int32');
	hist.smin        = fread(fid, 1,'*int32');
	
    % check if hist.orient was saved as ascii char value
    switch hist.orient,
        case 48, hist.orient = uint8(0);
        case 49, hist.orient = uint8(1);
        case 50, hist.orient = uint8(2);
        case 51, hist.orient = uint8(3);
        case 52, hist.orient = uint8(4);
        case 53, hist.orient = uint8(5);
    end
    
return


% Note on using char:
% The 'char orient' field in the header is intended to
% hold simply an 8-bit unsigned integer value, not the ASCII representation
% of the character for that value.  A single 'char' byte is often used to
% represent an integer value in Analyze if the known value range doesn't
% go beyond 0-255 - saves a byte over a short int, which may not mean
% much in today's computing environments, but given that this format
% has been around since the early 1980's, saving bytes here and there on
% older systems was important!  In this case, 'char' simply provides the
% byte of storage - not an indicator of the format for what is stored in
% this byte.  Generally speaking, anytime a single 'char' is used, it is
% probably meant to hold an 8-bit integer value, whereas if this has
% been dimensioned as an array, then it is intended to hold an ASCII
% character string, even if that was only a single character.
% Denny  <hanson.dennis2@mayo.edu>


% Comments
% The header format is flexible and can be extended for new 
% user-defined data types. The essential structures of the header 
% are the header_key and the image_dimension.
%

% The required elements in the header_key substructure are: 
%
% int sizeof_header   Must indicate the byte size of the header file. 
% int extents         Should be 16384, the image file is created as 
%                     contiguous with a minimum extent size. 
% char regular        Must be 'r' to indicate that all images and 
%                     volumes are the same size. 
% 

% The image_dimension substructure describes the organization and 
% size of the images. These elements enable the database to reference 
% images by volume and slice number. Explanation of each element follows: 
% 
% short int dim[ ];      /* Array of the image dimensions */ 
%
% dim[0]      Number of dimensions in database; usually 4. 
% dim[1]      Image X dimension; number of pixels in an image row. 
% dim[2]      Image Y dimension; number of pixel rows in slice. 
% dim[3]      Volume Z dimension; number of slices in a volume. 
% dim[4]      Time points; number of volumes in database.
% dim[5]      Undocumented.
% dim[6]      Undocumented.
% dim[7]      Undocumented.
% 
% char vox_units[4]     Specifies the spatial units of measure for a voxel. 
% char cal_units[8]      Specifies the name of the calibration unit. 
% short int unused1      /* Unused */ 
% short int datatype      /* Datatype for this image set */ 
% /*Acceptable values for datatype are*/ 
% #define DT_NONE             0
% #define DT_UNKNOWN          0    /*Unknown data type*/ 
% #define DT_BINARY           1    /*Binary             ( 1 bit per voxel)*/ 
% #define DT_UNSIGNED_CHAR    2    /*Unsigned character ( 8 bits per voxel)*/ 
% #define DT_SIGNED_SHORT     4    /*Signed short       (16 bits per voxel)*/ 
% #define DT_SIGNED_INT       8    /*Signed integer     (32 bits per voxel)*/ 
% #define DT_FLOAT           16    /*Floating point     (32 bits per voxel)*/ 
% #define DT_COMPLEX         32    /*Complex (64 bits per voxel; 2 floating point numbers)/* 
% #define DT_DOUBLE          64    /*Double precision   (64 bits per voxel)*/ 
% #define DT_RGB            128    /*A Red-Green-Blue datatype*/
% #define DT_ALL            255    /*Undocumented*/
% 
% short int bitpix;    /* Number of bits per pixel; 1, 8, 16, 32, or 64. */ 
% short int dim_un0;   /* Unused */ 
% 
% float pixdim[];     Parallel array to dim[], giving real world measurements in mm and ms. 
%       pixdim[0];    Pixel dimensions? 
%       pixdim[1];    Voxel width in mm. 
%       pixdim[2];    Voxel height in mm. 
%       pixdim[3];    Slice thickness in mm. 
%       pixdim[4];    timeslice in ms (ie, TR in fMRI). 
%       pixdim[5];    Undocumented. 
%       pixdim[6];    Undocumented. 
%       pixdim[7];    Undocumented. 
% 
% float vox_offset;   Byte offset in the .img file at which voxels start. This value can be 
%                     negative to specify that the absolute value is applied for every image
%                     in the file. 
% 
% float roi_scale; Specifies the Region Of Interest scale? 
% float funused1; Undocumented. 
% float funused2; Undocumented. 
% 
% float cal_max; Specifies the upper bound of the range of calibration values. 
% float cal_min; Specifies the lower bound of the range of calibration values. 
% 
% int compressed; Undocumented. 
% int verified;   Undocumented. 
% 
% int glmax;    The maximum pixel value for the entire database. 
% int glmin;    The minimum pixel value for the entire database. 
% 
% 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [ avw ] = read_image(avw,IMGorient,machine,verbose)

fid = fopen(sprintf('%s.img',avw.fileprefix),'r',machine);
if fid < 0,
  msg = sprintf('...cannot open file %s.img\n\n',avw.fileprefix);
  error(msg);
end

if verbose,
    ver = '[$Revision: 1.1 $]';
    fprintf('\nAVW_IMG_READ [v%s]\n',ver(12:16));  tic;
end

% short int bitpix;    /* Number of bits per pixel; 1, 8, 16, 32, or 64. */ 
% short int datatype      /* Datatype for this image set */ 
% /*Acceptable values for datatype are*/ 
% #define DT_NONE             0
% #define DT_UNKNOWN          0    /*Unknown data type*/ 
% #define DT_BINARY           1    /*Binary             ( 1 bit per voxel)*/ 
% #define DT_UNSIGNED_CHAR    2    /*Unsigned character ( 8 bits per voxel)*/ 
% #define DT_SIGNED_SHORT     4    /*Signed short       (16 bits per voxel)*/ 
% #define DT_SIGNED_INT       8    /*Signed integer     (32 bits per voxel)*/ 
% #define DT_FLOAT           16    /*Floating point     (32 bits per voxel)*/ 
% #define DT_COMPLEX         32    /*Complex (64 bits per voxel; 2 floating point numbers)/* 
% #define DT_DOUBLE          64    /*Double precision   (64 bits per voxel)*/ 
% #define DT_RGB            128    /*A Red-Green-Blue datatype*/
% #define DT_ALL            255    /*Undocumented*/

switch double(avw.hdr.dime.bitpix),
  case  1,   precision = 'bit1';
  case  8,   precision = 'uchar';
  case 16,   precision = 'int16';
  case 32,
    if     isequal(avw.hdr.dime.datatype, 8), precision = 'int32';
    else                                      precision = 'single';
    end
  case 64,   precision = 'double';
  otherwise,
    precision = 'uchar';
    if verbose, fprintf('...precision undefined in header, using ''uchar''\n'); end
end

% read the whole .img file into matlab (faster)
if verbose,
    fprintf('...reading %s Analyze %s image format.\n',machine,precision);
end
fseek(fid,0,'bof');
% adjust for matlab version
ver = version;
ver = str2num(ver(1));
if ver < 6,
  tmp = fread(fid,inf,sprintf('%s',precision));
else,
  tmp = fread(fid,inf,sprintf('%s=>double',precision));
end
fclose(fid);

% Update the global min and max values
avw.hdr.dime.glmax = max(double(tmp));
avw.hdr.dime.glmin = min(double(tmp));


%---------------------------------------------------------------
% Now partition the img data into xyz

% --- first figure out the size of the image

% short int dim[ ];      /* Array of the image dimensions */ 
%
% dim[0]      Number of dimensions in database; usually 4. 
% dim[1]      Image X dimension;  number of pixels in an image row. 
% dim[2]      Image Y dimension;  number of pixel rows in slice. 
% dim[3]      Volume Z dimension; number of slices in a volume. 
% dim[4]      Time points; number of volumes in database.

PixelDim = double(avw.hdr.dime.dim(2));
RowDim   = double(avw.hdr.dime.dim(3));
SliceDim = double(avw.hdr.dime.dim(4));
TimeDim  = double(avw.hdr.dime.dim(5));

PixelSz  = double(avw.hdr.dime.pixdim(2));
RowSz    = double(avw.hdr.dime.pixdim(3));
SliceSz  = double(avw.hdr.dime.pixdim(4));
TimeSz   = double(avw.hdr.dime.pixdim(5));




% ---- NON STANDARD ANALYZE...

% Some Analyze files have been found to set -ve pixdim values, eg
% the MNI template avg152T1_brain in the FSL etc/standard folder,
% perhaps to indicate flipped orientation?  If so, this code below
% will NOT handle the flip correctly!
if PixelSz < 0,
  warning('X pixdim < 0 !!! resetting to abs(avw.hdr.dime.pixdim(2))');
  PixelSz = abs(PixelSz);
  avw.hdr.dime.pixdim(2) = single(PixelSz);
end
if RowSz < 0,
  warning('Y pixdim < 0 !!! resetting to abs(avw.hdr.dime.pixdim(3))');
  RowSz = abs(RowSz);
  avw.hdr.dime.pixdim(3) = single(RowSz);
end
if SliceSz < 0,
  warning('Z pixdim < 0 !!! resetting to abs(avw.hdr.dime.pixdim(4))');
  SliceSz = abs(SliceSz);
  avw.hdr.dime.pixdim(4) = single(SliceSz);
end

% ---- END OF NON STANDARD ANALYZE





% --- check the orientation specification and arrange img accordingly
if ~isempty(IMGorient),
  if ischar(IMGorient),
    avw.hdr.hist.orient = uint8(str2num(IMGorient));
  else
    avw.hdr.hist.orient = uint8(IMGorient);
  end
end,

if isempty(avw.hdr.hist.orient),
  msg = [ '...unspecified avw.hdr.hist.orient, using default 0\n',...
      '   (check image and try explicit IMGorient option).\n'];
  fprintf(msg);
  avw.hdr.hist.orient = uint8(0);
end

% --- check if the orientation is to be flipped for a volume with more
% --- than 3 dimensions.  this logic is currently unsupported so throw
% --- an error.  volumes of any dimensionality may be read in *only* as
% --- unflipped, ie, avw.hdr.hist.orient == 0
if ( TimeDim > 1 ) && (avw.hdr.hist.orient ~= 0 ),
   msg = [ 'ERROR: This volume has more than 3 dimensions *and* ', ...
           'requires flipping the data.  Flipping is not supported ', ...
           'for volumes with dimensionality greater than 3.  Set ', ...
           'avw.hdr.hist.orient = 0 and flip your volume after ', ...
           'calling this function' ];
   msg = sprintf( '%s (%s).', msg, mfilename );
   error( msg );
end

switch double(avw.hdr.hist.orient),
  
  case 0, % transverse unflipped
    
    % orient = 0:  The primary orientation of the data on disk is in the
    % transverse plane relative to the object scanned.  Most commonly, the fastest
    % moving index through the voxels that are part of this transverse image would
    % span the right-left extent of the structure imaged, with the next fastest
    % moving index spanning the posterior-anterior extent of the structure.  This
    % 'orient' flag would indicate to Analyze that this data should be placed in
    % the X-Y plane of the 3D Analyze Coordinate System, with the Z dimension
    % being the slice direction.
    
    % For the 'transverse unflipped' type, the voxels are stored with
    % Pixels in 'x' axis (varies fastest) - from patient right to left
    % Rows in   'y' axis                  - from patient posterior to anterior
    % Slices in 'z' axis                  - from patient inferior to superior
    
    if verbose, fprintf('...reading axial unflipped orientation\n'); end
    
    % -- This code will handle nD files
    dims = double( avw.hdr.dime.dim(2:end) );
    % replace dimensions of 0 with 1 to be used in reshape
    idx = find( dims == 0 );
    dims( idx ) = 1;
    avw.img = reshape( tmp, dims );
    
    % -- The code above replaces this
    %         avw.img = zeros(PixelDim,RowDim,SliceDim);
    %         
    %         n = 1;
    %         x = 1:PixelDim;
    %         for z = 1:SliceDim,
    %             for y = 1:RowDim,
    %                 % load Y row of X values into Z slice avw.img
    %                 avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
    %                 n = n + PixelDim;
    %             end
    %         end
    
    
    % no need to rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    
    
case 1, % coronal unflipped
    
    % orient = 1:  The primary orientation of the data on disk is in the coronal
    % plane relative to the object scanned.  Most commonly, the fastest moving
    % index through the voxels that are part of this coronal image would span the
    % right-left extent of the structure imaged, with the next fastest moving
    % index spanning the inferior-superior extent of the structure.  This 'orient'
    % flag would indicate to Analyze that this data should be placed in the X-Z
    % plane of the 3D Analyze Coordinate System, with the Y dimension being the
    % slice direction.
    
    % For the 'coronal unflipped' type, the voxels are stored with
    % Pixels in 'x' axis (varies fastest) - from patient right to left
    % Rows in   'z' axis                  - from patient inferior to superior
    % Slices in 'y' axis                  - from patient posterior to anterior
    
    if verbose, fprintf('...reading coronal unflipped orientation\n'); end
    
    avw.img = zeros(PixelDim,SliceDim,RowDim);
    
    n = 1;
    x = 1:PixelDim;
    for y = 1:SliceDim,
      for z = 1:RowDim,
        % load Z row of X values into Y slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    avw.hdr.dime.dim(2:4) = int16([PixelDim,SliceDim,RowDim]);
    avw.hdr.dime.pixdim(2:4) = single([PixelSz,SliceSz,RowSz]);
    
    
  case 2, % sagittal unflipped
    
    % orient = 2:  The primary orientation of the data on disk is in the sagittal
    % plane relative to the object scanned.  Most commonly, the fastest moving
    % index through the voxels that are part of this sagittal image would span the
    % posterior-anterior extent of the structure imaged, with the next fastest
    % moving index spanning the inferior-superior extent of the structure.  This
    % 'orient' flag would indicate to Analyze that this data should be placed in
    % the Y-Z plane of the 3D Analyze Coordinate System, with the X dimension
    % being the slice direction.
    
    % For the 'sagittal unflipped' type, the voxels are stored with
    % Pixels in 'y' axis (varies fastest) - from patient posterior to anterior
    % Rows in   'z' axis                  - from patient inferior to superior
    % Slices in 'x' axis                  - from patient right to left
    
    if verbose, fprintf('...reading sagittal unflipped orientation\n'); end
    
    avw.img = zeros(SliceDim,PixelDim,RowDim);
    
    n = 1;
    y = 1:PixelDim;         % posterior to anterior (fastest)
    
    for x = 1:SliceDim,     % right to left (slowest)
      for z = 1:RowDim,   % inferior to superior
        
        % load Z row of Y values into X slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    avw.hdr.dime.dim(2:4) = int16([SliceDim,PixelDim,RowDim]);
    avw.hdr.dime.pixdim(2:4) = single([SliceSz,PixelSz,RowSz]);
    
    
    %--------------------------------------------------------------------------------
    % Orient values 3-5 have the second index reversed in order, essentially
    % 'flipping' the images relative to what would most likely become the vertical
    % axis of the displayed image.
    %--------------------------------------------------------------------------------
    
  case 3, % transverse/axial flipped
    
    % orient = 3:  The primary orientation of the data on disk is in the
    % transverse plane relative to the object scanned.  Most commonly, the fastest
    % moving index through the voxels that are part of this transverse image would
    % span the right-left extent of the structure imaged, with the next fastest
    % moving index spanning the *anterior-posterior* extent of the structure.  This
    % 'orient' flag would indicate to Analyze that this data should be placed in
    % the X-Y plane of the 3D Analyze Coordinate System, with the Z dimension
    % being the slice direction.
    
    % For the 'transverse flipped' type, the voxels are stored with
    % Pixels in 'x' axis (varies fastest) - from patient right to Left
    % Rows in   'y' axis                  - from patient anterior to Posterior *
    % Slices in 'z' axis                  - from patient inferior to Superior
    
    if verbose, fprintf('...reading axial flipped (+Y from Anterior to Posterior)\n'); end
    
    avw.img = zeros(PixelDim,RowDim,SliceDim);
    
    n = 1;
    x = 1:PixelDim;
    for z = 1:SliceDim,
      for y = RowDim:-1:1, % flip in Y, read A2P file into P2A 3D matrix
        
        % load a flipped Y row of X values into Z slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % no need to rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    
    
  case 4, % coronal flipped
    
    % orient = 4:  The primary orientation of the data on disk is in the coronal
    % plane relative to the object scanned.  Most commonly, the fastest moving
    % index through the voxels that are part of this coronal image would span the
    % right-left extent of the structure imaged, with the next fastest moving
    % index spanning the *superior-inferior* extent of the structure.  This 'orient'
    % flag would indicate to Analyze that this data should be placed in the X-Z
    % plane of the 3D Analyze Coordinate System, with the Y dimension being the
    % slice direction.
    
    % For the 'coronal flipped' type, the voxels are stored with
    % Pixels in 'x' axis (varies fastest) - from patient right to Left
    % Rows in   'z' axis                  - from patient superior to Inferior*
    % Slices in 'y' axis                  - from patient posterior to Anterior
    
    if verbose, fprintf('...reading coronal flipped (+Z from Superior to Inferior)\n'); end
    
    avw.img = zeros(PixelDim,SliceDim,RowDim);
    
    n = 1;
    x = 1:PixelDim;
    for y = 1:SliceDim,
      for z = RowDim:-1:1, % flip in Z, read S2I file into I2S 3D matrix
        
        % load a flipped Z row of X values into Y slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    avw.hdr.dime.dim(2:4) = int16([PixelDim,SliceDim,RowDim]);
    avw.hdr.dime.pixdim(2:4) = single([PixelSz,SliceSz,RowSz]);
    
    
  case 5, % sagittal flipped
    
    % orient = 5:  The primary orientation of the data on disk is in the sagittal
    % plane relative to the object scanned.  Most commonly, the fastest moving
    % index through the voxels that are part of this sagittal image would span the
    % posterior-anterior extent of the structure imaged, with the next fastest
    % moving index spanning the *superior-inferior* extent of the structure.  This
    % 'orient' flag would indicate to Analyze that this data should be placed in
    % the Y-Z plane of the 3D Analyze Coordinate System, with the X dimension
    % being the slice direction.
    
    % For the 'sagittal flipped' type, the voxels are stored with
    % Pixels in 'y' axis (varies fastest) - from patient posterior to Anterior
    % Rows in   'z' axis                  - from patient superior to Inferior*
    % Slices in 'x' axis                  - from patient right to Left
    
    if verbose, fprintf('...reading sagittal flipped (+Z from Superior to Inferior)\n'); end
    
    avw.img = zeros(SliceDim,PixelDim,RowDim);
    
    n = 1;
    y = 1:PixelDim;
    
    for x = 1:SliceDim,
      for z = RowDim:-1:1, % flip in Z, read S2I file into I2S 3D matrix
        
        % load a flipped Z row of Y values into X slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    avw.hdr.dime.dim(2:4) = int16([SliceDim,PixelDim,RowDim]);
    avw.hdr.dime.pixdim(2:4) = single([SliceSz,PixelSz,RowSz]);
    
  otherwise
    
    error('unknown value in avw.hdr.hist.orient, try explicit IMGorient option.');
    
end

if verbose, t=toc; fprintf('...done (%5.2f sec).\n\n',t); end

return




% This function attempts to read the orientation of the
% Analyze file according to the hdr.hist.orient field of the 
% header.  Unfortunately, this field is optional and not
% all programs will set it correctly, so there is no guarantee,
% that the data loaded will be correctly oriented.  If necessary, 
% experiment with the 'orient' option to read the .img 
% data into the 3D matrix of avw.img as preferred.
% 

% (Conventions gathered from e-mail with support@AnalyzeDirect.com)
% 
% 0  transverse unflipped 
%       X direction first,  progressing from patient right to left, 
%       Y direction second, progressing from patient posterior to anterior, 
%       Z direction third,  progressing from patient inferior to superior. 
% 1  coronal unflipped 
%       X direction first,  progressing from patient right to left, 
%       Z direction second, progressing from patient inferior to superior, 
%       Y direction third,  progressing from patient posterior to anterior. 
% 2  sagittal unflipped 
%       Y direction first,  progressing from patient posterior to anterior, 
%       Z direction second, progressing from patient inferior to superior, 
%       X direction third,  progressing from patient right to left. 
% 3  transverse flipped 
%       X direction first,  progressing from patient right to left, 
%       Y direction second, progressing from patient anterior to posterior, 
%       Z direction third,  progressing from patient inferior to superior. 
% 4  coronal flipped 
%       X direction first,  progressing from patient right to left, 
%       Z direction second, progressing from patient superior to inferior, 
%       Y direction third,  progressing from patient posterior to anterior. 
% 5  sagittal flipped 
%       Y direction first,  progressing from patient posterior to anterior, 
%       Z direction second, progressing from patient superior to inferior, 
%       X direction third,  progressing from patient right to left. 


%----------------------------------------------------------------------------
% From ANALYZE documentation...
% 
% The ANALYZE coordinate system has an origin in the lower left 
% corner. That is, with the subject lying supine, the coordinate 
% origin is on the right side of the body (x), at the back (y), 
% and at the feet (z). This means that:
% 
% +X increases from right (R) to left (L)
% +Y increases from the back (posterior,P) to the front (anterior, A)
% +Z increases from the feet (inferior,I) to the head (superior, S)
% 
% The LAS orientation is the radiological convention, where patient 
% left is on the image right.  The alternative neurological
% convention is RAS (also Talairach convention).
% 
% A major advantage of the Analzye origin convention is that the 
% coordinate origin of each orthogonal orientation (transverse, 
% coronal, and sagittal) lies in the lower left corner of the 
% slice as it is displayed.
% 
% Orthogonal slices are numbered from one to the number of slices
% in that orientation. For example, a volume (x, y, z) dimensioned 
% 128, 256, 48 has: 
% 
%   128 sagittal   slices numbered 1 through 128 (X)
%   256 coronal    slices numbered 1 through 256 (Y)
%    48 transverse slices numbered 1 through  48 (Z)
% 
% Pixel coordinates are made with reference to the slice numbers from 
% which the pixels come. Thus, the first pixel in the volume is 
% referenced p(1,1,1) and not at p(0,0,0).
% 
% Transverse slices are in the XY plane (also known as axial slices).
% Sagittal slices are in the ZY plane. 
% Coronal slices are in the ZX plane. 
% 
%----------------------------------------------------------------------------


%----------------------------------------------------------------------------
% E-mail from support@AnalyzeDirect.com
% 
% The 'orient' field in the data_history structure specifies the primary
% orientation of the data as it is stored in the file on disk.  This usually
% corresponds to the orientation in the plane of acquisition, given that this
% would correspond to the order in which the data is written to disk by the
% scanner or other software application.  As you know, this field will contain
% the values:
% 
% orient = 0 transverse unflipped
% 1 coronal unflipped
% 2 sagittal unflipped
% 3 transverse flipped
% 4 coronal flipped
% 5 sagittal flipped
% 
% It would be vary rare that you would ever encounter any old Analyze 7.5
% files that contain values of 'orient' which indicate that the data has been
% 'flipped'.  The 'flipped flag' values were really only used internal to
% Analyze to precondition data for fast display in the Movie module, where the
% images were actually flipped vertically in order to accommodate the raster
% paint order on older graphics devices.  The only cases you will encounter
% will have values of 0, 1, or 2.
% 
% As mentioned, the 'orient' flag only specifies the primary orientation of
% data as stored in the disk file itself.  It has nothing to do with the
% representation of the data in the 3D Analyze coordinate system, which always
% has a fixed representation to the data.  The meaning of the 'orient' values
% should be interpreted as follows:
% 
% orient = 0:  The primary orientation of the data on disk is in the
% transverse plane relative to the object scanned.  Most commonly, the fastest
% moving index through the voxels that are part of this transverse image would
% span the right-left extent of the structure imaged, with the next fastest
% moving index spanning the posterior-anterior extent of the structure.  This
% 'orient' flag would indicate to Analyze that this data should be placed in
% the X-Y plane of the 3D Analyze Coordinate System, with the Z dimension
% being the slice direction.
% 
% orient = 1:  The primary orientation of the data on disk is in the coronal
% plane relative to the object scanned.  Most commonly, the fastest moving
% index through the voxels that are part of this coronal image would span the
% right-left extent of the structure imaged, with the next fastest moving
% index spanning the inferior-superior extent of the structure.  This 'orient'
% flag would indicate to Analyze that this data should be placed in the X-Z
% plane of the 3D Analyze Coordinate System, with the Y dimension being the
% slice direction.
% 
% orient = 2:  The primary orientation of the data on disk is in the sagittal
% plane relative to the object scanned.  Most commonly, the fastest moving
% index through the voxels that are part of this sagittal image would span the
% posterior-anterior extent of the structure imaged, with the next fastest
% moving index spanning the inferior-superior extent of the structure.  This
% 'orient' flag would indicate to Analyze that this data should be placed in
% the Y-Z plane of the 3D Analyze Coordinate System, with the X dimension
% being the slice direction.
% 
% Orient values 3-5 have the second index reversed in order, essentially
% 'flipping' the images relative to what would most likely become the vertical
% axis of the displayed image.
% 
% Hopefully you understand the difference between the indication this 'orient'
% flag has relative to data stored on disk and the full 3D Analyze Coordinate
% System for data that is managed as a volume image.  As mentioned previously,
% the orientation of patient anatomy in the 3D Analyze Coordinate System has a
% fixed orientation relative to each of the orthogonal axes.  This orientation
% is completely described in the information that is attached, but the basics
% are:
% 
% Left-handed coordinate system
% 
% X-Y plane is Transverse
% X-Z plane is Coronal
% Y-Z plane is Sagittal
% 
% X axis runs from patient right (low X) to patient left (high X)
% Y axis runs from posterior (low Y) to anterior (high Y)
% Z axis runs from inferior (low Z) to superior (high Z)
% 
%----------------------------------------------------------------------------



%----------------------------------------------------------------------------
% SPM2 NOTES from spm2 webpage: One thing to watch out for is the image 
% orientation. The proper Analyze format uses a left-handed co-ordinate 
% system, whereas Talairach uses a right-handed one. In SPM99, images were 
% flipped at the spatial normalisation stage (from one co-ordinate system 
% to the other). In SPM2b, a different approach is used, so that either a 
% left- or right-handed co-ordinate system is used throughout. The SPM2b 
% program is told about the handedness that the images are stored with by 
% the spm_flip_analyze_images.m function and the defaults.analyze.flip 
% parameter that is specified in the spm_defaults.m file. These files are 
% intended to be customised for each site. If you previously used SPM99 
% and your images were flipped during spatial normalisation, then set 
% defaults.analyze.flip=1. If no flipping took place, then set 
% defaults.analyze.flip=0. Check that when using the Display facility
% (possibly after specifying some rigid-body rotations) that: 
% 
% The top-left image is coronal with the top (superior) of the head displayed 
% at the top and the left shown on the left. This is as if the subject is viewed 
% from behind. 
% 
% The bottom-left image is axial with the front (anterior) of the head at the 
% top and the left shown on the left. This is as if the subject is viewed from above. 
% 
% The top-right image is sagittal with the front (anterior) of the head at the 
% left and the top of the head shown at the top. This is as if the subject is 
% viewed from the left.
%----------------------------------------------------------------------------



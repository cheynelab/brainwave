function bw_make_contrast_image(file1, file2, outfile)
%       BW_MAKE_CONTRAST_IMAGE
%
%   function bw_make_contrast_image(file1, file2, outfile)
%
%   DESCRIPTION: Taking the two analyze format filesnames specified by 
%   file1 and file2, the function will subtract file1-file2 and save the 
%   result under the name specified by outfile. 
%
% (c) D. Cheyne, 2011. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_make_contrast_image(file1, file2, outfile)
%
% D. Cheyne, July, 2011
% 
% - based on bw_subtract_image_files does not automatically plot resul
% - has ability to keep positive only difference
%
% 
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[path file ext] = bw_fileparts(file1);

if strncmp(ext,'.txt',4) == 1
    img1 = load(file1);
    img2 = load(file2);
    diff = img1 - img2;
    
    fid = fopen(outfile,'w');
    fprintf(fid,'%.6f\n',diff);
    fclose(fid);
    return;
end


positiveOnly = false;

[image fileType] = bw_read_SPM_file(file1);
if (fileType == 0)
    fprintf('Can only subtract Analyze or NIfTI files...\n');
    return;
end
        
hdr = image.hdr;
xdim1 = int32(hdr.dime.dim(2));
ydim1 = int32(hdr.dime.dim(3));
zdim1 = int32(hdr.dime.dim(4));
xres1 = double(hdr.dime.pixdim(2));
yres1 = double(hdr.dime.pixdim(3));
zres1 = double(hdr.dime.pixdim(4));
fprintf('read SPM volume %s, dimensions =[%g %g %g], resolution = [%g %g %g]\n',file1, xdim1, ydim1, zdim1, xres1, yres1, zres1);

img1 = image.img;

[image fileType] = bw_read_SPM_file(file2);
if (fileType == 0)
    fprintf('Can only subtract Analyze or NIfTI files...\n');
    return;
end
hdr = image.hdr;

xdim2 = int32(hdr.dime.dim(2));
ydim2 = int32(hdr.dime.dim(3));
zdim2 = int32(hdr.dime.dim(4));
xres2 = double(hdr.dime.pixdim(2));
yres2 = double(hdr.dime.pixdim(3));
zres2 = double(hdr.dime.pixdim(4));

fprintf('read SPM volume %s, dimensions =[%g %g %g], resolution = [%g %g %g]\n',file2, xdim2, ydim2, zdim2, xres2, yres2, zres2);       

img2 = image.img;

% do sanity check on image size
if (xdim1 ~= xdim2 || ydim1 ~= ydim2 || zdim1 ~= zdim2)
    fprintf('Images are not same dimensions...\n');
    return;
end
if (xres1 ~= xres2 || yres1 ~= yres2 || zres1 ~= zres2)
    fprintf('Images are not same voxel size...\n');
    return;
end

new_image = image;     % copy header
new_image.img = img1 - img2;  % replace data with difference

%
% to save the A > B contrast remove negative voxels...
%
if (positiveOnly)
    negVox = find(new_image.img < 0);
    new_image.img(negVox) = NaN;
end

if fileType==1
    [path new_image.fileprefix ext] = bw_fileparts(outfile);  
    bw_write_spm_analyze(new_image, new_image.fileprefix);
elseif fileType==2
    save_nii(new_image, outfile);
end 

fprintf('Saving contrast:\n (%s > %s) as:\n --> %s\n', file1, file2, outfile);


end

        
      